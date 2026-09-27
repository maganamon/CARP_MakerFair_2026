`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Wire game serial numbers -> 14-segment patterns
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  Turns serial_idx (0-7) into the 4 characters for ht16k33_driver
  (digit0 = leftmost). Same table as wire_game_fsm:

    idx  serial  wire
     0   B7K2    Green
     1   A4M6    Red
     2   T3R8    Blue
     3   E5N3    Blue
     4   C1L4    Yellow
     5   O7P1    Yellow
     6   Z9D2    Red
     7   U2X8    Green

  Segment patterns use the Adafruit 14-segment layout (bit 0 = top segment
  A ... bit 14 = decimal point). If a character looks wrong on your module,
  fix its constant below.
*/

module wire_serial_rom (
    input  logic [2:0]  serial_idx,
    output logic [15:0] digit0,      // leftmost
    output logic [15:0] digit1,
    output logic [15:0] digit2,
    output logic [15:0] digit3       // rightmost
);

    // Digits
    localparam logic [15:0] C_1 = 16'h0006;
    localparam logic [15:0] C_2 = 16'h00DB;
    localparam logic [15:0] C_3 = 16'h008F;
    localparam logic [15:0] C_4 = 16'h00E6;
    localparam logic [15:0] C_5 = 16'h2069;
    localparam logic [15:0] C_6 = 16'h00FD;
    localparam logic [15:0] C_7 = 16'h0007;
    localparam logic [15:0] C_8 = 16'h00FF;
    localparam logic [15:0] C_9 = 16'h00EF;

    // Letters
    localparam logic [15:0] C_A = 16'h00F7;
    localparam logic [15:0] C_B = 16'h128F;
    localparam logic [15:0] C_C = 16'h0039;
    localparam logic [15:0] C_D = 16'h120F;
    localparam logic [15:0] C_E = 16'h00F9;
    localparam logic [15:0] C_K = 16'h2470;
    localparam logic [15:0] C_L = 16'h0038;
    localparam logic [15:0] C_M = 16'h0536;
    localparam logic [15:0] C_N = 16'h2136;
    localparam logic [15:0] C_O = 16'h003F;
    localparam logic [15:0] C_P = 16'h00F3;
    localparam logic [15:0] C_R = 16'h20F3;
    localparam logic [15:0] C_T = 16'h1201;
    localparam logic [15:0] C_U = 16'h003E;
    localparam logic [15:0] C_X = 16'h2D00;
    localparam logic [15:0] C_Z = 16'h0C09;

    always_comb begin
        case (serial_idx)
            3'd0:    {digit0, digit1, digit2, digit3} = {C_B, C_7, C_K, C_2};
            3'd1:    {digit0, digit1, digit2, digit3} = {C_A, C_4, C_M, C_6};
            3'd2:    {digit0, digit1, digit2, digit3} = {C_T, C_3, C_R, C_8};
            3'd3:    {digit0, digit1, digit2, digit3} = {C_E, C_5, C_N, C_3};
            3'd4:    {digit0, digit1, digit2, digit3} = {C_C, C_1, C_L, C_4};
            3'd5:    {digit0, digit1, digit2, digit3} = {C_O, C_7, C_P, C_1};
            3'd6:    {digit0, digit1, digit2, digit3} = {C_Z, C_9, C_D, C_2};
            default: {digit0, digit1, digit2, digit3} = {C_U, C_2, C_X, C_8};
        endcase
    end

endmodule
