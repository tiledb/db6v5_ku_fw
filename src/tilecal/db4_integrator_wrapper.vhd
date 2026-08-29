----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Alberto Valero
-- 
-- Create Date:    16:39:27 10/08/2014 
-- Design Name: 
-- Module Name:    integrator_wrapper - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
-- 
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
	-- Revision 2 - Fernando Carrio
	-- Modified for new 10.24/4.8 Gbps links
	-- 02/07/2015
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library tilecal;
use tilecal.db6_design_package.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db4_integrator_wrapper is
Port (
    p_clknet_in                  : in    t_db_clknet;
	reset                  : in STD_LOGIC;
	clk40                  : in  STD_LOGIC;
	--clk80                  : in  STD_LOGIC;
	Integrator_config_reg  : IN std_logic_vector(31 downto 0);	
	GBT_Integrator         : OUT std_logic_vector(4 downto 0);
	EndOfOrbit		        : IN std_logic;
	-- IOBUF moved to db7_io_box; split O/I/T instead of inout.
	I2C_SDA_DRIVE_OUT : out std_logic_vector(1 downto 0);
	I2C_SDA_TRI_OUT   : out std_logic_vector(1 downto 0);
	I2C_SDA_READ_IN   : in  std_logic_vector(1 downto 0);
	I2C_SCL_DRIVE_OUT : out std_logic_vector(1 downto 0);
	I2C_SCL_TRI_OUT   : out std_logic_vector(1 downto 0);
	I2C_SCL_READ_IN   : in  std_logic_vector(1 downto 0);
	Integ1DataOut          : out STD_LOGIC_VECTOR(15 downto 0);
	Integ2DataOut          : out STD_LOGIC_VECTOR(15 downto 0);
	Integ1EOR			     : out STD_LOGIC;
	Integ2EOR			     : out STD_LOGIC;
	CNTOrbit_O             : OUT std_logic_VECTOR (7 DOWNTO 0);
	p_end_of_read_out      : out std_logic;
	p_integrator_adc_data_out      : out t_integrator_adc_data;
    p_bc_count_readout_out : out std_logic_vector(15 downto 0);
	p_sda_debug_out : out std_logic_vector(1 downto 0);
	p_scl_debug_out : out std_logic_vector(1 downto 0)	
	
);
end db4_integrator_wrapper;

architecture Behavioral of db4_integrator_wrapper is

	signal Integ1_request,Integ2_request : std_logic_vector(15 downto 0);
	signal Integ1_data_out,   Integ2_data_out : std_logic_vector(15 downto 0);
	signal Integ1_EndOfRead,  Integ2_EndOfRead : std_logic;
	
	ATTRIBUTE KEEP: STRING;
	ATTRIBUTE KEEP of Integ1_request,Integ2_request,Integ1_data_out,Integ2_data_out: signal is "TRUE";
	
	signal s_reset, s_reset_from_vio : std_logic;
	signal s_sda_debug, s_scl_debug : std_logic_vector(1 downto 0);
	signal s_gbt_integrator : std_logic_vector(4 downto 0);
	signal s_cntorbit : std_logic_vector(7 downto 0);
	signal s_statea, s_stateb : std_logic_vector(3 downto 0);

begin
    p_scl_debug_out <= s_scl_debug;
    p_sda_debug_out <= s_sda_debug;
    s_reset <= reset or s_reset_from_vio;
    CNTOrbit_O <= s_cntorbit;
	db4_integrator_main : entity tilecal.db4_integrator_main
	port map(
	    p_clknet_in => p_clknet_in,
		reset 						=> s_reset,
		clk40 						=> clk40,
		--clk80 						=> clk80, -- 85.333 MHz
		Integrator_config_reg 	=> Integrator_config_reg,
		Integ1_request  			=> Integ1_request,
		Integ2_request  			=> Integ2_request,
		Integ1_data_out 			=> Integ1_data_out,
		Integ2_data_out 			=> Integ2_data_out,
		Integ1_EndOfRead 			=> Integ1_EndOfRead,
		Integ2_EndOfRead 			=> Integ2_EndOfRead, 
		GBT_Integrator  			=> s_gbt_integrator,--GBT_Integrator,
		EndOfOrbit					=> EndOfOrbit, --BCR
		p_end_of_read_out           => p_end_of_read_out,
		p_bc_count_readout_out     => p_bc_count_readout_out,
		CNTOrbit_O					=> s_cntorbit, --BCR
		p_statea_out                => s_statea,
		p_stateb_out                => s_stateb,
		p_integrator_adc_data_out   => p_integrator_adc_data_out
	);
	GBT_Integrator <= s_gbt_integrator;
	
	Integ1DataOut          <=Integ1_data_out;
	Integ2DataOut          <=Integ2_data_out;
	Integ1EOR			     <=Integ1_EndOfRead;
	Integ2EOR			     <=Integ2_EndOfRead;
	
	db4_integrator_q0 : entity tilecal.db4_integrator
	port map (
	    p_clknet_in => p_clknet_in,
	    p_reset_in  => s_reset,
		CLK_IN         	=> clk40,   -- 156.25KHz MAX1169 specs say 400KHz max rate for scl
		Integrator_config_reg 	=> Integrator_config_reg,
		INTEG_DATA_IN  	=> Integ1_request,
		INTEG_DATA_OUT 	=> Integ1_data_out,
		EndOfRead		   => Integ1_EndOfRead,
		I2C_SDA_DRIVE_OUT => I2C_SDA_DRIVE_OUT(0),
		I2C_SDA_TRI_OUT   => I2C_SDA_TRI_OUT(0),
		I2C_SDA_READ_IN   => I2C_SDA_READ_IN(0),
		I2C_SCL_DRIVE_OUT => I2C_SCL_DRIVE_OUT(0),
		I2C_SCL_TRI_OUT   => I2C_SCL_TRI_OUT(0),
		I2C_SCL_READ_IN   => I2C_SCL_READ_IN(0),
		p_sda_debug_out => s_sda_debug(0),
		p_scl_debug_out => s_scl_debug(0)
	   );
	db4_integrator_q1 : entity tilecal.db4_integrator
	port map (
	    p_clknet_in => p_clknet_in,
	    p_reset_in  => s_reset,
		CLK_IN         	=> clk40,   -- 156.25KHz MAX1169 specs say 400KHz max rate for scl
        Integrator_config_reg =>Integrator_config_reg,
		INTEG_DATA_IN  	=> Integ2_request,
		INTEG_DATA_OUT 	=> Integ2_data_out,
		EndOfRead		   => Integ2_EndOfRead,
		I2C_SDA_DRIVE_OUT => I2C_SDA_DRIVE_OUT(1),
		I2C_SDA_TRI_OUT   => I2C_SDA_TRI_OUT(1),
		I2C_SDA_READ_IN   => I2C_SDA_READ_IN(1),
		I2C_SCL_DRIVE_OUT => I2C_SCL_DRIVE_OUT(1),
		I2C_SCL_TRI_OUT   => I2C_SCL_TRI_OUT(1),
		I2C_SCL_READ_IN   => I2C_SCL_READ_IN(1),
        p_sda_debug_out => s_sda_debug(1),
		p_scl_debug_out => s_scl_debug(1)
	   );

end Behavioral;

