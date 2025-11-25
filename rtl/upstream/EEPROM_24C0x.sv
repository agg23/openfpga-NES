// 24C01, 24C02 EEPROM support
// by GreyRogue for NES MiSTer

module EEPROM_24C0x
(
	// Replace type_24C01 with EEPROM size and command size (Test State y/n and address bytes)?
	input             type_24C01,          // 24C01 is 128 bytes/no Test State?, 24C02 is 256 bytes/Test State
	input      [ 3:0] page_mask,           // Typically 0x3, 0x7, or 0xF; semi-correlated with size
	input             no_test_state,       // No control word (ID check/upper address bits); Usually only for X24C01
	input             address_write_only,  // Some models only set address in write mode (24C0xA?)
	input             clk,
	input             ce,
	input             reset,
	input             SCL,                 // Serial Clock
	input             SDA_in,              // Serial Data (same pin as below, split for convenience)
	output reg        SDA_out,             // Serial Data (same pin as above, split for convenience)
	input      [ 2:0] E_id,                // Chip Enable ID
	input             WC_n,                // ~Write Control
	input      [ 7:0] data_from_ram,       // Data read from RAM
	output     [ 7:0] data_to_ram,         // Data written to RAM
	output     [ 7:0] ram_addr,            // RAM Address
	output reg        ram_read,            // RAM read
	output reg        ram_write,           // RAM write
	input             ram_done,            // RAM access done
	// savestates
	input      [63:0] SaveStateBus_Din,
	input      [ 9:0] SaveStateBus_Adr,
	input             SaveStateBus_wren,
	input             SaveStateBus_rst,
	input             SaveStateBus_load,
	output     [63:0] SaveStateBus_Dout
);

typedef enum bit [2:0] {
	STATE_STANDBY,
	STATE_TEST,
	STATE_ADDRESS,
	STATE_WRITE,
	STATE_READ
} mystate;
mystate state;

reg [9:0] command;
reg [7:0] address;
reg [8:0] data;  // 8 bits data, plus ack bit
reg last_SCL;
reg last_SDA;
reg read_next;
// Some X24C0x documents show it working with a test state, instead of combined address/read/write.
// wire no_test_state = type_24C01;

always @(posedge clk) if (reset) begin
	state <= STATE_STANDBY;
	command <= 0;
	last_SCL <= 0;
	last_SDA <= 0;
	SDA_out <= 1;  // NoAck
	ram_read <= 0;
	ram_write <= 0;
	read_next <= 0;
end else if (SaveStateBus_load) begin
	case (SS_MAP1[2:0])
		0: state <= STATE_STANDBY;
		1: state <= STATE_TEST;
		2: state <= STATE_ADDRESS;
		3: state <= STATE_WRITE;
		4: state <= STATE_READ;
	endcase
	command   <= SS_MAP1[12: 3];
	last_SCL  <= SS_MAP1[   13];
	last_SDA  <= SS_MAP1[   14];
	SDA_out   <= SS_MAP1[   15];
	ram_read  <= SS_MAP1[   16];
	ram_write <= SS_MAP1[   17];
	data      <= SS_MAP1[26:18];
	address   <= SS_MAP1[34:27];
	read_next <= SS_MAP1[   35];
end else if (ce) begin
	last_SCL <= SCL;
	last_SDA <= SDA_in;
	if (ram_write && ram_done) begin
		ram_write <= 0;
		// address[3:0] <= (address[3:0] & ~page_mask) | (page_mask & (address[3:0] + 4'h1)); //Increment wraps at 4/8/16 byte boundary
		// Alternate for line above:
		address[3:0] <= address[3:0] + 4'h1;  // Wrap at 4/8/16 byte boundary
		if (!page_mask[2]) begin
			address[2] <= address[2];  // Put back; Increment wraps at 4 byte boundary   : mask = 0x3
		end
		if (!page_mask[3]) begin
			address[3] <= address[3];  // Put back; Increment wraps at 4/8 byte boundary : mask = 0x3 or 0x7
		end
	end
	if (ram_read && ram_done) begin
		ram_read <= 0;
		data <= {data_from_ram, 1'b1};  // NoAck at end
	end
	if (SCL && last_SCL && !SDA_in && last_SDA) begin
		if (no_test_state) state <= STATE_ADDRESS;
		else state <= STATE_TEST;
		command <= 10'd2;
	end else if (SCL && last_SCL && SDA_in && !last_SDA) begin
		state   <= STATE_STANDBY;
		command <= 10'd0;
	end else if (state == STATE_STANDBY) begin
		// Do nothing
	end else if (SCL && !last_SCL) begin
		command <= {command[8:0], SDA_in};
	end else if (!SCL && last_SCL) begin
		SDA_out <= 1;  //NoAck
		if (state == STATE_READ) begin
			SDA_out <= data[8];
			if (!ram_read) begin
				data[8:1] <= data[7:0];
			end
		end
		if (command[9]) begin
			if (state == STATE_TEST) begin
				if (command[7:1] == {4'b1010, E_id}) begin
					if (command[0]) begin
						if (address_write_only) begin
							state <= STATE_READ;
							ram_read <= 1;
						end else begin
							state <= STATE_ADDRESS;
						end
						read_next <= 1;
					end else begin
						state <= STATE_ADDRESS;
						read_next <= 0;
					end
					SDA_out <= 0;  //Ack
				end
				command <= 10'd1;
			end else if (state == STATE_ADDRESS) begin
				if (type_24C01) begin
					address <= {1'b0, command[7:1]};
					if (command[0]) begin
						state <= STATE_READ;
						ram_read <= 1;
					end else begin
						state <= STATE_WRITE;
					end
				end else begin
					address <= command[7:0];
					if (read_next & !address_write_only) begin
						state <= STATE_READ;
						ram_read <= 1;
					end else begin
						state <= STATE_WRITE;
					end
				end
				SDA_out <= 0;  //Ack
				command <= 10'd1;
			end else if (state == STATE_WRITE) begin
				data <= {command[7:0], 1'b0};
				if (!WC_n) begin
					ram_write <= 1;
					SDA_out   <= 0;  //Ack
				end
				command <= 10'd1;
			end else if (state == STATE_READ) begin
				ram_read <= 1;
				SDA_out  <= 1;  //NoAck
				address  <= address + 8'b1;
				command  <= 10'd1;
			end
		end
	end
end

assign ram_addr = (type_24C01 == 1) ? {1'b0, address[6:0]} : address;
assign data_to_ram = data[8:1];

// savestate
assign SS_MAP1_BACK[ 2: 0] = (state == STATE_STANDBY)  ? 3'd0 :
							 (state == STATE_TEST)     ? 3'd1 :
							 (state == STATE_ADDRESS)  ? 3'd2 :
							 (state == STATE_WRITE)    ? 3'd3 :
														 3'd4;
assign SS_MAP1_BACK[12: 3] = command;
assign SS_MAP1_BACK[   13] = last_SCL;
assign SS_MAP1_BACK[   14] = last_SDA;
assign SS_MAP1_BACK[   15] = SDA_out;
assign SS_MAP1_BACK[   16] = ram_read;
assign SS_MAP1_BACK[   17] = ram_write;
assign SS_MAP1_BACK[26:18] = data;
assign SS_MAP1_BACK[34:27] = address;
assign SS_MAP1_BACK[   35] = read_next;
assign SS_MAP1_BACK[63:36] = 28'b0;  // free to be used

wire [63:0] SS_MAP1;
wire [63:0] SS_MAP1_BACK;
eReg_SavestateV #(SSREG_INDEX_L2MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (
		clk,
		SaveStateBus_Din,
		SaveStateBus_Adr,
		SaveStateBus_wren,
		SaveStateBus_rst,
		SaveStateBus_Dout,
		SS_MAP1_BACK,
		SS_MAP1
);

endmodule
