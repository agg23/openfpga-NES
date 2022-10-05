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

    // APF Save States
    input  wire savestate_load,
    output reg  savestate_load_ack,
    output reg  savestate_load_busy,
    output reg  savestate_load_ok,
    output reg  savestate_load_err,

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

  // Drop lowest bit of ss_addr
  wire [21:0] full_ss_addr = {ss_addr[20:1], shift_count};
  wire [15:0] psram_data_out;
  wire psram_read_ack;
  wire psram_read_avail;

  // Disable reads when initially populating ram with save state
  wire psram_read_en = state >= LOAD_STATE_ACK && ~save_state_loader_write;

  psram #(
      .CLOCK_SPEED(85.9)
  ) wram (
      .clk(clk_mem_85_9),

      .bank_sel(0),
      // Remove bottom most bit, since this is a 8bit address and the RAM wants a 16bit address
      .addr(save_state_loader_write ? save_state_loader_addr[21:1] : full_ss_addr),

      .write_en(save_state_loader_write),
      .data_in(save_state_loader_data),
      .write_high_byte(1),
      .write_low_byte(1),

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

  assign ss_dout = read_buffer;

  reg prev_savestate_load;
  reg prev_ss_busy;

  localparam LOAD_STATE_NONE = 0;
  localparam LOAD_STATE_ACK = 1;
  localparam LOAD_STATE_READ_REQ = 5;
  localparam LOAD_STATE_READ_DELAY_START = LOAD_STATE_READ_REQ + 1;  //6

  localparam LOAD_STATE_READ_DELAY_WAIT_ACK = LOAD_STATE_READ_DELAY_START + 1;  //7
  localparam LOAD_STATE_READ_DELAY_WAIT_AVAIL = LOAD_STATE_READ_DELAY_WAIT_ACK + 1;  // 8

  localparam LOAD_STATE_FILL_BUFFER = LOAD_STATE_READ_DELAY_WAIT_AVAIL + 1;  // 9
  localparam LOAD_STATE_SEND = LOAD_STATE_FILL_BUFFER + 1;  // 10
  localparam LOAD_STATE_FINISH = LOAD_STATE_SEND + 1;  // 11

  reg [7:0] state = LOAD_STATE_NONE;
  reg [63:0] read_buffer = 0;
  reg [1:0] shift_count = 0;

  reg prev_psram_read_ack;
  reg prev_psram_read_avail;

  always @(posedge clk_ppu_21_47) begin
    prev_savestate_load <= savestate_load;
    prev_ss_busy <= ss_busy;

    if (savestate_load && ~prev_savestate_load) begin
      // Begin ss manager
      state <= LOAD_STATE_ACK;
      shift_count <= 0;
    end

    savestate_load_ack <= 0;
    ss_ack <= 0;

    if (state != LOAD_STATE_NONE) begin
      state <= state + 1;
    end

    prev_psram_read_ack   <= psram_read_ack;
    prev_psram_read_avail <= psram_read_avail;

    case (state)
      LOAD_STATE_ACK: begin
        savestate_load_ack <= 1;
        savestate_load_ok <= 0;
        savestate_load_err <= 0;

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
        read_buffer[47:0] <= read_buffer[63:16];
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
        read_buffer[63:48] <= psram_data_out;

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

        state <= LOAD_STATE_NONE;
      end
    endcase
  end
endmodule
