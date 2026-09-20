`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Design: 3-deep, 4-bit-wide synchronous FIFO with a non-destructive
//         "cycle" pointer for continuous playback of stored entries.
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  - push/wr_data: standard FIFO write (ignored if full)
  - pop: standard FIFO read/consume (ignored if empty); rd_data shows
         the entry at rd_ptr combinationally
  - cycle_data: a free-running, non-destructive pointer that advances
    once per `tick` pulse, walking through only the currently VALID
    entries (0 .. count-1), wrapping back to index 0 at the end.
      count == 0 -> cycle_data outputs 4'b0000 (nothing valid yet)
      count == 1 -> cycle_ptr stays at 0, cycle_data holds that 1 item
      count == 2 -> cycle_ptr toggles 0,1,0,1,... (one step per tick)
      count == 3 -> cycle_ptr walks 0,1,2,0,1,2,... (one step per tick)
  - cycle_done_tgl: flips (0->1 or 1->0) every time cycle_ptr wraps
    back to index 0, i.e. every time one full pass through the valid
    entries completes. Downstream logic can edge-detect this signal
    (compare against its previous value) to get a one-shot "playback
    pass complete" event, without needing to catch a single-cycle pulse.
*/

module sync_fifo_3x4 #(
    parameter int DEPTH = 3,
    parameter int WIDTH = 4
)(
    input  logic             clk,
    input  logic             tick,   // cycle_ptr advances once per tick pulse
    input  logic             rst,

    // write side
    input  logic             push,
    input  logic [WIDTH-1:0] wr_data,

    // read side (destructive)
    input  logic             pop,
    output logic [WIDTH-1:0] rd_data,

    // cycle side (non-destructive, tick-driven display pointer)
    output logic [WIDTH-1:0] cycle_data,
    output logic             cycle_done_tgl,

    output logic full,
    output logic empty
);

    localparam int PTR_W = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [DEPTH-1:0];

    logic [PTR_W-1:0] wr_ptr;
    logic [PTR_W-1:0] rd_ptr;
    logic [PTR_W-1:0] cycle_ptr;
    logic [PTR_W-1:0] count;   // number of valid entries (0..DEPTH)

    assign full  = (count == DEPTH[PTR_W-1:0]);
    assign empty = (count == '0);

    // ------------------------------------------------------------------
    // Write / read pointers + count
    // ------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end
        else begin
            if (push && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1'b1;
            end

            if (pop && !empty) begin
                rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1'b1;
            end

            case ({push && !full, pop && !empty})
                2'b10:   count <= count + 1'b1;   // push only
                2'b01:   count <= count - 1'b1;   // pop only
                default: count <= count;          // none, or push+pop (net 0)
            endcase
        end
    end

    assign rd_data = mem[rd_ptr];

    // ------------------------------------------------------------------
    // Cycle pointer: advances once per `tick`, wraps at (count - 1),
    // not (DEPTH - 1). cycle_done_tgl flips on every wrap event.
    // ------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_ptr      <= '0;
            cycle_done_tgl <= 1'b0;
        end
        else if (count == '0) begin
            cycle_ptr <= '0;
            // no valid entries -> no completed passes; leave cycle_done_tgl as-is
        end
        else if (tick) begin
            if (cycle_ptr >= count - 1'b1) begin
                cycle_ptr      <= '0;
                cycle_done_tgl <= ~cycle_done_tgl;   // one full pass just completed
            end
            else begin
                cycle_ptr <= cycle_ptr + 1'b1;
            end
        end
        // else: no tick this cycle -> hold cycle_ptr and cycle_done_tgl
    end

    assign cycle_data = (count == '0) ? '0 : mem[cycle_ptr];

endmodule