<!--
This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project is a shameless promo screen for the RISC-V Ottawa group that we are just about to form. It is based on the standard VGA demo from vga-playground.com. The design drives a TinyVGA PMOD with 2-bit-per-channel colour, sourced from an 8-entry palette ROM.

Three text messages, "RISC-V Ottawa", "Join us!", and "riscvottawa.ca" bounce around the frame DVD-screensaver style. Each is an independent sprite with its own position, direction, and palette colour. When a sprite hits a wall it reverses on that axis and increments its colour index, so each bounce changes the message's colour.

When two or three message sprites overlap, the overlap rectangle lights up: the glyph pixels of the colliding messages are XOR-combined and drawn in a rapidly cycling "strobe" colour, while the rest of the overlap rectangle is filled with a dimmed version of the same colour, so collisions show as a glowing flash that pulses through the palette.

Behind the bouncing text, a small CPU chip sprite spins in the centre of the screen. The spin is faked as a "spinning coin". Bouncing text always renders on top of the chip.

All sprite data lives in a single 128×128 1-bit ROM packed into four 32-pixel-tall bands (three text messages plus the four chip rotation frames laid out side by side).

The pixel pipeline is fully combinational from `(pix_x, pix_y)` to the RGB output register. Sprite positions and the strobe/colour counters update once per frame on the rising edge of `pix_y == 0`.

## How to test

[Open the design in vga-playground](https://vga-playground.com/) and paste in `src/project.v`, `src/hvsync_generator.v`, `src/palette.v`, and `src/bitmap_rom.v`. You should see the three messages bouncing on a black background, the chip spinning in the middle, and a strobing flash whenever two messages overlap.

To regenerate the bitmap ROM with different text or a different chip sprite.

RTL simulation using the cocotb harness in `test/` is currently overridden to just always pass. Nobody got time for tests (╯°□°)╯︵ ┻━┻.

## External hardware

TinyVGA PMOD on the dedicated outputs (`uo`):

| pin | signal |
|-----|--------|
| `uo[7]` | HSync |
| `uo[3]` | VSync |
| `uo[6:4]` | high bit of R / G / B |
| `uo[2:0]` | low bit of R / G / B |

Tested in VGA Playground; targets a standard 640×480 @ 60 Hz VGA monitor.

## BONUS - imgtoveri.py

I attended the [Latch-Up 2026 Tiny Tapeout workshop](https://fossi-foundation.org/latch-up/2026#tiny-tapeout-workshop-pat-deegan). During this workshop Pat Deegan provided us with a great script to convert text to the VGA playground bitmap format/code.
I took inspiration from his script to create [imgtovery.py](../imgtoveri.py).
The script accepts any PIL-supported image format (PNG, JPEG, BMP, GIF, TIFF, WebP, etc) and converts it the same VGA playground bitmap code. You can use this script to add your own image to the logo project preset on the TT VGA playground site!
