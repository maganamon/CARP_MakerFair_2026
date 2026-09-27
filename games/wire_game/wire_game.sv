`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Wire game wrapper (serial number + press handling)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  Wraps wire_game_fsm (the answer checker, unchanged) so it works on the board:

  1. serial_idx: picked from the free-running LFSR on the first clock after
     reset, then held for the whole game. wire_serial_rom turns it into the
     4 characters shown on the 14-segment display.

  2. One press = one check. button_lock's valid stays high while a wire
     button is held (millions of clocks). Fed straight into wire_game_fsm,
     `wrong` would be high on every one of those clocks and lives_manager
     would take all 3 lives from one press. Here the press is turned into a
     1-clock pulse, so each press is checked exactly once.

  3. solved latches: once the right wire is pressed the game stays solved
     (until reset) and further presses are ignored.
     wrong is a 1-clock pulse for lives_manager; the same serial stays up.
*/

module wire_game (
    input  logic       clk,
    input  logic       rst,

    input  logic [2:0] rng,          // 3 bits of lfsr_8bit_rng.output_data
    input  logic [3:0] btn_signal,   // wire_signal from buttons_manager (one-hot)
    input  logic       btn_valid,    // wire_valid  from buttons_manager (level)

    output logic [2:0] serial_idx,   // which of the 8 serial numbers is shown
    output logic       solved,
    output logic       wrong         // 1-clock pulse -> lives_manager
);

    logic started;
    logic valid_d;
    logic press;
    logic fsm_win, fsm_wrong;

    assign press = btn_valid & ~valid_d & started;     // first clock of a press

    wire_game_fsm u_wire_game_fsm (
        .serial_number_idx (serial_idx),
        .btn_pressed       (btn_signal),
        .btn_valid         (press),
        .win               (fsm_win),
        .wrong             (fsm_wrong)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            started    <= 1'b0;
            serial_idx <= 3'd0;
            valid_d    <= 1'b0;
            solved     <= 1'b0;
            wrong      <= 1'b0;
        end else begin
            valid_d <= btn_valid;
            wrong   <= 1'b0;                   // default: no pulse

            if (!started) begin
                serial_idx <= rng;             // pick this game's serial number
                started    <= 1'b1;
            end else if (!solved && press) begin
                if (fsm_win)        solved <= 1'b1;
                else if (fsm_wrong) wrong  <= 1'b1;
            end
        end
    end

endmodule
