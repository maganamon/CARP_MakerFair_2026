`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Design: Simon Says LED Controller
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

module simon_led_controller (

    input  logic       clk,
    input  logic       tick,
    input  logic       rst,

    input  logic       valid,
    input  logic       win,
    input  logic       push,

    // One-hot user button
    input  logic [3:0] btn_pressed,

    // New random sequence value produced by FSM
    input  logic [3:0] fifo_write_data,

    output logic [3:0] leds_o
);

    logic [3:0] fifo_o;
    logic       toggle_pause;


    // ============================================================
    // Simon sequence FIFO
    // ============================================================

    sync_fifo_3x4 u_simon_fifo (
        .clk            (clk),
        .tick           (tick),
        .rst            (rst),

        .push           (push),
        .wr_data        (fifo_write_data),

        .pop            (1'b0),
        .rd_data        (),

        .cycle_data     (fifo_o),
        .cycle_done_tgl (toggle_pause),

        .full           (),
        .empty          ()
    );


    // ============================================================
    // LED playback ON/OFF mux
    // ============================================================

    logic [3:0] mux_t_o;

    mux2to1 u_simon_mux_toggle (
        .a   (fifo_o),
        .b   (4'b0000),
        .sel (toggle_pause),
        .f   (mux_t_o)
    );


    // ============================================================
    // During user input, display pressed button
    // ============================================================

    logic [3:0] mux_f_o;

    mux2to1 u_simon_mux_button (
        .a   (mux_t_o),
        .b   (btn_pressed),
        .sel (valid),
        .f   (mux_f_o)
    );


    // ============================================================
    // Win condition: all LEDs on
    // ============================================================

    logic [3:0] mux_led_o;

    mux2to1 u_simon_mux_win (
        .a   (mux_f_o),
        .b   (4'b1111),
        .sel (win),
        .f   (mux_led_o)
    );


    assign leds_o = mux_led_o;

endmodule
