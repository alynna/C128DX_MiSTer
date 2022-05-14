
module vdc_top (
	input    [1:0] version,   // 0=REV7A (8563), 1=REV8 (8563), 2=REV9 (8568)
	input          ram64k,    // 0=16K RAM, 1=64K RAM

	input          clk,
	input          reset,
	input          init,

	input          cs,        // chip select
	input          rs,        // register select
	input          we,        // write enable
	input    [7:0] db_in,     // data in
	output   [7:0] db_out,    // data out

	input          enablePixel0,
	input          enablePixel1
);

// version  chip
//   0      8563 R7A    initial version, 16k or 64k RAM
//   1      8563 R8     changes to R25, 16k or 64k RAM
//   2      8568 R9     adds R37, 64k RAM

									 // Reg      Init value  Description
reg   [7:0] reg_ht;         // R0         7E 126    Horizontal total (minus 1)
reg   [7:0] reg_hd;         // R1         50 80     Horizontal displayed
reg   [7:0] reg_hp;         // R2         66 102    Horizontal sync position
reg   [3:0] reg_vw;         // R3[7:4]     4 4      Vertical sync width (plus 1)
reg   [3:0] reg_hw;         // R3[3:0]     9 9      Horizontal sync width
reg   [7:0] reg_vt;         // R4      20/27 32/39  Vertical total (minus 1) [32 for NTSC, 39 for PAL]
reg   [4:0] reg_va;         // R5         00 0      Vertical total adjust
reg   [7:0] reg_vd;         // R6         19 25     Vertical displayed
reg   [7:0] reg_vp;         // R7      1D/20 29/32  Vertical sync position (plus 1) [29 for NTSC, 32 for PAL]
reg   [1:0] reg_im;         // R8          0 off    Interlace mode
reg   [4:0] reg_ctv;        // R9         07 7      Character Total Vertical (minus 1)
reg   [1:0] reg_cm;         // R10[6:5]    1 none   Cursor mode
reg   [4:0] reg_cs;         // R10[4:0]    0 0      Cursor scanline start
reg   [4:0] reg_ce;         // R11        07 7      Cursor scanline end (plus 1?)
reg  [15:0] reg_ds;         // R12/R13  0000 0000   Display start
reg  [15:0] reg_cp;         // R14/R15  0000 0000   Cursor position
reg   [7:0] reg_lpv;        // R16                  Light pen V position
reg   [7:0] reg_lph;        // R17                  Light pen H position
reg  [15:0] reg_ua;         // R18/R19       -      Update address
reg  [15:0] reg_aa;         // R20/R21  0800 0800   Attribute start address
reg   [3:0] reg_cth;        // R22[7:4]    7 7      Character total horizontal (minus 1)
reg   [3:0] reg_cdh;        // R22[3:0]    8 8      Character displayed horizontal (plus 1 in double width mode)
reg   [4:0] reg_cdv;        // R23        08 8      Character displayed vertical (minus 1)
reg         reg_copy;       // R24[7]      0 off    Block copy mode
reg         reg_rvs;        // R24[6]      0 off    Reverse screen
reg         reg_cbrate;     // R24[5]      1 1/30   Character blink rate
reg   [4:0] reg_vss;        // R24[4:0]   00 0      Vertical smooth scroll
reg         reg_text;       // R25[7]      0 text   Mode select (text/bitmap)
reg         reg_atr;        // R25[6]      1 on     Attribute enable
reg         reg_semi;       // R25[5]      0 off    Semi-graphic mode
reg         reg_dbl;        // R25[4]      0 off    Pixel double width
reg   [3:0] reg_hss;        // R25[3:0]  0/7 0/7    Smooth horizontal scroll [0 for rev 7A, 7 for rev 8/9]
reg   [3:0] reg_fg;         // R26[7:4]    F white  Foreground RGBI
reg   [3:0] reg_bg;         // R26[3:0]    0 black  Background RGBI
reg   [7:0] reg_ai;         // R27        00 0      Address increment per row
reg   [2:0] reg_cb;         // R28[7:5]    1 2000   Character set start address
reg         reg_ram;        // R28[4]      0 4416   RAM type (0=16k accessible, 1=64k accessible)
reg   [4:0] reg_ul;         // R29        07 7      Underline scan line
reg   [7:0] reg_wc;         // R30                  Word count
reg   [7:0] reg_da;         // R31                  Data (in)
reg  [15:0] reg_ba;         // R32/R33              Block copy source address
reg   [7:0] reg_deb;        // R34        7D 125    Display enable begin
reg   [7:0] reg_dee;        // R35        64 100    Display enable end
reg   [3:0] reg_drr;        // R36         5 5      Ram refresh/scan line
reg         reg_hspol = 1;  // R37[7]               [Rev 9 (8568) only], HSYnc polarity
reg         reg_vspol = 1;  // R37[6]               [Rev 9 (8568) only], VSYnc polarity

reg   [7:0] regSel;         // selected internal register (write to $D600)

reg         lpStatus;       // light pen status
reg         vSync;          // vertical sync
reg         hSync;          // horizontal sync

wire        busy;

wire        enablePixel = enablePixel0 | (~reg_dbl & enablePixel1);

vdc_ramiface ram (
	.ram64k(ram64k),
	.clk(clk),
	.enable(enablePixel),
	.reset(reset),
	.regA(regSel),
	.db_in(db_in),
	.cs(cs),
	.rs(rs),
	.we(we),
	.reg_copy(reg_copy),
	.reg_ram(reg_ram),
	.reg_ua(reg_ua),
	.reg_wc(reg_wc),
	.reg_da(reg_da),
	.reg_ba(reg_ba),
	.busy(busy)
);

// Internal registers
always @(posedge clk) begin
	if (reset) begin
		regSel <= 0;

		reg_ht <= 0;
		reg_hd <= 0;
		reg_hp <= 0;
		reg_vw <= 0;
		reg_hw <= 0;
		reg_vt <= 0;
		reg_va <= 0;
		reg_vd <= 0;
		reg_vp <= 0;
		reg_im <= 0;
		reg_ctv <= 0;
		reg_cm <= 0;
		reg_cs <= 0;
		reg_ce <= 0;
		reg_ds <= 0;
		reg_cp <= 0;
		reg_lpv <= 0;
		reg_lph <= 0;
		reg_aa <= 0;
		reg_cth <= 0;
		reg_cdh <= 0;
		reg_cdv <= 0;
		reg_copy <= 0;
		reg_rvs <= 0;
		reg_cbrate <= 0;
		reg_vss <= 0;
		reg_text <= 0;
		reg_atr <= 0;
		reg_semi <= 0;
		reg_dbl <= 0;
		reg_hss <= 0;
		reg_fg <= 0;
		reg_bg <= 0;
		reg_ai <= 0;
		reg_cb <= 0;
		reg_ram <= 0;
		reg_ul <= 0;
		reg_deb <= 0;
		reg_dee <= 0;
		reg_drr <= 0;
		reg_hspol <= 1;
		reg_vspol <= 1;
	end
	else if (cs)
		if (we) begin
			if (!rs) begin
				regSel <= db_in;
			end
			else if (!busy) begin
				case (regSel)
					 0: reg_ht       <= db_in;
					 1: reg_hd       <= db_in;
					 2: reg_hp       <= db_in;
					 3: begin
							reg_vw     <= db_in[7:4];
							reg_hw     <= db_in[3:0];
						end
					 4: reg_vt       <= db_in;
					 5: reg_va       <= db_in[4:0];
					 6: reg_vd       <= db_in;
					 7: reg_vp       <= db_in;
					 8: reg_im       <= db_in[1:0];
					 9: reg_ctv      <= db_in[4:0];
					10: begin
							reg_cm     <= db_in[6:5];
							reg_cs     <= db_in[4:0];
						end
					11: reg_ce       <= db_in[4:0];
					12: reg_ds[15:8] <= db_in;
					13: reg_ds[7:0]  <= db_in;
					14: reg_cp[15:8] <= db_in;
					15: reg_cp[7:0]  <= db_in;
					// R16-R17 are read-only
					// writes to R18-R19 are handled by vdc_ramiface
					20: reg_aa[15:8] <= db_in;
					21: reg_aa[7:0]  <= db_in;
					22: begin
							reg_cth    <= db_in[7:4];
							reg_cdh    <= db_in[3:0];
						end
					23: reg_cdv      <= db_in[4:0];
					24: begin
							reg_copy   <= db_in[7];
							reg_rvs    <= db_in[6];
							reg_cbrate <= db_in[5];
							reg_vss    <= db_in[4:0];
						end
					25: begin
							reg_text   <= db_in[7];
							reg_atr    <= db_in[6];
							reg_semi   <= db_in[5];
							reg_dbl    <= db_in[4];
							reg_hss    <= db_in[3:0];
						end
					26: begin
							reg_fg     <= db_in[7:4];
							reg_bg     <= db_in[3:0];
						end
					27: reg_ai       <= db_in;
					28: begin
							reg_cb     <= db_in[7:5];
							reg_ram    <= db_in[4];
						end
					29: reg_ul       <= db_in[4:0];
					// writes to R30-R33 are handled by vdc_ramiface
					34: reg_deb      <= db_in;
					35: reg_dee      <= db_in;
					36: reg_drr      <= db_in[3:0];
					// R37 only exists in 8568
					37: if (version[1]) begin
							reg_hspol  <= db_in[7];
							reg_vspol  <= db_in[6];
						end
				endcase
			end
		end
		else
			if (!rs) begin
				db_out <= {~busy, lpStatus, vSync, 3'b000, version};
				lpStatus <= 0;
			end
			else if (!busy)
				case (regSel)
					 0: db_out <= reg_ht;
					 1: db_out <= reg_hd;
					 2: db_out <= reg_hp;
					 3: db_out <= {reg_vw, reg_hw};
					 4: db_out <= reg_vt;
					 5: db_out <= {3'b111, reg_va};
					 6: db_out <= reg_vd;
					 7: db_out <= reg_vp;
					 8: db_out <= {6'b111111, reg_im};
					 9: db_out <= {3'b111, reg_ctv};
					10: db_out <= {1'b1, reg_cm, reg_cs};
					11: db_out <= {3'b111, reg_ce};
					12: db_out <= reg_ds[15:8];
					13: db_out <= reg_ds[7:0];
					14: db_out <= reg_cp[15:8];
					15: db_out <= reg_cp[7:0];
					16: db_out <= reg_lpv;
					17: db_out <= reg_lph;
					18: db_out <= reg_ua[15:8];
					19: db_out <= reg_ua[7:0];
					20: db_out <= reg_aa[15:8];
					21: db_out <= reg_aa[7:0];
					22: db_out <= reg_cth & reg_cdh;
					23: db_out <= {3'b111, reg_cdv};
					24: db_out <= {reg_copy, reg_rvs, reg_cbrate, reg_vss};
					25: db_out <= {reg_text, reg_atr, reg_semi, reg_dbl, reg_hss};
					26: db_out <= {reg_fg, reg_bg};
					27: db_out <= reg_ai;
					28: db_out <= {reg_cb, reg_ram, 4'b1111};
					29: db_out <= {3'b111, reg_ul};
					30: db_out <= reg_wc;
					31: db_out <= reg_da;
					32: db_out <= reg_ba[15:8];
					33: db_out <= reg_ba[7:0];
					34: db_out <= reg_deb;
					35: db_out <= reg_dee;
					36: db_out <= {4'b1111, reg_drr};
					37: db_out <= {reg_hspol|~version[1], reg_vspol|~version[1], 6'b111111};
					default: db_out <= 8'b11111111;
				endcase
end

endmodule
