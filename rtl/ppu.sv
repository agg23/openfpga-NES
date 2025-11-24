// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

// altera message_off 10935
// altera message_off 10027

import regs_savestates::*;

// Module handles updating the vram scroll register
module VramAddressGen (
	input clk,
	input clear,
	input ce,
	input reset,
	input is_rendering,
	input [2:0] ain,     // input address from CPU
	input [7:0] din,     // data input
	input read,          // read
	input write,         // write
	input is_pre_render, // Is this the pre-render scanline
	input trigger_2007,
	input [8:0] cycle,
	output [14:0] vram,
	output [2:0] fine_x_scroll,  // Current vram value
	// savestates
	input [63:0]  SaveStateBus_Din,
	input [ 9:0]  SaveStateBus_Adr,
	input         SaveStateBus_wren,
	input         SaveStateBus_rst,
	output [63:0] SaveStateBus_Dout
);

wire [63:0] SS_vram;
wire [63:0] SS_vram_BACK;
eReg_SavestateV #(SSREG_INDEX_LOOPY, SSREG_DEFAULT_LOOPY) iREG_SAVESTATE (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout, SS_vram_BACK, SS_vram);

// Controls how much to increment on each write
reg ppu_incr; // 0 = 1, 1 = 32
// Current VRAM address
reg [14:0] vram_v;
// Temporary VRAM address
reg [14:0] vram_t;
// Fine X scroll (3 bits)
reg [2:0] vram_x;
// Latch
reg ppu_address_latch;
reg [1:0] write_shift;

assign SS_vram_BACK[    0] = ppu_incr;
assign SS_vram_BACK[15: 1] = vram_v;
assign SS_vram_BACK[30:16] = vram_t;
assign SS_vram_BACK[33:31] = vram_x;
assign SS_vram_BACK[   34] = ppu_address_latch;
assign SS_vram_BACK[52:51] = write_shift;
assign SS_vram_BACK[63:55] = 9'b0; // free to be used

wire write_2006b = write_shift[1];

wire inc_horizontal = (cycle[2:0] == 7 && ((cycle <= 255) || (cycle >= 320 && cycle <= 335)) && is_rendering);
wire inc_vertical = (cycle == 255) && is_rendering;
wire copy_hscroll = ((cycle == 256) && is_rendering) || write_2006b;
wire copy_vscroll = ((cycle >= 279 && cycle <= 303) && is_pre_render && is_rendering) || write_2006b;

wire  [14:0] vram_t_mask;
assign {vram_t_mask[10], vram_t_mask[4:0]} = (write_2006b || copy_hscroll) ? {vram_t[10], vram_t[4:0]} : 6'b11_1111;
assign {vram_t_mask[14:11], vram_t_mask[9:5]} = (write_2006b || copy_vscroll) ? {vram_t[14:11], vram_t[9:5]} : 9'b1_1111_1111;

// Handle updating vram_t and vram_v
always @(posedge clk) begin
	if (reset) begin
		ppu_incr          <= SS_vram[    0]; //0;
		vram_v           <= SS_vram[15: 1]; //0;
		vram_t           <= SS_vram[30:16]; //0;
		vram_x           <= SS_vram[33:31]; //0;
		ppu_address_latch <= SS_vram[   34]; //0;
		write_shift       <= SS_vram[52:51]; //0;
	end else if (ce) begin

		// Horizontal copy at cycle 256 and rendering OR if delayed 2006 write
		if (copy_hscroll)
			{vram_v[10], vram_v[4:0]} <= {vram_t[10], vram_t[4:0]};

		// Vertical copy at Cycles 279 to 303 and rendering OR delayed 2006 write
		if (copy_vscroll)
			{vram_v[14:11], vram_v[9:5]} <= {vram_t[14:11], vram_t[9:5]};

		// Increment course X scroll from (cycle 0-255 or 320-335) and cycle[2:0] == 7
		if (inc_horizontal || (trigger_2007 && is_rendering)) begin
			vram_v[4:0] <= (vram_v[4:0] + 1'd1) & vram_t_mask[4:0];
			vram_v[10] <= (vram_v[10] ^ &vram_v[4:0]) & vram_t_mask[10];
			if (copy_hscroll) begin // vram_t will also get corrupted
				vram_t[4:0] <= (vram_v[4:0] + 1'd1) & vram_t_mask[4:0];
				vram_t[10] <= (vram_v[10] ^ &vram_v[4:0]) & vram_t_mask[10];
			end
		end

		// Vertical Increment at 255 and rendering
		if (inc_vertical || (trigger_2007 && is_rendering)) begin
			vram_v[14:12] <= (vram_v[14:12] + 1'd1) & vram_t_mask[14:12];
			vram_v[9:5] <= vram_v[9:5] & vram_t_mask[9:5];
			vram_v[11] <= vram_v[11] & vram_t_mask[11];
			if (vram_v[14:12] == 7) begin
				if (vram_v[9:5] == 29) begin
					vram_v[9:5] <= 0;
					vram_v[11] <= ~vram_v[11] & vram_t_mask[11];
				end else begin
					vram_v[9:5] <= (vram_v[9:5] + 1'd1) & vram_t_mask[9:5];
				end
			end
			if (copy_vscroll) begin // vram_t will also get corrupted
				vram_t[14:12] <= (vram_v[14:12] + 1'd1) & vram_t_mask[14:12];
				vram_t[9:5] <= vram_v[9:5] & vram_t_mask[9:5];
				vram_t[11] <= vram_v[11] & vram_t_mask[11];
				if (vram_v[14:12] == 7) begin
					if (vram_v[9:5] == 29) begin
						vram_t[9:5] <= 0;
						vram_t[11] <= ~vram_v[11] & vram_t_mask[11];
					end else begin
						vram_t[9:5] <= (vram_v[9:5] + 1'd1) & vram_t_mask[9:5];
					end
				end
			end
		end

		if (~is_rendering && trigger_2007 && !clear)
			vram_v <= vram_v + (ppu_incr ? 15'd32 : 15'd1);

		if (write && ain == 0) begin
			vram_t[10] <= din[0];
			vram_t[11] <= din[1];
			ppu_incr <= din[2];
		end else if (write && ain == 5) begin
			if (!ppu_address_latch) begin
				vram_t[4:0] <= din[7:3];
				vram_x <= din[2:0];
			end else begin
				vram_t[9:5] <= din[7:3];
				vram_t[14:12] <= din[2:0];
			end
			ppu_address_latch <= !ppu_address_latch;
		end else if (write && ain == 6) begin
			ppu_address_latch <= !ppu_address_latch;
			if (!ppu_address_latch) begin
				vram_t[13:8] <= din[5:0];
				vram_t[14] <= 0;
			end else begin
				vram_t[7:0] <= din;
			end
		end else if (read && ain == 2) begin
			ppu_address_latch <= 0; //Reset PPU address latch
		end

		// Writes to vram address appear to be delayed by 2 cycles
		write_shift <= {write_shift[0], (write && ain == 6) && ppu_address_latch};

		if (clear) begin
			vram_t <= 0;
			vram_x <= 0;
			ppu_address_latch <= 0;
		end
	end
end

assign vram = vram_v;
assign fine_x_scroll = vram_x;

endmodule


// Generates the current scanline / cycle counters
module ClockGen #(parameter USE_SAVESTATE = 0) (
	input clk,
	input ce,
	input reset,
	input [1:0] sys_type,
	input is_rendering,
	output reg [8:0] scanline,
	output reg [8:0] cycle,
	output reg is_in_vblank,
	output end_of_line,
	output at_last_cycle_group,
	output exiting_vblank,
	output entering_vblank,
	output reg is_pre_render,
	output short_frame,
	output is_vbe_sl,
	output evenframe,
	output reg hsync,
	output reg vsync,
	output reg hblank,
	output reg vblank,
	// savestates
	input [63:0]  SaveStateBus_Din,
	input [ 9:0]  SaveStateBus_Adr,
	input         SaveStateBus_wren,
	input         SaveStateBus_rst,
	output [63:0] SaveStateBus_Dout
);

reg is_even_frame = 0; // 1 indicates even frame.
assign evenframe = is_even_frame;

// Dendy is 291 to 310
wire [8:0] vblank_start_sl;
wire [8:0] vblank_end_sl;
wire [8:0] vsync_start_sl;
wire [8:0] last_sl;
wire skip_en;
reg [3:0] rendering_sr;

always_comb begin
	case (sys_type)
		2'b00,2'b11: begin // NTSC/Vs.
			vblank_start_sl = 9'd241;
			vblank_end_sl   = 9'd260;
			vsync_start_sl  = 9'd244;
			skip_en         = 1'b1;
		end

		2'b01: begin       // PAL
			vblank_start_sl = 9'd241;
			vblank_end_sl   = 9'd310;
			vsync_start_sl  = 9'd269;
			skip_en         = 1'b0;
		end

		2'b10: begin       // Dendy
			vblank_start_sl = 9'd291; // FIXME vblank doesn't ACTUALLY start here, just the nmi
			vblank_end_sl   = 9'd310;
			vsync_start_sl  = 9'd269; // Guessing it's the same as PAL
			skip_en         = 1'b0;
		end
	endcase
end

assign at_last_cycle_group = (cycle[8:3] == 42);

// For NTSC only, the *last* cycle of odd frames is skipped.
// In Visual 2C02, the counter starts at zero and flips at scanline 256.
assign short_frame = end_of_line & skip_pixel;
reg skip_next = 0;
wire skip_pixel = skip_next && skip_en;
assign end_of_line = at_last_cycle_group && (cycle[3:0] == (skip_pixel ? 3 : 4));

// Confimed with Visual 2C02
// All vblank clocked registers should have changed and be readable by cycle 1 of 241/261
assign entering_vblank = (cycle == 0) && scanline == vblank_start_sl;
assign exiting_vblank = (cycle == 0) && is_pre_render;

assign is_vbe_sl = (scanline == vblank_end_sl);

// New value for is_in_vblank flag
wire new_is_in_vblank = entering_vblank ? 1'b1 : exiting_vblank ? 1'b0 : is_in_vblank;

// Savestates
wire [63:0] SS_CLKGEN;
generate
	if (USE_SAVESTATE) begin
		wire [63:0] SS_CLKGEN_BACK;
		wire [63:0] SS_CLKGEN_OUT;
		eReg_SavestateV #(SSREG_INDEX_CLOCKGEN, SSREG_DEFAULT_CLOCKGEN) iREG_SAVESTATE (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SS_CLKGEN_OUT, SS_CLKGEN_BACK, SS_CLKGEN);
		assign SaveStateBus_Dout = SS_CLKGEN_OUT;

		assign SS_CLKGEN_BACK[  8:0] = cycle;
		assign SS_CLKGEN_BACK[    9] = is_in_vblank;
		assign SS_CLKGEN_BACK[13:10] = rendering_sr;
		assign SS_CLKGEN_BACK[22:14] = scanline;
		assign SS_CLKGEN_BACK[   23] = is_pre_render;
		assign SS_CLKGEN_BACK[   24] = is_even_frame;
		assign SS_CLKGEN_BACK[   25] = skip_next;
		assign SS_CLKGEN_BACK[   26] = vblank;
		assign SS_CLKGEN_BACK[   27] = hblank;
		assign SS_CLKGEN_BACK[   28] = vsync;
		assign SS_CLKGEN_BACK[   29] = hsync;
		assign SS_CLKGEN_BACK[63:30] = 34'b0; // free to be used
	end else begin
		assign SS_CLKGEN         = 64'b0;
		assign SaveStateBus_Dout = SS_CLKGEN;
	end
endgenerate

wire hsync_period = (cycle >= 278 && cycle <= 302);
wire hblank_period = (cycle >= 269 && cycle <= 326);

// Set if the current line is line 0..239
always @(posedge clk) if (reset) begin
	skip_next <= 0;
	if (USE_SAVESTATE) begin
		cycle        <= SS_CLKGEN[  8:0]; // 338;
		is_in_vblank <= SS_CLKGEN[    9]; // 0;
		rendering_sr <= SS_CLKGEN[13:10]; // no reset before => 0 should be ok;
		skip_next    <= SS_CLKGEN[   25]; // 0;
		vblank       <= SS_CLKGEN[   26]; // 0;
		hblank       <= SS_CLKGEN[   27]; // 0;
		vsync        <= SS_CLKGEN[   28]; // 0;
		hsync        <= SS_CLKGEN[   29]; // 0;
	end else begin
		cycle        <= 0;
		is_in_vblank <= 0;
		rendering_sr <= '0;
		skip_next    <= 0;
		vblank       <= 0;
		hblank       <= 0;
		vsync        <= 0;
		hsync        <= 0;
	end
end else if (ce) begin
	if (cycle == 338) begin
		skip_next <= is_pre_render && ~is_even_frame && is_rendering && skip_en;
	end
	rendering_sr <= {rendering_sr[2:0], is_rendering};
	cycle <= end_of_line ? 9'd0 : cycle + 9'd1;
	is_in_vblank <= new_is_in_vblank;

	hsync <= hsync_period;
	hblank <= hblank_period;

	if (scanline == vsync_start_sl && hsync_period)
		vsync <= 1;
	if (scanline == (vsync_start_sl + 3'd3) && hsync_period)
		vsync <= 0;

	if (scanline == 9'd241 && hblank_period)
		vblank <= 1;
	if (is_pre_render && hblank_period)
		vblank <= 0;
end

always @(posedge clk) if (reset) begin
	if (USE_SAVESTATE) begin
		scanline          <= SS_CLKGEN[22:14]; // 0;
		is_pre_render     <= SS_CLKGEN[   23]; // 0;
		is_even_frame      <= SS_CLKGEN[   24]; // 0; // Resets to 0, the first frame will always end with 341 pixels.
	end else begin
		scanline          <= 0;
		is_pre_render     <= 0;
		is_even_frame      <= 0; // Resets to 0, the first frame will always end with 341 pixels.
	end
end else if (ce && end_of_line) begin
	// Once the scanline counter reaches end of 260, it gets reset to -1.
	scanline <= (scanline == vblank_end_sl) ? 9'b111111111 : scanline + 1'd1;
	// The pre render flag is set while we're on scanline -1.
	is_pre_render <= (scanline == vblank_end_sl);

	if (scanline == 255)
		is_even_frame <= ~is_even_frame;
end

endmodule // ClockGen

// 8 of these exist, they are used to output sprites.
module Sprite(
	input clk,
	input ce,
	input enable,
	input counting,
	input rendering,
	input [3:0] load,
	input [26:0] load_in,
	output [26:0] load_out,
	output [4:0] bits // Low 4 bits = pixel, high bit = prio
);

reg [1:0] upper_color; // Upper 2 bits of color
reg [7:0] x_coord;     // X coordinate where we want things
reg [7:0] pix1, pix2;  // Shift registers, output when x_coord == 0
reg aprio;             // Current prio
wire active = (x_coord == 0) || (enable && !counting); // Set to 1 when x_coord is zero

always @(posedge clk) if (ce) begin
	if (!active && counting) begin
		// Decrease until x_coord is zero.
		x_coord <= x_coord - 8'h01;
	end else if (rendering && enable) begin
		pix1 <= pix1 >> 1;
		pix2 <= pix2 >> 1;
	end
	if (load[3]) pix1 <= load_in[26:19];
	if (load[2]) pix2 <= load_in[18:11];
	if (load[1]) x_coord <= load_in[10:3];
	if (load[0]) {upper_color, aprio} <= load_in[2:0];
end
assign bits = {aprio, upper_color, active && pix2[0], active && pix1[0]};
assign load_out = {pix1, pix2, x_coord, upper_color, aprio};

endmodule  // SpriteGen

// This contains all sprites. Will return the pixel value of the highest prioritized sprite.
// When load is set, and clocked, load_in is loaded into sprite 15 and all others are shifted down.
// Sprite 0 has highest prio.
module SpriteSet(
	input clk,
	input ce,               // Input clock
	input enable,           // Enable pixel generation
	input counting,         // Set to 1 if counting is enabled
	input rendering,        // Set to 1 if rendering is enabled
	input [3:0] load,       // Which parts of the state to load/shift.
	input [3:0] load_ex,    // Which parts of the state to load/shift for extra sprites.
	input [26:0] load_in,   // State to load with
	input [26:0] load_in_ex,// Extra spirtes
	output [4:0] bits,      // Output bits
	output is_sprite0,       // Set to true if sprite #0 was output
	input extra_sprites
);

wire [26:0] load_out7, load_out6, load_out5, load_out4, load_out3, load_out2, load_out1, load_out0,
	load_out15, load_out14, load_out13, load_out12, load_out11, load_out10, load_out9, load_out8;
wire [4:0] bits7, bits6, bits5, bits4, bits3, bits2, bits1, bits0,
	bits15, bits14, bits13, bits12, bits11, bits10, bits9, bits8;

// Extra sprites
Sprite sprite15(clk, ce, enable, counting, rendering, load_ex, load_in_ex, load_out15, bits15);
Sprite sprite14(clk, ce, enable, counting, rendering, load_ex, load_out15, load_out14, bits14);
Sprite sprite13(clk, ce, enable, counting, rendering, load_ex, load_out14, load_out13, bits13);
Sprite sprite12(clk, ce, enable, counting, rendering, load_ex, load_out13, load_out12, bits12);
Sprite sprite11(clk, ce, enable, counting, rendering, load_ex, load_out12, load_out11, bits11);
Sprite sprite10(clk, ce, enable, counting, rendering, load_ex, load_out11, load_out10, bits10);
Sprite sprite9( clk, ce, enable, counting, rendering, load_ex, load_out10, load_out9,  bits9);
Sprite sprite8( clk, ce, enable, counting, rendering, load_ex, load_out9,  load_out8,  bits8);

// Basic Sprites
Sprite sprite7( clk, ce, enable, counting, rendering, load, load_in,    load_out7,  bits7);
Sprite sprite6( clk, ce, enable, counting, rendering, load, load_out7,  load_out6,  bits6);
Sprite sprite5( clk, ce, enable, counting, rendering, load, load_out6,  load_out5,  bits5);
Sprite sprite4( clk, ce, enable, counting, rendering, load, load_out5,  load_out4,  bits4);
Sprite sprite3( clk, ce, enable, counting, rendering, load, load_out4,  load_out3,  bits3);
Sprite sprite2( clk, ce, enable, counting, rendering, load, load_out3,  load_out2,  bits2);
Sprite sprite1( clk, ce, enable, counting, rendering, load, load_out2,  load_out1,  bits1);
Sprite sprite0( clk, ce, enable, counting, rendering, load, load_out1,  load_out0,  bits0);

// Determine which sprite is visible on this pixel.
assign bits = bits_orig;
wire [4:0] bits_orig =
	bits0[1:0]  != 0 ? bits0 :
	bits1[1:0]  != 0 ? bits1 :
	bits2[1:0]  != 0 ? bits2 :
	bits3[1:0]  != 0 ? bits3 :
	bits4[1:0]  != 0 ? bits4 :
	bits5[1:0]  != 0 ? bits5 :
	bits6[1:0]  != 0 ? bits6 :
	bits7[1:0]  != 0 || ~extra_sprites ? bits7 :
	bits_ex;

wire [4:0] bits_ex =
	bits8[1:0]  != 0 ? bits8 :
	bits9[1:0]  != 0 ? bits9 :
	bits10[1:0] != 0 ? bits10 :
	bits11[1:0] != 0 ? bits11 :
	bits12[1:0] != 0 ? bits12 :
	bits13[1:0] != 0 ? bits13 :
	bits14[1:0] != 0 ? bits14 :
	bits15;

assign is_sprite0 = bits0[1:0] != 0;

endmodule  // SpriteSet

module OAMEval(
	input clk,
	input ce,
	input reset,
	input clear_signal,
	input end_of_line,
	input rendering_enabled,   // Set to 1 if evaluations are enabled
	input obj_size,            // Set to 1 if objects are 16 pixels.
	input [8:0] scanline,      // Current scan line (compared against Y)
	input [8:0] cycle,         // Current cycle.
	output [7:0] oam_bus,      // Current value on the OAM bus, returned to NES through $2004.
	output reg [31:0] oam_bus_ex,
	input oam_addr_write,      // Load oam with specified value, when writing to NES $2003.
	input oam_data_write,      // Load oam_ptr with specified value, when writing to NES $2004.
	input [7:0] oam_din,       // New value for oam or oam_ptr
	output reg overflow,   // Set to true if we had more than 8 objects on a scan line. Reset when exiting vblank.
	output reg sprite0,        // True if sprite#0 is included on the scan line currently being painted.
	input is_vbe,              // Last line before pre-render
	input PAL,
	output in_range,
	output masked_sprites,     // If the game is trying to mask extra sprites
	input is_pre_render,
	// savestates
	input [63:0]  SaveStateBus_Din,
	input [ 9:0]  SaveStateBus_Adr,
	input         SaveStateBus_wren,
	input         SaveStateBus_rst,
	output [63:0] SaveStateBus_Dout,

	input  [7:0]  Savestate_OAMAddr,
	input         Savestate_OAMRdEn,
	input         Savestate_OAMWrEn,
	input  [7:0]  Savestate_OAMWriteData,
	output [7:0]  Savestate_OAMReadData
);

wire [63:0] SS_OAMEVAL;
wire [63:0] SS_OAMEVAL_BACK;
eReg_SavestateV #(SSREG_INDEX_OAMEVAL, SSREG_DEFAULT_OAMEVAL) iREG_SAVESTATE (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout, SS_OAMEVAL_BACK, SS_OAMEVAL);


// https://wiki.nesdev.com/w/index.php/PPU_sprite_evaluation
// NOTE: At the time of this writing, much information on the wiki is off by one, as mentioned here:
// https://forums.nesdev.com/viewtopic.php?f=3&t=19005

assign oam_bus = oam_data;
wire [7:0] oam_dbus = oam_data_write ? oam_din : oam_data;

enum {
	STATE_IDLE,
	STATE_CLEAR,
	STATE_EVAL,
	STATE_FETCH,
	STATE_REFRESH
} oam_state = STATE_IDLE;

reg [7:0] oam_temp[64];    // OAM Temporary buffer, normally 32 bytes, 64 for extra sprites
reg [7:0] oam[256];        // OAM RAM, 256 bytes
reg [7:0] oam_addr;        // OAM Address Register 2003
reg [2:0] oam_secondary_row;   // Pointer to oam_temp;
reg [7:0] oam_data;        // OAM Data Register 2004
reg oam_secondary_ovr;         // Write enable for OAM temp, disabled if full

// Extra Registers
reg [5:0] oam_addr_ex;     // OAM pointer for use with extra sprites
reg [3:0] oam_secondary_row_ex;
reg [2:0] spr_counter;     // Count sprites

reg old_rendering;
reg old_using_secondary;

wire visible = (scanline < 240);
wire rendering = (is_pre_render || visible) && rendering_enabled;
wire evaluating = visible && rendering_enabled;
wire secondary_write = cycle[0];

wire [7:0] oam_read_addr = oam_addr_write ? oam_din : oam_addr;
wire is_attr_byte = oam_read_addr[1:0] == 2'b10;

// Note the following corruption evaluation is NOT suitable for use generally because of it's combinational nature
wire using_secondary = rendering && ((~cycle[0] && cycle <= 8'd255) || cycle > 8'd255) ? 1'b1 : 1'b0;
wire [4:0] oam_row_cur = using_secondary ? oam_secondary_addr : (oam_addr_write ? oam_din[7:3] : oam_addr[7:3]);
wire [4:0] oam_row_last = old_using_secondary ? oam_secondary_addr : oam_addr[7:3];

// 2003 writes will cause a ram row corruption ONLY when the write occurs during the wrong *half*
// of a PPU cycle. During certain cpu/ppu alignments, including the "good" alignment, this won't
// occur at all. It seems to cause problems sometimes so I'll leave it here as reference but
// it seems best to keep it disabled until actual unaligned PPU can be implemented.

wire corrupting_write = 0;// (oam_addr_write & ~using_secondary);

assign in_range = scanline[7:0] >= oam_dbus && scanline[7:0] < oam_dbus + (obj_size ? 16 : 8);

wire clear_secondary_addr = ((cycle == 63) || (cycle == 255) || (cycle == 339)) && rendering;

reg [4:0] oam_secondary_addr;

reg sprite0_curr;
reg [2:0] repeat_count;

assign masked_sprites = &repeat_count;

reg n_ovr, ex_ovr;
reg [1:0] oam_secondary_column;

assign SS_OAMEVAL_BACK[ 7: 0] = oam_data;
assign SS_OAMEVAL_BACK[    8] = ~oam_secondary_ovr;
assign SS_OAMEVAL_BACK[14: 9] = oam_secondary_addr;
assign SS_OAMEVAL_BACK[17:15] = oam_secondary_row;
assign SS_OAMEVAL_BACK[21:18] = oam_secondary_row_ex;
assign SS_OAMEVAL_BACK[   22] = n_ovr;
assign SS_OAMEVAL_BACK[25:23] = spr_counter;
assign SS_OAMEVAL_BACK[28:26] = repeat_count;
assign SS_OAMEVAL_BACK[   29] = sprite0;
assign SS_OAMEVAL_BACK[   30] = sprite0_curr;
assign SS_OAMEVAL_BACK[   38] = overflow;
assign SS_OAMEVAL_BACK[40:39] = oam_secondary_column;
assign SS_OAMEVAL_BACK[   41] = ex_ovr;
assign SS_OAMEVAL_BACK[47:42] = oam_addr_ex;
assign SS_OAMEVAL_BACK[55:48] = oam_addr;
assign SS_OAMEVAL_BACK[58:56] = (oam_state == STATE_IDLE)  ? 3'd0 :
	(oam_state == STATE_CLEAR) ? 3'd1 :
	(oam_state == STATE_EVAL)  ? 3'd2 :
	(oam_state == STATE_FETCH) ? 3'd3 :
	3'd4;
assign SS_OAMEVAL_BACK[59] = old_rendering;
assign SS_OAMEVAL_BACK[60] = old_using_secondary;
assign SS_OAMEVAL_BACK[37:31] = '0; // free to be used
assign SS_OAMEVAL_BACK[63:61] = 3'b0; // free to be used

wire oam_wr_enabled = ~oam_secondary_ovr && ~is_pre_render;

always @(posedge clk) begin :oam_eval

reg [8:0] last_y, last_tile, last_attr; // unused?
reg [1:0] eval_count;
reg sec_ovr;

if (Savestate_OAMRdEn) Savestate_OAMReadData  <= oam[Savestate_OAMAddr];
if (Savestate_OAMWrEn) oam[Savestate_OAMAddr] <= Savestate_OAMWriteData;

if (reset) begin
	oam_temp <= '{64{8'hFF}};

	oam_data         <= SS_OAMEVAL[ 7: 0]; //oam_temp[0] == 8'hFF
	oam_secondary_ovr    <= ~SS_OAMEVAL[    8]; //1;
	oam_secondary_addr    <= SS_OAMEVAL[13: 9]; //0;
	oam_secondary_row    <= SS_OAMEVAL[17:15]; //0;
	oam_secondary_row_ex <= SS_OAMEVAL[21:18]; //0;
	n_ovr            <= SS_OAMEVAL[   22]; //0;
	spr_counter      <= SS_OAMEVAL[25:23]; //0;
	repeat_count     <= SS_OAMEVAL[28:26]; //0;
	sprite0          <= SS_OAMEVAL[   29]; //0;
	sprite0_curr     <= SS_OAMEVAL[   30]; //0;
	overflow         <= SS_OAMEVAL[   38]; //0;
	oam_secondary_column     <= SS_OAMEVAL[40:39]; //0;
	ex_ovr           <= SS_OAMEVAL[   41]; //0;
	oam_addr_ex      <= SS_OAMEVAL[47:42]; //0;
	oam_addr         <= SS_OAMEVAL[55:48]; //0;
	case (SS_OAMEVAL[58:56])
		0: oam_state <= STATE_IDLE;
		1: oam_state <= STATE_CLEAR;
		2: oam_state <= STATE_EVAL;
		3: oam_state <= STATE_FETCH;
		4: oam_state <= STATE_REFRESH;
	endcase
	old_rendering <= SS_OAMEVAL[59];
	old_using_secondary <= SS_OAMEVAL[60];
end else if (ce) begin

	// State machine. Remember these will be one ppu cycle early.
	case (cycle)
		340: oam_state <= STATE_CLEAR;   // 64 cycles
		63:  oam_state <= STATE_EVAL;    // 192 cycles
		255: oam_state <= STATE_FETCH;   // 64 cycles
		319: oam_state <= STATE_REFRESH; // 19 cycles
	endcase
	if (end_of_line)
		oam_state <= STATE_CLEAR;


	old_rendering <= rendering;
	old_using_secondary <= using_secondary;

	if (((old_rendering != rendering) || corrupting_write) && ~PAL) begin
		if ((old_using_secondary != using_secondary) || corrupting_write) begin
			oam[{oam_row_cur, 3'b000}] <= oam[{oam_row_last, 3'b000}];
			oam[{oam_row_cur, 3'b001}] <= oam[{oam_row_last, 3'b001}];
			oam[{oam_row_cur, 3'b010}] <= oam[{oam_row_last, 3'b010}];
			oam[{oam_row_cur, 3'b011}] <= oam[{oam_row_last, 3'b011}];
			oam[{oam_row_cur, 3'b100}] <= oam[{oam_row_last, 3'b100}];
			oam[{oam_row_cur, 3'b101}] <= oam[{oam_row_last, 3'b101}];
			oam[{oam_row_cur, 3'b110}] <= oam[{oam_row_last, 3'b110}];
			oam[{oam_row_cur, 3'b111}] <= oam[{oam_row_last, 3'b111}];
			oam_temp[oam_row_cur] <= oam_temp[oam_row_last];
		end
	end

	// XXX this is outside the "evaluating" block because of timing issues
	if (end_of_line) begin
		oam_secondary_row_ex <= 0;
		oam_addr_ex <= 0;
		ex_ovr <= 0;
		spr_counter <= 0;
		repeat_count <= 0;
		oam_bus_ex <= 32'hFFFFFFFF;
	end

	if (rendering) begin
		if (cycle < 64) begin               // Initialization state
			oam_data <= 8'hFF;
			n_ovr <= 0;

			if (secondary_write) begin
				if (oam_wr_enabled) begin // If this overflows due to rendering status corrupting the addr, oamdata will still be FF
					oam_temp[oam_secondary_addr] <= 8'hFF;

					// Clear extra sprite space too
					oam_temp[{1'b1, oam_secondary_addr}] <= 8'hFF;
				end

				{oam_secondary_ovr, oam_secondary_addr} <= {1'b0, oam_secondary_addr} + 6'd1;
			end

			// During init, we hunt for the 8th sprite in OAM, so we know where to start for extra sprites
			if (~&spr_counter) begin
				oam_addr_ex <= oam_addr_ex + 1'd1;
				if (scanline[7:0] >= oam[{oam_addr_ex, 2'b00}] && scanline[7:0] < oam[{oam_addr_ex, 2'b00}] + (obj_size ? 16 : 8))
					spr_counter <= spr_counter + 1'b1;
			end
		end else if (cycle < 256) begin             // Evaluation State
			if (evaluating || (visible && PAL)) begin
				// This phase has exactly enough cycles to evaluate all 64 sprites if 8 are on the current line,
				// so extra sprite evaluation has to be done seperately.
				if (&spr_counter && ~ex_ovr) begin
					{ex_ovr, oam_addr_ex} <= oam_addr_ex + 7'd1;
					if (scanline[7:0] >= oam[{oam_addr_ex, 2'b00}] &&
						scanline[7:0] < oam[{oam_addr_ex, 2'b00}] + (obj_size ? 16 : 8)) begin
						if (oam_secondary_row_ex < 8) begin // Turbo style.
							oam_secondary_row_ex <= oam_secondary_row_ex + 1'b1;
							oam_temp[{oam_secondary_row_ex, 2'b00} + 6'd32] <= oam[{oam_addr_ex, 2'b00}];
							oam_temp[{oam_secondary_row_ex, 2'b01} + 6'd32] <= oam[{oam_addr_ex, 2'b01}];
							oam_temp[{oam_secondary_row_ex, 2'b10} + 6'd32] <= oam[{oam_addr_ex, 2'b10}];
							oam_temp[{oam_secondary_row_ex, 2'b11} + 6'd32] <= oam[{oam_addr_ex, 2'b11}];
						end
					end
				end

				//On even cycles, data is read from (primary) OAM
				if (!secondary_write) begin
					oam_data <= is_pre_render ? oam_temp[oam_secondary_addr] : (oam[oam_read_addr] & (is_attr_byte ? 8'hE3 : 8'hFF));
				end else begin
					if (oam_wr_enabled && ~n_ovr) // The Attr byte of secondary OAM is NOT missing bits 4:2
						oam_temp[oam_secondary_addr] <= oam_dbus;
					else
						oam_data <= oam_temp[oam_secondary_addr];

					if (cycle == 65)
						sprite0_curr <= in_range && ~is_pre_render;

					if (eval_count == 2'd0) begin // Evaluate Y for in_range
						if (in_range && ~is_pre_render && ~n_ovr) begin
							eval_count <= 2'd1; // is good, start copy
							{n_ovr, oam_addr} <= {1'b0, oam_addr} + 9'd1;

							if (~oam_secondary_ovr) begin
								{oam_secondary_ovr, oam_secondary_addr} <= {1'b0, oam_secondary_addr} + 6'd1;
							end else begin
								overflow <= 1; // Overflow is set when Y is in range, oam_secondary_ovr is set, n_ovr is not set
							end

						end else begin
							if (~is_pre_render) begin
								if (oam_secondary_ovr & ~n_ovr) begin // Not in range but due to the secondary oam read, it buggily triggers a +1 increment too
									{n_ovr, oam_addr[7:2]} <= {1'b0, oam_addr[7:2]} + 6'd1;
									oam_addr[1:0] <= oam_addr[1:0] + 2'd1;
								end else begin // Normal and proper advance to the next Y position "slot"
									{n_ovr, oam_addr} <= ({1'b0, oam_addr} + 9'd4) & 9'h1FC;
								end
							end
						end
					end else if (eval_count == 2'd3) begin // end of copy
						// Due to a hardware bug, X is evaluated with the same logic as Y,
						// under normal circumstances regardless of if true or false, the outcome is the same
						// but if the oamaddress is misaligned, the oamaddress increments differently in practice.
						if (in_range && ~n_ovr) begin
							{n_ovr, oam_addr} <= {1'b0, oam_addr} + 9'd1;
						end else begin
							if (oam_secondary_ovr & ~n_ovr) begin // Same buggy increment as y if secondary oam is full
								{n_ovr, oam_addr} <= {1'b0, oam_addr} + 9'd5;
							end else begin
								{n_ovr, oam_addr} <= ({1'b0, oam_addr} + 9'd1) & 9'h1FC;
							end
						end

						// Some kludgy stuff for extra sprite evaluation
						if (~oam_secondary_ovr) begin
							last_y <= oam[{oam_addr[7:2], 2'b00}];
							last_tile <= oam[{oam_addr[7:2], 2'b01}];
							last_attr <= oam[{oam_addr[7:2], 2'b10}];
							// Check for repeats to see if the game is trying to mask sprites
							if (|oam_secondary_addr[4:2] &&
								last_y == oam[{oam_addr[7:2], 2'b00}] &&
								last_tile == oam[{oam_addr[7:2], 2'b01}] &&
								last_attr == oam[{oam_addr[7:2], 2'b10}]) begin
								repeat_count <= repeat_count + 3'd1;
							end
						end else begin
							// The reason this flag is set is because to get here, overflow must have been set and it sets this flag
							n_ovr <= 1;
						end
					end else begin
						{n_ovr, oam_addr} <= {1'b0, oam_addr} + 9'd1;
					end
				end
				// Check if the 9th sprite is a repeat
				if (last_y    == oam_temp[6'd32] &&
					last_tile == oam_temp[6'd33] &&
					last_attr == oam_temp[6'd34] &&
					cycle == 9'd255 && repeat_count < 7)
					repeat_count <= repeat_count + 3'd1;
			end

			if (n_ovr) n_ovr <= 1;// Prevent this from being cleared by oam primary rollover

		end else if (cycle < 320) begin
			oam_addr <= '0;
			sprite0 <= sprite0_curr;
			oam_data <= oam_temp[oam_secondary_addr];

			if ((cycle[2:0] < 4'd3 || cycle[2:0] == 3'd7) && ~oam_secondary_ovr)
				{oam_secondary_ovr, oam_secondary_addr} <= {1'b0, oam_secondary_addr} + 6'd1;

			if (cycle[2:0] == 3'd0) begin
				oam_bus_ex <= {
					oam_temp[{1'b1, oam_secondary_addr[4:2], 2'b11}],
					oam_temp[{1'b1, oam_secondary_addr[4:2], 2'b10}],
					oam_temp[{1'b1, oam_secondary_addr[4:2], 2'b01}],
					oam_temp[{1'b1, oam_secondary_addr[4:2], 2'b00}]
				};
			end
		end else begin // STATE_REFRESH
			oam_data <= oam_temp[0];
		end
	end else begin
		oam_data <= oam[oam_read_addr]; // Keep it available in case it's read
	end

	// Once started, this continues regardless of rendering status.
	if (|eval_count && secondary_write) begin // The evaluation counter and it's subsequent increment of the oam_secondary_address seems to increment even when not rendering
		eval_count <= eval_count + 2'd1;
		if (~oam_secondary_ovr) begin
			{oam_secondary_ovr, oam_secondary_addr} <= {1'b0, oam_secondary_addr} + 6'd1;
		end else begin
			overflow <= 1; // Overflow is set each tick of the eval SR
		end
	end

	if (clear_signal) begin
		overflow <= 0;
	end

	// Writes to OAMDATA during rendering (on the pre-render line and the visible lines 0-239,
	// provided either sprite or background rendering is enabled) do not modify values in OAM,
	// but do perform a glitchy increment of OAMADDR, bumping only the high 6 bits (i.e., it bumps
	// the [n] value in PPU sprite evaluation - it's plausible that it could bump the low bits instead
	// depending on the current status of sprite evaluation). This extends to DMA transfers via OAMDMA,
	// since that uses writes to $2004. For emulation purposes, it is probably best to completely ignore
	// writes during rendering.
	if (oam_data_write) begin
		if (~rendering) begin
			oam[oam_read_addr] <= (is_attr_byte) ? (oam_din & 8'hE3) : oam_din; // attr has no bits 2-4
			oam_data <= oam_din;
			oam_addr <= oam_addr + 1'b1;
		end else begin
			oam_addr <= {oam_addr[7:2] + 6'd1, 2'b00};
		end
	end

	if (oam_addr_write) begin
		oam_addr <= oam_din;
	end

	// Clearing takes precedence over setting
	if (clear_secondary_addr) begin
		oam_secondary_addr <= 0;
		oam_secondary_ovr <= 0;
	end

end
end // End Always

endmodule


// Generates addresses in VRAM where we'll fetch sprite graphics from,
// and populates load, load_in so the SpriteGen can be loaded.
// 10 LUT, 4 Slices
module SpriteAddressGen(
	input clk,
	input ce,
	input rendering,
	input enabled,          // If unset, |load| will be all zeros.
	input obj_size,         // 0: Sprite Height 8, 1: Sprite Height 16.
	input obj_patt,         // Object pattern table selection
	input in_range,         // If a y byte is in scanline range
	input [8:0] scanline,
	input [7:0] temp,       // Input temp data from SpriteTemp. #0 = Y Coord, #1 = Tile, #2 = Attribs, #3 = X Coord
	output [12:0] vram_addr,// Low bits of address in VRAM that we'd like to read.
	input [7:0] vram_data,  // Byte of VRAM in the specified address
	output [3:0] load,      // Which subset of load_in that is now valid, will be loaded into SpritesGen.
	output [26:0] load_in   // Bits to load into SpritesGen.
);
reg [2:0] count;
reg [7:0] temp_tile;    // Holds the tile that we will get
reg [3:0] temp_y;       // Holds the Y coord (will be swapped based on FlipY).
reg flip_x, flip_y;     // If incoming bitmap data needs to be flipped in the X or Y direction.
wire load_y =    (count == 0) && enabled;
wire load_tile = (count == 1) && enabled;
wire load_attr = (count == 2) && enabled;
wire load_x =    (count == 3) && enabled;
wire load_pix1 = (count == 5) && enabled;
wire load_pix2 = (count == 7) && enabled;
reg dummy_sprite; // Set if attrib indicates the sprite is invalid.

// Flip incoming vram data based on flipx. Zero out the sprite if it's invalid. The bits are already flipped once.
wire [7:0] vram_f =
	dummy_sprite ? 8'd0 :
	!flip_x ? {vram_data[0], vram_data[1], vram_data[2], vram_data[3], vram_data[4], vram_data[5], vram_data[6], vram_data[7]} :
	vram_data;

wire [3:0] y_f = temp_y ^ {flip_y, flip_y, flip_y, flip_y};
assign load = {load_pix1, load_pix2, load_x, load_attr};
assign load_in = {vram_f, vram_f, temp, temp[1:0], temp[5]};

// If $2000.5 = 0, the tile index data is used as usual, and $2000.3
// selects the pattern table to use. If $2000.5 = 1, the MSB of the range
// result value become the LSB of the indexed tile, and the LSB of the tile
// index value determines pattern table selection. The lower 3 bits of the
// range result value are always used as the fine vertical offset into the
// selected pattern.
assign vram_addr = {obj_size ? temp_tile[0] : obj_patt, temp_tile[7:1], obj_size ? y_f[3] : temp_tile[0], count[1], y_f[2:0]};
wire [7:0] scanline_y = scanline[7:0] - temp;
always @(posedge clk) if (ce) begin
	if (!enabled)
		count <= 3'd0;
	else
		count <= count + 3'd1;

	if (load_y) begin temp_y <= scanline_y[3:0]; dummy_sprite <= ~in_range; end
	if (load_tile) temp_tile <= temp;
	if (load_attr) {flip_y, flip_x} <= {temp[7:6]};
	end

endmodule  // SpriteAddressGen


// Condensed sprite address generator for extra sprites
module SpriteAddressGenEx(
	input clk,
	input ce,
	input rendering,
	input enabled,          // If unset, |load| will be all zeros.
	input obj_size,         // 0: Sprite Height 8, 1: Sprite Height 16.
	input obj_patt,         // Object pattern table selection
	input [7:0] scanline,
	input [31:0] temp,      // Input temp data from SpriteTemp. #0 = Y Coord, #1 = Tile, #2 = Attribs, #3 = X Coord
	input [7:0] vram_data,  // Byte of VRAM in the specified address
	output [12:0] vram_addr,// Low bits of address in VRAM that we'd like to read.
	output [3:0] load,      // Which subset of load_in that is now valid, will be loaded into SpritesGen.
	output [26:0] load_in,  // Bits to load into SpritesGen.
	output use_ex,          // If extra sprite address should be used
	input masked_sprites
);
reg [2:0] count;

// We keep an odd structure here to maintain compatibility with the existing sprite modules
// which are constrained by the behavior of the original system.
wire load_tile = (count == 1);
wire load_attr = (count == 2) && enabled;
wire load_x =    (count == 3) && enabled;
wire load_pix1 = (count == 5) && enabled;
wire load_pix2 = (count == 7) && enabled;

reg [7:0] pix1_latch, pix2_latch;

wire [7:0] temp_y = scanline[7:0] - temp[7:0];
wire [7:0] tile   = temp[15:8];
wire [7:0] attr   = temp[23:16];
wire [7:0] temp_x = temp[31:24];

wire flip_x = attr[6];
wire flip_y = attr[7];
wire dummy_sprite = attr[4];

assign use_ex = ~dummy_sprite && ~count[2] && ~masked_sprites;

// Flip incoming vram data based on flipx. Zero out the sprite if it's invalid. The bits are already flipped once.
wire [7:0] vram_f =
	(dummy_sprite || masked_sprites || ~rendering) ? 8'd0 :
	!flip_x ? {vram_data[0], vram_data[1], vram_data[2], vram_data[3], vram_data[4], vram_data[5], vram_data[6], vram_data[7]} :
	vram_data;

wire [3:0] y_f = temp_y[3:0] ^ {flip_y, flip_y, flip_y, flip_y};
assign load = {load_pix1, load_pix2, load_x, load_attr};
assign load_in = {pix1_latch, pix2_latch, load_temp, load_temp[1:0], load_temp[5]};

wire [7:0] load_temp;
always_comb begin
	case (count)
		0: load_temp = temp_y;
		1: load_temp = tile;
		2: load_temp = attr;
		3,4,5,6,7: load_temp = temp_x;
	endcase
end

// If $2000.5 = 0, the tile index data is used as usual, and $2000.3
// selects the pattern table to use. If $2000.5 = 1, the MSB of the range
// result value become the LSB of the indexed tile, and the LSB of the tile
// index value determines pattern table selection. The lower 3 bits of the
// range result value are always used as the fine vertical offset into the
// selected pattern.
assign vram_addr = {obj_size ? tile[0] : obj_patt, tile[7:1], obj_size ? y_f[3] : tile[0], count[1], y_f[2:0]};
always @(posedge clk) if (ce) begin
	if (!enabled)
		count <= 3'd0;
	else
		count <= count + 3'd1;
	if (load_tile) pix1_latch <= vram_f;
	if (load_x) pix2_latch <= vram_f;
end

endmodule  // SpriteAddressGen

module BgPainter(
	input clk,
	input pclk0,
	input clear,
	input enable,             // Shift registers activated
	input latch_nametable,
	input latch_attrtable,
	input latch_pattern1,
	input latch_pattern2,
	input [2:0] fine_x_scroll,
	input [14:0] vram_v,
	output [7:0] name_table,  // VRAM name table to read next.
	input [7:0] vram_data,
	output [3:0] pixel
);

reg [15:0] playfield_pipe_1;       // Name table pixel pipeline #1
reg [15:0] playfield_pipe_2;       // Name table pixel pipeline #2
reg [8:0]  playfield_pipe_3;       // Attribute table pixel pipe #1
reg [8:0]  playfield_pipe_4;       // Attribute table pixel pipe #2
reg [7:0] current_name_table;      // Holds the current name table byte
reg [1:0] current_attribute_table; // Holds the 2 current attribute table bits
reg [7:0] bg0;                     // Pixel data for last loaded background
wire [7:0] bg1 =  vram_data;

initial begin
	playfield_pipe_1 = 0;
	playfield_pipe_2 = 0;
	playfield_pipe_3 = 0;
	playfield_pipe_4 = 0;
	current_name_table = 0;
	current_attribute_table = 0;
	bg0 = 0;
end

always @(posedge clk) if (pclk0) begin
	if (latch_nametable)
		current_name_table <= vram_data;

	if (enable) begin
		if (latch_attrtable) begin
			current_attribute_table <=
				(!vram_v[1] && !vram_v[6]) ? vram_data[1:0] :
				( vram_v[1] && !vram_v[6]) ? vram_data[3:2] :
				(!vram_v[1] &&  vram_v[6]) ? vram_data[5:4] :
				vram_data[7:6];
		end

		if (latch_pattern1)
			bg0 <= vram_data; // Pattern table bitmap #0

		playfield_pipe_1[15:0] <= {1'b1, playfield_pipe_1[15:1]};
		playfield_pipe_2[15:0] <= {1'b0, playfield_pipe_2[15:1]};
		playfield_pipe_3[7:0] <= playfield_pipe_3[8:1];
		playfield_pipe_4[7:0] <= playfield_pipe_4[8:1];

		if (latch_pattern2) begin // This should be the cycle that horizontal v increment is seen
			playfield_pipe_1[15:8] <= {bg0[0], bg0[1], bg0[2], bg0[3], bg0[4], bg0[5], bg0[6], bg0[7]};
			playfield_pipe_2[15:8] <= {bg1[0], bg1[1], bg1[2], bg1[3], bg1[4], bg1[5], bg1[6], bg1[7]};
			playfield_pipe_3[8] <= current_attribute_table[0];
			playfield_pipe_4[8] <= current_attribute_table[1];
		end
	end

	if (clear) begin
		playfield_pipe_1 <= 0;
		playfield_pipe_2 <= 0;
		playfield_pipe_3 <= 0;
		playfield_pipe_4 <= 0;
		current_name_table <= 0;
		current_attribute_table <= 0;
		bg0 <= 0;
	end

end

assign name_table = current_name_table;

wire [3:0] i = {1'b0, fine_x_scroll};

assign pixel = {playfield_pipe_4[i], playfield_pipe_3[i], playfield_pipe_2[i], playfield_pipe_1[i]};

endmodule  // BgPainter


module PixelMuxer(
	input  logic [3:0] bg,
	input  logic [3:0] obj,
	input  logic       obj_prio,
	output logic [4:0] out,
	output logic       is_obj
);

wire bg_valid = |bg[1:0];
wire obj_valid = |obj[1:0];

assign is_obj = obj_valid && ~(obj_prio && bg_valid);
assign out = (bg_valid | obj_valid) ? (is_obj ? {1'b1, obj} : {1'b0, bg}) : 5'd0;

endmodule


module PaletteRam
(
	input clk,
	input ce,
	input [4:0] addr,
	input [5:0] din,
	output [5:0] dout,
	input write,
	input [1:0] extra_bits,
	input reset,
	input rendering,
	input c_corrupt,
	input [4:0] raw_addr,
	input in_range,
	// savestates
	input [63:0]  SaveStateBus_Din,
	input [ 9:0]  SaveStateBus_Adr,
	input         SaveStateBus_wren,
	input         SaveStateBus_rst,
	output [63:0] SaveStateBus_Dout
);

// savestates
localparam SAVESTATE_MODULES    = 4;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
assign SaveStateBus_Dout  = SaveStateBus_wired_or[ 0] | SaveStateBus_wired_or[ 1] | SaveStateBus_wired_or[ 2] | SaveStateBus_wired_or[ 3];

wire [63:0] SS_PAL [3:0];
wire [63:0] SS_PAL_BACK [3:0];
eReg_SavestateV #(SSREG_INDEX_PAL0, SSREG_DEFAULT_PAL0) iREG_SAVESTATE_PAL0 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_PAL_BACK[0], SS_PAL[0]);
eReg_SavestateV #(SSREG_INDEX_PAL1, SSREG_DEFAULT_PAL1) iREG_SAVESTATE_PAL1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_PAL_BACK[1], SS_PAL[1]);
eReg_SavestateV #(SSREG_INDEX_PAL2, SSREG_DEFAULT_PAL2) iREG_SAVESTATE_PAL2 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[2], SS_PAL_BACK[2], SS_PAL[2]);
eReg_SavestateV #(SSREG_INDEX_PAL3, SSREG_DEFAULT_PAL3) iREG_SAVESTATE_PAL3 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[3], SS_PAL_BACK[3], SS_PAL[3]);

reg [5:0] palette [32];
// = '{
//	6'h00, 6'h01, 6'h00, 6'h01,
//	6'h00, 6'h02, 6'h02, 6'h0D,
//	6'h08, 6'h10, 6'h08, 6'h24,
//	6'h00, 6'h00, 6'h04, 6'h2C,
//	6'h09, 6'h01, 6'h34, 6'h03,
//	6'h00, 6'h04, 6'h00, 6'h14,
//	6'h08, 6'h3A, 6'h00, 6'h02,
//	6'h00, 6'h20, 6'h2C, 6'h08
//};

// If 0x0,4,8,C: mirror every 0x10
wire corrupting = old_rendering && ~rendering && c_corrupt && in_range;
wire [4:0] addr2 = (addr[1:0] == 0) ? {1'b0, addr[3:0]} : addr;
wire [4:0] addr3 = corrupting ? {addr2[4], raw_addr[3:2], addr2[1:0]} : addr2;

assign dout = palette[addr3];

assign SS_PAL_BACK[0][ 5: 0] = palette[ 0]; assign SS_PAL_BACK[1][ 5: 0] = palette[1 ]; assign SS_PAL_BACK[2][ 5: 0] = palette[2 ]; assign SS_PAL_BACK[3][ 5: 0] = palette[3 ];
assign SS_PAL_BACK[0][13: 8] = palette[ 4]; assign SS_PAL_BACK[1][13: 8] = palette[5 ]; assign SS_PAL_BACK[2][13: 8] = palette[6 ]; assign SS_PAL_BACK[3][13: 8] = palette[7 ];
assign SS_PAL_BACK[0][21:16] = palette[ 8]; assign SS_PAL_BACK[1][21:16] = palette[9 ]; assign SS_PAL_BACK[2][21:16] = palette[10]; assign SS_PAL_BACK[3][21:16] = palette[11];
assign SS_PAL_BACK[0][29:24] = palette[12]; assign SS_PAL_BACK[1][29:24] = palette[13]; assign SS_PAL_BACK[2][29:24] = palette[14]; assign SS_PAL_BACK[3][29:24] = palette[15];
assign SS_PAL_BACK[0][37:32] = palette[16]; assign SS_PAL_BACK[1][37:32] = palette[17]; assign SS_PAL_BACK[2][37:32] = palette[18]; assign SS_PAL_BACK[3][37:32] = palette[19];
assign SS_PAL_BACK[0][45:40] = palette[20]; assign SS_PAL_BACK[1][45:40] = palette[21]; assign SS_PAL_BACK[2][45:40] = palette[22]; assign SS_PAL_BACK[3][45:40] = palette[23];
assign SS_PAL_BACK[0][53:48] = palette[24]; assign SS_PAL_BACK[1][53:48] = palette[25]; assign SS_PAL_BACK[2][53:48] = palette[26]; assign SS_PAL_BACK[3][53:48] = palette[27];
assign SS_PAL_BACK[0][61:56] = palette[28]; assign SS_PAL_BACK[1][61:56] = palette[29]; assign SS_PAL_BACK[2][61:56] = palette[30]; assign SS_PAL_BACK[3][61:56] = palette[31];

reg old_rendering;

always @(posedge clk) if (reset) begin
	palette[ 0] <= SS_PAL[0][ 5: 0]; palette[1 ] <= SS_PAL[1][ 5: 0]; palette[2 ] <= SS_PAL[2][ 5: 0]; palette[3 ] <= SS_PAL[3][ 5: 0];
	palette[ 4] <= SS_PAL[0][13: 8]; palette[5 ] <= SS_PAL[1][13: 8]; palette[6 ] <= SS_PAL[2][13: 8]; palette[7 ] <= SS_PAL[3][13: 8];
	palette[ 8] <= SS_PAL[0][21:16]; palette[9 ] <= SS_PAL[1][21:16]; palette[10] <= SS_PAL[2][21:16]; palette[11] <= SS_PAL[3][21:16];
	palette[12] <= SS_PAL[0][29:24]; palette[13] <= SS_PAL[1][29:24]; palette[14] <= SS_PAL[2][29:24]; palette[15] <= SS_PAL[3][29:24];
	palette[16] <= SS_PAL[0][37:32]; palette[17] <= SS_PAL[1][37:32]; palette[18] <= SS_PAL[2][37:32]; palette[19] <= SS_PAL[3][37:32];
	palette[20] <= SS_PAL[0][45:40]; palette[21] <= SS_PAL[1][45:40]; palette[22] <= SS_PAL[2][45:40]; palette[23] <= SS_PAL[3][45:40];
	palette[24] <= SS_PAL[0][53:48]; palette[25] <= SS_PAL[1][53:48]; palette[26] <= SS_PAL[2][53:48]; palette[27] <= SS_PAL[3][53:48];
	palette[28] <= SS_PAL[0][61:56]; palette[29] <= SS_PAL[1][61:56]; palette[30] <= SS_PAL[2][61:56]; palette[31] <= SS_PAL[3][61:56];
end else if (ce) begin
	if (write) begin
		palette[addr2] <= din;
	end

	old_rendering <= rendering;

	if (corrupting) begin
		palette[{addr2[4], raw_addr[3:0]}] <= palette[{addr2[4], raw_addr[3:2], addr2[1:0]}];
	end
end

endmodule  // PaletteRam

module debug_dots(
	input enable,
	input [5:0] color,
	input custom1,
	input custom2,
	input w2000,
	input w2001,
	input r2002,
	input w2003,
	input r2004,
	input w2004,
	input w2005,
	input w2006,
	input r2007,
	input w2007,
	output [5:0] new_color
);

always_comb begin
	new_color = color;
	if (enable) begin
		if (custom1)
			new_color = 6'h31;
		else if (custom2)
			new_color = 6'h34;
		else if (w2000)
			new_color = 6'h16;
		else if (w2001)
			new_color = 6'h03;
		else if (r2002)
			new_color = 6'h17;
		else if (w2003)
			new_color = 6'h15;
		else if (r2004)
			new_color = 6'h09;
		else if (w2004)
			new_color = 6'h28;
		else if (w2005)
			new_color = 6'h1A;
		else if (w2006)
			new_color = 6'h12;
		else if (r2007)
			new_color = 6'h21;
		else if (w2007)
			new_color = 6'h06;
	end
end

endmodule


module PPU(
	input         clk,
	input         cs,
	input         RWn,
	input         rst_behavior,
	input         ce,
	input         debug_dots,
	input         reset,            // input clock  21.48 MHz / 4. 1 clock cycle = 1 pixel
	input         cold_reset,       // power cycle
	inout   [1:0] sys_type,         // System type. 0 = NTSC 1 = PAL 2 = Dendy 3 = Vs.
	output  [5:0] color,            // output color value, one pixel outputted every clock
	input   [7:0] din,              // input data from bus
	output  [7:0] dout,             // output data to CPU
	input   [2:0] ain,              // input address from CPU
	input         read,             // read
	input         write,            // write
	output reg    nmi,              // one while inside vblank
	output        vram_r,           // read from vram active
	output        vram_r_ex,        // use extra sprite address
	output        vram_w,           // write to vram active
	output [13:0] vram_addr,        // vram address
	output [13:0] vram_a_ex,        // vram address for extra sprites
	input   [7:0] vram_dbus_in,     // vram input
	output  [7:0] vram_dout,
	output  [8:0] scanline,
	output  [8:0] cycle,
	output  [2:0] emphasis,
	output        hsync,
	output        vsync,
	output        hblank,
	output        vblank,
	output        short_frame,
	input         extra_sprites,
	input  [1:0]  mask,
	output        render_ena_out,
	output        evenframe,
	// savestates
	input [63:0]  SaveStateBus_Din,
	input [ 9:0]  SaveStateBus_Adr,
	input         SaveStateBus_wren,
	input         SaveStateBus_rst,
	input         SaveStateBus_load,
	output [63:0] SaveStateBus_Dout,

	input  [7:0]  Savestate_OAMAddr,
	input         Savestate_OAMRdEn,
	input         Savestate_OAMWrEn,
	input  [7:0]  Savestate_OAMWriteData,
	output [7:0]  Savestate_OAMReadData
);

// Savestates
localparam SAVESTATE_MODULES    = 6;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
assign SaveStateBus_Dout = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1] | SaveStateBus_wired_or[2] | SaveStateBus_wired_or[3] | SaveStateBus_wired_or[4] | SaveStateBus_wired_or[5];

wire [63:0] SS_PPU;
wire [63:0] SS_PPU_BACK;
wire [63:0] SS_PPU_DECAY;
wire [63:0] SS_PPU_DECAY_BACK;
eReg_SavestateV #(SSREG_INDEX_PPU_1, SSREG_DEFAULT_PPU_1) iREG_SAVESTATE_PPU       (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_PPU_BACK,       SS_PPU);
eReg_SavestateV #(SSREG_INDEX_PPU_2, SSREG_DEFAULT_PPU_2) iREG_SAVESTATE_PPU_DECAY (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_PPU_DECAY_BACK, SS_PPU_DECAY);

// wire cs_w = !RWn && cs;
// wire cs_r = RWn && cs;

// wire w2000 = cs_w && (ain == 3'd0);
// wire w2001 = cs_w && (ain == 3'd1);
// wire r2002 = cs_r && (ain == 3'd2);
// wire r2003 = cs_r && (ain == 3'd3);
// wire r2004 = cs_r && (ain == 3'd4);
// wire w2004 = cs_w && (ain == 3'd4);
// wire w2005 = cs_w && (ain == 3'd5);
// wire w2006 = cs_w && (ain == 3'd6);
// wire r2007 = cs_r && (ain == 3'd7);
// wire w2007 = cs_w && (ain == 3'd7);

// These are stored in control register 0
reg obj_patt, obj_patt1; // Object pattern table
reg bg_patt, bg_patt1;  // Background pattern table
reg obj_size, obj_size1; // 1 if sprites are 16 pixels high, else 0.
reg vbl_enable;  // Enable VBL flag
reg clear; // Enable write after first vblank

// These are stored in control register 1
reg grayscale; // Disable color burst
reg playfield_clip;     // 0: Left side 8 pixels playfield clipping
reg object_clip;        // 0: Left side 8 pixels object clipping

wire in_range;

initial begin
	obj_patt = 0;
	bg_patt = 0;
	obj_size = 0;
	vbl_enable = 0;
	grayscale = 0;
	playfield_clip = 0;
	object_clip = 0;
	enable_playfield = 0;
	enable_objects = 0;
	emph_reg = 0;
	clear = 0;
end

reg nmi_occured;         // True if NMI has occured but not cleared.
reg [7:0] vram_latch;

// Clock generator
wire is_in_vblank;        // True if we're in VBLANK
wire end_of_line;         // At the last pixel of a line
wire at_last_cycle_group; // At the very last cycle group of the scan line.
wire exiting_vblank;      // At the very last cycle of the vblank
wire entering_vblank;     //
wire is_pre_render_line;  // True while we're on the pre render scanline

reg enable_playfield, enable_objects;

// Rendering_enabled is mostly part of the timing signals, which then get propagated. we know that
// the spr/bg enabled registers don't apply til the write ends, and then all timing signals but one
// then have to go through a pclk1, so that's 1-2 cycles to apply, then +1 (or more) for everything
// except skip_dot calculation.
reg [2:0] re_sr, eo_sr, eb_sr; // rendering enable shift register
wire rendering_enabled = re_sr[1];
wire rendering_regs = enable_objects | enable_playfield;
assign render_ena_out = rendering_regs;

// 2C02 has an "is_vblank" flag that is true from pixel 0 of line 241 to pixel 0 of line 0;
wire is_rendering = rendering_enabled && (scanline < 240 || is_pre_render_line);
wire is_rendering_d = re_sr[2] && (scanline < 240 || (is_pre_render_line && cycle != 0) || (scanline == 241 && cycle == 0));
wire is_vbe_sl;

wire clear_signal = is_pre_render_line;

wire [13:0] vram_a;
reg [7:0] vram_a_byte;

ClockGen clock(
	.clk                 (clk),
	.ce                  (ce),
	.reset               (reset),
	.sys_type            (sys_type),
	.is_rendering        (rendering_regs),
	.scanline            (scanline),
	.cycle               (cycle),
	.is_in_vblank        (is_in_vblank),
	.end_of_line         (end_of_line),
	.at_last_cycle_group (at_last_cycle_group),
	.exiting_vblank      (exiting_vblank),
	.entering_vblank     (entering_vblank),
	.is_pre_render       (is_pre_render_line),
	.short_frame         (short_frame),
	.is_vbe_sl           (is_vbe_sl),
	.evenframe           (evenframe),
	.hsync               (hsync),
	.vsync               (vsync),
	.hblank              (hblank),
	.vblank              (vblank),
	// savestates
	.SaveStateBus_Din  (SaveStateBus_Din ),
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[2])
);
defparam clock.USE_SAVESTATE = 1;

// The vram module handles updating of the vram address
wire [14:0] vram;
wire [2:0] fine_x_scroll;

VramAddressGen vram0(
	.clk           (clk),
	.ce            (ce),
	.reset         (reset),
	.clear         (clear),
	.is_rendering  (is_rendering),
	.ain           (ain),
	.din           (ppu_dbus),
	.read          (read),
	.write         (write),
	.is_pre_render (is_pre_render_line),
	.trigger_2007  (vram_w_ppudata_d || vram_r_ppudata_d),
	.cycle         (cycle),
	.vram          (vram),
	.fine_x_scroll (fine_x_scroll),
	 // savestates
	.SaveStateBus_Din  (SaveStateBus_Din ),
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[3])
);

// Set to true if the current ppu_addr pointer points into palette ram.
wire is_pal_address = (vram[13:8] == 6'b111111);

// Paints background
wire [7:0] bg_name_table;
wire [3:0] bg_pixel_noblank;

wire in_visible_frame = (scanline < 240 || is_pre_render_line) && cycle > 0 && cycle < 257;
wire out_of_clip = cycle > 8'd8;

// Cycle 0 is excluded because the H_LT_256R signal is delayed by a pixel, so 0 is missed.
wire bgp_en = ((in_visible_frame || (cycle >= 321 && cycle <= 336))) && rendering_enabled;

BgPainter bg_painter(
	.clk            (clk),
	.pclk0          (ce),
	.clear          (reset),
	.latch_nametable(cycle[2:0] == 2 && rendering_enabled),
	.latch_attrtable(cycle[2:0] == 4),
	.latch_pattern1 (cycle[2:0] == 6),
	.latch_pattern2 (cycle[2:0] == 0),
	.enable         (bgp_en),
	.fine_x_scroll  (fine_x_scroll),
	.vram_v         (vram),
	.name_table     (bg_name_table),
	.vram_data      (vram_din),
	.pixel          (bg_pixel_noblank)
);

// Blank out BG in the leftmost 8 pixels
wire show_bg_on_pixel = (playfield_clip || out_of_clip) && eb_sr[1];
wire [3:0] bg_pixel = {bg_pixel_noblank[3:2], show_bg_on_pixel ? bg_pixel_noblank[1:0] : 2'b00};

wire [31:0] oam_bus_ex;
wire masked_sprites;

wire [8:0] scanline_nopr = is_pre_render_line ? (~|sys_type ? 9'd261 : 9'd311) : scanline;

OAMEval spriteeval (
	.clk               (clk),
	.ce                (ce),
	.reset             (reset),
	.end_of_line       (end_of_line),
	.rendering_enabled (rendering_enabled),
	.obj_size          (obj_size1),
	.scanline          (scanline_nopr),
	.cycle             (cycle),
	.clear_signal      (clear_signal),
	.oam_bus           (oam_bus),
	.oam_bus_ex        (oam_bus_ex),
	.oam_addr_write    (write && (ain == 3)),
	.oam_data_write    (write && (ain == 4)),
	.oam_din           (ppu_dbus),
	.in_range          (in_range),
	.overflow          (sprite_overflow),
	.sprite0           (obj0_on_line),
	.is_vbe            (is_vbe_sl),
	.is_pre_render     (is_pre_render_line),
	.PAL               (sys_type[0]),
	.masked_sprites    (masked_sprites),
	 // savestates
	.SaveStateBus_Din       (SaveStateBus_Din        ),
	.SaveStateBus_Adr       (SaveStateBus_Adr        ),
	.SaveStateBus_wren      (SaveStateBus_wren       ),
	.SaveStateBus_rst       (SaveStateBus_rst        ),
	.SaveStateBus_Dout      (SaveStateBus_wired_or[4]),
	.Savestate_OAMAddr      (Savestate_OAMAddr       ),
	.Savestate_OAMRdEn      (Savestate_OAMRdEn       ),
	.Savestate_OAMWrEn      (Savestate_OAMWrEn       ),
	.Savestate_OAMWriteData (Savestate_OAMWriteData  ),
	.Savestate_OAMReadData  (Savestate_OAMReadData   )
);


wire [7:0] oam_bus;
wire sprite_overflow;
wire obj0_on_line; // True if sprite#0 is included on the current line

wire [4:0] obj_pixel_noblank;
wire [12:0] sprite_vram_addr;
wire is_obj0_pixel;            // True if obj_pixel originates from sprite0.
wire [3:0] spriteset_load;     // Which subset of the |load_in| to load into SpriteSet
wire [26:0] spriteset_load_in; // Bits to load into SpriteSet
reg [2:0] emph_reg;

// Between 257..320 (64 cycles), fetches bitmap data for the 8 sprites and fills in the SpriteSet
// so that it can start drawing on the next frame.
wire sprite_load_en = (cycle >= 257 && cycle < 321);
SpriteAddressGen address_gen(
	.clk       (clk),
	.ce        (ce),
	.rendering (rendering_enabled),
	.in_range  (in_range & rendering_enabled),
	.enabled   (sprite_load_en),  // Load sprites between 257..320
	.obj_size  (obj_size1),
	.scanline  (scanline_nopr),
	.obj_patt  (obj_patt1),               // Object size and pattern table
	.temp      (~is_rendering ? 8'hFF : oam_bus),                // Info from temp buffer.
	.vram_addr (sprite_vram_addr),       // [out] VRAM Address that we want data from
	.vram_data (vram_din),               // [in] Data at the specified address
	.load      (spriteset_load),
	.load_in   (spriteset_load_in)       // Which parts of SpriteGen to load
);

wire [12:0] sprite_vram_addr_ex;
wire [3:0] spriteset_load_ex;
wire [26:0] spriteset_load_in_ex;
wire use_ex;

SpriteAddressGenEx address_gen_ex(
	.clk            (clk),
	.ce             (ce),
	.rendering      (rendering_enabled),
	.enabled        (sprite_load_en),  // Load sprites between 256..319
	.obj_size       (obj_size1),
	.scanline       (scanline_nopr[7:0]),
	.obj_patt       (obj_patt1),               // Object size and pattern table
	.temp           (~is_rendering ? 32'hFFFFFFFF : oam_bus_ex),                // Info from temp buffer.
	.vram_addr      (sprite_vram_addr_ex),    // [out] VRAM Address that we want data from
	.vram_data      (vram_din),               // [in] Data at the specified address
	.load           (spriteset_load_ex),
	.load_in        (spriteset_load_in_ex),    // Which parts of SpriteGen to load
	.use_ex         (use_ex),
	.masked_sprites (masked_sprites)
);

reg [3:0] sprite_sr;

// Between 1..256 (256 cycles), draws pixels.
// Between 257..320 (64 cycles), will be populated for next line
SpriteSet sprite_gen(
	.clk           (clk),
	.ce            (ce),
	.enable        (in_visible_frame), // Enable between 1..256 if rendering enabled
	.counting      (sprite_sr[2]),
	.rendering     (rendering_enabled),
	.load          (spriteset_load),
	.load_in       (spriteset_load_in),
	.load_ex       (spriteset_load_ex),
	.load_in_ex    (spriteset_load_in_ex),
	.bits          (obj_pixel_noblank),
	.is_sprite0    (is_obj0_pixel),
	.extra_sprites (extra_sprites)
);

// Blank out obj in the leftmost 8 pixels?
wire show_obj_on_pixel = (object_clip || out_of_clip) && eo_sr[1];
wire [4:0] obj_pixel = {obj_pixel_noblank[4:2], show_obj_on_pixel ? obj_pixel_noblank[1:0] : 2'b00};

reg sprite0_hit_bg;            // True if sprite#0 has collided with the BG in the last frame.

assign SS_PPU_BACK[0] = sprite0_hit_bg;

wire spr0_hit = is_rendering        &&    // Object rendering is enabled
			in_visible_frame    &&    // X Pixel 0..255
			cycle[8:0] != 256   &&    // X pixel != 255
			!is_pre_render_line &&    // Y Pixel 0..239
			obj0_on_line        &&    // True if sprite#0 is included on the scan line.
			is_obj0_pixel       &&    // True if the pixel came from tempram #0.
			show_obj_on_pixel   &&
			bg_pixel[1:0] != 0        // Background pixel nonzero
			;

always @(posedge clk) begin
	if (SaveStateBus_load) begin
		sprite0_hit_bg <= SS_PPU[0];
	end else if (ce) begin
		if (!sprite_sr[2])
			sprite_sr <= {sprite_sr[2:0], 1'b0};
		if (cycle == 339 && in_rendering_frame)
			sprite_sr <= {3'b000, rendering_regs};
		if (cycle == 256)
			sprite_sr <= {4'b0000};
		if (clear_signal) begin
			sprite0_hit_bg <= 0;
		end else if (spr0_hit) begin
			sprite0_hit_bg <= 1;
		end
	end
end

wire [4:0] pixel;
wire pixel_is_obj;

PixelMuxer pixel_muxer(
	.bg       (bg_pixel),
	.obj      (obj_pixel[3:0]),
	.obj_prio (obj_pixel[4]),
	.out      (pixel),
	.is_obj   (pixel_is_obj)
);

// VRAM Address Assignment

assign vram_a_ex = {1'b0, sprite_vram_addr_ex};

// Vram Address timing:
// cycle 0 *special behavior
// Cycle 1-260 and 321 to 340 the background is fetched
// ON Cycle[2:0] == 1 and 2, Nametable fetch
// ON Cycle[2:0] == 3 and 4, Attribute Fetch
// ON Cycle[2:0] == 5 and 6, Background LSBs
// On Cycle[2:0] == 7 and 0, Background MSBs.
// The reads take two cycles and should begin on the odd cycles setting the address and get the data on the even cycles.

// Between cycles 261 through 320, the sprites are fetched
// ON Cycle[2:0] == 1 and 2, Sprite LSB's
// ON Cycle[2:0] == 3 and 4, Sprite MSB's
// ON Cycle[2:0] == 5 and 6, Dummy Nametable
// On Cycle[2:0] == 7 and 0, Dummy Attributes

// It is important to note that on FPGA's, what happens ON a clock enable is the cycle-1 of when the
// result of the action is observed. So if you do something on (cycle == 0 && ce) that means the action
// is observed on what documentation would call cycle == 1, because cycle increments on CE as well.
// However, combinational logic is instant, not delayed.

// The actual logic for reading vram stuff is as follows, with latching following by one ppu cycle.
// For context, t2 means the signal delayed by 2 half-ppu-cycles (one full ppu cycle).
// wire load_nametable = ~(is_rendering && (((t2[H_LT_256R] || t2[H_EQ_320_TO_335R]) && t2[H_MOD8_2_OR_3R]) || hpos[2][2]));
// wire load_attrtable = t2[H_MOD8_2_OR_3R] && (t2[H_LT_256R] || t2[H_EQ_320_TO_335R]);
// wire load_pattern1 = t2[H_MOD8_4_OR_5R];
// wire load_pattern2 = t2[H_MOD8_6_OR_7R];
// wire load_sprites = t3[H_EQ_256_TO_319R];
// wire load_sprnt = is_rendering && hpos[2][2];

wire special_dot = ~evenframe && cycle == 0 && scanline == 0; // This dot is skipped on even frames

wire nametable_read = cycle[2:0] == 1 || cycle[2:0] == 2 || (sprite_load_en && (cycle[2:0] == 3 || cycle[2:0] == 4)) || cycle > 336 || special_dot;
wire attribute_read = (cycle[2:0] == 3 || cycle[2:0] == 4) && ~nametable_read;
wire pattern_table_upper = cycle[1:0] == 3 || cycle[1:0] == 0;
wire read_cycle = ~cycle[0];

always_comb begin
	if (~is_rendering_d) begin
		vram_a = vram[13:0];
		vram_r_ex = 0;
	end else begin
		// Extra sprite fetch override flag
		if (sprite_load_en) // Fetch Extra sprites during dummy reads of sprite loadout
			vram_r_ex = use_ex && extra_sprites;
		else
			vram_r_ex = 0;

		if (nametable_read)
			vram_a = {2'b10, vram[11:0]};                                 // Name Table
		else if (attribute_read)
			vram_a = {2'b10, vram[11:10], 4'b1111, vram[9:7], vram[4:2]}; // Attribute table
		else if (sprite_load_en)
			vram_a = {1'b0, sprite_vram_addr};                            // Sprite pattern table during sprite loadout
		else
			vram_a = {1'b0, bg_patt1, bg_name_table, pattern_table_upper, vram[14:12]}; // Background pattern table otherwise
	end
end

// Read from VRAM, either when user requested a manual read, or when we're generating pixels.
wire vram_r_ppudata = read_2007_delayed[2];
wire vram_r_ppudata_d = read_2007_delayed[3];
wire vram_w_ppudata = write_2007_delayed[2];
wire vram_w_ppudata_d = write_2007_delayed[3];

wire ALE = (is_rendering_d && ~read_cycle) | (read_2007_delayed[1] || write_2007_delayed[1]);

wire [7:0] vram_din = vram_r ? vram_dbus_in : (vram_w ? vram_dout : (ALE ? vram_a[7:0] : vram_dbus_in));

// The true and proper logic is that it will read if rendering is enabled and the previous cycle was odd.
// this is important when you go from 340->0 or 339->0.
assign vram_r = vram_r_ppudata | (is_rendering_d && read_cycle && (cycle != 0 || special_dot));
assign vram_w = ~vram_r && vram_w_ppudata && !is_pal_address; // R&W at the same time should yield to read most of the time

// Value currently being written to video ram
assign vram_dout = ALE ? vram_a[7:0] : ppu_dbus;

// One cycle after vram_r was asserted, the value
// is available on the bus.
reg vram_read_delayed;

assign SS_PPU_BACK[21:14] = vram_latch;
assign SS_PPU_BACK[   22] = vram_read_delayed;
assign SS_PPU_BACK[57:50] = vram_a_byte;

// For any future person who wants to understand what is going on here: the NES PPU multiplexes the
// bottom 8 bits of the address with its ppu vram data bus. This means the data bits alternate between
// vram_addr[7:0] and vram_dout. There is an external latch controlled by the ALE pin which assembles
// the vram_addr into its full form. We do the latching in the PPU here instead for the sake of
// cleanliness, but if you ever wanted to add real hardware compatible pins, you'd change this here.
assign vram_addr = {vram_a[13:8], ALE ? vram_latch_value : vram_a_byte};

wire [7:0] vram_latch_value = /*vram_r ? vram_din :*/ vram_a[7:0]; // This breaks stuff if uncommented.

always @(posedge clk) begin
	if (SaveStateBus_load) begin
		vram_latch        <= SS_PPU[21:14];
		vram_read_delayed <= SS_PPU[   22];
		vram_a_byte       <= SS_PPU[57:50];
	end else if (ce) begin
		// If it so happens that ALE and vram_r are both asserted at the same time due to a poorly
		// timed 2007 read, the ppu data bus will not be driven by the PPU and instead driven
		// by the vram itself, so the external latch latches the data byte rather than the lower
		// 8 bits of the address.
		if (ALE) // Simulate the external latch
			vram_a_byte <= vram_latch_value;
		if (vram_read_delayed)
			vram_latch <= vram_din;
		vram_read_delayed <= vram_r_ppudata;
	end
end

reg [5:0] color_pipe[4];
wire [5:0] color2;
wire pal_writes_valid = is_pal_address && ~is_rendering;
// On a real system if master_mode is set the ext pins would also be used for palette address, but
// we dont have those here.
wire [4:0] pram_addr = is_rendering && in_visible_frame ? pixel : (pal_writes_valid ? vram[4:0] : 5'b00000);

wire in_rendering_frame = scanline < 240 || is_pre_render_line;

PaletteRam palette_ram(
	.clk          (clk),
	.reset        (reset),
	.ce           (ce),
	.addr         (pram_addr), // Read addr
	.din          (ppu_dbus[5:0]),  // Value to write
	.dout         (color2),    // Output color
	.write        (vram_w_ppudata && pal_writes_valid), // Condition for writing
	// Palette corruption signals
	.rendering    (rendering_enabled),
	.c_corrupt    (attribute_read ? (&{vram[13:12], vram_a[11:8]}) : &vram[13:8]), // Corrupt palette writes
	.raw_addr     (vram[4:0]),
	.in_range     (in_rendering_frame),
	// savestates
	.SaveStateBus_Din  (SaveStateBus_Din ),
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[5])
);

reg [4:0] write_2007_delayed;
reg [4:0] read_2007_delayed;

wire write_2001 = (write && ain == 1);
wire pal_mask = ~|scanline || cycle < 3 || cycle > 254;
wire auto_mask = (mask == 2'b11) && ~object_clip && ~playfield_clip;
wire mask_left = ~out_of_clip && ((|mask && ~&mask) || auto_mask);
wire mask_right = cycle > 248 && mask == 2'b10;

// PAL/Dendy masks scanline 0 and 2 pixels on each side with black.
wire mask_pal = (|sys_type && pal_mask);
wire in_draw_range = ~(cycle >= 271 && cycle <= 328) && ~vblank;
wire grayscale_bit = write_2001 ? ppu_dbus[0] : grayscale;
wire not_grayscale = ((in_draw_range || (vram_r_ppudata && is_pal_address))) && ~grayscale_bit;

debug_dots debug_d(
	.enable     (debug_dots),
	.color      (color0),
	.custom1    (0),
	.custom2    (spr0_hit),
	.w2000      (write && ain == 0),
	.w2001      (write && ain == 1),
	.r2002      (read && ain == 2),
	.w2003      (write && ain == 3),
	.r2004      (read && ain == 4),
	.w2004      (write && ain == 4),
	.w2005      (write && ain == 5),
	.w2006      (write && ain == 6),
	.r2007      (read && ain == 7),
	.w2007      (write && ain == 7),
	.new_color  (color)
);

wire [5:0] color0 = (not_grayscale ? color_pipe[0] : {color_pipe[0][5:4], 4'b0});
wire [5:0] color1 = (mask_right | mask_left | mask_pal) ? 6'h0E : color2;

wire clear_nmi = (clear_signal | (read && ain == 2));
wire set_nmi = entering_vblank & ~clear_nmi;

wire [7:0] ppu_dbus =
	write ? din :
	read ? (
		(ain == 2) ? {nmi_occured, (spr0_hit || sprite0_hit_bg) & ~clear_signal, sprite_overflow & ~clear_signal, latched_dout[4:0]} : // PPUSTATUS
		(ain == 4) ? oam_bus : // OAMDATA
		(ain == 7) ? (is_pal_address ? {latched_dout[7:6], (grayscale ? {color1[5:4], 4'b0000} : color1)} : vram_latch) : // PPUDATA
		latched_dout) :
	latched_dout;

assign emphasis = {write_2001 ? ppu_dbus[7] : emph_reg[2], emph_reg[1], emph_reg[0]}; // behavior of 2c07 is unknown so oh well.

assign SS_PPU_BACK[    1] = obj_patt;
assign SS_PPU_BACK[    2] = bg_patt;
assign SS_PPU_BACK[    3] = obj_size;
assign SS_PPU_BACK[    4] = vbl_enable;
assign SS_PPU_BACK[    5] = grayscale;
assign SS_PPU_BACK[    6] = playfield_clip;
assign SS_PPU_BACK[    7] = object_clip;
assign SS_PPU_BACK[    8] = enable_playfield;
assign SS_PPU_BACK[    9] = enable_objects;
assign SS_PPU_BACK[12:10] = emph_reg;
assign SS_PPU_BACK[   13] = nmi_occured;
assign SS_PPU_BACK[36:34] = re_sr;

always @(posedge clk) begin
	if (reset) begin
		obj_patt         <= SS_PPU[    1]; // 0; // 2000 resets to 0
		bg_patt          <= SS_PPU[    2]; // 0; // 2000 resets to 0
		obj_size         <= SS_PPU[    3]; // 0; // 2000 resets to 0
		vbl_enable       <= SS_PPU[    4]; // 0;
		grayscale        <= SS_PPU[    5]; // 0; // 2001 resets to 0
		playfield_clip   <= SS_PPU[    6]; // 0; // 2001 resets to 0
		object_clip      <= SS_PPU[    7]; // 0; // 2001 resets to 0
		enable_playfield <= SS_PPU[    8]; // 0; // 2001 resets to 0
		enable_objects   <= SS_PPU[    9]; // 0; // 2001 resets to 0
		emph_reg         <= SS_PPU[12:10]; // 0; // 2001 resets to 0
		nmi_occured      <= SS_PPU[   13]; // 0; // wasn't reset before!
		re_sr            <= SS_PPU[36:34]; // 0; // rendering disabled on reset
	end else if (ce) begin
		// These are use combinationally so they have to be delayed to the end of M2
		obj_patt1 <= obj_patt;
		bg_patt1  <= bg_patt;
		obj_size1 <= obj_size;
		re_sr <= {re_sr[1:0], rendering_regs};
		eo_sr <= {eo_sr[1:0], enable_objects};
		eb_sr <= {eb_sr[1:0], enable_playfield};
		if (write) begin
			case (ain)
				0: begin // PPU Control Register 1
					// t:....BA.. ........ = d:......BA
					obj_patt <= ppu_dbus[3];
					bg_patt <= ppu_dbus[4];
					obj_size <= ppu_dbus[5];
					vbl_enable <= ppu_dbus[7];
				end

				1: begin // PPU Control Register 2
					grayscale <= ppu_dbus[0];
					playfield_clip <= ppu_dbus[1];
					object_clip <= ppu_dbus[2];
					enable_playfield <= ppu_dbus[3];
					enable_objects <= ppu_dbus[4];
					emph_reg <= |sys_type ? {ppu_dbus[7], ppu_dbus[5], ppu_dbus[6]} : ppu_dbus[7:5];
				end
			endcase
			if (clear) begin
				obj_patt         <= 'd0;
				bg_patt          <= 'd0;
				obj_size         <= 'd0;
				vbl_enable       <= 'd0;
				grayscale        <= 'd0;
				playfield_clip   <= 'd0;
				object_clip      <= 'd0;
				enable_playfield <= 'd0;
				enable_objects   <= 'd0;
				emph_reg         <= 'd0;
			end
		end
		// https://wiki.nesdev.com/w/index.php/NMI
		if (set_nmi)
			nmi_occured <= 1;
		if (clear_nmi)
			nmi_occured <= 0;
	end
end

// If we're triggering a VBLANK NMI
assign nmi = nmi_occured && vbl_enable;

// Last data on bus is persistent
reg [7:0] latched_dout;

reg [23:0] decay_high;
reg [23:0] decay_low;

reg refresh_high, refresh_low;

assign SS_PPU_BACK[   23] = refresh_high;
assign SS_PPU_BACK[   24] = refresh_low;
assign SS_PPU_BACK[32:25] = latched_dout;
assign SS_PPU_BACK[   33] = clear;
assign SS_PPU_BACK[41:37] = read_2007_delayed;
assign SS_PPU_BACK[46:42] = write_2007_delayed;
assign SS_PPU_BACK[63:58] = 'd0; // free to be used

assign SS_PPU_DECAY_BACK[23: 0] = decay_low;
assign SS_PPU_DECAY_BACK[47:24] = decay_high;
assign SS_PPU_DECAY_BACK[63:48] = 'd0; // free to be use

always @(posedge clk) begin
	if (ce && clear_signal)
		clear <= 0;
	if (refresh_high) begin
		decay_high <= 3221590; // aprox 600ms decay rate
		refresh_high <= 0;
	end

	if (refresh_low) begin
		decay_low <= 3221590;
		refresh_low <= 0;
	end

	if (ce) begin
		// 2007 reads/writes are very special. They wait for the read to end, then
		// enter a shift register that is high for 2 cycles 2 full cycle after the end
		// to 3 full cycles after the end.
		read_2007_delayed <= {read_2007_delayed[3:0], (read && (ain == 7))};
		write_2007_delayed <= {write_2007_delayed[3:0], (write && (ain == 7))};

		color_pipe <= '{color1, color_pipe[0], color_pipe[1], color_pipe[2]};

		latched_dout <= ppu_dbus;

		if (decay_high > 0)
			decay_high <= decay_high - 1'b1;
		else
			latched_dout[7:5] <= 3'b000;

		if (decay_low > 0)
			decay_low <= decay_low - 1'b1;
		else
			latched_dout[4:0] <= 5'b00000;
	end

	if (read) begin
		case (ain)
			2: begin
				refresh_high <= 1'b1;
			end

			4: begin
				//latched_dout <= oam_bus;
				refresh_high <= 1'b1;
				refresh_low <= 1'b1;
			end

			7: begin
				if (is_pal_address) begin
					refresh_low <= 1'b1;
				end else begin
					refresh_high <= 1'b1;
					refresh_low <= 1'b1;
				end
			end
			default: ;
		endcase

	end else if (write) begin
		refresh_high <= 1'b1;
		refresh_low <= 1'b1;
	end

	if (reset) begin
		latched_dout <= 8'd0;
		clear <= rst_behavior;
	end

	if (SaveStateBus_load) begin
		refresh_high <= SS_PPU[   23];
		refresh_low  <= SS_PPU[   24];
		latched_dout <= SS_PPU[32:25];
		clear        <= SS_PPU[   33];
		read_2007_delayed  <= SS_PPU[41:37];
		write_2007_delayed <= SS_PPU[46:42];
		decay_low    <= SS_PPU_DECAY[23: 0];
		decay_high   <= SS_PPU_DECAY[47:24];
	end
end

assign dout = latched_dout;

endmodule  // PPU