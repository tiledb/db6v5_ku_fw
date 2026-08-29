----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:29:59 02/12/2014 
-- Design Name: 
-- Module Name:    integrator - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision 1 - File Created by Alberto Valero
-- Date: 05/06/2014 - Valencia
-- Additional Comments: 
	-- Revision 2 - Fernando Carrio
	-- Modified for new 10.24/4.8 Gbps links
	-- 02/07/2015


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
library tilecal;
use tilecal.db6_design_package.all;

entity db6_integrator_interface is
Port ( 
	p_master_reset_in                   : IN std_logic;
    p_clknet_in                  : in    t_db_clknet;
	p_db_reg_rx_in : in t_db_reg_rx;
    -- IOBUF moved to db7_io_box; split O/I/T instead of inout.
    p_integrator_sda_drive_out : out t_mb_std_logic;
    p_integrator_sda_tri_out   : out t_mb_std_logic;
    p_integrator_sda_read_in   : in  t_mb_std_logic;
    p_integrator_scl_drive_out : out t_mb_std_logic;
    p_integrator_scl_tri_out   : out t_mb_std_logic;
    p_integrator_scl_read_in   : in  t_mb_std_logic;
    p_mb_integrator_out : out t_mb_integrator
);
end db6_integrator_interface;

architecture Behavioral of db6_integrator_interface is

begin

  db4_integrator_wrapper : entity tilecal.db4_integrator_wrapper
    port map(
        p_clknet_in           => p_clknet_in,
        reset                 => p_db_reg_rx_in(cfb_strobe_reg)(c_integrator_reset_bit),
        clk40                 => p_clknet_in.refclk40,
        --clk80                 => p_clknet_in.refclk80,
        Integrator_config_reg => p_db_reg_rx_in(cfb_integrator_interval),
        --GBT_Integrator        => p_mb_integrator_out.gbt,
        EndOfOrbit            => p_clknet_in.bcr.bcr,
        p_end_of_read_out     => p_mb_integrator_out.end_of_read,
        I2C_SDA_DRIVE_OUT(0) => p_integrator_sda_drive_out.q0,
        I2C_SDA_DRIVE_OUT(1) => p_integrator_sda_drive_out.q1,
        I2C_SDA_TRI_OUT(0)   => p_integrator_sda_tri_out.q0,
        I2C_SDA_TRI_OUT(1)   => p_integrator_sda_tri_out.q1,
        I2C_SDA_READ_IN(0)   => p_integrator_sda_read_in.q0,
        I2C_SDA_READ_IN(1)   => p_integrator_sda_read_in.q1,
        I2C_SCL_DRIVE_OUT(0) => p_integrator_scl_drive_out.q0,
        I2C_SCL_DRIVE_OUT(1) => p_integrator_scl_drive_out.q1,
        I2C_SCL_TRI_OUT(0)   => p_integrator_scl_tri_out.q0,
        I2C_SCL_TRI_OUT(1)   => p_integrator_scl_tri_out.q1,
        I2C_SCL_READ_IN(0)   => p_integrator_scl_read_in.q0,
        I2C_SCL_READ_IN(1)   => p_integrator_scl_read_in.q1,
        Integ1DataOut         => p_mb_integrator_out.integrator_data.q0, -- BUS_to_Chipscope(15 downto 0),
        Integ2DataOut         => p_mb_integrator_out.integrator_data.q1, -- BUS_to_Chipscope(31 downto 16),
        Integ1EOR			    => p_mb_integrator_out.end_of_read_quadrant.q0, -- BUS_to_Chipscope(32),
        Integ2EOR			    => p_mb_integrator_out.end_of_read_quadrant.q1, -- BUS_to_Chipscope(33),
        CNTOrbit_O 				 => p_mb_integrator_out.orbit_counter, --p_bcr_counter_out(46 DOWNTO 39)
        p_bc_count_readout_out => p_mb_integrator_out.bc_count_readout,
        p_integrator_adc_data_out  => p_mb_integrator_out.integrator_adc_data
      );

end Behavioral;
