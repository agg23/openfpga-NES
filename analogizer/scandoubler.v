//
// scandoubler.v
// 
// Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 

// AMR - generates and output a pixel clock with a reliable phase relationship with
// with the scandoubled hsync pulse.  Allows the incoming data to be sampled more
// sparsely, reducing block RAM usage.  ce_x1/x2 are replaced with a ce_divider
// which is the largest value the counter will reach before resetting - so 3'111 to
// divide clk_sys by 8, 3'011 to divide by 4, 3'101 to divide by six.

// Also now has a bypass mode, in which the incoming data will be scaled to the output
// width but otherwise unmodified.  Simplifies the rest of the video chain.


module scandoubler
(
	// system interface
	input            clk_sys,

	input            bypass,

	// Pixelclock
	input      [2:0] ce_divider, // 0 - clk_sys/4, 1 - clk_sys/2, 2 - clk_sys/3, 3 - clk_sys/4, etc.
	output           pixel_ena,

	// scanlines (00-none 01-25% 10-50% 11-75%)
	input      [1:0] scanlines,

	// shifter video interface
	input            hb_in,
	input            vb_in,
	input            hs_in,
	input            vs_in,
	input      [COLOR_DEPTH-1:0] r_in,
	input      [COLOR_DEPTH-1:0] g_in,
	input      [COLOR_DEPTH-1:0] b_in,

	// output interface
	output       hb_out,
	output       vb_out,
	output       hs_out,
	output       vs_out,
	output [OUT_COLOR_DEPTH-1:0] r_out,
	output [OUT_COLOR_DEPTH-1:0] g_out,
	output [OUT_COLOR_DEPTH-1:0] b_out
);

parameter HCNT_WIDTH = 9; // Resolution of scandoubler buffer
parameter COLOR_DEPTH = 6; // Bits per colour to be stored in the buffer
parameter HSCNT_WIDTH = 12; // Resolution of hsync counters
parameter OUT_COLOR_DEPTH = 6; // Bits per color outputted

// --------------------- create output signals -----------------
// latch everything once more to make it glitch free and apply scanline effect
reg scanline;
reg [OUT_COLOR_DEPTH-1:0] r;
reg [OUT_COLOR_DEPTH-1:0] g;
reg [OUT_COLOR_DEPTH-1:0] b;

wire [COLOR_DEPTH*3-1:0] sd_mux = bypass ? {r_in, g_in, b_in} : sd_out[COLOR_DEPTH*3-1:0];

localparam m = OUT_COLOR_DEPTH/COLOR_DEPTH;
localparam n = OUT_COLOR_DEPTH%COLOR_DEPTH;

always @(*) begin
	if (n>0) begin
		b = { {m{sd_mux[COLOR_DEPTH-1:0]}}, sd_mux[COLOR_DEPTH-1 -:n] };
		g = { {m{sd_mux[COLOR_DEPTH*2-1:COLOR_DEPTH]}}, sd_mux[COLOR_DEPTH*2-1 -:n] };
		r = { {m{sd_mux[COLOR_DEPTH*3-1:COLOR_DEPTH*2]}}, sd_mux[COLOR_DEPTH*3-1 -:n] };
	end else begin
		b = { {m{sd_mux[COLOR_DEPTH-1:0]}} };
		g = { {m{sd_mux[COLOR_DEPTH*2-1:COLOR_DEPTH]}} };
		r = { {m{sd_mux[COLOR_DEPTH*3-1:COLOR_DEPTH*2]}} };
	end
end


reg [OUT_COLOR_DEPTH+6:0] r_mul;
reg [OUT_COLOR_DEPTH+6:0] g_mul;
reg [OUT_COLOR_DEPTH+6:0] b_mul;
reg hb_o;
reg vb_o;
reg hs_o;
reg vs_o;

wire scanline_bypass = (!scanline) | (!(|scanlines)) | bypass;

// More subtle variant of the scanlines effect.
// 0 00 -> 1000000 0x40	 -  bypass / inert mode
// 1 01 -> 0111010 0x3a  -  25%
// 2 10 -> 0101110 0x2e  -  50%
// 3 11 -> 0011010 0x1a  -  75%

wire [6:0] scanline_coeff = scanline_bypass ?
                            7'b1000000 : {~(&scanlines),scanlines[0],1'b1,~scanlines[0],2'b10};

always @(posedge clk_sys) begin
	if(ce_x2) begin
		hs_o <= hs_sd;
		vs_o <= vs_sd;
		hb_o <= hb_sd;
		vb_o <= vb_sd;

		// reset scanlines at every new screen
		if(vs_o != vs_in) scanline <= 0;

		// toggle scanlines at begin of every hsync
		if(hs_o && !hs_sd) scanline <= !scanline;

		r_mul<=r*scanline_coeff;
		g_mul<=g*scanline_coeff;
		b_mul<=b*scanline_coeff;
	end
end

wire [OUT_COLOR_DEPTH-1:0] r_o = r_mul[OUT_COLOR_DEPTH+5 -:OUT_COLOR_DEPTH];
wire [OUT_COLOR_DEPTH-1:0] g_o = g_mul[OUT_COLOR_DEPTH+5 -:OUT_COLOR_DEPTH];
wire [OUT_COLOR_DEPTH-1:0] b_o = b_mul[OUT_COLOR_DEPTH+5 -:OUT_COLOR_DEPTH];

// Output multiplexing
wire   blank_out = hb_out | vb_out;
assign r_out = blank_out ? {OUT_COLOR_DEPTH{1'b0}} : bypass ? r : r_o;
assign g_out = blank_out ? {OUT_COLOR_DEPTH{1'b0}} : bypass ? g : g_o;
assign b_out = blank_out ? {OUT_COLOR_DEPTH{1'b0}} : bypass ? b : b_o;
assign hb_out = bypass ? hb_in : hb_o;
assign vb_out = bypass ? vb_in : vb_o;
assign hs_out = bypass ? hs_in : hs_o;
assign vs_out = bypass ? vs_in : vs_o;


// scan doubler output register
reg [COLOR_DEPTH*3-1:0] sd_out;

// ==================================================================
// ======================== the line buffers ========================
// ==================================================================

// 2 lines of 2**HCNT_WIDTH pixels 3*COLOR_DEPTH bit RGB
(* ramstyle = "no_rw_check" *) reg [COLOR_DEPTH*3-1:0] sd_buffer[2*2**HCNT_WIDTH];

// use alternating sd_buffers when storing/reading data   
reg        line_toggle;

// total hsync time (in 16MHz cycles), hs_total reaches 1024
reg  [HCNT_WIDTH-1:0] hcnt;
reg  [HSCNT_WIDTH:0] hs_max;
reg  [HSCNT_WIDTH:0] hs_rise;
reg  [HCNT_WIDTH:0] hb_fall[2];
reg  [HCNT_WIDTH:0] hb_rise[2];
reg  [HCNT_WIDTH+1:0] vb_event[2];
reg  [HCNT_WIDTH+1:0] vs_event[2];
reg  [HSCNT_WIDTH:0] synccnt;

// Input pixel clock, aligned with input sync:
wire[2:0] ce_divider_adj = |ce_divider ? ce_divider : 3'd3; // 0 = clk/4 for compatiblity
reg [2:0] ce_divider_in;
reg [2:0] ce_divider_out;

reg [2:0] i_div;
wire ce_x1 = (i_div == ce_divider_in);

always @(posedge clk_sys) begin
	reg hsD, vsD;
	reg vbD;
	reg hbD;

	// Pixel logic on x1 clkena
	if(ce_x1) begin
		hcnt <= hcnt + 1'd1;
		vsD <= vs_in;
		vbD <= vb_in;

		sd_buffer[{line_toggle, hcnt}] <= {r_in, g_in, b_in};
		if (vbD ^ vb_in) vb_event[line_toggle] <= {1'b1, vb_in, hcnt};
		if (vsD ^ vs_in) vs_event[line_toggle] <= {1'b1, vs_in, hcnt};
		// save position of hblank
		hbD <= hb_in;
		if(!hbD &&  hb_in) hb_rise[line_toggle] <= {1'b1, hcnt};
		if( hbD && !hb_in) hb_fall[line_toggle] <= {1'b1, hcnt};
	end

	// Generate pixel clock
	i_div <= i_div + 1'd1;

	if (i_div==ce_divider_adj) i_div <= 3'b000;

	synccnt <= synccnt + 1'd1;
	hsD <= hs_in;
	if(hsD && !hs_in) begin
		// At hsync latch the ce_divider counter limit for the input clock
		// and pass the previous input clock limit to the output stage.
		// This should give correct output if the pixel clock changes mid-screen.
		ce_divider_out <= ce_divider_in;
		ce_divider_in <= ce_divider_adj;
		hs_max <= {1'b0,synccnt[HSCNT_WIDTH:1]};
		hcnt <= 0;
		synccnt <= 0;
		i_div <= 3'b000;
	end

	// save position of rising edge
	if(!hsD && hs_in) hs_rise <= {1'b0,synccnt[HSCNT_WIDTH:1]};

	// begin of incoming hsync
	if(hsD && !hs_in) begin
		line_toggle <= !line_toggle;
		vb_event[!line_toggle] <= 0;
		vs_event[!line_toggle] <= 0;
		hb_rise[!line_toggle][HCNT_WIDTH] <= 0;
		hb_fall[!line_toggle][HCNT_WIDTH] <= 0;
	end

end

// ==================================================================
// ==================== output timing generation ====================
// ==================================================================

reg  [HSCNT_WIDTH:0] sd_synccnt;
reg  [HCNT_WIDTH-1:0] sd_hcnt;
reg vb_sd = 0;
reg hb_sd = 0;
reg hs_sd = 0;
reg vs_sd = 0;

// Output pixel clock, aligned with output sync:
reg [2:0] sd_i_div;
wire ce_x2 = (sd_i_div == ce_divider_out) | (sd_i_div == {1'b0,ce_divider_out[2:1]});

// timing generation runs 32 MHz (twice the input signal analysis speed)
always @(posedge clk_sys) begin
	reg hsD;

	// Output logic on x2 clkena
	if(ce_x2) begin
		// output counter synchronous to input and at twice the rate
		sd_hcnt <= sd_hcnt + 1'd1;

		// read data from line sd_buffer
		sd_out <= sd_buffer[{~line_toggle, sd_hcnt}];

		// Handle VBlank event
		if(vb_event[~line_toggle][HCNT_WIDTH+1] && sd_hcnt == vb_event[~line_toggle][HCNT_WIDTH-1:0]) vb_sd <= vb_event[~line_toggle][HCNT_WIDTH];
		// Handle VSync event
		if(vs_event[~line_toggle][HCNT_WIDTH+1] && sd_hcnt == vs_event[~line_toggle][HCNT_WIDTH-1:0]) vs_sd <= vs_event[~line_toggle][HCNT_WIDTH];
		// Handle HBlank events
		if(hb_rise[~line_toggle][HCNT_WIDTH] && sd_hcnt == hb_rise[~line_toggle][HCNT_WIDTH-1:0]) hb_sd <= 1;
		if(hb_fall[~line_toggle][HCNT_WIDTH] && sd_hcnt == hb_fall[~line_toggle][HCNT_WIDTH-1:0]) hb_sd <= 0;
	end

	sd_i_div <= sd_i_div + 1'd1;
	if (sd_i_div==ce_divider_adj) sd_i_div <= 3'b000;

	//  Framing logic on sysclk
	sd_synccnt <= sd_synccnt + 1'd1;
	hsD <= hs_in;

	if(sd_synccnt == hs_max || (hsD && !hs_in)) begin
		sd_synccnt <= 0;
		sd_hcnt <= 0;
		hs_sd <= 0;
		sd_i_div <= 3'b000;
	end

	if(sd_synccnt == hs_rise) hs_sd <= 1;

end

wire ce_x4 = sd_i_div[0]; // Faster pixel_ena for higher subdivisions to prevent blending from becoming to coarse.

assign pixel_ena = ce_divider_out > 3'd5 ? 
		bypass ? ce_x2 : ce_x4 :
		bypass ? ce_x1 : ce_x2 ;

endmodule