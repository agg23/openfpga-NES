# Run with quartus_sh -t generate.tcl

# Load Quartus II Tcl Project package
package require ::quartus::project

# Required for compilation
package require ::quartus::flow

if { $argc != 1 } {
  puts "Exactly 1 argument required"
  exit
}

project_open projects/nes_pocket.qpf

if { [lindex $argv 0] == "NTSC_SET1" } {
   puts "NTSC_SET1"
   set_parameter -name USE_PAL_PLL -entity core_top '0
   set_parameter -name USE_MMAPPER_SET1 -entity cart_top '1
   set_parameter -name USE_MMAPPER_SET2 -entity cart_top '0
   set_parameter -name USE_PAL_PLL -entity nes_pll_01 '0
} elseif { [lindex $argv 0] == "NTSC_SET2" } {
  puts "NTSC_SET2"
   set_parameter -name USE_PAL_PLL -entity core_top '0
   set_parameter -name USE_MMAPPER_SET1 -entity cart_top '0
   set_parameter -name USE_MMAPPER_SET2 -entity cart_top '1
   set_parameter -name USE_PAL_PLL -entity nes_pll_01 '0
} elseif { [lindex $argv 0] == "PAL_SET1" } {
  puts "PAL_SET1"
   set_parameter -name USE_PAL_PLL -entity core_top '1
   set_parameter -name USE_MMAPPER_SET1 -entity cart_top '1
   set_parameter -name USE_MMAPPER_SET2 -entity cart_top '0
   set_parameter -name USE_PAL_PLL -entity nes_pll_01 '1
} elseif { [lindex $argv 0] == "PAL_SET2" } {
  puts "PAL_SET2"
   set_parameter -name USE_PAL_PLL -entity core_top '1
   set_parameter -name USE_MMAPPER_SET1 -entity cart_top '0
   set_parameter -name USE_MMAPPER_SET2 -entity cart_top '1
   set_parameter -name USE_PAL_PLL -entity nes_pll_01 '1
} else {
  puts "Unknown bitstream type [lindex $argv 0]"
  project_close
  exit
}

# save changes to .qsf
export_assignments

execute_flow -compile

project_close