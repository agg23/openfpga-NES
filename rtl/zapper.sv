// NES Zapper emulation – fully off when gun disabled or reset
// Apr, 20 2019 (modified for full gun-disable)

module zapper (
  input        clk,
  input        reset,
  input        lightgun_enabled,   // new top-level control
  input        dpad_up,
  input        dpad_down,
  input        dpad_left,
  input        dpad_right,
  input [7:0]  dpad_aim_speed,
  input [15:0] analog,
  input        analog_trigger,
  input  [8:0] cycle,
  input  [8:0] scanline,
  input        vde,
  input  [5:0] color,
  output reg  [1:0] reticle,
  output       light,
  output       trigger
);

// Enable signal – module active only when gun is enabled and not in reset
wire gun_enable = lightgun_enabled & ~reset;

// Internal counters and state
reg [31:0] trigger_cnt;
reg [8:0]  light_cnt;
reg [9:0]  pos_x, pos_y;
reg        old_vde;
reg [8:0]  old_scanline;
reg [15:0] old_analog;
reg        pressed;

parameter cross_size = 8'd4;

// Hit detection
wire hit_x = ((pos_x >= cycle - cross_size && pos_x <= cycle + cross_size) && scanline == pos_y);
wire hit_y = ((pos_y >= scanline - cross_size && pos_y <= scanline + cross_size) && cycle == pos_x);

wire is_offscreen = ((pos_x >= 254 || pos_x <= 1) || (pos_y >= 224 || pos_y <= 8));
wire light_square = ((pos_x >= cycle - 3'd4 && pos_x <= cycle + 3'd4) && (pos_y >= scanline - 3'd4 && pos_y <= scanline + 3'd4));

wire [7:0] joy_x = analog[7:0];
wire [7:0] joy_y = analog[15:8];
wire trigger_btn = analog_trigger;

// Active state wires
wire light_state   = light_cnt > 0;
wire trigger_state = trigger_cnt > 32'd2_100_000;

// Outputs masked by gun_enable
assign light   = gun_enable ? ~light_state   : 1'b0;
assign trigger = gun_enable ? trigger_state : 1'b0;

always @(posedge clk) begin
  if (~gun_enable) begin
    // Fully clear all internal state when gun disabled
    trigger_cnt   <= 0;
    light_cnt     <= 0;
    pos_x         <= 0;
    pos_y         <= 0;
    reticle       <= 0;
    old_scanline  <= 0;
    old_vde       <= 0;
    old_analog    <= 0;
    pressed       <= 0;
  end else begin
    // --- normal operation ---
    old_scanline <= scanline;

    if (trigger_cnt > 0) trigger_cnt <= trigger_cnt - 1'b1;

    // Drain light over time
    if (old_scanline != scanline && light_cnt > 0) light_cnt <= light_cnt - 1'b1;

    // Trigger button handling
    if (trigger_cnt == 0 && trigger_btn && ~pressed) begin
      trigger_cnt <= 32'd830_000 + 32'd2_100_000;
      pressed <= 1'b1;
    end
    if (~trigger_btn) pressed <= 0;

    old_vde <= vde;

    if (~old_vde & vde) begin
      old_analog <= analog;
      if (old_analog != analog) begin
        pos_x <= joy_x;
        pos_y <= joy_y;
      end else begin
        // D-pad movement
        if(dpad_left)  pos_x <= (pos_x >= dpad_aim_speed) ? pos_x - dpad_aim_speed : 0;
        if(dpad_right) pos_x <= (pos_x <= 8'd255 - dpad_aim_speed) ? pos_x + dpad_aim_speed : 8'd255;
        if(dpad_up)    pos_y <= (pos_y >= dpad_aim_speed) ? pos_y - dpad_aim_speed : 0;
        if(dpad_down)  pos_y <= (pos_y < 8'd240 - dpad_aim_speed) ? pos_y + dpad_aim_speed : 8'd240;
      end
    end

    // Reticle updates
    reticle[0] <= (hit_x || hit_y);
    reticle[1] <= is_offscreen;

    // Light detection
    if (light_square && ~is_offscreen) begin
      if (color == 6'h20 || color == 6'h30)
        light_cnt <= 9'd26;
      else if ((color[5:4] == 3 && color < 6'h3E) || color == 6'h10)
        if (light_cnt < 9'd20) light_cnt <= 9'd20;
      else if ((color[5:4] == 2 && color < 6'h2E) || color == 6'h00)
        if (light_cnt < 9'd17) light_cnt <= 9'd17;
    end
  end
end

endmodule

