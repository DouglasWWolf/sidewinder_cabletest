
module prbs31 #
(
    parameter seed = 32'hFFFF_FFFE
)
(
    input             clock, resetn,
    output reg [31:0] prbs
);



function [31:0] next_prbs31 (input[31:0] in);
	begin
		next_prbs31[31] = in[30] ^ in[27];
		next_prbs31[30] = in[29] ^ in[26];
		next_prbs31[29] = in[28] ^ in[25];
		next_prbs31[28] = in[27] ^ in[24];
		next_prbs31[27] = in[26] ^ in[23];
		next_prbs31[26] = in[25] ^ in[22];
		next_prbs31[25] = in[24] ^ in[21];
		next_prbs31[24] = in[23] ^ in[20];
		next_prbs31[23] = in[22] ^ in[19];
		next_prbs31[22] = in[21] ^ in[18];
		next_prbs31[21] = in[20] ^ in[17];
		next_prbs31[20] = in[19] ^ in[16];
		next_prbs31[19] = in[18] ^ in[15];
		next_prbs31[18] = in[17] ^ in[14];
		next_prbs31[17] = in[16] ^ in[13];
		next_prbs31[16] = in[15] ^ in[12];
		next_prbs31[15] = in[14] ^ in[11];
		next_prbs31[14] = in[13] ^ in[10];
		next_prbs31[13] = in[12] ^ in[ 9];
		next_prbs31[12] = in[11] ^ in[ 8];
		next_prbs31[11] = in[10] ^ in[ 7];
		next_prbs31[10] = in[ 9] ^ in[ 6];
		next_prbs31[ 9] = in[ 8] ^ in[ 5];
		next_prbs31[ 8] = in[ 7] ^ in[ 4];
		next_prbs31[ 7] = in[ 6] ^ in[ 3];
		next_prbs31[ 6] = in[ 5] ^ in[ 2];
		next_prbs31[ 5] = in[ 4] ^ in[ 1];
		next_prbs31[ 4] = in[ 3] ^ in[ 0];
		next_prbs31[ 3] = in[ 2] ^ (in[30] ^ in[27]);
		next_prbs31[ 2] = in[ 1] ^ (in[29] ^ in[26]);
		next_prbs31[ 1] = in[ 0] ^ (in[28] ^ in[25]);
		next_prbs31[ 0] = (in[30] ^ in[27]) ^ (in[27] ^ in[24]);
	end
endfunction

always @(posedge clock)begin
	if (resetn == 0) begin
		prbs <= seed;
	end else begin
		prbs <= next_prbs31(prbs);
	end
end

endmodule

