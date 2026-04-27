----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.10.2022 21:27:29
-- Design Name: 
-- Module Name: db6_cis_interface_io - Behavioral
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

entity db6_cis_interface_io is
  Port ( 
        p_tph_out               : out t_mb_diff_pair;
        p_tpl_out               : out t_mb_diff_pair;
        p_tph_in               : in t_mb_std_logic;
        p_tpl_in               : in t_mb_std_logic
        
  );
end db6_cis_interface_io;

architecture Behavioral of db6_cis_interface_io is

begin


    i_tph_q0_OBUFDS : OBUFDS
    --generic map (IOSTANDARD => "DIFF_HSTL_I_18")
        port map (
        O => p_tph_out.q0.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB =>p_tph_out.q0.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => p_tph_in.q0 -- 1-bit input: Buffer input
        );

    i_tph_q1_OBUFDS : OBUFDS
    --generic map (IOSTANDARD => "DIFF_HSTL_I_18")
        port map (
        O => p_tph_out.q1.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB =>p_tph_out.q1.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => p_tph_in.q1 -- 1-bit input: Buffer input
        );


    i_tpl_q0_OBUFDS : OBUFDS
    --generic map (IOSTANDARD => "DIFF_HSTL_I_18")
        port map (
        O => p_tpl_out.q0.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB => p_tpl_out.q0.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => p_tpl_in.q0 -- 1-bit input: Buffer input
        );


    i_tpl_q1_OBUFDS : OBUFDS
    --generic map (IOSTANDARD => "DIFF_HSTL_I_18")
        port map (
        O => p_tpl_out.q1.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB => p_tpl_out.q1.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => p_tpl_in.q1 -- 1-bit input: Buffer input
        );


end Behavioral;
