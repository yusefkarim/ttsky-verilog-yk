/*
 * Copyright (c) 2024 Tiny Tapeout LTD
 * SPDX-License-Identifier: Apache-2.0
 *
 * A shameless RISC-V Ottawa promo: three text messages bouncing DVD-screensaver style
 * around a 640x480 VGA frame. When two or more messages overlap, the
 * overlap region renders an XOR overlay of the message glyphs in a
 * strobing palette colour, with a dim halo over the rest of the overlap
 * rectangle so collisions read as a glowing flash.
 */

`default_nettype none

parameter DISPLAY_WIDTH  = 640;
parameter DISPLAY_HEIGHT = 480;
parameter MSG_W          = 128;
parameter MSG_H          = 32;
parameter CHIP_SIZE      = 32;
parameter CHIP_X         = 304;  // centered: (640 - 32) / 2
parameter CHIP_Y         = 224;  // centered: (480 - 32) / 2

module tt_um_vga_yusefkarim (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // VGA signals
  wire hsync;
  wire vsync;
  reg  [1:0] R;
  reg  [1:0] G;
  reg  [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused-input warnings (ui_in / uio_in / ena currently unused)
  wire _unused_inputs = &{ena, ui_in, uio_in};

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  // ---------------------------------------------------------------
  // Three bouncer state vectors. msg_id is implicit from the index
  // (bouncer i reads ROM band y in [i*32 .. i*32+31]).
  // ---------------------------------------------------------------
  reg [9:0] pos_x0, pos_x1, pos_x2;
  reg [9:0] pos_y0, pos_y1, pos_y2;
  reg       dir_x0, dir_x1, dir_x2;
  reg       dir_y0, dir_y1, dir_y2;
  reg [2:0] color0, color1, color2;

  reg [9:0] prev_y;
  reg [7:0] frame_counter;

  // ---------------------------------------------------------------
  // Per-pixel: bbox tests, ROM lookups, composition
  // ---------------------------------------------------------------
  wire in0 = (pix_x >= pos_x0) && (pix_x < pos_x0 + MSG_W) &&
             (pix_y >= pos_y0) && (pix_y < pos_y0 + MSG_H);
  wire in1 = (pix_x >= pos_x1) && (pix_x < pos_x1 + MSG_W) &&
             (pix_y >= pos_y1) && (pix_y < pos_y1 + MSG_H);
  wire in2 = (pix_x >= pos_x2) && (pix_x < pos_x2 + MSG_W) &&
             (pix_y >= pos_y2) && (pix_y < pos_y2 + MSG_H);

  // Local coords (only meaningful when in_boxN is true, where the
  // difference is guaranteed to fit in MSG_W / MSG_H).
  wire [9:0] dx0 = pix_x - pos_x0;
  wire [9:0] dx1 = pix_x - pos_x1;
  wire [9:0] dx2 = pix_x - pos_x2;
  wire [9:0] dy0 = pix_y - pos_y0;
  wire [9:0] dy1 = pix_y - pos_y1;
  wire [9:0] dy2 = pix_y - pos_y2;
  wire [6:0] lx0 = dx0[6:0];
  wire [6:0] lx1 = dx1[6:0];
  wire [6:0] lx2 = dx2[6:0];
  wire [4:0] ly0 = dy0[4:0];
  wire [4:0] ly1 = dy1[4:0];
  wire [4:0] ly2 = dy2[4:0];
  // Chip sprite (32x32) anchored at (CHIP_X, CHIP_Y).
  wire in_chip = (pix_x >= CHIP_X) && (pix_x < CHIP_X + CHIP_SIZE) &&
                 (pix_y >= CHIP_Y) && (pix_y < CHIP_Y + CHIP_SIZE);
  wire [9:0] dxc = pix_x - CHIP_X;
  wire [9:0] dyc = pix_y - CHIP_Y;
  wire [4:0] lxc = dxc[4:0];
  wire [4:0] lyc = dyc[4:0];

  // Chip rotation frame index: low bits of frame_counter so the chip
  // visibly spins.  bits[3:2] = advance every 4 frames, full cycle ~16
  // frames (~270 ms at 60 Hz).
  wire [1:0] chip_frame = frame_counter[3:2];

  wire _unused_dxdy = &{dx0[9:7], dx1[9:7], dx2[9:7],
                        dy0[9:5], dy1[9:5], dy2[9:5],
                        dxc[9:5], dyc[9:5]};

  // ROM read addresses: ports 0..2 carry the per-message band offset
  // (msg_id * 32); port 3 carries the chip band (band 3 = y[6:5]==2'b11)
  // and uses chip_frame as the high x bits to slot-select among the 4
  // 32-wide rotation frames laid out side by side.
  wire pixel0_raw, pixel1_raw, pixel2_raw, chip_pixel;
  bitmap_rom rom (
      .x0(lx0), .y0({2'd0, ly0}),                .pixel0(pixel0_raw),
      .x1(lx1), .y1({2'd1, ly1}),                .pixel1(pixel1_raw),
      .x2(lx2), .y2({2'd2, ly2}),                .pixel2(pixel2_raw),
      .x3({chip_frame, lxc}), .y3({2'b11, lyc}), .pixel3(chip_pixel)
  );

  wire text0 = in0 & pixel0_raw;
  wire text1 = in1 & pixel1_raw;
  wire text2 = in2 & pixel2_raw;

  // Overlap count (0..3).
  wire [1:0] overlap = {1'b0, in0} + {1'b0, in1} + {1'b0, in2};
  wire collide      = overlap[1];   // 2 or 3 boxes overlap
  wire text_xor     = text0 ^ text1 ^ text2;

  // Per-bouncer palette colour (used when only that bouncer's bbox covers
  // this pixel).
  wire [5:0] color0_rgb, color1_rgb, color2_rgb, strobe_rgb, chip_rgb;
  palette pal0    (.color_index(color0),                .rrggbb(color0_rgb));
  palette pal1    (.color_index(color1),                .rrggbb(color1_rgb));
  palette pal2    (.color_index(color2),                .rrggbb(color2_rgb));
  palette palstr  (.color_index(frame_counter[5:3]),    .rrggbb(strobe_rgb));
  // Chip cycles colour slowly so the spin reads even on the edge-on frame.
  palette palchip (.color_index(frame_counter[7:5]),    .rrggbb(chip_rgb));

  // Pick the active solo colour; only one of in0/in1/in2 is set when not
  // colliding.
  wire [5:0] solo_rgb = ({6{in0}} & color0_rgb)
                      | ({6{in1}} & color1_rgb)
                      | ({6{in2}} & color2_rgb);
  wire       solo_text = text0 | text1 | text2;

  // Dim halo: bright strobe colour halved per channel for the overlap
  // background so the collision rectangle visibly glows.
  wire [5:0] halo_rgb = {1'b0, strobe_rgb[5],
                         1'b0, strobe_rgb[3],
                         1'b0, strobe_rgb[1]};

  // Chip renders behind the bouncing text: a bouncer's bbox always wins,
  // so the chip is visible only in pixels no bouncer covers.
  wire chip_show = in_chip & chip_pixel;

  reg [5:0] pix_rgb;
  always @* begin
    if (!video_active) begin
      pix_rgb = 6'b0;
    end else if (collide) begin
      pix_rgb = text_xor ? strobe_rgb : halo_rgb;
    end else if (overlap[0]) begin
      pix_rgb = solo_text ? solo_rgb : 6'b0;
    end else if (chip_show) begin
      pix_rgb = chip_rgb;
    end else begin
      pix_rgb = 6'b0;
    end
  end

  // ---------------------------------------------------------------
  // RGB output register
  // ---------------------------------------------------------------
  always @(posedge clk) begin
    if (~rst_n) begin
      R <= 0; G <= 0; B <= 0;
    end else begin
      R <= pix_rgb[5:4];
      G <= pix_rgb[3:2];
      B <= pix_rgb[1:0];
    end
  end

  // ---------------------------------------------------------------
  // Once-per-frame tick: rising edge of pix_y == 0 (top of frame).
  // Update all three bouncers and the strobe counter.
  // ---------------------------------------------------------------
  wire frame_tick = (pix_y == 0) && (prev_y != pix_y);

  always @(posedge clk) begin
    if (~rst_n) begin
      prev_y        <= 10'd0;
      frame_counter <= 8'd0;

      pos_x0 <= 10'd40;  pos_y0 <= 10'd60;
      dir_x0 <= 1'b1;    dir_y0 <= 1'b1;   color0 <= 3'd0;

      pos_x1 <= 10'd300; pos_y1 <= 10'd180;
      dir_x1 <= 1'b0;    dir_y1 <= 1'b1;   color1 <= 3'd2;

      pos_x2 <= 10'd180; pos_y2 <= 10'd360;
      dir_x2 <= 1'b1;    dir_y2 <= 1'b0;   color2 <= 3'd5;
    end else begin
      prev_y <= pix_y;
      if (frame_tick) begin
        frame_counter <= frame_counter + 1'b1;

        // Bouncer 0
        pos_x0 <= pos_x0 + (dir_x0 ? 10'd1 : -10'd1);
        pos_y0 <= pos_y0 + (dir_y0 ? 10'd1 : -10'd1);
        if (pos_x0 == 10'd1            && !dir_x0) begin dir_x0 <= 1'b1; color0 <= color0 + 1'b1; end
        if (pos_x0 == DISPLAY_WIDTH  - MSG_W - 10'd1 && dir_x0) begin dir_x0 <= 1'b0; color0 <= color0 + 1'b1; end
        if (pos_y0 == 10'd1            && !dir_y0) begin dir_y0 <= 1'b1; color0 <= color0 + 1'b1; end
        if (pos_y0 == DISPLAY_HEIGHT - MSG_H - 10'd1 && dir_y0) begin dir_y0 <= 1'b0; color0 <= color0 + 1'b1; end

        // Bouncer 1
        pos_x1 <= pos_x1 + (dir_x1 ? 10'd1 : -10'd1);
        pos_y1 <= pos_y1 + (dir_y1 ? 10'd1 : -10'd1);
        if (pos_x1 == 10'd1            && !dir_x1) begin dir_x1 <= 1'b1; color1 <= color1 + 1'b1; end
        if (pos_x1 == DISPLAY_WIDTH  - MSG_W - 10'd1 && dir_x1) begin dir_x1 <= 1'b0; color1 <= color1 + 1'b1; end
        if (pos_y1 == 10'd1            && !dir_y1) begin dir_y1 <= 1'b1; color1 <= color1 + 1'b1; end
        if (pos_y1 == DISPLAY_HEIGHT - MSG_H - 10'd1 && dir_y1) begin dir_y1 <= 1'b0; color1 <= color1 + 1'b1; end

        // Bouncer 2
        pos_x2 <= pos_x2 + (dir_x2 ? 10'd1 : -10'd1);
        pos_y2 <= pos_y2 + (dir_y2 ? 10'd1 : -10'd1);
        if (pos_x2 == 10'd1            && !dir_x2) begin dir_x2 <= 1'b1; color2 <= color2 + 1'b1; end
        if (pos_x2 == DISPLAY_WIDTH  - MSG_W - 10'd1 && dir_x2) begin dir_x2 <= 1'b0; color2 <= color2 + 1'b1; end
        if (pos_y2 == 10'd1            && !dir_y2) begin dir_y2 <= 1'b1; color2 <= color2 + 1'b1; end
        if (pos_y2 == DISPLAY_HEIGHT - MSG_H - 10'd1 && dir_y2) begin dir_y2 <= 1'b0; color2 <= color2 + 1'b1; end
      end
    end
  end

endmodule
