`timescale 1ns / 1ps

// Binary (2-bit) -> one-hot (4-bit) decoder.
// Every input value (0-3) maps to exactly one of the four one-hot
// codes; there is no invalid input to default on, since bin_in
// only ever has 4 possible values.
module bin2_to_onehot4(
    input  logic [1:0] bin_in,
    output logic [3:0] onehot_out
);

    always_comb begin
        case (bin_in)
            2'b00: onehot_out = 4'b0001;
            2'b01: onehot_out = 4'b0010;
            2'b10: onehot_out = 4'b0100;
            2'b11: onehot_out = 4'b1000;
            default: onehot_out = 4'b0000;
        endcase
    end

endmodule