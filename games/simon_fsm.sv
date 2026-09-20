`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
//Design: simon says LED game
//Engineer: CARP
///////////////////////////////////////////////////////////////////////////////

/*
  3-round Simon Says.
  Round N shows a sequence of N LED blinks (1s on / 1s off each), then
  waits for the user to press the same N buttons in order. Correct ->
  advance round (append one more random step, replay whole sequence).
  Wrong at any point -> LOSE.
*/

module simon_fsm(
    input  logic       clk,
    input  logic       rst,

    input  logic       tick_1hz,     // shared 1Hz tick from tick_gen
    input  logic [3:0] btn_pressed,  // one-hot from buttons_manager (simon_signal)
    input  logic       btn_valid,    // simon_valid from buttons_manager
    input  logic [1:0] rng_lsfr,     // 2-bit slice of lsfr_8bit_rng.output_data

    output logic [3:0] leds_o,
    output logic       win,
    output logic       wrong
);


    // ------------------------------------------------------------------
    // State encoding
    // ------------------------------------------------------------------
    typedef enum logic [2:0] {
        NEW_GAME,        // waiting for game start
        SETUP,
        ADVANCE,     // correct + more rounds to go -> back to NEW_STEP
        CHECK,       // compare last press against expected step
        WIN,         // correct + round == MAX_ROUNDS -> done
        WRONG         // wrong press -> done
    } state_t;

    state_t state, next_state;

    // ------------------------------------------------------------------
    // Game data
    // ------------------------------------------------------------------
    logic [1:0] round;                     // current round: number of steps in play (1..3)
    logic [1:0] indx;
    logic [1:0] answ_bank [2:0];
    logic [1:0] btn_2bit;

onehot4_to_bin2 u_simon_encode (
    .onehot_in (btn_pressed),
    .bin_out   (btn_2bit)
);

    // TODO: playback blink sub-state (which half of the 1s/1s cycle you're in)
    // TODO: pressed-button one-hot -> 2-bit index decode (needed to compare
    //       btn_pressed against sequence[step_idx], which is stored as 2 bits)

    // ------------------------------------------------------------------
    // State register
    // ------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= NEW_GAME;
        else
            state <= next_state;
    end

    // ------------------------------------------------------------------
    // Next-state logic
    // ------------------------------------------------------------------
    always_comb begin
        next_state = state;

        case (state)
            NEW_GAME: begin
                win <= 0;
                wrong <= 0;
                round <= 2'd0;
                answ_bank <= '0;
                next_state <= SETUP;
            end

            SETUP: begin
                answ_bank[round] = rng_lsfr;
                if (round != 2'd3)
                    next_state <= CHECK;
                else
                    next_state <= WIN;
            end

            ADVANCE: begin
                if (round == 2'b11)
                    next_state = WIN;
                else if (wrong == 0) begin
                    round <= round + 1;
                    next_state = SETUP;
                end
                else
                    next_state = NEW_GAME;
            end
            CHECK: begin
                leds_o = answ_bank[round]
                if (btn_valid) begin
                    if(answ_bank[round] == btn_2bit)
                        next_state <= ADVANCE;
                end
                else
                    next_state = CHECK;
            end
            WIN: begin
                win = 1;
                next_state = WIN;
            end

            WRONG: begin
                round <= 0;
                next_state = NEW_GAME;
                wrong = 1'b1;
            end
            default: next_state = NEW_GAME;
        endcase
    end

    // ------------------------------------------------------------------
    // Output logic
    // ------------------------------------------------------------------
    always_comb begin
        win    = (state == WIN);
        leds_o = {4{win}};

        // TODO: in PLAYBACK, decode sequence[step_idx] (2-bit) to one-hot leds_o,
        //       gated by blink on/off sub-state
    end

endmodule
