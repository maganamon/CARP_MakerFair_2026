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

    input logic        timer_sw

    output logic [3:0] simon_led,
    output logic [2:0] lives_led,     // LD15, LD14, LD13: shared lives for ALL games
    output logic       wire_led,

    output logic [7:0] seg,
    output logic [3:0] an,

    input  logic [7:0] sw,            // SW0-SW7: onboard game answer
    input  logic       btnU,          // top button: submit
    output logic [7:0] onboard_led,   // LD0-LD7: the pattern to work from

    // i2c signals
    inout  wire        disp_scl,      // HT16K33 SCL
    inout  wire        disp_sda,      // HT16K33 SDA

    // VGA
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue,
    output logic       Hsync,
    output logic       Vsync
);

    logic out_of_time;

    // ============================================================
    // Signals shared between sections (declared before first use)
    // ============================================================

    // wire game
    logic [3:0]  wire_btns_db;
    logic [3:0]  wire_signal;
    logic        wire_valid;
    logic [2:0]  wire_serial;
    logic        wire_solved;
    logic        wire_wrong;
    logic [3:0]  wire_cut;
    logic [15:0] ser0, ser1, ser2, ser3;

    // onboard game
    logic        btnU_db;
    logic        onboard_solved;
    logic        onboard_wrong;

    // lives + end of game
    logic        simon_wrong;
    logic [1:0]  strikes;         // lives lost, sets the Simon color rules
    logic        game_over;       // out of lives
    logic        bomb_won;        // everything solved in time
    logic        bomb_lost;       // out of time or out of lives
    logic        games_rst;

    assign wire_led = wire_solved;


    // ============================================================
    // Debounce the Simon and wire buttons (sync + 10 ms stable)
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

    btn_debounce #(
        .WIDTH        (4),
        .STABLE_COUNT (DEBOUNCE_COUNT)
    ) u_wire_debounce (
        .clk     (clk),
        .rst     (rst),
        .btn_in  (wire_btns),
        .btn_out (wire_btns_db)
    );


    // ============================================================
    // Button Manager
    // ============================================================

    logic [3:0] simon_signal;
    logic       simon_valid;

    buttons_manager u_buttons_manager (
        .clk          (clk),
        .rst          (rst),

        .simon_btns   (simon_btns_db),
        .wire_btns    (wire_btns_db),

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
        .SHORT_TIME  (timer_sw_s1),

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
    logic [7:0] rng_data;           // Simon [1:0], wire [4:2], onboard all 8
    /* verilator lint_on UNUSEDSIGNAL */

    lfsr_8bit_rng u_rng (
        .clk         (clk),
        .rst         (1'b0),          // free-running: never reset, so every game starts differently
        .output_data (rng_data)
    );


    // ============================================================
    // Press pulse for the Simon FSM + 1-tick LED echo
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


    // ============================================================
    // End of the game: won (all solved) / lost (time or lives)
    // ============================================================

    logic simon_win;

    bomb_status u_bomb (
        .clk          (clk),
        .rst          (rst),
        .out_of_time  (out_of_time),
        .out_of_lives (game_over),
        .simon_done   (simon_win),
        .wire_done    (wire_solved),
        .onboard_done (onboard_solved),
        .won          (bomb_won),
        .lost         (bomb_lost)
    );

    // Lost (out of time OR out of lives) -> hold EVERY game in reset
    // until rst is pressed. bomb_lost comes from a flip-flop, so it is
    // safe to use as a reset.
    assign games_rst = rst | bomb_lost;

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

    simon_fsm u_simon_fsm (
        .clk          (clk),
        .rst          (simon_rst),

        .tick_1hz     (tick_1hz),

        .btn_pressed  (simon_answer),     // button translated to the LED color it answers
        .btn_valid    (simon_press),      // 1-clock pulse per press

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
        .rst             (simon_rst | fifo_clr),

        .valid           (echo_on),
        .win             (simon_win),
        .push            (simon_push),

        .btn_pressed     (echo_led),

        .fifo_write_data (simon_fsm_led),

        .leds_o          (simon_led)
    );


    // ============================================================
    // Wire game
    // ============================================================

    wire_game u_wire_game (
        .clk        (clk),
        .rst        (games_rst),          // stops when the bomb is lost
        .rng        (rng_data[4:2]),      // different bits than Simon's [1:0]
        .btn_signal (wire_signal),
        .btn_valid  (wire_valid),
        .serial_idx (wire_serial),
        .solved     (wire_solved),
        .wrong      (wire_wrong),         // takes a shared life
        .cut        (wire_cut)            // which wires are cut (VGA)
    );

    wire_serial_rom u_wire_serial (
        .serial_idx (wire_serial),
        .digit0     (ser0),
        .digit1     (ser1),
        .digit2     (ser2),
        .digit3     (ser3)
    );


    // ============================================================
    // 14-segment display (HT16K33 over I2C): shows the serial number
    // ============================================================

    ht16k33_driver #(
        .CLK_HZ         (100_000_000),
        .I2C_HZ         (100_000),
        .I2C_ADDR       (7'h70),
        .BRIGHTNESS     (4'hF),
        .POWERUP_CYCLES (1_000_000)       // 10 ms
    ) u_display (
        .clk       (clk),
        .rst       (rst),
        .digit0    (ser0),
        .digit1    (ser1),
        .digit2    (ser2),
        .digit3    (ser3),
        .scl       (disp_scl),
        .sda       (disp_sda),
        .ack_error ()
    );


    // ============================================================
    // Onboard LED game
    // ============================================================

    btn_debounce #(
        .WIDTH        (1),
        .STABLE_COUNT (DEBOUNCE_COUNT)
    ) u_btnU_debounce (
        .clk     (clk),
        .rst     (rst),
        .btn_in  (btnU),
        .btn_out (btnU_db)
    );

    onboard_game u_onboard_game (
        .clk         (clk),
        .rst         (games_rst),         // stops when the bomb is lost
        .rng         (rng_data),
        .serial_idx  (wire_serial),       // same serial as on the display
        .sw          (sw[7:0]),
        .submit      (btnU_db),           // btnU after btn_debounce
        .led         (onboard_led),       // LD0-LD7
        .answ_random (),                  // not needed any more
        .solved      (onboard_solved),
        .wrong       (onboard_wrong)      // shared lives
    );


    // ============================================================
    // VGA (640x480): wire panel; all green on win, all red on loss
    // ============================================================

    vga_wires u_vga (
        .clk       (clk),
        .cut       (wire_cut),
        .win       (bomb_won),
        .lose      (bomb_lost),
        .vga_r     (vgaRed),
        .vga_g     (vgaGreen),
        .vga_b     (vgaBlue),
        .vga_hsync (Hsync),
        .vga_vsync (Vsync)
    );

endmodule