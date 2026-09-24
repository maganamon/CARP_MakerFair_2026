.PHONY: all no-icarus lint lint-led icarus sim vsim wave clean

# Shared RTL (bin2_to_onehot4.sv lives here)
LIB  := ../../inputs_rtl
TOP  := simon_fsm_tb
SRCS := simon_fsm_tb.sv simon_fsm.sv
WAVE := simon_fsm_tb.vcd

all: lint icarus sim

no-icarus: lint vsim

# Lint only the testbench + FSM (the LED controller has its own target)
lint:
	@echo "Linting with Verilator...."
	verilator --lint-only --timing -Wall -y $(LIB) --top-module $(TOP) $(SRCS)

# Needs simon_fifo and mux2to1: add their folder with another -y once you find it
lint-led:
	verilator --lint-only -Wall -y $(LIB) --top-module simon_led_controller simon_led_controller.sv

icarus:
	@echo "Running Icarus...."
	iverilog -g2012 -y $(LIB) -Y .sv -s $(TOP) -o simon_tb.vvp $(SRCS)
	@echo ".... End Icarus."

sim: icarus
	@echo "Running Sim...."
	vvp simon_tb.vvp
	@echo "Opening WaveForm...."
	gtkwave $(WAVE)

vsim:
	@echo "Running V-Sim...."
	verilator --binary --timing --trace -Wno-fatal -y $(LIB) --top-module $(TOP) $(SRCS)
	./obj_dir/V$(TOP)
	@echo "Opening WaveForm...."
	gtkwave $(WAVE)

wave:
	gtkwave $(WAVE)

clean:
	rm -rf obj_dir simon_tb.vvp $(WAVE)