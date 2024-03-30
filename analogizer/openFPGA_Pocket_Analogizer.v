//This module encapsulates all Analogizer adapter signals
// Original work by @RndMnkIII. 
// Date: 01/2024 
// Release: 1.0

// *** Analogizer R.1 adapter ***
//Pin mappings:                                               VGA CONNECTOR                                                                                          USB3 TYPE A FEMALE CONNECTOR (SNAC)
//                        ______________________________________________________________________________________________________________________________________________________________________________________________________                             
//                       /                              VS  HS          R   G   B                                                                  1      2       3       4      5       6       7       8       9              \
//                       |                              |   |           |   |   |                                                                 VBUS   D-      D+      GND     RX-     RX+     GND_D   TX-     TX+             |
//FUNCTION:              |                              |   |           |   |   |                                                                 +5V    OUT1    OUT2    GND     IO3     IN4     IO5     IO6     IN7             |
//                       |  A                           |   |           |   |   |                                                                          ^       ^              ^       |       ^       ^       |              |
//                       |  N                           |   |           |   |   |                                                                          |       |              V       V       V       V       V              |
//                       |  A                           |   |           |   |   |                                                                                                                                                |                              
//                       |  L                           |   |           |   |   |                                                                                                                                                |            
//                       |  O                           |   |         +------------+                                                                                                                                             |
//  PIN DIR:             |  G                           |   |         |            |---------------------------------------------------------------------------------------------------------+                                   |
//  ^ OUTPUT             |  I                           |   |         |  RGB DAC   |                                                                                                         |                                   |
//  V INPUT              |  Z                           |   |         |            |===================================================================++                                    |                                   |
//                       |  E                           |   |         +------------+                                                                   ||                                    |                                   |
//                       |  R                           |   |            ||  |   |                                                                     ||                                    |                                   |         
//                       |                              |   +--------+   ||  |   +------------------------------------------------------------------+  ||                                    |                                   |                                  |
//                       |  R                           +------+     |   ||  +===============================++                                     |  ||                                    |                                   |
//                       |  1                                  |     |   ||                                  ||                                     |  ||                                    |                                   |
//                       |     CONF.B        IO5V       ---    |     |   \\================================  \\================================     |  \\================================   VID               IO3^  IO6^         |  
//                       |     CONF.A   IN4  ---  IN7   IO3V   VS    HS    R0    R1    R2    R3    R4    R5    G0    G1    G2    G3    G4    G5   /BLK   B0    B1    B2    B3    B4    B5   CLK  OUT1   OUT2  IO5^  IO6V         |  
//                       |      __3.3V__ |___ | __ |_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____^__GND__    |                                
//POCKET                 |     /         V    V    V     V     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     ^     V       \   | 
//CARTRIDGE PIN #:       \____|     1    2    3    4     5     6     7     8     9    10    11    12    13    14    15    16    17    18    19    20    21    22    23    24    25    26    27    28    29    30    31   32  |___/
//                             \_________|____|____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_____|_______/
//Pocket Pin Name:                       |    |    |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     | 
//cart_tran_bank0[7] --------------------+    |    |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     | 
//cart_tran_bank0[6] -------------------------+    |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank0[5] ------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank0[4] ------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank3[0] ------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     | 
//cart_tran_bank3[1] ------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     
//cart_tran_bank3[2] ------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank3[3] ------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank3[4] ------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank3[5] ------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank3[6] ------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank3[7] ------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//------------------                                                                                           |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank2[0] ------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     
//cart_tran_bank2[1] ------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank2[2] ------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank2[3] ------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank2[4] ------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank2[5] ------------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank2[6] ------------------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |     |
//cart_tran_bank2[7] ------------------------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |     |                                   
//------------------                                                                                                                                           |     |     |     |     |     |     |     |     |     |
//cart_tran_bank1[0] ------------------------------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |     |
//cart_tran_bank1[1] ------------------------------------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |     |
//cart_tran_bank1[2] ------------------------------------------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |     |
//cart_tran_bank1[3] ------------------------------------------------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |     |
//cart_tran_bank1[4] ------------------------------------------------------------------------------------------------------------------------------------------------------------------+     |     |     |     |     |
//cart_tran_bank1[5] ------------------------------------------------------------------------------------------------------------------------------------------------------------------------+     |     |     |     |
//cart_tran_bank1[6] ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+     |     |     |
//cart_tran_bank1[7] ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+     |     |
//cart_tran_pin30    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+     | 
//cart_tran_pin31    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
`default_nettype none
`timescale 1ns / 1ps

module openFPGA_Pocket_Analogizer #(parameter MASTER_CLK_FREQ=50_000_000) (
	input wire i_clk,
    input wire i_rst,
	input wire i_ena,
	//Video interface
	input wire [3:0] analog_video_type,
	input wire [7:0] R,
	input wire [7:0] G,
	input wire [7:0] B,
	input wire BLANKn,
	input wire Hsync,
	input wire Vsync,
	input wire video_clk,
	//SNAC interface
    input wire conf_AB,              //0 conf. A(default), 1 conf. B (see graph above)
    input wire [4:0] game_cont_type, //0-15 Conf. A, 16-31 Conf. B
    input wire [2:0] game_cont_sample_rate, //0 compatibility mode (slowest), 1 normal mode, 2 fast mode, 3 superfast mode
    output wire [15:0] p1_btn_state,
    output wire [15:0] p2_btn_state,
    output wire busy,   
	//Pocket Analogizer IO interface to the cartridge port
	inout   wire    [7:0]   cart_tran_bank2,
	output  wire            cart_tran_bank2_dir,
	inout   wire    [7:0]   cart_tran_bank3,
	output  wire            cart_tran_bank3_dir,
	inout   wire    [7:0]   cart_tran_bank1,
	output  wire            cart_tran_bank1_dir,
	inout   wire    [7:4]   cart_tran_bank0,
	output  wire            cart_tran_bank0_dir,
	inout   wire            cart_tran_pin30,
	output  wire            cart_tran_pin30_dir,
	output  wire            cart_pin30_pwroff_reset,
	inout   wire            cart_tran_pin31,
	output  wire            cart_tran_pin31_dir,
    //debug
    output wire o_stb
);
	wire [7:4] CART_BK0_OUT /* synthesis keep */;
    wire [7:4] CART_BK0_IN /* synthesis keep */;
    wire CART_BK0_DIR /* synthesis keep */; 
    wire [7:6] CART_BK1_OUT_P76 /* synthesis keep */;
    wire CART_PIN30_OUT /* synthesis keep */;
    wire CART_PIN30_IN /* synthesis keep */;
    wire CART_PIN30_DIR /* synthesis keep */; 
    wire CART_PIN31_OUT /* synthesis keep */;
    wire CART_PIN31_IN /* synthesis keep */;
    wire CART_PIN31_DIR /* synthesis keep */;

	openFPGA_Pocket_Analogizer_SNAC #(.MASTER_CLK_FREQ(MASTER_CLK_FREQ)) snac
	(
		.i_clk(i_clk),
		.i_rst(i_rst),
		.conf_AB(conf_AB),              //0 conf. A(default), 1 conf. B (see graph above)
		.game_cont_type(game_cont_type), //0-15 Conf. A, 16-31 Conf. B
		.game_cont_sample_rate(game_cont_sample_rate), //0 compatibility mode (slowest), 1 normal mode, 2 fast mode, 3 superfast mode
		.p1_btn_state(p1_btn_state),
		.p2_btn_state(p2_btn_state),
		.busy(busy),    
		//SNAC Pocket cartridge port interface (see graph above)   
		.CART_BK0_OUT(CART_BK0_OUT),
		.CART_BK0_IN(CART_BK0_IN),
		.CART_BK0_DIR(CART_BK0_DIR), 
		.CART_BK1_OUT_P76(CART_BK1_OUT_P76),
		.CART_PIN30_OUT(CART_PIN30_OUT),
		.CART_PIN30_IN(CART_PIN30_IN),
		.CART_PIN30_DIR(CART_PIN30_DIR), 
		.CART_PIN31_OUT(CART_PIN31_OUT),
		.CART_PIN31_IN(CART_PIN31_IN),
		.CART_PIN31_DIR(CART_PIN31_DIR),
		//debug
    	.o_stb(o_stb)
	); 
	//Choose type of analog video type of signal
	reg [5:0] Rout, Gout, Bout;
	reg HsyncOut, VsyncOut, BLANKnOut;
	wire [7:0] Yout, PrOut, PbOut;
	always @(*) begin
		case(analog_video_type)
			4'd0: begin //RGBS
				Rout = R[7:2];
				Gout = G[7:2];
				Bout = B[7:2];
				HsyncOut = Hsync;
				VsyncOut = 1'b1;
				BLANKnOut = BLANKn;
			end
			4'd1: begin //RGsB
				Rout = R[7:2];
				Gout = G[7:2];
				Bout = B[7:2];
				HsyncOut = 1'b1;
				VsyncOut = Hsync; //to DAC SYNC pin, SWITCH SOG ON
				BLANKnOut = BLANKn;
			end
			4'd2: begin //YPbPr
				Rout = PrOut[7:2];
				Gout = Yout[7:2];
				Bout = PbOut[7:2];
				HsyncOut = 1'b1;
				VsyncOut = YPbPr_sync; //to DAC SYNC pin, SWITCH SOG ON
				BLANKnOut = 1'b1; // YPbPr_blank; //FIX with 1'b0 ???
			end
			default: begin
				Rout = R[7:2];
				Gout = G[7:2];
				Bout = B[7:2];
				HsyncOut = Hsync;
				VsyncOut = 1'b1;
				BLANKnOut = BLANKn;
			end
		endcase
	end

	wire YPbPr_sync, YPbPr_blank;
	vga_out ybpr_video
	(
		.clk(video_clk),
		.ypbpr_en((analog_video_type == 4'd2)),

		.hsync(1'b0),
		.vsync(1'b0),
		.csync(Hsync),
		.de(BLANKn),

		.din({R,G,B}),
		.dout({PrOut,Yout,PbOut}),

		.hsync_o(),
		.vsync_o(),
		.csync_o(YPbPr_sync),
		.de_o(YPbPr_blank)
	);

	//infer tri-state buffers for cartridge data signals
	//BK0
	assign cart_tran_bank0         = i_rst | ~i_ena ? 4'hf : ((CART_BK0_DIR) ? CART_BK0_OUT : 4'hZ);     //on reset state set ouput value to 4'hf
	assign cart_tran_bank0_dir     = i_rst | ~i_ena ? 1'b1 : CART_BK0_DIR;                              //on reset state set pin dir to output
	assign CART_BK0_IN             = cart_tran_bank0;
	//BK3
	assign cart_tran_bank3         = i_rst | ~i_ena ? 8'hzz : {Rout[5:0],HsyncOut,VsyncOut};                          //on reset state set ouput value to 8'hZ
	assign cart_tran_bank3_dir     = i_rst | ~i_ena ? 1'b0  : 1'b1;                                     //on reset state set pin dir to input
	//BK2
	assign cart_tran_bank2         = i_rst | ~i_ena ? 8'hzz : {Bout[0],BLANKnOut,Gout[5:0]};                          //on reset state set ouput value to 8'hZ
	assign cart_tran_bank2_dir     = i_rst | ~i_ena ? 1'b0  : 1'b1;                                     //on reset state set pin dir to input
	//BK1
	assign cart_tran_bank1         = i_rst | ~i_ena ? 8'hzz : {CART_BK1_OUT_P76,video_clk,Bout[5:1]};      //on reset state set ouput value to 8'hZ
	assign cart_tran_bank1_dir     = i_rst | ~i_ena ? 1'b0  : 1'b1;                                     //on reset state set pin dir to input
	//PIN30
	assign cart_tran_pin30         = i_rst | ~i_ena ? 1'b0 : ((CART_PIN30_DIR) ? CART_PIN30_OUT : 1'bZ); //on reset state set ouput value to 4'hf
	assign cart_tran_pin30_dir     = i_rst | ~i_ena ? 1'bz : CART_PIN30_DIR;                              //on reset state set pin dir to output
	assign CART_PIN30_IN           = cart_tran_pin30;
	assign cart_pin30_pwroff_reset = i_rst | ~i_ena ? 1'b0 : 1'b1;                                      //1'b1 (GPIO USE)
	//PIN31
	assign cart_tran_pin31         = i_rst | ~i_ena ? 1'bz : ((CART_PIN31_DIR) ? CART_PIN31_OUT : 1'bZ); //on reset state set ouput value to 4'hf
	assign cart_tran_pin31_dir     = i_rst | ~i_ena ? 1'b0 : CART_PIN31_DIR;                            //on reset state set pin dir to input
	assign CART_PIN31_IN           = cart_tran_pin31;
endmodule