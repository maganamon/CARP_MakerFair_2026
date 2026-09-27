`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Onboard LED bit-operation game (8 bits)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  1. Sample the LFSR once for an 8-bit pattern -> shown on LD0-LD7.
  2. The operation comes from the serial number on the 14-segment display
     (serial_idx from the wire game), using two questions from the manual:

       Q1: does the serial start with a VOWEL?
       Q2: do its two numbers count DOWN (e.g. B7K2: 7 -> 2) or UP?

                      numbers count DOWN          numbers count UP
       vowel          E5N3, O7P1: XOR 1100_1100   A4M6, U2X8: XOR 0011_0011
       consonant      B7K2, Z9D2: flip all bits   T3R8, C1L4: AND 1100_1100

       answ_random   player must enter on SW0-SW7
         2'b00       pattern XOR 1100_1100
         2'b01       pattern XOR 0011_0011
         2'b10       ~pattern            (flip every bit)
         2'b11       pattern AND 1100_1100

     answ_random is still an output (handy for debug / a hint display).
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
    input  logic [2:0] serial_idx,    // serial on the display (wire_game.serial_idx)
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
        GEN_OP,         // wait 8 clocks, look up answ_random from the serial
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
    // Serial number -> operation (vowel? x numbers count down/up?)
    //   idx serial  vowel  numbers  op
    //    0  B7K2    no     down     10 flip
    //    1  A4M6    yes    up       01 XOR 0011_0011
    //    2  T3R8    no     up       11 AND 1100_1100
    //    3  E5N3    yes    down     00 XOR 1100_1100
    //    4  C1L4    no     up       11 AND 1100_1100
    //    5  O7P1    yes    down     00 XOR 1100_1100
    //    6  Z9D2    no     down     10 flip
    //    7  U2X8    yes    up       01 XOR 0011_0011
    // ------------------------------------------------------------------
    function automatic logic [1:0] op_for_serial(input logic [2:0] idx);
        case (idx)
            3'd0:    op_for_serial = 2'b10;
            3'd1:    op_for_serial = 2'b01;
            3'd2:    op_for_serial = 2'b11;
            3'd3:    op_for_serial = 2'b00;
            3'd4:    op_for_serial = 2'b11;
            3'd5:    op_for_serial = 2'b00;
            3'd6:    op_for_serial = 2'b10;
            default: op_for_serial = 2'b01;
        endcase
    endfunction

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
                    // wait 8 clocks so the wire game has picked its serial
                    if (wait_cnt == 3'd7) begin
                        answ_random <= op_for_serial(serial_idx);
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