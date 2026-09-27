`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: VGA output for the wire game (640x480 @ 60 Hz)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  Glue between the 100 MHz design and the VGA port:

    clock_480p   (Project F, MIT)  100 MHz -> 25.2 MHz pixel clock (MMCM)
    display_480p (Project F, MIT)  640x480 timing: hsync, vsync, de, sx, sy
    wire_vga_renderer              draws the wires (gap where cut[i] = 1)

  Get the two Project F files from github.com/projf/projf-explore:
    lib/clock/xc7/clock_480p.sv    -> drivers/vga/clock_480p.sv
    lib/display/display_480p.sv    -> drivers/vga/display_480p.sv

  clock_480p uses the Xilinx MMCME2_BASE and BUFG primitives. Vivado has
  them built in. For Icarus / Verilator, add tb/sim_models/xilinx_sim_models.sv
  to the simulation file list (simple stand-ins; never used by Vivado).
*/

module vga_wires (
    input  logic       clk,         // 100 MHz
    input  logic [3:0] cut,         // wire i has been cut (100 MHz domain)
    input  logic       win,         // whole screen green (100 MHz domain)
    input  logic       lose,        // whole screen red   (100 MHz domain)

    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,
    output logic       vga_hsync,
    output logic       vga_vsync
);

    logic clk_pix;
    logic clk_pix_locked;

    /* verilator lint_off PINCONNECTEMPTY */
    clock_480p u_clock (                    // 25.2 MHz pixel clock from the MMCM
        .clk_100m       (clk),
        .rst            (1'b0),             // MMCM locks on its own after configuration
        .clk_pix        (clk_pix),
        .clk_pix_5x     (),                 // only needed for HDMI
        .clk_pix_locked (clk_pix_locked)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    // Hold the timing generator in reset until the pixel clock is stable
    logic rst_pix;
    assign rst_pix = ~clk_pix_locked;

    logic               hsync, vsync, de;
    logic signed [15:0] sx, sy;

    /* verilator lint_off PINCONNECTEMPTY */
    display_480p u_timing (
        .clk_pix (clk_pix),
        .rst_pix (rst_pix),
        .hsync   (hsync),
        .vsync   (vsync),
        .de      (de),
        .frame   (),
        .line    (),
        .sx      (sx),
        .sy      (sy)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    wire_vga_renderer u_render (
        .clk_pix   (clk_pix),
        .sx        (sx),
        .sy        (sy),
        .de        (de),
        .hsync_in  (hsync),
        .vsync_in  (vsync),
        .cut       (cut),
        .win       (win),
        .lose      (lose),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .vga_hsync (vga_hsync),
        .vga_vsync (vga_vsync)
    );

endmodule