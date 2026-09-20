//------------------------------------------------------------------------
// button_lock
//
// Generic single-group button arbiter/lock.
// - Accepts a press only if exactly one bit of `btns` is high (one-hot).
// - Once accepted, latches that button and asserts `valid`.
// - Ignores all other buttons in the group while locked.
// - Unlocks only when the entire group returns to 0 (full release).
//------------------------------------------------------------------------
module button_lock #(
    parameter int WIDTH = 4
)(
    input  logic             clk,
    input  logic             rst,
 
    input  logic [WIDTH-1:0] btns,
 
    output logic [WIDTH-1:0] signal_out,
    output logic             valid
);
 
    logic             locked;
    logic [WIDTH-1:0] locked_btn;
 
    // True only if exactly one bit of btns is set.
    // (btns & (btns-1)) clears the lowest set bit; if the result is 0,
    // there was at most one bit set to begin with.
    logic one_hot;
    assign one_hot = (btns != '0) && ((btns & (btns - 1'b1)) == '0);
 
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            locked     <= 1'b0;
            locked_btn <= '0;
        end else begin
            if (!locked) begin
                // Only latch on a clean single-button press
                if (one_hot) begin
                    locked     <= 1'b1;
                    locked_btn <= btns;
                end
            end else begin
                // Stay locked, ignoring any other button presses,
                // until the whole group is released.
                if (btns == '0) begin
                    locked     <= 1'b0;
                    locked_btn <= '0;
                end
            end
        end
    end
 
    assign signal_out = locked ? locked_btn : '0;
    assign valid      = locked;
 
endmodule
