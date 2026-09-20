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
    output logic       push_to_fifo,
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
    logic [3:0] answ_bank [2:0];
    logic [3:0] onehot4_o;

bin2_to_onehot4 u_simon_decode(
    .bin_in(rng_lsfr),
    .onehot_out(onehot4_o)
);

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
                push_to_fifo = 1'b0;
                wrong = 0;
                round = 2'd0;
                answ_bank = '0;
                next_state = SETUP;
            end

            SETUP: begin
                push_to_fifo = 1'b1;
                answ_bank[round] = onehot4_o;
                leds_o = answ_bank[round];
                next_state = CHECK;
            end

            ADVANCE: begin
                if (round == 2'b10)
                    next_state = WIN;
                else if (wrong == 0) begin
                    round = round + 1;
                    next_state = SETUP;
                end
                else
                    next_state = NEW_GAME;
            end
            CHECK: begin
                push_to_fifo = 1'b0;
                leds_o = answ_bank[round];
                if (btn_valid) begin
                    if(answ_bank[round] == btn_pressed)
                        next_state = ADVANCE;
                    else
                        next_state = WRONG;
                end
                else
                    next_state = CHECK;
            end
            WIN: begin
                leds_o = 4'b1111;
                next_state = WIN;
            end

            WRONG: begin
                round = 0;
                next_state = NEW_GAME;
                wrong = 1'b1;
            end
            default: 
            next_state = NEW_GAME;
        endcase
    end

    // ------------------------------------------------------------------
    // Output logic
    // ------------------------------------------------------------------
    always_comb begin
        win = (state == WIN);
    end

endmodule
