# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Thomas Benz <tbenz@iis.ee.ethz.ch>
#  
vsim -t 1ps -voptargs=+acc -suppress vopt-8386 tb_system_level -wlf logs/tb_system_level.wlf

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
log -r /*

run -all
