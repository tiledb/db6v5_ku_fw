# User post-bitstream hook (see Hog/Tcl/integrated/post-bitstream.tcl, which sources
# this file by convention as "./Top/<group>/<project>/post-bitstream.tcl" after doing
# its own git-describe-tagged archive copy into $dst_dir).
#
# In addition to that describe-tagged archive, also drop a copy of the bitstream,
# raw binary, and debug-probes file into bin/<timestamp>/, so successive builds are
# easy to find/diff by build time rather than only by (possibly "-dirty") git sha.
#
# Variables used below ($bin_dir, $work_path, $top_name) are already set by the
# sourcing post-bitstream.tcl at this point in its execution.

set ts_dir [file normalize "$bin_dir/[clock format [clock seconds] -format {%Y%m%d_%H%M%S}]"]
Msg Info "Creating timestamped bin subfolder $ts_dir..."
file mkdir $ts_dir

foreach e {.bit .bin .ltx} {
  set src [file normalize "$work_path/$top_name$e"]
  if {[file exists $src]} {
    Msg Info "Copying $src into $ts_dir..."
    file copy -force $src "$ts_dir/[file tail $src]"
  } else {
    Msg Debug "File $src not found, skipping."
  }
}
