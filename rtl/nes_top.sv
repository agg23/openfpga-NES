module nes_top (
    input clk_74a,
    input clk_ppu_21_47,
    input clk_85_9,
    input clock_locked,

    input [1:0] sys_type,

    // Control
    input wire external_reset,

    // Inputs
    input wire p1_button_a,
    input wire p1_button_b,
    input wire p1_button_a_turbo,
    input wire p1_button_b_turbo,
    input wire p1_button_start,
    input wire p1_button_select,
    input wire p1_dpad_up,
    input wire p1_dpad_down,
    input wire p1_dpad_left,
    input wire p1_dpad_right,

    input wire [7:0] p1_lstick_x,
    input wire [7:0] p1_lstick_y,

    input wire p2_button_a,
    input wire p2_button_b,
    input wire p2_button_a_turbo,
    input wire p2_button_b_turbo,
    input wire p2_button_start,
    input wire p2_button_select,
    input wire p2_dpad_up,
    input wire p2_dpad_down,
    input wire p2_dpad_left,
    input wire p2_dpad_right,

    input wire p3_button_a,
    input wire p3_button_b,
    input wire p3_button_a_turbo,
    input wire p3_button_b_turbo,
    input wire p3_button_start,
    input wire p3_button_select,
    input wire p3_dpad_up,
    input wire p3_dpad_down,
    input wire p3_dpad_left,
    input wire p3_dpad_right,

    input wire p4_button_a,
    input wire p4_button_b,
    input wire p4_button_a_turbo,
    input wire p4_button_b_turbo,
    input wire p4_button_start,
    input wire p4_button_select,
    input wire p4_dpad_up,
    input wire p4_dpad_down,
    input wire p4_dpad_left,
    input wire p4_dpad_right,

    //Analogizer SNAC Zapper (always on P2 port)
    input wire SNAC_Zapper_Trigger,
    input wire SNAC_Zapper_Light,

    // Settings
    input wire hide_overscan,
    input wire [1:0] mask_vid_edges,
    input wire allow_extra_sprites,
    input wire [2:0] selected_palette,

    input wire multitap_enabled,
    input wire [1:0] lightgun_enabled, //added bit one to check for Analogizer SNAC Zapper
    input wire [7:0] lightgun_dpad_aim_speed,

    input wire [2:0] turbo_speed,
    input wire swap_controllers,

    // Data in
    input wire        ioctl_wr,
    input wire [27:0] ioctl_addr,
    input wire [ 7:0] ioctl_dout,
    input wire        ioctl_download,

    input wire palette_download,
    input wire is_downloading,

    // Save data
    output wire has_save,
    input wire sd_buff_wr,
    input wire sd_buff_rd,
    input wire [17:0] sd_buff_addr,
    output wire [7:0] sd_buff_din,
    input wire [7:0] sd_buff_dout,

    // Save states
    output wire mapper_has_savestate,

    input wire ss_save,
    input wire ss_load,

    output wire [63:0] ss_din,
    input wire [63:0] ss_dout,
    output wire [25:0] ss_addr,
    output wire ss_rnw,
    output wire ss_req,
    output wire [7:0] ss_be,
    input wire ss_ack,

    output wire ss_busy,

    // SDRAM
    output wire [12:0] dram_a,
    output wire [ 1:0] dram_ba,
    inout  wire [15:0] dram_dq,
    output wire [ 1:0] dram_dqm,
    output wire        dram_clk,
    output wire        dram_cke,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,

    // Video
    output HSync,
    output VSync,
    output HBlank,
    output VBlank,
    output [7:0] video_r,
    output [7:0] video_g,
    output [7:0] video_b,

    // Audio
    output [15:0] audio
);

  // File types
  wire type_nsf = 0;
  wire type_fds = 0;
  wire type_nes = 1;
  wire type_bios = 0;

  wire is_bios = 0;

  // Temp wires
  wire                               [127:0] status = 0;

  wire                               [  1:0]                   nes_ce;

  wire gg_code = 0;
  wire gg_reset = 0;
  wire gg_avail = 0;

  wire int_audio = 1;
  wire ext_audio = 1;

  wire                               [  5:0]                   color;
  wire                               [  2:0]                   emphasis;
  wire                               [  8:0]                   cycle;
  wire                               [  8:0]                   scanline;

  wire                               [  1:0]                   diskside;
  wire fds_busy = 0;
  wire fds_eject = 0;
  wire fds_auto_eject = 0;
  wire                               [  1:0] max_diskside = 0;

  wire                               [ 24:0]                   cpu_addr;
  wire                                                         cpu_read;
  wire                                                         cpu_write;
  wire                               [  7:0]                   cpu_dout;
  wire                               [  7:0]                   cpu_din;

  wire                               [ 21:0]                   ppu_addr;
  wire                                                         ppu_read;
  wire                                                         ppu_write;
  wire                               [  7:0]                   ppu_dout;
  wire                               [  7:0]                   ppu_din;

  wire                                                         state_loaded;

  wire downloading = ioctl_download;

  // pause
  reg                                                          pausecore;
  reg                                [  1:0]                   videopause_ce;
  wire                                                         corepaused;
  wire                                                         refresh;
  wire                                                         sleep_savestate;

  wire pal_video = |sys_type;

  always_ff @(posedge clk_ppu_21_47) begin
    pausecore <= sleep_savestate;

    if (!corepaused) begin
      videopause_ce <= nes_ce + 1'd1;
    end else begin
      videopause_ce <= videopause_ce + 1'd1;
    end
  end


  NES nes (
      .clk           (clk_ppu_21_47),
      .reset_nes     (reset_nes),
      .cold_reset    (downloading & (type_fds | type_nes)),
      .pausecore     (pausecore),
      .corepaused    (corepaused),
      .sys_type      (sys_type),
      .nes_div       (nes_ce),
      .mapper_flags  (downloading ? 64'd0 : mapper_flags),
      .gg            (status[20]),
      .gg_code       (gg_code),
      .gg_reset      (gg_reset && loader_clk && !ioctl_addr),
      .gg_avail      (gg_avail),
      // Audio
      .sample        (audio),
      .audio_channels(5'b11111),
      .int_audio     (int_audio),
      .ext_audio     (ext_audio),
      // Video
      //.ex_sprites    (allow_extra_sprites),
      .ex_sprites    (1'b0),
      .color         (color),
      .emphasis      (emphasis),
      .cycle         (cycle),
      .scanline      (scanline),
      .mask          (mask_vid_edges),
      // User Input
      .joypad_out    (joypad_out),
      .joypad_clock  (joypad_clock),
      .joypad1_data  (joypad1_data),
      .joypad2_data  (joypad2_data),

      .diskside      (diskside),
      .fds_busy      (fds_busy),
      .fds_eject     (fds_eject),
      .fds_auto_eject(fds_auto_eject),
      .max_diskside  (max_diskside),

      // Memory transactions
      .cpumem_addr (cpu_addr),
      .cpumem_read (cpu_read),
      .cpumem_write(cpu_write),
      .cpumem_dout (cpu_dout),
      .cpumem_din  (cpu_din),
      .ppumem_addr (ppu_addr),
      .ppumem_read (ppu_read),
      .ppumem_write(ppu_write),
      .ppumem_dout (ppu_dout),
      .ppumem_din  (ppu_din),
      .refresh     (refresh),

      .prg_mask(prg_mask),
      .chr_mask(chr_mask),

      .bram_addr    (bram_addr),
      .bram_din     (bram_din),
      .bram_dout    (bram_dout),
      .bram_write   (bram_write),
      .bram_override(bram_en),
      // .save_written (save_written),

      // savestates
      .mapper_has_savestate (mapper_has_savestate),
      .increaseSSHeaderCount(1),
      .save_state           (ss_save),
      .load_state           (ss_load),
      .savestate_number     (0),
      .sleep_savestate      (sleep_savestate),

      .Savestate_SDRAMAddr     (Savestate_SDRAMAddr),
      .Savestate_SDRAMRdEn     (Savestate_SDRAMRdEn),
      .Savestate_SDRAMWrEn     (Savestate_SDRAMWrEn),
      .Savestate_SDRAMWriteData(Savestate_SDRAMWriteData),
      .Savestate_SDRAMReadData (Savestate_SDRAMReadData),

      .SaveStateExt_Din (SaveStateBus_Din),
      .SaveStateExt_Adr (SaveStateBus_Adr),
      .SaveStateExt_wren(SaveStateBus_wren),
      .SaveStateExt_rst (SaveStateBus_rst),
      .SaveStateExt_Dout(SaveStateBus_Dout),
      .SaveStateExt_load(savestate_load),

      .savestate_busy(ss_busy),

      .SAVE_out_Din(ss_din),  // data read from savestate
      .SAVE_out_Dout(ss_dout),  // data written to savestate
      .SAVE_out_Adr(ss_addr),  // all addresses are DWORD addresses!
      .SAVE_out_rnw(ss_rnw),  // read = 1, write = 0
      .SAVE_out_ena(ss_req),  // one cycle high for each action
      .SAVE_out_be(ss_be),
      .SAVE_out_done(ss_ack)  // should be one cycle high when write is done or read value is valid
  );

  // Turbo

  wire p1_a_turbo;
  wire p1_b_turbo;

  wire p2_a_turbo;
  wire p2_b_turbo;

  wire p3_a_turbo;
  wire p3_b_turbo;

  wire p4_a_turbo;
  wire p4_b_turbo;

  button_turbo p1_turbo (
      .clk(clk_ppu_21_47),

      .turbo_speed(turbo_speed),
      .vsync(VSync),

      .a_button_turbo(p1_button_a_turbo),
      .b_button_turbo(p1_button_b_turbo),

      .a_turbo(p1_a_turbo),
      .b_turbo(p1_b_turbo)
  );

  button_turbo p2_turbo (
      .clk(clk_ppu_21_47),

      .turbo_speed(turbo_speed),
      .vsync(VSync),

      .a_button_turbo(p2_button_a_turbo),
      .b_button_turbo(p2_button_b_turbo),

      .a_turbo(p2_a_turbo),
      .b_turbo(p2_b_turbo)
  );

  button_turbo p3_turbo (
      .clk(clk_ppu_21_47),

      .turbo_speed(turbo_speed),
      .vsync(VSync),

      .a_button_turbo(p3_button_a_turbo),
      .b_button_turbo(p3_button_b_turbo),

      .a_turbo(p3_a_turbo),
      .b_turbo(p3_b_turbo)
  );

  button_turbo p4_turbo (
      .clk(clk_ppu_21_47),

      .turbo_speed(turbo_speed),
      .vsync(VSync),

      .a_button_turbo(p4_button_a_turbo),
      .b_button_turbo(p4_button_b_turbo),

      .a_turbo(p4_a_turbo),
      .b_turbo(p4_b_turbo)
  );

  // Controllers

  wire [2:0] joypad_out;
  wire [1:0] joypad_clock;
  reg [23:0] joypad_bits;
  reg [23:0] joypad_bits2;
  reg [1:0] last_joypad_clock;
  wire joy_swap = swap_controllers;

  wire mic = 0;
  wire paddle_en = 0;
  wire paddle_btn = 0;
  wire [4:0] joypad1_data = {2'b0, mic, paddle_en & paddle_btn, joypad_bits[0]};
  // Upper 4 bits are other peripherals
  wire [4:0] joypad2_data = {(lightgun_enabled[1] ? SNAC_Zapper_Trigger : trigger),  (lightgun_enabled[1] ? SNAC_Zapper_Light : light), 2'b0, joypad_bits2[0]}; //Added check for Analogizer SNAC Zapper

  wire [7:0] nes_joy_A = {
    p1_dpad_right,
    p1_dpad_left,
    p1_dpad_down,
    p1_dpad_up,
    p1_button_start,
    p1_button_select,
    p1_button_b || p1_b_turbo,
    p1_button_a || p1_a_turbo
  };

  wire [7:0] nes_joy_B = {
    p2_dpad_right,
    p2_dpad_left,
    p2_dpad_down,
    p2_dpad_up,
    p2_button_start,
    p2_button_select,
    p2_button_b || p2_b_turbo,
    p2_button_a || p2_a_turbo
  };

  wire [7:0] nes_joy_C = {
    p3_dpad_right,
    p3_dpad_left,
    p3_dpad_down,
    p3_dpad_up,
    p3_button_start,
    p3_button_select,
    p3_button_b || p3_b_turbo,
    p3_button_a || p3_a_turbo
  };

  wire [7:0] nes_joy_D = {
    p4_dpad_right,
    p4_dpad_left,
    p4_dpad_down,
    p4_dpad_up,
    p4_button_start,
    p4_button_select,
    p4_button_b || p4_b_turbo,
    p4_button_a || p4_a_turbo
  };

  wire [1:0] reticle;
  wire trigger;
  wire light;

  zapper zap (
      .clk(clk_ppu_21_47),
      .reset(reset_nes | ~lightgun_enabled[0]),
      .dpad_up(p1_dpad_up),
      .dpad_down(p1_dpad_down),
      .dpad_left(p1_dpad_left),
      .dpad_right(p1_dpad_right),
      .dpad_aim_speed(lightgun_dpad_aim_speed),
      .analog({p1_lstick_y, p1_lstick_x}),
      .analog_trigger(p1_button_a),
      .cycle(cycle),
      .scanline(scanline),
      .vde(~VBlank),
      .color(color),
      .reticle(reticle),
      .light(light),
      .trigger(trigger)
  );

  always @(posedge clk_ppu_21_47) begin
    if (reset_nes) begin
      joypad_bits <= 0;
      // joypad_bits2 <= 0;
      // joypad_d3 <= 0;
      // joypad_d4 <= 0;
      last_joypad_clock <= 0;
    end else begin
      if (joypad_out[0]) begin
        joypad_bits <= {
          multitap_enabled ? {8'h08, nes_joy_C} : 16'hFFFF, joy_swap ? nes_joy_B : nes_joy_A
        };
        joypad_bits2 <= {
          multitap_enabled ? {8'h04, nes_joy_D} : 16'hFFFF, joy_swap ? nes_joy_A : nes_joy_B
        };

        // joypad_d4 <= paddle_en ? paddle_nes : {4'b1111, powerpad[7], powerpad[11], powerpad[2], powerpad[3]};
        // joypad_d3 <= {
        //   powerpad[6],
        //   powerpad[10],
        //   powerpad[9],
        //   powerpad[5],
        //   powerpad[8],
        //   powerpad[4],
        //   powerpad[0],
        //   powerpad[1]
        // };
      end
      if (!joypad_clock[0] && last_joypad_clock[0]) begin
        joypad_bits <= {1'b0, joypad_bits[23:1]};
      end
      if (!joypad_clock[1] && last_joypad_clock[1]) begin
        joypad_bits2 <= {1'b0, joypad_bits2[23:1]};
        // joypad_d4 <= {~paddle_en, joypad_d4[7:1]};
        // joypad_d3 <= {1'b1, joypad_d3[7:1]};
      end
      last_joypad_clock <= joypad_clock;
    end
  end

  // Loading
  wire [7:0] file_input = ioctl_dout;
  //   wire [7:0] loader_input = (loader_busy && !downloading) ? !nsf ? bios_data : nsf_data : file_input;
  wire [7:0] loader_input = file_input;
  wire loader_clk = ioctl_wr;
  wire [24:0] loader_addr;
  wire [7:0] loader_write_data;
  reg loader_reset;
  wire loader_write;
  wire [63:0] loader_flags;
  reg [63:0] mapper_flags;
  wire fds = (mapper_flags[7:0] == 8'h14);
  wire nsf = (loader_flags[7:0] == 8'h1F);
  wire piano = (mapper_flags[30]);
  wire [3:0] prg_nvram = mapper_flags[34:31];
  wire loader_busy, loader_done, loader_fail;
  wire [9:0] prg_mask, chr_mask;
  assign has_save = mapper_flags[25];

  GameLoader loader (
      .clk         (clk_ppu_21_47),
      .reset       (loader_reset),
      .downloading (downloading),
      .filetype    ({4'b0000, type_nsf, type_fds, type_nes, type_bios}),
      .is_bios     (is_bios),                                             // boot0 bios
      .indata      (loader_input),
      .indata_clk  (loader_clk),
      .mem_addr    (loader_addr),
      .mem_data    (loader_write_data),
      .mem_write   (loader_write),
      .mapper_flags(loader_flags),
      .prg_mask    (prg_mask),
      .chr_mask    (chr_mask),
      .busy        (loader_busy),
      .done        (loader_done),
      .error       (loader_fail)
      // .rom_loaded  (rom_loaded)
  );

  always @(posedge clk_ppu_21_47) if (loader_done) mapper_flags <= loader_flags;

  // reset after download
  reg [7:0] download_reset_cnt;
  wire download_reset = download_reset_cnt != 0;
  always @(posedge clk_ppu_21_47) begin
    if (downloading) download_reset_cnt <= 8'hFF;
    else if (!loader_busy && download_reset_cnt) download_reset_cnt <= download_reset_cnt - 1'd1;
  end

  // hold machine in reset until first download starts
  reg init_reset_n = 0;
  always @(posedge clk_ppu_21_47) if (downloading) init_reset_n <= 1;

  always_ff @(posedge clk_ppu_21_47) begin
    reg old_downld;

    old_downld   <= downloading;
    loader_reset <= !download_reset || (~old_downld && downloading);
  end

  //   reg led_blink;
  //   always @(posedge clk_ppu_21_47) begin : blink_block
  //     int cnt = 0;
  //     cnt <= cnt + 1;
  //     if (cnt == 10000000) begin
  //       cnt <= 0;
  //       led_blink <= ~led_blink;
  //     end
  //     ;
  //   end

  wire reset_nes = ~init_reset_n || download_reset || loader_fail || hold_reset || external_reset || clearing_ram;
  // arm_reset || bk_loading || bk_loading_req || (old_sys_type != status[24:23]);

  //   reg [1:0] old_sys_type;
  //   always @(posedge clk_ppu_21_47) old_sys_type <= status[24:23];

  wire [17:0] bram_addr;
  wire [7:0] bram_din;
  wire [7:0] bram_dout;
  wire bram_write;
  wire bram_en;
  //   wire trigger;
  //   wire light;

  //   wire [1:0] diskside;
  //   reg diskside_info;
  //   always @(posedge clk_ppu_21_47) begin
  //     reg [1:0] old_diskside;

  //     old_diskside  <= diskside;
  //     diskside_info <= (old_diskside != diskside);
  //   end

  //   wire gg_reset = (type_fds | type_gg | type_nes | type_nsf) && ioctl_download;

  // RAM

  // loader_write -> clock when data available
  // reg loader_write_mem;
  // reg [7:0] loader_write_data_mem;
  // reg [24:0] loader_addr_mem;

  // reg loader_write_triggered;

  // always @(posedge clk_ppu_21_47) begin
  //   if (loader_write) begin
  //     loader_write_triggered <= 1'b1;
  //     loader_addr_mem <= loader_addr;
  //     loader_write_data_mem <= loader_write_data;
  //     //   ioctl_wait <= 1;
  //   end

  //   if (nes_ce == 3) begin
  //     loader_write_mem <= loader_write_triggered;
  //     if (loader_write_triggered) begin
  //       loader_write_triggered <= 1'b0;
  //     end
  //     //   else if (ioctl_wait) begin
  //     //     ioctl_wait <= 0;
  //     //   end
  //   end
  // end

  wire save_busy;

  // SDRAM controller is stupid and only detects the rising edge of read and write
  // iff the rising edge occurs on a non-busy cycle
  wire save_wr = sd_buff_wr && ~save_busy;
  wire save_rd = sd_buff_rd && ~save_busy;

  // sleep_savestate is set by NES core to indicate save state transition is occuring
  // Savestate_* is set by the NES core to control SDRAM for state
  // save_addr is set by controller in this code
  wire [24:0] ch2_addr = sleep_savestate ? Savestate_SDRAMAddr : {7'b0001111, save_addr};
  wire ch2_wr = sleep_savestate ? Savestate_SDRAMWrEn : save_wr;
  wire [7:0] ch2_din = sleep_savestate ? Savestate_SDRAMWriteData : sd_buff_dout;
  wire ch2_rd = sleep_savestate ? Savestate_SDRAMRdEn : save_rd;

  assign Savestate_SDRAMReadData = save_dout;

  sdram sdram (
      // system interface
      .clk (clk_85_9),
      .init(!clock_locked),

      // cpu/chipset interface
      .ch0_addr((downloading | loader_busy) ? loader_addr : {3'b0, ppu_addr}),
      .ch0_wr  (loader_write | ppu_write),
      .ch0_din ((downloading | loader_busy) ? loader_write_data : ppu_dout),
      .ch0_rd  (~(downloading | loader_busy) & ppu_read),
      .ch0_dout(ppu_din),
      // .ch0_busy(),

      .ch1_addr(cpu_addr),
      .ch1_wr  (cpu_write),
      .ch1_din (cpu_dout),
      .ch1_rd  (cpu_read),
      .ch1_dout(cpu_din),
      // .ch1_busy(),

      // reserved for backup ram save/load
      .ch2_addr(ch2_addr),
      .ch2_wr  (clearing_ram ? clear_wr : ch2_wr),
      .ch2_din (clearing_ram ? 0 : ch2_din),
      .ch2_rd  (ch2_rd),
      .ch2_dout(save_dout),
      .ch2_busy(save_busy),

      .refresh(refresh),
      .ss_in  (sdram_ss_in),
      .ss_load(savestate_load),
      .ss_out (sdram_ss_out),

      // Actual SDRAM interface
      .SDRAM_DQ(dram_dq),
      .SDRAM_A(dram_a),
      .SDRAM_DQML(dram_dqm[0]),
      .SDRAM_DQMH(dram_dqm[1]),
      .SDRAM_BA(dram_ba),
      //   .SDRAM_nCS(),
      .SDRAM_nWE(dram_we_n),
      .SDRAM_nRAS(dram_ras_n),
      .SDRAM_nCAS(dram_cas_n),
      .SDRAM_CLK(dram_clk),
      .SDRAM_CKE(dram_cke)
  );

  wire [7:0] save_dout;
  assign sd_buff_din = bram_en ? eeprom_dout : save_dout;

  reg did_load_save = 0;
  reg clearing_ram = 0;
  reg [17:0] clear_ram_addr = 0;
  reg [3:0] clear_div = 0;
  reg clear_wr = 0;

  reg prev_is_downloading = 0;
  reg prev_palette_download = 0;

  always @(posedge clk_85_9) begin
    prev_is_downloading   <= is_downloading;
    prev_palette_download <= palette_download;

    if (sd_buff_wr) begin
      // Save has been loaded, don't clear save RAM
      did_load_save <= 1;
    end

    if (prev_is_downloading && ~is_downloading && ~did_load_save && ~prev_palette_download) begin
      // All assets have been loaded and no save was loaded and we didn't just load a palette
      clearing_ram <= 1;
    end

    if (clearing_ram) begin
      if (clear_div > 0) begin
        clear_div <= clear_div - 1;
      end else begin
        clear_wr <= 0;
      end

      if (~clear_wr && ~save_busy) begin
        if (&clear_ram_addr) begin
          // Finished clearing RAM
          clearing_ram <= 0;
        end else begin
          // Move to next address and write
          clear_wr <= 1;
          clear_div <= 15;

          clear_ram_addr <= clear_ram_addr + 1;
        end
      end
    end
  end

  wire [7:0] eeprom_dout;
  dpram #(" ", 11) save_ram (
      .clock_a(clk_85_9),
      .address_a(clearing_ram ? clear_ram_addr : bram_addr),
      .data_a(clearing_ram ? 0 : bram_dout),
      .wren_a(clearing_ram ? clear_wr : bram_write),
      .q_a(bram_din),

      .clock_b(clk_ppu_21_47),
      .address_b(sd_buff_addr),
      .data_b(sd_buff_dout),
      .wren_b(sd_buff_wr),
      .q_b(eeprom_dout)
  );

  wire [17:0] save_addr = clearing_ram ? clear_ram_addr : sd_buff_addr;

  ///////////////////////////// savestates /////////////////////////////////

  wire [24:0]                                                           Savestate_SDRAMAddr;
  wire                                                                  Savestate_SDRAMRdEn;
  wire                                                                  Savestate_SDRAMWrEn;
  wire [ 7:0]                                                           Savestate_SDRAMWriteData;
  wire [ 7:0]                                                           Savestate_SDRAMReadData;

  wire [63:0]                                                           SaveStateBus_Din;
  wire [ 9:0]                                                           SaveStateBus_Adr;
  wire                                                                  SaveStateBus_wren;
  wire                                                                  SaveStateBus_rst;
  wire [63:0]                                                           SaveStateBus_Dout;
  wire                                                                  savestate_load;

  wire [15:0] sdram_ss_in = SS_Ext[15:0];
  wire [15:0]                                                           sdram_ss_out;

  wire [63:0]                                                           SS_Ext;
  wire [63:0]                                                           SS_Ext_BACK;
  eReg_SavestateV #(SSREG_INDEX_EXT, SSREG_DEFAULT_EXT) iREG_SAVESTATE_Ext (
      clk_ppu_21_47,
      SaveStateBus_Din,
      SaveStateBus_Adr,
      SaveStateBus_wren,
      SaveStateBus_rst,
      SaveStateBus_Dout,
      SS_Ext_BACK,
      SS_Ext
  );

  assign SS_Ext_BACK[15:0]  = sdram_ss_out;
  assign SS_Ext_BACK[63:16] = 48'b0;  // free to be used

  // wire bk_busy = 0;
  // wire bk_loading = 0;
  // wire [8:0] sd_lba = 0;
  wire OSD_STATUS = 0;
  wire bk_state = 0;

  // always @(posedge clk_ppu_21_47) begin

  //   if (~save_busy & ~save_rd & ~save_wr) save_wait <= 0;

  //   if (~bk_busy) begin
  //     save_addr <= '1;
  //     save_wait <= 0;
  //   end else if (sd_ack & ~save_busy) begin
  //     if (~bk_loading && (save_addr != {sd_lba[8:0], sd_buff_addr})) begin
  //       save_rd   <= 1;
  //       save_addr <= {sd_lba[8:0], sd_buff_addr};
  //       save_wait <= 1;
  //     end
  //     if (bk_loading && sd_buff_wr) begin
  //       save_wr   <= 1;
  //       save_addr <= {sd_lba[8:0], sd_buff_addr};
  //       save_wait <= 1;
  //     end
  //   end
  //   if (~bk_busy | save_busy | bram_en) {save_rd, save_wr} <= 0;
  // end

  // reg bk_pending;
  // wire save_written;
  // always @(posedge clk) begin
  //   if ((mapper_flags[25] || fds) && ~OSD_STATUS && save_written) bk_pending <= 1'b1;
  //   else if (bk_state) bk_pending <= 1'b0;
  // end

  ///////////////////////////////////////////////////
  // palette loader
  reg [23:0] pal_color;
  reg [5:0] pal_index;
  reg [1:0] pal_count;

  wire pal_write = palette_download ? ~|pal_count : 1'b0;

  always @(posedge clk_ppu_21_47) begin
    if (palette_download && loader_clk && ioctl_addr < 192) begin
      pal_count <= pal_count == 2 ? 2'd0 : pal_count + 2'd1;
      case (pal_count)
        0: begin
          pal_color[23:16] <= file_input;
          //pal_write <= 0;
          pal_index <= ioctl_addr > 0 ? pal_index + 1'd1 : pal_index;
        end

        1: begin
          pal_color[15:8] <= file_input;
        end

        2: begin
          pal_color[7:0] <= file_input;
          //pal_write <= 1;
        end
      endcase
    end

    if (!palette_download) begin
      //pal_write <= 0;
      pal_count <= 0;
      pal_index <= 0;
    end
  end

  // Video
  wire hold_reset;
  wire [1:0] nes_ce_video = corepaused ? videopause_ce : nes_ce;

  video video (
      .clk(clk_ppu_21_47),
      .reset(reset_nes),
      .cnt(nes_ce_video),
      .hold_reset(hold_reset),
      .color(color),
      .count_v(scanline),
      .count_h(cycle),
      .hide_overscan(hide_overscan),
      .palette(selected_palette),
      .load_color(pal_write),
      .load_color_data(pal_color),
      .load_color_index(pal_index),
      .emphasis(emphasis),
      // Zapper
      .reticle(lightgun_enabled[0] ? reticle : 2'b00),
      .pal_video(pal_video),

      // .ce_pix(ce_pix),
      .HSync(HSync),
      .VSync(VSync),
      .HBlank(HBlank),
      .VBlank(VBlank),
      .R(video_r),
      .G(video_g),
      .B(video_b)
  );

  // TODO: FDS save support
  // wire [17:0] rom_sz = 0;

  // wire [ 8:0] save_sz = fds ? rom_sz[17:9] : bram_en ? 9'd3 : (prg_nvram == 4'd7) ? 9'd15 : 9'd63;

endmodule
