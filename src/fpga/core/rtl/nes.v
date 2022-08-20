// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

// Sprite DMA Works as follows.
// When the CPU writes to $4014 DMA is initiated ASAP.
// DMA runs for 512 cycles, the first cycle it reads from address
// xx00 - xxFF, into a latch, and the second cycle it writes to $2004.

// Facts:
// 1) Sprite DMA always does reads on even cycles and writes on odd cycles.
// 2) There are 1-2 cycles of cpu_read=1 after cpu_read=0 until Sprite DMA starts (pause_cpu=1, aout_enable=0)
// 3) Sprite DMA reads the address value on the last clock of cpu_read=0
// 4) If DMC interrupts Sprite, then it runs on the even cycle, and the odd cycle will be idle (pause_cpu=1, aout_enable=0)
// 5) When DMC triggers && interrupts CPU, there will be 2-3 cycles (pause_cpu=1, aout_enable=0) before DMC DMA starts.

// https://wiki.nesdev.com/w/index.php/PPU_OAM
// https://wiki.nesdev.com/w/index.php/APU_DMC
// https://forums.nesdev.com/viewtopic.php?f=3&t=6100
// https://forums.nesdev.com/viewtopic.php?f=3&t=14120

module DmaController(
	input clk,
	input ce,
	input reset,
	input odd_cycle,               // Current cycle even or odd?
	input sprite_trigger,          // Sprite DMA trigger?
	input dmc_trigger,             // DMC DMA trigger?
	input cpu_read,                // CPU is in a read cycle?
	input [7:0] data_from_cpu,     // Data written by CPU?
	input [7:0] data_from_ram,     // Data read from RAM?
	input [15:0] dmc_dma_addr,     // DMC DMA Address
	output [15:0] aout,            // Address to access
	output aout_enable,            // DMA controller wants bus control
	output read,                   // 1 = read, 0 = write
	output [7:0] data_to_ram,      // Value to write to RAM
	output dmc_ack,                // ACK the DMC DMA
	output pause_cpu               // CPU is pausede
);

reg dmc_state;
reg [1:0] spr_state;
reg [7:0] sprite_dma_lastval;
reg [15:0] sprite_dma_addr;     // sprite dma source addr
wire [8:0] new_sprite_dma_addr = sprite_dma_addr[7:0] + 8'h01;

always @(posedge clk) if (reset) begin
	dmc_state <= 0;
	spr_state <= 0;
	sprite_dma_lastval <= 0;
	sprite_dma_addr <= 0;
end else if (ce) begin
	if (dmc_state == 0 && dmc_trigger && cpu_read && !odd_cycle) dmc_state <= 1;
	if (dmc_state == 1 && !odd_cycle) dmc_state <= 0;

	if (sprite_trigger) begin sprite_dma_addr <= {data_from_cpu, 8'h00}; spr_state <= 1; end
	if (spr_state == 1 && cpu_read && odd_cycle) spr_state <= 3;
	if (spr_state[1] && !odd_cycle && dmc_state == 1) spr_state <= 1;
	if (spr_state[1] && odd_cycle) sprite_dma_addr[7:0] <= new_sprite_dma_addr[7:0];
	if (spr_state[1] && odd_cycle && new_sprite_dma_addr[8]) spr_state <= 0;
	if (spr_state[1]) sprite_dma_lastval <= data_from_ram;
end

assign pause_cpu = (spr_state[0] || dmc_trigger);
assign dmc_ack   = (dmc_state == 1 && !odd_cycle);
assign aout_enable = dmc_ack || spr_state[1];
assign read = !odd_cycle;
assign data_to_ram = sprite_dma_lastval;
assign aout = dmc_ack ? dmc_dma_addr : !odd_cycle ? sprite_dma_addr : 16'h2004;

endmodule

module NES(
	input         clk,
	input         reset_nes,
	input         cold_reset,
	input         pausecore,
	output        corepaused,
	input   [1:0] sys_type,
	output  [1:0] nes_div,
	input  [63:0] mapper_flags,
	output [15:0] sample,         // sample generated from APU
	output  [5:0] color,          // pixel generated from PPU
	output  [1:0] joypad_clock,   // Set to 1 for each joypad to clock it.
	output  [2:0] joypad_out,     // Set to 1 to strobe joypads. Then set to zero to keep the value.
	input   [4:0] joypad1_data,   // Port1
	input   [4:0] joypad2_data,   // Port2
	input         fds_busy,       // FDS Disk Swap Busy
	input         fds_eject,      // FDS Disk Swap Pause
	input         fds_auto_eject,
	input   [1:0] max_diskside,
	output  [1:0] diskside,

	input   [4:0] audio_channels, // Enabled audio channels
	input         ex_sprites,
	input   [1:0] mask,

	// Access signals for the SDRAM.
	output [24:0] cpumem_addr,
	output        cpumem_read,
	output        cpumem_write,
	output  [7:0] cpumem_dout,
	input   [7:0] cpumem_din,
	output [21:0] ppumem_addr,
	output        ppumem_read,
	output        ppumem_write,
	output  [7:0] ppumem_dout,
	input   [7:0] ppumem_din,
	output        refresh,

	input  [20:0] prg_mask,
	input  [19:0] chr_mask,

	// Override for BRAM
	output [17:0] bram_addr,      // address to access
	input   [7:0] bram_din,       // Data from BRAM
	output  [7:0] bram_dout,
	output        bram_write,     // is a write operation
	output        bram_override,

	output  [8:0] cycle,
	output  [8:0] scanline,
	input         int_audio,
	input         ext_audio,
	output        apu_ce,
	input         gg,
	input [128:0] gg_code,
	output        gg_avail,
	input         gg_reset,
	output  [2:0] emphasis,
	output        save_written,
	
	// savestates
	output        mapper_has_savestate,
	input         increaseSSHeaderCount,
	input         save_state,
	input         load_state,
	input  [1:0]  savestate_number,
	output        sleep_savestate,
	output        state_loaded,
	
	output [24:0] Savestate_SDRAMAddr,     
	output        Savestate_SDRAMRdEn,    
	output        Savestate_SDRAMWrEn,    
	output [7:0]  Savestate_SDRAMWriteData,
	input  [7:0]  Savestate_SDRAMReadData,
	
	output [63:0] SaveStateExt_Din, 
	output [9:0]  SaveStateExt_Adr, 
	output        SaveStateExt_wren,
	output        SaveStateExt_rst, 
	input  [63:0] SaveStateExt_Dout,
	output        SaveStateExt_load,

	output [63:0] SAVE_out_Din,  	// data read from savestate
	input  [63:0] SAVE_out_Dout, 	// data written to savestate
	output [25:0] SAVE_out_Adr,  	// all addresses are DWORD addresses!
	output        SAVE_out_rnw,   // read = 1, write = 0
	output        SAVE_out_ena,   // one cycle high for each action
	output  [7:0] SAVE_out_be,     
	input         SAVE_out_done   // should be one cycle high when write is done or read value is valid
);


/**********************************************************/
/*************            Clocks            ***************/
/**********************************************************/

// Master clock speed: NTSC/Dendy: 21.477272, PAL: 21.2813696

// Cyc 123456789ABC123456789ABC123456789ABC123456789ABC
// CPU ----M------C----M------C----M------C----M------C
// PPU ---P---P---P---P---P---P---P---P---P---P---P---P
//  M: M2 Tick, C: CPU Tick, P: PPU Tick -: Idle Cycle
//
// On Mister, we must pre-fetch data from memory 4 cycles before it is needed.
// Memory requests are aligned to the PPU clock and there are two types: CPU pre-fetch
// and PPU pre-fetch. The CPU pre-fetch needs to be completed before the end of the CPU cycle, and
// the PPU pre-fetch needs to be completed before each PPU CE is ticked.
// The PPU_CE that acknowledges reads and writes always occurs after the M2 rising edge, and cart/mapper
// CE's are always triggered on the rising edge of M2, which means that PPU will always see
// any changes made by the cart mappers. Because the mapper on MiSTer is capable of changing the data that
// is given to the CPU (banking, etc) the best time to run it is the first PPU cycle where the data from the
// CPU is visible on the bus.
//
// The obvious issue is that the CPU and PPU pre-fetches will collide. Fortunately, because Nintendo
// wanted to save pins, the ppu has to take two PPU ticks for every read, meaning there will always be
// a minimum of one free PPU cycle in which to fit the CPU read. This does however create the issue that
// we always need perfect alignment.
//
// Therefore, we can dervive the following order of operations:
// - CPU pre-fetch should happen during first free PPU tick in a CPU cycle.
// - Cart CE should happen on the second PPU tick in a CPU cycle always
// - PPU read/write should happen on the last PPU tick in a CPU cycle (usually third)

assign nes_div = div_sys;
assign apu_ce = cpu_ce;

wire [7:0] from_data_bus;
wire [7:0] cpu_dout;

// odd or even apu cycle, AKA div_apu or apu_/clk2. This is actually not 50% duty cycle. It is high for 18
// master cycles and low for 6 master cycles. It is considered active when low or "even".
reg odd_or_even = 1; // 1 == odd, 0 == even

// Clock Dividers
localparam div_cpu_n = 5'd12;
localparam div_ppu_n = 3'd4;

// Counters
reg [4:0] div_cpu = 5'd1;
reg [2:0] div_ppu = 3'd1;
reg [1:0] div_sys = 2'd0;

// CE's
wire cpu_ce  = (div_cpu == div_cpu_n);
wire ppu_ce  = (div_ppu == div_ppu_n);
wire cart_ce = (cart_pre & ppu_ce); // First PPU cycle where cpu data is visible.

// Signals
wire cart_pre  = (ppu_tick == (cpu_tick_count[2] ? 1 : 0));
wire ppu_read  = (ppu_tick == (cpu_tick_count[2] ? 2 : 1));
wire ppu_write = (ppu_tick == (cpu_tick_count[2] ? 1 : 0));

wire phi2 = (div_cpu > 4 && div_cpu < div_cpu_n);

// The infamous NES jitter is important for accuracy, but wreks havok on modern devices and scalers,
// so what I do here is pause the whole system for one PPU clock and insert a "fake" ppu clock to
// replace the missing pixel. Thus the system runs accurately (ableit a few nanoseconds per frame slower)
// but all video devices stay happy.

wire skip_pixel;
reg freeze_clocks = 0;
reg [4:0] faux_pixel_cnt;

wire use_fake_h = freeze_clocks && faux_pixel_cnt < 6;
reg [1:0] ppu_tick = 0;

reg [1:0] last_sys_type;
reg [2:0] cpu_tick_count;

wire skip_ppu_cycle = (cpu_tick_count == 4) && (ppu_tick == 0);

reg hold_reset = 0;
reg bootvector_flag;
wire cpu_reset = reset_ss | hold_reset;
wire reset = cpu_reset | bootvector_flag;
wire reset_noSS = reset_nes | hold_reset | bootvector_flag;

// pause
reg corepause_active       = 0;
reg corepause_active_delay = 0;
reg skip_pause_ce          = 0;
reg  [7:0] corepause_delay = 8'd0;
reg  [2:0] div_ppu_pause = 0;
wire skip_pixel_pause;
wire ppu_ce_pause = corepause_active ? (div_ppu_pause == div_ppu_n) : ppu_ce;
wire render_ena;
wire [8:0] cycle_paused;
wire [8:0] scanline_paused;
wire       is_in_vblank_paused;
wire       evenframe;
wire       evenframe_paused;

assign corepaused = corepause_active;
assign refresh    = corepause_active_delay && ppu_ce_pause;

always @(posedge clk) begin
	if (reset_nes) hold_reset <= 1;
	if (cpu_ce) hold_reset <= 0;
	if (~freeze_clocks | ~(div_ppu == (div_ppu_n - 1'b1))) begin
		if (~skip_ppu_cycle)
			div_cpu <= cpu_ce || (ppu_ce && div_cpu > div_cpu_n) ? 5'd1 : div_cpu + 5'd1;

		div_ppu <= ppu_ce ? 3'd1 : div_ppu + 3'd1;

		// reset the ticker on the first ppu tick at or after a cpu tick.
		if (cpu_ce)
			ppu_tick <= 0;
		else if (ppu_ce)
			ppu_tick <= ppu_tick + 1'b1;
	end

	// Add one extra PPU tick every 5 cpu cycles for PAL.
	if (cpu_ce && sys_type[0])
		cpu_tick_count <= cpu_tick_count[2] ? 3'd0 : cpu_tick_count + 1'b1;

	// SDRAM Clock
	div_sys <= div_sys + 1'b1;

	// De-Jitter shenanigans
	if (faux_pixel_cnt == 3)
		freeze_clocks <= 1'b0;

	if (|faux_pixel_cnt)
		faux_pixel_cnt <= faux_pixel_cnt - 1'b1;

	if (((skip_pixel && ~corepause_active) || (skip_pixel_pause && corepause_active)) && (faux_pixel_cnt == 0)) begin
		freeze_clocks <= 1'b1;
		faux_pixel_cnt <= {div_ppu_n - 1'b1, 1'b0} + 1'b1;
	end


	if (reset_nes | hold_reset) begin
		bootvector_flag <= 1;
		odd_or_even <= 1;
	end else if (loading_savestate) begin
		odd_or_even <= SS_TOP[0];
	end else if (cpu_ce) begin
		odd_or_even <= ~odd_or_even;
		bootvector_flag <= 0;
	end

	// Realign if the system type changes.
	last_sys_type <= sys_type;
	if (last_sys_type != sys_type) begin
		div_cpu <= 5'd1;
		div_ppu <= 3'd1;
		div_sys <= 0;
		cpu_tick_count <= 0;
	end
	
	// pause
	if (ppu_ce_pause) skip_pause_ce <= 0; // must skip the first CE after pause to sync back to correct ppu
	
	if (reset_nes) begin
		corepause_active       <= 0;
		corepause_active_delay <= 0;
	end else begin
		if (corepause_active || (pausecore && div_cpu == 5'd1 && div_ppu == 3'd1 && div_sys == 0 && cpu_tick_count == 0 && ~freeze_clocks && is_in_vblank_paused && ~pause_cpu && cpu_Instrnew)) begin
			div_cpu           <= 5'd1;
			div_ppu           <= 3'd1;
			div_sys           <= 0;
			cpu_tick_count    <= 0;
			corepause_active  <= 1;
			div_ppu_pause     <= div_ppu + 3'd1;
		end
		
		if (corepause_active) begin
			
			if (corepause_delay < 8'hFF) begin
				corepause_delay <= corepause_delay + 1'd1;
			end else begin
				corepause_active_delay <= 1;
			end
			
			if (~freeze_clocks | ~(div_ppu_pause == (div_ppu_n - 1'b1))) begin
				div_ppu_pause <= ppu_ce_pause ? 3'd1 : div_ppu_pause + 3'd1;
				if (~pausecore && ppu_ce_pause && (cycle_paused == ppu_cycle) && (scanline_paused == scanline_ppu) && (evenframe == evenframe_paused)) begin
					corepause_active       <= 0;
					corepause_active_delay <= 0;
					skip_pause_ce          <= 1;
				end
			end
		end else begin
			corepause_delay <= 8'd0;
		end
	end
	
end

assign SS_TOP_BACK[0] = odd_or_even;

ClockGen clockgen_pause(
	.clk                 (clk),
	.ce                  (ppu_ce_pause && ~skip_pause_ce),
	.reset               (reset_noSS),
	.sys_type            (sys_type),
	.is_rendering        (render_ena),
	.scanline            (scanline_paused),
	.cycle               (cycle_paused),
	.is_in_vblank        (is_in_vblank_paused),
	//.end_of_line         (end_of_line),
	//.at_last_cycle_group (at_last_cycle_group),
	//.exiting_vblank      (exiting_vblank),
	//.entering_vblank     (entering_vblank),
	//.is_pre_render       (is_pre_render_line),
	.short_frame         (skip_pixel_pause),
	//.is_vbe_sl           (is_vbe_sl)
	.evenframe           (evenframe_paused)
);

/**********************************************************/
/*************              CPU             ***************/
/**********************************************************/

wire [15:0] cpu_addr;
wire cpu_rnw;
wire pause_cpu;
wire nmi;
wire mapper_irq;
wire apu_irq;
wire cpu_Instrnew;

// IRQ only changes once per CPU ce and with our current
// limited CPU model, NMI is only latched on the falling edge
// of M2, which corresponds with CPU ce, so no latches needed.

T65 cpu(
	.mode   (0),
	.BCD_en (0),

	.res_n  (~cpu_reset),
	.clk    (clk),
	.enable (cpu_ce),
	.rdy    (~pause_cpu),

	.IRQ_n  (~(apu_irq | mapper_irq)),
	.NMI_n  (~nmi),
	.R_W_n  (cpu_rnw),

	.A      (cpu_addr),
	.DI     (cpu_rnw ? from_data_bus : cpu_dout),
	.DO     (cpu_dout),
	
	.Instrnew (cpu_Instrnew),
	
	// savestates
	.SaveStateBus_Din  (SaveStateBus_Din ), 
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_load (loading_savestate ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[0])
);

wire [15:0] dma_aout;
wire dma_aout_enable;
wire dma_read;
wire [7:0] dma_data_to_ram;
wire apu_dma_request, apu_dma_ack;
wire [15:0] apu_dma_addr;

// Determine the values on the bus outgoing from the CPU chip (after DMA / APU)
wire [15:0] addr = dma_aout_enable ? dma_aout  : cpu_addr;
wire [7:0]  dbus = dma_aout_enable ? dma_data_to_ram : cpu_dout;
wire mr_int      = dma_aout_enable ? dma_read  : cpu_rnw;
wire mw_int      = dma_aout_enable ? !dma_read : !cpu_rnw;

DmaController dma(
	.clk            (clk),
	.ce             (cpu_ce),
	.reset          (reset_noSS),
	.odd_cycle      (odd_or_even),                // Even or odd cycle
	.sprite_trigger ((addr == 'h4014 && mw_int)), // Sprite trigger
	.dmc_trigger    (apu_dma_request),            // DMC Trigger
	.cpu_read       (cpu_rnw),                    // CPU in a read cycle?
	.data_from_cpu  (cpu_dout),                   // Data from cpu
	.data_from_ram  (from_data_bus),              // Data from RAM etc.
	.dmc_dma_addr   (apu_dma_addr),               // DMC addr
	.aout           (dma_aout),
	.aout_enable    (dma_aout_enable),
	.read           (dma_read),
	.data_to_ram    (dma_data_to_ram),
	.dmc_ack        (apu_dma_ack),
	.pause_cpu      (pause_cpu)
);


/**********************************************************/
/*************             APU              ***************/
/**********************************************************/

wire apu_cs = addr >= 'h4000 && addr < 'h4018;
wire [7:0] apu_dout;
wire [15:0] sample_apu;

APU apu(
	.MMC5           (1'b0),
	.clk            (clk),
	.PHI2           (phi2),
	.CS             (apu_cs),
	.PAL            (sys_type[0]),
	.ce             (apu_ce),
	.reset          (reset),
	.cold_reset     (cold_reset),
	.ADDR           (addr[4:0]),
	.RW             (cpu_rnw),
	.DIN            (dbus),
	.DOUT           (apu_dout),
	.audio_channels (audio_channels),
	.Sample         (sample_apu),
	.DmaReq         (apu_dma_request),
	.DmaAck         (apu_dma_ack),
	.DmaAddr        (apu_dma_addr),
	.DmaData        (from_data_bus),
	.odd_or_even    (odd_or_even),
	.IRQ            (apu_irq),
	// savestates
	.SaveStateBus_Din  (SaveStateBus_Din ), 
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_load (loading_savestate ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[1])
);
defparam apu.SSREG_INDEX_TOP  = SSREG_INDEX_APU_TOP;
defparam apu.SSREG_INDEX_DMC1 = SSREG_INDEX_APU_DMC1;
defparam apu.SSREG_INDEX_DMC2 = SSREG_INDEX_APU_DMC2;
defparam apu.SSREG_INDEX_FCT  = SSREG_INDEX_APU_FCT;

assign sample = sample_a;
reg [15:0] sample_a;

always @* begin
	case (audio_en)
		0: sample_a = 16'd0;
		1: sample_a = sample_ext;
		2: sample_a = sample_inverted;
		3: sample_a = sample_ext;
	endcase
end

wire [15:0] sample_inverted = 16'hFFFF - sample_apu;
wire [1:0] audio_en = {int_audio, ext_audio};
wire [15:0] audio_mappers = (audio_en == 2'd1) ? 16'd0 : sample_inverted;


// Joypads are mapped into the APU's range.
wire joypad1_cs = (addr == 'h4016);
wire joypad2_cs = (addr == 'h4017);

reg [2:0] joy_out;
always @(posedge clk) begin
	if (joypad1_cs && mw_int)
		joy_out <= cpu_dout[2:0];
end

assign joypad_out = joy_out;
assign joypad_clock = {joypad2_cs && mr_int, joypad1_cs && mr_int};


/**********************************************************/
/*************             PPU              ***************/
/**********************************************************/

// The real PPU has a CS pin which is a combination of the output of the 74319 (ppu address selector)
// and the M2 pin from the CPU. This will only be low for 1 and 7/8th PPU cycles, or
// 7 and 1/2 master cycles on NTSC. Therefore, the PPU should read or write once per cpu cycle, and
// with our alignment, this should occur at PPU cycle 2 (the *third* cycle).
wire mr_ppu     = mr_int && ppu_read; // Read *from* the PPU.
wire mw_ppu     = mw_int && ppu_write; // Write *to* the PPU.
wire ppu_cs = addr >= 'h2000 && addr < 'h4000;
wire [7:0] ppu_dout;            // Data from PPU to CPU
wire chr_read, chr_write, chr_read_ex;       // If PPU reads/writes from VRAM
wire [13:0] chr_addr, chr_addr_ex;           // Address PPU accesses in VRAM
wire [7:0] chr_from_ppu;        // Data from PPU to VRAM
wire [7:0] chr_to_ppu;
wire [8:0] ppu_cycle;
wire [8:0] scanline_ppu;
assign cycle = use_fake_h ? 9'd340 : (corepause_active) ? cycle_paused : ppu_cycle;
assign scanline = (corepause_active) ? scanline_paused : scanline_ppu;

PPU ppu(
	.clk              (clk),
	.ce               (ppu_ce),
	.reset            (reset),
	.sys_type         (sys_type),
	.color            (color),
	.din              (dbus),
	.dout             (ppu_dout),
	.ain              (addr[2:0]),
	.read             (ppu_cs && mr_ppu),
	.write            (ppu_cs && mw_ppu),
	.nmi              (nmi),
	.vram_r           (chr_read),
	.vram_r_ex        (chr_read_ex),
	.vram_w           (chr_write),
	.vram_a           (chr_addr),
	.vram_a_ex        (chr_addr_ex),
	.vram_din         (chr_to_ppu),
	.vram_dout        (chr_from_ppu),
	.scanline         (scanline_ppu),
	.cycle            (ppu_cycle),
	.emphasis         (emphasis),
	.short_frame      (skip_pixel),
	.extra_sprites    (ex_sprites),
	.mask             (mask),
	.render_ena_out   (render_ena),
	.evenframe			(evenframe),
	// savestates
	.SaveStateBus_Din       (SaveStateBus_Din        ), 
	.SaveStateBus_Adr       (SaveStateBus_Adr        ),
	.SaveStateBus_wren      (SaveStateBus_wren       ),
	.SaveStateBus_rst       (SaveStateBus_rst        ),
	.SaveStateBus_load      (loading_savestate       ),
	.SaveStateBus_Dout      (SaveStateBus_wired_or[2]),
	.Savestate_OAMAddr      (Savestate_OAMAddr       ),     
	.Savestate_OAMRdEn      (Savestate_OAMRdEn       ),    
	.Savestate_OAMWrEn      (Savestate_OAMWrEn       ),    
	.Savestate_OAMWriteData (Savestate_OAMWriteData  ),
	.Savestate_OAMReadData  (Savestate_OAMReadData   )
);


/**********************************************************/
/*************             Cart             ***************/
/**********************************************************/

wire [15:0] prg_addr = addr;
wire [7:0] prg_din = dbus & (prg_conflict ? cpumem_din : 8'hFF);

wire prg_read  = mr_int && cart_pre && !apu_cs && !ppu_cs;
wire prg_write = mw_int && cart_pre;

wire prg_allow, prg_bus_write, prg_conflict, vram_a10, vram_ce, chr_allow;
wire [24:0] prg_linaddr;
wire [21:0] chr_linaddr;
wire [7:0] prg_dout_mapper, chr_from_ppu_mapper;
wire has_chr_from_ppu_mapper;
wire [15:0] sample_ext;

assign save_written = (mapper_flags[7:0] == 8'h14) ? (prg_linaddr[21:18] == 4'b1111 && prg_write) : (prg_addr[15:13] == 3'b011 && prg_write) | bram_write;

cart_top multi_mapper (
	// FPGA specific
	.clk               (clk),
	.reset             (reset_noSS),
	.flags             (mapper_flags),            // iNES header data (use 0 while loading)
	.paused            (freeze_clocks),
	// Cart pins (slightly abstracted)
	.ce                (cart_ce & ~reset_noSS),   // M2 (held in high impedance during reset)
	.cpu_ce            (cpu_ce),                  // Serves as M2 Inverted
	.prg_ain           (prg_addr),                // CPU Address in (a15 abstracted from ROMSEL)
	.prg_read          (prg_read),                // CPU RnW split
	.prg_write         (prg_write),               // CPU RnW split
	.prg_din           (prg_din),                 // CPU Data bus in (split from bid)
	.prg_dout          (prg_dout_mapper),         // CPU Data bus out (split from bid)
	.chr_ex            (chr_read_ex),             // Flag indicating to use extra sprite addr
	.chr_ain_orig      (chr_addr),                // PPU address in
	.chr_ain_ex        (chr_addr_ex),             // PPU address for extra sprites
	.chr_read          (chr_read),                // PPU read (inverted, active high)
	.chr_write         (chr_write),               // PPU write (inverted, active high)
	.chr_din           (chr_from_ppu),            // PPU data bus in (split from bid)
	.chr_dout          (chr_from_ppu_mapper),     // PPU data bus in (split from bid)
	.vram_a10          (vram_a10),                // CIRAM a10 line
	.vram_ce           (vram_ce),                 // CIRAM chip enable
	.irq               (mapper_irq),              // IRQ (inverted, active high)
	.audio_in          (audio_mappers),           // Amplified and inverted APU audio
	.audio             (sample_ext),              // Mixed audio output from cart
	// SDRAM Communication
	.prg_aout          (prg_linaddr),             // SDRAM adjusted PRG RAM address
	.prg_allow         (prg_allow),               // Simulates internal CE/Locking
	.chr_aout          (chr_linaddr),             // SDRAM adjusted CHR RAM address
	.chr_allow         (chr_allow),               // Simulates internal CE/Locking
	.prg_mask          (prg_mask),                // PRG Mask for SDRAM translation
	.chr_mask          (chr_mask),                // CHR Mask for SDRAM translation
	// External hardware interface (EEPROM)
	.mapper_addr       (bram_addr),
	.mapper_data_in    (bram_din),
	.mapper_data_out   (bram_dout),
	.mapper_prg_write  (bram_write),
	.mapper_ovr        (bram_override),
	// Cheats
	.prg_from_ram      (from_data_bus),           // Hacky cpu din <= get rid of this!
	// Behavior helper flags
	.has_chr_dout      (has_chr_from_ppu_mapper), // Output specific data for CHR rather than from SDRAM
	.prg_bus_write     (prg_bus_write),           // PRG data driven to bus
	.prg_conflict      (prg_conflict),            // Simulate bus conflicts
	.has_savestate     (mapper_has_savestate),    // Mapper supports savestates
	// User input/FDS controls
	.fds_eject         (fds_eject),               // Used to trigger FDS disk changes
	.fds_busy          (fds_busy),                // Used to trigger FDS disk changes
	.diskside          (diskside),
	.max_diskside      (max_diskside),
	.fds_auto_eject    (fds_auto_eject),

	// savestates
	.SaveStateBus_Din  (SaveStateBus_Din ), 
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_load (loading_savestate ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[3]),
	
	.Savestate_MAPRAMactive   (Savestate_MAPRAMactive),
	.Savestate_MAPRAMAddr     (Savestate_MAPRAMAddr),
	.Savestate_MAPRAMRdEn     (Savestate_MAPRAMRdEn),
	.Savestate_MAPRAMWrEn     (Savestate_MAPRAMWrEn),
	.Savestate_MAPRAMWriteData(Savestate_MAPRAMWriteData),
	.Savestate_MAPRAMReadData (Savestate_MAPRAMReadData)
);

wire genie_ovr;
wire [7:0] genie_data;

CODES codes (
	.clk        (clk),
	.reset      (gg_reset),
	.enable     (~gg),
	.addr_in    (addr),
	.data_in    (prg_allow ? cpumem_din : prg_dout_mapper),
	.code       (gg_code),
	.available  (gg_avail),
	.genie_ovr  (genie_ovr),
	.genie_data (genie_data)
);


/**********************************************************/
/*************       Bus Arbitration        ***************/
/**********************************************************/

assign chr_to_ppu = has_chr_from_ppu_mapper ? chr_from_ppu_mapper : ppumem_din;

assign cpumem_addr  = prg_linaddr;
assign cpumem_read  = (prg_read & prg_allow) | (prg_write && prg_conflict);
assign cpumem_write = prg_write && prg_allow;
assign cpumem_dout  = prg_din;
assign ppumem_addr  = chr_linaddr;
assign ppumem_read  = chr_read;
assign ppumem_write = chr_write && (chr_allow || vram_ce);
assign ppumem_dout  = chr_from_ppu;

reg [7:0] open_bus_data;

always @(posedge clk) begin
	if (loading_savestate) begin
		open_bus_data <= SS_TOP[8:1];
	end else begin
		open_bus_data <= from_data_bus;
	end
end

assign from_data_bus = genie_ovr ? genie_data : raw_data_bus;

reg [7:0] raw_data_bus;

always @* begin
	if (reset)
		raw_data_bus = SS_TOP[16:9]; // 0;
	else if (apu_cs) begin
		if (joypad1_cs)
			raw_data_bus = {open_bus_data[7:5], joypad1_data};
		else if (joypad2_cs)
			raw_data_bus = {open_bus_data[7:5], joypad2_data};
		else
			raw_data_bus = (addr == 16'h4015) ? apu_dout : open_bus_data;
	end else if (ppu_cs) begin
		raw_data_bus = ppu_dout;
	end else if (prg_allow) begin
		raw_data_bus = cpumem_din;
	end else if (prg_bus_write) begin
		raw_data_bus = prg_dout_mapper;
	end else begin
		raw_data_bus = open_bus_data;
	end
end

assign SS_TOP_BACK[ 8: 1] = open_bus_data;
assign SS_TOP_BACK[16: 9] = raw_data_bus;
assign SS_TOP_BACK[63:17] = 47'b0; // free to be used


/**********************************************************/
/*************       Savestates             ***************/
/**********************************************************/

wire [63:0] SaveStateBus_Din;
wire [9:0] SaveStateBus_Adr;
wire SaveStateBus_wren, SaveStateBus_rst;
  
wire [7:0]  Savestate_RAMWriteData;
wire [7:0]  Savestate_RAMReadData;
wire [24:0] Savestate_RAMAddr;
wire        Savestate_RAMRdEn;
wire        Savestate_RAMWrEn;
wire [2:0]  Savestate_RAMType;

localparam SAVESTATE_MODULES    = 5;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];

wire reset_ss;
wire reset_delay;
wire savestate_savestate;
wire savestate_loadstate;
wire [31:0] savestate_address;
wire savestate_busy;  

wire [63:0] SS_TOP;
wire [63:0] SS_TOP_BACK;	
eReg_SavestateV #(SSREG_INDEX_TOP, SSREG_DEFAULT_TOP) iREG_SAVESTATE_TOP (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[4], SS_TOP_BACK, SS_TOP);  

wire [63:0] SaveStateBus_Dout  = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1] | SaveStateBus_wired_or[2] | SaveStateBus_wired_or[3] | SaveStateBus_wired_or[4] | SaveStateExt_Dout;
 
wire loading_savestate;
wire saving_savestate;
wire sleep_savestates;
wire sleep_rewind;

assign Savestate_SDRAMAddr      = Savestate_RAMAddr;
assign Savestate_SDRAMRdEn      = Savestate_RAMRdEn && (Savestate_RAMType > 1);
assign Savestate_SDRAMWrEn      = Savestate_RAMWrEn && (Savestate_RAMType > 1);
assign Savestate_SDRAMWriteData = Savestate_RAMWriteData;

wire [7:0] Savestate_OAMAddr      = Savestate_RAMAddr[7:0];
wire       Savestate_OAMRdEn      = Savestate_RAMRdEn && (Savestate_RAMType == 0);
wire       Savestate_OAMWrEn      = Savestate_RAMWrEn && (Savestate_RAMType == 0);
wire [7:0] Savestate_OAMWriteData = Savestate_RAMWriteData;
wire [7:0] Savestate_OAMReadData;

wire        Savestate_MAPRAMactive    = loading_savestate | saving_savestate;
wire [12:0] Savestate_MAPRAMAddr      = Savestate_RAMAddr[12:0];
wire        Savestate_MAPRAMRdEn      = Savestate_RAMRdEn && (Savestate_RAMType == 1);
wire        Savestate_MAPRAMWrEn      = Savestate_RAMWrEn && (Savestate_RAMType == 1);
wire [7:0]  Savestate_MAPRAMWriteData = Savestate_RAMWriteData;
wire [7:0]  Savestate_MAPRAMReadData;

assign Savestate_RAMReadData = (Savestate_RAMType == 0) ? Savestate_OAMReadData : 
										 (Savestate_RAMType == 1) ? Savestate_MAPRAMReadData :
										 Savestate_SDRAMReadData;

assign SaveStateExt_Din  = SaveStateBus_Din;
assign SaveStateExt_Adr  = SaveStateBus_Adr;
assign SaveStateExt_wren = SaveStateBus_wren;
assign SaveStateExt_rst  = SaveStateBus_rst;
assign SaveStateExt_load = loading_savestate;

 
savestates savestates (
	.clk                    (clk),
	.reset_in               (reset_nes),
	.reset_ss               (reset_ss),
	.reset_delay            (reset_delay),
	
	.load_done              (state_loaded),
	
	.increaseSSHeaderCount  (increaseSSHeaderCount),
	.save                   (savestate_savestate),
	.load                   (savestate_loadstate),
	.savestate_address      (savestate_address),
	.savestate_busy         (savestate_busy),      
	
	.paused                 (corepause_active_delay),
	
	.BUS_Din                (SaveStateBus_Din), 
	.BUS_Adr                (SaveStateBus_Adr), 
	.BUS_wren               (SaveStateBus_wren), 
	.BUS_rst                (SaveStateBus_rst), 
	.BUS_Dout               (SaveStateBus_Dout),
		
	.loading_savestate      (loading_savestate),
	.saving_savestate       (saving_savestate),
	.sleep_savestate        (sleep_savestates),
	
	.Save_RAMAddr           (Savestate_RAMAddr),     
	.Save_RAMRdEn           (Savestate_RAMRdEn),           
	.Save_RAMWrEn           (Savestate_RAMWrEn),           
	.Save_RAMWriteData      (Savestate_RAMWriteData),   
	.Save_RAMReadData       (Savestate_RAMReadData),
	.Save_RAMType           (Savestate_RAMType),
				
	.bus_out_Din            (SAVE_out_Din),   
	.bus_out_Dout           (SAVE_out_Dout),  
	.bus_out_Adr            (SAVE_out_Adr),   
	.bus_out_rnw            (SAVE_out_rnw),   
	.bus_out_ena            (SAVE_out_ena),   
	.bus_out_be             (SAVE_out_be),   
	.bus_out_done           (SAVE_out_done)  
);

statemanager #(58720256, 33554432) statemanager (
	.clk                 (clk),
	.reset               (reset_nes),
	
	.rewind_on           (1'b0),    
	.rewind_active       (1'b0),
	
	.savestate_number    (savestate_number),
	.save                (save_state),
	.load                (load_state),
	
	.sleep_rewind        (sleep_rewind),
	.vsync               (1'b0),       
	
	.request_savestate   (savestate_savestate),
	.request_loadstate   (savestate_loadstate),
	.request_address     (savestate_address),  
	.request_busy        (savestate_busy)     
);

assign sleep_savestate = sleep_rewind | sleep_savestates;

endmodule
