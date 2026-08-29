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

#i2c
set_property IOSTANDARD LVCMOS33 [get_ports {p_xadc_i2c_inout[scl]}]
set_property IOSTANDARD LVCMOS33 [get_ports {p_xadc_i2c_inout[sda]}]
set_property PACKAGE_PIN M21 [get_ports {p_xadc_i2c_inout[sda]}]
set_property PULLTYPE PULLUP [get_ports {p_xadc_i2c_inout[scl]}]
set_property PULLTYPE PULLUP [get_ports {p_xadc_i2c_inout[sda]}]


#p_good
set_property PACKAGE_PIN R18 [get_ports {p_pgood_in[mb_5v0_n_3v3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_pgood_in[mb_5v0_n_3v3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_pgood_in[mb_2v5_1v2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {p_pgood_in[mb_5v0_1v8]}]
set_property PACKAGE_PIN T18 [get_ports {p_pgood_in[mb_10v0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {p_pgood_in[mb_10v0]}]


set_property PACKAGE_PIN P12 [get_ports {p_xadc_analog_in[v][p]}]


# Input clock periods. These duplicate the values entered for the
#  input clocks. You can use these to time your system
#----------------------------------------------------------------
#create_clock -name dclk_in -period 25 [get_ports dclk_in]
#set_property IOSTANDARD ANALOG [get_ports  vp]
#set_property IOSTANDARD ANALOG [get_ports  vn]
#set_property PACKAGE_PIN AD26 [get_ports vauxp0]
#set_property IOSTANDARD ANALOG [get_ports  vauxp0]
#set_property PACKAGE_PIN AE26 [get_ports vauxn0]
#set_property IOSTANDARD ANALOG [get_ports  vauxn0]
#set_property PACKAGE_PIN AE25 [get_ports vauxp1]
#set_property IOSTANDARD ANALOG [get_ports  vauxp1]
#set_property PACKAGE_PIN AF25 [get_ports vauxn1]
#set_property IOSTANDARD ANALOG [get_ports  vauxn1]

#set_property PACKAGE_PIN AD20 [get_ports vauxp2]
#set_property IOSTANDARD ANALOG [get_ports  vauxp2]
#set_property PACKAGE_PIN AD21 [get_ports vauxn2]
#set_property IOSTANDARD ANALOG [get_ports  vauxn2]

#set_property PACKAGE_PIN AE20 [get_ports vauxp3]
#set_property IOSTANDARD ANALOG [get_ports  vauxp3]
#set_property PACKAGE_PIN AE21 [get_ports vauxn3]
#set_property IOSTANDARD ANALOG [get_ports  vauxn3]

#set_property PACKAGE_PIN V18 [get_ports vauxp4]
#set_property IOSTANDARD ANALOG [get_ports  vauxp4]
#set_property PACKAGE_PIN V19 [get_ports vauxn4]
#set_property IOSTANDARD ANALOG [get_ports  vauxn4]

#set_property PACKAGE_PIN W21 [get_ports vauxp5]
#set_property IOSTANDARD ANALOG [get_ports  vauxp5]
#set_property PACKAGE_PIN Y21 [get_ports vauxn5]
#set_property IOSTANDARD ANALOG [get_ports  vauxn5]

#set_property PACKAGE_PIN AF17 [get_ports vauxp6]
#set_property IOSTANDARD ANALOG [get_ports  vauxp6]
#set_property PACKAGE_PIN AF18 [get_ports vauxn6]
#set_property IOSTANDARD ANALOG [get_ports  vauxn6]

#set_property PACKAGE_PIN AF19 [get_ports vauxp7]
#set_property IOSTANDARD ANALOG [get_ports  vauxp7]
#set_property PACKAGE_PIN AF20 [get_ports vauxn7]
#set_property IOSTANDARD ANALOG [get_ports  vauxn7]

#set_property PACKAGE_PIN AF23 [get_ports vauxp8]
#set_property IOSTANDARD ANALOG [get_ports  vauxp8]
#set_property PACKAGE_PIN AF24 [get_ports vauxn8]
#set_property IOSTANDARD ANALOG [get_ports  vauxn8]

#set_property PACKAGE_PIN AE22 [get_ports vauxp9]
#set_property IOSTANDARD ANALOG [get_ports  vauxp9]
#set_property PACKAGE_PIN AF22 [get_ports vauxn9]
#set_property IOSTANDARD ANALOG [get_ports  vauxn9]

#set_property PACKAGE_PIN AB21 [get_ports vauxp10]
#set_property IOSTANDARD ANALOG [get_ports  vauxp10]
#set_property PACKAGE_PIN AC21 [get_ports vauxn10]
#set_property IOSTANDARD ANALOG [get_ports  vauxn10]

#set_property PACKAGE_PIN AC19 [get_ports vauxp11]
#set_property IOSTANDARD ANALOG [get_ports  vauxp11]
#set_property PACKAGE_PIN AD19 [get_ports vauxn11]
#set_property IOSTANDARD ANALOG [get_ports  vauxn11]

#set_property PACKAGE_PIN W18 [get_ports vauxp12]
#set_property IOSTANDARD ANALOG [get_ports  vauxp12]
#set_property PACKAGE_PIN W19 [get_ports vauxn12]
#set_property IOSTANDARD ANALOG [get_ports  vauxn12]

#set_property PACKAGE_PIN W16 [get_ports vauxp13]
#set_property IOSTANDARD ANALOG [get_ports  vauxp13]
#set_property PACKAGE_PIN Y16 [get_ports vauxn13]
#set_property IOSTANDARD ANALOG [get_ports  vauxn13]

#set_property PACKAGE_PIN AC18 [get_ports vauxp14]
#set_property IOSTANDARD ANALOG [get_ports  vauxp14]
#set_property PACKAGE_PIN AD18 [get_ports vauxn14]
#set_property IOSTANDARD ANALOG [get_ports  vauxn14]

#set_property PACKAGE_PIN AE17 [get_ports vauxp15]
#set_property IOSTANDARD ANALOG [get_ports  vauxp15]
#set_property PACKAGE_PIN AE18 [get_ports vauxn15]
#set_property IOSTANDARD ANALOG [get_ports  vauxn15]


#set_property LOC SYSMONE1_X0Y0 [get_cells -hier {*inst_sysmon} -filter {NAME =~ *inst_sysmon}]
##set_false_path -to [get_pins -hierarchical -filter {NAME =~ *inst_sysmon*/RESET}]
#set_false_path -to [get_pins -of [get_cells -hier -filter {NAME =~ *inst_sysmon*}] -filter {NAME =~*RESET}]
#set_property DONT_TOUCH true [get_cells -hierarchical -filter {NAME =~*/inst_sysmon*}]





















