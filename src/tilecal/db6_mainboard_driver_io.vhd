----------------------------------------------------------------------------------
-- Module Name: db6_mainboard_driver_io - Behavioral
-- Additional Comments: IO-primitive isolation layer for db6_mainboard_driver.
--                       Extracted from db6_mainboard_driver.vhd so the mainboard
--                       driver logic itself is free of IOB primitives (needed so
--                       it can later be triplicated for TMR). Instantiated from
--                       db7_io_box.vhd. See ~/.claude/plans/peppy-yawning-platypus.md.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_mainboard_driver_io is
    port (
        p_ssel_out         : out t_mb_diff_pair;
        p_sclk_out         : out t_mb_diff_pair;
        p_sdata_out        : out t_mb_diff_pair;
        p_sdata_in         : in  t_mb_diff_pair;

        p_ssel_in          : in  t_mb_std_logic;
        p_sclk_in          : in  t_mb_std_logic;
        p_sdata_tx_in      : in  t_mb_std_logic; -- data to transmit, drives OBUFDS
        p_sdata_rx_out     : out t_mb_std_logic  -- received data, from IBUFDS
    );
end db6_mainboard_driver_io;

architecture Behavioral of db6_mainboard_driver_io is
begin

i_mb_q0_sdata_out_OBUFDS : OBUFDS
    port map (
    O => p_sdata_out.q0.p,
    OB => p_sdata_out.q0.n,
    I => p_sdata_tx_in.q0
    );

i_mb_q1_sdata_out_OBUFDS : OBUFDS
    port map (
    O => p_sdata_out.q1.p,
    OB => p_sdata_out.q1.n,
    I => p_sdata_tx_in.q1
    );

i_mb_q0_sdata_in_IBUFDS : IBUFDS
    port map (
    I => p_sdata_in.q0.p,
    IB => p_sdata_in.q0.n,
    O => p_sdata_rx_out.q0
    );

i_mb_q1_sdata_in_IBUFDS : IBUFDS
    port map (
    I => p_sdata_in.q1.p,
    IB => p_sdata_in.q1.n,
    O => p_sdata_rx_out.q1
    );

i_mb_q0_sclk_OBUFDS : OBUFDS
    port map (
    O => p_sclk_out.q0.p,
    OB => p_sclk_out.q0.n,
    I => p_sclk_in.q0
    );

i_mb_q1_sclk_OBUFDS : OBUFDS
    port map (
    O => p_sclk_out.q1.p,
    OB => p_sclk_out.q1.n,
    I => p_sclk_in.q1
    );

i_mb_q0_psel_OBUFDS : OBUFDS
    port map (
    O => p_ssel_out.q0.p,
    OB => p_ssel_out.q0.n,
    I => p_ssel_in.q0
    );

i_mb_q1_psel_OBUFDS : OBUFDS
    port map (
    O => p_ssel_out.q1.p,
    OB => p_ssel_out.q1.n,
    I => p_ssel_in.q1
    );

end Behavioral;
