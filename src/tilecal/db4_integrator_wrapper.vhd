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
	I2C_SDA                : inout STD_LOGIC_VECTOR(1 downto 0);
	I2C_SCL                : inout STD_LOGIC_VECTOR(1 downto 0);
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


COMPONENT ila_integrator_debug

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe13 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
	probe14 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
);
END COMPONENT  ;

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
		I2C_SDA        	=> I2C_SDA(0),
		I2C_SCL        	=> I2C_SCL(0),
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
		I2C_SDA        	=> I2C_SDA(1),
		I2C_SCL        	=> I2C_SCL(1),
        p_sda_debug_out => s_sda_debug(1),
		p_scl_debug_out => s_scl_debug(1)
	   );

--i_vio_integrator_debug : vio_integrator_debug
--  PORT MAP (
--    clk => clk80,
--    probe_in0 => Integrator_config_reg,
--    probe_in1 => Integ1_request,
--    probe_in2 => Integ1_data_out,
--    probe_in3 => Integ2_request,
--    probe_in4 => Integ2_data_out,
--    probe_in5 => s_gbt_integrator,
--    probe_in6 => s_cntorbit,
--    probe_in7(0) => Integ2_EndOfRead,
--    probe_in8(0) => Integ2_EndOfRead,
--    probe_in9(0) => s_sda_debug(0),
--    probe_in10(0) => s_scl_debug(1),
--    probe_in11(0) => s_sda_debug(0),
--    probe_in12(0) => s_scl_debug(1),
--    probe_in13 => s_statea,
--    probe_in14 => s_stateb,
--    probe_out0(0) => s_reset_from_vio
--  );


--i_ila_integrator_debug : ila_integrator_debug
--PORT MAP (
--	clk => clk40, --p_clknet_in.cfgbus_clk40,

--    probe0 => Integrator_config_reg,
--    probe1 => Integ1_request,
--    probe2 => Integ1_data_out,
--    probe3 => Integ2_request,
--    probe4 => Integ2_data_out,
--    probe5 => s_gbt_integrator,
--    probe6 => s_cntorbit,
--    probe7(0) => Integ2_EndOfRead,
--    probe8(0) => Integ2_EndOfRead,
--    probe9(0) => s_sda_debug(0),
--    probe10(0) => s_scl_debug(1),
--    probe11(0) => s_sda_debug(0),
--    probe12(0) => s_scl_debug(1),
--    probe13 => s_statea,
--    probe14 => s_stateb
--);



end Behavioral;

