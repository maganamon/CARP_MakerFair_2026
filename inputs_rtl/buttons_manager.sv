`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Design: Buttons Manager
// Engineer: CARP
//////////////////////////////////////////////////////////////////////////////////


module buttons_manager(
    input  logic       clk,
    input  logic       rst,

    input logic [3:0] simon_btns,
    input logic [3:0] wire_btns,

    // output signals
    output logic [3:0] simon_signal,
    output logic [3:0] wire_signal,

    output logic       simon_valid,
    output logic       wire_valid
);


    button_lock #(.WIDTH(4)) simon_lock (
        .clk        (clk),
        .rst        (rst),
        .btns       (simon_btns),
        .signal_out (simon_signal),
        .valid      (simon_valid)
    );
 
    button_lock #(.WIDTH(4)) wire_lock (
        .clk        (clk),
        .rst        (rst),
        .btns       (wire_btns),
        .signal_out (wire_signal),
        .valid      (wire_valid)
    );

endmodule
