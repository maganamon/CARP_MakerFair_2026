`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design: 8 bit LFSR
// Engineer: Rodolfo Magana
//////////////////////////////////////////////////////////////////////////////////

/*
    This is to act as a psuedo random number generator.
    Feedback counter.
*/
module lsfr_8bit_rng(
    input  logic       clk,
    input  logic       rst,
    output logic [7:0] output_data
    //output logic finished
);

    logic feedback;
    assign feedback = output_data[7];

always_ff @(posedge clk) begin
    if (rst)
        output_data <= 8'b1111_1111;
    else begin
        output_data[0] <= feedback;
        output_data[1] <= output_data[0];
        output_data[2] <= output_data[1] ^ feedback;
        output_data[3] <= output_data[2] ^ feedback;
        output_data[4] <= output_data[3] ^ feedback;
        output_data[5] <= output_data[4];
        output_data[6] <= output_data[5];
        output_data[7] <= output_data[6];
    end
end

endmodule
