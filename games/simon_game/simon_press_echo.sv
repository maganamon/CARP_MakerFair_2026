`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Simon button press -> 1-cycle pulse + LED echo for one tick
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  button_lock's `valid` stays high for as long as the button is held
  (millions of clocks). Two things need something different:

  press_pulse : 1 clock high on the press itself. simon_fsm expects this;
                with the level signal it would see the same press on every
                clock and count it again against the next step.

  echo_on / echo_led : show the pressed button on the Simon LEDs for one
                full tick period, however short the press was. The echo
                turns off on the 2nd tick after the press, so it stays on
                for between 1 and 2 seconds (the press can land anywhere
                inside a tick period).
*/

module simon_press_echo (
    input  logic       clk,
    input  logic       rst,
    input  logic       tick,          // 1 Hz tick
    input  logic       valid,         // simon_valid from buttons_manager (level)
    input  logic [3:0] btn,           // simon_signal from buttons_manager

    output logic       press_pulse,   // 1 clock per press -> simon_fsm.btn_valid
    output logic       echo_on,       // -> simon_led_controller.valid
    output logic [3:0] echo_led       // -> simon_led_controller.btn_pressed
);

    logic valid_d;
    logic tick_seen;

    // Rising edge of valid = the moment the button is pressed
    always_ff @(posedge clk or posedge rst) begin
        if (rst) valid_d <= 1'b0;
        else     valid_d <= valid;
    end

    assign press_pulse = valid & ~valid_d;

    // Hold the pressed button on the LEDs for one full tick
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            echo_on   <= 1'b0;
            echo_led  <= 4'b0000;
            tick_seen <= 1'b0;
        end else if (press_pulse) begin
            echo_on   <= 1'b1;
            echo_led  <= btn;
            tick_seen <= 1'b0;
        end else if (echo_on && tick) begin
            if (tick_seen) begin
                echo_on  <= 1'b0;
                echo_led <= 4'b0000;
            end else begin
                tick_seen <= 1'b1;
            end
        end
    end

endmodule

/*

tick_1hz     _|‾|__________________|‾|__________________|‾|________
button       ____|‾‾‾|_____________________________________________
valid        ____|‾‾‾|_____________________________________________   (level, as long as held)
press_pulse  ____|‾|_______________________________________________   (1 clock → FSM)
tick_seen    ______________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|__________
echo_on      ____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_________   (LED lit ~2 s here)
echo_led     ----< btn >------------------------------------< 0 >--

*/
