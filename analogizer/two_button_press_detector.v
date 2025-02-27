//Module to detect when two buttons are pressed for 2 seconds
module two_button_press_detector(
    input wire clk,           // System clock at 28.375160 MHz
    input wire reset,         // Reset signal
    input wire button1,       // First button input
    input wire button2,       // Second button input
    output reg detection_done // Output signal when both buttons are pressed for 2 seconds
);

    parameter COUNT_MAX = 56750320; // Number of clock cycles for 2 seconds
    reg [31:0] counter;               // Counter for 2 seconds

    // State machine states
    localparam IDLE = 0, 
               COUNTING = 1;
    reg state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            detection_done <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (button1 && button2) begin
                        counter <= 0;
                        state <= COUNTING;
                    end else begin
                        detection_done <= 0;
                        counter <= 0;
                    end
                end
                COUNTING: begin
                    if (button1 && button2) begin
                        if (counter < COUNT_MAX - 1) begin
                            counter <= counter + 1;
                            detection_done <= 0;
                        end else begin
                            detection_done <= 1;
                            state <= IDLE; // Reset back to IDLE after detection
                        end
                    end else begin
                        detection_done <= 0;
                        state <= IDLE;
                        counter <= 0; // Reset counter if buttons are released before 2 seconds
                    end
                end
            endcase
        end
    end

endmodule