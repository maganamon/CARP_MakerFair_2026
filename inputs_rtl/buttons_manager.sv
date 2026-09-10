`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Design: Buttons Manager
// Engineer: Rodolfo Magana
//////////////////////////////////////////////////////////////////////////////////

/*
    This is a button manager that will include:
    - 2 x 2 array button manager
    - probing
    - 1 input at a time
    - only one output while a button is held
    - ignores other buttons until original button is released

    Button mapping:

                col1    col2
              ----------------
      row1    |  00  |   01  |
      row2    |  10  |   11  |

*/

module buttons_manager(
    input  logic       clk,
    input  logic       rst,

    input  logic       col1,
    input  logic       col2,

    output logic       row1,
    output logic       row2,

    output logic       btn_VALID,
    output logic [1:0] button_pressed
);

    logic [1:0] detect_btn;

    assign detect_btn = {col2, col1};


    typedef enum logic [2:0] {
        WAIT_INPUT,
        PROBE_ALL,
        PROBE_ROW1,
        PROBE_ROW2,
        WAIT_RELEASE
    } state_t;

    state_t state;


    always_ff @(posedge clk) begin

        if (rst) begin

            state          <= PROBE_ROW1;

            row1           <= 1'b1;
            row2           <= 1'b1;

            btn_VALID      <= 1'b0;
            button_pressed <= 2'b00;

        end

        else begin

            // Default:
            // btn_VALID only stays high for one clock
            btn_VALID <= 1'b0;


            case (state)

                ////////////////////////////////////////////////////////
                // Probe Row 1
                ////////////////////////////////////////////////////////
                WAIT_INPUT: begin
                    row1 <= 1'b1;
                    row2 <= 1'b1;
                    state <= PROBE_ALL;
                end

                PROBE_ALL: begin
                    row1 <= 1'b1;
                    row2 <= 1'b1;
                    if (detect_btn > 2'b00)
                        state <= PROBE_ROW1;
                    else
                        state <= WAIT_INPUT;
                end

                PROBE_ROW1: begin

                    row1 <= 1'b1;
                    row2 <= 1'b0;

                    if (detect_btn == 2'b01) begin

                        // Row 1, Column 1
                        button_pressed <= 2'b00;
                        btn_VALID      <= 1'b1;

                        state <= WAIT_RELEASE;

                    end

                    else if (detect_btn == 2'b10) begin

                        // Row 1, Column 2
                        button_pressed <= 2'b01;
                        btn_VALID      <= 1'b1;

                        state <= WAIT_RELEASE;

                    end

                    else begin

                        // Nothing found on Row 1.
                        // Probe Row 2 next.
                        state <= PROBE_ROW2;

                    end

                end


                ////////////////////////////////////////////////////////
                // Probe Row 2
                ////////////////////////////////////////////////////////

                PROBE_ROW2: begin

                    row1 <= 1'b0;
                    row2 <= 1'b1;

                    if (detect_btn == 2'b01) begin

                        // Row 2, Column 1
                        button_pressed <= 2'b10;
                        btn_VALID      <= 1'b1;

                        state <= WAIT_RELEASE;

                    end

                    else if (detect_btn == 2'b10) begin

                        // Row 2, Column 2
                        button_pressed <= 2'b11;
                        btn_VALID      <= 1'b1;

                        state <= WAIT_RELEASE;

                    end

                    else begin

                        // Nothing found.
                        // Go back and probe Row 1.
                        state <= PROBE_ROW1;

                    end

                end


                ////////////////////////////////////////////////////////
                // Button has already been registered.
                //
                // Ignore EVERYTHING until all buttons are released.
                ////////////////////////////////////////////////////////

                WAIT_RELEASE: begin

                    // Drive both rows so that we can detect whether
                    // any button is still being held.
                    row1 <= 1'b1;
                    row2 <= 1'b1;


                    // Both columns low means no buttons detected
                    //
                    // NOTE:
                    // This assumes your buttons produce logic 1 when
                    // pressed.
                    if (detect_btn == 2'b00) begin

                        state <= WAIT_INPUT;

                    end

                end


                default: begin

                    state <= WAIT_INPUT;

                end

            endcase

        end

    end

endmodule
