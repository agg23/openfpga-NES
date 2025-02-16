//Famicom Disk System

module MapperFDS(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// Special ports
	input [7:0] prg_dbus,     // For getting data during disk reads
	input [7:0] audio_dout,
	inout [1:0] diskside_b,
	input [1:0] max_diskside,
	input       fds_busy,
	input       fds_eject_btn,
	input       fds_auto_eject_en,
	input       fds_fast,

	// savestates
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign prg_aout_b      = enable ? prg_aout : 22'hZ;
assign prg_dout_b      = enable ? prg_dout : 8'hZ;
assign prg_allow_b     = enable ? prg_allow : 1'hZ;
assign chr_aout_b      = enable ? chr_aout : 22'hZ;
assign chr_allow_b     = enable ? chr_allow : 1'hZ;
assign vram_a10_b      = enable ? vram_a10 : 1'hZ;
assign vram_ce_b       = enable ? vram_ce : 1'hZ;
assign irq_b           = enable ? irq : 1'hZ;
assign flags_out_b     = enable ? flags_out : 16'hZ;
assign audio_b         = enable ? audio[15:0] : 16'hZ;
assign diskside_b      = enable ? diskside : 2'hZ;

wire [21:0] prg_addr, prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
wire [7:0] prg_dout;
wire [15:0] flags_out = {12'd0, 1'b1, 1'b0, prg_bus_write, 1'b0};
wire prg_bus_write;
wire irq;

wire [15:0] audio = audio_in;

reg fds_prg_bus_write;
wire fds_audio_prg_bus_write = (prg_ain >= 16'h4040 && prg_ain < 16'h4080) | (prg_ain >= 16'h4090 && prg_ain <= 16'h4097);
assign prg_bus_write = (fds_prg_bus_write | fds_audio_prg_bus_write);

reg vertical;

reg timer_irq;
reg timer_irq_en;
reg timer_irq_repeat;
reg [15:0] timerlatch;
reg [15:0] timer;

reg write_en;
reg diskreset;
reg disk_reg_en;
reg disk_irq_en;
reg motor_on;
reg byte_transfer_flag;
reg new_byte;
reg byte_transfer;
reg got_start_byte, got_start_byte_d;
reg after_pre_gap;
reg read_4030;
reg [19:0] transfer_cnt;
reg [15:0] byte_cnt;
reg [15:0] file_size;
reg [2:0] block_type;
reg block_end;

wire disk_eject;
reg disk_eject_auto, disk_eject_wait;
reg [1:0] diskside;
reg [15:0] diskpos;
reg [17:0] sideoffset;
wire [17:0] romoffset;
reg [4:0] read_4032_cnt;
reg [22:0] cpu_clk_cnt;
reg old_eject_btn;

reg read_disk_d, write_disk_d;
wire prg_disk_rd_reg = (prg_ain == 16'h4031);
wire prg_disk_wr_reg = (prg_ain == 16'h4024);
wire read_disk = (~prg_write & prg_disk_rd_reg);
wire write_disk = (prg_write & prg_disk_wr_reg & write_en & byte_transfer & got_start_byte_d & motor_on & ~diskreset & ~block_end);
wire disk_ready = (~disk_eject & ~diskreset & motor_on & ~diskend);
wire [7:0] disk_data = write_disk ? prg_din : prg_dbus;
wire disk_irq = (byte_transfer_flag & disk_irq_en);

// The FDS transfer rate is around 96.4kHz which is 10.37 microseconds per bit.
// The gap at the start of the disk is typically 28300 bits long and gaps between blocks 976 bits.
// A byte takes 82.99 microseconds which is around 149 CPU cycles.
// We can use shorter delays here.
localparam PRE_GAP_DELAY_FAST = 20'd65535;
localparam PRE_GAP_DELAY_ORIG = 20'd525420;
localparam BYTE_DELAY_FAST    = 20'd99;
localparam BYTE_DELAY_ORIG    = 20'd149;
localparam EJECT_DELAY        = 100 * 23'd29780;

wire [19:0] pre_gap_delay = fds_fast ? PRE_GAP_DELAY_FAST : PRE_GAP_DELAY_ORIG;
wire [19:0] byte_delay = fds_fast ? BYTE_DELAY_FAST : BYTE_DELAY_ORIG;

always@(posedge clk) begin
	if(~enable) begin
		diskside <= 0;
		timer_irq_en <= 0;
		timer_irq <= 0;
		disk_reg_en <= 0;
		disk_irq_en <= 0;
		write_en <= 0;
		byte_transfer <= 0;
		byte_transfer_flag <= 0;
		new_byte <= 0;
		got_start_byte <= 0;
		got_start_byte_d <= 0;
		after_pre_gap <= 0;
		read_4030 <= 0;
		byte_cnt <= 0;
		transfer_cnt <= 0;
		block_end <= 0;
		disk_eject_auto <= 0;
		disk_eject_wait <= 0;
		read_4032_cnt <= 0;
		cpu_clk_cnt <= 0;
		read_disk_d <= 0;
		write_disk_d <= 0;
	end else if (SaveStateBus_load) begin
		timer_irq_en       <= SS_MAP1[    0];
		timer_irq          <= SS_MAP1[    1];
		timer_irq_repeat   <= SS_MAP1[    2];
		timer              <= SS_MAP1[18: 3];
		timerlatch         <= SS_MAP1[34:19];
		disk_reg_en        <= SS_MAP1[   35];
		disk_irq_en        <= SS_MAP1[   36];
		byte_transfer_flag <= SS_MAP1[   37];
		byte_transfer      <= SS_MAP1[   38];
		got_start_byte     <= SS_MAP1[   39];
		got_start_byte_d   <= SS_MAP1[   40];
		motor_on           <= SS_MAP1[   41];
		diskreset          <= SS_MAP1[   42];
		write_en           <= SS_MAP1[   43];
		vertical           <= SS_MAP1[   44];
		new_byte           <= SS_MAP1[   45];
		byte_cnt           <= SS_MAP1[61:46];
		block_end          <= SS_MAP1[   62];
		after_pre_gap      <= SS_MAP1[   63];
		block_type         <= SS_MAP2[ 2: 0];
		transfer_cnt       <= SS_MAP2[22: 3];
		diskside           <= SS_MAP2[24:23];
		cpu_clk_cnt        <= SS_MAP2[47:25];
		disk_eject_auto    <= SS_MAP2[   48];
		disk_eject_wait    <= SS_MAP2[   49];
		read_4032_cnt      <= SS_MAP2[54:50];
		read_4030          <= SS_MAP2[   55];
		read_disk_d        <= SS_MAP2[   56];
		write_disk_d       <= SS_MAP2[   57];
		old_eject_btn      <= SS_MAP2[   58];
		diskpos            <= SS_MAP3[15: 0];
		file_size          <= SS_MAP3[31:16];
	end else begin

		if (ce) begin
			if (timer_irq_en) begin
				if (timer == 0) begin
					timer_irq <= 1;
					timer <= timerlatch;
					if (~timer_irq_repeat) begin
						timer_irq_en <= 0;
					end
				end else begin
					timer <= timer - 1'd1;
				end
			end

			if(prg_write) begin
				case(prg_ain)
					16'h4020: timerlatch[7:0] <= prg_din;

					16'h4021: timerlatch[15:8] <= prg_din;

					16'h4022: begin
						timer_irq_repeat <= prg_din[0];
						timer_irq_en <= prg_din[1] & disk_reg_en;

						if (prg_din[1] & disk_reg_en) begin
							timer <= timerlatch;
						end else begin
							timer_irq <= 0;
						end
					end

					16'h4023: begin
						disk_reg_en <= prg_din[0];
						if (~prg_din[0]) begin
							timer_irq_en <= 0;
							timer_irq <= 0;
						end
					end

					16'h4024: begin //disk data write
						byte_transfer_flag <= 0;
						if (write_en & byte_transfer & prg_din == 8'h80) begin
							got_start_byte <= 1;
						end
					end

					16'h4025: begin // disk control
						motor_on      <= prg_din[0];
						diskreset     <= prg_din[1];
						write_en      <= !prg_din[2];
						vertical      <= !prg_din[3];
						//crc_en        <= prg_din[4];
						byte_transfer <= prg_din[6];
						disk_irq_en   <= prg_din[7];

						if (~byte_transfer & prg_din[6]) begin // new transfer start
							byte_transfer_flag <= write_en;
							new_byte <= 0;
							got_start_byte <= 0;
							got_start_byte_d <= 0;
							byte_cnt <= 0;
							block_end <= 0;
							block_type <= 0;
							if (after_pre_gap) begin
								transfer_cnt <= 0;
							end
						end
					end

					16'h4027:   //powerpak extra: disk side
						if (fds_auto_eject_en)
							diskside <= prg_din[1:0];
				endcase
			end

			got_start_byte_d <= got_start_byte;


			// ---- Disk switching
			cpu_clk_cnt <= cpu_clk_cnt + 1'b1;

			if (~fds_auto_eject_en) begin
				old_eject_btn <= fds_eject_btn;
				if (~old_eject_btn & fds_eject_btn & ~write_en & ~fds_busy) begin
					diskside <= (max_diskside == diskside) ? 2'd0 : (diskside + 1'b1);
					disk_eject_auto <= 1; // Minimum eject time
					cpu_clk_cnt <= 0;
				end
			end

			if (fds_auto_eject_en) begin
				if (diskreset & ~fds_busy) begin // Diskreset is usually on when the game is waiting for disk swap
					if (~disk_eject_auto) begin
						if (prg_read & prg_ain == 16'h4032 & ~disk_eject_wait) begin
							read_4032_cnt <= read_4032_cnt + 1'b1;
						end

						if (read_4032_cnt == 5'd20) begin
							read_4032_cnt <= 0;
							disk_eject_auto <= 1;
							disk_eject_wait <= 1;
							cpu_clk_cnt <= 0;
						end
					 end
				end else begin
					disk_eject_auto <= 0;
					read_4032_cnt <= 0;
					disk_eject_wait <= 0;
					cpu_clk_cnt <= 0;
				end
			end

			if (cpu_clk_cnt == EJECT_DELAY) begin // Eject for a certain amount of frames
				cpu_clk_cnt <= 0;
				if (disk_eject_auto) begin
					disk_eject_auto <= 0;
				end else if (disk_eject_wait) begin // Wait a while after inserting the disk
					disk_eject_wait <= 0;
				end
			end


			// ---- Disk transfers
			if (prg_read & prg_ain == 16'h4030) begin
				read_4030 <= 1;
			end

			if (read_4030) begin
				timer_irq <= 0;
				byte_transfer_flag <= 0;
				read_4030 <= 0;
			end

			// For some reason the 2 CRC bytes at the end of every block
			// are missing from .fds files so we need to determine
			// where the block ends to prevent reads/writes overflowing.
			if ((read_disk & ~write_en) | write_disk) begin
				if (byte_cnt == 0) begin
					block_type <= disk_data[2:0];
				end

				if (block_type == 3) begin
					if (byte_cnt == 'h0D) file_size[ 7:0] <= disk_data;
					if (byte_cnt == 'h0E) file_size[15:8] <= disk_data;
				end
			end

			read_disk_d <= read_disk;
			write_disk_d <= write_disk;

			if (read_disk_d & byte_transfer_flag) begin
				byte_transfer_flag <= 0;
			end

			if ((read_disk_d & ~write_en) | write_disk_d) begin // Delayed to the next CE after a read/write.
				if (new_byte) begin
					new_byte <= 0;
					byte_cnt <= byte_cnt + 1'b1;
					if (~diskend & ~block_end) begin
						diskpos <= diskpos + 1'b1;
					end

					if (  (block_type == 1 && byte_cnt == 'h37)
						| (block_type == 2 && byte_cnt == 'h01)
						| (block_type == 3 && byte_cnt == 'h0F)
						| (block_type == 4 && byte_cnt == file_size) )
					begin
						block_end <= 1;
					end
				end
			end

			transfer_cnt <= transfer_cnt + 1'b1;
			if (~motor_on) begin
				transfer_cnt <= 0;
			end else if(diskreset) begin
				transfer_cnt <= 0;
				diskpos<=0;
				after_pre_gap <= 0;
			end else begin
				if (~after_pre_gap) begin
					if (transfer_cnt == pre_gap_delay) begin // Beginning of disk
						after_pre_gap <= 1;
						transfer_cnt <= 0;
					end
				end else if (transfer_cnt == byte_delay) begin
					transfer_cnt <= 0;
					if (byte_transfer & ~fds_busy) begin
						byte_transfer_flag <= 1;
						new_byte <= 1;
					end
				end
			end
		end
	end
end

assign SS_MAP1_BACK[    0] = timer_irq_en;
assign SS_MAP1_BACK[    1] = timer_irq;
assign SS_MAP1_BACK[    2] = timer_irq_repeat;
assign SS_MAP1_BACK[18: 3] = timer;
assign SS_MAP1_BACK[34:19] = timerlatch;
assign SS_MAP1_BACK[   35] = disk_reg_en;
assign SS_MAP1_BACK[   36] = disk_irq_en;
assign SS_MAP1_BACK[   37] = byte_transfer_flag;
assign SS_MAP1_BACK[   38] = byte_transfer;
assign SS_MAP1_BACK[   39] = got_start_byte;
assign SS_MAP1_BACK[   40] = got_start_byte_d;
assign SS_MAP1_BACK[   41] = motor_on;
assign SS_MAP1_BACK[   42] = diskreset;
assign SS_MAP1_BACK[   43] = write_en;
assign SS_MAP1_BACK[   44] = vertical;
assign SS_MAP1_BACK[   45] = new_byte;
assign SS_MAP1_BACK[61:46] = byte_cnt;
assign SS_MAP1_BACK[   62] = block_end;
assign SS_MAP1_BACK[   63] = after_pre_gap;

assign SS_MAP2_BACK[ 2: 0] = block_type;
assign SS_MAP2_BACK[22: 3] = transfer_cnt;
assign SS_MAP2_BACK[24:23] = diskside;
assign SS_MAP2_BACK[47:25] = cpu_clk_cnt;
assign SS_MAP2_BACK[   48] = disk_eject_auto;
assign SS_MAP2_BACK[   49] = disk_eject_wait;
assign SS_MAP2_BACK[54:50] = read_4032_cnt;
assign SS_MAP2_BACK[   55] = read_4030;
assign SS_MAP2_BACK[   56] = read_disk_d;
assign SS_MAP2_BACK[   57] = write_disk_d;
assign SS_MAP2_BACK[   58] = old_eject_btn;
assign SS_MAP2_BACK[63:59] = 0;

assign SS_MAP3_BACK[15: 0] = diskpos;
assign SS_MAP3_BACK[31:16] = file_size;
assign SS_MAP3_BACK[63:32] = 0;


// Loopy's patched bios use a trick to catch requested diskside for games
// using standard bios load process.
// Unlicensed games sometimes doesn't use standard bios load process. This
// break automatic diskside trick.
// diskside_manual to be manage from OSD user input allow to add diskswap capabilities.
// (automatic fds_eject should be preferably stopped before changing diskside_manual)

wire diskend=(diskpos==65499);
always@* case(diskside) //16+65500*diskside
	0:sideoffset=18'h00010;
	1:sideoffset=18'h0ffec;
	2:sideoffset=18'h1ffc8;
	3:sideoffset=18'h2ffa4;
endcase
assign romoffset=diskpos + sideoffset;


// BIOS patches
localparam BIOS_PATCHES_CNT = 33;
wire [23:0] BIOS_PATCHES[BIOS_PATCHES_CNT] = '{
	// Wait for button press before loading disk
	'hEEE2_09,                       // Don't branch here otherwise no music

	'hEF33_20, 'hEF34_CC, 'hEF35_F4, // JSR $F4CC
	'hEF36_29, 'hEF37_F0,            // AND #$F0
	'hEF38_F0, 'hEF39_B0,            // BEQ $EEEA

	'hF4CC_20, 'hF4CD_EB, 'hF4CE_E9, // JSR $E9EB (ReadCtrls)
	'hF4CF_A5, 'hF4D0_F5,            // LDA $F5
	'hF4D1_05, 'hF4D2_F4,            // ORA $F4
	'hF4D3_85, 'hF4D4_F4,            // STA $F4
	'hF4D5_60,                       // RTS

	// Store diskside to $4027
	'hE445_20, 'hE446_D6, 'hE447_F4, // JSR $F4D6

	'hF4D6_A0, 'hF4D7_06,            // LDY #$06
	'hF4D8_B1, 'hF4D9_00,            // LDA ($00),Y
	'hF4DA_30, 'hF4DB_03,            // BMI $F4DF
	'hF4DC_8D, 'hF4DD_27, 'hF4DE_40, // STA $4027
	'hF4DF_4C, 'hF4E0_E3, 'hF4E1_E6  // JMP $E6E3 (StartXfer)
};

localparam BIOS_PATCHES2_CNT = 18;
wire [23:0] BIOS_PATCHES2[BIOS_PATCHES2_CNT] = '{
	// Remove some delays
	//'hE652_EA, 'hE653_EA, 'hE654_EA, // NOP <- This delay is needed for SMB2J Level 4-4 end
	'hE655_EA, 'hE656_EA, 'hE657_EA,
	'hE65D_EA, 'hE65E_EA, 'hE65F_EA,
	'hE691_EA, 'hE692_EA, 'hE693_EA,
	'hE6BB_EA, 'hE6BC_EA, 'hE6BD_EA,
	'hE6E8_EA, 'hE6E9_EA, 'hE6EA_EA,
	'hE6ED_EA, 'hE6EE_EA, 'hE6EF_EA
};

reg [7:0] patch_data;
reg bios_patch1_found, bios_patch2_found;
integer i;
always @* begin
	bios_patch1_found = 0;
	bios_patch2_found = 0;
	patch_data = 0;
	for (i = 0; i < BIOS_PATCHES_CNT; i=i+1) begin
		if (BIOS_PATCHES[i][23:8] == prg_ain) begin
			patch_data = BIOS_PATCHES[i][7:0];
			bios_patch1_found = 1;
		end
	end

	// These are only enabled when fds_fast = 1
	for (i = 0; i < BIOS_PATCHES2_CNT; i=i+1) begin
		if (BIOS_PATCHES2[i][23:8] == prg_ain) begin
			patch_data = BIOS_PATCHES2[i][7:0];
			bios_patch2_found = 1;
		end
	end

	if (~fds_fast) bios_patch2_found = 0;
end

wire bios_patch_found = bios_patch1_found | bios_patch2_found;

//NES data out
reg [7:0] prg_dout_r;
always @* begin
	fds_prg_bus_write = 1'b1;

	if (prg_ain == 16'h4030) begin //IRQ status
		prg_dout_r = {byte_transfer_flag, diskend, 4'd0, 1'b0, timer_irq};
	end else if (prg_ain == 16'h4032) begin //drive status
		prg_dout_r = {4'h4, 1'b0, disk_eject, ~disk_ready, disk_eject};
	end else if (prg_ain == 16'h4033) begin //power / exp
		prg_dout_r = 8'b10000000;
	end else if (fds_audio_prg_bus_write) begin
		prg_dout_r = audio_dout;
	end else if (bios_patch_found) begin
		prg_dout_r = patch_data;
	end else begin
		prg_dout_r = 8'd0;
		fds_prg_bus_write = 0;
	end
end


assign prg_dout = prg_dout_r;

assign irq = timer_irq | disk_irq;

assign disk_eject = disk_eject_auto | fds_eject_btn;

//bankswitch control: 6000-DFFF = sram, E000-FFFF = bios or disk
wire prg_is_ram = prg_ain[15] ^ (&prg_ain[14:13]); //$6000-DFFF
assign prg_addr = prg_is_ram ? { 7'b10_0000_1, prg_ain[14:0] } : { 9'd0, prg_ain[12:0] };

//Switch to Cart Ram for Disk access
//PRG 000000-001FFF = bios
//PRG 208000-20FFFF = wram
//PRG 3C0000-3FFFFF = disk image
assign prg_aout = (prg_disk_rd_reg | prg_disk_wr_reg) ? { 4'b111_1,romoffset } : prg_addr;
assign prg_allow = ((prg_ain[15] | prg_disk_rd_reg) & ~prg_write & ~bios_patch_found) | (prg_is_ram | write_disk);

assign chr_allow = 1;
assign chr_aout = { 9'b10_0000_000, chr_ain[12:0] };
assign vram_a10 = vertical ? chr_aout[10] : chr_aout[11];
assign vram_ce = chr_ain[13];

// savestate
localparam SAVESTATE_MODULES    = 3;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
wire [63:0] SS_MAP1, SS_MAP2, SS_MAP3;
wire [63:0] SS_MAP1_BACK, SS_MAP2_BACK, SS_MAP3_BACK;
wire [63:0] SaveStateBus_Dout_active = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1] | SaveStateBus_wired_or[2];

eReg_SavestateV #(SSREG_INDEX_MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_MAP1_BACK, SS_MAP1);
eReg_SavestateV #(SSREG_INDEX_MAP2, 64'h0000000000000000) iREG_SAVESTATE_MAP2 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_MAP2_BACK, SS_MAP2);
eReg_SavestateV #(SSREG_INDEX_MAP3, 64'h0000000000000000) iREG_SAVESTATE_MAP3 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[2], SS_MAP3_BACK, SS_MAP3);

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule

module fds_mixed (
	input         clk,
	input         ce,    // Negedge M2 (aka CPU ce)
	input         enable,
	input         wren,
	input  [15:0] addr_in,
	input   [7:0] data_in,
	output  [7:0] data_out,
	input  [15:0] audio_in,    // Inverted audio from APU
	output [15:0] audio_out,

	input         Savestate_MAPRAMactive,
	input [ 7:0]  Savestate_MAPRAMAddr,
	input         Savestate_MAPRAMRdEn,
	input         Savestate_MAPRAMWrEn,
	input  [7:0]  Savestate_MAPRAMWriteData,
	output [7:0]  Savestate_MAPRAMReadData
);

//expansion audio
fds_audio fds_audio
(
	.clk(clk),
	.m2(ce),
	.reset(!enable),
	.wr(wren),
	.addr_in(addr_in),
	.data_in(data_in),
	.data_out(data_out),
	.audio_out(audio_exp),

	.Savestate_MAPRAMactive   (Savestate_MAPRAMactive),
	.Savestate_MAPRAMAddr     (Savestate_MAPRAMAddr),
	.Savestate_MAPRAMRdEn     (Savestate_MAPRAMRdEn),
	.Savestate_MAPRAMWrEn     (Savestate_MAPRAMWrEn),
	.ss_di                    (Savestate_MAPRAMWriteData),
	.ss_do                    (Savestate_MAPRAMReadData)
);

wire [11:0] audio_exp;

reg [2:0] div_fds;
reg fds_filter_ce;

always @(posedge clk) begin
	fds_filter_ce <= 0;
	div_fds <= div_fds + 1'd1;
	if (div_fds == 2) begin
		div_fds <= 0;
		fds_filter_ce <= 1;
	end

	if (~enable) begin
		div_fds <= 0;
		fds_filter_ce <= 0;
	end
end

wire [15:0] audio_exp_f;

IIR_filter #(
	.coeff_x   (2.15/1.140404269e+03),
	.coeff_x0  (1),
	.coeff_x1  (0),
	.coeff_x2  (0),
	.coeff_y0  (-0.9982462360),
	.coeff_y1  (0),
	.coeff_y2  (0),
	.stereo    (0)
) fds_filter (
	.clk       (clk),
	.ce        (fds_filter_ce),
	.sample_ce (1),
	.input_l   ({audio_exp[11:0], 4'b0000}),
	.output_l  (audio_exp_f)
);

wire [16:0] audio = audio_in + {1'b0, ~(audio_exp_f[15] ? 15'h7FFF : audio_exp_f[14:0])};
assign audio_out = ~audio[16:1];

endmodule

// FDS Audio module by Kitrinx
// Based on the amazing research by Loopy from Jan, 2019

module fds_audio(
	input            clk,
	input            m2,
	input            reset,
	input            wr,
	input     [15:0] addr_in,
	input      [7:0] data_in,
	output reg [7:0] data_out,
	output    [11:0] audio_out,

	input            Savestate_MAPRAMactive,
	input      [7:0] Savestate_MAPRAMAddr,
	input            Savestate_MAPRAMRdEn,
	input            Savestate_MAPRAMWrEn,
	input      [7:0] ss_di,
	output reg [7:0] ss_do
);

// Volume Envelope
reg  [5:0] vol_speed;
reg  [5:0] vol_gain;
reg  [5:0] vol_pwm_lat;
reg        vol_dir;
reg        vol_disable;

// Sweep Envelope
reg [5:0]  sweep_speed;
reg [5:0]  sweep_gain;
reg        sweep_dir;
reg        sweep_disable;

// Modulator
reg [11:0] mod_frequency;
reg [17:0] mod_accum;
reg        mod_step;
reg  [2:0] mod_table[0:31];
reg signed [6:0] mod_bias;
reg signed [6:0] mod_incr;
reg        mod_disable;

// Wave Table
reg        wave_wren;
reg [23:0] wave_accum;
reg  [5:0] wave_table[0:63];
reg  [5:0] wave_latch;
reg [11:0] wave_frequency;
reg        wave_disable; // high: Envelopes 4x faster and stops mod table accum.

// Timing
reg        env_disable;
reg  [7:0] env_speed = 8'hE8;
reg [11:0] vol_env_ticks, sweep_env_ticks;
reg  [5:0] vol_ticks, sweep_ticks;
reg  [1:0] master_vol;

// Master timer
reg [3:0] cycles;

wire [12:0] mod_acc_next = mod_accum[11:0] + mod_frequency;

// Loopy's magical modulation math
wire signed [11:0] temp = mod_bias * $signed({1'b0, sweep_gain});
wire signed [11:0] temp2 = $signed((|temp[3:0] & ~temp[11]) ? temp + 12'sh20 : temp);
wire signed [11:0] temp3 = temp2 + 12'sh400;
wire [19:0] wave_pitch = $unsigned(temp3[11:4]) * wave_frequency;

// Volume math
wire [11:0] mul_out = wave_latch * (vol_pwm_lat[5] ? 6'd32 : vol_pwm_lat);

wire [15:0] level_out;
assign audio_out = level_out[11:0];

always_comb begin
	case (master_vol)
		2'b00: level_out = mul_out;
		2'b01: level_out = {mul_out, 1'b0} / 16'd3;
		2'b10: level_out = mul_out[11:1];
		2'b11: level_out = {mul_out, 1'b0} / 16'd5;
		default: level_out = mul_out;
	endcase

	if (addr_in >= 'h4040 && addr_in < 'h4080) begin
		if (wave_wren)
			data_out = wave_table[addr_in[5:0]];
		else
			data_out = wave_table[wave_accum[23:18]];
	end else begin
		case (addr_in)
			'h4090: data_out = {2'b01, vol_gain};
			'h4091: data_out = wave_accum[19:12];
			'h4092: data_out = {2'b01, sweep_gain};
			'h4093: data_out = {1'b0, mod_accum[11:5]};
			'h4094: data_out = wave_pitch[11:4];
			'h4095: data_out = {cycles, mod_incr[3:0]};
			'h4096: data_out = {2'b01, wave_table[wave_accum[23:18]]};
			'h4097: data_out = {1'b0, mod_bias};
			default: data_out = 8'b0100_0000;
		endcase
	end

	case (mod_table[mod_accum[17:13]])
		3'h0: mod_incr = 0;
		3'h1: mod_incr = 7'sd1;
		3'h2: mod_incr = 7'sd2;
		3'h3: mod_incr = 7'sd4;
		3'h4: mod_incr = -7'sd4;
		3'h5: mod_incr = -7'sd4;
		3'h6: mod_incr = -7'sd2;
		3'h7: mod_incr = -7'sd1;
		default: mod_incr = 0;
	endcase
end

always_ff @(posedge clk) begin
reg old_m2;

old_m2 <= m2;
if (reset) begin
	sweep_disable <= 1'b1;
	env_disable <= 1'b1;
	wave_disable <= 1'b1;
	mod_disable <= 1'b1;
	wave_accum <= 0;
	mod_accum <= 0;
	{cycles, sweep_ticks, sweep_env_ticks, vol_ticks, vol_env_ticks, master_vol} <= 0;
end else if (Savestate_MAPRAMWrEn) begin
	casez (Savestate_MAPRAMAddr)
		8'h00: { vol_disable, vol_dir, vol_speed } <= ss_di;
		8'h01: { master_vol, vol_gain } <= ss_di;
		8'h02: { vol_pwm_lat } <= ss_di[5:0];
		8'h03: { sweep_disable, sweep_dir, sweep_speed } <= ss_di;
		8'h04: { sweep_gain } <= ss_di[5:0];
		8'h05: { mod_frequency[7:0] } <= ss_di;
		8'h06: { mod_frequency[11:8] } <= ss_di[3:0];
		8'h07: { mod_accum[7:0] } <= ss_di;
		8'h08: { mod_accum[15:8] } <= ss_di;
		8'h09: { sweep_ticks, mod_accum[17:16] } <= ss_di;
		8'h0A: { mod_disable, mod_bias } <= ss_di;
		8'h0B: { wave_accum[7:0] } <= ss_di;
		8'h0C: { wave_accum[15:8] } <= ss_di;
		8'h0D: { wave_accum[23:16] } <= ss_di;
		8'h0E: { wave_wren, wave_disable, wave_latch } <= ss_di;
		8'h0F: { wave_frequency[7:0] } <= ss_di;
		8'h10: { wave_frequency[11:8] } <= ss_di[3:0];
		8'h11: { env_speed } <= ss_di;
		8'h12: { vol_env_ticks[7:0] } <= ss_di;
		8'h13: { vol_env_ticks[11:8] } <= ss_di[3:0];
		8'h14: { sweep_env_ticks[7:0] } <= ss_di;
		8'h15: { cycles, sweep_env_ticks[11:8] } <= ss_di;
		8'h16: { mod_step, env_disable, vol_ticks } <= ss_di;
		// $20-$3F
		8'b001?????: mod_table[Savestate_MAPRAMAddr[4:0]] <= ss_di[2:0];
		// $40-$7F
		8'b01??????: wave_table[Savestate_MAPRAMAddr[5:0]] <= ss_di[5:0];
		default: ;
	endcase
end else if (~old_m2 & m2) begin
	//**** Timings ****//
	cycles <= wave_disable ? 4'h0 : cycles + 1'b1;

	if (&cycles && ~wave_disable) begin
		wave_accum <= wave_accum + wave_pitch;
		if (~mod_disable)
			mod_accum <= mod_accum + mod_frequency;
	end

	//**** Envelopes ****//
	if (~env_disable && env_speed) begin

		//**** Volume Envelope ****//
		if (~vol_disable) begin
			if (vol_env_ticks >= {env_speed, 3'b111}) begin
				vol_env_ticks <= 0;
				if (vol_ticks == vol_speed) begin
					vol_ticks <= 0;
					if (vol_dir && ~vol_gain[5])
						vol_gain <= vol_gain + 1'b1;
					else if (~vol_dir && vol_gain)
						vol_gain <= vol_gain - 1'b1;
				end else
					vol_ticks <= vol_ticks + 1'b1;
			end else
				vol_env_ticks <= vol_env_ticks + (~wave_disable ? 1'b1 : 4'd4);
		end

		//**** Sweep Envelope ****//
		if (~sweep_disable) begin
			if (sweep_env_ticks >= {env_speed, 3'b111}) begin
				sweep_env_ticks <= 0;
				if (sweep_ticks == sweep_speed) begin
					sweep_ticks <= 0;
					if (sweep_dir && ~sweep_gain[5])
						sweep_gain <= sweep_gain + 1'b1;
					else if (~sweep_dir && sweep_gain)
						sweep_gain <= sweep_gain - 1'b1;
				end else
					sweep_ticks <= sweep_ticks + 1'b1;
			end else
				sweep_env_ticks <= sweep_env_ticks + (~wave_disable ? 1'b1 : 4'd4);
		end
	end

	//**** Modulation ****//
	if ((&cycles && mod_acc_next[12]) || mod_step) begin
		if (mod_table[mod_accum[17:13]] == 3'h4) begin
			mod_bias <= 0;
		end else begin
			mod_bias <= mod_bias + mod_incr;
		end
	end

	//**** Latches ****//
	if (~|wave_accum[23:18])
		vol_pwm_lat <= vol_gain;

	if (~wave_wren)
		wave_latch <= wave_table[wave_accum[23:18]];

	//**** Registers ****//
	if (wr) begin
		if (addr_in >= 'h4040 && addr_in < 'h4080) begin
			if (wave_wren)
				wave_table[addr_in[5:0]] <= data_in[5:0];
		end
		case (addr_in)
			16'h4080: begin
				{vol_disable, vol_dir, vol_speed} <= data_in;
				if (data_in[7]) vol_gain <= data_in[5:0];
				vol_ticks <= 0;
				vol_env_ticks <= 0;
			end

			16'h4082: wave_frequency[7:0] <= data_in;

			16'h4083: begin
				wave_frequency[11:8] <= data_in[3:0];
				wave_disable <= data_in[7];
				env_disable <= data_in[6];

				if (data_in[7]) begin
					wave_accum <= 0;
					cycles <= 0;
				end

				if (data_in[6]) begin // Reset envelopes
					vol_ticks <= 0;
					sweep_ticks <= 0;
					vol_env_ticks <= 0;
					sweep_env_ticks <= 0;
				end
			end

			16'h4084: begin
				{sweep_disable, sweep_dir, sweep_speed} <= data_in;
				if (data_in[7]) sweep_gain <= data_in[5:0];
				sweep_ticks <= 0;
				sweep_env_ticks <= 0;
			end

			16'h4085: mod_bias <= data_in[6:0];

			16'h4086: mod_frequency[7:0] <= data_in;

			16'h4087: begin
				mod_frequency[11:8] <= data_in[3:0];
				mod_disable <= data_in[7];
				mod_step <= data_in[6];

				if (data_in[7])
					mod_accum[12:0] <= 0;
			end

			16'h4088: begin
				if (mod_disable) begin
					mod_table[mod_accum[17:13]] <= data_in[2:0];
					mod_accum[17:13] <= mod_accum[17:13] + 1'b1;
				end
			end

			16'h4089: begin
				wave_wren <= data_in[7];
				master_vol <= data_in[1:0];
			end

			16'h408A: begin
				env_speed <= data_in;
				vol_ticks <= 0;
				sweep_ticks <= 0;
				vol_env_ticks <= 0; // Undocumented, but I believe this is right.
				sweep_env_ticks <= 0;
			end
		endcase
	end
end // if m2
end

always @(posedge clk) begin
	if (reset) begin
		ss_do <= 8'd0;
	end else if (Savestate_MAPRAMRdEn) begin
		casez (Savestate_MAPRAMAddr)
			8'h00: ss_do <= { vol_disable, vol_dir, vol_speed };
			8'h01: ss_do <= { master_vol, vol_gain };
			8'h02: ss_do <= { 2'd0, vol_pwm_lat };
			8'h03: ss_do <= { sweep_disable, sweep_dir, sweep_speed };
			8'h04: ss_do <= { 2'd0, sweep_gain };
			8'h05: ss_do <= { mod_frequency[7:0] };
			8'h06: ss_do <= { 4'd0, mod_frequency[11:8] };
			8'h07: ss_do <= { mod_accum[7:0] };
			8'h08: ss_do <= { mod_accum[15:8] };
			8'h09: ss_do <= { sweep_ticks, mod_accum[17:16] };
			8'h0A: ss_do <= { mod_disable, mod_bias };
			8'h0B: ss_do <= { wave_accum[7:0] };
			8'h0C: ss_do <= { wave_accum[15:8] };
			8'h0D: ss_do <= { wave_accum[23:16] };
			8'h0E: ss_do <= { wave_wren, wave_disable, wave_latch };
			8'h0F: ss_do <= { wave_frequency[7:0] };
			8'h10: ss_do <= { 4'd0, wave_frequency[11:8] };
			8'h11: ss_do <= { env_speed };
			8'h12: ss_do <= { vol_env_ticks[7:0] };
			8'h13: ss_do <= { 4'd0, vol_env_ticks[11:8] };
			8'h14: ss_do <= { sweep_env_ticks[7:0] };
			8'h15: ss_do <= { cycles, sweep_env_ticks[11:8] };
			8'h16: ss_do <= { mod_step, env_disable, vol_ticks };
			// $20-$3F
			8'b001?????: ss_do <= { 5'd0, mod_table[Savestate_MAPRAMAddr[4:0]] };
			// $40-$7F
			8'b01??????: ss_do <= { 2'd0, wave_table[Savestate_MAPRAMAddr[5:0]] };
			default: ss_do <= 8'd0;
		endcase
	end
end

endmodule
