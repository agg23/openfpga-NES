// Nintendo Vs. System ROM board (iNES mapper 99).
// https://www.nesdev.org/wiki/INES_Mapper_099
//
// This module implements only the mapper-visible ROM/RAM wiring. Vs. cabinet
// inputs, RGB PPU behavior, protection devices, watchdog, and DualSystem
// ownership are platform features and intentionally live outside this mapper.
module Mapper99(
	input         clk,         // System clock
	input         ce,          // M2 ~cpu_clk
	input         enable,      // Mapper enabled
	input  [63:0] flags,       // Cart flags
	input  [15:0] prg_ain,     // PRG address
	inout  [21:0] prg_aout_b,  // PRG address out
	input         prg_read,    // PRG read
	input         prg_write,   // PRG write
	input   [7:0] prg_din,     // PRG data in
	inout   [7:0] prg_dout_b,  // PRG data out
	inout         prg_allow_b, // Enable access to memory for the operation
	input  [13:0] chr_ain,     // CHR address in
	inout  [21:0] chr_aout_b,  // CHR address out
	input         chr_read,    // CHR read
	inout   [7:0] chr_dout_b,  // CHR data override for an absent ROM socket
	inout         chr_allow_b, // CHR write enable
	inout         vram_a10_b,  // CIRAM A10
	inout         vram_ce_b,   // Route access to internal 2 KiB CIRAM
	inout         irq_b,       // IRQ
	input  [15:0] audio_in,    // Inverted audio from APU
	inout  [15:0] audio_b,     // Mixed audio output
	inout  [15:0] flags_out_b, // Mapper behavior flags
	// Savestates
	input  [63:0] SaveStateBus_Din,
	input   [9:0] SaveStateBus_Adr,
	input         SaveStateBus_wren,
	input         SaveStateBus_rst,
	input         SaveStateBus_load,
	output [63:0] SaveStateBus_Dout
);

assign prg_aout_b  = enable ? prg_aout : 22'hZ;
assign prg_dout_b  = enable ? 8'hFF : 8'hZ;
assign prg_allow_b = enable ? prg_allow : 1'hZ;
assign chr_aout_b  = enable ? chr_aout : 22'hZ;
assign chr_dout_b  = enable ? chr_dout : 8'hZ;
assign chr_allow_b = enable ? chr_allow : 1'hZ;
assign vram_a10_b  = enable ? vram_a10 : 1'hZ;
assign vram_ce_b   = enable ? vram_ce : 1'hZ;
assign irq_b       = enable ? 1'b0 : 1'hZ;
assign flags_out_b = enable ? flags_out : 16'hZ;
assign audio_b     = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [2:0] prg_banks = flags[40:38]; // Exact count in 8 KiB units, 1-5
wire [1:0] chr_banks = flags[42:41]; // Exact count in 8 KiB units, 1-2
wire       four_screen = flags[16];
wire       chr_ram = flags[15];

reg bank_select;

always @(posedge clk) begin
	if (~enable) begin
		bank_select <= 1'b0;
	end else if (SaveStateBus_load) begin
		bank_select <= SS_MAP1[0];
	end else if (ce && prg_write && (prg_ain == 16'h4016)) begin
		bank_select <= prg_din[2];
	end
end

// The ROMs populate 8 KiB sockets. Small fixed programs are right-aligned so
// the reset vectors remain at $E000-$FFFF. The 40 KiB Gumshoe layout adds bank
// 4 as an alternate $8000-$9FFF socket selected by OUT2.
reg [2:0] prg_bank;
reg       prg_rom_present;

always @* begin
	prg_bank = 3'd0;
	prg_rom_present = 1'b0;

	case (prg_banks)
		3'd1: begin
			if (prg_ain[14:13] == 2'b11) begin
				prg_bank = 3'd0;
				prg_rom_present = 1'b1;
			end
		end
		3'd2: begin
			case (prg_ain[14:13])
				2'b10: begin
					prg_bank = 3'd0;
					prg_rom_present = 1'b1;
				end
				2'b11: begin
					prg_bank = 3'd1;
					prg_rom_present = 1'b1;
				end
				default: begin
					prg_bank = 3'd0;
					prg_rom_present = 1'b0;
				end
			endcase
		end
		3'd3: begin
			case (prg_ain[14:13])
				2'b01: begin
					prg_bank = 3'd0;
					prg_rom_present = 1'b1;
				end
				2'b10: begin
					prg_bank = 3'd1;
					prg_rom_present = 1'b1;
				end
				2'b11: begin
					prg_bank = 3'd2;
					prg_rom_present = 1'b1;
				end
				default: begin
					prg_bank = 3'd0;
					prg_rom_present = 1'b0;
				end
			endcase
		end
		3'd4: begin
			prg_bank = {1'b0, prg_ain[14:13]};
			prg_rom_present = 1'b1;
		end
		3'd5: begin
			case (prg_ain[14:13])
				2'b00: prg_bank = bank_select ? 3'd4 : 3'd0;
				2'b01: prg_bank = 3'd1;
				2'b10: prg_bank = 3'd2;
				2'b11: prg_bank = 3'd3;
			endcase
			prg_rom_present = 1'b1;
		end
		default: begin
			prg_bank = 3'd0;
			prg_rom_present = 1'b0;
		end
	endcase
end

wire prg_is_ram = (prg_ain[15:13] == 3'b011);
wire prg_is_rom = prg_ain[15];
wire [21:0] prg_rom_addr = {6'b00_0000, prg_bank, prg_ain[12:0]};
wire [21:0] prg_ram_addr = {9'b11_1100_000, 2'b00, prg_ain[10:0]};

wire prg_allow = prg_is_ram || (prg_is_rom && !prg_write && prg_rom_present);
wire [21:0] prg_aout = prg_is_ram ? prg_ram_addr : prg_rom_addr;

// With one CHR ROM populated, selecting the second socket leaves the PPU bus
// undriven. The multiplexed PPU bus most recently carried the low address byte,
// which is the core's mapper-local approximation for that open-bus read.
// https://www.nesdev.org/wiki/Open_bus_behavior
wire chr_rom_present = (chr_banks == 2'd2) || ((chr_banks == 2'd1) && !bank_select);
wire chr_open_bus = !chr_ain[13] && !chr_ram && !chr_rom_present;
wire [7:0] chr_dout = chr_ain[7:0];

wire [21:0] chr_rom_addr = {8'b10_0000_00, bank_select, chr_ain[12:0]};
wire [21:0] chr_ram_addr = {9'b11_1111_111, chr_ain[12:0]};
wire [21:0] four_screen_addr = {10'b11_1111_1100, chr_ain[11:0]};
wire [21:0] chr_aout = (four_screen && chr_ain[13]) ? four_screen_addr :
	chr_ram ? chr_ram_addr : chr_rom_addr;

wire chr_allow = (chr_ram && !chr_ain[13]) || (four_screen && chr_ain[13]);
wire vram_ce = chr_ain[13] && !four_screen;
wire vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
wire [15:0] flags_out = {12'h000, 1'b1, 2'b00, chr_open_bus};

// Savestate bank bit. The actual hardware signal is CPU OUT2; retaining the
// mapper-visible latch here avoids widening the CPU/cart interface in this pass.
wire [63:0] SS_MAP1;
wire [63:0] SS_MAP1_BACK;
wire [63:0] SaveStateBus_Dout_active;

assign SS_MAP1_BACK[0] = bank_select;
assign SS_MAP1_BACK[63:1] = 63'b0;

eReg_SavestateV #(10'd32, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (
	clk,
	SaveStateBus_Din,
	SaveStateBus_Adr,
	SaveStateBus_wren,
	SaveStateBus_rst,
	SaveStateBus_Dout_active,
	SS_MAP1_BACK,
	SS_MAP1
);

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule
