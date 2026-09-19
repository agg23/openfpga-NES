module composite_board (
	input  wire               clk,
	input  wire               reset,
	input  wire signed [23:0] pin_a,      // Q2.21 volts, first half cycle
	input  wire signed [23:0] pin_b,      // second half cycle
	output reg  signed [23:0] rca_a,
	output reg  signed [23:0] rca_b
);

// Q1 emitter offset and module follower drop, Q2.21 volts.
localparam signed [25:0] VBE1 = 26'sd1637876;
localparam signed [25:0] VBE2 = 26'sd1363149;

// Discrete LC state update x' = A x + B u, signed Q16.
localparam signed [17:0] A00 = 18'sd6623;
localparam signed [17:0] A01 = -18'sd36773;
localparam signed [17:0] A10 = 18'sd36773;
localparam signed [17:0] A11 = 18'sd20213;
localparam signed [17:0] B0  = 18'sd36773;
localparam signed [17:0] B1  = 18'sd45323;

// RCA shunt with the series and termination resistors, one-pole step.
localparam signed [17:0] K_RCA = 18'sd65404;

// ---------------------------------------------------------------- Q1 follower

reg signed [25:0] u_a, u_b;

always @(posedge clk) begin
	if (reset) begin
		u_a <= 26'sd0;
		u_b <= 26'sd0;
	end else begin
		u_a <= {{2{pin_a[23]}}, pin_a} + VBE1;
		u_b <= {{2{pin_b[23]}}, pin_b} + VBE1;
	end
end

// ------------------------------------------------------------ bead and C5

function automatic signed [25:0] lc_row(input signed [17:0] ca, input signed [25:0] xa,
	input signed [17:0] cb, input signed [25:0] xb, input signed [17:0] cu, input signed [25:0] u);
	/* verilator lint_off UNUSEDSIGNAL */
	reg signed [45:0] acc;
	/* verilator lint_on UNUSEDSIGNAL */
	begin
		acc = ca * xa + cb * xb + cu * u;
		lc_row = acc[41:16];
	end
endfunction

reg signed [25:0] x0, x1;      // bead current (volt scaled), C5 voltage
reg signed [25:0] vc_a, vc_b;

wire signed [25:0] x0_mid = lc_row(A00, x0, A01, x1, B0, u_a);
wire signed [25:0] x1_mid = lc_row(A10, x0, A11, x1, B1, u_a);
wire signed [25:0] x0_end = lc_row(A00, x0_mid, A01, x1_mid, B0, u_b);
wire signed [25:0] x1_end = lc_row(A10, x0_mid, A11, x1_mid, B1, u_b);

always @(posedge clk) begin
	if (reset) begin
		x0 <= 26'sd0;
		x1 <= 26'sd0;
		vc_a <= 26'sd0;
		vc_b <= 26'sd0;
	end else begin
		x0 <= x0_end;
		x1 <= x1_end;
		vc_a <= x1_mid;
		vc_b <= x1_end;
	end
end

// ------------------------------------- module follower, series 75, RCA load

function automatic signed [25:0] rca_step(input signed [25:0] v, input signed [25:0] vc);
	reg signed [25:0] target;
	reg signed [26:0] diff;
	/* verilator lint_off UNUSEDSIGNAL */
	reg signed [44:0] step;
	reg signed [26:0] sum;
	/* verilator lint_on UNUSEDSIGNAL */
	begin
		target = (vc - VBE2) >>> 1;
		diff = {target[25], target} - {v[25], v};
		step = diff * K_RCA;
		sum = {v[25], v} + step[42:16];
		rca_step = sum[25:0];
	end
endfunction

function automatic signed [23:0] sat24(input signed [25:0] v);
	if      (v >  26'sd8388607) sat24 =  24'sd8388607;
	else if (v < -26'sd8388608) sat24 = 24'sh800000;
	else                        sat24 =  v[23:0];
endfunction

reg signed [25:0] v_rca;

wire signed [25:0] rca_mid = rca_step(v_rca, vc_a);
wire signed [25:0] rca_end = rca_step(rca_mid, vc_b);

always @(posedge clk) begin
	if (reset) begin
		v_rca <= 26'sd0;
		rca_a <= 24'sd0;
		rca_b <= 24'sd0;
	end else begin
		v_rca <= rca_end;
		rca_a <= sat24(rca_mid);
		rca_b <= sat24(rca_end);
	end
end

endmodule
