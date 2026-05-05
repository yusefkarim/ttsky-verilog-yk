#!/usr/bin/env python3
"""Convert an image into a Verilog ROM module containing a 128x128 1-bit bitmap."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

SIZE = 128
BYTES_PER_ROW = SIZE // 8
TOTAL_BYTES = SIZE * BYTES_PER_ROW


def image_to_bytes(path: Path) -> list[int]:
    with Image.open(path) as src:
        img = src.convert("1").resize((SIZE, SIZE))
    pixels = list(img.getdata())

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
        description="Convert an image (PNG, JPEG, BMP, GIF, etc.) into a "
        f"{SIZE}x{SIZE} 1-bit Verilog bitmap ROM module.",
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
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if not args.input.is_file():
        print(f"error: input file not found: {args.input}", file=sys.stderr)
        return 1
    try:
        data = image_to_bytes(args.input)
    except (OSError, Image.UnidentifiedImageError) as exc:
        print(f"error: could not read image: {exc}", file=sys.stderr)
        return 1

    args.output.write_text(render_verilog(data, args.module))
    print(f"Wrote {args.output} ({TOTAL_BYTES} bytes, module '{args.module}')")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
