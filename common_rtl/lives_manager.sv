`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Shared lives counter (3 lives across ALL games)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  One lives counter for the whole MakerFaire board. Every game has its own
  bit in lose_life; a 1-clock pulse on any bit takes one life.

    lose_life[0] = Simon      (simon_fsm.wrong)
    lose_life[1] = Wire game  (not written yet, tie to 1'b0)
    lose_life[2] = Onboard LED game (not written yet, tie to 1'b0)

    lives   lives_led   Basys3 LEDs (LD15 LD14 LD13)
      3       111          on   on   on
      2       110          on   on   off
      1       100          on   off  off
      0       000          off  off  off   -> game_over = 1

  If two games signal a mistake on the exact same clock, only one life is
  taken (practically never happens with human button presses).

  game_over is a flip-flop output (no glitches), so it is safe to OR into
  each game's reset to stop every game. Only rst gives the lives back.
*/

module lives_manager #(
    parameter int NUM_GAMES = 3
)(
    input  logic                 clk,
    input  logic                 rst,
    input  logic [NUM_GAMES-1:0] lose_life,  // 1-clock pulse per mistake, one bit per game
    output logic [2:0]           lives_led,  // [2]=LD15 (leftmost), [1]=LD14, [0]=LD13
    output logic                 game_over
);

    logic [1:0] lives;
    logic       any_mistake;

    assign any_mistake = |lose_life;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            lives     <= 2'd3;
            game_over <= 1'b0;
        end else if (any_mistake && lives != 2'd0) begin
            lives <= lives - 1'b1;
            if (lives == 2'd1)
                game_over <= 1'b1;        // that was the last life
        end
    end

    always_comb begin
        case (lives)
            2'd3:    lives_led = 3'b111;
            2'd2:    lives_led = 3'b110;
            2'd1:    lives_led = 3'b100;
            default: lives_led = 3'b000;
        endcase
    end

endmodule

/* 
|lose_life explanation:
lose_life = 3'b000;  // no game reported a mistake
any_mistake = 1'b0;

lose_life = 3'b001;  // Simon reported a mistake
any_mistake = 1'b1;

lose_life = 3'b010;  // Wire game reported a mistake
any_mistake = 1'b1;

lose_life = 3'b100;  // LED game reported a mistake
any_mistake = 1'b1;

lose_life = 3'b101;  // Simon and LED both reported one
any_mistake = 1'b1;
*/
