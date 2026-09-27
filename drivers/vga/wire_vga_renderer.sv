`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: Wire game VGA picture (640x480)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  Draws the wire panel from the pixel position given by display_480p:

      black background
      grey terminal block on the left and on the right
      4 wires, top to bottom: yellow, red, white, blue
      each wire steps down half way:

          ####====================#
          ####                    #
          ####                    #=====================####
                                                        ####

      cut[i] = 1 -> a gap in the middle of wire i, with a copper-coloured
      tip on each cut end:

          ####=============o            o===================####

  win  = 1 -> the whole screen is green (bomb defused)
  lose = 1 -> the whole screen is red   (out of time or out of lives)
  (win wins if both are ever set.)

  cut, win and lose come from the 100 MHz domain; they are synchronized
  here (2 flip-flops each).
  Output colour, hsync and vsync are registered together so they stay lined up.
*/

module wire_vga_renderer (
    input  logic               clk_pix,
    input  logic signed [15:0] sx,          // from display_480p
    input  logic signed [15:0] sy,
    input  logic               de,
    input  logic               hsync_in,
    input  logic               vsync_in,

    input  logic [3:0]         cut,         // 100 MHz domain: wire i has been cut
    input  logic               win,         // 100 MHz domain: whole screen green
    input  logic               lose,        // 100 MHz domain: whole screen red

    output logic [3:0]         vga_r,
    output logic [3:0]         vga_g,
    output logic [3:0]         vga_b,
    output logic               vga_hsync,
    output logic               vga_vsync
);

    // ------------------------------------------------------------------
    // Layout (pixels)
    // ------------------------------------------------------------------
    localparam int BLOCK_Y0 = 70;           // terminal blocks, top and bottom
    localparam int BLOCK_Y1 = 420;
    localparam int BLK_L_X0 = 40;           // left block
    localparam int BLK_L_X1 = 120;
    localparam int BLK_R_X0 = 520;          // right block
    localparam int BLK_R_X1 = 600;

    localparam int WIRE_Y0  = 100;          // top edge of wire 0 (left part)
    localparam int SPACING  = 80;           // between wires
    localparam int WIRE_W   = 16;           // wire thickness
    localparam int DROP     = 32;           // step down in the middle
    localparam int JOG_X    = 320;          // x of the vertical step

    localparam int SCREW_L  = 88;           // screw heads on the blocks
    localparam int SCREW_R  = 528;
    localparam int SCREW_W  = 24;

    localparam int GAP_X0   = 288;          // gap when a wire is cut
    localparam int GAP_X1   = 368;
    localparam int TIP_W    = 6;            // copper tip at each cut end

    // Colours {R,G,B}, 4 bits each
    localparam logic [11:0] C_BLACK  = 12'h000;
    localparam logic [11:0] C_GREY   = 12'h888;
    localparam logic [11:0] C_SCREW  = 12'h444;
    localparam logic [11:0] C_COPPER = 12'hD71;
    localparam logic [11:0] C_WIN    = 12'h0F0;   // full-screen green
    localparam logic [11:0] C_LOSE   = 12'hF00;   // full-screen red

    function automatic logic [11:0] wire_color(input int i);
        case (i)
            0:       wire_color = 12'hFF0;  // yellow (top)
            1:       wire_color = 12'hF00;  // red
            2:       wire_color = 12'hFFF;  // white
            default: wire_color = 12'h24F;  // blue (bottom)
        endcase
    endfunction

    // ------------------------------------------------------------------
    // cut / win / lose: 100 MHz -> pixel clock
    // ------------------------------------------------------------------
    logic [3:0] cut_s0, cut_s1;
    logic       win_s0, win_s1;
    logic       lose_s0, lose_s1;

    always_ff @(posedge clk_pix) begin
        cut_s0  <= cut;
        cut_s1  <= cut_s0;
        win_s0  <= win;
        win_s1  <= win_s0;
        lose_s0 <= lose;
        lose_s1 <= lose_s0;
    end

    // ------------------------------------------------------------------
    // Pixel colour
    // ------------------------------------------------------------------
    int          x, y;
    logic [11:0] pix;

    assign x = int'(sx);
    assign y = int'(sy);

    always_comb begin
        pix = C_BLACK;

        // terminal blocks
        if (y >= BLOCK_Y0 && y < BLOCK_Y1 &&
            ((x >= BLK_L_X0 && x < BLK_L_X1) || (x >= BLK_R_X0 && x < BLK_R_X1)))
            pix = C_GREY;

        for (int i = 0; i < 4; i++) begin
            // screw heads where each wire is clamped
            if (x >= SCREW_L && x < SCREW_L + SCREW_W &&
                y >= WIRE_Y0 + i*SPACING - 4 && y < WIRE_Y0 + i*SPACING + WIRE_W + 4)
                pix = C_SCREW;
            if (x >= SCREW_R && x < SCREW_R + SCREW_W &&
                y >= WIRE_Y0 + i*SPACING + DROP - 4 && y < WIRE_Y0 + i*SPACING + DROP + WIRE_W + 4)
                pix = C_SCREW;

            // wire body: left run, vertical step, right run
            if ((y >= WIRE_Y0 + i*SPACING && y < WIRE_Y0 + i*SPACING + WIRE_W &&
                 x >= SCREW_L + 8 && x < JOG_X + WIRE_W) ||
                (x >= JOG_X && x < JOG_X + WIRE_W &&
                 y >= WIRE_Y0 + i*SPACING && y < WIRE_Y0 + i*SPACING + DROP + WIRE_W) ||
                (y >= WIRE_Y0 + i*SPACING + DROP && y < WIRE_Y0 + i*SPACING + DROP + WIRE_W &&
                 x >= JOG_X && x < SCREW_R + SCREW_W - 8)) begin

                if (cut_s1[i] && x >= GAP_X0 && x < GAP_X1)
                    pix = C_BLACK;                                   // the gap
                else if (cut_s1[i] && ((x >= GAP_X0 - TIP_W && x < GAP_X0) ||
                                       (x >= GAP_X1 && x < GAP_X1 + TIP_W)))
                    pix = C_COPPER;                                  // cut ends
                else
                    pix = wire_color(i);
            end
        end

        // end of the game: paint over everything
        if (win_s1)
            pix = C_WIN;
        else if (lose_s1)
            pix = C_LOSE;
    end

    // ------------------------------------------------------------------
    // Registered outputs (colour + syncs stay aligned)
    // ------------------------------------------------------------------
    always_ff @(posedge clk_pix) begin
        vga_hsync <= hsync_in;
        vga_vsync <= vsync_in;
        {vga_r, vga_g, vga_b} <= de ? pix : C_BLACK;
    end

endmodule
