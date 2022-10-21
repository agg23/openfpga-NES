module save_state_controller (
    input wire clk_74a,
    input wire clk_mem_85_9,
    input wire clk_ppu_21_47,

    // APF
    input wire bridge_wr,
    input wire bridge_rd,
    input wire bridge_endian_little,
    input wire [31:0] bridge_addr,
    input wire [31:0] bridge_wr_data,
    output wire [31:0] save_state_bridge_read_data,

    // APF Save States
    input  wire savestate_load,
    output wire savestate_load_ack_s,
    output wire savestate_load_busy_s,
    output wire savestate_load_ok_s,
    output wire savestate_load_err_s,

    input  wire savestate_start,
    output wire savestate_start_ack_s,
    output wire savestate_start_busy_s,
    output wire savestate_start_ok_s,
    output wire savestate_start_err_s,

    // Save States
    output reg ss_save,
    output reg ss_load,

    input wire [63:0] ss_din,
    output wire [63:0] ss_dout,
    input wire [25:0] ss_addr,
    input wire ss_rnw,
    input wire ss_req,
    input wire [7:0] ss_be,
    output reg ss_ack,

    input wire ss_busy,

    // PSRAM
    output wire [21:16] cram0_a,
    inout wire [15:0] cram0_dq,
    input wire cram0_wait,
    output wire cram0_clk,
    output wire cram0_adv_n,
    output wire cram0_cre,
    output wire cram0_ce0_n,
    output wire cram0_ce1_n,
    output wire cram0_oe_n,
    output wire cram0_we_n,
    output wire cram0_ub_n,
    output wire cram0_lb_n
);
  wire savestate_load_s;
  wire savestate_start_s;

  // Syncing
  synch_3 #(
      .WIDTH(2)
  ) savestate_in (
      {savestate_load, savestate_start},
      {savestate_load_s, savestate_start_s},
      clk_ppu_21_47
  );

  reg savestate_load_ack;
  reg savestate_load_busy;
  reg savestate_load_ok;
  reg savestate_load_err;

  reg savestate_start_ack;
  reg savestate_start_busy;
  reg savestate_start_ok;
  reg savestate_start_err;

  synch_3 #(
      .WIDTH(8)
  ) savestate_out (
      {
        savestate_load_ack,
        savestate_load_busy,
        savestate_load_ok,
        savestate_load_err,
        savestate_start_ack,
        savestate_start_busy,
        savestate_start_ok,
        savestate_start_err
      },
      {
        savestate_load_ack_s,
        savestate_load_busy_s,
        savestate_load_ok_s,
        savestate_load_err_s,
        savestate_start_ack_s,
        savestate_start_busy_s,
        savestate_start_ok_s,
        savestate_start_err_s
      },
      clk_74a
  );

  wire save_state_loader_write;
  wire [22:0] save_state_loader_addr;
  wire [15:0] save_state_loader_data;

  wire save_state_unloader_read;
  wire [22:0] save_state_unloader_addr;

  // data_loader #(
  //     .ADDRESS_MASK_UPPER_4(4'h4),
  //     .ADDRESS_SIZE(22),
  //     .OUTPUT_WORD_SIZE(2)
  // ) save_state_loader (
  //     .clk_74a(clk_74a),
  //     .clk_memory(clk_ppu_21_47),

  //     .bridge_wr(bridge_wr),
  //     .bridge_endian_little(bridge_endian_little),
  //     .bridge_addr(bridge_addr),
  //     .bridge_wr_data(bridge_wr_data),

  //     .write_en  (save_state_loader_write),
  //     .write_addr(save_state_loader_addr),
  //     .write_data(save_state_loader_data)
  // );

  wire fifo_load_empty;
  reg fifo_load_read_req = 0;
  wire [63:0] fifo_load_dout;
  reg fifo_load_clr = 0;

  // wire [10:0] debug_used;
  reg [31:0] written_words = 0;
  reg [31:0] transferred_words = 0;

  // TODO: Add endianness
  // assign ss_dout = {fifo_load_dout[47:32], fifo_load_dout[63:48], fifo_load_dout[15:0], fifo_load_dout[31:16]};
  assign ss_dout = {
    fifo_load_dout[39:32],
    fifo_load_dout[47:40],
    fifo_load_dout[55:48],
    fifo_load_dout[63:56],
    fifo_load_dout[7:0],
    fifo_load_dout[15:8],
    fifo_load_dout[23:16],
    fifo_load_dout[31:24]
  };

  reg prev_wr;
  reg [31:0] last_write_addr;
  reg [31:0] debug_dupe_writes = 0;

  always @(posedge clk_74a) begin
    if (bridge_wr && ~prev_wr && bridge_addr[31:28] == 4'h4) begin
      written_words <= written_words + 4;

      if (bridge_addr == last_write_addr) begin
        debug_dupe_writes <= debug_dupe_writes + 1;
      end

      last_write_addr <= bridge_addr;
    end

    prev_wr <= bridge_wr && bridge_addr[31:28] == 4'h4;
  end

  dcfifo_mixed_widths fifo_load (
      .data(bridge_wr_data),
      .rdclk(clk_ppu_21_47),
      .rdreq(fifo_load_read_req),
      .wrclk(clk_74a),
      .wrreq(bridge_wr && bridge_addr[31:28] == 4'h4),
      .q(fifo_load_dout),
      .rdempty(fifo_load_empty),
      .aclr(fifo_load_clr)
      // .eccstatus(),
      // .rdfull(),
      // .rdusedw(),
      // .wrempty(),
      // .wrfull(),
      // .wrusedw()
  );
  defparam fifo_load.intended_device_family = "Cyclone V", fifo_load.lpm_numwords = 4096,
      fifo_load.lpm_showahead = "OFF", fifo_load.lpm_type = "dcfifo_mixed_widths",
      fifo_load.lpm_width = 32, fifo_load.lpm_widthu = 12,
      fifo_load.lpm_widthu_r = 11, fifo_load.lpm_width_r = 64, fifo_load.overflow_checking = "OFF",
      fifo_load.rdsync_delaypipe = 5, fifo_load.underflow_checking = "ON", fifo_load.use_eab = "ON",
      fifo_load.wrsync_delaypipe = 5, fifo_load.write_aclr_synch = "ON";

  reg  fifo_save_write_req;
  reg  fifo_save_read_req;

  wire fifo_save_rd_empty;
  wire fifo_save_wr_empty;

  dcfifo_mixed_widths fifo_save (
      .data(ss_din),
      .rdclk(clk_74a),
      .rdreq(fifo_save_read_req),
      .wrclk(clk_ppu_21_47),
      .wrreq(fifo_save_write_req),
      .q({
        save_state_bridge_read_data[7:0],
        save_state_bridge_read_data[15:8],
        save_state_bridge_read_data[23:16],
        save_state_bridge_read_data[31:24]
      }),
      .rdempty(fifo_save_rd_empty),
      .wrempty(fifo_save_wr_empty),
      .aclr(1'b0)
      // .eccstatus(),
      // .rdfull(),
      // .rdusedw(),
      // .wrfull(),
      // .wrusedw()
  );
  defparam fifo_save.intended_device_family = "Cyclone V", fifo_save.lpm_numwords = 4,
      fifo_save.lpm_showahead = "OFF", fifo_save.lpm_type = "dcfifo_mixed_widths",
      fifo_save.lpm_width = 64, fifo_save.lpm_widthu = 2, fifo_save.lpm_widthu_r = 3,
      fifo_save.lpm_width_r = 32, fifo_save.overflow_checking = "ON",
      fifo_save.rdsync_delaypipe = 5, fifo_save.underflow_checking = "ON", fifo_save.use_eab = "ON",
      fifo_save.wrsync_delaypipe = 5;


  // data_unloader #(
  //     .ADDRESS_MASK_UPPER_4(4'h4),
  //     .ADDRESS_SIZE(22),
  //     .INPUT_WORD_SIZE(2),
  //     // It takes 7 cycles for a PSRAM read in the mem clock, which is 4x PPU clock, so allow
  //     // 14 mem cycles < 4 PPU cycles to make sure it completes
  //     // Larger than 4 delay just because we have plenty of time. Decrease this if we ever speed up APF
  //     .READ_MEM_CLOCK_DELAY(5)
  // ) save_state_unloader (
  //     .clk_74a(clk_74a),
  //     .clk_memory(clk_ppu_21_47),

  //     .bridge_rd(bridge_rd),
  //     .bridge_endian_little(bridge_endian_little),
  //     .bridge_addr(bridge_addr),
  //     .bridge_rd_data(save_state_bridge_read_data),

  //     .read_en  (save_state_unloader_read),
  //     .read_addr(save_state_unloader_addr),
  //     .read_data(save_state_unloader_data)
  // );

  reg prev_bridge_rd;
  reg [1:0] save_read_state = NONE;

  wire [27:0] bridge_save_addr = bridge_addr[27:0];
  wire bridge_save_rd = bridge_rd && bridge_addr[31:28] == 4'h4;

  reg [31:0] fifo_empty_count = 0;
  reg [31:0] fifo_addr_count = 0;

  localparam SAVE_READ_REQ = 1;

  always @(posedge clk_74a) begin
    prev_bridge_rd <= bridge_rd;

    if (bridge_rd && ~prev_bridge_rd && bridge_addr[31:28] == 4'h4) begin
      if (~fifo_save_rd_empty && bridge_save_addr[22:2] != last_unloader_addr) begin
        save_read_state <= SAVE_READ_REQ;

        fifo_save_read_req <= 1;

        last_unloader_addr <= bridge_save_addr[22:2];
      end else if (fifo_save_rd_empty) begin
        fifo_empty_count <= fifo_empty_count + 1;
      end else begin
        fifo_addr_count <= fifo_addr_count + 1;
      end
    end

    // TODO: Remove
    if (fifo_empty_count == 32'hFFFFFFFF || fifo_addr_count == 32'hFFFFFFFF || debug_dupe_writes == 32'hFFFFFFFF || transferred_words == 32'hFFFFFFFF || written_words == 32'hFFFFFFFF) begin
      save_read_state <= NONE;
    end

    case (save_read_state)
      SAVE_READ_REQ: begin
        save_read_state <= NONE;

        fifo_save_read_req <= 0;
      end
    endcase
  end

  reg  [20:0] last_unloader_addr = 21'hFFFF;
  wire [15:0] save_state_unloader_data;

  localparam NONE = 0;

  localparam SAVE_BUSY = 1;
  localparam SAVE_WAIT_REQ = SAVE_BUSY + 1;
  localparam SAVE_WAIT_REQ_DELAY = SAVE_WAIT_REQ + 1;
  localparam SAVE_WAIT_ACK = SAVE_WAIT_REQ_DELAY + 1;
  localparam SAVE_SHIFT = SAVE_WAIT_ACK + 1;

  localparam LOAD_WAIT_REQ = 20;
  localparam LOAD_READ_REQ = LOAD_WAIT_REQ + 1;
  localparam LOAD_WAIT_APF_START = LOAD_READ_REQ + 1;

  localparam LOAD_APF_COMPLETE = LOAD_WAIT_APF_START + 1;

  reg [7:0] state = NONE;

  reg save_state_saving_req = 0;
  reg save_state_loading = 0;
  reg [63:0] ss_buffer = 0;
  // Used for duplicate reads
  reg [63:0] last_ss_buffer = 0;
  reg [1:0] save_shift_count = 0;

  reg did_req = 0;
  reg is_dup_read = 0;

  reg prev_savestate_start = 0;
  reg prev_savestate_load = 0;
  reg prev_ss_busy = 0;
  reg prev_bridge_save_rd = 0;

  reg [31:0] debug_hash_adder  /* synthesis noprune */;
  reg [31:0] debug_hash_xor  /* synthesis noprune */;
  reg [63:0] debug_read_value  /* synthesis noprune */;
  reg [31:0] duplicate_read_count = 0;

  always @(posedge clk_ppu_21_47) begin
    prev_ss_busy <= ss_busy;
    prev_savestate_start <= savestate_start_s;
    prev_savestate_load <= savestate_load_s;
    prev_bridge_save_rd <= bridge_save_rd;

    ss_load <= 0;
    ss_save <= 0;
    ss_ack <= 0;
    fifo_save_write_req <= 0;

    if (duplicate_read_count == 32'hFFFFFFFF) begin
      state <= NONE;
    end

    if (~fifo_load_empty && ~save_state_loading) begin
      // Begin save stating
      state <= LOAD_WAIT_REQ;

      save_state_loading <= 1;

      ss_load <= 1;
    end

    if (savestate_start_s && ~prev_savestate_start) begin
      // Begin saving state
      state <= SAVE_BUSY;

      savestate_start_ack <= 1;
      savestate_start_ok <= 0;
      savestate_start_err <= 0;

      savestate_load_ok <= 0;
      savestate_load_err <= 0;

      ss_save <= 1;
    end else if (savestate_load_s && ~prev_savestate_load) begin
      // Begin APF savestate load (data is already copied into ss manager)
      save_state_saving_req <= 1;

      savestate_load_ack <= 1;
      savestate_load_ok <= 0;
      savestate_load_err <= 0;

      savestate_start_ok <= 0;
      savestate_start_err <= 0;
    end

    case (state)
      // Saving
      SAVE_BUSY: begin
        savestate_start_ack  <= 0;
        savestate_start_busy <= 1;

        if (ss_req) begin
          // First req, end busy, start loading out
          // Duplicate of SAVE_WAIT_REQ
          state <= SAVE_WAIT_REQ_DELAY;

          // Latch data
          // ss_buffer <= ss_din;
          fifo_save_write_req <= 1;

          savestate_start_busy <= 0;
          savestate_start_ok <= 1;
        end
      end
      SAVE_WAIT_REQ: begin
        // Wait for SS manager to send us more data
        if (ss_req) begin
          state <= SAVE_WAIT_REQ_DELAY;

          // Latch data
          // ss_buffer <= ss_din;
          fifo_save_write_req <= 1;
        end else if (prev_ss_busy && ~ss_busy) begin
          // Left busy, SS manager is done
          state <= NONE;
        end
      end
      SAVE_WAIT_REQ_DELAY: begin
        // Delay for empty to go low
        state <= SAVE_WAIT_ACK;
      end
      SAVE_WAIT_ACK: begin
        // Wait for bridge to read word
        if (fifo_save_wr_empty) begin
          state  <= SAVE_WAIT_REQ;

          ss_ack <= 1;
        end
      end

      // Wait for bridge to request this word
      // if (bridge_save_rd && ~prev_bridge_save_rd) begin
      //   if (bridge_save_addr[22:2] != last_unloader_addr) begin
      //     // This isn't a duplicate read, request data

      //     // TODO: Set data to last_ss_buffer data
      //     // Otherwise (if not duplicate) read FIFO and set to output

      //     // state <= SAVE_SHIFT;

      //     // duplicate_read_count <= duplicate_read_count + 1;

      //     // if (last_unloader_addr[0]) begin
      //     //   // High 32 bit word
      //     //   save_state_unloader_data <= last_ss_buffer[47:32];

      //     //   // If it's the high word, set the shift count to 2 and 3
      //     //   save_shift_count <= {1'b1, save_shift_count[0]};
      //     // end else begin
      //     //   // Low 32 bit word
      //     //   save_state_unloader_data <= last_ss_buffer[15:0];

      //     //   // If it's the low word, set the shift count to 0 and 1
      //     //   save_shift_count <= {1'b0, save_shift_count[0]};
      //     // end

      //     // is_dup_read <= 1;
      //   end else begin
      //     // state <= SAVE_SHIFT;

      //     // if (save_shift_count == 0) begin
      //     //   // This is the first read operation. Save buffer in case we have a dup read
      //     //   last_ss_buffer <= ss_buffer;
      //     // end
      //     // is_dup_read <= 0;

      //     // save_state_unloader_data <= ss_buffer[15:0];
      //   end
      // end
      // end
      // SAVE_SHIFT: begin
      //   if (~save_state_unloader_read && prev_save_state_unloader_read) begin
      //     // End read
      //     state <= SAVE_WAIT_ACK;

      //     if (is_dup_read) begin
      //       last_ss_buffer[47:0] <= last_ss_buffer[63:16];
      //     end else begin
      //       ss_buffer[47:0] <= ss_buffer[63:16];
      //     end
      //     save_shift_count <= save_shift_count + 1;

      //     if (save_shift_count == 1 || save_shift_count == 3) begin
      //       // A single bridge write has completed
      //       last_unloader_addr <= save_state_unloader_addr[22:2];
      //     end

      //     if (save_shift_count == 3) begin
      //       // Sent out full 64bit word
      //       if (is_dup_read) begin
      //         // We want to go back to our normal loading
      //         // We've already seen a req from the SS manager, so go back to wait for a read
      //         state <= SAVE_WAIT_ACK;
      //         is_dup_read <= 0;
      //       end else begin
      //         // Ack complete to SS manager
      //         state  <= SAVE_WAIT_REQ;

      //         ss_ack <= 1;
      //       end

      //       save_shift_count <= 0;
      //     end
      //   end
      // end

      // Loading
      LOAD_WAIT_REQ: begin
        if (prev_ss_busy && ~ss_busy) begin
          // Finished load. Wait for APF ack
          state <= LOAD_WAIT_APF_START;
        end else if (~fifo_load_empty) begin
          if (did_req || ss_req) begin
            // Request and FIFO has data
            state <= LOAD_READ_REQ;
            fifo_load_read_req <= 1;
            did_req <= 0;
          end
        end else if (ss_req) begin
          // Request. Wait for data to arrive
          did_req <= 1;
        end
      end
      LOAD_READ_REQ: begin
        // Data should be available from FIFO read
        state <= LOAD_WAIT_REQ;

        fifo_load_read_req <= 0;
        debug_hash_adder <= debug_hash_adder + ss_dout[63:32] + ss_dout[31:0];
        debug_hash_xor <= debug_hash_xor ^ ss_dout[63:32] ^ ss_dout[31:0];
        debug_read_value <= ss_dout;
        ss_ack <= 1;
        // 8 bytes in each
        transferred_words <= transferred_words + 2 * 4;
      end
      LOAD_WAIT_APF_START: begin
        if (save_state_saving_req) begin
          // Begin APF savestate load (data is already copied into ss manager)
          state <= LOAD_APF_COMPLETE;

          fifo_load_clr <= 1;

          savestate_load_ack <= 0;
          savestate_load_busy <= 1;

          save_state_saving_req <= 0;
        end
      end
      LOAD_APF_COMPLETE: begin
        state <= NONE;

        fifo_load_clr <= 0;

        savestate_load_busy <= 0;
        savestate_load_ok <= 1;

        save_state_loading <= 0;
      end
    endcase
  end
endmodule
