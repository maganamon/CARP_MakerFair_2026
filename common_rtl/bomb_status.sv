`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Overall result of the bomb (won / lost)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  won  : all three modules solved before time ran out / lives ran out
  lost : out of time OR out of lives, before everything was solved

  Both are latched: once the game is decided it stays decided until rst.
  That matters because the countdown keeps running after a win and would
  otherwise reach 00:00 and turn the screen red; after a win, out_of_time
  is ignored. If everything gets solved on the very same clock that time
  runs out, the player wins.

  lost is a flip-flop output, so it is safe to use in the games' reset
  (games_rst = rst | lost) to stop every game.
*/

module bomb_status (
    input  logic clk,
    input  logic rst,

    input  logic out_of_time,     // CountDown_7seg: timer reached 00:00
    input  logic out_of_lives,    // lives_manager.game_over

    input  logic simon_done,      // simon_fsm.win
    input  logic wire_done,       // wire_game.solved
    input  logic onboard_done,    // onboard_game.solved

    output logic won,             // -> VGA: whole screen green
    output logic lost             // -> VGA: whole screen red
);

    logic all_done;
    assign all_done = simon_done & wire_done & onboard_done;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            won  <= 1'b0;
            lost <= 1'b0;
        end else if (!won && !lost) begin          // decide only once
            if (all_done)
                won  <= 1'b1;
            else if (out_of_time || out_of_lives)
                lost <= 1'b1;
        end
    end

endmodule