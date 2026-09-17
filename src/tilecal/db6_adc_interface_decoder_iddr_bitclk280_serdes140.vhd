----------------------------------------------------------------------------------
-- db6_adc_interface_decoder_iddr_bitclk280_serdes140
--
-- 2026-09-13: decoder for g_adc_clocking_scheme=iddr280_serdes140 -- consumes
-- db6_adc_interface_io_iddr_bitclk280_serdes140.vhd's native-ISERDESE3, 4-bit-wide,
-- 140MHz-CLKDIV-registered output (see that file's header for why this exists: the
-- same timing fix hss_wizard uses, without pulling in the wizard IP).
--
-- The word-assembly FSM (proc_align_data) and toggle-based CDC into cfgbus_clk40
-- (proc_cdc_capture) below are copied essentially verbatim from
-- db6_adc_interface_decoder_iserdese.vhd (the hss_wizard scheme's decoder), which
-- already solves the identical problem -- reconstructing 14-bit fc/hg/lg words and
-- locating the "11111110000000" fc marker from a 4-bit-wide-per-cycle stream, then
-- crossing into cfgbus_clk40 with a single-bit toggle/2-flop synchronizer instead of
-- a wider, tear-prone multi-bit crossing. See that file's own extensive comment on the
-- proc_align_data bit-order literals (7/C/1, not their bit-reversal) before touching
-- them -- verified against the working iddr280 decoder's own extraction convention,
-- not just assumed.
--
-- Differs from db6_adc_interface_decoder_iserdese.vhd in exactly the ways this scheme's
-- IO layer differs from hss_wizard's: this scheme uses IDELAYE3 var_load tap
-- calibration (db6_adc_idelay_calibration.vhd), like iddr280/iddr280_clkdiv, not
-- hss_wizard's fixed-delay/no-idelay approach -- so this decoder takes
-- p_calibration_tap_in/done_in/failed_in (mirroring
-- db6_adc_interface_decoder_iddr_bitclk280.vhd) instead of a p_ctrl_reset_from_sm_in/
-- p_frame_missalignment_out closed loop with the IO layer (this scheme's IO layer has
-- no internal reset state machine to close that loop with -- BUFGCE_DIV's CLR is
-- synchronized locally, see that file).
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library tilecal;
use tilecal.db6_design_package.all;

library UNISIM;
use UNISIM.VComponents.all;

entity db6_adc_interface_decoder_iddr_bitclk280_serdes140 is
generic (
        g_tmr_enabled : std_logic := '1'
    );
  Port (
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;

        --inputs
        p_adc_bitclk_in    : in std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_in : in std_logic_vector(5 downto 0); -- 140MHz, this scheme's fabric-facing clock
        p_adc_frameclk_in  : in t_byteslice_sr;
        p_adc_lg_data_in   : in t_byteslice_sr;
        p_adc_hg_data_in   : in t_byteslice_sr;
        -- per-channel pll_adc_channel lock, generated in
        -- db6_adc_interface_io_iddr_bitclk280_serdes140.vhd (not here -- a PLL can't be
        -- triplicated)
        p_adc_pll0_locked_in : in std_logic_vector(5 downto 0) := (others => '0');
        -- db6_adc_idelay_calibration's result -- see
        -- db6_adc_interface_decoder_iddr_bitclk280.vhd's identical ports
        p_calibration_tap_in    : in t_idelay_count := (others => (others => '0'));
        p_calibration_done_in   : in std_logic_vector(5 downto 0) := (others => '0');
        p_calibration_failed_in : in std_logic_vector(5 downto 0) := (others => '0');

        --control
        p_adc_readout_control_in : in t_adc_readout_control;

        --output
        p_adc_readout_out       : out t_adc_readout;

        --debug
        p_leds_out      : out std_logic_vector(3 downto 0)

  );
end db6_adc_interface_decoder_iddr_bitclk280_serdes140;

architecture Behavioral of db6_adc_interface_decoder_iddr_bitclk280_serdes140 is

    signal s_frame_missalignment : std_logic_vector (5 downto 0) := (others => '0');

    signal s_adc_channel_fifo_fc, s_adc_channel_fifo_hg, s_adc_channel_fifo_lg : t_adc_channel_fifo;

    -- fast-domain (p_adc_bitclkdiv_in, 140MHz) FSM-verified commit values, pre-CDC --
    -- see proc_align_data below
    signal s_fc_data_fast, s_hg_data_fast, s_lg_data_fast : t_adc_data := (others => (others => '0'));
    -- toggles once per committed word -- see db6_adc_interface_decoder_iserdese.vhd's
    -- header for the full CDC design reasoning (toggle/valid-handshake synchronizer)
    signal s_data_toggle : std_logic_vector(5 downto 0) := (others => '0');
    signal s_toggle_sync0, s_toggle_sync1, s_toggle_sync1_prev : std_logic_vector(5 downto 0) := (others => '0');
    signal s_frame_missalignment_sync0, s_frame_missalignment_sync1 : std_logic_vector(5 downto 0) := (others => '1');

    signal s_adc_readout : t_adc_readout :=
        (
            lg_bitslip => (others => "0111"),
            hg_bitslip => (others => "0111"),
            lg_idelay_count => (others =>"000000000"),
            hg_idelay_count => (others =>"000000000"),
            fc_idelay_count => (others =>"000000000"),
            lg_data =>(others=>"00000000000000"),
            hg_data =>(others=>"00000000000000"),
            fc_data =>(others=>"00000000000000"),

            channel_cdc_align_counter => (others=> (others=>'0')),
            channel_phase_offset => (others=>'0'),
            channel_missed_bit_count=>(others=>'0'),
            channel_frame_missalignemt => (others=>'0'),
            channel_locked => (others=>'0'),
            channel_missed_locked => (others=>'0'),
            channel_clk280_locked => (others=>'0'),
            channel_idelay_calibration_done => (others=>'0'),
            channel_idelay_calibration_failed => (others=>'0'),
            channel_clk280_stopped => (others=>'0'),
            channel_valid_fc_frame_counter => (others =>(others=>'0')),
            channel_invalid_fc_frame_counter => (others =>(others=>'0')),
            channel_valid_divclk_frame_counter => (others =>(others=>'0')),
            channel_invalid_lg_frame_counter => (others =>(others=>'0')),
            channel_invalid_hg_frame_counter => (others =>(others=>'0')),

            channel_enable_test_pattern => (others=> '0'),
            channel_lg_data_test_pattern => (others => (others=> '0')),
            channel_hg_data_test_pattern => (others => (others=> '0')),
            channel_pedestal_test_underflow_lg_counter => (others => (others=> '0')),
            channel_pedestal_test_overflow_lg_counter => (others => (others=> '0')),
            channel_pedestal_test_underflow_hg_counter => (others => (others=> '0')),
            channel_pedestal_test_overflow_hg_counter => (others => (others=> '0')),

            channel_pedestal_test_overflow => (others=> '0'),
            channel_pedestal_test_underflow => (others=> '0'),

            -- 2026-09-14: db6_data_readout_inject_debug status fields (see
            -- db6_design_package.vhd / db6v5_top.vhd's s_mb_interface_gbt_tx splice) --
            -- not driven here, only by that splice; initialized off like every other
            -- status field in this aggregate.
            data_readout_inject_active => '0',
            data_readout_inject_ram_rdata => (others => '0'),
            data_readout_inject_word_active => (others => '0'),

            readout_initialized => '0',

            mb_adc_config_control => c_adc_register_init_config_14_bit,

            channel_fifo_block_ram_fc => s_adc_channel_fifo_fc,
            channel_fifo_block_ram_lg => s_adc_channel_fifo_lg,
            channel_fifo_block_ram_hg => s_adc_channel_fifo_hg,

            channel_leds => (others => "0000"),

            tmr_enabled => g_tmr_enabled,
            tmr_error_lg => (others => '0'),
            tmr_error_hg => (others => '0'),
            tmr_error_fc => (others => '0'),
            tmr_error => (others => '0')
        );

begin

p_adc_readout_out <= s_adc_readout;

gen_adc_channels: for v_adc in 0 to 5 generate

    -- status signals -- see db6_adc_interface_decoder_iddr_bitclk280.vhd's identical
    -- channel_clk280_locked convention, and db6_adc_idelay_calibration.vhd for the
    -- calibration_tap/done/failed fields.
    s_adc_readout.channel_clk280_locked(v_adc) <= p_adc_pll0_locked_in(v_adc);
    s_adc_readout.fc_idelay_count(v_adc) <= p_calibration_tap_in(v_adc);
    s_adc_readout.lg_idelay_count(v_adc) <= p_calibration_tap_in(v_adc);
    s_adc_readout.hg_idelay_count(v_adc) <= p_calibration_tap_in(v_adc);
    s_adc_readout.channel_idelay_calibration_done(v_adc)   <= p_calibration_done_in(v_adc);
    s_adc_readout.channel_idelay_calibration_failed(v_adc) <= p_calibration_failed_in(v_adc);

    -- word-assembly FSM: 7 states, each consuming one new 4-bit chunk of fc/hg/lg per
    -- p_adc_bitclkdiv_in (140MHz) cycle, checking the known fc marker
    -- ("11111110000000") nibble-by-nibble to both locate word boundaries and validate
    -- lock -- copied from db6_adc_interface_decoder_iserdese.vhd's proc_align_data
    -- (see that file's header comment for the bit-order literal derivation: 7/C/1, not
    -- their bit-reversal -- cross-checked against the proven iddr280 decoder's own
    -- extraction convention).
    -- 2026-09-13: p_clknet_in.adc_config.force_adc_readout_reset added alongside
    -- p_master_reset_in -- see t_debug_control_adc_config's header comment
    -- (db6_design_package.vhd).
    proc_align_data : process (p_adc_bitclkdiv_in(v_adc), p_master_reset_in, p_clknet_in.adc_config.force_adc_readout_reset)
    variable v_state  : integer range 0 to 6;
    variable v_lg_data  : std_logic_vector(11 downto 0):=(others=>'0');
    variable v_hg_data  : std_logic_vector(11 downto 0):=(others=>'0');
    variable v_fc_data  : std_logic_vector(11 downto 0):=(others=>'0');
    begin
        if p_master_reset_in = '1' or p_clknet_in.adc_config.force_adc_readout_reset = '1' then
            s_frame_missalignment(v_adc) <= '1';
            v_state := 0;
        elsif rising_edge(p_adc_bitclkdiv_in(v_adc)) then
            case v_state is
                when 0 =>
                    if p_adc_frameclk_in(v_adc)(3 downto 0) = x"F" then
                        v_hg_data(11 downto 8)     := (p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1) & p_adc_hg_data_in(v_adc)(2) & p_adc_hg_data_in(v_adc)(3));
                        v_lg_data(11 downto 8)     := (p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1) & p_adc_lg_data_in(v_adc)(2) & p_adc_lg_data_in(v_adc)(3));
                        v_fc_data(11 downto 8)     := (p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1) & p_adc_frameclk_in(v_adc)(2) & p_adc_frameclk_in(v_adc)(3));
                        v_state := 1;
                    else
                        s_frame_missalignment(v_adc) <= '1';
                        v_state := 0;
                    end if;
                when 1 =>
                    if p_adc_frameclk_in(v_adc)(3 downto 0) = x"7" then
                        v_hg_data(7 downto 4)     := (p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1) & p_adc_hg_data_in(v_adc)(2) & p_adc_hg_data_in(v_adc)(3));
                        v_lg_data(7 downto 4)     := (p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1) & p_adc_lg_data_in(v_adc)(2) & p_adc_lg_data_in(v_adc)(3));
                        v_fc_data(7 downto 4)     := (p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1) & p_adc_frameclk_in(v_adc)(2) & p_adc_frameclk_in(v_adc)(3));
                        v_state := 2;
                    else
                        s_frame_missalignment(v_adc) <= '1';
                        v_state := 0;
                    end if;
                when 2 =>
                    if p_adc_frameclk_in(v_adc)(3 downto 0) = x"0" then
                        v_hg_data(3 downto 0)     := (p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1) & p_adc_hg_data_in(v_adc)(2) & p_adc_hg_data_in(v_adc)(3));
                        v_lg_data(3 downto 0)     := (p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1) & p_adc_lg_data_in(v_adc)(2) & p_adc_lg_data_in(v_adc)(3));
                        v_fc_data(3 downto 0)     := (p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1) & p_adc_frameclk_in(v_adc)(2) & p_adc_frameclk_in(v_adc)(3));
                        s_hg_data_fast(v_adc)(13 downto 2)<= v_hg_data;
                        s_lg_data_fast(v_adc)(13 downto 2)<= v_lg_data;
                        s_fc_data_fast(v_adc)(13 downto 2)<= v_fc_data;
                        s_data_toggle(v_adc) <= not s_data_toggle(v_adc);
                        v_state := 3;
                    else
                        s_frame_missalignment(v_adc) <= '1';
                        v_state := 0;
                    end if;
                when 3 =>
                    if p_adc_frameclk_in(v_adc)(3 downto 0) = x"C" then
                        v_hg_data(11 downto 10)     := (p_adc_hg_data_in(v_adc)(2) & p_adc_hg_data_in(v_adc)(3));
                        v_lg_data(11 downto 10)     := (p_adc_lg_data_in(v_adc)(2) & p_adc_lg_data_in(v_adc)(3));
                        v_fc_data(11 downto 10)     := (p_adc_frameclk_in(v_adc)(2) & p_adc_frameclk_in(v_adc)(3));
                        v_state := 4;
                    else
                        s_frame_missalignment(v_adc) <= '1';
                        v_state := 0;
                    end if;
                when 4 =>
                    if p_adc_frameclk_in(v_adc)(3 downto 0) = x"F" then
                        v_hg_data(9 downto 6)     := (p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1) & p_adc_hg_data_in(v_adc)(2) & p_adc_hg_data_in(v_adc)(3));
                        v_lg_data(9 downto 6)     := (p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1) & p_adc_lg_data_in(v_adc)(2) & p_adc_lg_data_in(v_adc)(3));
                        v_fc_data(9 downto 6)     := (p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1) & p_adc_frameclk_in(v_adc)(2) & p_adc_frameclk_in(v_adc)(3));
                        v_state := 5;
                    else
                        s_frame_missalignment(v_adc) <= '1';
                        v_state := 0;
                    end if;
                when 5 =>
                    if p_adc_frameclk_in(v_adc)(3 downto 0) = x"1" then
                        v_hg_data(5 downto 2)     := (p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1) & p_adc_hg_data_in(v_adc)(2) & p_adc_hg_data_in(v_adc)(3));
                        v_lg_data(5 downto 2)     := (p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1) & p_adc_lg_data_in(v_adc)(2) & p_adc_lg_data_in(v_adc)(3));
                        v_fc_data(5 downto 2)     := (p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1) & p_adc_frameclk_in(v_adc)(2) & p_adc_frameclk_in(v_adc)(3));
                        v_state := 6;
                    else
                        s_frame_missalignment(v_adc) <= '1';
                        v_state := 0;
                    end if;
                when 6 =>
                    if p_adc_frameclk_in(v_adc)(3 downto 0) = x"0" then
                        v_hg_data(1 downto 0)     := (p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1));
                        v_lg_data(1 downto 0)     := (p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1));
                        v_fc_data(1 downto 0)     := (p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1));
                        s_frame_missalignment(v_adc) <= '0';
                        s_hg_data_fast(v_adc)(13 downto 2)<= v_hg_data;
                        s_lg_data_fast(v_adc)(13 downto 2)<= v_lg_data;
                        s_fc_data_fast(v_adc)(13 downto 2)<= v_fc_data;
                        s_data_toggle(v_adc) <= not s_data_toggle(v_adc);
                        v_state := 0;
                    else
                        s_frame_missalignment(v_adc) <= '1';
                        v_state := 0;
                    end if;
                when others =>
                    s_frame_missalignment(v_adc)   <= '1';
                    v_state   := 0;
             end case;
        end if;
    end process;

    -- CDC into p_clknet_in.cfgbus_clk40 -- see
    -- db6_adc_interface_decoder_iserdese.vhd's s_data_toggle declaration for the full
    -- design reasoning (toggle/valid-handshake synchronizer, fixed latency, no
    -- per-channel tap selection, no elastic buffering).
    proc_cdc_capture : process(p_clknet_in.cfgbus_clk40, p_master_reset_in, p_clknet_in.adc_config.force_adc_readout_reset)
    begin
        if p_master_reset_in = '1' or p_clknet_in.adc_config.force_adc_readout_reset = '1' then
            s_toggle_sync0(v_adc) <= '0';
            s_toggle_sync1(v_adc) <= '0';
            s_toggle_sync1_prev(v_adc) <= '0';
            s_frame_missalignment_sync0(v_adc) <= '1';
            s_frame_missalignment_sync1(v_adc) <= '1';
            s_adc_readout.channel_locked(v_adc) <= '0';
        elsif rising_edge(p_clknet_in.cfgbus_clk40) then
            s_toggle_sync0(v_adc) <= s_data_toggle(v_adc);
            s_toggle_sync1(v_adc) <= s_toggle_sync0(v_adc);
            s_toggle_sync1_prev(v_adc) <= s_toggle_sync1(v_adc);

            s_frame_missalignment_sync0(v_adc) <= s_frame_missalignment(v_adc);
            s_frame_missalignment_sync1(v_adc) <= s_frame_missalignment_sync0(v_adc);

            if s_toggle_sync1(v_adc) /= s_toggle_sync1_prev(v_adc) then
                s_adc_readout.fc_data(v_adc) <= s_fc_data_fast(v_adc);
                s_adc_readout.hg_data(v_adc) <= s_hg_data_fast(v_adc);
                s_adc_readout.lg_data(v_adc) <= s_lg_data_fast(v_adc);
                if s_fc_data_fast(v_adc) = "11111110000000" then
                    s_adc_readout.channel_locked(v_adc) <= '1';
                else
                    s_adc_readout.channel_locked(v_adc) <= '0';
                end if;
            end if;
        end if;
    end process;

    s_adc_readout.channel_frame_missalignemt(v_adc) <= s_frame_missalignment_sync1(v_adc);

end generate;

end Behavioral;
