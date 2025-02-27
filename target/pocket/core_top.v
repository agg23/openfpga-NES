//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

    //
    // physical connections
    //

    ///////////////////////////////////////////////////
    // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

    input wire clk_74a,  // mainclk1
    input wire clk_74b,  // mainclk1

    ///////////////////////////////////////////////////
    // cartridge interface
    // switches between 3.3v and 5v mechanically
    // output enable for multibit translators controlled by pic32

    // GBA AD[15:8]
    inout  wire [7:0] cart_tran_bank2,
    output wire       cart_tran_bank2_dir,

    // GBA AD[7:0]
    inout  wire [7:0] cart_tran_bank3,
    output wire       cart_tran_bank3_dir,

    // GBA A[23:16]
    inout  wire [7:0] cart_tran_bank1,
    output wire       cart_tran_bank1_dir,

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    inout  wire [7:4] cart_tran_bank0,
    output wire       cart_tran_bank0_dir,

    // GBA CS2#/RES#
    inout  wire cart_tran_pin30,
    output wire cart_tran_pin30_dir,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output wire cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    inout  wire cart_tran_pin31,
    output wire cart_tran_pin31_dir,

    // infrared
    input  wire port_ir_rx,
    output wire port_ir_tx,
    output wire port_ir_rx_disable,

    // GBA link port
    inout  wire port_tran_si,
    output wire port_tran_si_dir,
    inout  wire port_tran_so,
    output wire port_tran_so_dir,
    inout  wire port_tran_sck,
    output wire port_tran_sck_dir,
    inout  wire port_tran_sd,
    output wire port_tran_sd_dir,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

    output wire [21:16] cram0_a,
    inout  wire [ 15:0] cram0_dq,
    input  wire         cram0_wait,
    output wire         cram0_clk,
    output wire         cram0_adv_n,
    output wire         cram0_cre,
    output wire         cram0_ce0_n,
    output wire         cram0_ce1_n,
    output wire         cram0_oe_n,
    output wire         cram0_we_n,
    output wire         cram0_ub_n,
    output wire         cram0_lb_n,

    output wire [21:16] cram1_a,
    inout  wire [ 15:0] cram1_dq,
    input  wire         cram1_wait,
    output wire         cram1_clk,
    output wire         cram1_adv_n,
    output wire         cram1_cre,
    output wire         cram1_ce0_n,
    output wire         cram1_ce1_n,
    output wire         cram1_oe_n,
    output wire         cram1_we_n,
    output wire         cram1_ub_n,
    output wire         cram1_lb_n,

    ///////////////////////////////////////////////////
    // sdram, 512mbit 16bit

    output wire [12:0] dram_a,
    output wire [ 1:0] dram_ba,
    inout  wire [15:0] dram_dq,
    output wire [ 1:0] dram_dqm,
    output wire        dram_clk,
    output wire        dram_cke,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,

    ///////////////////////////////////////////////////
    // sram, 1mbit 16bit

    output wire [16:0] sram_a,
    inout  wire [15:0] sram_dq,
    output wire        sram_oe_n,
    output wire        sram_we_n,
    output wire        sram_ub_n,
    output wire        sram_lb_n,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input wire vblank,

    ///////////////////////////////////////////////////
    // i/o to 6515D breakout usb uart

    output wire dbg_tx,
    input  wire dbg_rx,

    ///////////////////////////////////////////////////
    // i/o pads near jtag connector user can solder to

    output wire user1,
    input  wire user2,

    ///////////////////////////////////////////////////
    // RFU internal i2c bus

    inout  wire aux_sda,
    output wire aux_scl,

    ///////////////////////////////////////////////////
    // RFU, do not use
    output wire vpll_feed,


    //
    // logical connections
    //

    ///////////////////////////////////////////////////
    // video, audio output to scaler
    output wire [23:0] video_rgb,
    output wire        video_rgb_clock,
    output wire        video_rgb_clock_90,
    output wire        video_de,
    output wire        video_skip,
    output wire        video_vs,
    output wire        video_hs,

    output wire audio_mclk,
    input  wire audio_adc,
    output wire audio_dac,
    output wire audio_lrck,

    ///////////////////////////////////////////////////
    // bridge bus connection
    // synchronous to clk_74a
    output wire        bridge_endian_little,
    input  wire [31:0] bridge_addr,
    input  wire        bridge_rd,
    output reg  [31:0] bridge_rd_data,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    ///////////////////////////////////////////////////
    // controller data
    //
    // key bitmap:
    //   [0]    dpad_up
    //   [1]    dpad_down
    //   [2]    dpad_left
    //   [3]    dpad_right
    //   [4]    face_a
    //   [5]    face_b
    //   [6]    face_x
    //   [7]    face_y
    //   [8]    trig_l1
    //   [9]    trig_r1
    //   [10]   trig_l2
    //   [11]   trig_r2
    //   [12]   trig_l3
    //   [13]   trig_r3
    //   [14]   face_select
    //   [15]   face_start
    // joy values - unsigned
    //   [ 7: 0] lstick_x
    //   [15: 8] lstick_y
    //   [23:16] rstick_x
    //   [31:24] rstick_y
    // trigger values - unsigned
    //   [ 7: 0] ltrig
    //   [15: 8] rtrig
    //
    input wire [15:0] cont1_key,
    input wire [15:0] cont2_key,
    input wire [15:0] cont3_key,
    input wire [15:0] cont4_key,
    input wire [31:0] cont1_joy,
    input wire [31:0] cont2_joy,
    input wire [31:0] cont3_joy,
    input wire [31:0] cont4_joy,
    input wire [15:0] cont1_trig,
    input wire [15:0] cont2_trig,
    input wire [15:0] cont3_trig,
    input wire [15:0] cont4_trig

);

  // not using the IR port, so turn off both the LED, and
  // disable the receive circuit to save power
  assign port_ir_tx              = 0;
  assign port_ir_rx_disable      = 1;

  // bridge endianness
  assign bridge_endian_little    = 0;

  // cart is unused, so set all level translators accordingly
  // directions are 0:IN, 1:OUT
//  assign cart_tran_bank3         = 8'hzz;
//  assign cart_tran_bank3_dir     = 1'b0;
//  assign cart_tran_bank2         = 8'hzz;
//  assign cart_tran_bank2_dir     = 1'b0;
//  assign cart_tran_bank1         = 8'hzz;
//  assign cart_tran_bank1_dir     = 1'b0;
//  assign cart_tran_bank0         = 4'hf;
//  assign cart_tran_bank0_dir     = 1'b1;
//  assign cart_tran_pin30         = 1'b0;  // reset or cs2, we let the hw control it by itself
//  assign cart_tran_pin30_dir     = 1'bz;
//  assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
//  assign cart_tran_pin31         = 1'bz;  // input
//  assign cart_tran_pin31_dir     = 1'b0;  // input

  // link port is input only
  assign port_tran_so            = 1'bz;
  assign port_tran_so_dir        = 1'b0;  // SO is output only
  assign port_tran_si            = 1'bz;
  assign port_tran_si_dir        = 1'b0;  // SI is input only
  assign port_tran_sck           = 1'bz;
  assign port_tran_sck_dir       = 1'b0;  // clock direction can change
  assign port_tran_sd            = 1'bz;
  assign port_tran_sd_dir        = 1'b0;  // SD is input and not used

  // tie off the rest of the pins we are not using
  assign cram0_a                 = 'h0;
  assign cram0_dq                = {16{1'bZ}};
  assign cram0_clk               = 0;
  assign cram0_adv_n             = 1;
  assign cram0_cre               = 0;
  assign cram0_ce0_n             = 1;
  assign cram0_ce1_n             = 1;
  assign cram0_oe_n              = 1;
  assign cram0_we_n              = 1;
  assign cram0_ub_n              = 1;
  assign cram0_lb_n              = 1;

  assign cram1_a                 = 'h0;
  assign cram1_dq                = {16{1'bZ}};
  assign cram1_clk               = 0;
  assign cram1_adv_n             = 1;
  assign cram1_cre               = 0;
  assign cram1_ce0_n             = 1;
  assign cram1_ce1_n             = 1;
  assign cram1_oe_n              = 1;
  assign cram1_we_n              = 1;
  assign cram1_ub_n              = 1;
  assign cram1_lb_n              = 1;

  assign sram_a                  = 'h0;
  assign sram_dq                 = {16{1'bZ}};
  assign sram_oe_n               = 1;
  assign sram_we_n               = 1;
  assign sram_ub_n               = 1;
  assign sram_lb_n               = 1;

  assign dbg_tx                  = 1'bZ;
  assign user1                   = 1'bZ;
  assign aux_scl                 = 1'bZ;
  assign vpll_feed               = 1'bZ;


  localparam [7:0] ADDRESS_ANALOGIZER_CONFIG = 8'hF7;
  // for bridge write data, we just broadcast it to all bus devices
  // for bridge read data, we have to mux it
  // add your own devices here
  wire [31:0] analogizer_bridge_rd_data;
  always @(*) begin
    casex (bridge_addr[31:24])
      default: begin
        bridge_rd_data <= 0;
      end
      ADDRESS_ANALOGIZER_CONFIG: begin bridge_rd_data <= analogizer_bridge_rd_data; end
      8'hF8: begin bridge_rd_data <= cmd_bridge_rd_data; end
    endcase

    if (bridge_addr[31:28] == 4'h2) begin
      bridge_rd_data <= sd_read_data;
    end else if (bridge_addr[31:28] == 4'h4) begin
      bridge_rd_data <= save_state_bridge_read_data;
    end
  end

  always @(posedge clk_74a) begin
    if (reset_delay > 0) begin
      reset_delay <= reset_delay - 1;
    end

    if (bridge_wr) begin
      casex (bridge_addr)
        32'h050: begin
          reset_delay <= 32'h100000;
        end
//        32'h054: begin
//          region <= bridge_wr_data[1:0];
//        end
        32'h200: begin
          hide_overscan <= bridge_wr_data[0];
        end
        32'h204: begin
          mask_vid_edges <= bridge_wr_data[1:0];
        end
        32'h208: begin
          allow_extra_sprites <= bridge_wr_data[0];
        end
        32'h20C: begin
          selected_palette <= bridge_wr_data[2:0];
        end
        32'h210: begin
          square_pixels <= bridge_wr_data[0];
        end
        32'h300: begin
          multitap_enabled <= bridge_wr_data[0];
        end
        32'h304: begin
          lightgun_enabled <= bridge_wr_data[1:0]; //Modified to add support for Analogizer SNAC Zapper lightgun
        end
        32'h308: begin
          lightgun_dpad_aim_speed <= bridge_wr_data[7:0];
        end
        32'h30C: begin
          swap_controllers <= bridge_wr_data[0];
        end
        32'h310: begin
          turbo_speed <= bridge_wr_data[2:0];
        end
      endcase
    end
  end

  //
  // host/target command handler
  //
  wire reset_n;  // driven by host commands, can be used as core-wide reset
  wire [31:0] cmd_bridge_rd_data;

  // bridge host commands
  // synchronous to clk_74a
  wire status_boot_done = pll_core_locked;
  wire status_setup_done = pll_core_locked;  // rising edge triggers a target command
  wire status_running = reset_n;  // we are running as soon as reset_n goes high

  wire dataslot_requestread;
  wire [15:0] dataslot_requestread_id;
  wire dataslot_requestread_ack = 1;
  wire dataslot_requestread_ok = 1;

  wire dataslot_requestwrite;
  wire [15:0] dataslot_requestwrite_id;
  wire dataslot_requestwrite_ack = 1;
  wire dataslot_requestwrite_ok = 1;

  wire dataslot_allcomplete;

  // TODO: Use mapper_has_savestate (and sync it)
  wire savestate_supported = 1;
  wire [31:0] savestate_addr = 32'h40000000;
  wire [31:0] savestate_size = 32'h144008;
  // Add buffer of 0x1000 for extra data that we'll just discard on loading
  wire [31:0] savestate_maxloadsize = savestate_size + 32'h1000;

  wire savestate_start;
  wire savestate_start_ack;
  wire savestate_start_busy;
  wire savestate_start_ok;
  wire savestate_start_err;

  wire savestate_load;
  wire savestate_load_ack;
  wire savestate_load_busy;
  wire savestate_load_ok;
  wire savestate_load_err;

  core_bridge_cmd icb (

      .clk    (clk_74a),
      .reset_n(reset_n),

      .bridge_endian_little(bridge_endian_little),
      .bridge_addr         (bridge_addr),
      .bridge_rd           (bridge_rd),
      .bridge_rd_data      (cmd_bridge_rd_data),
      .bridge_wr           (bridge_wr),
      .bridge_wr_data      (bridge_wr_data),

      .status_boot_done (status_boot_done),
      .status_setup_done(status_setup_done),
      .status_running   (status_running),

      .dataslot_requestread    (dataslot_requestread),
      .dataslot_requestread_id (dataslot_requestread_id),
      .dataslot_requestread_ack(dataslot_requestread_ack),
      .dataslot_requestread_ok (dataslot_requestread_ok),

      .dataslot_requestwrite    (dataslot_requestwrite),
      .dataslot_requestwrite_id (dataslot_requestwrite_id),
      .dataslot_requestwrite_ack(dataslot_requestwrite_ack),
      .dataslot_requestwrite_ok (dataslot_requestwrite_ok),

      .dataslot_allcomplete(dataslot_allcomplete),

      .savestate_supported  (savestate_supported),
      .savestate_addr       (savestate_addr),
      .savestate_size       (savestate_size),
      .savestate_maxloadsize(savestate_maxloadsize),

      .savestate_start     (savestate_start),
      .savestate_start_ack (savestate_start_ack),
      .savestate_start_busy(savestate_start_busy),
      .savestate_start_ok  (savestate_start_ok),
      .savestate_start_err (savestate_start_err),

      .savestate_load     (savestate_load),
      .savestate_load_ack (savestate_load_ack),
      .savestate_load_busy(savestate_load_busy),
      .savestate_load_ok  (savestate_load_ok),
      .savestate_load_err (savestate_load_err),

      .datatable_addr(datatable_addr),
      .datatable_wren(datatable_wren),
      .datatable_data(datatable_data),
      .datatable_q   (datatable_q)
  );

  // bridge data slot access

  reg [9:0] datatable_addr;
  reg datatable_wren;
  reg [31:0] datatable_data;
  wire [31:0] datatable_q;

  reg is_downloading = 0;

  wire ioctl_download = is_downloading && dataslot_requestwrite_id == 0;
  wire palette_download = is_downloading && dataslot_requestwrite_id == 11;

  wire has_save;

  always @(posedge clk_74a) begin
    if (dataslot_requestwrite) is_downloading <= 1;
    else if (dataslot_allcomplete) is_downloading <= 0;
  end

  always @(posedge clk_74a or negedge pll_core_locked) begin
    if (~pll_core_locked) begin
      datatable_addr <= 0;
      datatable_data <= 0;
      datatable_wren <= 0;
    end else begin
      // Write sram size
      datatable_wren <= 1;
      datatable_data <= has_save ? 32'h40_000 : 32'h0;
      // Data slot index 1, not id 1
      datatable_addr <= 1 * 2 + 1;
    end
  end

  // Data Loader 8
  wire ioctl_wr;
  wire [7:0] ioctl_dout;
  wire [27:0] ioctl_addr;

  data_loader #(
      .ADDRESS_MASK_UPPER_4(4'h1)
  ) data_loader (
      .clk_74a(clk_74a),
      .clk_memory(clk_ppu_21_47),

      .bridge_wr(bridge_wr),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),

      .write_en  (ioctl_wr),
      .write_addr(ioctl_addr),  // Unused
      .write_data(ioctl_dout)
  );

  wire [31:0] sd_read_data;

  wire sd_buff_wr;
  wire sd_buff_rd;

  wire [17:0] sd_buff_addr_in;
  wire [17:0] sd_buff_addr_out;

  wire [17:0] sd_buff_addr = sd_buff_wr ? sd_buff_addr_in : sd_buff_addr_out;

  wire [7:0] sd_buff_din;
  wire [7:0] sd_buff_dout;

  data_unloader #(
      .ADDRESS_MASK_UPPER_4(4'h2),
      .ADDRESS_SIZE(18),
      .READ_MEM_CLOCK_DELAY(7)
  ) save_data_unloader (
      .clk_74a(clk_74a),
      .clk_memory(clk_ppu_21_47),

      .bridge_rd(bridge_rd),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_rd_data(sd_read_data),

      .read_en  (sd_buff_rd),
      .read_addr(sd_buff_addr_out),
      .read_data(sd_buff_din)
  );

  data_loader #(
      .ADDRESS_MASK_UPPER_4(4'h2),
      .ADDRESS_SIZE(18),
      .WRITE_MEM_CLOCK_DELAY(7),
      .WRITE_MEM_EN_CYCLE_LENGTH(3)
  ) save_data_loader (
      .clk_74a(clk_74a),
      .clk_memory(clk_ppu_21_47),

      .bridge_wr(bridge_wr),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),

      .write_en  (sd_buff_wr),
      .write_addr(sd_buff_addr_in),
      .write_data(sd_buff_dout)
  );

  // Save states
  // Save state unloader
  wire ss_busy;
  wire [63:0] ss_din;
  wire [63:0] ss_dout;
  wire [25:0] ss_addr;
  wire ss_rnw;
  wire ss_req;
  wire [7:0] ss_be;
  wire ss_ack;

  wire ss_save;
  wire ss_load;

  wire mapper_has_savestate;
  wire [31:0] save_state_bridge_read_data;

  save_state_controller save_state_controller (
      .clk_74a(clk_74a),
      .clk_mem_85_9(clk_85_9),
      .clk_ppu_21_47(clk_ppu_21_47),

      // APF
      .bridge_wr(bridge_wr),
      .bridge_rd(bridge_rd),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),
      .save_state_bridge_read_data(save_state_bridge_read_data),

      // APF Save States
      .savestate_load(savestate_load),
      .savestate_load_ack_s(savestate_load_ack),
      .savestate_load_busy_s(savestate_load_busy),
      .savestate_load_ok_s(savestate_load_ok),
      .savestate_load_err_s(savestate_load_err),

      .savestate_start(savestate_start),
      .savestate_start_ack_s(savestate_start_ack),
      .savestate_start_busy_s(savestate_start_busy),
      .savestate_start_ok_s(savestate_start_ok),
      .savestate_start_err_s(savestate_start_err),

      // Save States Manager
      .ss_save(ss_save),
      .ss_load(ss_load),

      .ss_din (ss_din),
      .ss_dout(ss_dout),
      .ss_addr(ss_addr),
      .ss_rnw (ss_rnw),
      .ss_req (ss_req),
      .ss_be  (ss_be),
      .ss_ack (ss_ack),

      .ss_busy(ss_busy)
  );

  // Core

  wire [15:0] cont1_key_s;
  wire [15:0] cont2_key_s;
  wire [15:0] cont3_key_s;
  wire [15:0] cont4_key_s;
  wire [31:0] cont1_joy_s;

  synch_3 #(
      .WIDTH(16)
  ) cont1_s (
      cont1_key,
      cont1_key_s,
      clk_ppu_21_47
  );

  synch_3 #(
      .WIDTH(16)
  ) cont2_s (
      cont2_key,
      cont2_key_s,
      clk_ppu_21_47
  );

  synch_3 #(
      .WIDTH(16)
  ) cont3_s (
      cont3_key,
      cont3_key_s,
      clk_ppu_21_47
  );

  synch_3 #(
      .WIDTH(16)
  ) cont4_s (
      cont4_key,
      cont4_key_s,
      clk_ppu_21_47
  );

  synch_3 #(
      .WIDTH(32)
  ) joy1_s (
      cont1_joy,
      cont1_joy_s,
      clk_ppu_21_47
  );

  // Settings
  reg [1:0] region = 0;

  reg hide_overscan = 0;
  reg [1:0] mask_vid_edges = 0;
  reg square_pixels = 0;
   reg allow_extra_sprites = 0;
   reg [2:0] selected_palette = 0;
   wire external_reset = reset_delay > 0;

   reg multitap_enabled = 0;
   reg [1:0] lightgun_enabled = 0;
   reg [7:0] lightgun_dpad_aim_speed = 0;

   reg [2:0] turbo_speed = 0;
   reg swap_controllers = 0;

  wire [1:0] region_s;

  wire hide_overscan_s;
  wire [1:0] mask_vid_edges_s;
  wire square_pixels_s;
  wire allow_extra_sprites_s;
  wire [2:0] selected_palette_s;
  wire external_reset_s;

  wire multitap_enabled_s;
  wire [1:0] lightgun_enabled_s;
  wire [7:0] lightgun_dpad_aim_speed_s;

  wire [2:0] turbo_speed_s;
  wire swap_controllers_s;

  synch_3 #(
      .WIDTH(24)
  ) settings_s (
      {
        region,
        hide_overscan,
        mask_vid_edges,
        square_pixels,
        allow_extra_sprites,
        selected_palette,
        external_reset,
        multitap_enabled,
        lightgun_enabled,
        lightgun_dpad_aim_speed,
        turbo_speed,
        swap_controllers
      },
      {
        region_s,
        hide_overscan_s,
        mask_vid_edges_s,
        square_pixels_s,
        allow_extra_sprites_s,
        selected_palette_s,
        external_reset_s,
        multitap_enabled_s,
        lightgun_enabled_s,
        lightgun_dpad_aim_speed_s,
        turbo_speed_s,
        swap_controllers_s
      },
      clk_ppu_21_47
  );

  reg [1:0] prev_region = 0;

  always @(posedge clk_ppu_21_47) begin
    prev_region <= region_s;
  end

  reg [31:0] reset_delay = 0;

  wire hide_overscan_with_region = hide_overscan_s && region_s == 2'b0;

/*[ANALOGIZER_HOOK_BEGIN]*/
//reg analogizer_ena;
wire [3:0] analogizer_video_type;
wire [4:0] snac_game_cont_type;
wire [3:0] snac_cont_assignment;
wire [2:0] SC_fx;
wire       pocket_blank_screen;
//reg       analogizer_osd_out;

wire  ANALOGIZER_DE = ~(h_blank || v_blank);
  //create aditional switch to blank Pocket screen.
  wire [23:0] video_rgb_pocket;
  assign video_rgb_pocket = (pocket_blank_screen) ? 24'h000000: video_rgb_nes;

//switch between Analogizer SNAC and Pocket Controls for P1-P4 (P3,P4 when uses PCEngine Multitap)
  wire [15:0] p1_btn, p2_btn, p3_btn, p4_btn;
  wire [31:0] p1_joy, p2_joy;
  reg [31:0] p1_joystick, p2_joystick;
  reg  [15:0] p1_controls, p2_controls, p3_controls, p4_controls;

wire snac_is_analog = (snac_game_cont_type == 5'h12) || (snac_game_cont_type == 5'h13);
wire [31:0] neutral_joystick = 32'h80808080;

always @(posedge clk_ppu_21_47) begin
	reg [31:0] p1_pocket_btn, p1_pocket_joy;
	reg [31:0] p2_pocket_btn, p2_pocket_joy;
  reg [31:0] p3_pocket_btn;
  reg [31:0] p4_pocket_btn;

    if(snac_game_cont_type == 5'h0) begin //SNAC is disabled
          p1_controls <= cont1_key_s;
				  p1_joystick <= cont1_joy_s;
          p2_controls <= cont2_key_s;
          p3_controls <= cont3_key_s;
          p4_controls <= cont4_key_s;
    end
    else begin
	  p1_pocket_btn <= snac_is_analog ? {{4'h3},{12'h0},p1_btn} : {{4'h2},{12'h0},p1_btn};
	  p1_pocket_joy <= snac_is_analog ? p1_joy : neutral_joystick; 
	  p2_pocket_btn <= snac_is_analog ? {{4'h3},{12'h0},p2_btn} : {{4'h2},{12'h0},p2_btn};
     p2_pocket_joy <= snac_is_analog ? p2_joy : neutral_joystick; 
     p3_pocket_btn <= snac_is_analog ? {{4'h3},{12'h0},p3_btn} : {{4'h2},{12'h0},p3_btn};
	  p4_pocket_btn <= snac_is_analog ? {{4'h3},{12'h0},p4_btn} : {{4'h2},{12'h0},p4_btn};

      case(snac_cont_assignment[1:0])
      2'h0:    begin  //SNAC P1 -> Pocket P1
	  			//0x13 PSX SNAC Analog -> 0x3 See: https://www.analogue.co/developer/docs/bus-communication#PAD
				//0xXX another SANC	-> 0x2
          p1_controls <= p1_pocket_btn;
          p1_joystick <= p1_pocket_joy; //check for PSX Analog SNAC or return neutral position data
          p2_controls <= cont2_key_s;
          p3_controls <= cont3_key_s;
          p4_controls <= cont4_key_s;

        end
      2'h1: begin  //SNAC P1 -> Pocket P2
          p1_controls <= cont1_key_s;
          p1_joystick <= cont1_joy_s;
          p2_controls <= p1_pocket_btn;
          p3_controls <= cont3_key_s;
          p4_controls <= cont4_key_s;
        end
      2'h2: begin //SNAC P1 -> Pocket P1, SNAC P2 -> Pocket P2
          p1_controls <= p1_pocket_btn;
          p1_joystick <= p1_pocket_joy; //check for PSX Analog SNAC or return neutral position data
          p2_controls <= p2_pocket_btn;
          p3_controls <= cont3_key_s;
          p4_controls <= cont4_key_s;
        end
      2'h3: begin //SNAC P1 -> Pocket P2, SNAC P2 -> Pocket P1
          p1_controls <= p2_pocket_btn;
          p1_joystick <= p2_pocket_joy; //check for PSX Analog SNAC or return neutral position data
          p2_controls <= p1_pocket_btn;
          p3_controls <= cont3_key_s;
          p4_controls <= cont4_key_s;
        end
	    4'h4: begin //SNAC P1-P2 -> Pocket P3-P4
          p1_controls <= cont1_key_s;
          p1_joystick <= cont1_joy_s;
          p2_controls <= cont2_key_s;
          p3_controls <= p1_pocket_btn;
          p4_controls <= p2_pocket_btn;
        end
	    4'h5: begin //SNAC P1-P4 -> Pocket P1-P4
          p1_controls <= p1_pocket_btn;
          p1_joystick <= p1_pocket_joy; //check for PSX Analog SNAC or return neutral position data
          p2_controls <= p2_pocket_btn;
          p3_controls <= p3_pocket_btn;
          p4_controls <= p4_pocket_btn;
        end
      default: begin 
          p1_controls <= cont1_key_s;
          p1_joystick <= cont1_joy_s;
          p2_controls <= cont2_key_s;
          p3_controls <= cont3_key_s;
          p4_controls <= cont4_key_s;
        end
      endcase
    end
  end

wire clk_vid = video_rgb_clock; //video_rgb_clock; //Fixed one bit shift error on RGB channels.

wire SYNC = ~^{video_hs_nes, video_vs_nes};

//*** Analogizer Interface V1.0 ***
//reg analogizer_ena;
reg [3:0] analog_video_type;
reg [4:0] game_cont_type /* synthesis keep */;

// Video Y/C Encoder settings
// Follows the Mike Simone Y/C encoder settings:
// https://github.com/MikeS11/MiSTerFPGA_YC_Encoder
// SET PAL and NTSC TIMING and pass through status bits. ** YC must be enabled in the qsf file **
wire [39:0] CHROMA_PHASE_INC;
wire PALFLAG;

parameter NTSC_REF = 3.579545;   
parameter PAL_REF = 4.43361875;

// Parameters to be modifed
parameter CLK_VIDEO_NTSC = 42.954496; // Must be filled E.g XX.X Hz - CLK_VIDEO
parameter CLK_VIDEO_PAL  = 42.954496; // Must be filled E.g XX.X Hz - CLK_VIDEO

//PAL CLOCK FREQUENCY SHOULD BE 42.56274
localparam [39:0] NTSC_PHASE_INC = 40'd91626062837; //d91_625_958_315; //d91_625_968_981; // ((NTSC_REF**2^40) / CLK_VIDEO_NTSC) - SNES Example;
localparam [39:0] PAL_PHASE_INC = 40'd113487895860; //FAKE PAL, using same frequency as CLK_VIDEO_NTSC

assign CHROMA_PHASE_INC = PALFLAG ? PAL_PHASE_INC : NTSC_PHASE_INC; 
assign PALFLAG = (analogizer_video_type == 4'h4); 

//42_954_496
openFPGA_Pocket_Analogizer #(.MASTER_CLK_FREQ(42_954_496), .LINE_LENGTH(260), 
                             .ADDRESS_ANALOGIZER_CONFIG(ADDRESS_ANALOGIZER_CONFIG),
                             .USE_OLD_STYLE_SVGA_SCANDOUBLER(1'b1)) 
                           analogizer (
  .clk_74a(clk_74a),
	.i_clk(clk_analogizer),
	.i_rst(external_reset_s), //i_rst is active high
	.i_ena(1'b1),

	//Video interface
  .video_clk(clk_analogizer),
	.R(video_rgb_nes[23:16]),
	.G(video_rgb_nes[15:8]),
	.B(video_rgb_nes[7:0]),
  .Hblank(h_blank),
  .Vblank(v_blank),
  .BLANKn(de),
	.Hsync(video_hs_nes), //composite SYNC on HSync.
	.Vsync(video_vs_nes),
  .Csync(SYNC),

  //openFPGA Bridge interface
	.bridge_addr(bridge_addr),
	.bridge_rd(bridge_rd),
	.analogizer_bridge_rd_data(analogizer_bridge_rd_data),
	.bridge_wr(bridge_wr),
	.bridge_wr_data(bridge_wr_data),

	//Analogizer settings
	.snac_game_cont_type_out(snac_game_cont_type),
	.snac_cont_assignment_out(snac_cont_assignment),
	.analogizer_video_type_out(analogizer_video_type),
	.SC_fx_out(SC_fx),
	.pocket_blank_screen_out(pocket_blank_screen),
	.analogizer_osd_out(),

  //Video Y/C Encoder interface
  .CHROMA_PHASE_INC(CHROMA_PHASE_INC),
  .PALFLAG(PALFLAG),
  //Video SVGA Scandoubler interface
  .ce_pix(clk_video_5_37),
	.scandoubler(1'b1), //logic for disable/enable the scandoubler
	//SNAC interface
	.p1_btn_state(p1_btn),
  .p1_joy_state(p1_joy),
	.p2_btn_state(p2_btn),  
  .p2_joy_state(p2_joy),
  .p3_btn_state(p3_btn),
	.p4_btn_state(p4_btn),      
	//Pocket Analogizer IO interface to the Pocket cartridge port
	.cart_tran_bank2(cart_tran_bank2),
	.cart_tran_bank2_dir(cart_tran_bank2_dir),
	.cart_tran_bank3(cart_tran_bank3),
	.cart_tran_bank3_dir(cart_tran_bank3_dir),
	.cart_tran_bank1(cart_tran_bank1),
	.cart_tran_bank1_dir(cart_tran_bank1_dir),
	.cart_tran_bank0(cart_tran_bank0),
	.cart_tran_bank0_dir(cart_tran_bank0_dir),
	.cart_tran_pin30(cart_tran_pin30),
	.cart_tran_pin30_dir(cart_tran_pin30_dir),
	.cart_pin30_pwroff_reset(cart_pin30_pwroff_reset),
	.cart_tran_pin31(cart_tran_pin31),
	.cart_tran_pin31_dir(cart_tran_pin31_dir),
	//debug
	.o_stb()
);
/*[ANALOGIZER_HOOK_END]*/

  nes_top nes (
      .clk_74a(clk_74a),
      .clk_ppu_21_47(clk_ppu_21_47),
      .clk_85_9(clk_85_9),
      .clock_locked(pll_core_locked),

    .sys_type(region_s),

      // Control
      // Region changed, reset
      .external_reset(external_reset_s || prev_region != region_s || pll_reset),

      // Input
      .p1_button_a(p1_controls[4]),
      .p1_button_b(p1_controls[5]),
      .p1_button_a_turbo(p1_controls[6]),
      .p1_button_b_turbo(p1_controls[7]),
      .p1_button_start(p1_controls[15]),
      .p1_button_select(p1_controls[14]),
      .p1_dpad_up(p1_controls[0]),
      .p1_dpad_down(p1_controls[1]),
      .p1_dpad_left(p1_controls[2]),
      .p1_dpad_right(p1_controls[3]),

      .p1_lstick_x(p1_joystick[7:0]),
      .p1_lstick_y(p1_joystick[15:8]),

      .p2_button_a(p2_controls[4]),
      .p2_button_b(p2_controls[5]),
      .p2_button_a_turbo(p2_controls[6]),
      .p2_button_b_turbo(p2_controls[7]),
      .p2_button_start(p2_controls[15]),
      .p2_button_select(p2_controls[14]),
      .p2_dpad_up(p2_controls[0]),
      .p2_dpad_down(p2_controls[1]),
      .p2_dpad_left(p2_controls[2]),
      .p2_dpad_right(p2_controls[3]),

      .p3_button_a(p3_controls[4]),
      .p3_button_b(p3_controls[5]),
      .p3_button_a_turbo(p3_controls[6]),
      .p3_button_b_turbo(p3_controls[7]),
      .p3_button_start(p3_controls[15]),
      .p3_button_select(p3_controls[14]),
      .p3_dpad_up(p3_controls[0]),
      .p3_dpad_down(p3_controls[1]),
      .p3_dpad_left(p3_controls[2]),
      .p3_dpad_right(p3_controls[3]),

      .p4_button_a(p4_controls[4]),
      .p4_button_b(p4_controls[5]),
      .p4_button_a_turbo(p4_controls[6]),
      .p4_button_b_turbo(p4_controls[7]),
      .p4_button_start(p4_controls[15]),
      .p4_button_select(p4_controls[14]),
      .p4_dpad_up(p4_controls[0]),
      .p4_dpad_down(p4_controls[1]),
      .p4_dpad_left(p4_controls[2]),
      .p4_dpad_right(p4_controls[3]),

      // Settings
      .hide_overscan(hide_overscan_s), //Don't Hide overscan
      .mask_vid_edges(mask_vid_edges_s),
      .allow_extra_sprites(allow_extra_sprites_s),
      .selected_palette(selected_palette_s),

      .multitap_enabled(multitap_enabled_s),
      .lightgun_enabled(lightgun_enabled_s),
      .lightgun_dpad_aim_speed(lightgun_dpad_aim_speed_s),

      //SNAC Zapper inputs from P2 port
      .SNAC_Zapper_Trigger(p2_controls[7]), //added zapper trigger to Y
      .SNAC_Zapper_Light(p2_controls[6]), //added zapper light to X

      .turbo_speed(turbo_speed_s),
      .swap_controllers(swap_controllers_s),

      // APF
      .ioctl_wr(ioctl_wr),
      .ioctl_addr(ioctl_addr),
      .ioctl_dout(ioctl_dout),
      .ioctl_download(ioctl_download),

      .palette_download(palette_download),
      .is_downloading  (is_downloading),

      // Save data
      .has_save(has_save),
      .sd_buff_wr(sd_buff_wr),
      .sd_buff_rd(sd_buff_rd),
      .sd_buff_addr(sd_buff_addr),
      .sd_buff_din(sd_buff_din),
      .sd_buff_dout(sd_buff_dout),

      // Save states
      .mapper_has_savestate(mapper_has_savestate),
      .ss_save(ss_save),
      .ss_load(ss_load),

      .ss_busy(ss_busy),

      .ss_din (ss_din),
      .ss_dout(ss_dout),
      .ss_addr(ss_addr),
      .ss_rnw (ss_rnw),
      .ss_req (ss_req),
      .ss_be  (ss_be),
      .ss_ack (ss_ack),

      // SDRAM
      .dram_a(dram_a),
      .dram_ba(dram_ba),
      .dram_dq(dram_dq),
      .dram_dqm(dram_dqm),
      .dram_clk(dram_clk),
      .dram_cke(dram_cke),
      .dram_ras_n(dram_ras_n),
      .dram_cas_n(dram_cas_n),
      .dram_we_n(dram_we_n),

      // Video
      .HBlank (h_blank),
      .VBlank (v_blank),
      .HSync  (video_hs_nes),
      .VSync  (video_vs_nes),
      .video_r(video_rgb_nes[23:16]),
      .video_g(video_rgb_nes[15:8]),
      .video_b(video_rgb_nes[7:0]),

      .audio(audio)
  );

  // Video

  wire h_blank;
  wire v_blank;
  wire video_hs_nes;
  wire video_vs_nes;
  wire [23:0] video_rgb_nes;

  reg video_de_reg;
  reg video_hs_reg;
  reg video_vs_reg;
  reg [23:0] video_rgb_reg;

  assign video_rgb_clock = clk_video_5_37;
  assign video_rgb_clock_90 = clk_video_5_37_90deg;
  assign video_de = video_de_reg;
  assign video_hs = video_hs_reg;
  assign video_vs = video_vs_reg;
  assign video_rgb = video_rgb_reg;

  reg hs_prev;
  reg [2:0] hs_delay;
  reg vs_prev;
  reg de_prev;

  wire de = ~(h_blank || v_blank);
  wire [23:0] video_slot_rgb = {9'b0, hide_overscan_with_region, square_pixels_s, 10'b0, 3'b0};

  always @(posedge clk_video_5_37) begin
    video_hs_reg  <= 0;
    video_de_reg  <= 0;
    video_rgb_reg <= 24'h0;

    if (de) begin
      video_de_reg  <= 1;
      //video_rgb_reg <= video_rgb_nes;
      video_rgb_reg <= video_rgb_pocket;
    end else if (de_prev && ~de) begin
      video_rgb_reg <= video_slot_rgb;
    end

    if (hs_delay > 0) begin
      hs_delay <= hs_delay - 1;
    end

    if (hs_delay == 1) begin
      video_hs_reg <= 1;
    end

    if (~hs_prev && video_hs_nes) begin
      // HSync went high. Delay by 3 cycles to prevent overlapping with VSync
      hs_delay <= 7;
    end

    // Set VSync to be high for a single cycle on the rising edge of the VSync coming out of the core
    video_vs_reg <= ~vs_prev && video_vs_nes;
    hs_prev <= video_hs_nes;
    vs_prev <= video_vs_nes;
    de_prev <= de;
  end

  // Sound

  wire [15:0] audio;

  reg  [15:0] audio_buffer = 0;

  // Buffer audio to have better fitting on audio route
  always @(posedge clk_ppu_21_47) begin
    audio_buffer <= audio;
  end

  audio_mixer #(
      .DW(16),
      .STEREO(0)
  ) audio_mixer (
      .clk_74b  (clk_74b),
      .clk_audio(clk_ppu_21_47),

      // .reset()

      .vol_att(0),
      .mix(0),

      .is_signed(0),
      .core_l(audio_buffer),
      .core_r(audio_buffer),

      .audio_mclk(audio_mclk),
      .audio_lrck(audio_lrck),
      .audio_dac (audio_dac)
  );

  ///////////////////////////////////////////////

  wire clk_85_9;
  wire clk_ppu_21_47;
  wire clk_video_5_37;
  wire clk_video_5_37_90deg;
  wire clk_analogizer; //42_954_496

  // wire [63:0] reconfig_to_pll;
  // wire [63:0] reconfig_from_pll;

  wire pll_core_locked;

  reg  pll_reset = 0;

  mf_pllbase mp1 (
      .refclk(clk_74a),
      .rst   (pll_reset),
      // .rst(0),

      .outclk_0(clk_85_9),
      .outclk_1(clk_ppu_21_47),
      .outclk_2(clk_video_5_37),
      .outclk_3(clk_video_5_37_90deg),
      .outclk_4(clk_analogizer), //42.954496MHz

      // .reconfig_to_pll  (reconfig_to_pll),
      // .reconfig_from_pll(reconfig_from_pll),

      .locked(pll_core_locked)
  );

  // See https://github.com/agg23/openfpga-NES/issues/26

  // wire        cfg_waitrequest;
  // reg         cfg_write;
  // reg  [ 5:0] cfg_address;
  // reg  [31:0] cfg_data;

  // pll_reconfig pll_reconfig (
  //     .mgmt_clk(clk_74a),
  //     .mgmt_reset(0),
  //     .mgmt_waitrequest(cfg_waitrequest),
  //     .mgmt_read(0),
  //     .mgmt_readdata(),
  //     .mgmt_write(cfg_write),
  //     .mgmt_address(cfg_address),
  //     .mgmt_writedata(cfg_data),
  //     .reconfig_to_pll(reconfig_to_pll),
  //     .reconfig_from_pll(reconfig_from_pll)
  // );

  // wire pal = region != 0;

  // reg prev_pal = 0;
  // reg write_pal = 0;

  // reg [3:0] state = 0;

  // reg prev_pll_core_locked = 0;
  // reg [19:0] pll_reset_delay = 0;

  // always @(posedge clk_74a) begin
  //   prev_pal <= pal;
  //   prev_pll_core_locked <= pll_core_locked;

  //   cfg_write <= 0;
  //   if (prev_pal != pal) begin
  //     state <= 1;
  //     write_pal <= pal;
  //   end

  //   if (~pll_core_locked && prev_pll_core_locked) begin
  //     pll_reset_delay <= 20'hF_FFFF;
  //   end

  //   if (pll_reset_delay == 20'hFFFF) begin
  //     pll_reset <= 1;
  //   end else if (pll_reset_delay == 20'h0) begin
  //     pll_reset <= 0;
  //   end

  //   if (pll_reset_delay > 20'h0) begin
  //     pll_reset_delay <= pll_reset_delay - 20'h1;
  //   end

  //   if (!cfg_waitrequest) begin
  //     if (state) state <= state + 1'd1;
  //     case (state)
  //       1: begin
  //         cfg_address <= 0;
  //         cfg_data <= 0;
  //         cfg_write <= 1;
  //       end
  //       3: begin
  //         // Set fractional division
  //         // Config addresses come from https://www.intel.com/content/www/us/en/docs/programmable/683640/current/fractional-pll-dynamic-reconfiguration.html
  //         cfg_address <= 7;
  //         // NTSC: 425907062
  //         //   Mem: 85.908992 MHz
  //         //   Main: 21.477248 MHz
  //         //   Vid: 5.369312 MHz
  //         // PAL: 737738000
  //         //   Mem: 85.125472 MHz
  //         //   Main: 21.281368 MHz
  //         //   Vid: 5.320342 MHz
  //         cfg_data <= write_pal ? 737738000 : 425907062;
  //         cfg_write <= 1;
  //       end
  //       5: begin
  //         // Set counter C0
  //         cfg_address <= 'h5;
  //         cfg_data <= write_pal ? 32'h000404 : 32'h020403;
  //         cfg_write <= 1;
  //       end
  //       7: begin
  //         // Set counter C1
  //         cfg_address <= 'h5;
  //         cfg_data <= write_pal ? 32'h041010 : 32'h040E0E;
  //         cfg_write <= 1;
  //       end
  //       9: begin
  //         // Set counter C2
  //         cfg_address <= 'h5;
  //         cfg_data <= write_pal ? 32'h084040 : 32'h083838;
  //         cfg_write <= 1;
  //       end
  //       11: begin
  //         // Set counter C3
  //         cfg_address <= 'h5;
  //         cfg_data <= write_pal ? 32'h0C4040 : 32'h0C3838;
  //         cfg_write <= 1;
  //       end
  //       13: begin
  //         // Set counter M
  //         cfg_address <= 'h4;
  //         cfg_data <= write_pal ? 32'h20504 : 32'h00404;
  //         cfg_write <= 1;
  //       end
  //       15: begin
  //         // Begin fractional PLL reconfig
  //         cfg_address <= 2;
  //         cfg_data <= 0;
  //         cfg_write <= 1;
  //       end
  //     endcase
  //   end
  // end

endmodule
