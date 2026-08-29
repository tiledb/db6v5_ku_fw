----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.10.2022 14:31:16
-- Design Name: 
-- Module Name: db6_gbt_encoder_gearbox - Behavioral
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

library tilecal;
use tilecal.db6_design_package.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_gbt_encoder_gearbox is
  generic(
        g_ch_number : integer := 0;
        g_wordclkfreq : integer := 240
  );
  port (
        p_master_reset_in : std_logic;
		p_clknet_in : in t_db_clknet;
        p_db_reg_rx_in : in t_db_reg_rx;
        --p_gbt_tx_data_out       : out std_logic_vector(115 downto 0);
        p_gbt_encoder_interface_out         : out t_gbt_encoder_interface;
        p_gbt_encoder_interface_in         : in t_gbt_encoder_interface;
		p_sfp_ku_mgt_in                     : t_ku_mgt
		);
end db6_gbt_encoder_gearbox;

architecture Behavioral of db6_gbt_encoder_gearbox is

    signal s_data_buffer_lg, s_data_buffer_hg : std_logic_vector(115 downto 0);
    signal s_gbt_encoder_interface,s_gbt_encoder_interface_buffer : t_gbt_encoder_interface;
    
    signal s_cdc_reset_in, s_cdc_reset_out : std_logic;
    signal s_cdc_counter : integer range 0 to 3 := 0;
    signal s_data_phase,s_data_phase_sync : std_logic_vector(1 downto 0);

    constant c_pipeline_depth : integer := 2;

begin
    p_gbt_encoder_interface_out.gbt_tx_data_out.lg <= s_gbt_encoder_interface.gbt_tx_data_out.lg;--p_gbt_encoder_interface_in.gbt_tx_data_out.lg;
    p_gbt_encoder_interface_out.gbt_tx_data_out.hg <= s_gbt_encoder_interface.gbt_tx_data_out.lg;--p_gbt_encoder_interface_in.gbt_tx_data_out.hg;
    p_gbt_encoder_interface_out.gbt_tx_data_out.sync <= s_gbt_encoder_interface.gbt_tx_data_out.sync;
    p_gbt_encoder_interface_out.data_phase <= s_data_phase;
    p_gbt_encoder_interface_out.data_phase_sync <= s_data_phase_sync;
    
    p_gbt_encoder_interface_out.gbt_cdc_counter <= p_clknet_in.gbt_cdc_counter_array(g_ch_number);--s_cdc_counter;
    s_cdc_counter<=p_clknet_in.gbt_cdc_counter_array(g_ch_number);
    
    p_gbt_encoder_interface_out.gbt_bank_sync <=std_logic_vector(to_unsigned(s_cdc_counter,3));
    s_gbt_encoder_interface.gbt_tx_data_out.lg <= s_gbt_encoder_interface_buffer.gbt_tx_data_out.lg; --p_gbt_encoder_interface_in.gbt_tx_data_out.lg;
    s_gbt_encoder_interface.gbt_tx_data_out.hg <= s_gbt_encoder_interface_buffer.gbt_tx_data_out.hg; --p_gbt_encoder_interface_in.gbt_tx_data_out.hg;

    i_hg_pipeline : entity tilecal.db6_pipeline_propagator
    generic map(    g_pipeline_stages => 3,
                    g_pipeline_item_lenght => 116)
    Port map ( p_clk_in => p_clknet_in.gth_tx_wordclk(g_ch_number),
               p_pipeline_in => p_gbt_encoder_interface_in.gbt_tx_data_out.hg,
               p_pipeline_out => s_gbt_encoder_interface_buffer.gbt_tx_data_out.hg);

    i_lg_pipeline : entity tilecal.db6_pipeline_propagator
    generic map(    g_pipeline_stages => 3,
                    g_pipeline_item_lenght => 116)
    Port map ( p_clk_in => p_clknet_in.gth_tx_wordclk(g_ch_number),
               p_pipeline_in => p_gbt_encoder_interface_in.gbt_tx_data_out.lg,
               p_pipeline_out => s_gbt_encoder_interface_buffer.gbt_tx_data_out.lg);
    
       

    proc_db_data_sync : process(p_clknet_in.gth_tx_wordclk(g_ch_number))--(p_clknet_in.gth_tx_wordclk(g_ch_number), s_cdc_reset_out)--p_clknet_in.gth_tx_frameclk(g_ch_number))
    begin

        if rising_edge(p_clknet_in.gth_tx_wordclk(g_ch_number)) then --(p_clknet_in.gth_tx_wordclk(g_ch_number)) then--p_clknet_in.gth_tx_frameclk(g_ch_number)) then
            if p_clknet_in.gbt_cdc_counter_array(g_ch_number) = 0 then

                s_data_phase <= s_data_phase(0)&p_clknet_in.gbt_cdc_phase_array(g_ch_number);

                if p_clknet_in.gbt_cdc_phase_array(g_ch_number) = ((p_clknet_in.gbt_cdc_gearbox_phase(g_ch_number) or p_db_reg_rx_in(cfb_db_debug)(c_db_debug_gbt_cdc_phase_array+g_ch_number))) then -- '0' then
                    s_data_phase_sync<=s_data_phase_sync(0)&s_gbt_encoder_interface_buffer.gbt_tx_data_out.lg(89);
                    s_gbt_encoder_interface.gbt_tx_data_out.sync <= s_gbt_encoder_interface_buffer.gbt_tx_data_out.lg;
                else
                    s_data_phase_sync<=s_data_phase_sync(0)&p_gbt_encoder_interface_in.gbt_tx_data_out.hg(89);
                    s_gbt_encoder_interface.gbt_tx_data_out.sync <= s_gbt_encoder_interface_buffer.gbt_tx_data_out.hg;
                end if;
            end if;
        end if;            
    end process;
  


end Behavioral;
