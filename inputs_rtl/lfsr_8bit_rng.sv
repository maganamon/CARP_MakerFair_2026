`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design: 8 bit LFSR
// Engineer: Rodolfo Magana
//////////////////////////////////////////////////////////////////////////////////

/*
    This is to act as a psuedo random number generator.
    Feedback counter.

    The top level ties rst to 1'b0 so the LFSR free-runs from the moment the
    FPGA is programmed; that way each game starts at a different point in the
    sequence. Because it is never reset on the board, lfsr needs a start
    value: an LFSR that starts at all zeros stays at zero forever.
*/
module lfsr_8bit_rng(
    input  logic       clk,
    input  logic       rst,
    output logic [7:0] output_data
    //output logic finished
);

    logic [7:0] lfsr = 8'b1111_1111;   // start value loaded when the FPGA is programmed
    logic       feedback;

    assign feedback    = lfsr[7];
    assign output_data = lfsr;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            lfsr <= 8'b1111_1111;
        else begin
            lfsr[0] <= feedback;
            lfsr[1] <= lfsr[0];
            lfsr[2] <= lfsr[1] ^ feedback;
            lfsr[3] <= lfsr[2] ^ feedback;
            lfsr[4] <= lfsr[3] ^ feedback;
            lfsr[5] <= lfsr[4];
            lfsr[6] <= lfsr[5];
            lfsr[7] <= lfsr[6];
        end
    end

endmodule
