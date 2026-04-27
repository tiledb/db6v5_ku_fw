----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.10.2022 21:35:53
-- Design Name: 
-- Module Name: db6_cis_interface_driver - Behavioral
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

entity db6_cis_driver_oddr is
    generic (
        g_ila_cis_interface : natural := 0      -- 0 =no ila, 1 = ila enabled
        );
  Port ( 
        p_clknet_in                        : in t_db_clknet;
        p_master_reset_in       : in std_logic;
        p_db_reg_rx_in  : in t_db_reg_rx;
        p_tph_out               : out t_mb_std_logic;
        p_tpl_out               : out t_mb_std_logic
  );
end db6_cis_driver_oddr;

architecture Behavioral of db6_cis_driver_oddr is

    COMPONENT ila_cis_interface3
    PORT (
        clk : IN STD_LOGIC;
    
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END COMPONENT  ;
    
    signal s_tph, s_tpl : t_mb_std_logic;
    signal s_tph_fixed_phase, s_tpl_fixed_phase : t_mb_std_logic;
    signal s_master_reset : std_logic;
    signal s_cis_register : std_logic_vector(31 downto 0);
    
begin

--    proc_mux_clks : process(p_db_reg_rx_in(cfb_mb_phase_config)(0))
--    begin
--        if p_db_reg_rx_in(cfb_mb_phase_config)(0) = '1' then
--            p_tph_out.q1 <= p_db_reg_rx_in(cfb_mb_phase_config)(31);
--            p_tph_out.q0 <= p_db_reg_rx_in(cfb_mb_phase_config)(30);
--            p_tpl_out.q1 <= p_db_reg_rx_in(cfb_mb_phase_config)(29);
--            p_tpl_out.q0 <= p_db_reg_rx_in(cfb_mb_phase_config)(28);
--        else
            p_tph_out <= s_tph_fixed_phase;
            p_tpl_out <= s_tpl_fixed_phase;        
--        end if;
--    end process;

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
    
--i_db6_cis_driver_q0 : entity tilecal.db6_cis_driver_cdc
--        Port map(
--        p_clk240_in                     => p_clknet_in.mmcm_refclk240,
--        p_cdc_counter_in                => p_clknet_in.gbt_cdc_counter,
--        p_cdc_phase_in                  => p_clknet_in.gbt_cdc_phase,
--        p_clk40_deskew_in               => p_clknet_in.tp_clk40.q0,
--        p_cis_config_reg_in             => p_db_reg_rx_in(cfb_cis_config),
--        p_master_reset_in               => s_master_reset,
--        p_bcr_count_in                  => p_clknet_in.bcr.count,
--        p_tph_out                       => s_tph.q0,
--        p_tpl_out                       => s_tpl.q0
--        );

--i_db6_cis_driver_q1 : entity tilecal.db6_cis_driver_cdc
--        Port map(
--        p_clk240_in                     => p_clknet_in.mmcm_refclk240,
--        p_cdc_counter_in                => p_clknet_in.gbt_cdc_counter,
--        p_cdc_phase_in                  => p_clknet_in.gbt_cdc_phase,
--        p_clk40_deskew_in               => p_clknet_in.tp_clk40.q1,
--        p_cis_config_reg_in             => p_db_reg_rx_in(cfb_cis_config),
--        p_master_reset_in               => s_master_reset,
--        p_bcr_count_in                  => p_clknet_in.bcr.count,
--        p_tph_out                       => s_tph.q1,
--        p_tpl_out                       => s_tpl.q1
--        );

i_db6_cis_driver_q0_fixed_phase : entity tilecal.db6_cis_driver_cdc_oddr
        Port map(
        p_bitclk_in                     => p_clknet_in.mmcm_refclk320,
        p_cis_cdc_counter_in                => p_clknet_in.cis_cdc_counter,
        p_cis_cdc_phase_in                  => p_clknet_in.cis_cdc_phase,
--        p_clk40_deskew_in               => p_clknet_in.refclk40,
        p_cis_config_reg_in             => s_cis_register, --p_db_reg_rx_in(cfb_cis_config),
        p_master_reset_in               => s_master_reset,
        p_bcr_count_in                  => p_clknet_in.bcr.count,
        p_tph_out                       => s_tph_fixed_phase.q0,
        p_tpl_out                       => s_tpl_fixed_phase.q0
        );

i_db6_cis_driver_q1_fixed_phase : entity tilecal.db6_cis_driver_cdc_oddr
        Port map(
        p_bitclk_in                     => p_clknet_in.mmcm_refclk320,
        p_cis_cdc_counter_in                => p_clknet_in.cis_cdc_counter,
        p_cis_cdc_phase_in                  => p_clknet_in.cis_cdc_phase,
--        p_clk40_deskew_in               => p_clknet_in.refclk40,
        p_cis_config_reg_in             => s_cis_register, --p_db_reg_rx_in(cfb_cis_config),
        p_master_reset_in               => s_master_reset,
        p_bcr_count_in                  => p_clknet_in.bcr.count,
        p_tph_out                       => s_tph_fixed_phase.q1,
        p_tpl_out                       => s_tpl_fixed_phase.q1
        );


end Behavioral;


