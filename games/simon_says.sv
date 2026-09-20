`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
//Design: simon says LED game
//Engineer: CARP
///////////////////////////////////////////////////////////////////////////////

/*
  NOT FINISHed  comments here
*/

module simon_says(
     input  logic       clk,
     input  logic       rst,
     input  logic [3:0] btn_pressed,
     input  logic [1:0] rng_lsfr,
     output logic [3:0] leds_o 
     //output logic finished
 );

logic init;
always_ff @(posedge clk ) begin : Game_Setup
    
end



endmodule
