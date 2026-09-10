`timescale 1ns / 1ps

module tick_gen #(parameter int MAX_COUNT = 100_000_000)
(
    input  logic clk,
    input  logic rst,
    output logic tick
);

    logic [$clog2(MAX_COUNT)-1:0] counter;

    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= '0;
            tick    <= 1'b0;
        end
        else begin
            if (counter == MAX_COUNT - 1) begin
                counter <= '0;
                tick    <= 1'b1;
            end
            else begin
                counter <= counter + 1;
                tick    <= 1'b0;
            end
        end
    end

endmodule
