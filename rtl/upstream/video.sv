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
	input        hide_overscan,
	input  [3:0] palette,
	input  [2:0] emphasis,
	input  [1:0] reticle,
	input        pal_video,

	input        load_color,
	input [23:0] load_color_data,
	input  [5:0] load_color_index,

	output   reg hold_reset,

	output       ce_pix,
	output reg   HSync,
	output reg   VSync,
	output reg   HBlank,
	output reg   VBlank,
	output [7:0] R,
	output [7:0] G,
	output [7:0] B
);

reg pix_ce, pix_ce_n;
wire [5:0] color_ef = reticle[0] ? (reticle[1] ? 6'h21 : 6'h15) : is_padding ? 6'd63 : color;

always @(negedge clk) begin
	pix_ce   <= ~cnt[1] & ~cnt[0];
	pix_ce_n <=  cnt[1] & ~cnt[0];
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
	
	if(pix_ce_n) begin
		case (palette)
			0: pixel <= pal_kitrinx_lut[color_ef][23:0];
			1: pixel <= pal_smooth_lut[color_ef][23:0];
			2: pixel <= pal_wavebeam_lut[color_ef][23:0];
			3: pixel <= pal_sonycxa_lut[color_ef][23:0];
			4: pixel <= pal_pc10_lut[color_ef][23:0];
			5: pixel <= mem_data;
			default:pixel <= pal_kitrinx_lut[color_ef][23:0];
		endcase
	
		hbl <= hblank;
		vbl <= vblank;
	end
end


reg  hblank, vblank;
reg  [9:0] h, v;
reg  [1:0] free_sync = 0;
wire [9:0] hc = (&free_sync | reset) ? h : count_h;
wire [9:0] vc = (&free_sync | reset) ? v : count_v;
wire [9:0] vsync_start = (pal_video ? 10'd270 : 10'd243);

always @(posedge clk) begin
	reg [8:0] old_count_v;
	if (h == 0 && v == 0)
		hold_reset <= 1'b0;
	else if (reset)
		hold_reset <= 1'b1;

	if(pix_ce_n) begin
		if((old_count_v == 511) && (count_v == 0)) begin
			h <= 0;
			v <= 0;
			free_sync <= 0;
		end else begin
			if(h == 340) begin
				h <= 0;
				if(v == (pal_video ? 311 : 261)) begin
					v <= 0;
					if(~&free_sync) free_sync <= free_sync + 1'd1;
				end else begin
					v <= v + 1'd1;
				end
			end else begin
				h <= h + 1'd1;
			end
		end

		old_count_v <= count_v;
	end

	// The NES and SNES proper resolutions are 280 pixels wide, and 240 lines high. Only 256 of these pixels per line
	// are drawn with image data, but the real PPU padded the rest with color 0 to make the aspect ratio correct, since
	// they anticipated the overscan. This padding MUST be considered when scaling the image to 4:3 AR.
	// http://wiki.nesdev.com/w/index.php?title=Overscan#For_emulator_developers

	// Overscan is simply a zoom-in, and most emulators will take off 8 from the top and bottom to reach the magic
	// number of 224 pixels, so we take off a proportional percentage from the sides to compensate.

	if(pix_ce) begin
		if(hide_overscan) begin
			hblank <= (hc >= HBL_START && hc <= HBL_END);                  // 280 - ((224/240) * 16) = 261.3
			vblank <= (vc > (VBL_START - 9)) || (vc < 8);                  // 240 - 16 = 224
		end else begin
			hblank <= (hc >= HBL_START) && (hc <= HBL_END);                // 280 pixels
			vblank <= (vc >= VBL_START);                                   // 240 lines
		end
		
		if(hc == 279) begin
			HSync <= 1;
			VSync <= ((vc >= vsync_start) && (vc < vsync_start+3));
		end

		if(hc == 304) HSync <= 0;
	end
end

localparam HBL_START = 256;
localparam HBL_END   = 340;
localparam VBL_START = 240;
localparam VBL_END   = 511;

wire is_padding = (hc > 255);

reg dark_r, dark_g, dark_b;

wire [7:0] ri = pixel[23:16];
wire [7:0] gi = pixel[15:8];
wire [7:0] bi = pixel[7:0];

reg [7:0] ro,go,bo;
always @(posedge clk) if (pix_ce_n) begin
	reg [2:0] emph;
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
	
	HBlank <= hbl;
	VBlank <= vbl;
end

assign R = ro;
assign G = go;
assign B = bo;

endmodule
