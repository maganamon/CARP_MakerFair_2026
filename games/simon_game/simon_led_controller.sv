`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
//Design: simon says LED game
//Engineer: CARP
///////////////////////////////////////////////////////////////////////////////

/*
  NOT FINISHed  comments here
*/

module simon_led_controller(
     input   logic       clk,
     input   logic       tick,
     input   logic       rst,
     input   logic       valid,
     input   logic       win,
     input   logic       push,
     input   logic [3:0] btn_pressed,
     output  logic [3:0] leds_i,
     output  logic [3:0] leds_o 
     //output logic finished
 );

logic [3:0] fifo_o;
logic toggle_pause;

simon_fifo synch_fifo_3x4(
.clk(clk),
.tick(tick),   // cycle_ptr advances once per tick pulse
.rst(rst),
.push(push),
.wr_data(leds_i),
.pop(1'b0),
.rd_data(),
.cycle_data(fifo_o),
.cycle_done_tgl(toggle_pause),
.full(),
.empty()
);

logic [3:0] mux_t_o;

mux2to1 simon_mux_toggle(
.a(fifo_o),
.b(4'b0000),
.sel(toggle_pause),
.f(mux_t_o)
);

logic [3:0] mux_f_o;

mux2to1 simon_mux_fifo_i(
.a(mux_t_o),
.b(btn_pressed),
.sel(valid),
.f(mux_f_o)
);

logic [3:0] mux_led_o;

mux2to1 simon_mux_led_o(
.a(mux_f_o),
.b(4'b1111),
.sel(win),
.f(mux_led_o)
);

assign leds_o = mux_led_o;

endmodule
