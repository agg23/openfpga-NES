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
    output reg  savestate_load_ack,
    output reg  savestate_load_busy,
    output reg  savestate_load_ok,
    output reg  savestate_load_err,

    input  wire savestate_start,
    output reg  savestate_start_ack,
    output reg  savestate_start_busy,
    output reg  savestate_start_ok,
    output reg  savestate_start_err,

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
  wire save_state_loader_write;
  wire [27:0] save_state_loader_addr;
  wire [15:0] save_state_loader_data;

  wire save_state_unloader_read;
  wire [27:0] save_state_unloader_addr;

  data_loader #(
      .ADDRESS_MASK_UPPER_4(4'h4),
      .OUTPUT_WORD_SIZE(2)
      // .WRITE_MEM_CLOCK_DELAY(10),
      // .WRITE_MEM_EN_CYCLE_LENGTH(4)
  ) save_state_loader (
      .clk_74a(clk_74a),
      .clk_memory(clk_ppu_21_47),

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
      .INPUT_WORD_SIZE(2),
      // It takes 7 cycles for a PSRAM read in the mem clock, which is 4x PPU clock, so allow
      // 14 mem cycles < 4 PPU cycles to make sure it completes
      .READ_MEM_CLOCK_DELAY(4)
  ) save_state_unloader (
      .clk_74a(clk_74a),
      .clk_memory(clk_ppu_21_47),

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

  // Disable reads when initially populating ram with save state
  wire psram_read_en = (state >= LOAD_STATE_ACK && ~save_state_loader_write) || save_state_unloader_read;

  wire psram_write_en = save_state_loader_write || ss_psram_write;
  wire [15:0] psram_data_in = save_state_loader_write ? save_state_loader_data : ss_buffer[15:0];

  reg ss_psram_write;

  psram #(
      .CLOCK_SPEED(85.9)
  ) wram (
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
  localparam LOAD_STATE_READ_DELAY_START = LOAD_STATE_READ_REQ + 1;  //6

  localparam LOAD_STATE_READ_DELAY_WAIT_ACK = LOAD_STATE_READ_DELAY_START + 1;  //7
  localparam LOAD_STATE_READ_DELAY_WAIT_AVAIL = LOAD_STATE_READ_DELAY_WAIT_ACK + 1;  // 8

  localparam LOAD_STATE_FILL_BUFFER = LOAD_STATE_READ_DELAY_WAIT_AVAIL + 1;  // 9
  localparam LOAD_STATE_SEND = LOAD_STATE_FILL_BUFFER + 1;  // 10
  localparam LOAD_STATE_FINISH = LOAD_STATE_SEND + 1;  // 11

  reg [7:0] state = STATE_NONE;
  reg [63:0] ss_buffer = 0;
  reg [1:0] shift_count = 0;

  reg prev_savestate_start;
  reg prev_savestate_load;
  reg prev_ss_busy;

  reg prev_psram_read_ack;
  reg prev_psram_read_avail;

  reg prev_psram_write_ack;
  reg prev_psram_busy;

  always @(posedge clk_ppu_21_47) begin
    prev_savestate_start <= savestate_start;
    prev_savestate_load <= savestate_load;
    prev_ss_busy <= ss_busy;

    if (savestate_load && ~prev_savestate_load) begin
      // Begin ss manager
      state <= LOAD_STATE_ACK;
      shift_count <= 0;
    end else if (savestate_start && ~prev_savestate_start) begin
      // Begin ss manager
      state <= SAVE_STATE_ACK;
      shift_count <= 0;
    end

    savestate_start_ack <= 0;
    savestate_load_ack <= 0;
    ss_ack <= 0;
    ss_psram_write <= 0;

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
        if (~(psram_write_ack && ~prev_psram_write_ack)) begin
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
          state <= SAVE_STATE_WRITE_REQ;
          shift_count <= 0;
          ss_ack <= 1;
        end else begin
          state <= SAVE_STATE_WRITE_DELAY_WAIT_ACK;

          // Shift
          ss_buffer[47:0] <= ss_buffer[63:16];
          ss_psram_write <= 1;
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
        savestate_load_busy <= 1;
        ss_load <= 0;

        if (ss_req) begin
          // Read requested
          state <= LOAD_STATE_READ_DELAY_START;
        end else if (prev_ss_busy && ~ss_busy) begin
          // Left busy, SS manager is done
          state <= LOAD_STATE_FINISH;
        end else begin
          state <= LOAD_STATE_READ_REQ;
        end
      end
      LOAD_STATE_READ_DELAY_START: begin
        // Shift
        ss_buffer[47:0] <= ss_buffer[63:16];
      end
      LOAD_STATE_READ_DELAY_WAIT_ACK: begin
        // Wait for PSRAM to ack read
        if (~(psram_read_ack && ~prev_psram_read_ack)) begin
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
          state <= LOAD_STATE_SEND;
          shift_count <= 0;
        end else begin
          state <= LOAD_STATE_READ_DELAY_START;
          shift_count <= shift_count + 1;
        end
      end
      LOAD_STATE_SEND: begin
        ss_ack <= 1;

        state  <= LOAD_STATE_READ_REQ;
      end
      LOAD_STATE_FINISH: begin
        savestate_load_busy <= 0;
        savestate_load_ok <= 1;

        state <= STATE_NONE;
      end
    endcase
  end
endmodule
