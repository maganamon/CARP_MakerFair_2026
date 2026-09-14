`timescale 1ns / 1ps

// Top level: reads simon/wire button sets, enforces the
// "one button per set" lock via buttons_manager, then drives
// an LED vector per set via btn_to_led.
module top_level (
    input  logic       clk,
    input  logic       rst,

    input  logic [3:0] simon_btns,
    input  logic [3:0] wire_btns,

    output logic [3:0] simon_led,
);

    logic [1:0] simon_sel, wire_sel;
    logic       simon_valid, wire_valid;

    buttons_manager u_buttons_manager (
        .clk         (clk),
        .rst         (rst),
        .simon_btns  (simon_btns),
        .wire_btns   (wire_btns),
        .simon_sel   (simon_sel),
        .wire_sel    (wire_sel),
        .simon_valid (simon_valid),
        .wire_valid  (wire_valid)
    );

    btn_to_led u_simon_led (
        .btn_pressed (simon_sel),
        .valid       (simon_valid),
        .out_led     (simon_led)
    );

endmodule