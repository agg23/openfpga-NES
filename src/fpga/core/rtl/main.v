module MAIN_NES(
    input clk_ppu_21_47,
    input clk_85_9,
    input clock_locked,

    output ce_pix,
    output HSync,
    output VSync,
    output HBlank,
    output VBlank,
    output [7:0] video_r,
    output [7:0] video_g,
    output [7:0] video_b
  );

  wire loader_clk = 0;
  wire loader_busy = 0;
  wire [21:0] loader_addr_mem = 0;
  wire loader_write_mem = 0;
  wire loader_write_data_mem = 0;

  wire ioctl_addr = 0;

  wire reset_nes = 0;
  wire downloading = 0;
  wire type_fds = 0;
  wire type_nes = 1;

  wire save_written;

  wire [127:0] status = 0;

  wire nes_ce;

  wire mapper_flags = 0;

  wire gg_code = 0;
  wire gg_reset = 0;
  wire gg_avail = 0;

  wire sample;
  wire int_audio = 0;
  wire ext_audio = 0;
  wire apu_ce;

  wire color;
  wire [2:0] emphasis;
  wire [8:0] cycle;
  wire [8:0] scanline;

  wire [2:0] joypad_out;
  wire [1:0] joypad_clock;
  wire [4:0] joypad1_data = 0;
  wire [4:0] joypad2_data =0;

  wire [1:0] diskside;
  wire fds_busy = 0;
  wire fds_eject = 0;
  wire fds_auto_eject = 0;
  wire [1:0] max_diskside = 0;

  wire [24:0] cpu_addr;
  wire cpu_read;
  wire cpu_write;
  wire [7:0] cpu_dout;
  wire [7:0] cpu_din;

  wire [21:0] ppu_addr;
  wire ppu_read;
  wire ppu_write;
  wire [7:0] ppu_dout;
  wire [7:0] ppu_din;
  wire refresh;

  wire [20:0] prg_mask;
  wire [19:0] chr_mask;

  wire [17:0] bram_addr;
  wire [7:0] bram_din;
  wire [7:0] bram_dout;
  wire bram_write;
  wire bram_en;

  wire mapper_has_savestate;
  wire save_state = 0;
  wire load_state = 0;
  wire [1:0] savestate_number = 0;
  wire sleep_savestate;
  wire state_loaded;

  wire [24:0] Savestate_SDRAMAddr;
  wire Savestate_SDRAMRdEn;
  wire Savestate_SDRAMWrEn;
  wire [7:0] Savestate_SDRAMWriteData;
  wire [7:0] Savestate_SDRAMReadData;

  wire [63:0] SaveStateBus_Din;
  wire [9:0] SaveStateBus_Adr;
  wire SaveStateBus_wren;
  wire SaveStateBus_rst;
  wire [63:0] SaveStateBus_Dout = 0;
  wire savestate_load;

  wire [63:0] ss_din;
  wire [63:0] ss_dout = 0;
  wire [25:0] ss_addr;
  wire ss_rnw;
  wire ss_req;
  wire [7:0] ss_be;
  wire ss_ack = 0;

  NES nes (
        .clk             (clk_21_47),
        .reset_nes       (reset_nes),
        .cold_reset      (downloading & (type_fds | type_nes)),
        .pausecore       (0),
        // .corepaused      (corepaused),
        .sys_type        (status[24:23]),
        .nes_div         (nes_ce),
        .mapper_flags    (downloading ? 64'd0 : mapper_flags),
        .gg              (status[20]),
        .gg_code         (gg_code),
        .gg_reset        (gg_reset && loader_clk && !ioctl_addr),
        .gg_avail        (gg_avail),
        // Audio
        .sample          (sample),
        .audio_channels  (5'b11111),
        .int_audio       (int_audio),
        .ext_audio       (ext_audio),
        .apu_ce          (apu_ce),
        // Video
        .ex_sprites      (status[25]),
        .color           (color),
        .emphasis        (emphasis),
        .cycle           (cycle),
        .scanline        (scanline),
        .mask            (status[28:27]),
        // User Input
        .joypad_out      (joypad_out),
        .joypad_clock    (joypad_clock),
        .joypad1_data    (joypad1_data),
        .joypad2_data    (joypad2_data),

        .diskside        (diskside),
        .fds_busy        (fds_busy),
        .fds_eject       (fds_eject),
        .fds_auto_eject  (fds_auto_eject),
        .max_diskside    (max_diskside),

        // Memory transactions
        .cpumem_addr     (cpu_addr ),
        .cpumem_read     (cpu_read ),
        .cpumem_write    (cpu_write),
        .cpumem_dout     (cpu_dout ),
        .cpumem_din      (cpu_din  ),
        .ppumem_addr     (ppu_addr ),
        .ppumem_read     (ppu_read ),
        .ppumem_write    (ppu_write),
        .ppumem_dout     (ppu_dout ),
        .ppumem_din      (ppu_din  ),
        .refresh         (refresh  ),

        .prg_mask        (prg_mask ),
        .chr_mask        (chr_mask ),

        .bram_addr       (bram_addr),
        .bram_din        (bram_din),
        .bram_dout       (bram_dout),
        .bram_write      (bram_write),
        .bram_override   (bram_en),
        .save_written    (save_written),

        // savestates
        .mapper_has_savestate    (mapper_has_savestate),
        .increaseSSHeaderCount   (!status[44]),
        .save_state              (ss_save),
        .load_state              (ss_load),
        .savestate_number        (ss_slot),
        .sleep_savestate         (sleep_savestate),

        .Savestate_SDRAMAddr     (Savestate_SDRAMAddr     ),
        .Savestate_SDRAMRdEn     (Savestate_SDRAMRdEn     ),
        .Savestate_SDRAMWrEn     (Savestate_SDRAMWrEn     ),
        .Savestate_SDRAMWriteData(Savestate_SDRAMWriteData),
        .Savestate_SDRAMReadData (Savestate_SDRAMReadData ),

        .SaveStateExt_Din        (SaveStateBus_Din),
        .SaveStateExt_Adr        (SaveStateBus_Adr),
        .SaveStateExt_wren       (SaveStateBus_wren),
        .SaveStateExt_rst        (SaveStateBus_rst),
        .SaveStateExt_Dout       (SaveStateBus_Dout),
        .SaveStateExt_load       (savestate_load),

        .SAVE_out_Din            (ss_din),           // data read from savestate
        .SAVE_out_Dout           (ss_dout),          // data written to savestate
        .SAVE_out_Adr            (ss_addr),          // all addresses are DWORD addresses!
        .SAVE_out_rnw            (ss_rnw),           // read = 1, write = 0
        .SAVE_out_ena            (ss_req),           // one cycle high for each action
        .SAVE_out_be             (ss_be),
        .SAVE_out_done           (ss_ack)            // should be one cycle high when write is done or read value is valid
      );

  wire [15:0] sdram_ss_in = 0;
  wire [15:0] sdram_ss_out;

  sdram sdram
        (
          // system interface
          .clk        ( clk_85_9 ),
          .init       ( !clock_locked ),

          // cpu/chipset interface
          .ch0_addr   (  (downloading | loader_busy) ? loader_addr_mem       : {3'b0, ppu_addr}  ),
          .ch0_wr     (                                loader_write_mem      | ppu_write ),
          .ch0_din    (  (downloading | loader_busy) ? loader_write_data_mem : ppu_dout  ),
          .ch0_rd     ( ~(downloading | loader_busy)                         & ppu_read  ),
          .ch0_dout   ( ppu_din   ),
          .ch0_busy   ( ),

          .ch1_addr   ( cpu_addr  ),
          .ch1_wr     ( cpu_write ),
          .ch1_din    ( cpu_dout  ),
          .ch1_rd     ( cpu_read  ),
          .ch1_dout   ( cpu_din   ),
          .ch1_busy   ( ),

          // reserved for backup ram save/load
          // .ch2_addr   ( ch2_addr ),
          // .ch2_wr     ( ch2_wr ),
          // .ch2_din    ( ch2_din ),
          // .ch2_rd     ( ch2_rd ),
          // .ch2_dout   ( save_dout ),
          // .ch2_busy   ( save_busy ),

          .refresh    (refresh  ),
          .ss_in      (sdram_ss_in),
          .ss_load    (savestate_load),
          .ss_out     (sdram_ss_out)
        );

  reg  [31:0] sd_lba = 0;
  wire        sd_ack;
  wire  [8:0] sd_buff_addr;
  wire  [7:0] sd_buff_dout;
  wire  [7:0] sd_buff_din;
  wire        sd_buff_wr;

  wire [7:0] eeprom_dout;

  dpram #(" ", 11) eeprom
        (
          .clock_a(clk_85_9),
          .address_a(bram_addr),
          .data_a(bram_dout),
          .wren_a(bram_write),
          .q_a(bram_din),

          .clock_b(clk_21_47),
          .address_b({sd_lba[1:0],sd_buff_addr}),
          .data_b(sd_buff_dout),
          .wren_b(sd_buff_wr & sd_ack),
          .q_b(eeprom_dout)
        );

  wire hold_reset;
  // wire [1:0] nes_ce_video = corepaused ? videopause_ce : nes_ce;
  wire [1:0] nes_ce_video = nes_ce;

  wire hide_overscan = 0;
  wire [3:0] palette2_osd = 0;
  wire pal_video = 0;

  video video
        (
          .clk(clk_ppu_21_47),
          .reset(reset_nes),
          .cnt(nes_ce_video),
          .hold_reset(hold_reset),
          .color(color),
          .count_v(scanline),
          .count_h(cycle),
          .hide_overscan(hide_overscan),
          .palette(palette2_osd),
          // .load_color(pal_write && ioctl_download),
          // .load_color_data(pal_color),
          // .load_color_index(pal_index),
          .emphasis(emphasis),
          // Zapper
          // .reticle(~status[22] ? reticle : 2'b00),
          .pal_video(pal_video),

          .ce_pix(ce_pix),
          .HSync(HSync),
          .VSync(VSync),
          .HBlank(HBlank),
          .VBlank(VBlank),
          .R(video_r),
          .G(video_g),
          .B(video_b)
        );



endmodule
