----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Eduardo Valdes Santurio
--           Samuel Silverstein
--           Alberto Valero
-- Create Date: 10/03/2018 05:14:49 PM
-- Design Name: 
-- Module Name: db5_cis_interface - Behavioral
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
library UNISIM;
use UNISIM.VComponents.all;
library tilecal;
use tilecal.db6_design_package.all;

entity db6_cis_interface is
    generic (
        g_tmr_enabled      : natural := 0;       -- 0 = no no_tmr, 1 = tmr
        g_ila_cis_interface : natural := 0;      -- 0 =no ila, 1 = ila enabled
        g_cis_interface_mode : natural := 1
        );
  Port ( 
        p_clknet_in                        : in t_db_clknet;
        p_master_reset_in       : in std_logic;
        p_db_reg_rx_in  : in t_db_reg_rx;
        p_tph_out               : out t_mb_std_logic; -- plain logic; hss_cis IP now in db6_cis_interface_hss_io.vhd, instantiated from db7_io_box
        p_tpl_out               : out t_mb_std_logic; -- plain logic
        p_cis_interface_out         : out t_cis_interface
  );


end db6_cis_interface;

architecture Behavioral of db6_cis_interface is

    signal s_cis_interface : t_cis_interface;

begin
p_cis_interface_out <= s_cis_interface;

    i_db6_cis_interface_driver : entity tilecal.db6_cis_driver_hss
        generic map (
            g_ila_cis_interface => g_ila_cis_interface      -- 0 =no ila, 1 = ila enabled
            )
      Port map (
            p_clknet_in             => p_clknet_in,
            p_master_reset_in       => p_master_reset_in,
            p_db_reg_rx_in          => p_db_reg_rx_in,
            p_tph_out               => p_tph_out,
            p_tpl_out               => p_tpl_out
      );



end Behavioral;
