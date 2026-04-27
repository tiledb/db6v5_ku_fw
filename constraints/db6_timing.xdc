#################################################################################--
###                                                                            ##--
### db6 constraints                                                            ##--
### Version: 1.0                                                               ##--
### Creation date: 2019-11-05                                                  ##--
### Created by: : Eduardo Valdes                                               ##--
###                                                                            ##--
### Modification date:                                                         ##--
### Modified by:                         		                               ##--
###                                                                            ##--
#################################################################################--


#set_false_path -from [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -to [get_clocks {txoutclk_out[0]}]
#set_false_path -from [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -to [get_clocks {txoutclk_out[1]}]
#set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[1]}]

set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks p_clk40_out_pll_osc_clk]



set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[0][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[1][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[2][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[3][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[4][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_adc_bitclk_in[5][p]}]


set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[0][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[1][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[2][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[3][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[4][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[5][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]




set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {p_db_side_in_IBUF[0]_inst/O}]


set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]_1}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[0]_1}]



set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks p_clk200_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks p_clk200_out_pll_osc_clk] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]









set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_gbt_tp_q0_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_gbt_tp_q1_clk40_local_in[p]}]





#set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[1]_1}] -group [get_clocks {txoutclk_out[0]_1}]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]_1}] -group [get_clocks p_clk40_out_pll_osc_clk]

#set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[1]}] -group [get_clocks {txoutclk_out[0]}]
#set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks {txoutclk_out[1]}]






set_false_path -from [get_clocks -of_objects [get_pins i_db6_clock_interface/i_mmcm_cis_interface/inst/mmcme3_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins i_db6_clock_interface/i_mmcm_cis_interface/inst/mmcme3_adv_inst/CLKOUT0]]









