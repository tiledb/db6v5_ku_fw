#############################################################################
##
##
##
#############################################################################
##   ____  ____
##  /   /\/   /
## /___/  \  /
## \   \   \/    Core:          sem_ultra
##  \   \        Module:        sem_ultra_example_design
##  /   /        Filename:      sem_ultra_example_design.xdc
## /___/   /\    Purpose:       Constraints for the example design.
## \   \  /  \   
##  \___\/\___\
##
#############################################################################
##
## (c) Copyright 2014-2020 Xilinx, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Xilinx, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## Xilinx, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) Xilinx shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of Xilinx products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES. 
##
#############################################################################
##
## Constraint Description:
##
## These constraints are for physical implementation of the system level
## design example.
##
## The SEM controller initializes and manages the FPGA integrated silicon
## features for soft error mitigation.  When the controller is included
## in a design, do not include any design constraints related to these
## features.  See IP product guide for more information.
##
#############################################################################

########################################
## Example Design: Master Clock Timing
########################################
create_clock -name clk -period 40.0 [get_ports clk]

## The following are asynchronous and received by
## synchronizers for proper synchronization.

set_false_path -from [get_pins {example_support_wrapper/example_support/inst/example_cfg/cfg_icape3/CLK}] -to [get_pins {example_support_wrapper/example_support/inst/sem_controller/controller/controller_synchro_icap_prerror/sync_a/D}]
set_false_path -from [get_pins {example_support_wrapper/example_support/inst/example_cfg/cfg_icape3/CLK}] -to [get_pins {example_support_wrapper/example_support/inst/sem_controller/controller/controller_synchro_icap_prdone/sync_a/D}]
set_false_path -from [get_pins {example_support_wrapper/example_support/inst/example_cfg/cfg_icape3/CLK}] -to [get_pins {example_support_wrapper/example_support/inst/sem_controller/controller/controller_synchro_icap_avail/sync_a/D}]

########################################
## Example Design: UART Pin Timing
########################################

## Constraints on the UART pin timing; these are
## not critical as the signaling is asynchronous.

set_input_delay -clock clk -max -40.0 [get_ports uart_rx]
set_input_delay -clock clk -min 80.0 [get_ports uart_rx]

set_output_delay -clock clk -40.0 [get_ports uart_tx] -max
set_output_delay -clock clk 0 [get_ports uart_tx] -min

########################################
## Example Design: Logic Placement
########################################

create_pblock sem
resize_pblock [get_pblocks sem] -add {SLICE_X82Y75:SLICE_X87Y89}
resize_pblock [get_pblocks sem] -add {RAMB36_X8Y14:RAMB36_X8Y17}
resize_pblock [get_pblocks sem] -add {DSP48E2_X15Y30:DSP48E2_X15Y35}
add_cells_to_pblock -pblock sem -cells [get_cells example_support_wrapper/example_uart/*]
add_cells_to_pblock -pblock sem -cells [get_cells example_support_wrapper/example_support/inst/sem_controller/*]

# Force FRAME_ECC to the site in this SLR.
set_property LOC CONFIG_SITE_X0Y0 [get_cells example_support_wrapper/example_support/inst/example_cfg/cfg_frame_ecce3]
# Force ICAP to the site in this SLR.
set_property LOC CONFIG_SITE_X0Y0 [get_cells example_support_wrapper/example_support/inst/example_cfg/cfg_icape3]


########################################
## Example Design: Pin Placement Example 
## Syntax
########################################

#set_property PACKAGE_PIN <package pin> [get_ports clk]
#set_property PACKAGE_PIN <package pin> [get_ports uart_rx]
#set_property PACKAGE_PIN <package pin> [get_ports uart_tx]


#############################################################################
##
#############################################################################
