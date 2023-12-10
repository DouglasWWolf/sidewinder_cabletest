//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 08-Dec-23  DWW     1  Initial creation
//====================================================================================

/*

    This module receive incoming packets and compares their contents to data
    arriving via a FIFO.  On every clock cycle with a data-mismatch, the 
    "error" signal is raised.
*/

module receiver
(
    input   clk, resetn,
   
    output[1:0] status,

    //==================================================================
    //                   The packet-input stream
    //==================================================================
    input[511:0] AXIS_IN_TDATA,
    input[ 63:0] AXIS_IN_TKEEP,
    input        AXIS_IN_TLAST,
    input        AXIS_IN_TVALID,
    output       AXIS_IN_TREADY,
    //==================================================================    


    //==================================================================
    //                   The FIFO input stream
    //==================================================================
    input[511:0] AXIS_FIFO_TDATA,
    input[ 63:0] AXIS_FIFO_TKEEP,
    input        AXIS_FIFO_TLAST,
    input        AXIS_FIFO_TVALID,
    output       AXIS_FIFO_TREADY
    //==================================================================    

);

// This is the data-cycle handshake signal for the input stream
wire handshake = AXIS_IN_TREADY & AXIS_IN_TVALID;

// We're ready to read in data when we have something to compare it against
assign AXIS_IN_TREADY = AXIS_FIFO_TVALID & (resetn == 1);

// "error" strobes high on a data mismatch
wire error = (resetn == 1) & handshake & (AXIS_IN_TDATA != AXIS_FIFO_TDATA);

// This strobes high when we receive the last data-cycle of a packet
wire packet_rcvd = (resetn == 1) & handshake & AXIS_IN_TLAST;

// The FIFO should output its next element every time we see incoming data
assign AXIS_FIFO_TREADY = handshake;

// We report "data mismatch" and "packet was received" to the control module
assign status = {error, packet_rcvd};

endmodule
