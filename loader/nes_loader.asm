//Chip32 loader code for Analogizer NES Core
//RndMnkIII. 25/02/2025 : initial code - load bitstream based on NES ROM header
//           06/03/2025 : load NTSC/PAL bitstream based on iNES 2.0 ROM header. If not load NTSC by default.
//This code is based on the work of @agg23 openFPGA SNES core: https://github.com/agg23/openfpga-SNES
// Pseudocode:
// Check that is a iNES2.0 HEADER
// If it is a iNES2.0 Header Read the System Type Code: NTSC,PAL,Multisystem,Dendy(as PAL but compatible with NTSC ROMs)
// set the SysType to he readed code
// Load by default core NTSC
// If is MultiSystem read the FPGA space user setting for System Preference: if is Auto>NTSC, Auto>PAL or Auto>Dendy and assign type to NTSC,PAL or Dendy
// If is NTSC,PAL or Dendy and user setting Auto>... Choose the one from header setting. If the user setting is Force NTSC,PAL or Dendy, ignore header
// setting and assign the System Type based on User preference.
// If the header is not a iNES2.0 HEADER choose by default NTSC. If the user setting is Force NTSC,PAL or Dendy assign the System Type based on User preference.
arch chip32.vm
output "nes_loader.bin", create

constant DEBUG = 1

//NES Cartridge data slot (see data.json core file)
constant rom_dataslot = 0 

//Save state data slot
constant save_dataslot = 10
constant pal_dataslot = 11
constant analogizer_dataslot = 20


//number of mapper codes to check in the data table
constant num_audio_mappers = 9

// Host init command
constant put_core_reset = 0x4000
constant core_take_out_reset = 0x4001
constant host_init = 0x4002

//Addresses
constant is_nes20_mapper = 0x1000
constant rom_mapper_value = 0x1004
constant mmapper_set_value = 0x1008

//cpu_ppu_timing header[12][1:0]
// 00 RP2C02 ("NTSC NES")
// 01 RP2C07 ("Licensed PAL NES")
// 10 Multiple-region
// 11 UA6538 ("Dendy")
constant cpu_ppu_timing = 0x100C
constant is_nes_head = 0x1010
constant dirty_nes_head = 0x1014
constant nes20mapper = 0x1018
constant load_header_area = 0x1A00
constant load_analogizer_cfg_area = 0x1B00


// Error vector (0x0)
jp error_handler

// Init vector (0x2)
jp start

/// Includes ///
include "util.asm"
align(2)

// data (word size)
audio_mapper_codes:
//hex:5,13,14,18,1A,1F,45,55,D2
dw 5,19,20,24,26,31,69,85,210
//dw 5,19,547,24,26,31,69,85,210 //for testing only

start:
ld r1,#rom_dataslot //populate data slot
open r1,r2

//Load header values into memory
ld r1,#0
seek()
ld r1,#0x10 // Load 0x10 bytes, the NES/NES2 header size
ld r2,#load_header_area // Read into read_space memory
read()
close
log_string("Loaded header data")
ld.l r3,(load_header_area)

//Check that is a valid NES header
cmp r3,#0x1A53454E // Compare against 0xFFFF
jp nz, error_invalid_nes_header // If not equal, skip
log_string("Seems a iNES header...")
ld r10,#0
//check header[7][3:2] == 2'b10
ld.b r4,(load_header_area + 7)
lsr r4,#2
and r4,#2
jp z,is_dirty
log_string("Seems a iNES 2.0 header...")
ld r10,#1   //Uses R10 as iNES2.0 check

is_dirty:
	//check is not ines2.0
	bit r10,#1
	jp nz, calculate_code

	log_string("Checking header[9][7:1] != 0...")
	//check header[9][7:1] != 0
	ld.b r4,(load_header_area + 9)
	and r4,#0xFE //mask bits 7-1
	cmp r4,#0 //check if all bits are zero
	jp z, is_dirty_chk2
	ld r11,#1 ////Uses R11 as dirty check
	jp calculate_code
is_dirty_chk2:
log_string("Checking header[10]!= 0...")
	//check header[10]!= 0
	ld.b r4,(load_header_area + 10)
	cmp r4,#0 //check if all bits are zero
	jp z, is_dirty_chk3
	ld r11,#1 ////Uses R11 as dirty check
	jp calculate_code
is_dirty_chk3:
log_string("Checking header[11]!= 0...")
	//check header[11]!= 0
	ld.b r4,(load_header_area + 11)
	cmp r4,#0 //check if all bits are zero
	jp z, is_dirty_chk4
	ld r11,#1 ////Uses R11 as dirty check
	jp calculate_code
is_dirty_chk4:
log_string("Checking header[12]!= 0...")
	//check header[12]!= 0
	ld.b r4,(load_header_area + 12)
	cmp r4,#0 //check if all bits are zero
	jp z, is_dirty_chk5
	ld r11,#1 ////Uses R11 as dirty check
	jp calculate_code
is_dirty_chk5:
log_string("Checking header[13]!= 0...")
	//check header[13]!= 0
	ld.b r4,(load_header_area + 13)
	cmp r4,#0 //check if all bits are zero
	jp z, is_dirty_chk6
	ld r11,#1 ////Uses R11 as dirty check
	jp calculate_code
is_dirty_chk6:
log_string("Checking header[14]!= 0...")
	//check header[14]!= 0
	ld.b r4,(load_header_area + 14)
	cmp r4,#0 //check if all bits are zero
	jp z, is_dirty_chk7
	ld r11,#1 ////Uses R11 as dirty check
	jp calculate_code
is_dirty_chk7:
log_string("Checking header[15s]!= 0...")
	//check header[15]!= 0
	ld.b r4,(load_header_area + 15)
	cmp r4,#0 //check if all bits are zero
	jp z, calculate_code
	ld r11,#1 ////Uses R11 as dirty check

calculate_code:
	ld.b r3,(load_header_area + 6)
	ld.b r4,(load_header_area + 7)
	ld.b r5,(load_header_area + 8) //used for ines2.0 mapper value (16bits)
	ld r6,#0 //temp register to store mapper code

	//check is dirty
	bit r11,#1
	jp nz, calculate_code2
	log_string("Calculate code for clean header...")

	//is not dirty
	ld r6,r4 //load header[7]
	and r6,#0xF0 //mask upper nibble of header[7]
	and r3,#0xF0 //mask upper nibble of header[6]
	lsr r3,#4 //shift header[6]
	or r6,r3 // {header[7][7:4], header[6][7:4]}
	jp calculate_code3

calculate_code2:
	//is dirty
	log_string("Calculate code for dirty header...")
	and r3,#0xF0 //mask upper nibble of header[6]
	lsr r3,#4 //shift header[6]
	or r6,r3 // {4'b0000, header[6][7:4]}

calculate_code3:
	//check is ines2.0
	bit r10,#1
	jp z, store_mapper_value

	log_string("Calculate code for ines2.0 header...")
	//shift left 8 bits
	and r5,#3
	asl r5,#8
	or r6,r5 //combine with already stored value

store_mapper_value:
	ld r7,#rom_mapper_value
	ld.w (r7),r6

check_mmapper_code:
	//use r3 as counter, init to 0
	//r4  #num_audio_mappers
	//r5  base: #audio_mapper_codes (word)
	//r6  current checked code address
	//r7  current checked code (word)
	//r8 tmp for mapper code address
	//r9  mapper code value (word)
	//r12 mapper set: 0 block1, 1 block2 

	log_string("Checking mapper code...")
	
	ld r3,#0
	ld r12,#0 //by default mapper set block1
	ld r4,#num_audio_mappers
	ld r6,#audio_mapper_codes
	ld r8,#rom_mapper_value
	ld.w r9,(r8)

check_mapper_code_loop:
	cmp r4,r3 //check if all cores were already checked
	jp z, analogizer_conf_file_chk

	ld.w r7,(r6) //load the current code to check
	cmp r7,r9 //if are equal assign set2 mapper and exit loop
	jp z, block_set2
	//increase counter and address
	add r3,#1 //increase code count
	add r6,#2 //advance 2 bytes (1 word)
	jp check_mapper_code_loop

block_set2:
	log_string("Mapper is set Block2 (audio mapper)...")
	ld r12,#1 //mapper set block2 (audio mappers)

//*** Analogizer configuration code ***
analogizer_conf_file_chk:
	ld r1,#analogizer_dataslot //populate data slot
	
	//check if exist
	queryslot r1
	jp nz,check_system
	//the file exist, then proceed to load the configuration data
	open r1,r2
	
	//Load analogizer configuration into memory
	ld r1,#0
	seek2()
	ld r1,#0x4 // Load 0x4 bytes
	ld r2,#load_analogizer_cfg_area // Read into read_space memory
	read2()
	close
    
	log_string("Loaded Analogizer configuration data")
    
	//for simulator testing only, disable on real system
	//ld r3,#0x000588A2
	//ld.l (load_analogizer_cfg_area),r3 // bits[19:16]: 0 Auto>NTSC, 1 Auto>PAL, 2 Auto>Dendy, 3 Force NTSC, 4 Force PAL, 5 Force Dendy
    
	//regional settigs bit[19:16] from Analogizer Config (AC) are stored into r4
	ld.l r4,(load_analogizer_cfg_area)
	ld r3,#16 //number of positions to shift
	lsr r4,r3  //right shift
	and r4,#0xF //mask the lower 4 bits

check_system:
	//AC       -> r4
	//ROM_TYPE -> r6
	//SYS_TYPE -> r5
    log_string("*** Checking system ***")

	//store SYS_TYPE into r5
	ld r5,#0 //default SYS_TYPE is NTSC

	//check is ines2.0
	cmp r10,#1
	jp nz, load_core //core #0 or #1 based on mapper value

	//load ROM_TYPE into r6
	ld.b r6,(load_header_area + 0xC) //System for iNES2.0
	and r6,#3 //use two lower bits

	//*** Start the configuration of SYS_TYPE ***
	log_string("*** Start the configuration of SYS_TYPE ***")

	//If AC is "Force NTSC"
	cmp r4,#3
	jp z, set_AC_to_NTSC

	//If AC is "Force PAL"
	cmp r4,#4
	jp z, set_AC_to_PAL

	//If AC is "Force Dendy"
	cmp r4,#5
	jp z, set_AC_to_Dendy

	//now starts the auto detect behaviour
	//If ROM_TYPE is NTSC
    cmp r6,#0
	jp z, set_AC_to_NTSC

	//If ROM_TYPE is PAL
	cmp r6,#1
	jp z, set_AC_to_PAL

	//If ROM_TYPE is Dendy
	cmp r6,#3
	jp z, set_AC_to_Dendy

	//If ROM_TYPE is Multi-Region, then needs to dissambiguate
	cmp r6,#2
	jp nz, AC_already_set

	//If AC is "Auto>NTSC" (is the default value and SYS_TYPE don't need to change)
	cmp r4,#0
	jp z, set_AC_to_NTSC

	//If AC is "Auto>PAL"
	cmp r4,#1
	jp z, set_AC_to_PAL

	//If AC is "Auto>Dendy"
	cmp r4,#2
	jp z, set_AC_to_Dendy
	jp AC_already_set

set_AC_to_NTSC:
	ld r5,#0
	jp AC_already_set

set_AC_to_PAL:
	ld r5,#1
	jp AC_already_set

set_AC_to_Dendy:
	ld r5,#2
	jp AC_already_set

AC_already_set:
	ld r8,r5 //copy SYS_TYPE to to r8
	and r8,#1 //take bit 0 on r8: 0 NTSC/Dendy, 1 PAL
    asl r8,#1 //multiply by 2
    or r12,r8 //add r8 to r12 now the bitstream to load is encoded into r12

load_core:
	//load the core based on mapper code selection and region setting
	core r12 //core #0 NTSC Block 1, core #1 NTSC Block 2 (audio mappers), core #2 PAL/Dendy Block 1, core #3 PAL/Dendy Block 2
	
load_settings:
	//load assets files
	ld r1,#rom_dataslot
	loadf r1 // Load ROM

	ld r1,#save_dataslot
	loadf r1 // Load Save

	ld r1,#pal_dataslot
	loadf r1 // Load Palettes

	ld r1,#analogizer_dataslot
	loadf r1 // Load Analogizer settings

	//Send SYS_TYPE to the CORE at address 0x330
	ld r8,#0x330
	pmpw r8,r5 

	//send ROM_TYPE
	//ld r8,#0x334
	//pmpw r8,r6 

	//send AC
	//ld r8,#0x338
	//pmpw r8,r4 

	//send iNES2.0
	//ld r8,#0x33C
	//pmpw r8,r10 
	
	// Start core
	ld r0,#host_init
	host r0,r0
	exit 0

invalid_nes_header:
close
exit 1

error_handler:
ld r14,#test_err_msg

print:
printf r14
exit 1

error_invalid_nes_header:
ld r14,#invalid_nes_header_msg
printf r14
exit 1

test_err_msg:
db "Error",0
align(2)

invalid_nes_header_msg:
db "Invalid NES header",0
align(2)





















