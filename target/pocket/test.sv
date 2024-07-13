

		reg is_athena_rom = 1'b0;
		reg [7:0] patched_data;
		reg patch_rom_en; //Add this option to the Pocket Core menu

		always @(posedge clk_53_6_mhz) begin
			if(mem.addr == 25'h1 && mem.wr_data == 8'ha4) is_athena_rom <= 1'b1;
		end
		
		always @(*) begin
			patched_data <= mem.wr_data;

			//Assumes same ROM address scheme as in MiSTer
			if (patch_rom_en && is_athena_rom) begin
				case(mem.addr)
					25'h29e: patched_data <= 8'h48;
					25'h2a4: patched_data <= 8'h3e;
				endcase
			end
		end

		...

    AthenaCore snk_athena
    (
		...
		//hps_io rom interface
		.ioctl_addr          (mem.addr),
        .ioctl_wr            (mem.wr),
        .ioctl_data          (patched_data),

		...
	);