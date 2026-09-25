`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Design: Basys 3 Seven Segment Cathode Driver
// seg[0] = A
// seg[1] = B
// seg[2] = C
// seg[3] = D
// seg[4] = E
// seg[5] = F
// seg[6] = G
// seg[7] = DP
//
// Basys 3 seven segment display is ACTIVE LOW.
//////////////////////////////////////////////////////////////////////////////////

module CathodeDriver (
    input  logic        CLK,
    input  logic [15:0] HEX,

    output logic [7:0]  CATHODES,
    output logic [3:0]  ANODES
);

    // ============================================================
    // Display refresh counter
    // ============================================================

    logic [17:0] refresh_counter = '0;
    logic [1:0]  digit_select;

    always_ff @(posedge CLK) begin
        refresh_counter <= refresh_counter + 1'b1;
    end

    assign digit_select = refresh_counter[17:16];


    // ============================================================
    // Select which nibble/digit to display
    // ============================================================

    logic [3:0] digit;

    always_comb begin

        case (digit_select)

            2'b00: begin
                ANODES = 4'b1110;
                digit  = HEX[3:0];
            end

            2'b01: begin
                ANODES = 4'b1101;
                digit  = HEX[7:4];
            end

            2'b10: begin
                ANODES = 4'b1011;
                digit  = HEX[11:8];
            end

            2'b11: begin
                ANODES = 4'b0111;
                digit  = HEX[15:12];
            end

            default: begin
                ANODES = 4'b1111;
                digit  = 4'h0;
            end

        endcase

    end


    // ============================================================
    // Digit -> seven segment decoder
    //
    // CATHODES = {DP,G,F,E,D,C,B,A}
    // Active LOW
    // ============================================================

    always_comb begin

        case (digit)

            4'h0: CATHODES = 8'b11000000;
            4'h1: CATHODES = 8'b11111001;
            4'h2: CATHODES = 8'b10100100;
            4'h3: CATHODES = 8'b10110000;

            4'h4: CATHODES = 8'b10011001;
            4'h5: CATHODES = 8'b10010010;
            4'h6: CATHODES = 8'b10000010;
            4'h7: CATHODES = 8'b11111000;

            4'h8: CATHODES = 8'b10000000;
            4'h9: CATHODES = 8'b10010000;

            4'hA: CATHODES = 8'b10001000;
            4'hB: CATHODES = 8'b10000011;
            4'hC: CATHODES = 8'b11000110;
            4'hD: CATHODES = 8'b10100001;
            4'hE: CATHODES = 8'b10000110;
            4'hF: CATHODES = 8'b10001110;

            default:
                CATHODES = 8'b11111111;

        endcase

    end

endmodule