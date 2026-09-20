`timescale 1ns / 1ps

// One-hot -> binary encoder.
// Takes a one-hot 4-bit press (e.g. from buttons_manager's
// simon_signal/wire_signal) and encodes it to a 2-bit index,
// for comparing against a stored/expected 2-bit sequence value.
module btn_to_led(

    input  logic [3:0] btn_pressed,
    output  logic       valid,

    output logic [1:0] out_led

);

    always_comb begin
        // Default: no valid button press
        out_led = 2'b00;
        valid = 1'b0;

        if (valid) begin
            case (btn_pressed)
                4'b0001: begin
                    out_led = 2'b00;
                    valid = 1'b0;
                end
                4'b0010: begin
                    out_led = 2'b01;
                    valid = 1'b0;
                end
                4'b0100: begin
                    out_led = 2'b10;
                    valid = 1'b0;
                end
                4'b1000: begin
                    out_led = 2'b11;
                    valid = 1'b0;
                end
                default: begin
                    out_led = 2'b00;
                    valid = 1'b0;
                end

            endcase
        end

    end

endmodule
