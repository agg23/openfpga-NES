// NES Famicom Keyboard
// Jun, 24 2022

module keyboard (
	input        clk,
	input        reset,
	input        posit,
	input [10:0] ps2_key,
	input  [2:0] reg_4016,
	output reg  [3:0] reg_4017
);


wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];

reg btn_f1 = 0;
reg btn_f2 = 0;
reg btn_f3 = 0;
reg btn_f4 = 0;
reg btn_f5 = 0;
reg btn_f6 = 0;
reg btn_f7 = 0;
reg btn_f8 = 0;

reg btn_1 = 0;
reg btn_2 = 0;
reg btn_3 = 0;
reg btn_4 = 0;
reg btn_5 = 0;
reg btn_6 = 0;
reg btn_7 = 0;
reg btn_8 = 0;
reg btn_9 = 0;
reg btn_0 = 0;
reg btn_ds = 0;
reg btn_ca = 0;
reg btn_ye = 0;
reg btn_st = 0;

reg btn_es = 0;
reg btn_q = 0;
reg btn_w = 0;
reg btn_e = 0;
reg btn_r = 0;
reg btn_t = 0;
reg btn_y = 0;
reg btn_u = 0;
reg btn_i = 0;
reg btn_o = 0;
reg btn_p = 0;
reg btn_at = 0;
reg btn_lb = 0;
reg btn_rt = 0;
			
reg btn_ct = 0;
reg btn_a = 0;
reg btn_s = 0;
reg btn_d = 0;
reg btn_f = 0;
reg btn_g = 0;
reg btn_h = 0;
reg btn_j = 0;
reg btn_k = 0;
reg btn_l = 0;
reg btn_se = 0;
reg btn_cn = 0;
reg btn_rb = 0;
reg btn_ka = 0;
			
reg btn_ls = 0;
reg btn_z = 0;
reg btn_x = 0;
reg btn_c = 0;
reg btn_v = 0;
reg btn_b = 0;
reg btn_n = 0;
reg btn_m = 0;
reg btn_co = 0;
reg btn_pe = 0;
reg btn_fs = 0;
reg btn_un = 0;
reg btn_rs = 0;

reg btn_gr = 0;
reg btn_sp = 0;

reg btn_cl = 0;
reg btn_in = 0;
reg btn_de = 0;

reg btn_up    = 0;
reg btn_down  = 0;
reg btn_left  = 0;
reg btn_right = 0;

logic [7:0] keys [9];

assign keys = '{{btn_rb,   btn_lb,    btn_rt, btn_f8, btn_st, btn_ye, btn_rs,  btn_ka},
               {btn_se,   btn_cn,    btn_at, btn_f7, btn_ca, btn_ds, btn_fs,  btn_un},
               {btn_k,    btn_l,     btn_o,  btn_f6, btn_0,  btn_p,  btn_co,  btn_pe},
               {btn_j,    btn_u,     btn_i,  btn_f5, btn_8,  btn_9,  btn_n,   btn_m},
               {btn_h,    btn_g,     btn_y,  btn_f4, btn_6,  btn_7,  btn_v,   btn_b},
               {btn_d,    btn_r,     btn_t,  btn_f3, btn_4,  btn_5,  btn_c,   btn_f},
               {btn_a,    btn_s,     btn_w,  btn_f2, btn_3,  btn_e,  btn_z,   btn_x},
               {btn_ct,   btn_q,     btn_es, btn_f1, btn_2,  btn_1,  btn_gr,  btn_ls},
               {btn_left, btn_right, btn_up, btn_cl, btn_in, btn_de, btn_sp,  btn_down}};
//Column 0												Column 1
//$4017 bit	4   	3   	2     	1       	4   	3  	2     	1
//Row   0	]  	[    	RETURN	F8      	STOP	¥  	RSHIFT	KANA
//Row   1	;  	:    	@     	F7      	^   	-  	/     	_
//Row   2	K   	L   	O     	F6      	0   	P  	,     	.
//Row   3	J   	U    	I     	F5      	8   	9  	N     	M
//Row   4	H   	G   	Y     	F4      	6   	7  	V     	B
//Row   5	D   	R   	T     	F3      	4   	5  	C     	F
//Row   6	A   	S    	W     	F2      	3   	E  	Z     	X
//Row   7	CTR	Q    	ESC   	F1      	2   	1  	GRPH  	LSHIFT
//Row   8	LEFT	RIGHT	UP    	CLR HOME	INS 	DEL	SPACE 	DOWN
			
reg [3:0] row;
reg old_state;
reg last_col;
	
wire [7:0] rowvals = (row >= 4'd9) ? 8'd0 : keys[row];
wire [3:0] regvals = reg_4016[1] ? rowvals[3:0] : rowvals[7:4];  

always @(posedge clk) begin

	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up    <= pressed;
			'hX72: btn_down  <= pressed;
			'hX6B: btn_left  <= pressed;
			'hX74: btn_right <= pressed;
			'hX6C: btn_cl    <= pressed; // clr home
			'hX70: btn_in    <= pressed; // ins
			'hX71: btn_de    <= pressed; // del

			'hX05: btn_f1    <= pressed; // 1
			'hX06: btn_f2    <= pressed; // 2
			'hX04: btn_f3    <= pressed; // 3
			'hX0C: btn_f4    <= pressed; // 4
			'hX03: btn_f5    <= pressed; // 5
			'hX0B: btn_f6    <= pressed; // 6
			'hX83: btn_f7    <= pressed; // 7
			'hX0A: btn_f8    <= pressed; // 8

			'hX16: btn_1     <= pressed; // 1
			'hX1E: btn_2     <= pressed; // 2
			'hX26: btn_3     <= pressed; // 3
			'hX25: btn_4     <= pressed; // 4
			'hX2E: btn_5     <= pressed; // 5
			'hX36: btn_6     <= pressed; // 6
			'hX3D: btn_7     <= pressed; // 7
			'hX3E: btn_8     <= pressed; // 8
			'hX46: btn_9     <= pressed; // 9
			'hX45: btn_0     <= pressed; // 0
			'hX4E: btn_ds    <= pressed; // -
			'hX55: btn_ca    <= pressed; // = => ^
			'hX5D: btn_ye    <= pressed; // \ => yen
			'hX66: btn_st    <= pressed; // <- => stop

			'hX0D: btn_es    <= pressed; // tab => esc
			'hX15: btn_q     <= pressed; // q
			'hX1D: btn_w     <= pressed; // w
			'hX24: btn_e     <= pressed; // e
			'hX2D: btn_r     <= pressed; // r
			'hX2C: btn_t     <= pressed; // t
			'hX35: btn_y     <= pressed; // y
			'hX3C: btn_u     <= pressed; // u
			'hX43: btn_i     <= pressed; // i
			'hX44: btn_o     <= pressed; // o
			'hX4D: btn_p     <= pressed; // p
			'hX76: btn_at    <= pressed; // esc => @ not positional
			'hX54: btn_fs    <= pressed; // [ => /
			'hX5B: btn_rb    <= pressed; // ] => ] not positional
			
			'hX58: btn_ct    <= pressed; // caps => ctr
			'hX1C: btn_a     <= pressed; // a
			'hX1B: btn_s     <= pressed; // s
			'hX23: btn_d     <= pressed; // d
			'hX2B: btn_f     <= pressed; // f
			'hX34: btn_g     <= pressed; // g
			'hX33: btn_h     <= pressed; // h
			'hX3B: btn_j     <= pressed; // j
			'hX42: btn_k     <= pressed; // k
			'hX4B: btn_l     <= pressed; // l
			'hX4C: btn_se    <= pressed; // ;
			'hX52: btn_cn    <= pressed; // ' => :
			'hX14: btn_ka    <= pressed; // lctrl => katana not positional
			'hX5A: btn_rt    <= pressed; // enter (ret)
			
			'hX12: btn_ls    <= pressed; // lshift
			'hX1A: btn_z     <= pressed; // z
			'hX22: btn_x     <= pressed; // x
			'hX21: btn_c     <= pressed; // c
			'hX2A: btn_v     <= pressed; // v
			'hX32: btn_b     <= pressed; // b
			'hX31: btn_n     <= pressed; // n
			'hX3A: btn_m     <= pressed; // m
			'hX41: btn_co    <= pressed; // ,
			'hX49: btn_pe    <= pressed; // .
			'hx4A: btn_fs    <= pressed; // /
			'hX0E: btn_un    <= pressed; // ` => underscore not positional
			'hX59: btn_rs    <= pressed; // rshift

			'hX11: btn_gr    <= pressed; // lalt => graph
			'hX29: btn_sp    <= pressed; // space
		endcase
	end

			
	if (reset) begin
		row <= 0;
		last_col <= 0;
	end else begin
		last_col <= reg_4016[1];
		if (!reg_4016[1] && last_col)
			row <= (row == 4'd9) ? 4'd0 : row + 1'd1;
		if (reg_4016[0])
			row <= 4'd0;
		reg_4017 <= reg_4016[2] ? ~regvals : 4'd0;
	end
end

endmodule

