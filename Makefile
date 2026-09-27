.PHONY: all lint icarus sim vsim clean

RTL_DIRS := inputs_rtl game_rtl common_rtl
TB_DIR   := tb

RTL_FILES := $(foreach dir,$(RTL_DIRS),$(wildcard $(dir)/*.sv))
TB_FILES  := $(wildcard $(TB_DIR)/*.sv)

ALL_SV := $(RTL_FILES) $(TB_FILES)

SIM_OUT := build/sim
WAVE    := wave.vcd


all: lint icarus sim


lint:
	@echo "Linting with Verilator...."
	verilator --lint-only --timing -Wall -Wno-MULTITOP $(ALL_SV)
	@echo ".... End Lint."


icarus:
	@echo "Running Icarus...."
	mkdir -p build
	iverilog -g2012 -o $(SIM_OUT) $(ALL_SV)
	@echo ".... End Icarus."


sim:
	@echo "Running Sim...."
	vvp $(SIM_OUT)
	@echo "Opening WaveForm...."
	gtkwave $(WAVE)


vsim:
	@echo "Running Verilator Sim...."
	verilator --binary --timing $(ALL_SV)
	@echo ".... End Verilator Sim."


clean:
	rm -rf build
	rm -rf obj_dir
	rm -f *.vcd

win_build:
	& "C:\Xilinx\2025.1\Vivado\bin\vivado.bat" -mode batch -source ".\scripts\create_project.tcl"

win_open:
	& "C:\Xilinx\2025.1\Vivado\bin\vivado.bat" ".\vivado_project\MakerFaire_2026.xpr"

TOP_SRCS := top_level_MakerFair.sv common_rtl/*.sv inputs_rtl/*.sv \
            games/simon_game/simon_fsm.sv \
            games/simon_game/simon_led_controller.sv \
            games/simon_game/simon_press_echo.sv

top-sim:
	iverilog -g2012 -s top_level_MakerFair_tb -o top_tb.vvp tb/top_level_MakerFair_tb.sv $(TOP_SRCS)
	vvp top_tb.vvp

top-lint:
	verilator --lint-only --timing -Wall --top-module top_level_MakerFair_tb tb/top_level_MakerFair_tb.sv $(TOP_SRCS)