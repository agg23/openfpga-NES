// NES Zapper emulation, by Kitrinx
// Apr, 20 2019

module zapper (
  input        clk,
  input        reset,
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

assign light = ~light_state;
assign trigger = trigger_state;

wire light_state = light_cnt > 0;

reg [8:0] light_cnt; // timer for 10-25 scanlines worth of "light" activity.
reg signed [9:0] pos_x, pos_y;
wire trigger_state = (trigger_cnt > 'd2_100_000);
reg old_msg;
reg [8:0] old_scanline;
reg old_vde;
reg [15:0] old_analog;
reg pressed;

int trigger_cnt;

parameter cross_size = 8'd4;

wire hit_x = ((pos_x >= cycle - cross_size && pos_x <= cycle + cross_size) && scanline == pos_y);
wire hit_y = ((pos_y >= scanline - cross_size && pos_y <= scanline + cross_size) && cycle == pos_x);

wire is_offscreen = ((pos_x >= 254 || pos_x <= 1) || (pos_y >= 224 || pos_y <= 8));
wire light_square = ((pos_x >= cycle - 3'd4 && pos_x <= cycle + 3'd4) && (pos_y >= scanline - 3'd4 && pos_y <= scanline + 3'd4));

// Jump through a few hoops to deal with signed math
wire signed [7:0] joy_x = analog[7:0];
wire signed [7:0] joy_y = analog[15:8];

wire trigger_btn = analog_trigger;

always @(posedge clk) begin
  reg [15:0] jy1, jy2;

  if (reset) begin
    {trigger_cnt, pos_x, pos_y, light_cnt} <= 0;
    reticle <= 0;
  end else begin
    old_scanline <= scanline;

    if (trigger_cnt > 0) trigger_cnt <= trigger_cnt - 1'b1;

    // "Drain" the light from the zapper over time
    if (old_scanline != scanline && light_cnt > 0) light_cnt <= light_cnt - 1'b1;

    if (trigger_cnt == 0 && trigger_btn && ~pressed) begin
      trigger_cnt <= 'd830000 + 'd2_100_000;
      pressed <= 1'b1;
    end

    if (~trigger_btn) pressed <= 0;

    jy1 <= {8'd0, joy_y} * 8'd240;
    jy2 <= jy1;

    old_vde <= vde;
    if(~old_vde & vde) begin
      old_analog = analog;
      if (old_analog != analog) begin
        pos_x <= joy_x;
        pos_y <= jy2[15:8];
      end else begin
      if(dpad_left) begin
          if (pos_x >= dpad_aim_speed) pos_x <= pos_x - dpad_aim_speed;
          else pos_x <= 0;
        end
        if(dpad_right) begin
          if(pos_x <= 8'd255 - dpad_aim_speed) pos_x <= pos_x + dpad_aim_speed;
          else pos_x <= 8'd255;
        end
        if(dpad_up) begin
          if (pos_y >= dpad_aim_speed) pos_y <= pos_y - dpad_aim_speed;
          else pos_y <= 0;
        end
        if(dpad_down) begin
          if (pos_y < 8'd240 - dpad_aim_speed) pos_y <= pos_y + dpad_aim_speed;
          else pos_y <= 8'd240;
        end
      end
    end

    reticle[0] <= (hit_x || hit_y);
    reticle[1] <= is_offscreen;
    
    // See if we're "pointed" at light
    if (light_square && ~is_offscreen) begin
      if (color == 'h20 || color == 'h30)
        light_cnt <= 'd26;
      else if ((color[5:4] == 3 && color < 'h3E) || color == 'h10)
        if (light_cnt < 'd20) light_cnt <= 'd20;
      else if ((color[5:4] == 2 && color < 'h2E) || color == 'h00)
        if (light_cnt < 'd17) light_cnt <= 'd17;
    end
  end
end

endmodule

