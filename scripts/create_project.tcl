# ============================================================
# MakerFaire 2026
# Vivado Project Creation Script
#
# Run from repository root with:
#
#   vivado -source scripts/create_project.tcl
#
# This script generates a Vivado project from the source files
# stored in GitHub.
# ============================================================


# ------------------------------------------------------------
# Project Settings
# ------------------------------------------------------------

set project_name "MakerFaire_2026"

# Change this to your actual FPGA part
set fpga_part "xc7a35tcpg236-1"


# ------------------------------------------------------------
# Find repository root
# ------------------------------------------------------------

# Location of this TCL script
set script_dir [file dirname [file normalize [info script]]]

# Repository root is one folder above /scripts
set repo_dir [file normalize "$script_dir/.."]

# Generated Vivado project location
set project_dir "$repo_dir/vivado_project"


puts "========================================"
puts "MakerFaire 2026 Vivado Project Generator"
puts "========================================"
puts "Repository: $repo_dir"
puts "Project:    $project_dir"
puts "FPGA Part:  $fpga_part"
puts "========================================"


# ------------------------------------------------------------
# Create Vivado Project
# ------------------------------------------------------------

create_project $project_name $project_dir -part $fpga_part -force


# ------------------------------------------------------------
# RTL Source Files
# ------------------------------------------------------------

set rtl_files [glob -nocomplain \
    "$repo_dir/common_rtl/*.sv" \
    "$repo_dir/inputs_rtl/*.sv" \
    "$repo_dir/games/*.sv" \
    "$repo_dir/*.sv" \
]

if {[llength $rtl_files] > 0} {
    add_files -fileset sources_1 $rtl_files
} else {
    puts "WARNING: No RTL source files found."
}


# ------------------------------------------------------------
# Constraint Files
# ------------------------------------------------------------

set xdc_files [glob -nocomplain "$repo_dir/constraints/*.xdc"]

if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
} else {
    puts "WARNING: No XDC constraint files found."
}


# ------------------------------------------------------------
# Simulation / Testbench Files
# ------------------------------------------------------------

set tb_files [glob -nocomplain "$repo_dir/tb/*.sv"]

if {[llength $tb_files] > 0} {
    add_files -fileset sim_1 $tb_files
} else {
    puts "WARNING: No testbench files found."
}


# ------------------------------------------------------------
# Update Compile Order
# ------------------------------------------------------------

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1


# ------------------------------------------------------------
# Save Project
# ------------------------------------------------------------

puts ""
puts "========================================"
puts "Vivado project created successfully!"
puts ""
puts "Project location:"
puts "    $project_dir"
puts "========================================"