`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Design: MakerFaire Top Level
// Engineer: CARP
//////////////////////////////////////////////////////////////////////////////////

module top_level_MakerFair #(
    // Board values. The testbench passes smaller ones to simulate fast.
    parameter int TICK_COUNT     = 100_000_000,   // clocks per 1 Hz tick
    parameter int DEBOUNCE_COUNT = 1_000_000      // 10 ms @ 100 MHz
)(

    input  logic       clk,
    input  logic       rst,

    input  logic [3:0] simon_btns,
    input  logic [3:0] wire_btns,

    output logic [3:0] simon_led,
    output logic [2:0] lives_led,     // LD15, LD14, LD13: shared lives for ALL games

    output logic [7:0] seg,
    output logic [3:0] an,

    output logic       out_of_time
);

    // ============================================================
    // NEW: Debounce the Simon buttons (sync + 10 ms stable)
    // ============================================================

    logic [3:0] simon_btns_db;

    btn_debounce #(
        .WIDTH        (4),
        .STABLE_COUNT (DEBOUNCE_COUNT)
    ) u_simon_debounce (
        .clk     (clk),
        .rst     (rst),
        .btn_in  (simon_btns),
        .btn_out (simon_btns_db)
    );


    // ============================================================
    // Button Manager Signals
    // ============================================================

    logic [3:0] simon_signal;
    logic simon_valid;

    // Wire game not written yet: these are unused until then
    /* verilator lint_off UNUSEDSIGNAL */
    logic [3:0] wire_signal;
    logic wire_valid;
    /* verilator lint_on UNUSEDSIGNAL */


    // ============================================================
    // Button Manager
    // ============================================================

    buttons_manager u_buttons_manager (
        .clk          (clk),
        .rst          (rst),

        .simon_btns   (simon_btns_db),    // was simon_btns
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
        .MAX_COUNT(TICK_COUNT)
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

    /* verilator lint_off UNUSEDSIGNAL */
    logic [7:0] rng_data;           // only [1:0] used by Simon for now
    /* verilator lint_on UNUSEDSIGNAL */

    lfsr_8bit_rng u_rng (
        .clk         (clk),
        .rst         (1'b0),          // free-running: never reset, so every game starts differently
        .output_data (rng_data)
    );


    // ============================================================
    // NEW: Press pulse for the FSM + 1-tick LED echo
    // ============================================================

    logic       simon_press;      // 1 clock per press
    logic       echo_on;
    logic [3:0] echo_led;

    simon_press_echo u_simon_press_echo (
        .clk         (clk),
        .rst         (rst),
        .tick        (tick_1hz),
        .valid       (simon_valid),
        .btn         (simon_signal),
        .press_pulse (simon_press),
        .echo_on     (echo_on),
        .echo_led    (echo_led)
    );


    // ============================================================
    // Shared lives (3 across ALL games) -> left 3 onboard LEDs
    // ============================================================

    logic simon_wrong;
    logic [1:0] strikes;    // lives lost, sets the Simon color rules
    logic wire_wrong;       // TODO: drive from the wire game's checker
    logic onboard_wrong;    // TODO: drive from the onboard LED game
    logic game_over;

    assign wire_wrong    = 1'b0;
    assign onboard_wrong = 1'b0;

    lives_manager #(
        .NUM_GAMES (3)
    ) u_lives (
        .clk       (clk),
        .rst       (rst),
        .lose_life ({onboard_wrong, wire_wrong, simon_wrong}),
        .lives_led (lives_led),
        .strikes   (strikes),
        .game_over (game_over)
    );

    // Out of lives -> hold EVERY game in reset until rst is pressed.
    // Use games_rst as the reset of each game (wire, onboard) when added.
    logic games_rst;
    assign games_rst = rst | game_over;

    logic simon_rst;
    assign simon_rst = games_rst;

    // After a wrong press the FSM starts a new sequence, so the FIFO
    // must be emptied too (otherwise it keeps playing the old one).
    // Registered so the FIFO's async reset comes from a flip-flop.
    logic fifo_clr;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) fifo_clr <= 1'b0;
        else     fifo_clr <= simon_wrong;
    end


    // ============================================================
    // Simon color rules: which button answers which LED depends on
    // strikes (lives lost). Translates the pressed button into the
    // LED color it answers, so simon_fsm itself does not change.
    // ============================================================

    logic [3:0] simon_answer;

    simon_color_map u_simon_color_map (
        .strikes   (strikes),
        .btn_in    (simon_signal),
        .led_equiv (simon_answer)
    );


    // ============================================================
    // Simon FSM
    // ============================================================

    logic [3:0] simon_fsm_led;
    logic       simon_push;
    logic       simon_win;

    simon_fsm u_simon_fsm (
        .clk          (clk),
        .rst          (simon_rst),        // was rst

        .tick_1hz     (tick_1hz),

        .btn_pressed  (simon_answer),     // button translated to the LED color it answers
        .btn_valid    (simon_press),      // was simon_valid (level, not a pulse)

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
        .rst             (simon_rst | fifo_clr),   // was rst

        .valid           (echo_on),                // was simon_valid
        .win             (simon_win),
        .push            (simon_push),

        .btn_pressed     (echo_led),               // was simon_signal

        .fifo_write_data (simon_fsm_led),

        .leds_o          (simon_led)
    );

endmodule
