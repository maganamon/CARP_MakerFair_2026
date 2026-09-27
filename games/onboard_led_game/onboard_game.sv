`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Onboard LED bit-operation game (8 bits)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  1. Sample the LFSR once for an 8-bit pattern -> shown on LD0-LD7.
  2. Wait 8 clocks (so the LFSR has shifted in all-new bits) and sample it
     again for a 2-bit operation code, answ_random:

       answ_random   player must enter on SW0-SW7
         2'b00       pattern XOR 1100_1100
         2'b01       pattern XOR 0011_0011
         2'b10       ~pattern            (flip every bit)
         2'b11       pattern AND 1100_1100

     answ_random is an output so a hint display (14-segment, later) can
     show which operation to do.
  3. Player sets the switches and presses btnU (submit):
       correct -> solved = 1, LD0-LD7 all on, game done until reset
       wrong   -> wrong pulses for 1 clock (take a life), same puzzle stays

  Inputs:
    sw     : raw switches, synchronized in here
    submit : btnU AFTER debouncing (a level); the press edge is found here
*/

module onboard_game (
    input  logic       clk,
    input  logic       rst,

    input  logic [7:0] rng,           // lsfr_8bit_rng.output_data
    input  logic [7:0] sw,            // SW0-SW7
    input  logic       submit,        // debounced btnU (level)

    output logic [7:0] led,           // LD0-LD7
    output logic [1:0] answ_random,   // which operation (for the hint display)
    output logic       solved,
    output logic       wrong          // 1-clock pulse -> lives_manager
);

    localparam logic [7:0] MASK_A = 8'b1100_1100;
    localparam logic [7:0] MASK_B = 8'b0011_0011;

    typedef enum logic [1:0] {
        GEN_PATTERN,    // sample the LFSR for the LED pattern
        GEN_OP,         // wait 8 clocks, sample the LFSR for answ_random
        PLAY,           // wait for submit
        SOLVED          // correct answer entered
    } state_t;

    state_t     state;
    logic [7:0] pattern;
    logic [2:0] wait_cnt;
    logic [7:0] expected;

    // ------------------------------------------------------------------
    // Switch synchronizer + submit edge detect
    // ------------------------------------------------------------------
    logic [7:0] sw_s0, sw_s1;
    logic       submit_d;
    logic       submit_pulse;

    always_ff @(posedge clk) begin
        sw_s0 <= sw;
        sw_s1 <= sw_s0;
    end

    assign submit_pulse = submit & ~submit_d;

    // ------------------------------------------------------------------
    // Correct answer for the current puzzle
    // ------------------------------------------------------------------
    always_comb begin
        case (answ_random)
            2'b00:   expected = pattern ^ MASK_A;
            2'b01:   expected = pattern ^ MASK_B;
            2'b10:   expected = ~pattern;
            2'b11:   expected = pattern & MASK_A;
            default: expected = pattern & MASK_A;
        endcase
    end

    // ------------------------------------------------------------------
    // Game state
    // ------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= GEN_PATTERN;
            pattern     <= 8'h00;
            answ_random <= 2'b00;
            wait_cnt    <= '0;
            submit_d    <= 1'b0;
            wrong       <= 1'b0;
        end else begin
            submit_d <= submit;
            wrong    <= 1'b0;                  // default: no pulse

            case (state)
                GEN_PATTERN: begin
                    pattern  <= rng;
                    wait_cnt <= '0;
                    state    <= GEN_OP;
                end

                GEN_OP: begin
                    wait_cnt <= wait_cnt + 1'b1;
                    if (wait_cnt == 3'd7) begin
                        answ_random <= rng[1:0];
                        state       <= PLAY;
                    end
                end

                PLAY: begin
                    if (submit_pulse) begin
                        if (sw_s1 == expected)
                            state <= SOLVED;
                        else
                            wrong <= 1'b1;     // lose a life, keep the puzzle
                    end
                end

                SOLVED: ;                      // stay until reset

                default: state <= GEN_PATTERN;
            endcase
        end
    end

    assign solved = (state == SOLVED);

    always_comb begin
        case (state)
            PLAY:    led = pattern;
            SOLVED:  led = 8'hFF;
            default: led = 8'h00;
        endcase
    end

endmodule
