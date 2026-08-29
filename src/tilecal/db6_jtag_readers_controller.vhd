library ieee;
use ieee.std_logic_1164.all;

library tilecal;
use tilecal.db6_design_package.all;

-- Wraps the two mainboard-side db6_altera_jtag_driver instances (q0/q1).
-- p_enable_in is a level: while high, the wrapped driver's own FSM runs a
-- full IDCODE scan and holds in its done state; p_id_out is registered from
-- p_jtag drivers' id_out each time their done_out is seen high, so it keeps
-- the last successfully read ID even after p_enable_in drops and the scan
-- output goes back to idle.
entity db6_jtag_readers_controller is
    generic (
        g_clk_div : positive := 25
    );
    port (
        p_clk_in       : in  std_logic; -- 100 MHz

        p_enable_in    : in  t_mb_std_logic;

        p_jtag_tck_out : out t_mb_std_logic;
        p_jtag_tms_out : out t_mb_std_logic;
        p_jtag_tdi_out : out t_mb_std_logic;
        p_jtag_tdo_in  : in  t_mb_std_logic;

        p_id_out       : out t_mb_std_logic_vector_32;
        p_done_out     : out t_mb_std_logic
    );
end entity;

architecture rtl of db6_jtag_readers_controller is

    signal s_id_raw   : t_mb_std_logic_vector_32;
    signal s_done_raw : t_mb_std_logic;
    signal s_id_reg   : t_mb_std_logic_vector_32 := (q0 => (others => '0'), q1 => (others => '0'));

begin

    i_db6_altera_jtag_driver_q0 : entity tilecal.db6_altera_jtag_driver
        generic map (
            g_clk_div => g_clk_div
        )
        port map (
            p_clk_in       => p_clk_in,
            p_start_in     => p_enable_in.q0,
            p_jtag_tck_out => p_jtag_tck_out.q0,
            p_jtag_tms_out => p_jtag_tms_out.q0,
            p_jtag_tdi_out => p_jtag_tdi_out.q0,
            p_jtag_tdo_in  => p_jtag_tdo_in.q0,
            p_id_out       => s_id_raw.q0,
            p_done_out     => s_done_raw.q0
        );

    i_db6_altera_jtag_driver_q1 : entity tilecal.db6_altera_jtag_driver
        generic map (
            g_clk_div => g_clk_div
        )
        port map (
            p_clk_in       => p_clk_in,
            p_start_in     => p_enable_in.q1,
            p_jtag_tck_out => p_jtag_tck_out.q1,
            p_jtag_tms_out => p_jtag_tms_out.q1,
            p_jtag_tdi_out => p_jtag_tdi_out.q1,
            p_jtag_tdo_in  => p_jtag_tdo_in.q1,
            p_id_out       => s_id_raw.q1,
            p_done_out     => s_done_raw.q1
        );

    process(p_clk_in)
    begin
        if rising_edge(p_clk_in) then
            if s_done_raw.q0 = '1' then
                s_id_reg.q0 <= s_id_raw.q0;
            end if;
            if s_done_raw.q1 = '1' then
                s_id_reg.q1 <= s_id_raw.q1;
            end if;
        end if;
    end process;

    p_id_out   <= s_id_reg;
    p_done_out <= s_done_raw;

end architecture;
