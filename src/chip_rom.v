/*
 * Spinning CPU chip sprite, 4 frames packed into 320 bytes via lossless folds:
 *   - frame 0: stored verbatim                (mem[0..127])
 *   - frame 1: stored verbatim                (mem[128..255])
 *   - frame 2: only left half stored, right half is hflip(left)  (mem[256..319])
 *   - frame 3: not stored; equals hflip(frame 1)
 * Same external port as before; address mapping handled internally.
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module chip_rom (
    input  wire [6:0]       x0,
    input  wire [4:0]       y0,
    output wire             pixel0
);

  reg [7:0] mem[0:319];

  initial begin
    mem[0] = 8'h00;
    mem[1] = 8'h00;
    mem[2] = 8'h00;
    mem[3] = 8'h00;
    mem[4] = 8'h00;
    mem[5] = 8'h00;
    mem[6] = 8'h00;
    mem[7] = 8'h00;
    mem[8] = 8'h00;
    mem[9] = 8'h11;
    mem[10] = 8'h11;
    mem[11] = 8'h00;
    mem[12] = 8'h00;
    mem[13] = 8'h11;
    mem[14] = 8'h11;
    mem[15] = 8'h00;
    mem[16] = 8'h00;
    mem[17] = 8'h11;
    mem[18] = 8'h11;
    mem[19] = 8'h00;
    mem[20] = 8'he0;
    mem[21] = 8'hff;
    mem[22] = 8'hff;
    mem[23] = 8'h07;
    mem[24] = 8'h20;
    mem[25] = 8'h00;
    mem[26] = 8'h00;
    mem[27] = 8'h04;
    mem[28] = 8'ha0;
    mem[29] = 8'h03;
    mem[30] = 8'h00;
    mem[31] = 8'h04;
    mem[32] = 8'hbc;
    mem[33] = 8'h02;
    mem[34] = 8'h00;
    mem[35] = 8'h3c;
    mem[36] = 8'ha0;
    mem[37] = 8'h03;
    mem[38] = 8'h00;
    mem[39] = 8'h04;
    mem[40] = 8'h20;
    mem[41] = 8'h00;
    mem[42] = 8'h00;
    mem[43] = 8'h04;
    mem[44] = 8'h20;
    mem[45] = 8'h00;
    mem[46] = 8'h00;
    mem[47] = 8'h04;
    mem[48] = 8'h3c;
    mem[49] = 8'hf0;
    mem[50] = 8'h0f;
    mem[51] = 8'h3c;
    mem[52] = 8'h20;
    mem[53] = 8'hf0;
    mem[54] = 8'h0f;
    mem[55] = 8'h04;
    mem[56] = 8'h20;
    mem[57] = 8'hf0;
    mem[58] = 8'h0f;
    mem[59] = 8'h04;
    mem[60] = 8'h20;
    mem[61] = 8'hf0;
    mem[62] = 8'h0f;
    mem[63] = 8'h04;
    mem[64] = 8'h3c;
    mem[65] = 8'hf0;
    mem[66] = 8'h0f;
    mem[67] = 8'h3c;
    mem[68] = 8'h20;
    mem[69] = 8'hf0;
    mem[70] = 8'h0f;
    mem[71] = 8'h04;
    mem[72] = 8'h20;
    mem[73] = 8'hf0;
    mem[74] = 8'h0f;
    mem[75] = 8'h04;
    mem[76] = 8'h20;
    mem[77] = 8'hf0;
    mem[78] = 8'h0f;
    mem[79] = 8'h04;
    mem[80] = 8'h3c;
    mem[81] = 8'h00;
    mem[82] = 8'h00;
    mem[83] = 8'h3c;
    mem[84] = 8'h20;
    mem[85] = 8'h00;
    mem[86] = 8'h00;
    mem[87] = 8'h04;
    mem[88] = 8'h20;
    mem[89] = 8'h00;
    mem[90] = 8'h00;
    mem[91] = 8'h04;
    mem[92] = 8'h20;
    mem[93] = 8'h00;
    mem[94] = 8'h00;
    mem[95] = 8'h04;
    mem[96] = 8'h20;
    mem[97] = 8'h00;
    mem[98] = 8'h00;
    mem[99] = 8'h04;
    mem[100] = 8'h20;
    mem[101] = 8'h00;
    mem[102] = 8'h00;
    mem[103] = 8'h04;
    mem[104] = 8'he0;
    mem[105] = 8'hff;
    mem[106] = 8'hff;
    mem[107] = 8'h07;
    mem[108] = 8'h00;
    mem[109] = 8'h11;
    mem[110] = 8'h11;
    mem[111] = 8'h00;
    mem[112] = 8'h00;
    mem[113] = 8'h11;
    mem[114] = 8'h11;
    mem[115] = 8'h00;
    mem[116] = 8'h00;
    mem[117] = 8'h11;
    mem[118] = 8'h11;
    mem[119] = 8'h00;
    mem[120] = 8'h00;
    mem[121] = 8'h00;
    mem[122] = 8'h00;
    mem[123] = 8'h00;
    mem[124] = 8'h00;
    mem[125] = 8'h00;
    mem[126] = 8'h00;
    mem[127] = 8'h00;
    mem[128] = 8'h00;
    mem[129] = 8'h00;
    mem[130] = 8'h00;
    mem[131] = 8'h00;
    mem[132] = 8'h00;
    mem[133] = 8'h00;
    mem[134] = 8'h00;
    mem[135] = 8'h00;
    mem[136] = 8'h00;
    mem[137] = 8'h00;
    mem[138] = 8'h05;
    mem[139] = 8'h00;
    mem[140] = 8'h00;
    mem[141] = 8'h00;
    mem[142] = 8'h05;
    mem[143] = 8'h00;
    mem[144] = 8'h00;
    mem[145] = 8'h00;
    mem[146] = 8'h05;
    mem[147] = 8'h00;
    mem[148] = 8'h00;
    mem[149] = 8'hfc;
    mem[150] = 8'h3f;
    mem[151] = 8'h00;
    mem[152] = 8'h00;
    mem[153] = 8'h00;
    mem[154] = 8'h00;
    mem[155] = 8'h00;
    mem[156] = 8'h00;
    mem[157] = 8'h18;
    mem[158] = 8'h00;
    mem[159] = 8'h00;
    mem[160] = 8'h00;
    mem[161] = 8'h0f;
    mem[162] = 8'hc0;
    mem[163] = 8'h00;
    mem[164] = 8'h00;
    mem[165] = 8'h18;
    mem[166] = 8'h00;
    mem[167] = 8'h00;
    mem[168] = 8'h00;
    mem[169] = 8'h00;
    mem[170] = 8'h00;
    mem[171] = 8'h00;
    mem[172] = 8'h00;
    mem[173] = 8'h00;
    mem[174] = 8'h00;
    mem[175] = 8'h00;
    mem[176] = 8'h00;
    mem[177] = 8'hc3;
    mem[178] = 8'hc3;
    mem[179] = 8'h00;
    mem[180] = 8'h00;
    mem[181] = 8'hc0;
    mem[182] = 8'h03;
    mem[183] = 8'h00;
    mem[184] = 8'h00;
    mem[185] = 8'hc0;
    mem[186] = 8'h03;
    mem[187] = 8'h00;
    mem[188] = 8'h00;
    mem[189] = 8'hc0;
    mem[190] = 8'h03;
    mem[191] = 8'h00;
    mem[192] = 8'h00;
    mem[193] = 8'hc3;
    mem[194] = 8'hc3;
    mem[195] = 8'h00;
    mem[196] = 8'h00;
    mem[197] = 8'hc0;
    mem[198] = 8'h03;
    mem[199] = 8'h00;
    mem[200] = 8'h00;
    mem[201] = 8'hc0;
    mem[202] = 8'h03;
    mem[203] = 8'h00;
    mem[204] = 8'h00;
    mem[205] = 8'hc0;
    mem[206] = 8'h03;
    mem[207] = 8'h00;
    mem[208] = 8'h00;
    mem[209] = 8'h03;
    mem[210] = 8'hc0;
    mem[211] = 8'h00;
    mem[212] = 8'h00;
    mem[213] = 8'h00;
    mem[214] = 8'h00;
    mem[215] = 8'h00;
    mem[216] = 8'h00;
    mem[217] = 8'h00;
    mem[218] = 8'h00;
    mem[219] = 8'h00;
    mem[220] = 8'h00;
    mem[221] = 8'h00;
    mem[222] = 8'h00;
    mem[223] = 8'h00;
    mem[224] = 8'h00;
    mem[225] = 8'h00;
    mem[226] = 8'h00;
    mem[227] = 8'h00;
    mem[228] = 8'h00;
    mem[229] = 8'h00;
    mem[230] = 8'h00;
    mem[231] = 8'h00;
    mem[232] = 8'h00;
    mem[233] = 8'hfc;
    mem[234] = 8'h3f;
    mem[235] = 8'h00;
    mem[236] = 8'h00;
    mem[237] = 8'h00;
    mem[238] = 8'h05;
    mem[239] = 8'h00;
    mem[240] = 8'h00;
    mem[241] = 8'h00;
    mem[242] = 8'h05;
    mem[243] = 8'h00;
    mem[244] = 8'h00;
    mem[245] = 8'h00;
    mem[246] = 8'h05;
    mem[247] = 8'h00;
    mem[248] = 8'h00;
    mem[249] = 8'h00;
    mem[250] = 8'h00;
    mem[251] = 8'h00;
    mem[252] = 8'h00;
    mem[253] = 8'h00;
    mem[254] = 8'h00;
    mem[255] = 8'h00;
    mem[256] = 8'h00;
    mem[257] = 8'h00;
    mem[258] = 8'h00;
    mem[259] = 8'h00;
    mem[260] = 8'h00;
    mem[261] = 8'h00;
    mem[262] = 8'h00;
    mem[263] = 8'h00;
    mem[264] = 8'h00;
    mem[265] = 8'h00;
    mem[266] = 8'h00;
    mem[267] = 8'h80;
    mem[268] = 8'h00;
    mem[269] = 8'h00;
    mem[270] = 8'h00;
    mem[271] = 8'h00;
    mem[272] = 8'h00;
    mem[273] = 8'h40;
    mem[274] = 8'h00;
    mem[275] = 8'h00;
    mem[276] = 8'h00;
    mem[277] = 8'h00;
    mem[278] = 8'h00;
    mem[279] = 8'h00;
    mem[280] = 8'h00;
    mem[281] = 8'h80;
    mem[282] = 8'h00;
    mem[283] = 8'h80;
    mem[284] = 8'h00;
    mem[285] = 8'h80;
    mem[286] = 8'h00;
    mem[287] = 8'h80;
    mem[288] = 8'h00;
    mem[289] = 8'h80;
    mem[290] = 8'h00;
    mem[291] = 8'h80;
    mem[292] = 8'h00;
    mem[293] = 8'h80;
    mem[294] = 8'h00;
    mem[295] = 8'h80;
    mem[296] = 8'h00;
    mem[297] = 8'h40;
    mem[298] = 8'h00;
    mem[299] = 8'h00;
    mem[300] = 8'h00;
    mem[301] = 8'h00;
    mem[302] = 8'h00;
    mem[303] = 8'h00;
    mem[304] = 8'h00;
    mem[305] = 8'h00;
    mem[306] = 8'h00;
    mem[307] = 8'h00;
    mem[308] = 8'h00;
    mem[309] = 8'h80;
    mem[310] = 8'h00;
    mem[311] = 8'h00;
    mem[312] = 8'h00;
    mem[313] = 8'h00;
    mem[314] = 8'h00;
    mem[315] = 8'h00;
    mem[316] = 8'h00;
    mem[317] = 8'h00;
    mem[318] = 8'h00;
    mem[319] = 8'h00;
  end

  wire [1:0] f      = x0[6:5];
  wire [4:0] x      = x0[4:0];
  wire [4:0] xflip  = ~x;                              // 31 - x
  wire [3:0] xfold2 = x[4] ? ~x[3:0] : x[3:0];         // hflip-fold for frame 2

  reg [8:0] addr;
  reg [2:0] bitsel;
  always @* begin
    case (f)
      2'd0: begin
        addr   = {1'b0, y0, x[4:3]};            // 0..127
        bitsel = x[2:0];
      end
      2'd1: begin
        addr   = {1'b1, y0, x[4:3]};            // 128..255
        bitsel = x[2:0];
      end
      2'd2: begin
        addr   = {1'b1, 2'b00, y0, xfold2[3]};  // 256..319
        bitsel = xfold2[2:0];
      end
      default: begin // f == 3: hflip(frame 1)
        addr   = {1'b1, y0, xflip[4:3]};        // 128..255
        bitsel = xflip[2:0];
      end
    endcase
  end

  assign pixel0 = mem[addr][bitsel];

endmodule
