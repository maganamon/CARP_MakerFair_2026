`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Testbench: wire game + HT16K33 display + shared lives (top level)
//
// Drives the real board pins of top_level_MakerFair and plays the wire game
// the way a player does:
//   - an I2C slave model (HT16K33 at 0x70) sits on disp_scl / disp_sda,
//     ACKs every byte and records what the FPGA sends
//   - the TB reads the serial number off the "display", looks up the wire
//     with its OWN copy of the rules, and presses wire buttons (with bounce)
//
// Tests
//   D1  display start-up: 0x21, 0x81, 0xEx, then one 9-byte digit write,
//       every byte ACKed, driver's ack_error stays 0
//   D2  the display shows one of the 8 serial numbers, and it is the one
//       the wire game picked
//   W1  wrong wire -> exactly 1 life lost, not solved, serial unchanged
//   W2  wrong wire held down for a long time -> still exactly 1 life
//   W3  shared lives: wire mistakes change Simon's strikes, Simon untouched
//   W4  right wire -> solved, no life lost, later presses do nothing,
//       no extra display writes while the serial does not change
//   D3  after rst the display is set up again and shows the new serial
//   W5  3 wrong wires -> game over; wire game stops, presses do nothing
//   W6  serial number changes between games (free-running LFSR)
//
// Run with Icarus (uses tri-state nets + pullups):
//   iverilog -g2012 -s wire_display_tb -o wire_tb.vvp tb/wire_display_tb.sv $(TOP_SRCS)
//   vvp wire_tb.vvp
////////////////////////////////////////////////////////////////////////////////

/* verilator lint_off BLKSEQ */
/* verilator lint_off UNUSEDSIGNAL */
module wire_display_tb;

    // ------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------
    localparam int CLK_PERIOD = 10;       // 100 MHz
    localparam int TICK_DIV   = 200;      // 1 "second" = 200 clocks in sim
    localparam int DB_COUNT   = 20;       // debounce = 20 clocks in sim
    localparam int HOLD       = 40;       // clocks a button is held
    localparam int DISP_WAIT  = 3_000_000;// display power-up (1M) + I2C traffic

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    logic       clk = 1'b0;
    logic       rst;
    logic [3:0] simon_btns;
    logic [3:0] wire_btns;

    logic [3:0] simon_led;
    logic [2:0] lives_led;
    logic [7:0] seg;
    logic [3:0] an;
    logic       out_of_time;

    wire disp_scl, disp_sda;
    pullup (disp_scl);
    pullup (disp_sda);

    top_level_MakerFair #(
        .TICK_COUNT     (TICK_DIV),
        .DEBOUNCE_COUNT (DB_COUNT)
    ) dut (
        .clk         (clk),
        .rst         (rst),
        .simon_btns  (simon_btns),
        .wire_btns   (wire_btns),
        .simon_led   (simon_led),
        .lives_led   (lives_led),
        .seg         (seg),
        .an          (an),
        .out_of_time (out_of_time),
        .disp_scl    (disp_scl),
        .disp_sda    (disp_sda)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------------------------
    // Reference: the 8 serial numbers, their display patterns and the
    // correct wire (TB's own copy of the rules)
    //   wire buttons: 0 = yellow (top), 1 = red, 2 = green, 3 = blue
    // ------------------------------------------------------------------
    function automatic logic [63:0] ref_digits(input int idx);   // {d0,d1,d2,d3}
        case (idx)
            0: ref_digits = {16'h128F, 16'h0007, 16'h2470, 16'h00DB};  // B7K2
            1: ref_digits = {16'h00F7, 16'h00E6, 16'h0536, 16'h00FD};  // A4M6
            2: ref_digits = {16'h1201, 16'h008F, 16'h20F3, 16'h00FF};  // T3R8
            3: ref_digits = {16'h00F9, 16'h2069, 16'h2136, 16'h008F};  // E5N3
            4: ref_digits = {16'h0039, 16'h0006, 16'h0038, 16'h00E6};  // C1L4
            5: ref_digits = {16'h003F, 16'h0007, 16'h00F3, 16'h0006};  // O7P1
            6: ref_digits = {16'h0C09, 16'h00EF, 16'h120F, 16'h00DB};  // Z9D2
            default: ref_digits = {16'h003E, 16'h00DB, 16'h2D00, 16'h00FF};  // U2X8
        endcase
    endfunction

    function automatic string ref_name(input int idx);
        case (idx)
            0: ref_name = "B7K2";  1: ref_name = "A4M6";
            2: ref_name = "T3R8";  3: ref_name = "E5N3";
            4: ref_name = "C1L4";  5: ref_name = "O7P1";
            6: ref_name = "Z9D2";  7: ref_name = "U2X8";
            default: ref_name = "????";   // not one of the 8 serials
        endcase
    endfunction

    function automatic logic [3:0] ref_wire(input int idx);      // one-hot button
        case (idx)
            0, 7:    ref_wire = 4'b0100;   // green
            1, 6:    ref_wire = 4'b0010;   // red
            2, 3:    ref_wire = 4'b1000;   // blue
            default: ref_wire = 4'b0001;   // yellow (4, 5)
        endcase
    endfunction

    // Which serial is on the display (-1 = not one of the 8)
    function automatic int decode_display(input logic [63:0] d);
        decode_display = -1;
        for (int i = 0; i < 8; i++)
            if (d == ref_digits(i)) decode_display = i;
    endfunction

    // ------------------------------------------------------------------
    // HT16K33 model: I2C slave at 0x70 on disp_scl / disp_sda
    // ------------------------------------------------------------------
    logic ack_drive = 1'b0;
    assign disp_sda = ack_drive ? 1'b0 : 1'bz;     // open-drain ACK

    bit         in_txn    = 0;
    bit         addressed = 0;
    int         bitcnt    = 0;
    int         nbytes    = 0;
    logic [7:0] shreg     = 8'h00;
    logic [7:0] rx [0:15];
    int         rx_len    = 0;

    int          n_txn          = 0;     // complete transactions seen
    int          n_setup        = 0;     // 1-byte command transactions
    int          n_digit_writes = 0;     // 9-byte display RAM writes
    int          n_bad_txn      = 0;     // anything unexpected
    logic [7:0]  setup_bytes [0:7];
    logic [63:0] shown = '0;             // {d0,d1,d2,d3} on the display

    // START: SDA falls while SCL is high
    always @(negedge disp_sda) begin
        if (disp_scl === 1'b1) begin
            in_txn = 1; addressed = 0; bitcnt = 0; nbytes = 0; rx_len = 0;
        end
    end

    // STOP: SDA rises while SCL is high
    always @(posedge disp_sda) begin
        if (disp_scl === 1'b1 && in_txn) begin
            in_txn = 0;
            n_txn++;
            if (!addressed) begin
                n_bad_txn++;
                $display("[INFO] %0t  I2C: transaction not for address 0x70", $time);
            end else if (rx_len == 1) begin
                if (n_setup < 8) setup_bytes[n_setup] = rx[0];
                n_setup++;
            end else if (rx_len == 9 && rx[0] == 8'h00) begin
                shown = {rx[2], rx[1], rx[4], rx[3], rx[6], rx[5], rx[8], rx[7]};
                n_digit_writes++;
            end else begin
                n_bad_txn++;
                $display("[INFO] %0t  I2C: unexpected %0d-byte write", $time, rx_len);
            end
        end
    end

    // Data bits are sampled on the rising edge of SCL
    always @(posedge disp_scl) begin
        if (in_txn && bitcnt < 8) begin
            shreg  = {shreg[6:0], (disp_sda === 1'b0) ? 1'b0 : 1'b1};
            bitcnt = bitcnt + 1;
        end
    end

    // After 8 bits: ACK during the 9th clock, then let go
    always @(negedge disp_scl) begin
        if (in_txn) begin
            if (bitcnt == 8) begin
                if (nbytes == 0)
                    addressed = (shreg == {7'h70, 1'b0});   // write to 0x70
                else if (addressed && rx_len < 16) begin
                    rx[rx_len] = shreg;
                    rx_len     = rx_len + 1;
                end
                nbytes    = nbytes + 1;
                ack_drive = addressed;
                bitcnt    = 9;
            end else if (bitcnt == 9) begin
                ack_drive = 1'b0;
                bitcnt    = 0;
            end
        end
    end

    // ------------------------------------------------------------------
    // Monitors
    // ------------------------------------------------------------------
    int wire_wrong_cnt  = 0;
    int simon_wrong_cnt = 0;

    always @(posedge clk) begin
        if (dut.wire_wrong  === 1'b1) wire_wrong_cnt  = wire_wrong_cnt  + 1;
        if (dut.simon_wrong === 1'b1) simon_wrong_cnt = simon_wrong_cnt + 1;
    end

    // ------------------------------------------------------------------
    // Check / report
    // ------------------------------------------------------------------
    int n_pass = 0, n_fail = 0;

    task automatic check(input bit cond, input string msg);
        if (cond) begin
            n_pass++;
            $display("[PASS] %0t  %s", $time, msg);
        end else begin
            n_fail++;
            $display("[FAIL] %0t  %s   (lives_led=%b wire_serial=%0d solved=%b)",
                     $time, msg, lives_led, dut.wire_serial, dut.wire_solved);
        end
    endtask

    // ------------------------------------------------------------------
    // Stimulus helpers (inputs change on negedge clk)
    // ------------------------------------------------------------------
    task automatic reset_board(input int release_delay);
        @(negedge clk);
        rst = 1'b1; simon_btns = 4'b0000; wire_btns = 4'b0000;
        repeat (5 + release_delay) @(negedge clk);
        n_txn = 0; n_setup = 0; n_digit_writes = 0; n_bad_txn = 0;
        wire_wrong_cnt = 0; simon_wrong_cnt = 0;
        rst = 1'b0;
        repeat (5) @(negedge clk);
    endtask

    // A real wire-button press: bounce on, hold, bounce off, settle
    task automatic press_wire(input logic [3:0] b, input int hold);
        repeat (3) begin
            @(negedge clk) wire_btns = b;
            repeat (2) @(negedge clk);
            wire_btns = 4'b0000;
            repeat (2) @(negedge clk);
        end
        wire_btns = b;
        repeat (hold) @(negedge clk);
        repeat (3) begin
            wire_btns = 4'b0000;
            repeat (2) @(negedge clk);
            wire_btns = b;
            repeat (2) @(negedge clk);
        end
        wire_btns = 4'b0000;
        repeat (3*DB_COUNT) @(negedge clk);
    endtask

    // Wait until the display has received `target` digit writes
    task automatic wait_display(input int target, output bit ok);
        int i;
        ok = (n_digit_writes >= target);
        i  = 0;
        while (!ok && i < DISP_WAIT) begin
            @(negedge clk);
            ok = (n_digit_writes >= target);
            i++;
        end
    endtask

    function automatic logic [3:0] rot(input logic [3:0] v);   // another button
        rot = {v[2:0], v[3]};
    endfunction

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    int         idx, idx0, w0, s0, n0, distinct;
    logic [3:0] right, wrong_b;
    bit         got;
    bit         seen [8];

    initial begin
        // Only the TB-level signals (pins, I2C lines): the full design over
        // several million clocks would make a multi-GB waveform file.
        $dumpfile("wire_display_tb.vcd");
        $dumpvars(1, wire_display_tb);

        rst = 1'b1; simon_btns = 4'b0000; wire_btns = 4'b0000;

        // ---------------- D1: display start-up ----------------
        $display("\n==== D1: display start-up over I2C ====");
        reset_board(0);
        wait_display(1, got);
        check(got, "D1 display received its first digit write");
        check(n_setup == 3, $sformatf("D1 three set-up commands sent (saw %0d)", n_setup));
        if (n_setup >= 3) begin
            check(setup_bytes[0] == 8'h21, $sformatf("D1 1st command 0x21 oscillator on (got 0x%02h)", setup_bytes[0]));
            check(setup_bytes[1] == 8'h81, $sformatf("D1 2nd command 0x81 display on (got 0x%02h)", setup_bytes[1]));
            check(setup_bytes[2][7:4] == 4'hE, $sformatf("D1 3rd command 0xEx brightness (got 0x%02h)", setup_bytes[2]));
        end
        check(n_bad_txn == 0, "D1 no unexpected I2C transactions");
        check(dut.u_display.ack_error === 1'b0, "D1 driver saw every ACK (ack_error = 0)");

        // ---------------- D2: display shows the chosen serial ----------------
        $display("\n==== D2: display shows the wire game's serial ====");
        idx = decode_display(shown);
        check(idx >= 0, $sformatf("D2 display shows a valid serial (raw %h)", shown));
        check(idx == int'(dut.wire_serial),
              $sformatf("D2 display shows %s = the serial the wire game picked (idx %0d)",
                        ref_name(idx), dut.wire_serial));
        idx0  = idx;
        right = ref_wire(idx);
        $display("[INFO] serial %s -> correct wire button %b", ref_name(idx), right);

        // ---------------- W1: wrong wire ----------------
        $display("\n==== W1: wrong wire ====");
        w0 = wire_wrong_cnt;
        press_wire(rot(right), HOLD);
        check(wire_wrong_cnt == w0 + 1, "W1 wrong wire -> exactly one wrong pulse");
        check(lives_led === 3'b110, $sformatf("W1 one life lost (lives_led=%b)", lives_led));
        check(dut.wire_solved === 1'b0, "W1 not solved");
        check(int'(dut.wire_serial) == idx0, "W1 same serial after a wrong wire");

        // ---------------- W2: wrong wire held down ----------------
        $display("\n==== W2: wrong wire held for ~3 seconds ====");
        w0 = wire_wrong_cnt;
        press_wire(rot(rot(right)), 3*TICK_DIV);
        check(wire_wrong_cnt == w0 + 1, "W2 long hold -> still exactly one wrong pulse");
        check(lives_led === 3'b100, $sformatf("W2 second life lost (lives_led=%b)", lives_led));

        // ---------------- W3: shared lives ----------------
        $display("\n==== W3: wire mistakes are shared lives ====");
        check(dut.strikes == 2'd2, $sformatf("W3 Simon strikes = 2 after two wire mistakes (got %0d)", dut.strikes));
        check(simon_wrong_cnt == 0, "W3 wire presses never counted as Simon presses");

        // ---------------- W4: right wire ----------------
        $display("\n==== W4: right wire ====");
        w0 = wire_wrong_cnt; n0 = n_digit_writes;
        press_wire(right, HOLD);
        check(dut.wire_solved === 1'b1, "W4 right wire -> solved");
        check(wire_wrong_cnt == w0, "W4 no wrong pulse on the right wire");
        check(lives_led === 3'b100, "W4 no life lost on the right wire");
        press_wire(rot(right), HOLD);                  // after solving: ignored
        check(wire_wrong_cnt == w0 && lives_led === 3'b100,
              "W4 presses after solving do nothing");
        check(n_digit_writes == n0, "W4 no extra display writes while the serial is unchanged");

        // ---------------- D3: display after rst ----------------
        $display("\n==== D3: rst -> display set up again with the new serial ====");
        reset_board($urandom % 300);
        wait_display(1, got);
        check(got && n_setup == 3, "D3 display set up again after rst");
        idx = decode_display(shown);
        check(idx >= 0 && idx == int'(dut.wire_serial),
              $sformatf("D3 display shows %s = new wire serial (idx %0d)",
                        ref_name(idx), dut.wire_serial));
        check(lives_led === 3'b111, "D3 rst gave back 3 lives");

        // ---------------- W5: game over ----------------
        $display("\n==== W5: three wrong wires -> game over ====");
        right = ref_wire(int'(dut.wire_serial));
        press_wire(rot(right), HOLD);
        press_wire(rot(right), HOLD);
        press_wire(rot(right), HOLD);
        check(lives_led === 3'b000, $sformatf("W5 all lives gone (lives_led=%b)", lives_led));
        check(dut.game_over === 1'b1, "W5 game_over set");
        w0 = wire_wrong_cnt;
        press_wire(right, HOLD);
        press_wire(rot(right), HOLD);
        check(wire_wrong_cnt == w0 && dut.wire_solved === 1'b0 && lives_led === 3'b000,
              "W5 wire game stopped: presses during game over do nothing");

        // ---------------- W6: serial changes between games ----------------
        $display("\n==== W6: serial number changes between games ====");
        for (int i = 0; i < 8; i++) seen[i] = 0;
        for (int g = 0; g < 10; g++) begin
            reset_board($urandom % 500);               // player lets go of rst at a random time
            seen[dut.wire_serial] = 1;
            $display("[INFO] game %0d: serial %s", g, ref_name(int'(dut.wire_serial)));
        end
        distinct = 0;
        for (int i = 0; i < 8; i++) if (seen[i]) distinct++;
        check(distinct >= 3, $sformatf("W6 %0d different serials in 10 games (expected >= 3)", distinct));

        // ---------------- Summary ----------------
        $display("\n==================================================");
        $display("  wire_display_tb: %0d passed, %0d failed", n_pass, n_fail);
        $display("  %s", (n_fail == 0) ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
        $display("==================================================\n");
        $finish;
    end

    // Global watchdog
    initial begin
        #(64'd20_000_000 * CLK_PERIOD);
        $display("[FAIL] global timeout");
        $finish;
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on BLKSEQ */