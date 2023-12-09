module random 
(
    input          clock, resetn,
    output [511:0] value
);

prbs31#( 1) urand_00(clock, resetn, value[ 0*32 +: 32]);
prbs31#( 2) urand_01(clock, resetn, value[ 1*32 +: 32]);
prbs31#( 3) urand_02(clock, resetn, value[ 2*32 +: 32]);
prbs31#( 4) urand_03(clock, resetn, value[ 3*32 +: 32]);
prbs31#( 5) urand_04(clock, resetn, value[ 4*32 +: 32]);
prbs31#( 6) urand_05(clock, resetn, value[ 5*32 +: 32]);
prbs31#( 7) urand_06(clock, resetn, value[ 6*32 +: 32]);
prbs31#( 8) urand_07(clock, resetn, value[ 7*32 +: 32]);
prbs31#( 9) urand_08(clock, resetn, value[ 8*32 +: 32]);
prbs31#(10) urand_09(clock, resetn, value[ 9*32 +: 32]);
prbs31#(11) urand_10(clock, resetn, value[10*32 +: 32]);
prbs31#(12) urand_11(clock, resetn, value[11*32 +: 32]);
prbs31#(13) urand_12(clock, resetn, value[12*32 +: 32]);
prbs31#(14) urand_13(clock, resetn, value[13*32 +: 32]);
prbs31#(15) urand_14(clock, resetn, value[14*32 +: 32]);
prbs31#(16) urand_15(clock, resetn, value[15*32 +: 32]);

endmodule

