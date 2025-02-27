if (($args.count -ne 1) -or ($args[0] -eq "")) {
  Write-Output "Expected build type arg"
  exit 1
}

$build_type = $args[0]

quartus_sh -t generate.tcl $build_type

$exitcode = $LASTEXITCODE
if ($exitcode -ne 0) {
  Write-Output "Build failed with $exitcode"
  exit $exitcode
}

$output_file = "nes_set1.rev"

if (($build_type -eq "MMAPPER_SET1")) {
  $output_file = "nes_set1.rev"
} elseif (($build_type -eq "MMAPPER_SET2")) {
  $output_file = "nes_set2.rev"
}
