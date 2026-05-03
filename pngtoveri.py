#!/usr/bin/env python3
from PIL import Image

img = Image.open("in.png").convert("1").resize((128, 128))
pixels = list(img.getdata())

verilog = """
`default_nettype none

module bitmap_rom (
		input wire [6:0] x,
		input wire [6:0] y,
		output wire pixel
);

reg [7:0] mem[2047:0];
initial begin
"""

idx = 0
for y in range(128):
    for x in range(0, 128, 8):
        byte = 0
        for b in range(8):
            px = x + b
            if px < 128 and pixels[y * 128 + px]:
                byte |= (1 << b)
        verilog += f"    mem[{idx}] = 8'h{byte:02x};\n"
        idx += 1

verilog += """
  end

  wire [10:0] addr = {y[6:0], x[6:3]};
  assign pixel = mem[addr][x&7];

endmodule
"""

with open("logo_mem.v", "w") as f:
    f.write(verilog)
print("Done")
