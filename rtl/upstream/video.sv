// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

module video
(
	input        clk,
	input        reset,
	input  [1:0] cnt,
	input  [5:0] color,
	input  [8:0] count_h,
	input  [8:0] count_v,
	input  [1:0] hide_overscan,
	input  [3:0] palette,
	input  [2:0] emphasis,
	input  [1:0] reticle,
	input  [1:0] sys_type,
	input        pal_video,
	input        nes_hblank,
	input        nes_hsync,
	input        nes_vsync,
	input        nes_vblank,

	input        load_color,
	input [23:0] load_color_data,
	input  [5:0] load_color_index,

	output   reg hold_reset,

	output       ce_pix,
	output       HSync,
	output       VSync,
	output       HBlank,
	output       VBlank,
	output [7:0] R,
	output [7:0] G,
	output [7:0] B
);

reg vsync_reg, hsync_reg, hblank_reg, vblank_reg;
reg [1:0] hsync_shift, vsync_shift, hblank_shift, vblank_shift;

assign HSync = hsync_shift[1];
assign VSync = vsync_shift[1];
assign HBlank = hblank_shift[1];
assign VBlank = vblank_shift[1];

wire hsync_out = hsync_reg | nes_hsync;
wire vsync_out = vsync_reg | nes_vsync;
wire hblank_out = hblank_reg | nes_hblank;
wire vblank_out = vblank_reg | nes_vblank;

reg pix_ce;
wire [5:0] color_ef = reticle[0] ? (reticle[1] ? 6'h21 : 6'h15) : color;

always @(posedge clk) begin
	pix_ce   <= ~cnt[1] & ~cnt[0];
end

assign ce_pix = pix_ce;
// Kitrinx 34 palette by Kitrinx
wire [23:0] pal_kitrinx_lut[64] = '{
	'h666666, 'h01247B, 'h1B1489, 'h39087C, 'h520257, 'h5C0725, 'h571300, 'h472300,
	'h2D3300, 'h0E4000, 'h004500, 'h004124, 'h003456, 'h000000, 'h000000, 'h000000,
	'hADADAD, 'h2759C9, 'h4845DB, 'h6F34CA, 'h922B9B, 'hA1305A, 'h9B4018, 'h885400,
	'h686700, 'h3E7A00, 'h1B8213, 'h0D7C57, 'h136C99, 'h000000, 'h000000, 'h000000,
	'hFFFFFF, 'h78ABFF, 'h9897FF, 'hC086FF, 'hE27DEF, 'hF281AF, 'hED916D, 'hDBA43B,
	'hBDB825, 'h92CB33, 'h6DD463, 'h5ECEA8, 'h65BEEA, 'h525252, 'h000000, 'h000000,
	'hFFFFFF, 'hCADBFF, 'hD8D2FF, 'hE7CCFF, 'hF4C9F9, 'hFACBDF, 'hF7D2C4, 'hEEDAAF,
	'hE1E3A5, 'hD0EBAB, 'hC2EEBF, 'hBDEBDB, 'hC0E4F7, 'hB8B8B8, 'h000000, 'h000000
};

// Smooth palette from FirebrandX
wire [23:0] pal_smooth_lut[64] = '{
	'h6A6D6A, 'h001380, 'h1E008A, 'h39007A, 'h550056, 'h5A0018, 'h4F1000, 'h3D1C00,
	'h253200, 'h003D00, 'h004000, 'h003924, 'h002E55, 'h000000, 'h000000, 'h000000,
	'hB9BCB9, 'h1850C7, 'h4B30E3, 'h7322D6, 'h951FA9, 'h9D285C, 'h983700, 'h7F4C00,
	'h5E6400, 'h227700, 'h027E02, 'h007645, 'h006E8A, 'h000000, 'h000000, 'h000000,
	'hFFFFFF, 'h68A6FF, 'h8C9CFF, 'hB586FF, 'hD975FD, 'hE377B9, 'hE58D68, 'hD49D29,
	'hB3AF0C, 'h7BC211, 'h55CA47, 'h46CB81, 'h47C1C5, 'h4A4D4A, 'h000000, 'h000000,
	'hFFFFFF, 'hCCEAFF, 'hDDDEFF, 'hECDAFF, 'hF8D7FE, 'hFCD6F5, 'hFDDBCF, 'hF9E7B5,
	'hF1F0AA, 'hDAFAA9, 'hC9FFBC, 'hC3FBD7, 'hC4F6F6, 'hBEC1BE, 'h000000, 'h000000
};

// PC-10 Better by Kitrinx
wire [23:0] pal_pc10_lut[64] = '{
	'h6D6D6D, 'h10247C, 'h0A06B3, 'h6950C2, 'h6A0F62, 'h831264, 'h872F0F, 'h774C11,
	'h5E490F, 'h2C430A, 'h1E612A, 'h258011, 'h164244, 'h000000, 'h000000, 'h000000,
	'hB6B6B6, 'h2767C0, 'h1F48DA, 'h7114DA, 'h8A17DC, 'hB71987, 'hB0150F, 'hB37219,
	'h806C15, 'h3E8313, 'h258011, 'h34A46F, 'h2C8589, 'h000000, 'h000000, 'h000000,
	'hFFFFFF, 'h87B2ED, 'h9795EB, 'hC07BEB, 'hBD1DE1, 'hD97EED, 'hD59620, 'hDFB624,
	'hCFD326, 'h84CA20, 'h41E11D, 'h7FEED6, 'h4EE9EF, 'h000000, 'h000000, 'h000000,
	'hFFFFFF, 'hC3D8F6, 'hD2BBF4, 'hECBEF6, 'hE29EF2, 'hE8BCBA, 'hF0DBA0, 'hF5F969,
	'hF7FA87, 'hC3F364, 'hACF180, 'h7FEED6, 'hAAD5F4, 'h000000, 'h000000, 'h000000
};

// Wavebeam by NakedArthur
wire [23:0] pal_wavebeam_lut[64] = '{
	'h6B6B6B, 'h001B88, 'h21009A, 'h40008C, 'h600067, 'h64001E, 'h590800, 'h481600,
	'h283600, 'h004500, 'h004908, 'h00421D, 'h003659, 'h000000, 'h000000, 'h000000,
	'hB4B4B4, 'h1555D3, 'h4337EF, 'h7425DF, 'h9C19B9, 'hAC0F64, 'hAA2C00, 'h8A4B00,
	'h666B00, 'h218300, 'h008A00, 'h008144, 'h007691, 'h000000, 'h000000, 'h000000,
	'hFFFFFF, 'h63B2FF, 'h7C9CFF, 'hC07DFE, 'hE977FF, 'hF572CD, 'hF4886B, 'hDDA029,
	'hBDBD0A, 'h89D20E, 'h5CDE3E, 'h4BD886, 'h4DCFD2, 'h525252, 'h000000, 'h000000,
	'hFFFFFF, 'hBCDFFF, 'hD2D2FF, 'hE1C8FF, 'hEFC7FF, 'hFFC3E1, 'hFFCAC6, 'hF2DAAD,
	'hEBE3A0, 'hD2EDA2, 'hBCF4B4, 'hB5F1CE, 'hB6ECF1, 'hBFBFBF, 'h000000, 'h000000
};

// Sony CXA by FirebrandX
wire [23:0] pal_sonycxa_lut[64] = '{
	'h585858, 'h00238C, 'h00139B, 'h2D0585, 'h5D0052, 'h7A0017, 'h7A0800, 'h5F1800,
	'h352A00, 'h093900, 'h003F00, 'h003C22, 'h00325D, 'h000000, 'h000000, 'h000000,
	'hA1A1A1, 'h0053EE, 'h153CFE, 'h6028E4, 'hA91D98, 'hD41E41, 'hD22C00, 'hAA4400,
	'h6C5E00, 'h2D7300, 'h007D06, 'h007852, 'h0069A9, 'h000000, 'h000000, 'h000000,
	'hFFFFFF, 'h1FA5FE, 'h5E89FE, 'hB572FE, 'hFE65F6, 'hFE6790, 'hFE773C, 'hFE9308,
	'hC4B200, 'h79CA10, 'h3AD54A, 'h11D1A4, 'h06BFFE, 'h424242, 'h000000, 'h000000,
	'hFFFFFF, 'hA0D9FE, 'hBDCCFE, 'hE1C2FE, 'hFEBCFB, 'hFEBDD0, 'hFEC5A9, 'hFED18E,
	'hE9DE86, 'hC7E992, 'hA8EEB0, 'h95ECD9, 'h91E4FE, 'hACACAC, 'h000000, 'h000000
};


wire [23:0] mem_data;

spram #(.addr_width(6), .data_width(24), .mem_name("pal"), .mem_init_file("rtl/tao.mif")) pal_ram
(
	.clock(clk),
	.address(load_color ? load_color_index : color_ef),
	.data(load_color_data),
	.wren(load_color),
	.q(mem_data)
);

reg [23:0] pixel;

reg hbl, vbl;

always @(posedge clk) begin
	if(pix_ce) begin
		case (palette)
			0: pixel <= pal_kitrinx_lut[color_ef][23:0];
			1: pixel <= pal_smooth_lut[color_ef][23:0];
			2: pixel <= pal_wavebeam_lut[color_ef][23:0];
			3: pixel <= pal_sonycxa_lut[color_ef][23:0];
			4: pixel <= pal_pc10_lut[color_ef][23:0];
			5: pixel <= mem_data;
			default:pixel <= pal_kitrinx_lut[color_ef][23:0];
		endcase
	end
end

wire disengaged = reset || hold_reset;

reg  hblank, vblank;
reg  [8:0] h, v;
wire [8:0] hc = disengaged ? h : count_h;
wire [8:0] vc = disengaged ? v : count_v;
wire [8:0] vblank_start, vblank_end, hblank_start, hblank_end, hsync_start, hsync_end;
wire [8:0] vblank_start_sl, vblank_end_sl, vsync_start_sl;
wire hblank_period;

always_comb begin
	case (sys_type)
		2'b00,2'b11: begin // NTSC/Vs.
			vblank_start_sl = 9'd241;
			vblank_end_sl   = 9'd260;
			vsync_start_sl = 9'd244;
		end

		2'b01: begin       // PAL
			vblank_start_sl = 9'd241;
			vblank_end_sl   = 9'd310;
			vsync_start_sl = 9'd269;
		end

		2'b10: begin       // Dendy
			vblank_start_sl = 9'd241; // Vblank starts here allegedly, even though the flag is set at 291
			vblank_end_sl   = 9'd310;
			vsync_start_sl = 9'd269; // Guessing it's the same as PAL
		end
	endcase

	case (hide_overscan)
		2'b00: begin // Normal, trim to 224 lines, 256 dots
			hblank_period = (hc >= 257 || (hc <= 9'd0));
			vblank_start = vblank_start_sl - 9'd10;
			vblank_end = 9'd7;
		end
		2'b01: begin // "full" trim to 240 lines, 256 dots
			hblank_period = (hc >= 257 || (hc <= 9'd0));
			vblank_start = vblank_start_sl - 9'd2;
			vblank_end = 9'd511;
		end
		2'b10: begin // show border trim to 240 lines, 282 dots
			hblank_period = (hc >= 270 && hc <= 327);
			vblank_start = vblank_start_sl - 9'd2;
			vblank_end = 9'd511;
		end
		default: begin // Just show everything for the masochists
			hblank_period = (hc >= 270 && hc <= 326);
			vblank_start = vblank_start_sl;
			vblank_end = 9'd511;
		end
	endcase
end

wire hsync_period = (hc >= 278 && hc <= 302);

wire [7:0] ri = pixel[23:16];
wire [7:0] gi = pixel[15:8];
wire [7:0] bi = pixel[7:0];
reg [7:0] ro,go,bo;


always @(posedge clk) begin
	reg [2:0] emph;

	if (pix_ce) begin
		hsync_shift <= {hsync_shift[0], hsync_out};
		vsync_shift <= {vsync_shift[0], vsync_out};
		hblank_shift <= {hblank_shift[0], hblank_out};
		vblank_shift <= {vblank_shift[0], vblank_out};

		if (h == 0 && v == 0)
			hold_reset <= 1'b0;
		else if (reset)
			hold_reset <= 1'b1;

		h <= h + 1'd1;
		if (h >= 340) begin
			h <= 0;
			v <= v + 1'd1;
			if (v == vblank_end_sl)
				v <= 9'd511;
		end

		if (count_h == 5 && count_v == 0) begin // Resync the counters in case of skipped dots
			h <= 6'd0;
			v <= 0;
		end

		hsync_reg <= hsync_period;
		hblank_reg <= hblank_period;

		if (vc == vsync_start_sl && hsync_period)
			vsync_reg <= 1;
		if (vc == (vsync_start_sl + 2'd3) && hsync_period)
			vsync_reg <= 0;

		if (vc == vblank_start && hsync_period)
			vblank_reg <= 1;
		if (vc == vblank_end && hsync_period)
			vblank_reg <= 0;

		ro <= ri;
		go <= gi;
		bo <= bi;
		emph <= 0;
		if (~&color_ef[3:1]) begin // Only applies in draw range
			emph <= emphasis;
		end

		case(emph)
			1: begin
					ro <= ri;
					go <= gi - gi[7:2];
					bo <= bi - bi[7:2];
				end
			2: begin
					ro <= ri - ri[7:2];
					go <= gi;
					bo <= bi - bi[7:2];
				end
			3: begin
					ro <= ri - ri[7:2];
					go <= gi - gi[7:3];
					bo <= bi - bi[7:2] - bi[7:3];
				end
			4: begin
					ro <= ri - ri[7:3];
					go <= gi - gi[7:3];
					bo <= bi;
				end
			5: begin
					ro <= ri - ri[7:3];
					go <= gi - gi[7:2];
					bo <= bi - bi[7:3];
				end
			6: begin
					ro <= ri - ri[7:2];
					go <= gi - gi[7:3];
					bo <= bi - bi[7:3];
				end
			7: begin
					ro <= ri - ri[7:2];
					go <= gi - gi[7:2];
					bo <= bi - bi[7:2];
				end
		endcase
	end
end

assign R = ro;
assign G = go;
assign B = bo;

endmodule
