`timescale 1ns / 1ps

module btn_to_led(

    input  logic [3:0] btn_pressed,
    input  logic       valid,

    output logic [3:0] out_led

);

    always_comb begin

        // Default: no valid button press
        out_led = 4'b0000;

        if (valid) begin
            case (btn_pressed)

                4'b0001: out_led = 4'b0001;
                4'b0010: out_led = 4'b0010;
                4'b0100: out_led = 4'b0100;
                4'b1000: out_led = 4'b1000;

                default: out_led = 4'b0000;

            endcase
        end

    end

endmodule