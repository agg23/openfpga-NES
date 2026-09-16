// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jamie Blanks

// Portable NTSC composite decoder.

module composite_decoder #(
	// Samples per subcarrier cycle. Must be EVEN, so that the notch delay
	// SPC/2 is a whole number of samples and lands exactly half a cycle back.
	// Pick a sample clock that is a whole multiple of the subcarrier.
	parameter SPC = 8,
	// Line counter width. The comb's line store is 2^HCNT_W samples deep, so
	// it must cover a whole line when the comb is used.
	parameter HCNT_W = 10,
	// Luma low-pass: a boxcar this many samples long after the notch, 1 for
	// none. SPC/2 nulls the even subcarrier harmonics, which a carrier with
	// unequal rise and fall leaves in luma, and rolls luma off near 3 MHz
	// the way a consumer set does. The chroma and timing paths are delayed
	// to match.
	parameter LUMA_LP = 1,
	// Decoded samples per output pixel, a power of two. The pixel enable is
	// phase locked to the line so a scaler sees a stable grid.
	parameter PIX_DIV = 1,
	// Demodulation axes: degrees from the burst to the first axis, in 256ths
	// of a turn. NTSC I sits 57 degrees from burst (123 from B-Y), with Q
	// 90 degrees clockwise of it.
	parameter AXIS = 41,
	// Matrix from the two demodulated axes to RGB, signed Q8. Defaults are
	// the NTSC YIQ set: R = Y + 0.956 I + 0.621 Q, G = Y - 0.272 I - 0.647 Q,
	// B = Y - 1.106 I + 1.703 Q.
	parameter signed [17:0] MAT_RI = 18'sd245,
	parameter signed [17:0] MAT_RQ = 18'sd159,
	parameter signed [17:0] MAT_GI = -18'sd70,
	parameter signed [17:0] MAT_GQ = -18'sd166,
	parameter signed [17:0] MAT_BI = -18'sd283,
	parameter signed [17:0] MAT_BQ = 18'sd436
)(
	input                clk,
	input                reset,
	input                ce,          // one composite sample

	// Signed Q2.21 volts: 1.0 = 1.0V. Any DC reference: sync is separated
	// from the waveform and black is clamped off the back porch.
	input  signed [23:0] comp,

	input          [7:0] sat,         // 128 = unity
	input          [7:0] hue,         // 256 = one full cycle
	input          [3:0] chroma_trail,  // one-pole chroma tail, 2^n samples,
	                                  // 0 = off; luma delayed to match

	// Sharpness: aperture correction, luma peaking near 3 MHz by up to about
	// 9 dB at 15, the set's sharpness knob. 0 leaves luma as filtered.
	input          [3:0] sharpness,

	// Black stretch: each frame's darkest picture content is pulled toward
	// black by this fraction (0 off, 1 quarter, 2 half, 3 three quarters),
	// the dynamic-picture circuit of late-80s sets. Scenes that already
	// reach black are untouched.
	input          [1:0] black_stretch,

	// Brightness: how far below blanking black sits, signed Q2.13 volts.
	// Zero puts black at blanking, right for NTSC-J and consoles; a set
	// expecting the NTSC-M 7.5 IRE pedestal would use -439. Positive values
	// lift the picture, which is how the NES's below-blanking entries become
	// visible shades.
	input  signed [15:0] brightness,

	// Contrast: volts-to-white gain, Q16, applied after brightness:
	// 65536*255 / (white * 8192), 2857 for the NTSC 0.714 V white.
	input         [15:0] contrast,

	// Luma/chroma separation: 0 notch, 1 two-line comb, 2 adaptive comb
	// that falls back to the notch where adjacent lines differ.
	input          [1:0] comb_mode,

	output logic         ce_out,     // one decoded sample
	output logic         pix_out,    // one output pixel
	output logic         hs_out,
	output logic         vs_out,
	output logic         hb_out,
	output logic         vb_out,
	output logic   [7:0] r_out,
	output logic   [7:0] g_out,
	output logic   [7:0] b_out
);

localparam HALFC     = SPC / 2;
localparam [31:0] PHASE_INC = 32'd16777216 / SPC;  // 2^24 per subcarrier cycle
localparam [31:0] PHASE_FRAC = 32'd16777216 % SPC;
localparam PHASE_REM_W = $clog2(SPC);
localparam [31:0] BOX_RECIP = 32'd65536 / SPC;     // boxcar divide, avoids /SPC

localparam BURST_ACC  = 32;   // burst samples averaged, power of two
localparam BURST_SH   = 5;
localparam CLAMP_ACC  = 16;   // back-porch samples averaged for black
localparam CLAMP_SH   = 4;


function automatic integer tenths_us(input integer t);   // samples in t/10 us
	tenths_us = (SPC * 3579545 / 1000) * t / 10000;
endfunction
localparam [10:0] HS_WIDTH    = 11'(tenths_us(47));   // regenerated HS pulse
localparam [10:0] BURST_GATE  = 11'(tenths_us(60));   // burst measured from here
localparam [10:0] CLAMP_GATE  = 11'(tenths_us(85));   // black measured from here
localparam [10:0] HB_END      = 11'(tenths_us(91));
localparam [10:0] LONG_SYNC   = 11'(tenths_us(80));   // sync still low here: vertical
localparam [HCNT_W-1:0] FRONT_PORCH = HCNT_W'(tenths_us(17));
localparam [8:0] VB_BEFORE = 9'd3;    // blanked lines before vertical sync
localparam [8:0] VB_AFTER  = 9'd17;   // blanked lines from vertical sync on
localparam [8:0] LINES     = 9'd262;

localparam signed [23:0] SLICE = 24'sd209715;
localparam signed [23:0] TIP_DECAY = 24'sd2;

// chroma and timing paths.
localparam LP_DLY = (LUMA_LP > 1) ? (LUMA_LP + 2) / 2 : 0;
// Peaking taps sit this far apart, putting the peak near 3 MHz.
localparam PK_SPAN = SPC / 2 + 1;
localparam ALIGN_DLY = LP_DLY + PK_SPAN;
localparam [31:0] LP_RECIP = 32'd65536 / LUMA_LP;
localparam [31:0] MIN_MAG2 = 32'd16384;
localparam               BURST_SHIFT = 8;
localparam [7:0]         BURST_CONV  = 8'(AXIS);
localparam [31:0]        DIV_NUM     = 32'h49F700A6;

function automatic signed [15:0] sat16(input signed [17:0] v);
	if      (v >  18'sd32767) sat16 =  16'sd32767;
	else if (v < -18'sd32768) sat16 = -16'sd32768;
	else                      sat16 =  v[15:0];
endfunction

logic signed [23:0] tip;
logic sync_l, sync_d;
logic [HCNT_W-1:0] hcnt, line_len, front_at;
logic [8:0] vline;
logic vs_i, vb_i;

always_ff @(posedge clk) if (reset) begin
	tip <= 24'sh7fffff;
	sync_l <= 1'b0;
	sync_d <= 1'b0;
end else if (ce) begin
	tip <= (comp < tip) ? comp : tip + TIP_DECAY;
	sync_l <= comp < tip + SLICE;
	sync_d <= sync_l;
end

wire line_start = sync_l && ~sync_d;   // leading edge of sync

wire  [9:0] hpos;   // saturated for the window compares
generate
	if (HCNT_W > 10) begin : hpos_sat
		assign hpos = |hcnt[HCNT_W-1:10] ? 10'h3ff : hcnt[9:0];
	end else begin : hpos_full
		assign hpos = hcnt;
	end
endgenerate

wire in_burst  = ({1'b0, hpos} >= BURST_GATE) && ({1'b0, hpos} < BURST_GATE + 11'(BURST_ACC));
wire in_clamp  = ({1'b0, hpos} >= CLAMP_GATE) && ({1'b0, hpos} < CLAMP_GATE + 11'(CLAMP_ACC));
wire burst_fin = ({1'b0, hpos} == BURST_GATE + 11'(BURST_ACC));
wire clamp_fin = ({1'b0, hpos} == CLAMP_GATE + 11'(CLAMP_ACC));
wire long_sync = ({1'b0, hpos} == LONG_SYNC);

always_ff @(posedge clk) if (reset) begin
	hcnt <= {HCNT_W{1'b1}};
	line_len <= {HCNT_W{1'b1}};
	front_at <= {HCNT_W{1'b1}};
	vline <= 9'd0;
	vs_i <= 1'b0;
	vb_i <= 1'b0;
end else if (ce) begin
	if (line_start) begin
		hcnt <= {HCNT_W{1'b0}};
		line_len <= hcnt + 1'b1;
		front_at <= hcnt + 1'b1 - FRONT_PORCH;
	end else if (~&hcnt) begin
		hcnt <= hcnt + 1'b1;
	end

	if (long_sync) begin
		if (sync_l && !vs_i) vline <= 9'd0;
		else vline <= (vline == LINES - 9'd1) ? 9'd0 : vline + 9'd1;
		vs_i <= sync_l;
		vb_i <= (sync_l && !vs_i) || vline < VB_AFTER - 9'd1 || vline >= LINES - VB_BEFORE - 9'd1;
	end
end

wire hs_i = ({1'b0, hpos} < HS_WIDTH);
wire hb_i = ({1'b0, hpos} < HB_END) || (hcnt >= front_at);


logic signed [28:0] black_acc;
logic signed [23:0] black;
logic signed [15:0] c16;

wire signed [24:0] c_sub = comp - black;
wire signed [24:0] c_shf = c_sub >>> 8;

always_ff @(posedge clk) if (reset) begin
	black_acc <= 29'sd0;
	black <= 24'sd0;
	c16 <= 16'sd0;
end else if (ce) begin
	if (hpos == 10'd0)   black_acc <= 29'sd0;
	else if (in_clamp)   black_acc <= black_acc + {{5{comp[23]}}, comp};
	if (clamp_fin)       black <= black_acc[27:CLAMP_SH];

	if      (c_shf >  25'sd32767) c16 <=  16'sd32767;
	else if (c_shf < -25'sd32768) c16 <= -16'sd32768;
	else                          c16 <=  c_shf[15:0];
end

logic [HCNT_W-1:0] hcnt_d;
logic signed [15:0] prev;
logic [15:0] ram_rd;

wire  [HCNT_W:0]   comb_ahead = {1'b0, hcnt} + 1'b1;
wire  [HCNT_W-1:0] comb_rd = (comb_ahead >= {1'b0, line_len}) ?
	comb_ahead[HCNT_W-1:0] - line_len : comb_ahead[HCNT_W-1:0];

dpram #(.widthad_a(HCNT_W), .width_a(16)) linebuf
(
	.clock_a   (clk),
	.address_a (hcnt_d),
	.wren_a    (ce),
	.byteena_a (2'b11),
	.data_a    ($unsigned(c16)),
	.q_a       (),

	.clock_b   (clk),
	.address_b (comb_rd),
	.wren_b    (1'b0),
	.byteena_b (2'b11),
	.data_b    (16'd0),
	.q_b       (ram_rd)
);

logic [1:0] lines_seen;

always_ff @(posedge clk) if (reset) begin
	hcnt_d <= {HCNT_W{1'b0}};
	prev <= 16'sd0;
	lines_seen <= 2'd0;
end else if (ce) begin
	hcnt_d <= hcnt;
	prev   <= (lines_seen == 2'd3) ? $signed(ram_rd) : c16;
	if (line_start && lines_seen != 2'd3) lines_seen <= lines_seen + 2'd1;
end


logic [HALFC-1:0][15:0] nd;
logic signed [15:0] yc, cc, yc_d, y_lp;

wire signed [15:0] c_del = $signed(nd[HALFC-1]);
/* verilator lint_off UNUSEDSIGNAL */
wire signed [16:0] n_sum = c16 + c_del;     // notch luma
wire signed [16:0] n_dif = c16 - c_del;     // notch chroma
wire signed [16:0] v_sum = c16 + prev;      // comb luma
wire signed [16:0] v_dif = c16 - prev;      // comb chroma
/* verilator lint_on UNUSEDSIGNAL */

logic [SPC-1:0][15:0] dbuf;
logic [15:0] dacc;
logic [4:0] alpha;
wire signed [16:0] v_err = v_sum[16:1] - n_sum[16:1];
wire [15:0] v_abs = v_err[16] ? 16'(-v_err) : v_err[15:0];
wire [15:0] d_old = dbuf[SPC-1];
wire [15:0] dacc_n = dacc + v_abs - d_old;
/* verilator lint_off UNUSEDSIGNAL */
wire [31:0] dacc_d = dacc_n * BOX_RECIP[15:0];
wire [15:0] d_mean = dacc_d[31:16];
/* verilator lint_on UNUSEDSIGNAL */
wire [4:0] alpha_adapt = (d_mean[15:5] >= 11'd16) ? 5'd0 : 5'd16 - {1'b0, d_mean[8:5]};
wire [4:0] alpha_n = (comb_mode == 2'd1) ? 5'd16 : (comb_mode == 2'd2) ? alpha_adapt : 5'd0;

/* verilator lint_off UNUSEDSIGNAL */
wire signed [23:0] y_mix = v_sum * $signed({1'b0, alpha}) + n_sum * $signed({1'b0, 5'd16 - alpha});
wire signed [23:0] c_mix = v_dif * $signed({1'b0, alpha}) + n_dif * $signed({1'b0, 5'd16 - alpha});
/* verilator lint_on UNUSEDSIGNAL */

/* verilator lint_off UNUSEDSIGNAL */
wire signed [16:0] y_sum = yc + yc_d;
/* verilator lint_on UNUSEDSIGNAL */

always_ff @(posedge clk) if (reset) begin
	nd <= '0;
	dbuf <= '0;
	dacc <= 16'd0;
	alpha <= 5'd0;
	yc <= 16'sd0;
	cc <= 16'sd0;
	yc_d <= 16'sd0;
	y_lp <= 16'sd0;
end else if (ce) begin
	nd    <= {nd[HALFC-2:0], c16};
	dbuf  <= {dbuf[SPC-2:0], v_abs};
	dacc  <= dacc_n;
	alpha <= alpha_n;
	yc    <= y_mix[20:5];
	cc    <= c_mix[20:5];
	yc_d  <= yc;
	y_lp  <= y_sum[16:1];
end

logic [23:0] phase;
logic [PHASE_REM_W-1:0] phase_rem;
wire [PHASE_REM_W:0] phase_rem_next = {1'b0, phase_rem} + PHASE_FRAC[PHASE_REM_W:0];

always_ff @(posedge clk) if (reset) begin
	phase <= 24'd0;
	phase_rem <= '0;
end else if (ce) begin
	if (phase_rem_next >= SPC[PHASE_REM_W:0]) begin
		phase <= phase + PHASE_INC[23:0] + 24'd1;
		phase_rem <= PHASE_REM_W'(phase_rem_next - SPC[PHASE_REM_W:0]);
	end else begin
		phase <= phase + PHASE_INC[23:0];
		phase_rem <= phase_rem_next[PHASE_REM_W-1:0];
	end
end

function automatic signed [10:0] qsin(input [6:0] a);
	case (a)
		7'd0 : qsin = 11'sd0;
		7'd1 : qsin = 11'sd13;
		7'd2 : qsin = 11'sd25;
		7'd3 : qsin = 11'sd38;
		7'd4 : qsin = 11'sd50;
		7'd5 : qsin = 11'sd63;
		7'd6 : qsin = 11'sd75;
		7'd7 : qsin = 11'sd87;
		7'd8 : qsin = 11'sd100;
		7'd9 : qsin = 11'sd112;
		7'd10: qsin = 11'sd124;
		7'd11: qsin = 11'sd136;
		7'd12: qsin = 11'sd148;
		7'd13: qsin = 11'sd160;
		7'd14: qsin = 11'sd172;
		7'd15: qsin = 11'sd184;
		7'd16: qsin = 11'sd196;
		7'd17: qsin = 11'sd207;
		7'd18: qsin = 11'sd218;
		7'd19: qsin = 11'sd230;
		7'd20: qsin = 11'sd241;
		7'd21: qsin = 11'sd252;
		7'd22: qsin = 11'sd263;
		7'd23: qsin = 11'sd273;
		7'd24: qsin = 11'sd284;
		7'd25: qsin = 11'sd294;
		7'd26: qsin = 11'sd304;
		7'd27: qsin = 11'sd314;
		7'd28: qsin = 11'sd324;
		7'd29: qsin = 11'sd334;
		7'd30: qsin = 11'sd343;
		7'd31: qsin = 11'sd352;
		7'd32: qsin = 11'sd361;
		7'd33: qsin = 11'sd370;
		7'd34: qsin = 11'sd379;
		7'd35: qsin = 11'sd387;
		7'd36: qsin = 11'sd395;
		7'd37: qsin = 11'sd403;
		7'd38: qsin = 11'sd410;
		7'd39: qsin = 11'sd418;
		7'd40: qsin = 11'sd425;
		7'd41: qsin = 11'sd432;
		7'd42: qsin = 11'sd438;
		7'd43: qsin = 11'sd445;
		7'd44: qsin = 11'sd451;
		7'd45: qsin = 11'sd456;
		7'd46: qsin = 11'sd462;
		7'd47: qsin = 11'sd467;
		7'd48: qsin = 11'sd472;
		7'd49: qsin = 11'sd477;
		7'd50: qsin = 11'sd481;
		7'd51: qsin = 11'sd485;
		7'd52: qsin = 11'sd489;
		7'd53: qsin = 11'sd492;
		7'd54: qsin = 11'sd496;
		7'd55: qsin = 11'sd499;
		7'd56: qsin = 11'sd501;
		7'd57: qsin = 11'sd503;
		7'd58: qsin = 11'sd505;
		7'd59: qsin = 11'sd507;
		7'd60: qsin = 11'sd509;
		7'd61: qsin = 11'sd510;
		7'd62: qsin = 11'sd510;
		7'd63: qsin = 11'sd511;
		7'd64: qsin = 11'sd511;
		default: qsin = 11'sd511;
	endcase
endfunction

function automatic signed [10:0] sine(input [7:0] p);
	logic [6:0] idx;
	logic signed [10:0] v;
	idx  = p[6] ? (7'd64 - {1'b0, p[5:0]}) : {1'b0, p[5:0]};
	v    = qsin(idx);
	sine = p[7] ? -v : v;
endfunction

wire [7:0] ph = phase[23:16];

logic signed [17:0] i_dem, q_dem;

/* verilator lint_off UNUSEDSIGNAL */
wire signed [26:0] i_mul = cc * sine(ph);
wire signed [26:0] q_mul = cc * sine(ph + 8'd64);
/* verilator lint_on UNUSEDSIGNAL */

always_ff @(posedge clk) if (reset) begin
	i_dem <= 18'sd0;
	q_dem <= 18'sd0;
end else if (ce) begin
	i_dem <= i_mul[26:9];                   // undo the table's 511 scale
	q_dem <= -q_mul[26:9];
end

logic [SPC-1:0][17:0] ibuf, qbuf;
logic signed [21:0] iacc, qacc;
logic signed [17:0] ibox, qbox;

wire signed [17:0] i_old = $signed(ibuf[SPC-1]);
wire signed [17:0] q_old = $signed(qbuf[SPC-1]);
wire signed [21:0] iacc_n = iacc + {{4{i_dem[17]}}, i_dem} - {{4{i_old[17]}}, i_old};
wire signed [21:0] qacc_n = qacc + {{4{q_dem[17]}}, q_dem} - {{4{q_old[17]}}, q_old};
/* verilator lint_off UNUSEDSIGNAL */
wire signed [38:0] iacc_d = iacc_n * $signed({1'b0, BOX_RECIP[16:0]});
wire signed [38:0] qacc_d = qacc_n * $signed({1'b0, BOX_RECIP[16:0]});
/* verilator lint_on UNUSEDSIGNAL */

always_ff @(posedge clk) if (reset) begin
	ibuf <= '0;
	qbuf <= '0;
	iacc <= 22'sd0;
	qacc <= 22'sd0;
	ibox <= 18'sd0;
	qbox <= 18'sd0;
end else if (ce) begin
	ibuf <= {ibuf[SPC-2:0], i_dem};
	qbuf <= {qbuf[SPC-2:0], q_dem};
	iacc <= iacc_n;
	qacc <= qacc_n;
	ibox <= iacc_d[33:16];
	qbox <= qacc_d[33:16];
end

logic signed [22:0] ib_acc, qb_acc;
logic signed [15:0] ib, qb;
logic signed [15:0] ibh, qbh;
logic signed [17:0] cg, sg;

wire [7:0] hue_ph = BURST_CONV - hue;   // positive hue turns the picture counter-clockwise
wire signed [10:0] hue_c = sine(hue_ph + 8'd64);
wire signed [10:0] hue_s = sine(hue_ph);
/* verilator lint_off UNUSEDSIGNAL */
wire signed [26:0] rot_i = ib * hue_c - qb * hue_s;
wire signed [26:0] rot_q = ib * hue_s + qb * hue_c;
/* verilator lint_on UNUSEDSIGNAL */

wire signed [31:0] ibh_x = {{16{ibh[15]}}, ibh};
wire signed [31:0] qbh_x = {{16{qbh[15]}}, qbh};
wire        [31:0] mag2  = $unsigned(ibh_x * ibh_x) + $unsigned(qbh_x * qbh_x);

logic [31:0] div_rem;
/* verilator lint_off UNUSEDSIGNAL */
logic [31:0] div_num, div_quo, div_den;
/* verilator lint_on UNUSEDSIGNAL */
logic  [5:0] div_cnt;
logic        div_go, div_start;

wire [32:0] rem_sh = {div_rem, div_num[31]};
wire        rem_ge = (rem_sh >= {1'b0, div_den});
/* verilator lint_off UNUSEDSIGNAL */
wire [32:0] rem_nx = rem_ge ? (rem_sh - {1'b0, div_den}) : rem_sh;
/* verilator lint_on UNUSEDSIGNAL */

logic [15:0] inv;
logic        colour_ok;

/* verilator lint_off UNUSEDSIGNAL */
wire signed [33:0] cg_mul = ibh * $signed({1'b0, inv});
wire signed [33:0] sg_mul = qbh * $signed({1'b0, inv});
wire signed [17:0] cg_raw =  cg_mul[BURST_SHIFT+17:BURST_SHIFT];

wire signed [17:0] sg_raw =  sg_mul[BURST_SHIFT+17:BURST_SHIFT];
wire signed [25:0] cg_sat = cg_raw * $signed({1'b0, sat});
wire signed [25:0] sg_sat = sg_raw * $signed({1'b0, sat});
/* verilator lint_on UNUSEDSIGNAL */

always_ff @(posedge clk) if (reset) begin
	ib_acc <= 23'sd0;
	qb_acc <= 23'sd0;
	ib <= 16'sd0;
	qb <= 16'sd0;
	ibh <= 16'sd0;
	qbh <= 16'sd0;
	cg <= 18'sd0;
	sg <= 18'sd0;
	div_rem <= 32'd0;
	div_num <= 32'd0;
	div_quo <= 32'd0;
	div_den <= 32'd1;
	div_cnt <= 6'd0;
	div_go <= 1'b0;
	div_start <= 1'b0;
	inv <= 16'd0;
	colour_ok <= 1'b0;
end else if (ce) begin
	if (hpos == 10'd0) begin
		ib_acc <= 23'sd0;
		qb_acc <= 23'sd0;
	end
	else if (in_burst) begin
		ib_acc <= ib_acc + {{5{ibox[17]}}, ibox};
		qb_acc <= qb_acc + {{5{qbox[17]}}, qbox};
	end

	if (burst_fin) begin
		ib  <= sat16(ib_acc[22:BURST_SH]);
		qb  <= sat16(qb_acc[22:BURST_SH]);
	end

	if (burst_fin) div_go <= 1'b1;
	else           div_go <= 1'b0;
	div_start <= div_go;

	if (div_go) begin
		ibh     <= rot_i[24:9];
		qbh     <= rot_q[24:9];
	end

	if (div_start) begin
		div_cnt <= 6'd32;
		div_rem <= 32'd0;
		div_quo <= 32'd0;
		div_num <= DIV_NUM;
		div_den <= mag2;
	end
	else if (|div_cnt) begin
		div_cnt <= div_cnt - 6'd1;
		div_num <= {div_num[30:0], 1'b0};
		div_quo <= {div_quo[30:0], rem_ge};
		div_rem <= rem_nx[31:0];

		if (div_cnt == 6'd1) begin
			colour_ok <= (div_den >= MIN_MAG2);
			inv       <= |div_quo[30:15] ? 16'hFFFF : {div_quo[14:0], rem_ge};
		end
	end

	cg <= colour_ok ? cg_sat[24:7] : 18'sd0;
	sg <= colour_ok ? sg_sat[24:7] : 18'sd0;
end

logic signed [17:0] i_cor, q_cor, i_sm, q_sm;

/* verilator lint_off UNUSEDSIGNAL */
wire signed [36:0] icor_m = ibox * cg + qbox * sg;
wire signed [36:0] qcor_m = qbox * cg - ibox * sg;
/* verilator lint_on UNUSEDSIGNAL */
wire signed [17:0] i_err  = i_cor - i_sm;
wire signed [17:0] q_err  = q_cor - q_sm;

always_ff @(posedge clk) if (reset) begin
	i_cor <= 18'sd0;
	q_cor <= 18'sd0;
	i_sm <= 18'sd0;
	q_sm <= 18'sd0;
end else if (ce) begin
	i_cor <= icor_m[29:12];
	q_cor <= qcor_m[29:12];
	i_sm  <= |chroma_trail ? (i_sm + (i_err >>> chroma_trail)) : i_cor;
	q_sm  <= |chroma_trail ? (q_sm + (q_err >>> chroma_trail)) : q_cor;
end

logic signed [15:0] y_bw;
generate
	if (LUMA_LP > 1) begin : luma_lp
		logic [LUMA_LP-1:0][15:0] lbuf;
		logic signed [20:0] lacc;
		wire signed [15:0] l_old = $signed(lbuf[LUMA_LP-1]);
		wire signed [20:0] lacc_n = lacc + {{5{y_lp[15]}}, y_lp} - {{5{l_old[15]}}, l_old};
		/* verilator lint_off UNUSEDSIGNAL */
		wire signed [37:0] lacc_d = lacc_n * $signed({1'b0, LP_RECIP[16:0]});
		/* verilator lint_on UNUSEDSIGNAL */
		always_ff @(posedge clk) if (reset) begin
			lbuf <= '0;
			lacc <= 21'sd0;
			y_bw <= 16'sd0;
		end else if (ce) begin
			lbuf <= {lbuf[LUMA_LP-2:0], y_lp};
			lacc <= lacc_n;
			y_bw <= lacc_d[31:16];
		end
	end else begin : luma_wide
		assign y_bw = y_lp;
	end
endgenerate

logic [2*PK_SPAN-1:0][15:0] pkbuf;
logic signed [15:0] y_pk;
wire signed [15:0] pk_mid = $signed(pkbuf[PK_SPAN-1]);
wire signed [15:0] pk_old = $signed(pkbuf[2*PK_SPAN-1]);
wire signed [17:0] pk_diff = {pk_mid[15], pk_mid, 1'b0} - {{2{y_bw[15]}}, y_bw} - {{2{pk_old[15]}}, pk_old};
/* verilator lint_off UNUSEDSIGNAL */
wire signed [22:0] pk_mul = pk_diff * $signed({1'b0, sharpness});
wire signed [18:0] pk_sum = {{3{pk_mid[15]}}, pk_mid} + {{1{pk_mul[22]}}, pk_mul[22:5]};
/* verilator lint_on UNUSEDSIGNAL */

always_ff @(posedge clk) if (reset) begin
	pkbuf <= '0;
	y_pk <= 16'sd0;
end else if (ce) begin
	pkbuf <= {pkbuf[2*PK_SPAN-2:0], y_bw};
	if      (pk_sum >  19'sd32767) y_pk <=  16'sd32767;
	else if (pk_sum < -19'sd32768) y_pk <= -16'sd32768;
	else                           y_pk <=  pk_sum[15:0];
end

// Luma delay line matched to the chroma trail's mean delay.
wire [3:0] luma_delay = (chroma_trail == 4'd0) ? 4'd0 : (chroma_trail >= 4'd4) ? 4'd15 : 4'((1 << chroma_trail) - 1);

logic [15:0][15:0] ybuf;
logic signed [15:0] y_dly, y_pipe;

always_ff @(posedge clk) if (reset) begin
	ybuf <= '0;
	y_dly <= 16'sd0;
	y_pipe <= 16'sd0;
end else if (ce) begin
	ybuf  <= {ybuf[14:0], y_pk};
	y_dly <= $signed(ybuf[luma_delay]);
	y_pipe <= y_dly;
end

// Chroma delayed to stay beside the band-limited luma.
logic signed [17:0] i_al, q_al;
generate
	if (ALIGN_DLY > 0) begin : chroma_wait
		logic [ALIGN_DLY-1:0][17:0] ibuf_al, qbuf_al;
		always_ff @(posedge clk) if (reset) begin
			ibuf_al <= '0;
			qbuf_al <= '0;
		end else if (ce) begin
			ibuf_al <= {ibuf_al[ALIGN_DLY-2:0], i_sm};
			qbuf_al <= {qbuf_al[ALIGN_DLY-2:0], q_sm};
		end
		assign i_al = $signed(ibuf_al[ALIGN_DLY-1]);
		assign q_al = $signed(qbuf_al[ALIGN_DLY-1]);
	end else begin : chroma_direct
		assign i_al = i_sm;
		assign q_al = q_sm;
	end
endgenerate

logic signed [17:0] y8, i8, q8;

/* verilator lint_off UNUSEDSIGNAL */

logic signed [15:0] y_min, y_min_frame, stretch;
logic vb_q;
wire signed [15:0] stretch_amt = black_stretch == 2'd1 ? (y_min_frame >>> 2) :
                                 black_stretch == 2'd2 ? (y_min_frame >>> 1) :
                                 black_stretch == 2'd3 ? (y_min_frame - (y_min_frame >>> 2)) : 16'sd0;

wire signed [16:0] y_sub = y_pipe + brightness - stretch;
wire signed [18:0] lg    = $signed({3'b0, contrast});
wire signed [35:0] y8_m  = y_sub * lg;
wire signed [35:0] i8_m  = i_al  * $signed({1'b0, contrast});
wire signed [35:0] q8_m  = q_al  * $signed({1'b0, contrast});
/* verilator lint_on UNUSEDSIGNAL */

always_ff @(posedge clk) if (reset) begin
	y8 <= 18'sd0;
	i8 <= 18'sd0;
	q8 <= 18'sd0;
end else if (ce) begin
	y8 <= y8_m[33:16];
	i8 <= i8_m[33:16];
	q8 <= q8_m[33:16];
end

wire signed [27:0] y_sh  = {{2{y8[17]}}, y8, 8'd0};
wire signed [27:0] r_mix = y_sh + (i8 * MAT_RI + q8 * MAT_RQ);
wire signed [27:0] g_mix = y_sh + (i8 * MAT_GI + q8 * MAT_GQ);
wire signed [27:0] b_mix = y_sh + (i8 * MAT_BI + q8 * MAT_BQ);

/* verilator lint_off UNUSEDSIGNAL */
function automatic [7:0] clamp8(input signed [27:0] v);
	logic signed [19:0] s;
	s = v[27:8];
	if      (s > 20'sd255) clamp8 = 8'd255;
	else if (s < 20'sd0)   clamp8 = 8'd0;
	else                   clamp8 = s[7:0];
endfunction
/* verilator lint_on UNUSEDSIGNAL */

localparam LAT = 7 + ALIGN_DLY;
logic [LAT-1:0] hs_p, vs_p, hb_p, vb_p;

logic [4:0] act_cnt;
always_ff @(posedge clk) if (reset) begin
	y_min <= 16'sd32767;
	y_min_frame <= 16'sd0;
	stretch <= 16'sd0;
	vb_q <= 1'b0;
	act_cnt <= 5'd0;
end else if (ce) begin
	vb_q <= vb_p[LAT-2];
	act_cnt <= hb_p[LAT-2] ? 5'd0 : (&act_cnt ? act_cnt : act_cnt + 5'd1);
	if (vb_p[LAT-2] && !vb_q) begin
		y_min_frame <= (y_min > 16'sd0) ? y_min : 16'sd0;
		y_min <= 16'sd32767;
	end else if (&act_cnt && !hb_p[LAT-6] && !vb_p[LAT-2] && y_pipe < y_min) begin
		y_min <= y_pipe;
	end
	stretch <= stretch_amt;
end

always_ff @(posedge clk) begin
	if (reset) begin
		ce_out <= 1'b0;
		hs_p <= '0;
		vs_p <= '0;
		hb_p <= '0;
		vb_p <= '0;
		hs_out <= 1'b0;
		vs_out <= 1'b0;
		hb_out <= 1'b0;
		vb_out <= 1'b0;
		r_out <= 8'd0;
		g_out <= 8'd0;
		b_out <= 8'd0;
	end else begin
		ce_out <= ce;
		if (ce) begin
			hs_p <= {hs_p[LAT-2:0], hs_i};
			vs_p <= {vs_p[LAT-2:0], vs_i};
			hb_p <= {hb_p[LAT-2:0], hb_i};
			vb_p <= {vb_p[LAT-2:0], vb_i};

			hs_out <= hs_p[LAT-1];
			vs_out <= vs_p[LAT-1];
			hb_out <= hb_p[LAT-1];
			vb_out <= vb_p[LAT-1];

			r_out <= clamp8(r_mix);
			g_out <= clamp8(g_mix);
			b_out <= clamp8(b_mix);
		end
	end
end

logic [7:0] pix_cnt;
logic hs_q;

always_ff @(posedge clk) if (reset) begin
	pix_cnt <= 8'd0;
	hs_q <= 1'b0;
	pix_out <= 1'b0;
end else begin
	pix_out <= 1'b0;
	if (ce_out) begin
		hs_q <= hs_out;
		pix_cnt <= (hs_out && !hs_q) ? 8'd0 : pix_cnt + 8'd1;
		pix_out <= (pix_cnt & 8'(PIX_DIV - 1)) == 8'(PIX_DIV - 1);
	end
end

endmodule
