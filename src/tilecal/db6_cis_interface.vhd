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
        p_tph_out               : out t_mb_diff_pair;
        p_tpl_out               : out t_mb_diff_pair;
        p_cis_interface_out         : out t_cis_interface
  );
  
  
end db6_cis_interface;

architecture Behavioral of db6_cis_interface is

    signal s_tph, s_tpl : t_mb_std_logic;
    signal s_cis_interface : t_cis_interface;

begin
p_cis_interface_out <= s_cis_interface;

    i_db6_cis_interface_io : entity tilecal.db6_cis_interface_hss_io
      Port map (
            p_clknet_in             => p_clknet_in,
            p_db_reg_rx_in          => p_db_reg_rx_in,
            p_master_reset_in       => p_master_reset_in,
            p_tph_out               => p_tph_out,
            p_tpl_out               => p_tpl_out,
            p_tph_in                => s_tph,
            p_tpl_in                => s_tpl
            );

    i_db6_cis_interface_driver : entity tilecal.db6_cis_driver_hss
        generic map (
            g_ila_cis_interface => g_ila_cis_interface      -- 0 =no ila, 1 = ila enabled
            )
      Port map ( 
            p_clknet_in             => p_clknet_in,
            p_master_reset_in       => p_master_reset_in,
            p_db_reg_rx_in          => p_db_reg_rx_in,
            p_tph_out               => s_tph,
            p_tpl_out               => s_tpl
      );



end Behavioral;

------------------------------------------------------------------------------------
---- Company: 
---- Engineer: Eduardo Valdes Santurio
----           Samuel Silverstein
----           Alberto Valero
---- Create Date: 10/03/2018 05:14:49 PM
---- Design Name: 
---- Module Name: db5_cis_interface - Behavioral
---- Project Name: 
---- Target Devices: 
---- Tool Versions: 
---- Description: 
---- 
---- Dependencies: 
---- 
---- Revision:
---- Revision 0.01 - File Created
---- Additional Comments:
---- 
------------------------------------------------------------------------------------


--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;

---- Uncomment the following library declaration if using
---- arithmetic functions with Signed or Unsigned values
----use IEEE.NUMERIC_STD.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
--library tilecal;
--use tilecal.db6_design_package.all;

--entity db6_cis_interface is
--    generic (
--        g_tmr_enabled      : natural := 0;       -- 0 = no no_tmr, 1 = tmr
--        g_ila_cis_interface : natural := 0;      -- 0 =no ila, 1 = ila enabled
--        g_cis_interface_mode : natural := 1
--        );
--  Port ( 
--        p_clknet_in                        : in t_db_clknet;
--        p_master_reset_in       : in std_logic;
--        p_db_reg_rx_in  : in t_db_reg_rx;
--        p_tph_out               : out t_mb_diff_pair;
--        p_tpl_out               : out t_mb_diff_pair;
--        p_cis_interface_out         : out t_cis_interface
--  );
  
  
--end db6_cis_interface;

--architecture Behavioral of db6_cis_interface is

--    signal s_tph, s_tpl : t_mb_std_logic;
--    signal s_tph_tmr, s_tpl_tmr : t_mb_std_logic_tmr;
--    signal s_cis_interface : t_cis_interface;

--begin
--p_cis_interface_out <= s_cis_interface;

--gen_mode_cdc : if g_cis_interface_mode=0 generate
--    i_db6_cis_interface_io : entity tilecal.db6_cis_interface_io
--      Port map ( 
--            p_tph_out               => p_tph_out,
--            p_tpl_out               => p_tpl_out,
--            p_tph_in                => s_tph,
--            p_tpl_in                => s_tpl
--            );
    
--    gen_tmr_disabled : if g_tmr_enabled = 0 generate
--        s_cis_interface.tmr_enabled <= '0';
        
--        i_db6_cis_interface_driver : entity tilecal.db6_cis_interface_driver
--            generic map (
--                g_ila_cis_interface => g_ila_cis_interface      -- 0 =no ila, 1 = ila enabled
--                )
--          Port map ( 
--                p_clknet_in             => p_clknet_in,
--                p_master_reset_in       => p_master_reset_in,
--                p_db_reg_rx_in          => p_db_reg_rx_in,
--                p_tph_out               => s_tph,
--                p_tpl_out               => s_tpl
--          );
     
--     end generate;
     
--     gen_tmr_enabled : if g_tmr_enabled = 1 generate
--        s_cis_interface.tmr_enabled <= '1';
--        gen_tmr : for v_tmr in 0 to 2 generate
    
--            i_db6_cis_interface_driver : entity tilecal.db6_cis_interface_driver
--            generic map (
--                g_ila_cis_interface => g_ila_cis_interface      -- 0 =no ila, 1 = ila enabled
--                )
--            Port map ( 
--                p_clknet_in             => p_clknet_in,
--                p_master_reset_in       => p_master_reset_in,
--                p_db_reg_rx_in          => p_db_reg_rx_in,
--                p_tph_out               => s_tph_tmr(v_tmr),
--                p_tpl_out               => s_tpl_tmr(v_tmr)
--            );
        
--        end generate;
        
--            i_entity_db6_tmr_voter_tph_q0 : entity tilecal.db6_tmr_voter_sync
--            generic map(
--                g_vector_width      => 1
--            )
--            Port map (     
--                    p_clk_in                          => p_clknet_in.tp_clk40.q0,
--                    p_std_logic_vector_0_in(0)        => (s_tph_tmr(0).q0),
--                    p_std_logic_vector_1_in(0)        => (s_tph_tmr(1).q0),
--                    p_std_logic_vector_2_in(0)        => (s_tph_tmr(2).q0),
--                    p_tmr_error_out                => s_cis_interface.tmr_error_tph.q0,
--                    p_std_logic_vector_out(0)         => s_tph.q0   
--                    );
        
--            i_entity_db6_tmr_voter_tph_q1 : entity tilecal.db6_tmr_voter_sync
--            generic map(
--                g_vector_width      => 1
--            )
--            Port map (     
--                    p_clk_in                          => p_clknet_in.tp_clk40.q1,
--                    p_std_logic_vector_0_in(0)        => (s_tph_tmr(0).q1),
--                    p_std_logic_vector_1_in(0)        => (s_tph_tmr(1).q1),
--                    p_std_logic_vector_2_in(0)        => (s_tph_tmr(2).q1),
--                    p_tmr_error_out                => s_cis_interface.tmr_error_tph.q1,
--                    p_std_logic_vector_out(0)         => s_tph.q1   
--                    );
    
--            i_entity_db6_tmr_voter_tpl_q0 : entity tilecal.db6_tmr_voter_sync
--            generic map(
--                g_vector_width      => 1
--            )
--            Port map (     
--                    p_clk_in                          => p_clknet_in.tp_clk40.q0,
--                    p_std_logic_vector_0_in(0)        => (s_tpl_tmr(0).q0),
--                    p_std_logic_vector_1_in(0)        => (s_tpl_tmr(1).q0),
--                    p_std_logic_vector_2_in(0)        => (s_tpl_tmr(2).q0),
--                    p_tmr_error_out                => s_cis_interface.tmr_error_tpl.q0,
--                    p_std_logic_vector_out(0)         => s_tpl.q0   
--                    );
    
--            i_entity_db6_tmr_voter_tpl_q1 : entity tilecal.db6_tmr_voter_sync
--            generic map(
--                g_vector_width      => 1
--            )
--            Port map (     
--                    p_clk_in                          => p_clknet_in.tp_clk40.q1,
--                    p_std_logic_vector_0_in(0)        => (s_tpl_tmr(0).q1),
--                    p_std_logic_vector_1_in(0)        => (s_tpl_tmr(1).q1),
--                    p_std_logic_vector_2_in(0)        => (s_tpl_tmr(2).q1),
--                    p_tmr_error_out                => s_cis_interface.tmr_error_tpl.q1,
--                    p_std_logic_vector_out(0)         => s_tpl.q1   
--                    );
    
    
--     end generate;
--end generate;

--gen_mode_oddr : if g_cis_interface_mode=1 generate
--    i_db6_cis_interface_io : entity tilecal.db6_cis_interface_oddr_io
--      Port map (
--            p_clknet_in             => p_clknet_in,
--            p_db_reg_rx_in          => p_db_reg_rx_in,
--            p_master_reset_in       => p_master_reset_in,  
--            p_tph_out               => p_tph_out,
--            p_tpl_out               => p_tpl_out,
--            p_tph_in                => s_tph,
--            p_tpl_in                => s_tpl
--            );

--    i_db6_cis_interface_driver : entity tilecal.db6_cis_driver_oddr
--        generic map (
--            g_ila_cis_interface => g_ila_cis_interface      -- 0 =no ila, 1 = ila enabled
--            )
--      Port map ( 
--            p_clknet_in             => p_clknet_in,
--            p_master_reset_in       => p_master_reset_in,
--            p_db_reg_rx_in          => p_db_reg_rx_in,
--            p_tph_out               => s_tph,
--            p_tpl_out               => s_tpl
--      );

--end generate;

--end Behavioral;
