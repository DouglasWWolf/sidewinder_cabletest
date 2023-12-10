//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 08-Dec-23  DWW     1  Initial creation
//====================================================================================

/*
    This module generates packets full of psuedo-random data, and also writes
    that data into a FIFO so it can be compared to the incoming packet that 
    has been looped-back
*/

module packet_gen
(
    input   clk, resetn,
   

    input [ 7:0] CYCLES_PER_PACKET,
    input [63:0] PACKET_COUNT,
    input [ 2:0] control,
    output[ 2:0] status,
    output reg   resetn_fifo,

    //==================================================================
    //                   The packet-output stream
    //==================================================================
    output[511:0] AXIS_OUT_TDATA,
    output[ 63:0] AXIS_OUT_TKEEP,
    output        AXIS_OUT_TLAST,
    output        AXIS_OUT_TVALID,
    input         AXIS_OUT_TREADY,
    //==================================================================    


    //==================================================================
    //                   The FIFO output stream
    //==================================================================
    output[511:0] AXIS_FIFO_TDATA,
    output        AXIS_FIFO_TVALID,
    input         AXIS_FIFO_TREADY
    //==================================================================    

);


reg[ 63:0] packets_sent;
reg[  7:0] cycle_number;
reg        inject_latched;

// This is a new psuedo-random number on every clock cycle
wire[511:0] random;
random u_random(clk, resetn, random);

// This is a single bit on at a random location in a 512 bit field
wire[511:0] single_bit_error = {511'b0, inject_latched} << random[8:0];

// This is high on any clock cycle where a data transfer occurs on the output stream
wire handshake = AXIS_OUT_TVALID & AXIS_OUT_TREADY;

// This will latch high when we're sent a "halt" signal
reg halt;

// The possible states of our state machine
reg[  1:0] fsm_state;
localparam FSM_WAIT_FOR_START = 0;
localparam FSM_RESET_FIFO1    = 1;
localparam FSM_RESET_FIFO2    = 2;
localparam FSM_GENERATE       = 3;

// Bit definitions of the "control" port
localparam CTL_START  = 0;
localparam CTL_HALT   = 1;
localparam CTL_INJECT = 2;

// Bit definitions of the "status" port
localparam STA_BUSY   = 0;
localparam STA_SENT   = 1;
localparam STA_HALTED = 2;

// TDATA is driven with (psuedo) random bits, with potentially 1 bit flipped
assign AXIS_OUT_TDATA = random ^ single_bit_error;

// We always keep all bytes of the packet
assign AXIS_OUT_TKEEP = -1;

// TVALID is high whenever we're generating packets
assign AXIS_OUT_TVALID = (fsm_state == FSM_GENERATE);

// Drive TLAST high on the last cycle of every packet
assign AXIS_OUT_TLAST = (fsm_state == FSM_GENERATE) & (cycle_number == CYCLES_PER_PACKET);

// The FIFO output stream is data-driven from the random-number-generator
assign AXIS_FIFO_TDATA  = random;
assign AXIS_FIFO_TVALID = handshake;

// We're busy any time we're generating packets
assign status[STA_BUSY] = (control[CTL_START] || fsm_state != FSM_WAIT_FOR_START);

// Fill in the status bit that tells the outside world we've been halted
assign status[STA_HALTED] = (status[STA_BUSY] == 0) & halt;

// Strobe "packet_sent" on the last cycle of every packet
assign status[STA_SENT] = (handshake & AXIS_OUT_TLAST);

//==================================================================
// This state machine drives data-packets out both the AXIS_OUT
// and AXIS_FIFO streams
//==================================================================
reg[31:0] countdown;
//------------------------------------------------------------------
always @(posedge clk) begin
    
    // Latch the "halt" control signal
    if (control[CTL_HALT]) halt <= 1;

    // This performs a continuous countdown
    if (countdown) countdown <= countdown - 1;
    
    if (resetn == 0) begin
        fsm_state <= 0;
    end else case(fsm_state)

        FSM_WAIT_FOR_START:
            if (control[CTL_START]) begin
                resetn_fifo    <= 0;
                countdown      <= 16;
                inject_latched <= 0;
                halt           <= 0;
                fsm_state      <= FSM_RESET_FIFO1;
            end

        FSM_RESET_FIFO1:
            if (countdown == 0) begin
                resetn_fifo <= 1;
                countdown   <= 16;
                fsm_state   <= FSM_RESET_FIFO2;
            end

        FSM_RESET_FIFO2:
            if (countdown == 0) begin
                packets_sent <= 1;
                cycle_number <= 1;
                fsm_state    <= FSM_GENERATE;
            end

        FSM_GENERATE:
            if (handshake) begin
                inject_latched <= 0;                
                cycle_number   <= cycle_number + 1;
                if (AXIS_OUT_TLAST) begin
                    cycle_number <= 1;
                    if (packets_sent == PACKET_COUNT)
                        fsm_state <= FSM_WAIT_FOR_START;
                    else
                        packets_sent <= packets_sent + 1;
                    if (halt) fsm_state <= FSM_WAIT_FOR_START;
                end
            end

    endcase

    // If we've been told to inject an error, latch that state
    if (control[CTL_INJECT]) inject_latched <= 1;
end
//==================================================================


endmodule
