--=================================================================================================--
--##################################   module information   #######################################--
--=================================================================================================--
--                                                                                         
-- company:               stockholm university                                                        
-- engineer:              eduardo valdes eduardo.valdes@cern.ch
-- engineer:              sam silverstein silver@fysik.su.se
--                                                                                                 
-- project name:          db_gbtx_interface                                                                
-- module name:                                                   
--                                                                                                 
-- language:              vhdl'93                                                                  
--                                                                                                   
-- target device:         xilinx kintex ultrascale                                                         
-- tool version:          vivado                                                               
--                                                                                                   
-- version:               1.0                                                                      
--
-- description:            
--
-- versions history:      date         version   author            			description
--
--                        22/03/2018   1.0       eduardo valdes santurio   	firmware for the controlling the i2c configuration/monitoring of the gbtx / tilecal daughterboard
--
--
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_gbtx_interface is
  port (       
    p_clknet_in 		: in t_db_clknet;
    p_master_reset_in  : in std_logic_vector(31 downto 0);
    
    p_cfgbus_data_local_in       : in t_cfgbus_bitslice; -- plain logic; IO primitives in db6_cfgbus_interface_io_iddr.vhd, instantiated from db7_io_box
--    p_cfgbus_data_remote_in       : in t_cfgbus_data_in;      
    --p_db_reg_rx_out      : out t_db_reg_rx;
    p_cfgbus_interface : out t_cfgbus_interface;
    p_bcr_out    : out t_bcr;
        
    p_db_reg_rx_in : in t_db_reg_rx;
    p_gbt_encoder_interface_in        : in t_gbt_encoder_interface;
    p_gbtx_i2c_rem_enable_out   : out std_logic;
    p_gbtx_control_in : in t_gbtx_control;
    p_gbtx_interface_out : out t_gbtx_interface;
    -- IOBUF moved to db7_io_box; split O/I/T instead of inout.
    p_sda_drive_out : out std_logic_vector(0 downto 0);
    p_sda_tri_out   : out std_logic_vector(0 downto 0);
    p_sda_read_in   : in  std_logic_vector(0 downto 0);
    p_scl_drive_out : out std_logic_vector(0 downto 0);
    p_scl_tri_out   : out std_logic_vector(0 downto 0);
    p_scl_read_in   : in  std_logic_vector(0 downto 0);
    p_gbtx_configsel_out : out std_logic_vector(0 downto 0);

    -- gbtx register readback ram port b debug address (see db6_gbtx_i2c_interface_testbeam.vhd)
    p_gbtx_reg_readback_address_in : in std_logic_vector(8 downto 0);

    p_leds_out : out std_logic_vector(3 downto 0)
            );
end db6_gbtx_interface;

architecture behavioral of db6_gbtx_interface is
signal s_gbtx_control : t_gbtx_control;
begin

p_gbtx_configsel_out(0) <= (not p_db_reg_rx_in(cfb_gbtx_reg_config)(c_gbtxb_configsel_bit));-- & (not p_db_reg_rx_in(cfb_gbtx_reg_config)(c_gbtxa_configsel_bit));
p_gbtx_i2c_rem_enable_out <= '0';
proc_gbtx_control: process(p_db_reg_rx_in(cfb_gbtx_reg_config)(c_gbtx_control_bit ))
begin
    if p_db_reg_rx_in(cfb_gbtx_reg_config)(29) = '0' then
        s_gbtx_control <= p_gbtx_control_in;
   else 
        s_gbtx_control.gbtx_default_config <= p_db_reg_rx_in(cfb_gbtx_reg_config)(28);
        s_gbtx_control.gbtx_trigger_i2c_operation <= p_db_reg_rx_in(cfb_gbtx_reg_config)(27);
        s_gbtx_control.gbtx_i2c_read_write_operation <= p_db_reg_rx_in(cfb_gbtx_reg_config)(26);
        s_gbtx_control.gbtx_i2c_speed(15 downto 8) <= p_db_reg_rx_in(cfb_db_debug)(23 downto 16);
        s_gbtx_control.gbtx_reg_address<=p_db_reg_rx_in(cfb_gbtx_reg_config)(23 downto 8);
        s_gbtx_control.gbtx_reg_value<=p_db_reg_rx_in(cfb_gbtx_reg_config)(7 downto 0);
   end if;
end process;   
      
i_db6_gbtx_i2c_interface : entity tilecal.db6_gbtx_i2c_interface_testbeam
  port map(       
        p_clknet_in => p_clknet_in,
--        p_master_reset_in  => p_master_reset_in,
        p_db_reg_rx_in => p_db_reg_rx_in,
        p_gbt_encoder_interface_in => p_gbt_encoder_interface_in,
        
        p_gbtx_control_in => s_gbtx_control,
        p_gbtx_interface_out => p_gbtx_interface_out,
        p_sda_drive_out => p_sda_drive_out(0),
        p_sda_tri_out   => p_sda_tri_out(0),
        p_sda_read_in   => p_sda_read_in(0),
        p_scl_drive_out => p_scl_drive_out(0),
        p_scl_tri_out   => p_scl_tri_out(0),
        p_scl_read_in   => p_scl_read_in(0),
        p_gbtx_reg_readback_address_in => p_gbtx_reg_readback_address_in,

        p_leds_out => open
);


i_db6_cfgbus_interface : entity tilecal.db6_cfgbus_interface
    generic map (
        g_tmr_enabled      => 0,        -- 0 = no no_tmr, 1 = tmr
        g_vio_configbus_registers => 0)
    Port map (     
        p_master_reset_in => p_master_reset_in(c_cfgbus_reset_bit),
        p_clknet_in => p_clknet_in,
        p_cfgbus_data_local_in => p_cfgbus_data_local_in,
--        p_cfgbus_data_remote_in => p_cfgbus_data_remote_in,
        p_gbt_encoder_interface_in => p_gbt_encoder_interface_in,      
        --p_db_reg_rx_out => p_db_reg_rx_out,
        p_cfgbus_interface => p_cfgbus_interface,
        p_leds_out => open,
        p_bcr_out => p_bcr_out
    );
        


end behavioral;