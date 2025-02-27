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

if { [lindex $argv 0] == "MMAPPER_SET1" } {
  puts "MMAPPER_SET1"
  set_parameter -name USE_MMAPPER_SET1 -entity core_top '1
  set_parameter -name USE_MMAPPER_SET2 -entity core_top '0
} elseif { [lindex $argv 0] == "MMAPPER_SET2" } {
  puts "MMAPPER_SET2"
  set_parameter -name USE_MMAPPER_SET1 -entity core_top '0
  set_parameter -name USE_MMAPPER_SET2 -entity core_top '1
} else {
  puts "Unknown bitstream type [lindex $argv 0]"
  project_close
  exit
}

execute_flow -compile

project_close