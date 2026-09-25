`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Design: MakerFaire Top Level
// Engineer: CARP
//////////////////////////////////////////////////////////////////////////////////

module top_level_MakerFair (

    input  logic       clk,
    input  logic       rst,

    input  logic [3:0] simon_btns,
    input  logic [3:0] wire_btns,

    output logic [3:0] simon_led,

    output logic [7:0] seg,
    output logic [3:0] an,

    output logic       out_of_time
);

    // ============================================================
    // Button Manager Signals
    // ============================================================

    logic [3:0] simon_signal;
    logic [3:0] wire_signal;

    logic simon_valid;
    logic wire_valid;


    // ============================================================
    // Button Manager
    // ============================================================

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


    // ============================================================
    // 1 Hz Tick Generator
    // ============================================================

    logic tick_1hz;

    tick_gen #(
        .MAX_COUNT(100_000_000)
    ) u_tick_gen (
        .clk  (clk),
        .rst  (rst),
        .tick (tick_1hz)
    );


    // ============================================================
    // Countdown Timer
    // ============================================================

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


    // ============================================================
    // Seven Segment Display
    // ============================================================

    SevSegDisp u_sevseg (
        .CLK      (clk),
        .MODE     (countdown_mode),
        .DATA_IN  (countdown_data),

        .CATHODES (seg),
        .ANODES   (an)
    );

// ============================================================
// LFSR
// ============================================================

logic [7:0] rng_data;

lsfr_8bit_rng u_rng (
    .clk         (clk),
    .rst         (rst),
    .output_data (rng_data)
);


// ============================================================
// Simon FSM
// ============================================================

logic [3:0] simon_fsm_led;
logic       simon_push;
logic       simon_win;
logic       simon_wrong;

simon_fsm u_simon_fsm (
    .clk          (clk),
    .rst          (rst),

    .tick_1hz     (tick_1hz),

    .btn_pressed  (simon_signal),
    .btn_valid    (simon_valid),

    .rng_lsfr     (rng_data[1:0]),

    .leds_o       (simon_fsm_led),
    .push_to_fifo (simon_push),
    .win          (simon_win),
    .wrong        (simon_wrong)
);


// ============================================================
// Simon LED Controller
// ============================================================

simon_led_controller u_simon_led_controller (
    .clk             (clk),
    .tick            (tick_1hz),
    .rst             (rst),

    .valid           (simon_valid),
    .win             (simon_win),
    .push            (simon_push),

    .btn_pressed     (simon_signal),

    .fifo_write_data (simon_fsm_led),

    .leds_o          (simon_led)
);

endmodule