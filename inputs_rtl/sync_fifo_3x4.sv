`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Design: 3-deep, 4-bit-wide synchronous FIFO with a non-destructive
//         "cycle" pointer for playback of the stored entries.
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  - push/wr_data: standard FIFO write (ignored if full)
  - pop: standard FIFO read/consume (ignored if empty); rd_data shows
         the entry at rd_ptr combinationally
  - cycle_data / cycle_done_tgl: non-destructive playback of the valid
    entries (0 .. count-1), 1 tick ON + 1 tick OFF per entry:

        push   tick   tick   tick   tick   tick   tick
          |  s0  | off  |  s1  | off  |  s2  | off  |  s0  ...

        cycle_done_tgl = 0 -> ON  (show cycle_data)
        cycle_done_tgl = 1 -> OFF (gap between entries)

    Every push restarts playback at entry 0, ON. The Simon FSM pushes one
    new step right before each playback, so every playback starts with the
    first step and shows the steps in order. After the last entry it wraps
    back to entry 0 and keeps repeating.

      count == 0 -> cycle_data outputs 4'b0000 (nothing valid yet)
*/

module sync_fifo_3x4 #(
    parameter int DEPTH = 3,
    parameter int WIDTH = 4
)(
    input  logic             clk,
    input  logic             tick,   // playback steps once per tick pulse
    input  logic             rst,

    // write side
    input  logic             push,
    input  logic [WIDTH-1:0] wr_data,

    // read side (destructive)
    input  logic             pop,
    output logic [WIDTH-1:0] rd_data,

    // cycle side (non-destructive, tick-driven playback)
    output logic [WIDTH-1:0] cycle_data,
    output logic             cycle_done_tgl,   // 0 = entry ON, 1 = gap (OFF)

    output logic full,
    output logic empty
);

    localparam int PTR_W = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [DEPTH-1:0];

    logic [PTR_W-1:0] wr_ptr;
    logic [PTR_W-1:0] rd_ptr;
    logic [PTR_W-1:0] cycle_ptr;
    logic [PTR_W-1:0] count;   // number of valid entries (0..DEPTH)

    logic do_push, do_pop;

    assign full    = (count == DEPTH[PTR_W-1:0]);
    assign empty   = (count == '0);
    assign do_push = push && !full;
    assign do_pop  = pop  && !empty;

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
            if (do_push) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= (wr_ptr == PTR_W'(DEPTH-1)) ? '0 : wr_ptr + 1'b1;
            end

            if (do_pop) begin
                rd_ptr <= (rd_ptr == PTR_W'(DEPTH-1)) ? '0 : rd_ptr + 1'b1;
            end

            case ({do_push, do_pop})
                2'b10:   count <= count + 1'b1;   // push only
                2'b01:   count <= count - 1'b1;   // pop only
                default: count <= count;          // none, or push+pop (net 0)
            endcase
        end
    end

    assign rd_data = mem[rd_ptr];

    // ------------------------------------------------------------------
    // Playback: each tick goes ON -> OFF, or OFF -> next entry ON.
    // A push restarts playback at entry 0, ON.
    // ------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_ptr      <= '0;
            cycle_done_tgl <= 1'b0;
        end
        else if (do_push) begin
            cycle_ptr      <= '0;                    // new sequence: start at step 1
            cycle_done_tgl <= 1'b0;                  // ... and show it
        end
        else if (count == '0) begin
            cycle_ptr      <= '0;                    // nothing stored
            cycle_done_tgl <= 1'b0;
        end
        else if (tick) begin
            if (!cycle_done_tgl) begin
                cycle_done_tgl <= 1'b1;              // ON -> OFF (gap)
            end
            else begin
                cycle_done_tgl <= 1'b0;              // OFF -> next entry ON
                if (cycle_ptr >= count - 1'b1)
                    cycle_ptr <= '0;                 // wrap after the last entry
                else
                    cycle_ptr <= cycle_ptr + 1'b1;
            end
        end
        // else: no tick this cycle -> hold
    end

    assign cycle_data = (count == '0) ? '0 : mem[cycle_ptr];

endmodule
