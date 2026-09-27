`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Button synchronizer + debouncer
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  Mechanical buttons bounce for a few ms when pressed and released. Without
  this, button_lock sees several press/release events per real press, and
  the Simon FSM counts each one as a separate button press.

  - 2 flip-flop synchronizer (buttons are asynchronous to clk)
  - btn_out only changes after the synced input has been stable for
    STABLE_COUNT clocks (1_000_000 @ 100 MHz = 10 ms)
*/

module btn_debounce #(
    parameter int WIDTH        = 4,
    parameter int STABLE_COUNT = 1_000_000
)(
    input  logic             clk,
    input  logic             rst,
    input  logic [WIDTH-1:0] btn_in,
    output logic [WIDTH-1:0] btn_out
);

    localparam int CW = $clog2(STABLE_COUNT);

    logic [WIDTH-1:0] sync0, sync1;
    logic [CW-1:0]    cnt;

    // Synchronizer
    always_ff @(posedge clk) begin
        sync0 <= btn_in;
        sync1 <= sync0;
    end

    // Debounce: accept a new value only after it has been stable long enough
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt     <= '0;
            btn_out <= '0;
        end else if (sync1 == btn_out) begin
            cnt <= '0;                       // nothing changing
        end else if (cnt == CW'(STABLE_COUNT - 1)) begin
            btn_out <= sync1;                // stable long enough: accept
            cnt     <= '0;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule

/*
example:

sync1:       0 1 0 1 0 1 1 1 1 ...
btn_out:     0 0 0 0 0 0 0 0 0 ...

Walkthrough:
sync1 = 1, btn_out = 0  → different → increment cnt
sync1 = 0, btn_out = 0  → match     → reset cnt to 0
sync1 = 1, btn_out = 0  → different → increment cnt
sync1 = 0, btn_out = 0  → match     → reset cnt to 0
sync1 = 1, btn_out = 0  → different → begin counting
sync1 = 1, btn_out = 0  → different → keep counting
sync1 = 1, btn_out = 0  → different → keep counting
*/