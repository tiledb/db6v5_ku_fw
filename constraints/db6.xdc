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

## bitstream setting constraints

set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 69 [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]
set_property CFGBVS gnd [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR no [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE yes [current_design]

#db side
#set_property PACKAGE_PIN AD15 [get_ports {p_db_side_in[0]}]
#set_property PACKAGE_PIN AE15 [get_ports {p_db_side_in[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_db_side_in[0]}]
set_property PACKAGE_PIN N19 [get_ports {p_db_side_in[0]}]

#md number
set_property PACKAGE_PIN AF19 [get_ports {p_md_number_in[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_md_number_in[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_md_number_in[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_md_number_in[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_md_number_in[0]}]

#leds
set_property PACKAGE_PIN Y13 [get_ports {p_leds_out[1]}]
set_property PACKAGE_PIN AA13 [get_ports {p_leds_out[2]}]
set_property PACKAGE_PIN AE16 [get_ports {p_leds_out[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {p_leds_out[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {p_leds_out[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {p_leds_out[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {p_leds_out[3]}]

#mgt pins
#set_property PACKAGE_PIN P5 [get_ports {p_gth_refclk_gbtx_local_in[1][n]}]
#set_property PACKAGE_PIN T5 [get_ports {p_gth_refclk_gbtx_remote_in[1][n]}]

set_property PACKAGE_PIN AF5 [get_ports {p_tx_sfp_out[0][n]}]

#set_property PACKAGE_PIN Y1 [get_ports {p_commbus_gth_rx_in[1][n]}]
#set_property PACKAGE_PIN T1 [get_ports {p_commbus_gth_loopback_rx_in[0][n]}]
#set_property PACKAGE_PIN P1 [get_ports {p_commbus_gth_rx_in[0][n]}]
#set_property PACKAGE_PIN R3 [get_ports {p_commbus_gth_tx_out[0][n]}]
#set_property PACKAGE_PIN AA3 [get_ports {p_commbus_gth_tx_out[1][n]}]
#set_property PACKAGE_PIN U3 [get_ports {p_commbus_gth_loopback_tx_out[0][n]}]

#sfp


#commbus_ddr



#cfgbus data inputs


set_property PACKAGE_PIN C9 [get_ports {p_cfgbus_data_local_in[0][p]}]
set_property PACKAGE_PIN E8 [get_ports {p_cfgbus_data_local_in[6][p]}]
set_property PACKAGE_PIN H9 [get_ports {p_cfgbus_data_local_in[4][p]}]
set_property PACKAGE_PIN F9 [get_ports {p_cfgbus_data_local_in[5][p]}]
set_property PACKAGE_PIN J10 [get_ports {p_cfgbus_data_local_in[7][p]}]

set_property PACKAGE_PIN A14 [get_ports {p_cfgbus_data_remote_in[0][n]}]
set_property PACKAGE_PIN A15 [get_ports {p_cfgbus_data_remote_in[2][n]}]
set_property PACKAGE_PIN B12 [get_ports {p_cfgbus_data_remote_in[6][n]}]
set_property PACKAGE_PIN A12 [get_ports {p_cfgbus_data_remote_in[1][n]}]
set_property PACKAGE_PIN F13 [get_ports {p_cfgbus_data_remote_in[4][n]}]
set_property PACKAGE_PIN C13 [get_ports {p_cfgbus_data_remote_in[5][n]}]
set_property PACKAGE_PIN H13 [get_ports {p_cfgbus_data_remote_in[7][n]}]
set_property PACKAGE_PIN G14 [get_ports {p_cfgbus_data_remote_in[3][n]}]

#adc readout


#set_property PACKAGE_PIN W24 [get_ports {p_adc_frameclk_in[5][n]}]
#set_property PACKAGE_PIN W26 [get_ports {p_adc_lg_data_in[5][n]}]
set_property PACKAGE_PIN Y25 [get_ports {p_adc_hg_data_in[5][p]}]
#set_property PACKAGE_PIN Y26 [get_ports {p_adc_hg_data_in[5][n]}]
#set_property PACKAGE_PIN V24 [get_ports {p_adc_bitclk_in[5][n]}]
set_property PACKAGE_PIN T23 [get_ports {p_adc_bitclk_in[4][p]}]
#set_property PACKAGE_PIN T24 [get_ports {p_adc_bitclk_in[4][n]}]
#set_property PACKAGE_PIN R26 [get_ports {p_adc_hg_data_in[4][n]}]
set_property PACKAGE_PIN R22 [get_ports {p_adc_frameclk_in[4][p]}]
#set_property PACKAGE_PIN R23 [get_ports {p_adc_frameclk_in[4][n]}]
set_property PACKAGE_PIN P25 [get_ports {p_adc_lg_data_in[4][p]}]
#set_property PACKAGE_PIN R25 [get_ports {p_adc_lg_data_in[4][n]}]
#set_property PACKAGE_PIN E26 [get_ports {p_adc_lg_data_in[2][n]}]
set_property PACKAGE_PIN H26 [get_ports {p_adc_hg_data_in[2][p]}]
#set_property PACKAGE_PIN G26 [get_ports {p_adc_hg_data_in[2][n]}]
set_property PACKAGE_PIN F22 [get_ports {p_adc_frameclk_in[2][p]}]
#set_property PACKAGE_PIN F23 [get_ports {p_adc_frameclk_in[2][n]}]
#set_property PACKAGE_PIN J25 [get_ports {p_adc_bitclk_in[2][n]}]
set_property PACKAGE_PIN K23 [get_ports {p_adc_bitclk_in[3][p]}]
#set_property PACKAGE_PIN J23 [get_ports {p_adc_bitclk_in[3][n]}]
#set_property PACKAGE_PIN K22 [get_ports {p_adc_hg_data_in[3][n]}]
set_property PACKAGE_PIN G21 [get_ports {p_adc_frameclk_in[3][p]}]
#set_property PACKAGE_PIN G22 [get_ports {p_adc_frameclk_in[3][n]}]
set_property PACKAGE_PIN J21 [get_ports {p_adc_lg_data_in[3][p]}]
#set_property PACKAGE_PIN H21 [get_ports {p_adc_lg_data_in[3][n]}]
set_property PACKAGE_PIN A22 [get_ports {p_adc_hg_data_in[1][p]}]
#set_property PACKAGE_PIN A23 [get_ports {p_adc_hg_data_in[1][n]}]
#set_property PACKAGE_PIN A20 [get_ports {p_adc_lg_data_in[1][n]}]
#set_property PACKAGE_PIN C22 [get_ports {p_adc_frameclk_in[1][n]}]
#set_property PACKAGE_PIN E21 [get_ports {p_adc_bitclk_in[1][n]}]
#set_property PACKAGE_PIN C19 [get_ports {p_adc_bitclk_in[0][n]}]
set_property PACKAGE_PIN A17 [get_ports {p_adc_lg_data_in[0][p]}]
#set_property PACKAGE_PIN A18 [get_ports {p_adc_lg_data_in[0][n]}]
set_property PACKAGE_PIN B19 [get_ports {p_adc_hg_data_in[0][p]}]
#set_property PACKAGE_PIN A19 [get_ports {p_adc_hg_data_in[0][n]}]
set_property PACKAGE_PIN C17 [get_ports {p_adc_frameclk_in[0][p]}]
#set_property PACKAGE_PIN B17 [get_ports {p_adc_frameclk_in[0][n]}]


set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[3][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[3][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[3][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[3][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[3][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[3][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[3][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[3][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[4][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[4][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[4][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[4][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[4][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[4][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[4][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[4][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[5][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[5][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[5][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[5][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[5][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[5][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[5][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[5][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[2][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[2][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[2][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[2][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[2][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[2][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[2][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[2][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[1][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[1][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[1][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[1][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[0][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[0][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_frameclk_in[0][n]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_lg_data_in[0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_hg_data_in[0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_adc_bitclk_in[0][n]}]


#mb interface
#normal
#set_property PACKAGE_PIN C26 [get_ports {p_sdata_in[q0][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_sdata_in[q0][p]}]
#set_property PACKAGE_PIN D24 [get_ports {p_ssel_out[q0][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_ssel_out[q1][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_ssel_out[q1][n]}]
#set_property IOSTANDARD LVDS [get_ports {p_ssel_out[q0][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_sdata_out[q0][p]}]
#set_property PACKAGE_PIN A24 [get_ports {p_sclk_out[q0][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_sclk_out[q0][p]}]
#set_property PACKAGE_PIN AA24 [get_ports {p_sclk_out[q1][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_sclk_out[q1][p]}]
#set_property PACKAGE_PIN AB26 [get_ports {p_sdata_in[q1][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_sdata_in[q1][p]}]
#set_property PACKAGE_PIN AA25 [get_ports {p_sdata_out[q1][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_sdata_out[q1][p]}]
#set_property PACKAGE_PIN Y23 [get_ports {p_ssel_out[q1][p]}]
#set_property PACKAGE_PIN B24 [get_ports {p_sdata_out[q0][p]}]

#set_property DIFF_TERM_ADV TERM_100 [get_ports {p_sdata_in[q0][p]}]
#set_property DIFF_TERM_ADV TERM_100 [get_ports {p_sdata_in[q1][p]}]

#reversed
set_property IOSTANDARD LVDS [get_ports {p_sdata_in[q1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_ssel_out[q0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_ssel_out[q0][n]}]
set_property IOSTANDARD LVDS [get_ports {p_ssel_out[q1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_sdata_out[q1][p]}]
set_property PACKAGE_PIN A24 [get_ports {p_sclk_out[q1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_sclk_out[q1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_sclk_out[q0][p]}]
set_property PACKAGE_PIN AB26 [get_ports {p_sdata_in[q0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_sdata_in[q0][p]}]
set_property PACKAGE_PIN AA25 [get_ports {p_sdata_out[q0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_sdata_out[q0][p]}]

set_property DIFF_TERM_ADV TERM_100 [get_ports {p_sdata_in[q1][p]}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {p_sdata_in[q0][p]}]



#cis interface
#normal
#set_property PACKAGE_PIN D14 [get_ports {p_tph_out[q0][p]}]
#set_property PACKAGE_PIN G15 [get_ports {p_tpl_out[q0][p]}]
#set_property PACKAGE_PIN J11 [get_ports {p_tph_out[q1][p]}]
#set_property PACKAGE_PIN G11 [get_ports {p_tpl_out[q1][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_tph_out[q0][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_tph_out[q0][n]}]
#set_property IOSTANDARD LVDS [get_ports {p_tph_out[q1][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_tph_out[q1][n]}]
#set_property IOSTANDARD LVDS [get_ports {p_tpl_out[q1][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_tpl_out[q1][n]}]
#set_property IOSTANDARD LVDS [get_ports {p_tpl_out[q0][p]}]
#set_property IOSTANDARD LVDS [get_ports {p_tpl_out[q0][n]}]

#reversed
set_property PACKAGE_PIN J11 [get_ports {p_tph_out[q0][p]}]
set_property PACKAGE_PIN G11 [get_ports {p_tpl_out[q0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_tph_out[q1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_tph_out[q1][n]}]
set_property IOSTANDARD LVDS [get_ports {p_tph_out[q0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_tph_out[q0][n]}]
set_property IOSTANDARD LVDS [get_ports {p_tpl_out[q0][p]}]
set_property IOSTANDARD LVDS [get_ports {p_tpl_out[q0][n]}]
set_property IOSTANDARD LVDS [get_ports {p_tpl_out[q1][p]}]
set_property IOSTANDARD LVDS [get_ports {p_tpl_out[q1][n]}]


##serial id i2c interface

#gbtx interface
set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_rxready_in[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_rxready_in[1]}]
#set_property PACKAGE_PIN M25 [get_ports {p_gbtx_rxready_in[1]}]
#set_property PACKAGE_PIN J19 [get_ports {p_gbtx_rxready_in[0]}]

set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_datavalid_in[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_datavalid_in[1]}]

set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_i2c_scl_inout[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_i2c_scl_inout[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_i2c_sda_inout[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_i2c_sda_inout[0]}]



#system interface


#remote jtag
set_property PACKAGE_PIN W18 [get_ports p_tdo_remote_in]
set_property IOSTANDARD LVCMOS25 [get_ports p_tdo_remote_in]


#gbtx configsel (goes to proasic)
set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_configsel_out[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_gbtx_configsel_out[0]}]

#pgood
set_property PACKAGE_PIN AB16 [get_ports {p_pgood_in[db_1v5_3v3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_pgood_in[db_1v5_3v3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_pgood_in[db_1v2_5v0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_pgood_in[db_1v0_0v95]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_pgood_in[db_1v8_2v5]}]
set_property PACKAGE_PIN AA17 [get_ports {p_pgood_in[db_1v8_2v5]}]
set_property PACKAGE_PIN AA18 [get_ports {p_pgood_in[db_1v2_5v0]}]

# mainboard altera fpga reset
set_property IOSTANDARD LVCMOS25 [get_ports {p_mb_fpga_reset_low[q0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_mb_fpga_reset_low[q1]}]

set_property PACKAGE_PIN W20 [get_ports p_ku_hard_reset]
set_property IOSTANDARD LVCMOS25 [get_ports p_ku_hard_reset]
#set_property PULLUP true [get_ports p_ku_hard_reset]


#integrator
set_property PACKAGE_PIN AC12 [get_ports {p_integrator_sda_inout[q0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_integrator_sda_inout[q0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_integrator_scl_inout[q0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_integrator_scl_inout[q1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_integrator_sda_inout[q1]}]
set_property PACKAGE_PIN AB11 [get_ports {p_integrator_scl_inout[q1]}]




set_property IOSTANDARD LVCMOS18 [get_ports p_gbtx_i2c_rem_enable_out]



set_property IOSTANDARD SLVS_400_18 [get_ports {p_gbt_cfgbus_clk40_local_in[p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_gbt_cfgbus_clk40_local_in[n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[1][p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[1][n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[2][p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[2][n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[3][p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[3][n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[4][p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[4][n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[5][p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[5][n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[6][p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[6][n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[7][p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[7][n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[0][p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_cfgbus_data_local_in[0][n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_gbt_tp_q0_clk40_local_in[p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_gbt_tp_q0_clk40_local_in[n]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_gbt_tp_q1_clk40_local_in[p]}]
set_property IOSTANDARD SLVS_400_18 [get_ports {p_gbt_tp_q1_clk40_local_in[n]}]

set_property IOSTANDARD LVCMOS25 [get_ports p_sem_uart_rx_in]
set_property IOSTANDARD LVCMOS25 [get_ports p_sem_uart_tx_out]

