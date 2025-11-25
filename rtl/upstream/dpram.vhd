--------------------------------------------------------------
-- Single port Block RAM
--------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY spram IS
	generic (
		addr_width    : integer := 8;
		data_width    : integer := 8;
		mem_init_file : string := " ";
		mem_name      : string := "MEM" -- for InSystem Memory content editor.
	);
	PORT
	(
		clock   : in  STD_LOGIC;
		address : in  STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
		data    : in  STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
		enable  : in  STD_LOGIC := '1';
		wren    : in  STD_LOGIC := '0';
		q       : out STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
		cs      : in  std_logic := '1'
	);
END spram;


ARCHITECTURE SYN OF spram IS
BEGIN
	spram_sz : work.spram_sz
	generic map(addr_width, data_width, 2**addr_width, mem_init_file, mem_name)
	port map(clock,address,data,enable,wren,q,cs);
END SYN;


--------------------------------------------------------------
-- Single port Block RAM with specific size
--------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY spram_sz IS
	generic (
		addr_width    : integer := 8;
		data_width    : integer := 8;
		numwords      : integer := 2**8;
		mem_init_file : string := " ";
		mem_name      : string := "MEM" -- for InSystem Memory content editor.
	);
	PORT
	(
		clock   : in  STD_LOGIC;
		address : in  STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
		data    : in  STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
		enable  : in  STD_LOGIC := '1';
		wren    : in  STD_LOGIC := '0';
		q       : out STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
		cs      : in  std_logic := '1'
	);
END ENTITY;

ARCHITECTURE SYN OF spram_sz IS
	signal q0 : std_logic_vector((data_width - 1) downto 0);
BEGIN
	q<= q0 when cs = '1' else (others => '1');

	altsyncram_component : altsyncram
	GENERIC MAP (
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		intended_device_family => "Cyclone V",
		lpm_hint => "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME="&mem_name,
		lpm_type => "altsyncram",
		numwords_a => numwords,
		operation_mode => "SINGLE_PORT",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		init_file => mem_init_file, 
		widthad_a => addr_width,
		width_a => data_width,
		width_byteena_a => 1
	)
	PORT MAP (
		address_a => address,
		clock0 => clock,
		data_a => data,
		wren_a => wren and cs,
		q_a => q0
	);

END SYN;



LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.all;

ENTITY dpram IS
	GENERIC
	(
		init_file			: string := " ";
		widthad_a			: natural;
		width_a				: natural := 8;
    outdata_reg_a : string := "UNREGISTERED";
    outdata_reg_b : string := "UNREGISTERED"
	);
	PORT
	(
		address_a		: IN STD_LOGIC_VECTOR (widthad_a-1 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (widthad_a-1 DOWNTO 0) := (others => '0');
		clock_a		: IN STD_LOGIC ;
		clock_b		: IN STD_LOGIC ;
		data_a		: IN STD_LOGIC_VECTOR (width_a-1 DOWNTO 0) := (others => '0');
		data_b		: IN STD_LOGIC_VECTOR (width_a-1 DOWNTO 0) := (others => '0');
		wren_a		: IN STD_LOGIC  := '0';
		wren_b		: IN STD_LOGIC  := '0';
		byteena_a	: IN STD_LOGIC_VECTOR (width_a/8-1 DOWNTO 0) := (others => '1');
		byteena_b	: IN STD_LOGIC_VECTOR (width_a/8-1 DOWNTO 0) := (others => '1');
		q_a		: OUT STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (width_a-1 DOWNTO 0)
	);
END dpram;


ARCHITECTURE SYN OF dpram IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
	SIGNAL sub_wire1	: STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);



	COMPONENT altsyncram
	GENERIC (
		address_reg_b		: STRING;
		clock_enable_input_a		: STRING;
		clock_enable_input_b		: STRING;
		clock_enable_output_a		: STRING;
		clock_enable_output_b		: STRING;
		indata_reg_b		: STRING;
		init_file		: STRING;
		intended_device_family		: STRING;
		lpm_type		: STRING;
		numwords_a		: NATURAL;
		numwords_b		: NATURAL;
		operation_mode		: STRING;
		outdata_aclr_a		: STRING;
		outdata_aclr_b		: STRING;
		outdata_reg_a		: STRING;
		outdata_reg_b		: STRING;
		power_up_uninitialized		: STRING;
		read_during_write_mode_port_a		: STRING;
		read_during_write_mode_port_b		: STRING;
		widthad_a		: NATURAL;
		widthad_b		: NATURAL;
		width_a		: NATURAL;
		width_b		: NATURAL;
		width_byteena_a		: NATURAL;
		width_byteena_b		: NATURAL;
		wrcontrol_wraddress_reg_b		: STRING
	);
	PORT (
			wren_a	: IN STD_LOGIC ;
			clock0	: IN STD_LOGIC ;
			wren_b	: IN STD_LOGIC ;
			clock1	: IN STD_LOGIC ;
			address_a	: IN STD_LOGIC_VECTOR (widthad_a-1 DOWNTO 0);
			address_b	: IN STD_LOGIC_VECTOR (widthad_a-1 DOWNTO 0);
			q_a	: OUT STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
			q_b	: OUT STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
			byteena_a	: IN STD_LOGIC_VECTOR (width_a/8-1 DOWNTO 0) ;
			byteena_b	: IN STD_LOGIC_VECTOR (width_a/8-1 DOWNTO 0) ;
			data_a	: IN STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
			data_b	: IN STD_LOGIC_VECTOR (width_a-1 DOWNTO 0)
	);
	END COMPONENT;

BEGIN
	q_a    <= sub_wire0(width_a-1 DOWNTO 0);
	q_b    <= sub_wire1(width_a-1 DOWNTO 0);

	altsyncram_component : altsyncram
	GENERIC MAP (
		address_reg_b => "CLOCK1",
		clock_enable_input_a => "BYPASS",
		clock_enable_input_b => "BYPASS",
		clock_enable_output_a => "BYPASS",
		clock_enable_output_b => "BYPASS",
		indata_reg_b => "CLOCK1",
		init_file => init_file,
		intended_device_family => "Cyclone III",
		lpm_type => "altsyncram",
		numwords_a => 2**widthad_a,
		numwords_b => 2**widthad_a,
		operation_mode => "BIDIR_DUAL_PORT",
		outdata_aclr_a => "NONE",
		outdata_aclr_b => "NONE",
		outdata_reg_a => outdata_reg_a,
		outdata_reg_b => outdata_reg_a,
		power_up_uninitialized => "FALSE",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
		widthad_a => widthad_a,
		widthad_b => widthad_a,
		width_a => width_a,
		width_b => width_a,
		width_byteena_a => width_a/8,
		width_byteena_b => width_a/8,
		wrcontrol_wraddress_reg_b => "CLOCK1"
	)
	PORT MAP (
		wren_a => wren_a,
		clock0 => clock_a,
		wren_b => wren_b,
		clock1 => clock_b,
		address_a => address_a,
		address_b => address_b,
		data_a => data_a,
		data_b => data_b,
		q_a => sub_wire0,
		q_b => sub_wire1,
		byteena_a => byteena_a,
		byteena_b => byteena_b
	);



END SYN;
