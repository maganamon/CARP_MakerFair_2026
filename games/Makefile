.PHONY: all lint wavedump sim

all: lint icarus sim

no-icarus: lint vsim

lint:
	@echo "Linting with Verilator...."
	verilator --lint-only --timing -Wall *.sv
	@echo ".... End Lint."

icarus:
	@echo "Running Icarus...."
	iverilog -g2012 -o sim *.sv
	@echo ".... End Icarus."
sim:
	@echo "Running Sim...."
	vvp sim
	@echo "Opening WaveForm...."
	gtkwave wave.vcd

vsim: 
	@echo "Running V-Sim...."
	verilator --binary *.sv
	@echo "Opening WaveForm...."
	gtkwave wave.vcd