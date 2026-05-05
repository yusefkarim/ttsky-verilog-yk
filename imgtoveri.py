#!/usr/bin/env python3
"""
Convert an image into a Verilog ROM module containing a 128x128 1-bit bitmap.

Dependencies
------------

Requires Pillow. Install with: `pip install Pillow`

Usage
-----
    ./imgtoveri.py INPUT [options]

Run `./imgtoveri.py --help` for the full option list. The script accepts any
PIL-supported format (PNG, JPEG, BMP, GIF, TIFF, WebP, ...). The output is a
single Verilog file defining a read ROM addressed by 7-bit (x, y)
coordinates and emitting a 1-bit "pixel".

Common workflows
----------------
1. Quick conversion of a clean black-on-white logo:

       ./imgtoveri.py logo.png

2. Tune the threshold for a tricky image. Print a histogram to see where the
   pixel values cluster, then pick a cutoff between the foreground and
   background peaks:

       ./imgtoveri.py photo.png --histogram
       ./imgtoveri.py photo.png -t 90

3. Photograph or shaded artwork where a hard threshold loses detail. Use
   dithering (e.g., to encode grays as stipple patterns):

       ./imgtoveri.py portrait.jpg --dither

4. Line art whose thin outlines vanish into anti-aliasing after the
   downscale. Threshold at full resolution first so the strokes survive:

       ./imgtoveri.py line-art.png --sharp -t 200

5. White-on-black source (e.g. a dark-mode logo) — flip it so the foreground
   ends up black in the ROM:

       ./imgtoveri.py dark-logo.png --invert

6. Optional custom module name and output path:

       ./imgtoveri.py logo.png -o src/logo_rom.v -m logo_rom
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageOps

SIZE = 128
BYTES_PER_ROW = SIZE // 8
TOTAL_BYTES = SIZE * BYTES_PER_ROW


def _fit(img: Image.Image, fill: int) -> Image.Image:
    fitted = ImageOps.contain(img, (SIZE, SIZE), method=Image.Resampling.LANCZOS)
    if fitted.size == (SIZE, SIZE):
        return fitted
    canvas = Image.new(img.mode, (SIZE, SIZE), fill)
    canvas.paste(fitted, ((SIZE - fitted.width) // 2, (SIZE - fitted.height) // 2))
    return canvas


def image_to_bytes(
    path: Path,
    threshold: int = 128,
    dither: bool = False,
    autocontrast: bool = True,
    invert: bool = False,
    sharp: bool = False,
    histogram: bool = False,
) -> list[int]:
    with Image.open(path) as src:
        src.load()
        if src.mode in ("RGBA", "LA") or (
            src.mode == "P" and "transparency" in src.info
        ):
            rgba = src.convert("RGBA")
            bg = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
            full = Image.alpha_composite(bg, rgba).convert("L")
        else:
            full = src.convert("L")

    if autocontrast:
        full = ImageOps.autocontrast(full)
    if invert:
        full = ImageOps.invert(full)

    if sharp:
        full_bw = full.point(lambda v: 255 if v >= threshold else 0, mode="L")
        gray = _fit(full_bw, fill=255)
        bw = gray.point(lambda v: 255 if v >= 128 else 0, mode="1")
    else:
        gray = _fit(full, fill=255)
        if dither:
            bw = gray.convert("1")
        else:
            bw = gray.point(lambda v: 255 if v >= threshold else 0, mode="1")

    if histogram:
        hist = gray.histogram()
        buckets = [sum(hist[i : i + 32]) for i in range(0, 256, 32)]
        total = sum(buckets) or 1
        peak = max(buckets) or 1
        print("grayscale histogram (0=black .. 255=white):")
        for i, count in enumerate(buckets):
            bar = "#" * int(40 * count / peak)
            print(f"  {i * 32:3d}-{i * 32 + 31:3d} {100 * count / total:5.1f}%  {bar}")

    pixels = (
        bw.get_flattened_data()
        if hasattr(bw, "get_flattened_data")
        else list(bw.getdata())
    )

    data = []
    for y in range(SIZE):
        for x in range(0, SIZE, 8):
            byte = 0
            for b in range(8):
                if pixels[y * SIZE + x + b]:
                    byte |= 1 << b
            data.append(byte)
    return data


def render_verilog(data: list[int], module: str) -> str:
    lines = [
        "`default_nettype none",
        "",
        f"module {module} (",
        "    input  wire [6:0] x,",
        "    input  wire [6:0] y,",
        "    output wire       pixel",
        ");",
        "",
        f"    reg [7:0] mem[{TOTAL_BYTES - 1}:0];",
        "    initial begin",
    ]
    lines.extend(f"        mem[{i}] = 8'h{byte:02x};" for i, byte in enumerate(data))
    lines.extend(
        [
            "    end",
            "",
            "    wire [10:0] addr = {y[6:0], x[6:3]};",
            "    assign pixel = mem[addr][x & 7];",
            "",
            "endmodule",
            "",
        ]
    )
    return "\n".join(lines)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            f"Convert an image (PNG, JPEG, BMP, GIF, etc.) into a {SIZE}x{SIZE} "
            "1-bit Verilog bitmap ROM module. The image is converted to grayscale, "
            "resized with LANCZOS resampling (preserving aspect ratio, padded onto "
            "a white canvas), optionally autocontrasted, then thresholded to 1 bit."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", type=Path, help="Source image file")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("bitmap_rom.v"),
        help="Output Verilog file (default: %(default)s)",
    )
    parser.add_argument(
        "-m",
        "--module",
        default="bitmap_rom",
        help="Verilog module name (default: %(default)s)",
    )
    parser.add_argument(
        "-t",
        "--threshold",
        type=int,
        default=128,
        metavar="N",
        help=(
            "Brightness cutoff 0-255 for the 1-bit threshold (default: %(default)s). "
            "Raise to drop more midtones to black, lower to keep more white."
        ),
    )
    parser.add_argument(
        "--no-autocontrast",
        dest="autocontrast",
        action="store_false",
        help=(
            "Disable autocontrast stretching. By default the grayscale image is "
            "stretched to the full 0-255 range so the threshold uses full dynamic range."
        ),
    )
    parser.add_argument(
        "--invert",
        action="store_true",
        help="Swap black and white (useful for white-on-black logos).",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dither",
        action="store_true",
        help=(
            "Use Floyd-Steinberg dithering instead of a hard threshold. "
            "Better for photographs; produces speckle on flat regions."
        ),
    )
    mode.add_argument(
        "--sharp",
        action="store_true",
        help=(
            "Threshold at full source resolution before downscaling, then resize "
            "with LANCZOS and re-threshold. Keeps thin outlines intact for "
            "line-art images that lose their strokes to anti-aliasing in the "
            "default pipeline. Slightly jaggier edges in exchange."
        ),
    )
    parser.add_argument(
        "--histogram",
        action="store_true",
        help="Print a grayscale histogram of the resized image to help tune --threshold.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if not args.input.is_file():
        print(f"error: input file not found: {args.input}", file=sys.stderr)
        return 1
    try:
        data = image_to_bytes(
            args.input,
            threshold=args.threshold,
            dither=args.dither,
            autocontrast=args.autocontrast,
            invert=args.invert,
            sharp=args.sharp,
            histogram=args.histogram,
        )
    except (OSError, Image.UnidentifiedImageError) as exc:
        print(f"error: could not read image: {exc}", file=sys.stderr)
        return 1

    args.output.write_text(render_verilog(data, args.module))
    print(f"Wrote {args.output} ({TOTAL_BYTES} bytes, module '{args.module}')")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
