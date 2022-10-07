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
    output wire ss_save,
    output wire ss_load,

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

  data_loader #(
      .ADDRESS_MASK_UPPER_4(4'h4),
      .ADDRESS_SIZE(22),
      .OUTPUT_WORD_SIZE(2),
      .WRITE_MEM_CLOCK_DELAY(20)
      // .WRITE_MEM_EN_CYCLE_LENGTH(4)
  ) save_state_loader (
      .clk_74a(clk_74a),
      .clk_memory(clk_mem_85_9),

      .bridge_wr(bridge_wr),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_wr_data(bridge_wr_data),

      .write_en  (save_state_loader_write),
      .write_addr(save_state_loader_addr),
      .write_data(save_state_loader_data)
  );

  data_unloader #(
      .ADDRESS_MASK_UPPER_4(4'h4),
      .ADDRESS_SIZE(22),
      .INPUT_WORD_SIZE(2),
      // It takes 7 cycles for a PSRAM read in the mem clock, which is 4x PPU clock, so allow
      // 14 mem cycles < 4 PPU cycles to make sure it completes
      // Larger than 4 delay just because we have plenty of time. Decrease this if we ever speed up APF
      .READ_MEM_CLOCK_DELAY(20)
  ) save_state_unloader (
      .clk_74a(clk_74a),
      .clk_memory(clk_mem_85_9),

      .bridge_rd(bridge_rd),
      .bridge_endian_little(bridge_endian_little),
      .bridge_addr(bridge_addr),
      .bridge_rd_data(save_state_bridge_read_data),

      .read_en  (save_state_unloader_read),
      .read_addr(save_state_unloader_addr),
      .read_data(psram_data_out)
  );

  // Drop lowest bit of ss_addr
  wire [21:0] full_ss_addr = {ss_addr[20:1], shift_count};
  wire [15:0] psram_data_out;
  wire psram_read_ack;
  wire psram_read_avail;

  wire psram_write_ack;
  wire psram_busy;

  reg ss_psram_write;
  reg ss_psram_read;

  // Disable reads when initially populating ram with save state
  wire psram_read_en = ss_psram_read || save_state_unloader_read;

  wire psram_write_en = save_state_loader_write || ss_psram_write;
  wire [15:0] psram_data_in = save_state_loader_write ? save_state_loader_data : ss_buffer[15:0];

  psram #(
      .CLOCK_SPEED(85.9)
  ) psram (
      .clk(clk_mem_85_9),

      .bank_sel(0),
      // Remove bottom most bit, since this is a 8bit address and the RAM wants a 16bit address
      .addr(save_state_loader_write ? save_state_loader_addr[21:1]
          : save_state_unloader_read ? save_state_unloader_addr[21:1] : full_ss_addr),

      .busy(psram_busy),

      .write_en(psram_write_en),
      .data_in(psram_data_in),
      .write_high_byte(1),
      .write_low_byte(1),
      .write_ack(psram_write_ack),

      .read_en(psram_read_en),
      .data_out(psram_data_out),
      .read_ack(psram_read_ack),
      .read_avail(psram_read_avail),

      // Actual PSRAM interface
      .cram_a(cram0_a),
      .cram_dq(cram0_dq),
      .cram_wait(cram0_wait),
      .cram_clk(cram0_clk),
      .cram_adv_n(cram0_adv_n),
      .cram_cre(cram0_cre),
      .cram_ce0_n(cram0_ce0_n),
      .cram_ce1_n(cram0_ce1_n),
      .cram_oe_n(cram0_oe_n),
      .cram_we_n(cram0_we_n),
      .cram_ub_n(cram0_ub_n),
      .cram_lb_n(cram0_lb_n)
  );

  assign ss_dout = ss_buffer;

  localparam STATE_NONE = 0;

  // SAVE
  localparam SAVE_STATE_ACK = 1;
  localparam SAVE_STATE_WRITE_REQ = 5;

  localparam SAVE_STATE_WRITE_DELAY_WAIT_ACK = SAVE_STATE_WRITE_REQ + 1;  // 6
  localparam SAVE_STATE_WRITE_DELAY_WAIT_AVAIL = SAVE_STATE_WRITE_DELAY_WAIT_ACK + 1;  // 7
  localparam SAVE_STATE_WRITE_COMPLETE = SAVE_STATE_WRITE_DELAY_WAIT_AVAIL + 1;  // 8
  localparam SAVE_STATE_FINISH = SAVE_STATE_WRITE_COMPLETE + 1;  // 9

  // LOAD
  localparam LOAD_STATE_ACK = 20;
  localparam LOAD_STATE_READ_REQ = LOAD_STATE_ACK + 4;

  localparam LOAD_STATE_READ_DELAY_WAIT_ACK = LOAD_STATE_READ_REQ + 1;  // 25
  localparam LOAD_STATE_READ_DELAY_WAIT_AVAIL = LOAD_STATE_READ_DELAY_WAIT_ACK + 1;  // 26

  localparam LOAD_STATE_FILL_BUFFER = LOAD_STATE_READ_DELAY_WAIT_AVAIL + 1;  // 27
  localparam LOAD_STATE_FINISH = LOAD_STATE_FILL_BUFFER + 1;  // 28

  reg [7:0] state = STATE_NONE;
  reg [63:0] ss_buffer = 0;
  reg [1:0] shift_count = 0;
  reg [1:0] ack_count = 0;

  reg prev_savestate_start;
  reg prev_savestate_load;
  reg prev_ss_busy;

  reg prev_psram_read_ack;
  reg prev_psram_read_avail;

  reg prev_psram_write_ack;
  reg prev_psram_busy;

  always @(posedge clk_mem_85_9) begin
    prev_savestate_start <= savestate_start_s;
    prev_savestate_load <= savestate_load_s;
    prev_ss_busy <= ss_busy;

    if (savestate_load_s && ~prev_savestate_load) begin
      // Begin ss manager
      state <= LOAD_STATE_ACK;
      shift_count <= 0;
      ack_count <= 0;
    end else if (savestate_start_s && ~prev_savestate_start) begin
      // Begin ss manager
      state <= SAVE_STATE_ACK;
      shift_count <= 0;
      ack_count <= 0;
    end

    ss_ack <= 0;

    if (state != STATE_NONE) begin
      state <= state + 1;
    end

    prev_psram_read_ack <= psram_read_ack;
    prev_psram_read_avail <= psram_read_avail;

    prev_psram_write_ack <= psram_write_ack;
    prev_psram_busy <= psram_busy;

    case (state)
      // Saving //
      SAVE_STATE_ACK: begin
        savestate_start_ack <= 1;
        savestate_start_ok <= 0;
        savestate_start_err <= 0;

        savestate_load_ok <= 0;
        savestate_load_err <= 0;

        ss_save <= 1;
      end
      SAVE_STATE_WRITE_REQ: begin
        savestate_start_ack <= 0;
        savestate_start_busy <= 1;
        ss_save <= 0;

        if (ss_req && ~ss_rnw) begin
          // Write requested, capture SS manager data, send to PSRAM
          ss_buffer <= ss_din;
          state <= SAVE_STATE_WRITE_DELAY_WAIT_ACK;
          ss_psram_write <= 1;
        end else if (prev_ss_busy && ~ss_busy) begin
          // Left busy, SS manager is done
          state <= SAVE_STATE_FINISH;
        end else begin
          state <= SAVE_STATE_WRITE_REQ;
        end
      end
      SAVE_STATE_WRITE_DELAY_WAIT_ACK: begin
        if (psram_write_ack && ~prev_psram_write_ack) begin
          // Write began
          ss_psram_write <= 0;
        end else begin
          // Wait for PSRAM write to ack
          state <= SAVE_STATE_WRITE_DELAY_WAIT_ACK;
        end
      end
      SAVE_STATE_WRITE_DELAY_WAIT_AVAIL: begin
        if (~(~psram_busy && prev_psram_busy)) begin
          // Wait for PSRAM write to complete (and RAM to stop being busy)
          state <= SAVE_STATE_WRITE_DELAY_WAIT_AVAIL;
        end
      end
      SAVE_STATE_WRITE_COMPLETE: begin
        // Write completed
        if (shift_count == 3) begin
          // Send write ack
          ss_ack <= 1;

          if (ack_count == 3) begin
            state <= SAVE_STATE_WRITE_REQ;

            ack_count <= 0;
            shift_count <= 0;
          end else begin
            state <= SAVE_STATE_WRITE_COMPLETE;

            ack_count <= ack_count + 1;
          end
        end else begin
          state <= SAVE_STATE_WRITE_DELAY_WAIT_ACK;

          ss_psram_write <= 1;

          // Shift
          ss_buffer[47:0] <= ss_buffer[63:16];
          shift_count <= shift_count + 1;
        end
      end
      SAVE_STATE_FINISH: begin
        savestate_start_busy <= 0;
        savestate_start_ok <= 1;

        state <= STATE_NONE;
      end

      // Loading //
      LOAD_STATE_ACK: begin
        savestate_load_ack <= 1;
        savestate_load_ok <= 0;
        savestate_load_err <= 0;

        savestate_start_ok <= 0;
        savestate_start_err <= 0;

        ss_load <= 1;
      end
      // Load delay to leave ss_load high for several cycles
      LOAD_STATE_READ_REQ: begin
        savestate_load_ack <= 0;
        savestate_load_busy <= 1;
        ss_load <= 0;

        if (ss_req && ss_rnw) begin
          // Read requested
          state <= LOAD_STATE_READ_DELAY_WAIT_ACK;
          ss_psram_read <= 1;
        end else if (prev_ss_busy && ~ss_busy) begin
          // Left busy, SS manager is done
          state <= LOAD_STATE_FINISH;
        end else begin
          state <= LOAD_STATE_READ_REQ;
        end
      end
      LOAD_STATE_READ_DELAY_WAIT_ACK: begin
        // Wait for PSRAM to ack read
        if (psram_read_ack) begin
          // On ack
          ss_psram_read   <= 0;

          // Shift
          ss_buffer[47:0] <= ss_buffer[63:16];
        end else begin
          state <= LOAD_STATE_READ_DELAY_WAIT_ACK;
        end
      end
      LOAD_STATE_READ_DELAY_WAIT_AVAIL: begin
        // Wait for PSRAM to mark read data available
        if (~(psram_read_avail && ~prev_psram_read_avail)) begin
          state <= LOAD_STATE_READ_DELAY_WAIT_AVAIL;
        end
      end
      LOAD_STATE_FILL_BUFFER: begin
        // Read data and prepare to write to SS manager
        ss_buffer[63:48] <= psram_data_out;

        if (shift_count == 3) begin
          // Send data
          ss_ack <= 1;

          if (ack_count == 3) begin
            state <= LOAD_STATE_READ_REQ;

            ack_count <= 0;
            shift_count <= 0;
          end else begin
            state <= LOAD_STATE_FILL_BUFFER;

            ack_count <= ack_count + 1;
          end
        end else begin
          state <= LOAD_STATE_READ_DELAY_WAIT_ACK;

          // Read next
          ss_psram_read <= 1;

          shift_count <= shift_count + 1;
        end
      end
      LOAD_STATE_FINISH: begin
        savestate_load_busy <= 0;
        savestate_load_ok <= 1;

        state <= STATE_NONE;
      end
    endcase
  end
endmodule
