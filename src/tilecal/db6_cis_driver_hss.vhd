----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/02/2024 04:08:08 PM
-- Design Name: 
-- Module Name: db6_cis_driver_hss - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_cis_driver_hss is
    generic (
        g_ila_cis_interface : natural := 0      -- 0 =no ila, 1 = ila enabled
        );
  Port ( 
        p_clknet_in                        : in t_db_clknet;
--        p_cis_wordclk_in                   : in std_logic;
        p_master_reset_in       : in std_logic;
        p_db_reg_rx_in  : in t_db_reg_rx;
        p_tph_out               : out t_mb_std_logic;
        p_tpl_out               : out t_mb_std_logic
  );
end db6_cis_driver_hss;

architecture Behavioral of db6_cis_driver_hss is

    signal s_tph, s_tpl : t_mb_std_logic;
    signal s_master_reset : std_logic;
    signal s_cis_register : std_logic_vector(31 downto 0);

begin

    proc_mux_ctrl_from_vio : process(p_clknet_in.cis_enable)
    begin
        if p_clknet_in.cis_enable = '1' then
            s_cis_register(25 downto 14)<=p_clknet_in.cis_bcid_discharge;
            s_cis_register(13 downto 2)<=p_clknet_in.cis_bcid_charge;
            s_cis_register(1) <= p_clknet_in.cis_gain;
            s_cis_register(0)  <= '1';
        else
            s_cis_register <= p_db_reg_rx_in(cfb_cis_config);
        end if;
    end process;
    
    
    s_master_reset <= p_master_reset_in or p_db_reg_rx_in(cfb_strobe_reg)(c_cis_reset_bit);

i_db6_cis_driver_q0 : entity tilecal.db6_cis_driver_hss_quad
        Port map(
        p_clk40_in                     => p_clknet_in.cfgbus_clk40,
        p_cis_config_reg_in             => s_cis_register, --p_db_reg_rx_in(cfb_cis_config),
        p_master_reset_in               => s_master_reset,
        p_bcr_count_in                  => p_clknet_in.bcr.count,
        p_tph_out                       => p_tph_out.q0,
        p_tpl_out                       => p_tpl_out.q0
        );

i_db6_cis_driver_q1 : entity tilecal.db6_cis_driver_hss_quad
        Port map(
        p_clk40_in                     => p_clknet_in.cfgbus_clk40,
        p_cis_config_reg_in             => s_cis_register, --p_db_reg_rx_in(cfb_cis_config),
        p_master_reset_in               => s_master_reset,
        p_bcr_count_in                  => p_clknet_in.bcr.count,
        p_tph_out                       => p_tph_out.q1,
        p_tpl_out                       => p_tpl_out.q1
        );

end Behavioral;
