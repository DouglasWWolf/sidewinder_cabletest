//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 01-Dec-23  DWW     1  Initial creation
//====================================================================================

/*

*/


module cabletest_ctl 
(
    input clk, resetn,

    //================== This is an AXI4-Lite slave interface ==================
        
    // "Specify write address"              -- Master --    -- Slave --
    input[31:0]                             S_AXI_AWADDR,   
    input                                   S_AXI_AWVALID,  
    output                                                  S_AXI_AWREADY,
    input[2:0]                              S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input[31:0]                             S_AXI_WDATA,      
    input                                   S_AXI_WVALID,
    input[3:0]                              S_AXI_WSTRB,
    output                                                  S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             S_AXI_BRESP,
    output                                                  S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[31:0]                             S_AXI_ARADDR,     
    input                                   S_AXI_ARVALID,
    input[2:0]                              S_AXI_ARPROT,     
    output                                                  S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output[31:0]                                            S_AXI_RDATA,
    output                                                  S_AXI_RVALID,
    output[1:0]                                             S_AXI_RRESP,
    input                                   S_AXI_RREADY,
    //==========================================================================
 
    // This goes high for a cycle to signal the start of packet generation
    output reg start,

    // This goes high for a cycle to tell "packet_gen" to simulate an error
    output reg sim_err1, sim_err2,

    // Tells us whether the packet generators are doing their thing
    input busy1, busy2,

    // These pulse high 1 cycle every time a packet is sent
    input sent1, sent2,

    // These pulse high 1 cycle every time a packet is received
    input rcvd1, rcvd2, 

    // These pulse high on any clock cycle where a bit error occurs
    input err1, err2,

    // The number of cycles in a data-packet
    output reg[7:0] CYCLES_PER_PACKET, 
    
    // Number of packets that should be transmitted
    output reg[63:0] PACKET_COUNT

    //==========================================================================    
);  

    // Any time the register map of this module changes, this number should
    // be bumped
    localparam MODULE_VERSION = 1;

    // The indicies of the AXI registers
    localparam REG_MODULE_REV        =  0;
    localparam REG_STATUS            =  1;
    localparam REG_CYCLES_PER_PACKET =  2;
    localparam REG_PACKET_COUNTH     =  3;
    localparam REG_PACKET_COUNTL     =  4;

    localparam REG_PACKETS_SENT1H    =  5;
    localparam REG_PACKETS_SENT1L    =  6;
    localparam REG_PACKETS_SENT2H    =  7;
    localparam REG_PACKETS_SENT2L    =  8;
    
    localparam REG_PACKETS_RCVD1H    =  9;
    localparam REG_PACKETS_RCVD1L    = 10;
    localparam REG_PACKETS_RCVD2H    = 11;
    localparam REG_PACKETS_RCVD2L    = 12;

    localparam REG_ERRORS1           = 13;
    localparam REG_ERRORS2           = 14;

    localparam REG_SIM_ERROR         = 15;
    //==========================================================================


    //==========================================================================
    // We'll communicate with the AXI4-Lite Slave core with these signals.
    //==========================================================================
    // AXI Slave Handler Interface for write requests
    wire[31:0]  ashi_waddr;     // Input:  Write-address
    wire[31:0]  ashi_wdata;     // Input:  Write-data
    wire        ashi_write;     // Input:  1 = Handle a write request
    reg[1:0]    ashi_wresp;     // Output: Write-response (OKAY, DECERR, SLVERR)
    wire        ashi_widle;     // Output: 1 = Write state machine is idle

    // AXI Slave Handler Interface for read requests
    wire[31:0]  ashi_raddr;     // Input:  Read-address
    wire        ashi_read;      // Input:  1 = Handle a read request
    reg[31:0]   ashi_rdata;     // Output: Read data
    reg[1:0]    ashi_rresp;     // Output: Read-response (OKAY, DECERR, SLVERR);
    wire        ashi_ridle;     // Output: 1 = Read state machine is idle
    //==========================================================================

    // The state of the state-machines that handle AXI4-Lite read and AXI4-Lite write
    reg[3:0] axi4_write_state, axi4_read_state;

    // The AXI4 slave state machines are idle when in state 0 and their "start" signals are low
    assign ashi_widle = (ashi_write == 0) && (axi4_write_state == 0);
    assign ashi_ridle = (ashi_read  == 0) && (axi4_read_state  == 0);
   
    // These are the valid values for ashi_rresp and ashi_wresp
    localparam OKAY   = 0;
    localparam SLVERR = 2;
    localparam DECERR = 3;

    // An AXI slave is gauranteed a minimum of 128 bytes of address space
    // (128 bytes is 32 32-bit registers)
    localparam ADDR_MASK = 7'h7F;

    // Coalesce the two busy signals
    wire[1:0] busy = {busy2, busy1};
    
    // Number of packets transmitted
    reg[63:0] packets_out1, packets_out2;

    // Number of packets received
    reg[63:0] packets_in1, packets_in2;

    // Number of data-cycles with mismatch errors detected
    reg[31:0] errors1, errors2 ;

    //==========================================================================
    // This state machine handles AXI4-Lite write requests
    //
    // Drives:
    //==========================================================================
    always @(posedge clk) begin
    
        // These will only strobe high for one cycle
        start    <= 0;
        sim_err1 <= 0;
        sim_err2 <= 0;

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            axi4_write_state  <= 0;
            PACKET_COUNT      <= 0;
            CYCLES_PER_PACKET <= 16;

        // If we're not in reset, and a write-request has occured...        
        end else case (axi4_write_state)
        
        0:  if (ashi_write) begin
       
                // Assume for the moment that the result will be OKAY
                ashi_wresp <= OKAY;              
            
                // Convert the byte address into a register index
                case ((ashi_waddr & ADDR_MASK) >> 2)

                    REG_CYCLES_PER_PACKET:
                        if (busy == 0) begin
                            CYCLES_PER_PACKET <= ashi_wdata;
                        end

                    REG_PACKET_COUNTH:
                        if (busy == 0) begin
                            PACKET_COUNT[63:32] <= ashi_wdata;
                        end

                    REG_PACKET_COUNTL:
                        if (busy == 0 && {PACKET_COUNT[63:32], ashi_wdata} != 0) begin
                            PACKET_COUNT[31:0] <= ashi_wdata;
                            start              <= 1;
                        end

                    REG_SIM_ERROR:
                        begin
                            sim_err1 <= ashi_wdata[0];
                            sim_err2 <= ashi_wdata[1];
                        end


                    // Writes to any other register are a decode-error
                    default: ashi_wresp <= DECERR;
                endcase
            end

        endcase
    end
    //==========================================================================





    //==========================================================================
    // World's simplest state machine for handling AXI4-Lite read requests
    //==========================================================================
    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            axi4_read_state <= 0;
        
        // If we're not in reset, and a read-request has occured...        
        end else if (ashi_read) begin
       
            // Assume for the moment that the result will be OKAY
            ashi_rresp <= OKAY;              
            
            // Convert the byte address into a register index
            case ((ashi_raddr & ADDR_MASK) >> 2)
 
                // Allow a read from any valid register                
                REG_MODULE_REV:         ashi_rdata <= MODULE_VERSION;
                REG_STATUS:             ashi_rdata <= busy;
                REG_CYCLES_PER_PACKET:  ashi_rdata <= CYCLES_PER_PACKET;
                REG_PACKET_COUNTH:      ashi_rdata <= PACKET_COUNT[63:32];
                REG_PACKET_COUNTL:      ashi_rdata <= PACKET_COUNT[31:00];
                REG_PACKETS_SENT1H:     ashi_rdata <= packets_out1[63:32];
                REG_PACKETS_SENT1L:     ashi_rdata <= packets_out1[31:00];
                REG_PACKETS_SENT2H:     ashi_rdata <= packets_out2[63:32];
                REG_PACKETS_SENT2L:     ashi_rdata <= packets_out2[31:00];
                REG_PACKETS_RCVD1H:     ashi_rdata <= packets_in1 [63:32];
                REG_PACKETS_RCVD1L:     ashi_rdata <= packets_in1 [31:00];
                REG_PACKETS_RCVD2H:     ashi_rdata <= packets_in2 [63:32];
                REG_PACKETS_RCVD2L:     ashi_rdata <= packets_in2 [31:00];
                REG_ERRORS1:            ashi_rdata <= errors1;
                REG_ERRORS2:            ashi_rdata <= errors2;

                // Reads of any other register are a decode-error
                default: ashi_rresp <= DECERR;
            endcase
        end
    end
    //==========================================================================


    //==========================================================================
    // This state machine tracks the number of packets sent and received
    //==========================================================================
    always @(posedge clk) begin
        if (start || resetn == 0) begin
            packets_in1  <= 0;
            packets_in2  <= 0;
            packets_out1 <= 0;
            packets_out2 <= 0;
            errors1      <= 0;
            errors2      <= 0;
        end else begin
            if (sent1) packets_out1 <= packets_out1 + 1;
            if (sent2) packets_out2 <= packets_out2 + 1;
            if (rcvd1) packets_in1  <= packets_in1  + 1;
            if (rcvd2) packets_in2  <= packets_in2  + 1;
            if (err1 & errors1 != 32'hFFFF_FFFF) errors1 <= errors1 + 1;
            if (err2 & errors2 != 32'hFFFF_FFFF) errors2 <= errors2 + 1;
        end
    end
    //==========================================================================




    //==========================================================================
    // This connects us to an AXI4-Lite slave core
    //==========================================================================
    axi4_lite_slave axi_slave
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (S_AXI_AWADDR),
        .AXI_AWVALID    (S_AXI_AWVALID),   
        .AXI_AWPROT     (S_AXI_AWPROT),
        .AXI_AWREADY    (S_AXI_AWREADY),
        
        // AXI W channel
        .AXI_WDATA      (S_AXI_WDATA),
        .AXI_WVALID     (S_AXI_WVALID),
        .AXI_WSTRB      (S_AXI_WSTRB),
        .AXI_WREADY     (S_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (S_AXI_BRESP),
        .AXI_BVALID     (S_AXI_BVALID),
        .AXI_BREADY     (S_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (S_AXI_ARADDR), 
        .AXI_ARVALID    (S_AXI_ARVALID),
        .AXI_ARPROT     (S_AXI_ARPROT),
        .AXI_ARREADY    (S_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (S_AXI_RDATA),
        .AXI_RVALID     (S_AXI_RVALID),
        .AXI_RRESP      (S_AXI_RRESP),
        .AXI_RREADY     (S_AXI_RREADY),

        // ASHI write-request registers
        .ASHI_WADDR     (ashi_waddr),
        .ASHI_WDATA     (ashi_wdata),
        .ASHI_WRITE     (ashi_write),
        .ASHI_WRESP     (ashi_wresp),
        .ASHI_WIDLE     (ashi_widle),

        // ASHI read registers
        .ASHI_RADDR     (ashi_raddr),
        .ASHI_RDATA     (ashi_rdata),
        .ASHI_READ      (ashi_read ),
        .ASHI_RRESP     (ashi_rresp),
        .ASHI_RIDLE     (ashi_ridle)
    );
    //==========================================================================


endmodule
