//
// sdram.v
// This version issues refresh only when 8bit channel reads the same 16bit word 2 times
//
// sdram controller implementation
// Copyright (c) 2018 Sorgelig
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
//

module sdram
(

	// interface to the MT48LC16M16 chip
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // byte mask
	output reg        SDRAM_DQMH, // byte mask
	output reg  [1:0] SDRAM_BA,   // two banks
	output reg        SDRAM_nCS,  // a single chip select
	output reg        SDRAM_nWE,  // write enable
	output reg        SDRAM_nRAS, // row address select
	output reg        SDRAM_nCAS, // columns address select
	output            SDRAM_CLK,
	output            SDRAM_CKE,

	// cpu/chipset interface
	input             init,			// init signal after FPGA config to initialize RAM
	input             clk,			// sdram is accessed at up to 128MHz

	input      [24:0] ch0_addr,
	input             ch0_rd,
	input             ch0_wr,
	input       [7:0] ch0_din,
	output reg  [7:0] ch0_dout,
	output reg        ch0_busy,

	input      [24:0] ch1_addr,
	input             ch1_rd,
	input             ch1_wr,
	input       [7:0] ch1_din,
	output reg  [7:0] ch1_dout,
	output reg        ch1_busy,

	input      [24:0] ch2_addr,
	input             ch2_rd,
	input             ch2_wr,
	input       [7:0] ch2_din,
	output reg  [7:0] ch2_dout,
	output reg        ch2_busy,
	
	input             refresh,
	input      [15:0] ss_in,
	input             ss_load,
	output     [15:0] ss_out
);

assign SDRAM_nCS = 0;
assign SDRAM_CKE = 1;
assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];

localparam RASCAS_DELAY   = 3'd1; // tRCD=20ns -> 2 cycles@85MHz
localparam BURST_LENGTH   = 3'd0; // 0=1, 1=2, 2=4, 3=8, 7=full page
localparam ACCESS_TYPE    = 1'd0; // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2; // 2/3 allowed
localparam OP_MODE        = 2'd0; // only 0 (standard operation) allowed
localparam NO_WRITE_BURST = 1'd1; // 0=write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

localparam STATE_IDLE  = 3'd0;             // state to check the requests
localparam STATE_START = STATE_IDLE+1'd1;  // state in which a new command is started
localparam STATE_NEXT  = STATE_START+1'd1; // state in which a new command is started
localparam STATE_CONT  = STATE_START+RASCAS_DELAY;
localparam STATE_READY = STATE_CONT+CAS_LATENCY+2'd2;
localparam STATE_LAST  = STATE_READY;      // last state in cycle

reg  [2:0] state;
reg [22:0] a;
reg  [1:0] bank;
reg [15:0] data;
reg        we;
reg        ram_req=0;

wire [2:0] rd,wr;

assign rd = {ch2_rd, ch1_rd, ch0_rd};
assign wr = {ch2_wr, ch1_wr, ch0_wr};

// access manager
always @(posedge clk) begin
	reg old_ref;
	reg  [2:0] old_rd,old_wr;//,rd,wr;
	reg [24:1] last_a[3] = '{'1,'1,'1};

	old_rd <= old_rd & rd;
	old_wr <= old_wr & wr;

	if(state == STATE_IDLE && mode == MODE_NORMAL) begin
		ram_req <= 0;
		we <= 0;
		ch0_busy <= 0;
		ch1_busy <= 0;
		ch2_busy <= 0;
		if((~old_rd[0] & rd[0]) | (~old_wr[0] & wr[0])) begin
			old_rd[0] <= rd[0];
			old_wr[0] <= wr[0];
			we <= wr[0];
			{bank,a} <= ch0_addr;
			data <= {ch0_din,ch0_din};
			ram_req <= wr[0] || (last_a[0] != ch0_addr[24:1]);
			last_a[0] <= wr[0] ? '1 : ch0_addr[24:1];
			ch0_busy <= 1;
			state <= STATE_START;
		end
		else if((~old_rd[1] & rd[1]) | (~old_wr[1] & wr[1])) begin
			old_rd[1] <= rd[1];
			old_wr[1] <= wr[1];
			we <= wr[1];
			{bank,a} <= ch1_addr;
			data <= {ch1_din,ch1_din};
			ram_req <= wr[1] || (last_a[1] != ch1_addr[24:1]);
			last_a[1] <= wr[1] ? '1 : ch1_addr[24:1];
			ch1_busy <= 1;
			state <= STATE_START;
		end
		else if((~old_rd[2] & rd[2]) | (~old_wr[2] & wr[2])) begin
			old_rd[2] <= rd[2];
			old_wr[2] <= wr[2];
			we <= wr[2];
			{bank,a} <= ch2_addr;
			data <= {ch2_din,ch2_din};
			ram_req <= wr[2] || (last_a[2] != ch2_addr[24:1]);
			last_a[2] <= wr[2] ? '1 : ch2_addr[24:1];
			ch2_busy <= 1;
			state <= STATE_START;
		end
		else if (refresh) begin
			ram_req <= 1'b0;
			we      <= 1'b0;
			state   <= STATE_START;
		end
	end

	if (state == STATE_READY) begin
		ch0_busy <= 0;
		ch1_busy <= 0;
		ch2_busy <= 0;
	end

	if(mode != MODE_NORMAL || state != STATE_IDLE || reset) begin
		state <= state + 1'd1;
		if(state == STATE_LAST) state <= STATE_IDLE;
	end
end

localparam MODE_NORMAL = 2'b00;
localparam MODE_RESET  = 2'b01;
localparam MODE_LDM    = 2'b10;
localparam MODE_PRE    = 2'b11;

// initialization 
reg [1:0] mode;
reg [4:0] reset=5'h1f;
always @(posedge clk) begin
	reg init_old=0;
	init_old <= init;

	if(init_old & ~init) reset <= 5'h1f;
	else if(state == STATE_LAST) begin
		if(reset != 0) begin
			reset <= reset - 5'd1;
			if(reset == 14)     mode <= MODE_PRE;
			else if(reset == 3) mode <= MODE_LDM;
			else                mode <= MODE_RESET;
		end
		else mode <= MODE_NORMAL;
	end
end

localparam CMD_NOP             = 3'b111;
localparam CMD_ACTIVE          = 3'b011;
localparam CMD_READ            = 3'b101;
localparam CMD_WRITE           = 3'b100;
localparam CMD_BURST_TERMINATE = 3'b110;
localparam CMD_PRECHARGE       = 3'b010;
localparam CMD_AUTO_REFRESH    = 3'b001;
localparam CMD_LOAD_MODE       = 3'b000;

wire [1:0] dqm = {we & ~a[0], we & a[0]};

// SDRAM state machines
always @(posedge clk) begin
	reg [15:0] last_data[3];
	reg [15:0] data_reg;

	if(state == STATE_START) SDRAM_BA <= (mode == MODE_NORMAL) ? bank : 2'b00;

	SDRAM_DQ <= 'Z;
	casex({ram_req,we,mode,state})
		{2'b1X, MODE_NORMAL, STATE_START}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACTIVE;
		{2'b11, MODE_NORMAL, STATE_CONT }: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_DQ} <= {CMD_WRITE, data};
		{2'b10, MODE_NORMAL, STATE_CONT }: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_READ;
		{2'b0X, MODE_NORMAL, STATE_START}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_AUTO_REFRESH;

		// init
		{2'bXX,    MODE_LDM, STATE_START}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_LOAD_MODE;
		{2'bXX,    MODE_PRE, STATE_START}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRECHARGE;

		                          default: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
	endcase

	casex({ram_req,mode,state})
		{1'b1,  MODE_NORMAL, STATE_START}: SDRAM_A <= a[13:1];
		{1'b1,  MODE_NORMAL, STATE_CONT }: SDRAM_A <= {dqm, 2'b10, a[22:14]};

		// init
		{1'bX,     MODE_LDM, STATE_START}: SDRAM_A <= MODE;
		{1'bX,     MODE_PRE, STATE_START}: SDRAM_A <= 13'b0010000000000;

		                          default: SDRAM_A <= 13'b0000000000000;
	endcase

	data_reg <= SDRAM_DQ;

	if(state == STATE_READY) begin
		if(ch0_busy) begin
			if(ram_req) begin
				if(we) ch0_dout <= data[7:0];
				else begin
					ch0_dout <= a[0] ? data_reg[15:8] : data_reg[7:0];
					last_data[0] <= data_reg;
				end
			end
			else ch0_dout <= a[0] ? last_data[0][15:8] : last_data[0][7:0];
		end
		if(ch1_busy) begin
			if(ram_req) begin
				if(we) ch1_dout <= data[7:0];
				else begin
					ch1_dout <= a[0] ? data_reg[15:8] : data_reg[7:0];
					last_data[1] <= data_reg;
				end
			end
			else ch1_dout <= a[0] ? last_data[1][15:8] : last_data[1][7:0];
		end
		if(ch2_busy) begin
			if(ram_req) begin
				if(we) ch2_dout <= data[7:0];
				else begin
					ch2_dout <= a[0] ? data_reg[15:8] : data_reg[7:0];
					last_data[2] <= data_reg;
				end
			end
			else ch2_dout <= a[0] ? last_data[2][15:8] : last_data[2][7:0];
		end
	end
	
	if (ss_load) begin
		ch0_dout <= ss_in[7:0];
		ch1_dout <= ss_in[15:8];
	end
end

assign ss_out = {ch1_dout, ch0_dout};


altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

endmodule
