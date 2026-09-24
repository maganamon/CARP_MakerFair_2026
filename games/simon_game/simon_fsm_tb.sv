`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Testbench: simon_fsm (3-round Simon Says)
//
// Self-checking. Prints [PASS]/[FAIL] per check and a summary at the end.
// Every wait has a timeout, so a broken DUT can't hang the sim.
//
// Tests
//   T0  bin2_to_onehot4 decode (assumed 0->0001, 1->0010, 2->0100, 3->1000)
//   T1  reset behaviour
//   T2  full game: wait for playback, press the whole sequence each round
//   T3  full sequence per round: no advance until all N presses are in
//   T4  wrong press in round 1       -> wrong pulses, no win, game restarts
//   T5  wrong press in a later round -> round counter resets (needs 3 fresh wins)
//   T6  press during playback        -> ignored until sequence finished
//   T7  illegal button codes (none / multi-hot) -> treated as wrong
//
// Needs: simon_fsm.sv + bin2_to_onehot4.sv
// Icarus:  iverilog -g2012 -o simon_tb simon_fsm_tb.sv simon_fsm.sv bin2_to_onehot4.sv && vvp simon_tb +SEED=7
// Vivado:  xvlog -sv simon_fsm_tb.sv simon_fsm.sv bin2_to_onehot4.sv && xelab -debug typical simon_fsm_tb -s tb && xsim tb -R
////////////////////////////////////////////////////////////////////////////////

// Testbench code uses blocking '=' on purpose (clock generator and the
// scoreboard, so the test tasks see updated counts right away).
/* verilator lint_off BLKSEQ */
module simon_fsm_tb;

    // ------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------
    localparam int CLK_PERIOD  = 10;   // 100 MHz
    localparam int TICK_DIV    = 10;   // 1 "second" = 10 clocks in sim
    localparam int NGAMES      = 5;    // games per randomised test
    localparam int WAIT_CYCLES = 50;   // generic timeout

    // ------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------
    logic       clk = 0;
    logic       rst;
    logic       tick_1hz = 1'b0;
    logic [3:0] btn_pressed;
    logic       btn_valid;
    logic [1:0] rng_lsfr;

    logic [3:0] leds_o;
    logic       push_to_fifo;
    logic       win;
    logic       wrong;

    simon_fsm dut (
        .clk          (clk),
        .rst          (rst),
        .tick_1hz     (tick_1hz),
        .btn_pressed  (btn_pressed),
        .btn_valid    (btn_valid),
        .rng_lsfr     (rng_lsfr),
        .leds_o       (leds_o),
        .push_to_fifo (push_to_fifo),
        .win          (win),
        .wrong        (wrong)
    );

    // ------------------------------------------------------------------
    // Clock, 1 Hz tick, free-running "LFSR"
    // ------------------------------------------------------------------
    always #(CLK_PERIOD/2) clk = ~clk;

    int tick_cnt = 0;
    always @(posedge clk) begin
        if (tick_cnt == TICK_DIV-1) begin tick_cnt <= 0; tick_1hz <= 1'b1; end
        else                        begin tick_cnt <= tick_cnt + 1; tick_1hz <= 1'b0; end
    end

    bit rng_frozen = 0;      // T0 drives rng_lsfr by hand
    always @(negedge clk)
        if (!rng_frozen) rng_lsfr <= 2'($urandom);   // keep low 2 bits (0..3)

    // ------------------------------------------------------------------
    // Reference model + scoreboard
    // ------------------------------------------------------------------
    function automatic logic [3:0] ref_onehot(input logic [1:0] b);
        ref_onehot = 4'b0001 << b;
    endfunction

    // Every cycle push_to_fifo is high, the FSM is appending a new step.
    // Record what that step should be (independently of leds_o).
    logic [3:0] seq [0:15];
    int n_push    = 0;     // steps appended in the current game
    int wrong_cnt = 0;     // cycles with wrong == 1
    int push_leds_err = 0; // leds_o != new step while pushing

    always @(posedge clk) begin
        if (push_to_fifo === 1'b1) begin
            if (n_push < 16) seq[n_push] = ref_onehot(rng_lsfr);
            if (leds_o !== ref_onehot(rng_lsfr)) push_leds_err = push_leds_err + 1;
            n_push = n_push + 1;
        end
        if (wrong === 1'b1) wrong_cnt = wrong_cnt + 1;
    end

    // ------------------------------------------------------------------
    // Check / report helpers
    // ------------------------------------------------------------------
    int n_pass = 0, n_fail = 0;

    task automatic check(input bit cond, input string msg);
        if (cond) begin
            n_pass++;
            $display("[PASS] %0t  %s", $time, msg);
        end else begin
            n_fail++;
            $display("[FAIL] %0t  %s   (state=%0d round=%0d leds_o=%b win=%b wrong=%b)",
                     $time, msg, dut.state, dut.round, leds_o, win, wrong);
        end
    endtask

    // ------------------------------------------------------------------
    // Stimulus helpers (inputs change on negedge, away from the DUT's posedge)
    // ------------------------------------------------------------------
    task automatic start_game();
        @(negedge clk);
        rst = 1'b1; btn_valid = 1'b0; btn_pressed = 4'b0000;
        repeat (3) @(negedge clk);
        n_push = 0; wrong_cnt = 0; push_leds_err = 0;
        rst = 1'b0;
    endtask

    // Single-cycle button pulse (like buttons_manager's simon_valid)
    task automatic press(input logic [3:0] b);
        @(negedge clk);
        btn_pressed = b; btn_valid = 1'b1;
        @(negedge clk);
        btn_pressed = 4'b0000; btn_valid = 1'b0;
    endtask

    task automatic wait_for_push(input int target, input int max_cycles, output bit ok);
        int i;
        ok = (n_push >= target);
        i  = 0;
        while (!ok && i < max_cycles) begin
            @(negedge clk);
            ok = (n_push >= target);
            i++;
        end
    endtask

    task automatic wait_for_win(input int max_cycles, output bit ok);
        int i;
        ok = (win === 1'b1);
        i  = 0;
        while (!ok && i < max_cycles) begin
            @(negedge clk);
            ok = (win === 1'b1);
            i++;
        end
    endtask

    task automatic wait_ticks(input int n);
        repeat (n) @(posedge tick_1hz);
        @(negedge clk);
    endtask

    // After a win: stays won, all LEDs on, no new steps, no wrong
    task automatic check_win_sticky(input string tag);
        int p0, w0, i;
        bit ok;
        p0 = n_push; w0 = wrong_cnt; ok = 1;
        for (i = 0; i < 50; i++) begin
            @(negedge clk);
            if (win !== 1'b1 || leds_o !== 4'b1111) ok = 0;
        end
        check(ok,               {tag, ": win held high with leds_o=1111 for 50 cycles"});
        check(n_push == p0,     {tag, ": no new steps pushed after win"});
        check(wrong_cnt == w0,  {tag, ": wrong never asserted after win"});
    endtask

    // Plays a whole game: each round, wait out the playback (2 ticks per
    // step), then press the full sequence. Returns the round in which win
    // was seen (0 = never won).
    task automatic play_game(input string tag, output int win_round);
        int r, k, w0;
        bit got, stop;
        win_round = 0;
        stop = 0;
        for (r = 0; r < 3 && !stop; r++) begin
            wait_for_push(r+1, WAIT_CYCLES, got);
            check(got, $sformatf("%s round %0d: new step appended (push_to_fifo)", tag, r+1));
            if (!got) stop = 1;
            else begin
                wait_ticks(2*(r+1));         // playback: r+1 steps x (1s on + 1s off)
                check(leds_o === seq[r],
                      $sformatf("%s round %0d: leds_o holds step %b while waiting", tag, r+1, seq[r]));
                for (k = 0; k <= r && !stop; k++) begin
                    w0 = wrong_cnt;
                    press(seq[k]);
                    repeat (3) @(negedge clk);
                    if (wrong_cnt != w0) begin
                        check(0, $sformatf("%s round %0d: correct press #%0d (%b) accepted", tag, r+1, k+1, seq[k]));
                        stop = 1;
                    end
                end
                if (!stop && win === 1'b1) begin
                    win_round = r+1;
                    stop = 1;
                end
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    int  g, r, k, w0, p0, presses;
    bit  got, ok;
    logic [3:0] bad;

    initial begin
        $dumpfile("simon_fsm_tb.vcd");
        $dumpvars(0, simon_fsm_tb);

        rst = 1'b1; btn_valid = 1'b0; btn_pressed = 4'b0000; rng_lsfr = 2'd0;

        // ---------------- T0: decoder ----------------
        $display("\n==== T0: bin2_to_onehot4 decode ====");
        rng_frozen = 1;
        for (k = 0; k < 4; k++) begin
            @(negedge clk); rng_lsfr = k[1:0]; #1;
            check(dut.onehot4_o === ref_onehot(k[1:0]),
                  $sformatf("T0 rng=%0d -> onehot %b (expected %b)", k, dut.onehot4_o, ref_onehot(k[1:0])));
        end
        rng_frozen = 0;

        // ---------------- T1: reset ----------------
        $display("\n==== T1: reset ====");
        @(negedge clk); rst = 1'b1;
        repeat (3) @(negedge clk);
        check(win === 1'b0,          "T1 win = 0 during reset");
        check(wrong === 1'b0,        "T1 wrong = 0 during reset");
        check(push_to_fifo === 1'b0, "T1 push_to_fifo = 0 during reset");
        n_push = 0; wrong_cnt = 0; push_leds_err = 0;
        rst = 1'b0;
        wait_for_push(1, WAIT_CYCLES, got);
        check(got, "T1 first step pushed after reset released");
        check(push_leds_err == 0, "T1 leds_o shows the new step while it is pushed");

        // ---------------- T2: one press per round ----------------
        $display("\n==== T2: full game (wait for playback, repeat whole sequence) ====");
        for (g = 0; g < NGAMES; g++) begin
            start_game();
            play_game($sformatf("T2 game %0d", g), presses);
            check(presses == 3,
                  $sformatf("T2 game %0d: win after round 3 (won in round %0d, 0 = never)", g, presses));
            check(wrong_cnt == 0, $sformatf("T2 game %0d: wrong never asserted", g));
            check(push_leds_err == 0, $sformatf("T2 game %0d: leds_o matched each pushed step", g));
            if (presses != 0) check_win_sticky($sformatf("T2 game %0d", g));
        end

        // ---------------- T3: full sequence per round (spec) ----------------
        $display("\n==== T3: FSM waits for all N presses each round ====");
        for (g = 0; g < NGAMES; g++) begin
            start_game();
            ok = 1;
            for (r = 1; r <= 3 && ok; r++) begin
                wait_for_push(r, WAIT_CYCLES, got);
                check(got, $sformatf("T3 game %0d round %0d: step %0d appended", g, r, r));
                if (!got) ok = 0;
                else begin
                    check(n_push == r,
                          $sformatf("T3 game %0d round %0d: exactly %0d steps in play (saw %0d)", g, r, r, n_push));
                    wait_ticks(2*r);                // r blinks x (1s on + 1s off)
                    for (k = 0; k < r && ok; k++) begin
                        w0 = wrong_cnt; p0 = n_push;
                        press(seq[k]);
                        repeat (3) @(negedge clk);
                        if (wrong_cnt != w0) begin
                            check(0, $sformatf("T3 game %0d round %0d: correct press #%0d (%b) accepted", g, r, k+1, seq[k]));
                            ok = 0;
                        end else if (k < r-1 && n_push != p0) begin
                            check(0, $sformatf("T3 game %0d round %0d: FSM advanced after only %0d of %0d presses", g, r, k+1, r));
                            ok = 0;
                        end else if (r < 3 && win === 1'b1) begin
                            check(0, $sformatf("T3 game %0d round %0d: win asserted early", g, r));
                            ok = 0;
                        end
                    end
                end
            end
            if (ok) begin
                wait_for_win(10, got);
                check(got, $sformatf("T3 game %0d: win after round 3", g));
            end
        end

        // ---------------- T4: wrong press, round 1 ----------------
        $display("\n==== T4: wrong press in round 1 ====");
        start_game();
        wait_for_push(1, WAIT_CYCLES, got);
        check(got, "T4 first step appended");
        wait_ticks(2);                               // let the 1-step playback finish
        bad = {seq[0][2:0], seq[0][3]};            // rotate -> different one-hot
        w0 = wrong_cnt;
        press(bad);
        repeat (3) @(negedge clk);
        check(wrong_cnt > w0, "T4 wrong asserted after wrong button");
        check(win === 1'b0,   "T4 win stays low");
        wait_for_push(2, WAIT_CYCLES, got);
        $display("[INFO] %0t  T4 after a loss the FSM %s", $time,
                 got ? "auto-restarts a new game (WRONG -> NEW_GAME -> SETUP)" : "stays in lose state");

        // ---------------- T5: wrong press in a later round ----------------
        $display("\n==== T5: wrong press in round 2, then a clean game ====");
        start_game();
        wait_for_push(1, WAIT_CYCLES, got);
        wait_ticks(2);
        press(seq[0]);                               // round 1 correct
        wait_for_push(2, WAIT_CYCLES, got);
        check(got, "T5 round 2 reached");
        wait_ticks(4);                               // 2-step playback
        bad = {seq[0][2:0], seq[0][3]};              // round 2 expects seq[0] first
        w0 = wrong_cnt;
        press(bad);
        n_push = 0;       // FSM restarts on its own ~3 clocks from now; count fresh
        repeat (3) @(negedge clk);
        check(wrong_cnt > w0, "T5 wrong asserted in round 2");
        check(win === 1'b0,   "T5 no win after wrong press");
        // Next game must start again from round 1 (needs 3 presses)
        play_game("T5 replay", presses);
        check(presses == 3,
              $sformatf("T5 after a loss, a fresh game is won in round 3 (got %0d, 0 = never)", presses));

        // ---------------- T6: press during playback ----------------
        $display("\n==== T6: button pressed while sequence is still playing ====");
        start_game();
        wait_for_push(1, WAIT_CYCLES, got);
        p0 = n_push; w0 = wrong_cnt;
        press(seq[0]);                               // immediately, before 2 ticks elapse
        repeat (5) @(negedge clk);
        check(n_push == p0 && wrong_cnt == w0 && win === 1'b0,
              "T6 press during playback is ignored (no advance, no wrong)");

        // ---------------- T7: illegal codes ----------------
        $display("\n==== T7: illegal button codes ====");
        start_game();
        wait_for_push(1, WAIT_CYCLES, got);
        wait_ticks(2);
        w0 = wrong_cnt;
        press(4'b0000);
        repeat (3) @(negedge clk);
        check(wrong_cnt > w0, "T7 btn_valid with no button (0000) counts as wrong");
        start_game();
        wait_for_push(1, WAIT_CYCLES, got);
        wait_ticks(2);
        w0 = wrong_cnt;
        press(seq[0] | {seq[0][2:0], seq[0][3]});   // correct button + a neighbour
        repeat (3) @(negedge clk);
        check(wrong_cnt > w0, "T7 two buttons at once counts as wrong");

        // ---------------- Summary ----------------
        $display("\n==================================================");
        $display("  simon_fsm_tb: %0d passed, %0d failed", n_pass, n_fail);
        $display("  %s", (n_fail == 0) ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
        $display("==================================================\n");
        $finish;
    end

    // Global watchdog
    initial begin
        #(CLK_PERIOD * 200000);
        $display("[FAIL] global timeout");
        $finish;
    end

endmodule
/* verilator lint_on BLKSEQ */
