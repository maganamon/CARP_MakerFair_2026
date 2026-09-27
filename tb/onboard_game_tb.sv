`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Testbench: onboard_game (8-bit LED bit-operation game)
//
// Black-box: gives the game a serial number (as the wire game would), reads
// the LED pattern, works out the answer with its OWN copy of the manual rule
// (vowel? x numbers count down/up?) and drives sw / submit like a player.
//
// Tests
//   T1  reset: LEDs off while generating, then a pattern, not solved
//   T2  many puzzles: answ_random matches the manual rule for the serial;
//       wrong answer -> 1 wrong pulse, puzzle unchanged;
//       right answer -> solved, LEDs all on, no more wrong pulses
//   T3  all 8 serials and all 4 operations show up across the puzzles
//   T4  holding submit counts once; changing switches alone does nothing
////////////////////////////////////////////////////////////////////////////////

/* verilator lint_off BLKSEQ */
module onboard_game_tb;

    localparam int CLK_PERIOD = 10;
    localparam int NPUZZLES   = 40;

    logic       clk = 1'b0;
    logic       rst;
    logic [7:0] rng;
    logic [7:0] sw;
    logic       submit;
    logic [2:0] serial;          // stands in for wire_game.serial_idx

    logic [7:0] led;
    logic [1:0] answ_random;
    logic       solved;
    logic       wrong;

    onboard_game dut (
        .clk         (clk),
        .rst         (rst),
        .rng         (rng),
        .serial_idx  (serial),
        .sw          (sw),
        .submit      (submit),
        .led         (led),
        .answ_random (answ_random),
        .solved      (solved),
        .wrong       (wrong)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Free-running random source (stands in for the LFSR)
    always @(negedge clk) rng <= 8'($urandom);

    // Count wrong pulses
    int wrong_cnt = 0;
    always @(posedge clk) if (wrong === 1'b1) wrong_cnt = wrong_cnt + 1;

    // Reference model: the manual rule
    //   vowel + count down -> 00 XOR 1100_1100   vowel + count up -> 01 XOR 0011_0011
    //   consonant + down   -> 10 flip            consonant + up   -> 11 AND 1100_1100
    function automatic string serial_name(input logic [2:0] i);
        case (i)
            3'd0: serial_name = "B7K2";  3'd1: serial_name = "A4M6";
            3'd2: serial_name = "T3R8";  3'd3: serial_name = "E5N3";
            3'd4: serial_name = "C1L4";  3'd5: serial_name = "O7P1";
            3'd6: serial_name = "Z9D2";  default: serial_name = "U2X8";
        endcase
    endfunction

    function automatic logic [1:0] ref_op(input logic [2:0] i);
        bit vowel, down;
        case (i)                          // read straight off the serial text
            3'd0: begin vowel = 0; down = 1; end   // B7K2  7 > 2
            3'd1: begin vowel = 1; down = 0; end   // A4M6  4 < 6
            3'd2: begin vowel = 0; down = 0; end   // T3R8  3 < 8
            3'd3: begin vowel = 1; down = 1; end   // E5N3  5 > 3
            3'd4: begin vowel = 0; down = 0; end   // C1L4  1 < 4
            3'd5: begin vowel = 1; down = 1; end   // O7P1  7 > 1
            3'd6: begin vowel = 0; down = 1; end   // Z9D2  9 > 2
            default: begin vowel = 1; down = 0; end // U2X8 2 < 8
        endcase
        if (vowel) ref_op = down ? 2'b00 : 2'b01;
        else       ref_op = down ? 2'b10 : 2'b11;
    endfunction

    function automatic logic [7:0] ref_answer(input logic [7:0] p, input logic [1:0] op);
        case (op)
            2'b00:   ref_answer = p ^ 8'b1100_1100;
            2'b01:   ref_answer = p ^ 8'b0011_0011;
            2'b10:   ref_answer = ~p;
            default: ref_answer = p & 8'b1100_1100;
        endcase
    endfunction

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    int n_pass = 0, n_fail = 0;

    task automatic check(input bit cond, input string msg);
        if (cond) begin
            n_pass++;
        end else begin
            n_fail++;
            $display("[FAIL] %0t  %s   (led=%b op=%b solved=%b)", $time, msg, led, answ_random, solved);
        end
    endtask

    task automatic reset_game(input logic [2:0] ser);
        @(negedge clk);
        rst = 1'b1; submit = 1'b0; sw = 8'h00;
        serial = ser;
        repeat (3) @(negedge clk);
        rst = 1'b0;
        repeat (15) @(negedge clk);    // pattern + 8 clocks + op
    endtask

    // Set switches, wait for the synchronizer, press and release submit
    task automatic enter(input logic [7:0] val, input int hold);
        @(negedge clk) sw = val;
        repeat (4) @(negedge clk);
        submit = 1'b1;
        repeat (hold) @(negedge clk);
        submit = 1'b0;
        repeat (4) @(negedge clk);
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    logic [7:0] pat, ans;
    logic [1:0] op;
    logic [2:0] ser;
    int         w0, p;
    bit         seen [4];
    bit         seen_ser [8];

    initial begin
        $dumpfile("onboard_game_tb.vcd");
        $dumpvars(0, onboard_game_tb);

        rst = 1'b1; submit = 1'b0; sw = 8'h00; serial = 3'd0;
        for (int i = 0; i < 4; i++) seen[i] = 0;
        for (int i = 0; i < 8; i++) seen_ser[i] = 0;

        // ---------------- T1: reset ----------------
        $display("\n==== T1: reset ====");
        repeat (3) @(negedge clk);
        check(led === 8'h00 && solved === 1'b0, "T1 LEDs off and not solved during reset");
        rst = 1'b0;
        @(negedge clk);
        check(led === 8'h00, "T1 LEDs off while the puzzle is generated");
        repeat (15) @(negedge clk);
        check(solved === 1'b0, "T1 not solved after the puzzle appears");
        $display("[INFO] first puzzle: led=%b op=%b", led, answ_random);

        // ---------------- T2 + T3: many puzzles ----------------
        $display("\n==== T2/T3: %0d puzzles, wrong then right ====", NPUZZLES);
        for (p = 0; p < NPUZZLES; p++) begin
            ser = 3'(p % 8);                 // every serial 5 times
            reset_game(ser);
            pat = led;
            op  = ref_op(ser);
            ans = ref_answer(pat, op);
            seen[op]      = 1;
            seen_ser[ser] = 1;
            check(answ_random === op,
                  $sformatf("T2 puzzle %0d: serial %s -> op %b (DUT says %b)",
                            p, serial_name(ser), op, answ_random));

            // wrong answer first (flip one bit)
            w0 = wrong_cnt;
            enter(ans ^ 8'b0000_0001, 1);
            check(wrong_cnt == w0 + 1,
                  $sformatf("T2 puzzle %0d (op %b): wrong answer gives exactly 1 wrong pulse", p, op));
            check(solved === 1'b0, $sformatf("T2 puzzle %0d: wrong answer does not solve", p));
            check(led === pat && answ_random === op,
                  $sformatf("T2 puzzle %0d: same puzzle stays after a wrong answer", p));

            // right answer
            w0 = wrong_cnt;
            enter(ans, 1);
            check(solved === 1'b1,
                  $sformatf("T2 puzzle %0d: pattern %b op %b answer %b solves it", p, pat, op, ans));
            check(led === 8'hFF, $sformatf("T2 puzzle %0d: LEDs all on when solved", p));
            check(wrong_cnt == w0, $sformatf("T2 puzzle %0d: no wrong pulse on the right answer", p));

            // after solving, more presses do nothing
            enter(8'h00, 1);
            check(solved === 1'b1 && wrong_cnt == w0,
                  $sformatf("T2 puzzle %0d: presses after solving do nothing", p));
        end
        check(seen[0] && seen[1] && seen[2] && seen[3],
              $sformatf("T3 all 4 ops seen (00:%0d 01:%0d 10:%0d 11:%0d)", seen[0], seen[1], seen[2], seen[3]));
        check(seen_ser[0] && seen_ser[1] && seen_ser[2] && seen_ser[3] &&
              seen_ser[4] && seen_ser[5] && seen_ser[6] && seen_ser[7],
              "T3 all 8 serials tested");

        // ---------------- T4: held submit / switches only ----------------
        $display("\n==== T4: held submit counts once, switches alone do nothing ====");
        reset_game(3'd6);                            // Z9D2 -> flip
        ans = ref_answer(led, ref_op(3'd6));
        w0  = wrong_cnt;
        enter(~ans, 50);                           // wrong answer, button held 50 clocks
        check(wrong_cnt == w0 + 1, "T4 holding submit gives one wrong pulse, not many");
        w0 = wrong_cnt;
        @(negedge clk) sw = ans;                   // right answer on switches, no press
        repeat (20) @(negedge clk);
        check(solved === 1'b0 && wrong_cnt == w0, "T4 switches alone do not submit");
        enter(ans, 1);
        check(solved === 1'b1, "T4 then pressing submit solves it");

        // ---------------- Summary ----------------
        $display("\n==================================================");
        $display("  onboard_game_tb: %0d passed, %0d failed", n_pass, n_fail);
        $display("  %s", (n_fail == 0) ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
        $display("==================================================\n");
        $finish;
    end

    initial begin
        #(CLK_PERIOD * 100000);
        $display("[FAIL] global timeout");
        $finish;
    end

endmodule
/* verilator lint_on BLKSEQ */
