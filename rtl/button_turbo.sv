module button_turbo (
    input wire clk,

    input wire [2:0] turbo_speed,
    input wire vsync,

    input wire a_button_turbo,
    input wire b_button_turbo,

    output reg a_turbo = 0,
    output reg b_turbo = 0
);
  reg [3:0] a_turbo_counter = 0;
  reg [3:0] b_turbo_counter = 0;
  reg prev_vsync = 0;

  always @(posedge clk) begin
    prev_vsync <= vsync;

    if (vsync && ~prev_vsync) begin
      // Tick turbo
      if (a_button_turbo || a_turbo) begin
        // Either button is pressed, or we're still outputting the turbo state
        a_turbo_counter <= a_turbo_counter + 4'h1;

        // I can't get a task to work for this, so I guess I have to deal with duplicating all of it :(
        case (turbo_speed)
          3'h0: begin
            // No turbo enabled
            a_turbo_counter <= 0;
            a_turbo <= 0;
          end
          3'h1: begin
            if (a_turbo_counter >= 4'h9) begin
              // 3hz
              a_turbo_counter <= 0;
              a_turbo <= ~a_turbo;
            end
          end
          3'h2: begin
            if (a_turbo_counter >= 4'h5) begin
              // 5hz
              a_turbo_counter <= 0;
              a_turbo <= ~a_turbo;
            end
          end
          3'h3: begin
            if (a_turbo_counter >= 4'h3) begin
              // 7.5hz
              a_turbo_counter <= 0;
              a_turbo <= ~a_turbo;
            end
          end
          3'h4: begin
            if (a_turbo_counter >= 4'h2) begin
              // 10hz
              a_turbo_counter <= 0;
              a_turbo <= ~a_turbo;
            end
          end
          3'h5: begin
            if (a_turbo_counter >= 4'h1) begin
              // Toggle every other frame (15hz)
              a_turbo_counter <= 0;
              a_turbo <= ~a_turbo;
            end
          end
          3'h6: begin
            if (a_turbo_counter >= 4'h0) begin
              // Toggle every frame (30hz)
              a_turbo_counter <= 0;
              a_turbo <= ~a_turbo;
            end
          end
        endcase
      end

      if (b_button_turbo || b_turbo) begin
        // Either button is pressed, or we're still outputting the turbo state
        b_turbo_counter <= b_turbo_counter + 4'h1;

        case (turbo_speed)
          3'h0: begin
            // No turbo enabled
            b_turbo_counter <= 0;
            b_turbo <= 0;
          end
          3'h1: begin
            if (b_turbo_counter >= 4'h9) begin
              // 3hz
              b_turbo_counter <= 0;
              b_turbo <= ~b_turbo;
            end
          end
          3'h2: begin
            if (b_turbo_counter >= 4'h5) begin
              // 5hz
              b_turbo_counter <= 0;
              b_turbo <= ~b_turbo;
            end
          end
          3'h3: begin
            if (b_turbo_counter >= 4'h3) begin
              // 7.5hz
              b_turbo_counter <= 0;
              b_turbo <= ~b_turbo;
            end
          end
          3'h4: begin
            if (b_turbo_counter >= 4'h2) begin
              // 10hz
              b_turbo_counter <= 0;
              b_turbo <= ~b_turbo;
            end
          end
          3'h5: begin
            if (b_turbo_counter >= 4'h1) begin
              // Toggle every other frame (15hz)
              b_turbo_counter <= 0;
              b_turbo <= ~b_turbo;
            end
          end
          3'h6: begin
            if (b_turbo_counter >= 4'h0) begin
              // Toggle every frame (30hz)
              b_turbo_counter <= 0;
              b_turbo <= ~b_turbo;
            end
          end
        endcase
      end
    end
  end

endmodule
