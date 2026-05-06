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

// VGA frame is 640x480; sprites are 128 px wide bouncing-text bands of
// 16 px tall (a 16-char x 16-row grid) and a 32x32 chip in the centre.
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
  // Three bouncer state vectors. The ROM port index implicitly
  // selects which message a bouncer renders (port i reads message i).
  // ---------------------------------------------------------------
  // Each bouncer keeps a single 10-bit always-incrementing counter per
  // axis. The visible 9-bit position is a zigzag derived from the
  // counter: when the high bit is 0 the position ramps 0->511, when
  // it is 1 it ramps 511->0. This collapses the (pos, dir) pair, the
  // conditional inc/dec adder, and all four boundary equality
  // comparators into one increment + a tiny XOR-with-MSB.
  reg [9:0] cx0, cx1, cx2;
  reg [9:0] cy0, cy1, cy2;
  wire [8:0] pos_x0 = cx0[8:0] ^ {9{cx0[9]}};
  wire [8:0] pos_x1 = cx1[8:0] ^ {9{cx1[9]}};
  wire [8:0] pos_x2 = cx2[8:0] ^ {9{cx2[9]}};
  wire [8:0] pos_y0 = cy0[8:0] ^ {9{cy0[9]}};
  wire [8:0] pos_y1 = cy1[8:0] ^ {9{cy1[9]}};
  wire [8:0] pos_y2 = cy2[8:0] ^ {9{cy2[9]}};
  // Bouncer colours track position: as a sprite moves across the
  // frame, the upper bits of pos_x walk through palette indices, so
  // each crossing of a 64-pixel band shifts the colour. A constant
  // XOR per bouncer staggers their starting colours.
  wire [2:0] color0 = pos_x0[8:6] ^ 3'd0;
  wire [2:0] color1 = pos_x1[8:6] ^ 3'd2;
  wire [2:0] color2 = pos_x2[8:6] ^ 3'd5;

  reg [5:0] frame_counter;

  // ---------------------------------------------------------------
  // Per-pixel: bbox tests, ROM lookups, composition
  //
  // MSG_W = 128 = 2^7, MSG_H = 16 = 2^4. Inside test piggy-backs on
  // dx/dy subtractor upper bits.
  // ---------------------------------------------------------------
  wire [9:0] dx0 = pix_x - {1'b0, pos_x0};
  wire [9:0] dx1 = pix_x - {1'b0, pos_x1};
  wire [9:0] dx2 = pix_x - {1'b0, pos_x2};
  wire [9:0] dy0 = pix_y - {1'b0, pos_y0};
  wire [9:0] dy1 = pix_y - {1'b0, pos_y1};
  wire [9:0] dy2 = pix_y - {1'b0, pos_y2};

  wire in0 = (dx0[9:7] == 3'd0) && (dy0[9:4] == 6'd0);
  wire in1 = (dx1[9:7] == 3'd0) && (dy1[9:4] == 6'd0);
  wire in2 = (dx2[9:7] == 3'd0) && (dy2[9:4] == 6'd0);

  wire [6:0] lx0 = dx0[6:0];
  wire [6:0] lx1 = dx1[6:0];
  wire [6:0] lx2 = dx2[6:0];
  wire [3:0] ly0 = dy0[3:0];
  wire [3:0] ly1 = dy1[3:0];
  wire [3:0] ly2 = dy2[3:0];

  // Chip sprite (32x32) anchored at (CHIP_X, CHIP_Y); same bbox trick.
  wire [9:0] dxc = pix_x - CHIP_X;
  wire [9:0] dyc = pix_y - CHIP_Y;
  wire in_chip = (dxc[9:5] == 5'd0) && (dyc[9:5] == 5'd0);
  wire [4:0] lxc = dxc[4:0];
  wire [4:0] lyc = dyc[4:0];

  // Chip rotation frame index: low bits of frame_counter so the chip
  // visibly spins.  bits[3:2] = advance every 4 frames, full cycle ~16
  // frames (~270 ms at 60 Hz).
  wire [1:0] chip_frame = frame_counter[3:2];

  // bitmap_rom is character-indexed: a tiny font ROM + per-message
  // char-stream ROM. Each port renders a different message; the band
  // selection is implicit in the port (port i reads msgs[i, ...]).
  wire pixel0_raw, pixel1_raw, pixel2_raw, chip_pixel;
  bitmap_rom rom (
      .x0(lx0), .y0(ly0), .pixel0(pixel0_raw),
      .x1(lx1), .y1(ly1), .pixel1(pixel1_raw),
      .x2(lx2), .y2(ly2), .pixel2(pixel2_raw)
  );

  // Chip ROM holds the 4 spinning-coin frames packed side by side; the
  // current frame index is the high x bits.
  chip_rom chip (
      .x0({chip_frame, lxc}), .y0(lyc), .pixel0(chip_pixel)
  );

  wire text0 = in0 & pixel0_raw;
  wire text1 = in1 & pixel1_raw;
  wire text2 = in2 & pixel2_raw;

  // Overlap detection: any_box = at least one bbox; collide = at least
  // two. Direct boolean form avoids the 3-input popcount adder.
  wire any_box  = in0 | in1 | in2;
  wire collide  = (in0 & in1) | (in0 & in2) | (in1 & in2);
  wire text_xor = text0 ^ text1 ^ text2;

  wire solo_text = text0 | text1 | text2;
  // Chip renders behind the bouncing text: a bouncer's bbox always wins,
  // so the chip is visible only in pixels no bouncer covers.
  wire chip_show = in_chip & chip_pixel;

  // Single shared palette: priority-mux the colour index to the one we
  // actually need this pixel.  Saves four palette instances vs. looking
  // up every potential colour and muxing the 6-bit results.
  //
  // Priority mirrors the pix_rgb composition below:
  //   collide  -> strobe (frame_counter[5:3])
  //   in_i     -> that bouncer's color (only one in_i is high when !collide)
  //   else     -> chip palette index (used iff chip_show)
  wire [2:0] color_idx_active =
      collide ? frame_counter[5:3] :
      in0     ? color0             :
      in1     ? color1             :
      in2     ? color2             :
                frame_counter[5:3];

  wire [5:0] color_active;
  palette pal (.color_index(color_idx_active), .rrggbb(color_active));

  // Dim halo: shared palette output halved per channel.  Free in HDL
  // (just a wire reshuffle) so it stays.
  wire [5:0] halo_color = {1'b0, color_active[5],
                           1'b0, color_active[3],
                           1'b0, color_active[1]};

  reg [5:0] pix_rgb;
  always @* begin
    if (!video_active) begin
      pix_rgb = 6'b0;
    end else if (collide) begin
      pix_rgb = text_xor ? color_active : halo_color;
    end else if (any_box) begin
      pix_rgb = solo_text ? color_active : 6'b0;
    end else if (chip_show) begin
      pix_rgb = color_active;
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
  // Once-per-frame tick: first pixel of the top scanline. Fires
  // exactly once per frame, no edge-detect register needed.
  // ---------------------------------------------------------------
  wire frame_tick = (pix_x == 10'd0) && (pix_y == 10'd0);

  always @(posedge clk) begin
    if (~rst_n) begin
      frame_counter <= 6'd0;
      // Stagger initial counter values so the three bouncers don't
      // walk in lockstep. High bit picks initial direction; the low
      // 9 bits set starting position (when high bit is 0, that IS
      // the visible pos; when high bit is 1, visible pos = ~low9).
      cx0 <= 10'h028;  cy0 <= 10'h03C;  // pos (40, 60), going +,+
      cx1 <= 10'h2D3;  cy1 <= 10'h0B4;  // pos (300, 180), going -,+
      cx2 <= 10'h0B4;  cy2 <= 10'h297;  // pos (180, 360), going +,-
    end else if (frame_tick) begin
      frame_counter <= frame_counter + 1'b1;
      cx0 <= cx0 + 1'b1;  cy0 <= cy0 + 1'b1;
      cx1 <= cx1 + 1'b1;  cy1 <= cy1 + 1'b1;
      cx2 <= cx2 + 1'b1;  cy2 <= cy2 + 1'b1;
    end
  end

endmodule
