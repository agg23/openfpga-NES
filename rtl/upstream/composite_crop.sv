// Overscan crop for the decoded composite picture: the same dots and lines
// the RGB path trims, applied by extending the receiver's blanking. The
// receiver's active window starts at dot 329 with two pixels per dot, and
// its first line is the pre-render line.
//
//   mode 0  Normal             dots 1-256, lines 8-231
//   mode 1  Vertical overscan  dots 1-256, lines 0-239
//   mode 2  Borders            all dots,   lines 0-239
//   mode 3  Everything         no crop

module composite_crop (
	input  wire       clk,
	input  wire       pix,      // one output pixel
	input  wire       hb_in,
	input  wire       vb_in,
	input  wire [1:0] mode,
	output wire       hb_out,
	output wire       vb_out
);

reg [9:0] px;
reg [8:0] ln;
reg hb_d;

always @(posedge clk) if (pix) begin
	hb_d <= hb_in;
	px <= hb_in ? 10'd0 : px + 10'd1;
	if (vb_in) ln <= 9'd0;
	else if (hb_in && !hb_d) ln <= ln + 9'd1;
end

wire crop_h = !mode[1] && (px < 10'd26 || px > 10'd537);
wire crop_v = (mode == 2'd0) ? (ln < 9'd9 || ln > 9'd232) :
              (mode != 2'd3) && (ln < 9'd1 || ln > 9'd240);

assign hb_out = hb_in | crop_h;
assign vb_out = vb_in | crop_v;

endmodule
