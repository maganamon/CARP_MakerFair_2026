`timescale 1ns / 1ps

// Top level: reads simon/wire button sets, enforces the
// "one button per set" lock via buttons_manager, then drives
// an LED vector per set via btn_to_led. Also drives a countdown
// timer on the 7-segment display.
module top_level_MakerFair (
    input  logic       clk,
    input  logic       rst,

    input  logic [3:0] simon_btns,
    input  logic [3:0] wire_btns,

    output logic [3:0] simon_led,

    output logic [7:0] CATHODES,
    output logic [3:0] ANODES,
    output logic       out_of_time
);

logic [3:0] simon_signal, wire_signal;
logic       simon_valid, wire_valid;

buttons_manager u_buttons_manager (
    .clk          (clk),
    .rst          (rst),
    .simon_btns   (simon_btns),
    .wire_btns    (wire_btns),
    .simon_signal (simon_signal),
    .wire_signal  (wire_signal),
    .simon_valid  (simon_valid),
    .wire_valid   (wire_valid)
);

    btn_to_led u_simon_led (
        .btn_pressed (simon_sel),
        .valid       (simon_valid),
        .out_led     (simon_led)
    );

    // 1Hz tick for the countdown timer
    logic tick_1hz;

    tick_gen #(
        .MAX_COUNT(100_000_000)
    ) u_tick_gen (
        .clk  (clk),
        .rst  (rst),
        .tick (tick_1hz)
    );

    // Countdown timer (05:00 -> 00:00)
    logic [15:0] countdown_data;
    logic        countdown_mode;

    CountDown_7seg u_countdown (
        .CLK         (clk),
        .RST         (rst),
        .TICK        (tick_1hz),
        .DATA_OUT    (countdown_data),
        .MODE_OUT    (countdown_mode),
        .OUT_OF_TIME (out_of_time)
    );

    // 7-segment display of the countdown
    SevSegDisp u_sevseg (
        .CLK      (clk),
        .MODE     (countdown_mode),
        .DATA_IN  (countdown_data),
        .CATHODES (CATHODES),
        .ANODES   (ANODES)
    );

endmodule