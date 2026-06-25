library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity db6_altera_jtag_driver is
    generic (
        g_clk_div : positive := 25
    );
    port (
        ----------------------------------------------------------------
        -- System clock
        ----------------------------------------------------------------
        p_clk_in        : in  std_logic; -- 100 MHz

        ----------------------------------------------------------------
        -- Start pulse
        ----------------------------------------------------------------
        p_start_in      : in  std_logic;

        ----------------------------------------------------------------
        -- JTAG
        ----------------------------------------------------------------
        p_jtag_tck_out  : out std_logic;
        p_jtag_tms_out  : out std_logic;
        p_jtag_tdi_out  : out std_logic;
        p_jtag_tdo_in   : in  std_logic;

        ----------------------------------------------------------------
        -- Result
        ----------------------------------------------------------------
        p_id_out        : out std_logic_vector(31 downto 0);
        p_done_out      : out std_logic
    );
end entity;

architecture rtl of db6_altera_jtag_driver is

    --------------------------------------------------------------------
    -- JTAG TAP controller states
    --------------------------------------------------------------------
    type t_state is (
        ST_IDLE,

        -- Reset sequence
        ST_RESET_0,
        ST_RESET_1,
        ST_RESET_2,
        ST_RESET_3,
        ST_RESET_4,
        ST_RESET_5,

        -- Move to Shift-DR
        ST_GOTO_DRSELECT,
        ST_GOTO_DRCAPTURE,
        ST_GOTO_DRSHIFT,

        -- Shift IDCODE
        ST_SHIFT,

        -- Exit DR
        ST_EXIT1,
        ST_UPDATE,
        ST_DONE
    );

    signal s_state          : t_state := ST_IDLE;

    --------------------------------------------------------------------
    -- JTAG outputs
    --------------------------------------------------------------------
    signal s_tck            : std_logic := '0';
    signal s_tms            : std_logic := '1';
    signal s_tdi            : std_logic := '0';

    --------------------------------------------------------------------
    -- Clock divider
    -- 100 MHz / 50 = 2 MHz JTAG clock
    --------------------------------------------------------------------
    signal s_div_cnt : integer range 0 to g_clk_div-1 := 0;
    
    signal s_tick           : std_logic := '0';

    --------------------------------------------------------------------
    -- Shift register
    --------------------------------------------------------------------
    signal s_shift_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_bit_cnt        : integer range 0 to 31 := 0;

    signal s_done           : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------
    p_jtag_tck_out <= s_tck;
    p_jtag_tms_out <= s_tms;
    p_jtag_tdi_out <= s_tdi;

    p_id_out       <= s_shift_reg;
    p_done_out     <= s_done;

    --------------------------------------------------------------------
    -- Clock divider
    --------------------------------------------------------------------
    process(p_clk_in)
    begin
        if rising_edge(p_clk_in) then

            s_tick <= '0';

            if s_div_cnt = g_clk_div - 1 then
                s_div_cnt <= 0;
                s_tick    <= '1';
            else
                s_div_cnt <= s_div_cnt + 1;
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- Main JTAG FSM
    --------------------------------------------------------------------
    process(p_clk_in)
    begin
        if rising_edge(p_clk_in) then

            if s_tick = '1' then

                ----------------------------------------------------------------
                -- Generate TCK
                ----------------------------------------------------------------
                s_tck <= not s_tck;

                ----------------------------------------------------------------
                -- Execute FSM on TCK low->high transition
                ----------------------------------------------------------------
                if s_tck = '0' then

                    case s_state is

                        ----------------------------------------------------------------
                        -- Idle
                        ----------------------------------------------------------------
                        when ST_IDLE =>

                            s_done <= '0';
                            s_tms  <= '1';
                            s_tdi  <= '0';

                            if p_start_in = '1' then
                                s_state <= ST_RESET_0;
                            end if;

                        ----------------------------------------------------------------
                        -- Force TAP reset
                        -- TMS held high for 5+ clocks
                        ----------------------------------------------------------------
                        when ST_RESET_0 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_1;

                        when ST_RESET_1 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_2;

                        when ST_RESET_2 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_3;

                        when ST_RESET_3 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_4;

                        when ST_RESET_4 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_5;

                        when ST_RESET_5 =>
                            s_tms   <= '0';
                            s_state <= ST_GOTO_DRSELECT;

                        ----------------------------------------------------------------
                        -- Go to Shift-DR
                        ----------------------------------------------------------------
                        when ST_GOTO_DRSELECT =>
                            -- Select-DR-Scan
                            s_tms   <= '1';
                            s_state <= ST_GOTO_DRCAPTURE;

                        when ST_GOTO_DRCAPTURE =>
                            -- Capture-DR
                            s_tms   <= '0';
                            s_state <= ST_GOTO_DRSHIFT;

                        when ST_GOTO_DRSHIFT =>
                            -- Shift-DR
                            s_tms      <= '0';
                            s_bit_cnt  <= 0;
                            s_shift_reg <= (others => '0');
                            s_state    <= ST_SHIFT;

                        ----------------------------------------------------------------
                        -- Shift 32-bit IDCODE
                        ----------------------------------------------------------------
                        when ST_SHIFT =>

                            -- IDCODE instruction is default after reset
                            -- Shift zeros into TDI
                            s_tdi <= '0';

                            -- Shift in TDO LSB first
                            s_shift_reg <= p_jtag_tdo_in &
                                           s_shift_reg(31 downto 1);

                            if s_bit_cnt = 31 then
                                s_tms   <= '1'; -- Exit Shift-DR
                                s_state <= ST_EXIT1;
                            else
                                s_tms      <= '0';
                                s_bit_cnt  <= s_bit_cnt + 1;
                            end if;

                        ----------------------------------------------------------------
                        -- Exit1-DR
                        ----------------------------------------------------------------
                        when ST_EXIT1 =>
                            s_tms   <= '1';
                            s_state <= ST_UPDATE;

                        ----------------------------------------------------------------
                        -- Update-DR -> Run-Test/Idle
                        ----------------------------------------------------------------
                        when ST_UPDATE =>
                            s_tms   <= '0';
                            s_done  <= '1';
                            s_state <= ST_DONE;

                        ----------------------------------------------------------------
                        -- Done
                        ----------------------------------------------------------------
                        when ST_DONE =>

                            s_tms <= '0';
                            s_tdi <= '0';

                            if p_start_in = '0' then
                                s_done  <= '0';
                                s_state <= ST_IDLE;
                            end if;

                        when others =>
                            s_state <= ST_IDLE;

                    end case;

                end if;

            end if;

        end if;
    end process;

end architecture;