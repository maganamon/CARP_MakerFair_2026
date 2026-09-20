`timescale 1ns / 1ps

// One-hot (4-bit) -> binary (2-bit) encoder.
// Any input other than the four valid one-hot codes
// (including all-zero or multi-bit patterns) defaults to 2'b00.
module onehot4_to_bin2(
    input  logic [3:0] onehot_in,
    output logic [1:0] bin_out
);

    always_comb begin
        case (onehot_in)
            4'b0001: bin_out = 2'b00;
            4'b0010: bin_out = 2'b01;
            4'b0100: bin_out = 2'b10;
            4'b1000: bin_out = 2'b11;
            default: bin_out = 2'b00;
        endcase
    end

endmodule