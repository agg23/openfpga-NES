// NES Mouse-To-Zapper emulation, by Kitrinx
// Apr, 20 2019

module zapper (
	input        clk,
	input        reset,
	input [24:0] ps2_mouse,
	input [15:0] analog,
	input        analog_trigger,
	input        mode,
	input        trigger_mode,
	input  [8:0] cycle,
	input  [8:0] scanline,
	input  [5:0] color,
	output reg  [1:0] reticle,
	output       light,
	output       trigger
);

assign light = ~light_state;
assign trigger = trigger_state;

// Mouse control byte
// {Y overflow, X overflow Y sign bit, X sign bit, 1'b1, Middle Btn, Right Btn, Left Btn}
// 15-8 is x coordinate, 23:16 is y coordinate, in 2's complement.
// Bit 24 is high on a new packet.

wire signed [8:0] mouse_x = {ps2_mouse[4], ps2_mouse[15:8]};
wire signed [8:0] mouse_y = {ps2_mouse[5], ps2_mouse[23:16]};
wire mouse_msg = ps2_mouse[24];
wire light_state = light_cnt > 0;

wire signed [9:0] x_diff = pos_x + mouse_x;
wire signed [9:0] y_diff = pos_y - mouse_y;

reg [8:0] light_cnt; // timer for 10-25 scanlines worth of "light" activity.
reg signed [9:0] pos_x, pos_y;
wire trigger_state = (trigger_cnt > 'd2_100_000);
reg old_msg;
reg [8:0] old_scanline;
reg pressed;

int trigger_cnt;

wire hit_x = ((pos_x >= cycle - 1'b1 && pos_x <= cycle + 1'b1) && scanline == pos_y);
wire hit_y = ((pos_y >= scanline - 1'b1 && pos_y <= scanline + 1'b1) && cycle == pos_x);

wire is_offscreen = ((pos_x >= 254 || pos_x <= 1) || (pos_y >= 224 || pos_y <= 8));
wire light_square = ((pos_x >= cycle - 3'd4 && pos_x <= cycle + 3'd4) && (pos_y >= scanline - 3'd4 && pos_y <= scanline + 3'd4));

// Jump through a few hoops to deal with signed math
wire signed [7:0] joy_x = analog[7:0];
wire signed [7:0] joy_y = analog[15:8];
wire [7:0] joy_x_a = joy_x + 8'd128;
wire [7:0] joy_y_a = joy_y + 8'd128;

wire trigger_btn = trigger_mode ? analog_trigger : ps2_mouse[0];

always @(posedge clk) begin
	reg [15:0] jy1, jy2;

	if (reset) begin
		{trigger_cnt, pos_x, pos_y, light_cnt} <= 0;
		reticle <= 0;
	end else begin
		old_scanline <= scanline;
		old_msg <= mouse_msg;

		if (trigger_cnt > 0) trigger_cnt <= trigger_cnt - 1'b1;

		// "Drain" the light from the zapper over time
		if (old_scanline != scanline && light_cnt > 0) light_cnt <= light_cnt - 1'b1;

		// Update mouse coordinates if needed
		if (~old_msg & mouse_msg & ~mode) begin
			if (x_diff <= 0)
				pos_x <= 0;
			else if (x_diff >= 255)
				pos_x <= 10'd255;
			else
				pos_x <= x_diff;

			if (y_diff <= 0)
				pos_y <= 0;
			else if (y_diff >= 255)
				pos_y <= 10'd255;
			else
				pos_y <= y_diff;
		end

		// Check for the mapped trigger button regardless of mode
		if (trigger_cnt == 0 && trigger_btn && ~pressed) begin
			trigger_cnt <= 'd830000 + 'd2_100_000;
			pressed <= 1'b1;
		end

		if (~trigger_btn) pressed <= 0;
		
		jy1 <= {8'd0, joy_y_a} * 8'd240;
		jy2 <= jy1;

		// Update X/Y based on analog stick if in joystick mode
		if (mode) begin
			pos_x <= joy_x_a;
			pos_y <= jy2[15:8];
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

