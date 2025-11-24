if (($args.count -ne 1) -or ($args[0] -eq "")) {
  Write-Output "Expected build type arg"
  exit 1
}

$build_type = $args[0]

# Tested with Quartus 21.1
quartus_sh -t generate.tcl $build_type

$exitcode = $LASTEXITCODE
if ($exitcode -ne 0) {
  Write-Output "Build failed with $exitcode"
  exit $exitcode
}

$output_file = "NTSC_SET1.rev"

if (($build_type -eq "NTSC_SET1")) {
  $output_file = "NTSC_SET1.rev"
} elseif (($build_type -eq "NTSC_SET2")) {
  $output_file = "NTSC_SET2.rev"
} elseif (($build_type -eq "PAL_SET1")) {
  $output_file = "PAL_SET1.rev"
}elseif (($build_type -eq "PAL_SET2")) {
  $output_file = "PAL_SET2.rev"
}

.\tools\reverse_bits.exe .\projects\output_files\nes_pocket.rbf ".\core_bitstreams\$output_file";

