# Copyright 2023 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#

GIT ?= git
BENDER ?= bender
VSIM ?= vsim

PARAMS = "ISOLATE=1 BLEN=7   PHI=4" \
         "ISOLATE=0 BLEN=15  PHI=3" \
         "ISOLATE=0 BLEN=15  PHI=4" \
         "ISOLATE=0 BLEN=15  PHI=5" \
         "ISOLATE=0 BLEN=15  PHI=8" \
         "ISOLATE=0 BLEN=255 PHI=3" \
         "ISOLATE=0 BLEN=255 PHI=4" \
         "ISOLATE=0 BLEN=255 PHI=5" \
         "ISOLATE=0 BLEN=255 PHI=8"

all: build run

# Ensure half-built targets are purged
.DELETE_ON_ERROR:

ifdef gui
VSIM_ARGS := -do
else
VSIM_ARGS := -c -do
endif

# --------------
# RTL SIMULATION
# --------------

VLOG_ARGS += -suppress vlog-2583 -suppress vlog-13314 -suppress vlog-13233 -timescale \"1 ns / 1 ps\"
XVLOG_ARGS += -64bit -compile -vtimescale 1ns/1ns -quiet

define generate_vsim
	echo 'set ROOT [file normalize [file dirname [info script]]/$3]' > $1
	bender script $(VSIM) --vlog-arg="$(VLOG_ARGS)" $2 | grep -v "set ROOT" >> $1
	echo >> $1
endef

clean:
	rm -rf scripts/compile.tcl
	rm -rf work

# Download (partially non-free) simulation models from publically available sources;
# by running these targets or targets depending on them, you accept this (see README.md).
models/s27ks0641:
	mkdir -p $@
	rm -rf model_tmp && mkdir model_tmp
	cd model_tmp; wget https://www.infineon.com/dgdl/Infineon-S27KL0641_S27KS0641_VERILOG-SimulationModels-v05_00-EN.zip?fileId=8ac78c8c7d0d8da4017d0f6349a14f68
	cd model_tmp; mv 'Infineon-S27KL0641_S27KS0641_VERILOG-SimulationModels-v05_00-EN.zip?fileId=8ac78c8c7d0d8da4017d0f6349a14f68' model.zip
	cd model_tmp; unzip model.zip
	cd model_tmp; mv 'S27KL0641 S27KS0641' exe_folder
	cd model_tmp/exe_folder; unzip S27ks0641.exe
	cp model_tmp/exe_folder/S27ks0641/model/s27ks0641.v $@
	cp model_tmp/exe_folder/S27ks0641/model/s27ks0641_verilog.sdf models/s27ks0641/s27ks0641.sdf
	rm -rf model_tmp

scripts/compile.tcl: Bender.yml models/s27ks0641
	$(call generate_vsim, $@, -t rtl -t test,..)

build: scripts/compile.tcl
	$(VSIM) -c -do "source scripts/compile.tcl; exit"

run: clean build
	$(VSIM) $(VSIM_ARGS) "source scripts/start.tcl"

results:
	@for param_set in $(PARAMS); do \
		eval $$param_set ;\
		echo "Running testbench with $$param_set $$ISOLATE $$PHI $$BLEN merged $$ISOLATE-$$PHI-$$BLEN "; \
		$(VSIM) -c -do "vsim -t 1ps -voptargs=+acc -GIsolation=$$ISOLATE -GPHI=$$PHI -GBLEN=$$BLEN -suppress vopt-8386 tb_system_level -wlf logs/tb_system_level.wlf; set StdArithNoWarnings 1; set NumericStdNoWarnings 1; run -all; exit" ;\
		outfile="traces_rw_$$ISOLATE-$$PHI-$$BLEN.dat"; \
		mv traces_rw.dat $$outfile;\
	done
