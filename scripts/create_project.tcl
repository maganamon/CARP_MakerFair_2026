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

# Basys 3 FPGA
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

set rtl_files {}

# Top-level RTL files
foreach file [glob -nocomplain "$repo_dir/*.sv"] {
    lappend rtl_files $file
}

# Common RTL
foreach file [glob -nocomplain "$repo_dir/common_rtl/*.sv"] {
    lappend rtl_files $file
}

# Input RTL
foreach file [glob -nocomplain "$repo_dir/inputs_rtl/*.sv"] {
    lappend rtl_files $file
}

# ------------------------------------------------------------
# Game RTL
#
# Games are stored in subdirectories:
#
# games/
# ├── simon_game/
# ├── wire_game/
# └── onboard_led_game/
#
# Search each game directory for .sv files.
# ------------------------------------------------------------

foreach game_dir [glob -nocomplain -types d "$repo_dir/games/*"] {

    foreach file [glob -nocomplain "$game_dir/*.sv"] {
        lappend rtl_files $file
    }

}


# ------------------------------------------------------------
# Add RTL files
# ------------------------------------------------------------

if {[llength $rtl_files] > 0} {

    puts ""
    puts "RTL source files found:"
    puts "----------------------------------------"

    foreach file $rtl_files {
        puts "  $file"
    }

    puts "----------------------------------------"

    add_files -fileset sources_1 $rtl_files

} else {

    puts "WARNING: No RTL source files found."

}


# ------------------------------------------------------------
# Set Top Module
# ------------------------------------------------------------

set_property top top_level_MakerFair [current_fileset]


# ------------------------------------------------------------
# Constraint Files
# ------------------------------------------------------------

set xdc_files [glob -nocomplain "$repo_dir/constraints/*.xdc"]

if {[llength $xdc_files] > 0} {

    puts ""
    puts "Constraint files found:"
    puts "----------------------------------------"

    foreach file $xdc_files {
        puts "  $file"
    }

    puts "----------------------------------------"

    add_files -fileset constrs_1 $xdc_files

} else {

    puts "WARNING: No XDC constraint files found."

}


# ------------------------------------------------------------
# Simulation / Testbench Files
# ------------------------------------------------------------

set tb_files {}

# Main testbench directory
foreach file [glob -nocomplain "$repo_dir/tb/*.sv"] {
    lappend tb_files $file
}

# Game-specific testbenches
foreach game_dir [glob -nocomplain -types d "$repo_dir/games/*"] {

    foreach file [glob -nocomplain "$game_dir/*_tb.sv"] {
        lappend tb_files $file
    }

}


if {[llength $tb_files] > 0} {

    puts ""
    puts "Simulation files found:"
    puts "----------------------------------------"

    foreach file $tb_files {
        puts "  $file"
    }

    puts "----------------------------------------"

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

save_project_as $project_name $project_dir


puts ""
puts "========================================"
puts "Vivado project created successfully!"
puts ""
puts "Project location:"
puts "    $project_dir"
puts ""
puts "Top module:"
puts "    top_level_MakerFair"
puts ""
puts "RTL files added:"
puts "    [llength $rtl_files]"
puts ""
puts "Simulation files added:"
puts "    [llength $tb_files]"
puts "========================================"
