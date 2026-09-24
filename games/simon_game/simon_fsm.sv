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

  The LED controller's FIFO plays the sequence back; this FSM just waits
  in PLAY for 2 ticks per step (1s on + 1s off) before taking button presses.
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
        NEW_GAME,    // clear round counter, start a game
        SETUP,       // store a new random step in answ_bank[round]
        ADVANCE,     // correct: more rounds -> SETUP, last round -> WIN
        CHECK,       // compare press against expected step
        WIN,         // all rounds correct -> stay here until reset
        WRONG,       // wrong press -> back to NEW_GAME
        PLAY         // NEW: wait while the sequence plays (2 ticks per step)
    } state_t;

    state_t state, next_state;

    // ------------------------------------------------------------------
    // Game data
    // ------------------------------------------------------------------
    logic [1:0] round;                  // index of current step (0..2)
    logic [3:0] answ_bank [2:0];        // stored steps
    logic [3:0] onehot4_o;
    logic [1:0] idx;                    // NEW: which step the player must press next
    logic [2:0] ticks;                  // NEW: ticks waited in PLAY

    bin2_to_onehot4 u_simon_decode(
        .bin_in    (rng_lsfr),
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
    // Game data registers (everything that must be remembered lives here)
    // ------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            round     <= '0;
            idx       <= '0;
            ticks     <= '0;
            answ_bank[0] <= 4'b0000;
            answ_bank[1] <= 4'b0000;
            answ_bank[2] <= 4'b0000;
        end else begin
            case (state)
                NEW_GAME: round <= '0;
                SETUP: begin
                    answ_bank[round] <= onehot4_o;
                    idx   <= '0;                    // NEW
                    ticks <= '0;                    // NEW
                end
                PLAY:     if (tick_1hz) ticks <= ticks + 1'b1;          // NEW
                CHECK:    if (btn_valid && btn_pressed == answ_bank[idx] && idx != round)
                              idx <= idx + 1'b1;                        // NEW: next step
                ADVANCE:  if (round != 2'd2) round <= round + 1'b1;
                default:  ;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Next-state + output logic (no storage: every output has a default)
    // ------------------------------------------------------------------
    always_comb begin
        next_state   = state;
        push_to_fifo = 1'b0;
        wrong        = 1'b0;
        leds_o       = answ_bank[round];

        case (state)
            NEW_GAME: next_state = SETUP;

            SETUP: begin
                push_to_fifo = 1'b1;
                leds_o       = onehot4_o;   // new step (stored at end of this cycle)
                next_state   = PLAY;          // was CHECK
            end

            PLAY: begin                                     // NEW
                // round+1 steps x 2 ticks each; {round,1'b1} = 2*round+1
                if (tick_1hz && ticks == {round, 1'b1})
                    next_state = CHECK;
            end

            CHECK: begin
                if (btn_valid) begin
                    if (btn_pressed != answ_bank[idx])   // was answ_bank[round]
                        next_state = WRONG;
                    else if (idx == round)               // NEW: last step of this round
                        next_state = ADVANCE;
                end
            end

            ADVANCE: begin
                if (round == 2'd2)
                    next_state = WIN;
                else
                    next_state = SETUP;
            end

            WIN: leds_o = 4'b1111;

            WRONG: begin
                wrong      = 1'b1;
                next_state = NEW_GAME;
            end

            default: next_state = NEW_GAME;
        endcase
    end

    assign win = (state == WIN);

endmodule
