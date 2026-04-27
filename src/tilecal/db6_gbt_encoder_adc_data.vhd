----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.01.2023 18:56:09
-- Design Name: 
-- Module Name: db6_gbt_encoder_adc_data - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_gbt_encoder_adc_data is
  port (
        p_master_reset_in : std_logic;
		p_clknet_in : in t_db_clknet;
        p_db_reg_rx_in : in t_db_reg_rx;

		--interfaces
		p_mb_interface_in : in t_mb_interface;

        --outputs
        p_adc_data_lg_out : out std_logic_vector(71 downto 0);
		p_adc_data_hg_out : out std_logic_vector(71 downto 0);
		p_adc_data_fc_out : out std_logic_vector(71 downto 0)
        
		);

end db6_gbt_encoder_adc_data;

architecture Behavioral of db6_gbt_encoder_adc_data is

    constant c_pipeline_depth : integer := c_global_pipeline_depth;
    type t_adc_data_pipeline is array (0 to c_pipeline_depth-1) of std_logic_vector(71 downto 0);
    signal s_adc_data_lg_pipeline, s_adc_data_hg_pipeline, s_adc_data_fc_pipeline : t_adc_data_pipeline;
    
    signal s_adc_data_lg 	: std_logic_vector(71 downto 0) := (others => '0');
    signal s_adc_data_hg 	: std_logic_vector(71 downto 0) := (others => '0');
    signal s_adc_data_fc 	: std_logic_vector(71 downto 0) := (others => '0');  
    
begin

--p_adc_data_lg_out <= s_adc_data_lg_pipeline(c_pipeline_depth-1); --s_adc_data_lg;
--p_adc_data_hg_out <= s_adc_data_hg_pipeline(c_pipeline_depth-1); --s_adc_data_hg;
--p_adc_data_fc_out <= s_adc_data_fc_pipeline(c_pipeline_depth-1); --s_adc_data_fc;

p_adc_data_lg_out <= s_adc_data_lg;
p_adc_data_hg_out <= s_adc_data_hg;
p_adc_data_fc_out <= s_adc_data_fc;



-- reformat low- and high-gain data
gen_adc_reformat : for adc in 0 to 5 generate


    proc_register_adc_data : process(p_clknet_in.cfgbus_clk40)--process(p_clknet_in.refclk40)
    begin
        if p_master_reset_in = '1' then
        elsif rising_edge(p_clknet_in.cfgbus_clk40) then--(p_clknet_in.refclk40) then
            s_adc_data_hg(adc*12+11 downto adc*12)  <=  p_mb_interface_in.adc_readout.hg_data(adc)(13 downto 2);
            s_adc_data_lg(adc*12+11 downto adc*12)  <=  p_mb_interface_in.adc_readout.lg_data(adc)(13 downto 2);
            s_adc_data_fc(adc*12+11 downto adc*12)  <=  p_mb_interface_in.adc_readout.fc_data(adc)(13 downto 2);
        end if;
    end process;
end generate; -- gen_adc_reformat





end Behavioral;
