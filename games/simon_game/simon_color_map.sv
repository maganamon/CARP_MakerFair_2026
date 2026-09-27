`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Simon colour translation (depends on strikes)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  Colour index (LEDs and buttons):  0 = blue, 1 = yellow, 2 = green, 3 = red

  The LED that lights tells the player which button to press, and the
  rule changes with the number of strikes (lives lost, from lives_manager):

             LED shown:         blue    yellow   green    red
             ---------------------------------------------------------
    0 strikes -> press:         red     green    yellow   blue
    1 strike  -> press:         yellow  blue     red      green
    2 strikes -> press:         green   red      blue     yellow

  The blue column is the one you specified. The other columns are my
  suggestion (each row swaps colours in pairs, so every colour changes
  meaning at every strike level). Edit btn_for_led() to change the rules.

  This module works backwards: it takes the button the player pressed and
  outputs the LED colour that button answers for, so simon_fsm can keep
  comparing against the LED colours it stored. The FSM does not change.
*/

module simon_color_map (
    input  logic [1:0] strikes,     // 0, 1 or 2 lives lost
    input  logic [3:0] btn_in,      // one-hot button pressed (simon_signal)
    output logic [3:0] led_equiv    // one-hot LED colour that button answers
);

    // Which button (0-3) the player must press when LED `led` (0-3) lights
    function automatic logic [1:0] btn_for_led(input logic [1:0] s, input logic [1:0] led);
        case (s)
            2'd0: case (led)                 // 0 strikes
                      2'd0:    btn_for_led = 2'd3;   // blue   -> red
                      2'd1:    btn_for_led = 2'd2;   // yellow -> green
                      2'd2:    btn_for_led = 2'd1;   // green  -> yellow
                      default: btn_for_led = 2'd0;   // red    -> blue
                  endcase
            2'd1: case (led)                 // 1 strike
                      2'd0:    btn_for_led = 2'd1;   // blue   -> yellow
                      2'd1:    btn_for_led = 2'd0;   // yellow -> blue
                      2'd2:    btn_for_led = 2'd3;   // green  -> red
                      default: btn_for_led = 2'd2;   // red    -> green
                  endcase
            default: case (led)              // 2 strikes
                      2'd0:    btn_for_led = 2'd2;   // blue   -> green
                      2'd1:    btn_for_led = 2'd3;   // yellow -> red
                      2'd2:    btn_for_led = 2'd0;   // green  -> blue
                      default: btn_for_led = 2'd1;   // red    -> yellow
                  endcase
        endcase
    endfunction

    // Find the LED whose required button is the one pressed
    always_comb begin
        led_equiv = 4'b0000;                 // no button (or not one-hot) -> no match
        for (int l = 0; l < 4; l++) begin
            if (btn_in == (4'b0001 << btn_for_led(strikes, l[1:0])))
                led_equiv = 4'b0001 << l;
        end
    end

endmodule
