`default_nettype wire
`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Design: HT16K33 4-digit 14-segment display driver (I2C)
// Engineer: CARP
////////////////////////////////////////////////////////////////////////////////

/*
  Uses i2c_master.v from github.com/alexforencich/verilog-i2c (MIT license).
  Copy rtl/i2c_master.v from that repo into the project next to this file.

  What it sends (every transaction: START, address 0x70, bytes..., STOP):
    after power-up delay:  0x21            oscillator on
                           0x81            display on, no blink
                           0xE0|BRIGHTNESS dimming (0-15)
    then, and every time digit0..digit3 change:
                           0x00, d0[7:0], d0[15:8], d1[7:0], d1[15:8],
                                 d2[7:0], d2[15:8], d3[7:0], d3[15:8]

  digitN is the raw 16-bit segment pattern for that character (bit = segment),
  digit0 is the leftmost character.

  ack_error goes high (and stays high until rst) if the display ever fails to
  ACK a byte: wrong address, wiring, or no power. Handy on a spare LED.
*/

module ht16k33_driver #(
    parameter int         CLK_HZ         = 100_000_000,
    parameter int         I2C_HZ         = 100_000,      // 100 kHz standard mode
    parameter logic [6:0] I2C_ADDR       = 7'h70,        // default (no address jumpers)
    parameter logic [3:0] BRIGHTNESS     = 4'hF,         // 0 = dimmest, 15 = brightest
    parameter int         POWERUP_CYCLES = 1_000_000     // wait 10 ms @ 100 MHz before init
)(
    input  logic        clk,
    input  logic        rst,

    input  logic [15:0] digit0,     // leftmost character
    input  logic [15:0] digit1,
    input  logic [15:0] digit2,
    input  logic [15:0] digit3,     // rightmost character

    inout  wire         scl,        // I2C clock (open-drain)
    inout  wire         sda,        // I2C data  (open-drain)

    output logic        ack_error   // sticky: display did not answer
);

    localparam logic [15:0] PRESCALE = 16'(CLK_HZ / (I2C_HZ * 4));
    localparam int          PW       = $clog2(POWERUP_CYCLES + 1);

    // ------------------------------------------------------------------
    // Open-drain pins: only ever pull low or let go (pull-up makes the 1)
    // ------------------------------------------------------------------
    logic scl_i, scl_o, scl_t;
    logic sda_i, sda_o, sda_t;

    assign scl   = scl_t ? 1'bz : scl_o;
    assign sda   = sda_t ? 1'bz : sda_o;
    assign scl_i = scl;
    assign sda_i = sda;

    // ------------------------------------------------------------------
    // I2C master (alexforencich/verilog-i2c)
    // ------------------------------------------------------------------
    logic       cmd_valid, cmd_ready;
    logic [7:0] tx_data;
    logic       tx_valid, tx_ready, tx_last;
    logic       busy, missed_ack;

    /* verilator lint_off PINCONNECTEMPTY */
    i2c_master u_i2c (
        .clk                       (clk),
        .rst                       (rst),

        .s_axis_cmd_address        (I2C_ADDR),
        .s_axis_cmd_start          (1'b1),
        .s_axis_cmd_read           (1'b0),
        .s_axis_cmd_write          (1'b0),
        .s_axis_cmd_write_multiple (1'b1),      // send bytes until tx_last
        .s_axis_cmd_stop           (1'b1),      // STOP after the last byte
        .s_axis_cmd_valid          (cmd_valid),
        .s_axis_cmd_ready          (cmd_ready),

        .s_axis_data_tdata         (tx_data),
        .s_axis_data_tvalid        (tx_valid),
        .s_axis_data_tready        (tx_ready),
        .s_axis_data_tlast         (tx_last),

        .m_axis_data_tdata         (),          // no reads from the display
        .m_axis_data_tvalid        (),
        .m_axis_data_tready        (1'b1),
        .m_axis_data_tlast         (),

        .scl_i                     (scl_i),
        .scl_o                     (scl_o),
        .scl_t                     (scl_t),
        .sda_i                     (sda_i),
        .sda_o                     (sda_o),
        .sda_t                     (sda_t),

        .busy                      (busy),
        .bus_control               (),
        .bus_active                (),
        .missed_ack                (missed_ack),

        .prescale                  (PRESCALE),
        .stop_on_idle              (1'b0)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    // ------------------------------------------------------------------
    // Transactions: 0 = osc on, 1 = display on, 2 = brightness, 3 = digits
    // ------------------------------------------------------------------
    typedef enum logic [2:0] {
        S_POWERUP,      // let the display power up
        S_CMD,          // hand a START+address+STOP command to i2c_master
        S_DATA,         // feed the bytes of this transaction
        S_WAIT,         // wait for the STOP to finish
        S_IDLE          // up to date; resend digits when they change
    } state_t;

    state_t      state;
    logic [1:0]  txn;
    logic [3:0]  byte_idx;
    logic [PW-1:0] pwr_cnt;
    logic [63:0] digits_in, snap, shown;

    assign digits_in = {digit3, digit2, digit1, digit0};

    // Byte `i` of transaction `t` (digits come from the snapshot)
    function automatic logic [7:0] tx_byte(input logic [1:0] t, input logic [3:0] i,
                                           input logic [63:0] d);
        case (t)
            2'd0:    tx_byte = 8'h21;
            2'd1:    tx_byte = 8'h81;
            2'd2:    tx_byte = {4'hE, BRIGHTNESS};
            default: tx_byte = (i == 4'd0) ? 8'h00 : d[(int'(i) - 1) * 8 +: 8];
        endcase
    endfunction

    assign tx_data   = tx_byte(txn, byte_idx, snap);
    assign tx_last   = (txn == 2'd3) ? (byte_idx == 4'd8) : 1'b1;
    assign cmd_valid = (state == S_CMD);
    assign tx_valid  = (state == S_DATA);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_POWERUP;
            txn       <= 2'd0;
            byte_idx  <= '0;
            pwr_cnt   <= '0;
            snap      <= '0;
            shown     <= '0;
            ack_error <= 1'b0;
        end else begin
            if (missed_ack) ack_error <= 1'b1;

            case (state)
                S_POWERUP: begin
                    if (pwr_cnt == PW'(POWERUP_CYCLES)) begin
                        txn   <= 2'd0;
                        state <= S_CMD;
                    end else begin
                        pwr_cnt <= pwr_cnt + 1'b1;
                    end
                end

                S_CMD: begin
                    if (cmd_ready) begin
                        byte_idx <= '0;
                        state    <= S_DATA;
                    end
                end

                S_DATA: begin
                    if (tx_ready) begin
                        if (tx_last) state    <= S_WAIT;
                        else         byte_idx <= byte_idx + 1'b1;
                    end
                end

                S_WAIT: begin
                    if (!busy) begin
                        if (txn == 2'd3) begin
                            shown <= snap;            // display now shows snap
                            state <= S_IDLE;
                        end else begin
                            if (txn == 2'd2) snap <= digits_in;
                            txn   <= txn + 1'b1;
                            state <= S_CMD;
                        end
                    end
                end

                S_IDLE: begin
                    if (digits_in != shown) begin
                        snap  <= digits_in;
                        txn   <= 2'd3;
                        state <= S_CMD;
                    end
                end

                default: state <= S_POWERUP;
            endcase
        end
    end

endmodule
`default_nettype wire
