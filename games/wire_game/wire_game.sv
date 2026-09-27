`timescale 1ns / 1ps

module wire_game_fsm(
    input  logic [2:0] serial_number_idx,
    input  logic [3:0] btn_pressed,  // one-hot from button_lock
    input  logic       btn_valid,    // from button_lock

    output logic       win,
    output logic       wrong
);

// 0: B7K2 : Green
// 1: A4M6 : Red
// 2: T3R8 : Blue
// 3: E5N3 : Blue
// 4: C1L4 : Yellow
// 5: O7P1 : Yellow
// 6: Z9D2 : Red
// 7: U2X8 : Green
// Top wire : yellow : button 0
// 2nd wire : red : button 1
// 3rd wire : green : button 2
// 4th wire : blue : button 3

always_comb
begin
    win = 1'b0;
    wrong = 1'b0;
    if (  serial_number_idx == 3'd0 || serial_number_idx == 3'd7 ) // green
    begin
        if ( btn_valid && btn_pressed[2] ) win = 1'b1;
        else if ( btn_valid ) wrong = 1'b1;
    end
    if ( serial_number_idx == 3'd1 || serial_number_idx == 3'd6 ) // red
    begin
        if ( btn_valid && btn_pressed[1] ) win = 1'b1;
        else if ( btn_valid ) wrong = 1'b1;
    end
    if ( serial_number_idx == 3'd2 || serial_number_idx == 3'd3 ) // blue
    begin
        if ( btn_valid && btn_pressed[3] ) win = 1'b1;
        else if ( btn_valid ) wrong = 1'b1;
    end
    if ( serial_number_idx == 3'd4 || serial_number_idx == 3'd5 ) // yellow
    begin
        if ( btn_valid && btn_pressed[0] ) win = 1'b1;
        else if ( btn_valid ) wrong = 1'b1;
    end
end

endmodule