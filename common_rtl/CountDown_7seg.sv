`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rudy
// Engineer:
//
// Countdown Timer
// Starts at 05:00
// TICK should pulse once per second
//////////////////////////////////////////////////////////////////////////////////

module CountDown_7seg(
    input  logic        CLK,
    input  logic        RST,
    input  logic        TICK,

    output logic [15:0] DATA_OUT,
    output logic        MODE_OUT,
    output logic        OUT_OF_TIME
);

    logic [3:0] min_tens;
    logic [3:0] min_ones;
    logic [3:0] sec_tens;
    logic [3:0] sec_ones;

    assign MODE_OUT = 1'b0;

    // MM:SS
    assign DATA_OUT = {
        min_tens,
        min_ones,
        sec_tens,
        sec_ones
    };

    assign OUT_OF_TIME = (DATA_OUT == 16'd0);

    always_ff @(posedge CLK) begin

        if (RST) begin

            // Reset timer to 05:00
            min_tens <= 4'd0;
            min_ones <= 4'd5;
            sec_tens <= 4'd0;
            sec_ones <= 4'd0;

        end

        else if (TICK) begin

            // Stop counting when we reach 00:00
            if (DATA_OUT != 16'h0000) begin

                // Normal seconds countdown
                if (sec_ones > 0) begin

                    sec_ones <= sec_ones - 1;

                end

                // Example: 04:30 -> 04:29
                else if (sec_tens > 0) begin

                    sec_tens <= sec_tens - 1;
                    sec_ones <= 4'd9;

                end

                // Seconds are 00, so subtract one minute
                // Example: 05:00 -> 04:59
                else if (min_ones > 0) begin

                    min_ones <= min_ones - 1;

                    sec_tens <= 4'd5;
                    sec_ones <= 4'd9;

                end

                // Needed if timer can exceed 09:59
                else if (min_tens > 0) begin

                    min_tens <= min_tens - 1;
                    min_ones <= 4'd9;

                    sec_tens <= 4'd5;
                    sec_ones <= 4'd9;

                end

            end

        end

    end

endmodule
