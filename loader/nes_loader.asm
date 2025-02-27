//Chip32 loader code for Analogizer NES Core
//RndMnkIII. 25/02/2025.
//This code is based on the work of @agg23 openFPGA SNES core: https://github.com/agg23/openfpga-SNES
// 
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
seek()
ld r1,#0x10 // Load 0x10 bytes, the NES/NES2 header size
ld r2,#load_header_area // Read into read_space memory
read()

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
	//and r5,#3
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
	jp z, load_core

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

load_core:
	//file is no longer needed
	close
	//load the core based on mapper code selection
	core r12 //core #0  Block 1, core #1 Block 2 (audio mappers)
	

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





















