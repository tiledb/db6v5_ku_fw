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
    p_integrator_sda_inout   :      inout t_mb_std_logic;
    p_integrator_scl_inout   :      inout t_mb_std_logic; 	
    p_mb_integrator_out : out t_mb_integrator
);
end db6_integrator_interface;

architecture Behavioral of db6_integrator_interface is

--signal s_mb_integrator_out : t_mb_integrator;

--COMPONENT ila_integrator_debug
--PORT (
--	clk : IN STD_LOGIC;
--	probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
--	probe2 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
--	probe3 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
--	probe4 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
--	probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--	probe6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
--	probe7 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
--	probe8 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
--	probe9 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
--	probe10 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
--);
--END COMPONENT  ;

--signal s_reset_o : std_logic := '0';
begin

--s_reset_o <= p_db_reg_rx_in(cfb_strobe_reg)(c_integrator_reset_bit);

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
        I2C_SDA(0)               => p_integrator_sda_inout.q0, --BUS_4_I2C_SDA,
        I2C_SDA(1)               => p_integrator_sda_inout.q1,       
        I2C_SCL(0)               => p_integrator_scl_inout.q0, --BUS_4_I2C_SCL,
        I2C_SCL(1)               => p_integrator_scl_inout.q1,
        Integ1DataOut         => p_mb_integrator_out.integrator_data.q0, -- BUS_to_Chipscope(15 downto 0),
        Integ2DataOut         => p_mb_integrator_out.integrator_data.q1, -- BUS_to_Chipscope(31 downto 16),
        Integ1EOR			    => p_mb_integrator_out.end_of_read_quadrant.q0, -- BUS_to_Chipscope(32),
        Integ2EOR			    => p_mb_integrator_out.end_of_read_quadrant.q1, -- BUS_to_Chipscope(33),
        CNTOrbit_O 				 => p_mb_integrator_out.orbit_counter, --p_bcr_counter_out(46 DOWNTO 39)
        p_bc_count_readout_out => p_mb_integrator_out.bc_count_readout,
        p_integrator_adc_data_out  => p_mb_integrator_out.integrator_adc_data
      );


--i_ila_integrator_debug : ila_integrator_debug
--PORT map(
--	clk  => p_clknet_in.refclk40,
--	probe0(0) => s_mb_integrator_out.end_of_read, 
--	probe1 => p_db_reg_rx_in(cfb_integrator_interval), 
--	probe2 => (others=> '0'),
--	probe3 => s_mb_integrator_out.integrator_data.q0, 
--	probe4 => s_mb_integrator_out.integrator_data.q1, 
--	probe5(0) => p_clknet_in.bcr.bcr,
--	probe6 => s_mb_integrator_out.orbit_counter,
--	probe7(0) => s_mb_integrator_out.end_of_read_quadrant.q0,
--	probe7(1) => s_mb_integrator_out.end_of_read_quadrant.q1,
--	probe8 => (others=> '0'),
--	probe9 => (others=> '0'),
--	probe10 => (others=> '0')
--);


end Behavioral;
