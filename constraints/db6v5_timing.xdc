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



#bitclks

create_clock -period 3.571 -name {p_adc_bitclk_in[0][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[0][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[1][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[1][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[2][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[2][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[3][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[3][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[4][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[4][p]}]
create_clock -period 3.571 -name {p_adc_bitclk_in[5][p]} -waveform {0.000 1.786} [get_ports {p_adc_bitclk_in[5][p]}]

create_clock -period 12.500 -name {p_gbt_cis_hss_clk80_local_in[p]} -waveform {0.000 6.250} [get_ports {p_gbt_cis_hss_clk80_local_in[p]}]


#create clocks
create_clock -period 25.000 -name {p_gbt_cfgbus_clk40_local_in[p]} -waveform {0.000 12.500} [get_ports {p_gbt_cfgbus_clk40_local_in[p]}]
create_clock -period 25.000 -name {p_gbt_mb_q0_clk40_local_in[p]} -waveform {0.000 12.500} [get_ports {p_gbt_mb_q0_clk40_local_in[p]}]
create_clock -period 25.000 -name {p_gbt_mb_q1_clk40_local_in[p]} -waveform {0.000 12.500} [get_ports {p_gbt_mb_q1_clk40_local_in[p]}]
#create_clock -period 6.250 -name {p_gth_refclk_gbtx_local_in[0][p]} -waveform {0.000 3.125} [get_ports {p_gth_refclk_gbtx_local_in[0][p]}]
create_clock -period 12.500 -name {p_gth_refclk_gbtx_local_in[0][p]} -waveform {0.000 6.250} [get_ports {p_gth_refclk_gbtx_local_in[0][p]}]
#create_clock -period 12.50 -name {p_gth_refclk_gbtx_local_in[1][p]} -waveform {0.000 6.50} [get_ports {p_gth_refclk_gbtx_local_in[1][p]}]

create_clock -period 10.000 -name {p_osc_clk_in[p]} -waveform {0.000 5.000} [get_ports {p_osc_clk_in[p]}]
create_clock -period 3.125 -name {p_gbt_tp_q0_clk40_local_in[p]} -waveform {0.000 1.562} [get_ports {p_gbt_tp_q0_clk40_local_in[p]}]
create_clock -period 3.125 -name {p_gbt_tp_q1_clk40_local_in[p]} -waveform {0.000 1.562} [get_ports {p_gbt_tp_q1_clk40_local_in[p]}]

create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[0][p]} -waveform {0.000 12.500} [get_ports {p_adc_gbtx_frameclk_in[0][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[1][p]} -waveform {0.000 12.500} [get_ports {p_adc_gbtx_frameclk_in[1][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[2][p]} -waveform {0.000 12.500} [get_ports {p_adc_gbtx_frameclk_in[2][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[3][p]} [get_ports {p_adc_gbtx_frameclk_in[3][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[4][p]} [get_ports {p_adc_gbtx_frameclk_in[4][p]}]
create_clock -period 25.000 -name {p_adc_gbtx_frameclk_in[5][p]} [get_ports {p_adc_gbtx_frameclk_in[5][p]}]
create_clock -period 12.500 -name {p_gth_refclk_gbtx_local_in[1][p]} [get_ports {p_gth_refclk_gbtx_local_in[1][p]}]

set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[0][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[0][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[5][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[0][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[1][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[1][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[4][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[1][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[2][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[2][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[3][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[2][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[2][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[3][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[3][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[3][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[1][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[4][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[4][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[4][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[0][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[5][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_bitclk_in[5][p]}] -group [get_clocks {p_adc_gbtx_frameclk_in[5][p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks p_clk320_out_mmcm_cis_interface]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks p_clk320_out_mmcm_cis_interface]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[0][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[1][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[2][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[3][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[4][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[5][p]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]_1}] -group [get_clocks p_clk40_out_pll_osc_clk]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[0][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[1][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[2][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[3][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[4][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_adc_gbtx_frameclk_in[5][p]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[0]}]
#set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]_1}] -group [get_clocks {txoutclk_out[0]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[0]_1}]
#set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]}] -group [get_clocks {txoutclk_out[0]_1}]

set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {p_clk320_out_mmcm_cis_interface}]

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

set_clock_groups -asynchronous -group [get_clocks p_clk40_out_pll_osc_clk] -group [get_clocks {p_gbt_tp_q0_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_gbt_tp_q0_clk40_local_in[p]}]

set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks GEN_PLL_IN_IP_US.pll0_clkout0]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks shared_pll0_clkoutphy_out_DIV]



set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {p_db_side_in_IBUF[0]_inst/O}]


set_clock_groups -asynchronous -group [get_clocks {txoutclk_out[0]_1}] -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {txoutclk_out[0]_1}]

set_clock_groups -asynchronous -group [get_clocks {p_clk40_out_pll_osc_clk}] -group [get_clocks {p_clk320_out_pll_dskclk}]
set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks {p_clk320_out_pll_dskclk}]



set_clock_groups -asynchronous -group [get_clocks {p_gbt_cfgbus_clk40_local_in[p]}] -group [get_clocks p_clk200_out_pll_osc_clk]

