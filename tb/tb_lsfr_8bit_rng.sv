`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Testbench: 8 bit LFSR RNG
//////////////////////////////////////////////////////////////////////////////////

module tb_lsfr_8bit_rng;

    logic       clk;
    logic       rst;
    logic [7:0] output_data;

    // Keep track of which 8-bit values have appeared
    logic [255:0] seen;

    integer count;
    integer i;

    // Instantiate DUT
    lsfr_8bit_rng DUT (
        .clk         (clk),
        .rst         (rst),
        .output_data (output_data)
    );

    // 100 MHz clock
    // Period = 10 ns
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_lsfr_8bit_rng);
        clk = 0;
        forever #5 clk = ~clk;
    end


    initial begin

        // Initialize testbench variables
        rst   = 1;
        seen  = '0;
        count = 0;

        ////////////////////////////////////////////////////////////////
        // RESET
        ////////////////////////////////////////////////////////////////

        repeat (2)
            @(posedge clk);

        // Deassert reset away from positive edge
        @(negedge clk);
        rst = 0;


        ////////////////////////////////////////////////////////////////
        // TEST ALL 255 NON-ZERO STATES
        ////////////////////////////////////////////////////////////////

        repeat (255) begin

            @(posedge clk);

            // Wait for nonblocking assignments in DUT to update
            #1;

            $display(
                "Cycle = %0d | output_data = %8b | hex = %02h",
                count,
                output_data,
                output_data
            );


            ////////////////////////////////////////////////////////////
            // Check for illegal zero state
            ////////////////////////////////////////////////////////////

            if (output_data == 8'h00) begin
                $error(
                    "ERROR: LFSR entered the all-zero state at cycle %0d",
                    count
                );

                $finish;
            end


            ////////////////////////////////////////////////////////////
            // Check for repeated state
            ////////////////////////////////////////////////////////////

            if (seen[output_data]) begin
                $error(
                    "ERROR: output_data repeated early: %02h at cycle %0d",
                    output_data,
                    count
                );

                $finish;
            end


            ////////////////////////////////////////////////////////////
            // Mark this state as seen
            ////////////////////////////////////////////////////////////

            seen[output_data] = 1'b1;

            count = count + 1;

        end


        ////////////////////////////////////////////////////////////////
        // CHECK THAT EVERY NON-ZERO VALUE OCCURRED
        ////////////////////////////////////////////////////////////////

        for (i = 1; i < 256; i = i + 1) begin

            if (seen[i] == 0) begin
                $error(
                    "ERROR: Value %02h was never generated",
                    i
                );

                $finish;
            end

        end


        ////////////////////////////////////////////////////////////////
        // ZERO SHOULD NEVER HAVE OCCURRED
        ////////////////////////////////////////////////////////////////

        if (seen[0] == 1) begin
            $error(
                "ERROR: 00 should not occur in a normal XOR LFSR"
            );

            $finish;
        end


        ////////////////////////////////////////////////////////////////
        // VERIFY SEQUENCE REPEATS
        ////////////////////////////////////////////////////////////////

        @(posedge clk);
        #1;

        if (output_data != 8'hFF) begin
            $error(
                "ERROR: Expected sequence to return to FF, got %02h",
                output_data
            );

            $finish;
        end


        ////////////////////////////////////////////////////////////////
        // SUCCESS
        ////////////////////////////////////////////////////////////////

        $display("");
        $display("============================================");
        $display("         LFSR TEST PASSED");
        $display("============================================");
        $display("All 255 non-zero combinations were reached.");
        $display("No state repeated before the full sequence.");
        $display("LFSR successfully returned to 8'hFF.");
        $display("============================================");
        $display("");

        $finish;

    end

endmodule
