--=================================================================================================--
--##################################   module information   #######################################--
--=================================================================================================--
--                                                                                         
-- company:               stockholm university                                                        
-- engineer:              samuel silverstein    silver@fysik.su.se
--                        eduardo valdes santurio
--                                                                                                 
-- project name:          adc deserializer for ltc2264-12                                                                
-- module name:           adc_top                                        
--                                                                                                 
-- language:              vhdl                                                                 
--                                                                                                   --
--
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_adc_interface is
    generic (
            g_tmr_enabled      : std_logic := '0';       -- 0 = no no_tmr, 1 = tmr
            g_adc_clocking_scheme : t_adc_clocking_scheme := iddr280;
            g_bitclk        : integer := 280
        );
    port (
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;
        --inputs (plain logic; IBUFDS/IBUFGDS now in db6_adc_interface_io_iddr_bitclk280/240.vhd, instantiated from db7_io_box)
        p_adc_bitclk_in : in std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_in : in std_logic_vector(5 downto 0);
        p_frame_missalignment_in : in std_logic_vector(5 downto 0); -- iddr only
        p_adc_frameclk_in : in t_bitslice_sr; -- iddr only
        p_adc_lg_data_in : in t_bitslice_sr;  -- iddr only
        p_adc_hg_data_in : in t_bitslice_sr;  -- iddr only

        -- iserdese only: parallel, wider ports (see db7_io_box.vhd's port list for why),
        -- plus the closed-loop resync pair with db6_adc_interface_io_iserdese
        p_adc_frameclk_iserdese_in   : in  t_byteslice_sr;
        p_adc_lg_data_iserdese_in    : in  t_byteslice_sr;
        p_adc_hg_data_iserdese_in    : in  t_byteslice_sr;
        p_adc_pll0_locked_in         : in  std_logic_vector(5 downto 0) := (others => '0'); -- iserdese/hss only
        p_adc_frame_missalignment_out : out std_logic_vector(5 downto 0);
        p_adc_ctrl_reset_from_sm_in   : in  std_logic_vector(5 downto 0);
        --control
        p_adc_readout_control_in : in t_adc_readout_control;
        --output
        p_adc_readout_out       : out t_adc_readout;
        -- iddr/iddr280_clkdiv, g_bitclk=280 only: db6_adc_idelay_calibration's chosen
        -- IDELAYE3 tap/load/en_vtc, to be threaded up to db7_io_box's IDELAYE3
        -- primitives (see db6_adc_idelay_calibration.vhd's header for why this lives
        -- here, outside any TMR replication, rather than inside the decoder). Only the
        -- fc/lg/hg idelay_count/load/en_vtc fields of this record are meaningful; every
        -- other field is left undriven and must be ignored by whatever consumes this.
        p_adc_idelay_ctrl_out    : out t_adc_readout_control;
        -- 2026-09-16: automatic startup sequencer for the independent hg/lg tap
        -- search below (see db6_adc_idelay_calibration.vhd's header) -- puts the ADC
        -- into its known SPI test-pattern mode, runs calibration, then writes back
        -- the module's normal functional default config, entirely inside this
        -- entity so all calibration logic (idelay sweep + pattern sequencing) lives
        -- in one place. p_adc_config_reset_in should be db6_adc_config_driver's own
        -- reset (db6_mainboard_interface.vhd's s_adc_config_reset), so this
        -- sequencer resets in step with the module it orchestrates.
        -- p_adc_config_override_out/_active_out briefly (only while active='1')
        -- take priority over whatever the caller's own ADC SPI config mux (VIO
        -- mode/test_pattern_enable/raw registers, configbus/JTAG) would otherwise
        -- drive -- see db6_mainboard_interface.vhd's proc_test_mode for how it's
        -- wired in.
        p_adc_config_reset_in             : in  std_logic := '0';
        p_adc_config_override_out         : out t_adc_register_config;
        p_adc_config_override_active_out  : out std_logic;
        p_leds_out      : out std_logic_vector(3 downto 0)
				);
end db6_adc_interface;

architecture behavioral of db6_adc_interface is

    signal s_adc_gbtx_frameclk : std_logic_vector(5 downto 0);
    signal s_adc_bitclk_locked : std_logic_vector(5 downto 0); -- never driven (io wrapper's locked output was already unconnected pre-refactor)

    signal s_adc_readout : t_adc_readout;
    signal s_adc_readout_tmr : t_adc_readout_tmr;

    signal s_lg_idelay_count, s_hg_idelay_count, s_fc_idelay_count : t_idelay_count;

    -- 2026-09-12: db6_adc_idelay_calibration relocated here from
    -- db6_mainboard_interface.vhd (see that entity's header) -- single shared instance,
    -- outside gen_tmr_disabled/gen_tmr_enabled, driving p_adc_idelay_ctrl_out above and
    -- the new p_calibration_tap_in/done_in/failed_in inputs on every TMR copy of
    -- db6_adc_interface_decoder_iddr_bitclk280 identically.
    signal s_adc_idelay_fc_count, s_adc_idelay_lg_count, s_adc_idelay_hg_count, s_adc_idelay_calibration_tap : t_idelay_count;
    signal s_adc_idelay_fc_load, s_adc_idelay_lg_load, s_adc_idelay_hg_load : std_logic_vector(5 downto 0);
    signal s_adc_idelay_fc_en_vtc, s_adc_idelay_lg_en_vtc, s_adc_idelay_hg_en_vtc : std_logic_vector(5 downto 0);
    signal s_adc_idelay_calibration_done, s_adc_idelay_calibration_failed : std_logic_vector(5 downto 0);
    -- calibration's channel_locked feedback: tmr copy 0 when tripled, to avoid fan-in
    -- from all three onto one signal (same reasoning as the iserdese frame_missalignment
    -- feedback further below in this file).
    signal s_adc_channel_locked_for_calibration : std_logic_vector(5 downto 0);

    -- 2026-09-16: automatic startup sequencer for db6_adc_idelay_calibration's
    -- independent hg/lg tap search (see that file's header). Runs once, automatically,
    -- right after p_adc_config_reset_in releases: puts the ADC into its known SPI
    -- test-pattern mode (c_adc_idelay_calibration_test_pattern) via
    -- p_adc_config_override_out/_active_out, pulses the calibration engine's p_start_in
    -- once that's confirmed written (adc_config_done falling then rising again), waits
    -- for every channel to report done or failed, then writes the module's own existing
    -- default functional config (c_adc_register_init_config_14_bit) so the ADC is left
    -- correctly configured for real readout, and finally drops the override so the
    -- caller's own ADC SPI config mux (VIO/configbus) takes back over exactly as before.
    -- Declared here (unconditionally) but only ever actually driven away from its
    -- default/inactive values inside gen_idelay_calibration_bitclk280 below (g_bitclk=280
    -- -- the only case where a calibration engine exists to orchestrate); for g_bitclk=240
    -- or hss_wizard, these simply stay at their initial values forever (same "never
    -- driven" convention already used elsewhere in this file, e.g. s_adc_bitclk_locked),
    -- so p_adc_config_override_active_out reads a constant '0' there -- the caller's own
    -- mux behaves exactly as it did before this sequencer existed.
    type t_cal_seq_state is (st_enable_test_pattern, st_wait_test_pattern_written,
                              st_run_calibration, st_wait_calibration_done,
                              st_restore_default, st_wait_restore_written, st_done);
    signal s_cal_seq_state : t_cal_seq_state := st_enable_test_pattern;
    signal s_cal_seq_active : std_logic := '0';
    signal s_cal_seq_override : t_adc_register_config := c_adc_register_init_config_14_bit;
    signal s_cal_seq_start_calibration : std_logic := '0';
    signal s_cal_seq_adc_config_done_prev : std_logic := '0';
    -- generous fixed timeout on each "wait for adc_config_done to pulse" step, same
    -- large-fallback-counter idiom db6_adc_config_driver.vhd already uses (its own
    -- v_counter = 20000000 checks) -- purely a safety net against an unexpected stuck
    -- condition never leaving this sequencer parked mid-boot; not expected to ever fire.
    constant c_cal_seq_timeout : integer := 20000000;
    signal s_cal_seq_timeout_counter : integer range 0 to c_cal_seq_timeout := 0;

    -- iserdese + tmr only: each tmr copy's own frame_missalignment_out, tmr copy 0 feeds
    -- the shared io feedback (see gen_db6_adc_interface_iserdese below)
    type t_frame_missalignment_tmr is array (0 to 2) of std_logic_vector(5 downto 0);
    signal s_adc_frame_missalignment_tmr : t_frame_missalignment_tmr;

    -- 2026-09-13: db6_adc_idelay_calibration's LOAD pulse (proc_fast_domain in that
    -- file) is generated synchronous to whatever clock is passed as its
    -- p_adc_bitclk_in port -- its header says this MUST be "IDELAYE3's own CLK", i.e.
    -- whatever clock is actually wired to db7_io_box's IDELAYE3.CLK pin for the active
    -- scheme. For iddr280/iddr280_clkdiv that is the raw 280MHz p_adc_bitclk_in
    -- (db6_adc_interface_io_iddr_bitclk280.vhd's IDELAYE3 .clk <= s_bitclk_se). For
    -- iddr280_serdes140 it is the 140MHz CLKDIV (s_bitclkdiv) instead -- REQP-1742
    -- (IDELAYE3.CLK must share a net with its paired ISERDESE3.CLKDIV) forced that
    -- rewiring in db6_adc_interface_io_iddr_bitclk280_serdes140.vhd, but the shared
    -- calibration instance below was never updated to match, so the LOAD pulse was
    -- being generated in a domain unrelated to what IDELAYE3 actually samples it
    -- with -- corrupting the loaded tap and, with it, every capture downstream (the
    -- 2026-09-13 hardware bring-up symptom: frameclk nibbles changing but never
    -- matching the expected marker in any rotation). Feed the calibration module
    -- whichever clock is actually correct for the active scheme.
    signal s_idelay_calibration_clk : std_logic_vector(5 downto 0);

begin

s_idelay_calibration_clk <= p_adc_bitclkdiv_in when g_adc_clocking_scheme = iddr280_serdes140 else p_adc_bitclk_in;

p_adc_readout_out.channel_clk280_locked<=s_adc_bitclk_locked;

-- 2026-09-16: unconditional, single driver for both new ports (see
-- proc_idelay_calibration_sequencer's declaration comment above for why this is
-- outside any generate) -- sourced from s_cal_seq_active/s_cal_seq_override, which
-- only gen_idelay_calibration_bitclk280 (g_bitclk=280) below ever actually drives
-- away from their inactive defaults.
p_adc_config_override_active_out <= s_cal_seq_active;
p_adc_config_override_out         <= s_cal_seq_override;

-- IO primitives (IBUFDS/IBUFGDS/IDELAYE3/IDDRE1) for both bitclk variants moved to
-- db6_adc_interface_io_iddr_bitclk280.vhd / _bitclk240.vhd, instantiated from db7_io_box.
-- This entity now takes their plain-logic outputs directly as its own inputs.

-- ADC readout front end select: iddr (this branch, unchanged) or hss (below), by
-- g_adc_clocking_scheme. Only one is ever elaborated.
gen_db6_adc_interface_iddr : if g_adc_clocking_scheme /= hss_wizard generate

p_adc_frame_missalignment_out <= (others => '0');

gen_calibration_locked_tmr_disabled : if g_tmr_enabled = '0' generate
    s_adc_channel_locked_for_calibration <= s_adc_readout.channel_locked;
end generate;
gen_calibration_locked_tmr_enabled : if g_tmr_enabled = '1' generate
    s_adc_channel_locked_for_calibration <= s_adc_readout_tmr(0).channel_locked;
end generate;

gen_idelay_calibration_bitclk280 : if g_bitclk = 280 generate
    i_db6_adc_idelay_calibration : entity tilecal.db6_adc_idelay_calibration
        port map (
            p_master_reset_in   => p_master_reset_in,
            p_clknet_in         => p_clknet_in,
            p_adc_bitclk_in     => s_idelay_calibration_clk,
            -- 2026-09-16: was p_adc_readout_control_in.adc_config_done directly --
            -- now gated by proc_idelay_calibration_sequencer below (same entity) so
            -- the sweep only starts once the ADC is confirmed already in its startup
            -- test-pattern mode (needed for the independent hg/lg search below).
            p_start_in          => s_cal_seq_start_calibration,
            p_channel_locked_in => s_adc_channel_locked_for_calibration,
            -- 2026-09-16: independent hg/lg tap verification against a known ADC test
            -- pattern (see db6_adc_idelay_calibration.vhd's header) -- s_adc_readout
            -- is this same entity's decoder output, already in the cfgbus_clk40
            -- domain via the decoder's own CDC, so no new crossing needed here.
            p_hg_data_in          => s_adc_readout.hg_data,
            p_lg_data_in          => s_adc_readout.lg_data,
            p_expected_pattern_in => c_adc_idelay_calibration_test_pattern,
            p_fc_idelay_count_out  => s_adc_idelay_fc_count,
            p_fc_idelay_load_out   => s_adc_idelay_fc_load,
            p_fc_idelay_en_vtc_out => s_adc_idelay_fc_en_vtc,
            p_lg_idelay_count_out  => s_adc_idelay_lg_count,
            p_lg_idelay_load_out   => s_adc_idelay_lg_load,
            p_lg_idelay_en_vtc_out => s_adc_idelay_lg_en_vtc,
            p_hg_idelay_count_out  => s_adc_idelay_hg_count,
            p_hg_idelay_load_out   => s_adc_idelay_hg_load,
            p_hg_idelay_en_vtc_out => s_adc_idelay_hg_en_vtc,
            p_calibration_done_out   => s_adc_idelay_calibration_done,
            p_calibration_failed_out => s_adc_idelay_calibration_failed,
            p_calibration_tap_out    => s_adc_idelay_calibration_tap
        );

    p_adc_idelay_ctrl_out.fc_idelay_count  <= s_adc_idelay_fc_count;
    p_adc_idelay_ctrl_out.fc_idelay_load   <= s_adc_idelay_fc_load;
    p_adc_idelay_ctrl_out.fc_idelay_en_vtc <= s_adc_idelay_fc_en_vtc;
    p_adc_idelay_ctrl_out.lg_idelay_count  <= s_adc_idelay_lg_count;
    p_adc_idelay_ctrl_out.lg_idelay_load   <= s_adc_idelay_lg_load;
    p_adc_idelay_ctrl_out.lg_idelay_en_vtc <= s_adc_idelay_lg_en_vtc;
    p_adc_idelay_ctrl_out.hg_idelay_count  <= s_adc_idelay_hg_count;
    p_adc_idelay_ctrl_out.hg_idelay_load   <= s_adc_idelay_hg_load;
    p_adc_idelay_ctrl_out.hg_idelay_en_vtc <= s_adc_idelay_hg_en_vtc;

    -- 2026-09-16: see proc_idelay_calibration_sequencer's declaration comment
    -- (architecture header) for the full description. One-shot, runs automatically
    -- from reset; s_cal_seq_active drops back to '0' forever once st_done is reached
    -- and never re-enters except via a fresh p_adc_config_reset_in/force_recalibrate/
    -- force_adc_readout_reset.
    proc_idelay_calibration_sequencer : process(p_clknet_in.cfgbus_clk40, p_adc_config_reset_in, p_clknet_in.adc_config.force_recalibrate, p_clknet_in.adc_config.force_adc_readout_reset)
    begin
        if p_adc_config_reset_in = '1' or p_clknet_in.adc_config.force_recalibrate = '1' or p_clknet_in.adc_config.force_adc_readout_reset = '1' then
            s_cal_seq_state <= st_enable_test_pattern;
            s_cal_seq_active <= '1';
            s_cal_seq_override <= c_adc_register_init_config_14_bit;
            s_cal_seq_start_calibration <= '0';
            s_cal_seq_adc_config_done_prev <= '0';
            s_cal_seq_timeout_counter <= 0;
        elsif rising_edge(p_clknet_in.cfgbus_clk40) then

            s_cal_seq_adc_config_done_prev <= p_adc_readout_control_in.adc_config_done;

            case s_cal_seq_state is

                when st_enable_test_pattern =>
                    -- known calibration pattern into registers 3/4, same non-pattern
                    -- defaults db6_mainboard_interface.vhd's own proc_test_mode
                    -- test_pattern_enable branch uses -- see this record's own
                    -- c_adc_register_init_config_14_bit for mb_fpga/pmt_select.
                    s_cal_seq_override.mode <= '1';
                    s_cal_seq_override.trigger_mb_adc_config <= '1';
                    s_cal_seq_override.mb_fpga_select <= c_adc_register_init_config_14_bit.mb_fpga_select;
                    s_cal_seq_override.mb_pmt_select  <= c_adc_register_init_config_14_bit.mb_pmt_select;
                    s_cal_seq_override.adc_registers(0) <= c_adc_registers_init_14_bit(0);
                    s_cal_seq_override.adc_registers(1) <= c_adc_registers_init_14_bit(1);
                    s_cal_seq_override.adc_registers(2) <= c_adc_registers_init_14_bit(2);
                    s_cal_seq_override.adc_registers(3) <= '1' & '0' & c_adc_idelay_calibration_test_pattern(13 downto 8);
                    s_cal_seq_override.adc_registers(4) <= c_adc_idelay_calibration_test_pattern(7 downto 0);
                    s_cal_seq_timeout_counter <= 0;
                    s_cal_seq_state <= st_wait_test_pattern_written;

                when st_wait_test_pattern_written =>
                    s_cal_seq_override.trigger_mb_adc_config <= '0';
                    -- adc_config_done drops while db6_adc_config_driver runs the actual
                    -- SPI write sequence, then rises again once it's back in st_idle --
                    -- a falling-then-rising edge is the real "write finished" signal,
                    -- not just "trigger seen".
                    if s_cal_seq_adc_config_done_prev = '0' and p_adc_readout_control_in.adc_config_done = '1' then
                        s_cal_seq_start_calibration <= '1';
                        s_cal_seq_state <= st_run_calibration;
                    elsif s_cal_seq_timeout_counter = c_cal_seq_timeout then
                        -- shouldn't happen (db6_adc_config_driver has its own internal
                        -- timeout well under this one) -- fail safe by moving on rather
                        -- than parking the ADC in test-pattern mode forever.
                        s_cal_seq_state <= st_restore_default;
                    else
                        s_cal_seq_timeout_counter <= s_cal_seq_timeout_counter + 1;
                    end if;

                when st_run_calibration =>
                    s_cal_seq_start_calibration <= '0';
                    s_cal_seq_timeout_counter <= 0;
                    s_cal_seq_state <= st_wait_calibration_done;

                when st_wait_calibration_done =>
                    -- every channel reached a terminal state (locked all 3 lanes, or
                    -- at least one lane failed) -- proceed regardless of outcome so a
                    -- calibration failure on one channel never leaves the whole board
                    -- stuck in test-pattern mode; failures stay visible via
                    -- s_adc_idelay_calibration_failed for diagnosis.
                    if (s_adc_idelay_calibration_done or s_adc_idelay_calibration_failed) = "111111" then
                        s_cal_seq_state <= st_restore_default;
                    elsif s_cal_seq_timeout_counter = c_cal_seq_timeout then
                        s_cal_seq_state <= st_restore_default;
                    else
                        s_cal_seq_timeout_counter <= s_cal_seq_timeout_counter + 1;
                    end if;

                when st_restore_default =>
                    s_cal_seq_override <= c_adc_register_init_config_14_bit;
                    s_cal_seq_override.mode <= '1';
                    s_cal_seq_override.trigger_mb_adc_config <= '1';
                    s_cal_seq_timeout_counter <= 0;
                    s_cal_seq_state <= st_wait_restore_written;

                when st_wait_restore_written =>
                    s_cal_seq_override.trigger_mb_adc_config <= '0';
                    if s_cal_seq_adc_config_done_prev = '0' and p_adc_readout_control_in.adc_config_done = '1' then
                        s_cal_seq_active <= '0';
                        s_cal_seq_state <= st_done;
                    elsif s_cal_seq_timeout_counter = c_cal_seq_timeout then
                        -- fail safe: still hand the mux back rather than hold mode='1'
                        -- forever, even though the functional-default write may not
                        -- have completed -- an operator can always re-trigger manually
                        -- via the existing VIO mode/trigger controls from here.
                        s_cal_seq_active <= '0';
                        s_cal_seq_state <= st_done;
                    else
                        s_cal_seq_timeout_counter <= s_cal_seq_timeout_counter + 1;
                    end if;

                when st_done =>
                    null; -- terminal until p_adc_config_reset_in/force_recalibrate/force_adc_readout_reset

                when others =>
                    null;

            end case;
        end if;
    end process;

end generate;

gen_tmr_disabled: if g_tmr_enabled = '0' generate
    p_adc_readout_out<=s_adc_readout;
    g_bitclk240 : if g_bitclk = 240 generate
        i_db6_adc_interface_decoder_iddr : entity tilecal.db6_adc_interface_decoder_iddr_bitclk240
            generic map(
                g_adc_clocking_scheme =>  g_adc_clocking_scheme,
                g_tmr_enabled => g_tmr_enabled
                )
            port map (
                p_master_reset_in   => p_master_reset_in,
                --clock
                p_clknet_in         => p_clknet_in,
                p_db_reg_rx_in      => p_db_reg_rx_in,
                --inputs
                p_adc_bitclk_in     => p_adc_bitclk_in,
                p_adc_bitclkdiv_in    => p_adc_bitclkdiv_in,
                p_frame_missalignment_in => p_frame_missalignment_in,
                p_adc_frameclk_in   => p_adc_frameclk_in,
                p_adc_lg_data_in    => p_adc_lg_data_in,
                p_adc_hg_data_in    => p_adc_hg_data_in,


                --control
                p_adc_readout_control_in => p_adc_readout_control_in,

                --output
                p_adc_readout_out   => s_adc_readout,

                --debug
                p_leds_out          => open
                        );
    end generate;

    g_bitclk280 : if g_bitclk = 280 and g_adc_clocking_scheme /= iddr280_serdes140 generate
        i_db6_adc_interface_decoder_iddr : entity tilecal.db6_adc_interface_decoder_iddr_bitclk280
            generic map(
                g_tmr_enabled => g_tmr_enabled,
                g_adc_clocking_scheme => g_adc_clocking_scheme
                )
            port map (
                p_master_reset_in   => p_master_reset_in,
                --clock
                p_clknet_in         => p_clknet_in,
                p_db_reg_rx_in      => p_db_reg_rx_in,
                --inputs
                p_adc_bitclk_in     => p_adc_bitclk_in,
                p_adc_bitclkdiv_in    => p_adc_bitclkdiv_in,
                p_adc_frameclk_in   => p_adc_frameclk_in,
                p_adc_lg_data_in    => p_adc_lg_data_in,
                p_adc_hg_data_in    => p_adc_hg_data_in,
                p_adc_pll0_locked_in => p_adc_pll0_locked_in,
                p_calibration_tap_in    => s_adc_idelay_calibration_tap,
                p_calibration_done_in   => s_adc_idelay_calibration_done,
                p_calibration_failed_in => s_adc_idelay_calibration_failed,

                --control
                p_adc_readout_control_in => p_adc_readout_control_in,

                --output
                p_adc_readout_out   => s_adc_readout,

                --debug
                p_leds_out          => open
                        );
    end generate;

    -- 2026-09-13: iddr280_serdes140 -- see
    -- db6_adc_interface_decoder_iddr_bitclk280_serdes140.vhd's header. Consumes the
    -- same wide/iserdese-shaped ports as the hss_wizard branch below (this scheme's IO
    -- layer produces the same t_byteslice_sr shape), but stays inside
    -- gen_db6_adc_interface_iddr (g_adc_clocking_scheme /= hss_wizard) so it still gets
    -- the shared db6_adc_idelay_calibration instance above, unlike hss_wizard.
    g_bitclk280_serdes140 : if g_bitclk = 280 and g_adc_clocking_scheme = iddr280_serdes140 generate
        i_db6_adc_interface_decoder_iddr_serdes140 : entity tilecal.db6_adc_interface_decoder_iddr_bitclk280_serdes140
            generic map(
                g_tmr_enabled => g_tmr_enabled
                )
            port map (
                p_master_reset_in   => p_master_reset_in,
                --clock
                p_clknet_in         => p_clknet_in,
                p_db_reg_rx_in      => p_db_reg_rx_in,
                --inputs
                p_adc_bitclk_in     => p_adc_bitclk_in,
                p_adc_bitclkdiv_in  => p_adc_bitclkdiv_in,
                p_adc_frameclk_in   => p_adc_frameclk_iserdese_in,
                p_adc_lg_data_in    => p_adc_lg_data_iserdese_in,
                p_adc_hg_data_in    => p_adc_hg_data_iserdese_in,
                p_adc_pll0_locked_in => p_adc_pll0_locked_in,
                p_calibration_tap_in    => s_adc_idelay_calibration_tap,
                p_calibration_done_in   => s_adc_idelay_calibration_done,
                p_calibration_failed_in => s_adc_idelay_calibration_failed,

                --control
                p_adc_readout_control_in => p_adc_readout_control_in,

                --output
                p_adc_readout_out   => s_adc_readout,

                --debug
                p_leds_out          => open
                        );
    end generate;

end generate;

gen_tmr_enabled: if g_tmr_enabled = '1' generate
    p_adc_readout_out<=s_adc_readout;
    
    gen_tmr : for v_tmr in 0 to 2 generate
        g_bitclk240 : if g_bitclk = 240 generate
            i_db6_adc_interface_decoder_iddr : entity tilecal.db6_adc_interface_decoder_iddr_bitclk240
                generic map(
                    g_adc_clocking_scheme => g_adc_clocking_scheme,
                    g_tmr_enabled => g_tmr_enabled
                    )
                port map ( 	
                    p_master_reset_in   => '0',
                    --clock
                    p_clknet_in         => p_clknet_in,
                    p_db_reg_rx_in      => p_db_reg_rx_in,
                    --inputs
                    p_adc_bitclk_in     => p_adc_bitclk_in,
                    p_adc_bitclkdiv_in  => p_adc_bitclkdiv_in,
                    p_adc_frameclk_in   => p_adc_frameclk_in,
                    p_frame_missalignment_in => p_frame_missalignment_in,
                    p_adc_lg_data_in    => p_adc_lg_data_in,
                    p_adc_hg_data_in    => p_adc_hg_data_in,
                    
                    
                    --control
                    p_adc_readout_control_in => p_adc_readout_control_in,
                    
                    --output
                    p_adc_readout_out   => s_adc_readout_tmr(v_tmr),
                    
                    --debug
                    p_leds_out          => open
                            );
        end generate;
        g_bitclk280 : if g_bitclk = 280 and g_adc_clocking_scheme /= iddr280_serdes140 generate
            i_db6_adc_interface_decoder_iddr : entity tilecal.db6_adc_interface_decoder_iddr_bitclk280
                generic map(
                    g_tmr_enabled => g_tmr_enabled,
                    g_adc_clocking_scheme => g_adc_clocking_scheme
                    )
                port map (
                    p_master_reset_in   => '0',
                    --clock
                    p_clknet_in         => p_clknet_in,
                    p_db_reg_rx_in      => p_db_reg_rx_in,
                    --inputs
                    p_adc_bitclk_in     => p_adc_bitclk_in,
                    p_adc_bitclkdiv_in  => p_adc_bitclkdiv_in,
                    p_adc_frameclk_in   => p_adc_frameclk_in,
                    p_adc_lg_data_in    => p_adc_lg_data_in,
                    p_adc_hg_data_in    => p_adc_hg_data_in,
                    p_adc_pll0_locked_in => p_adc_pll0_locked_in,
                    p_calibration_tap_in    => s_adc_idelay_calibration_tap,
                    p_calibration_done_in   => s_adc_idelay_calibration_done,
                    p_calibration_failed_in => s_adc_idelay_calibration_failed,

                    --control
                    p_adc_readout_control_in => p_adc_readout_control_in,

                    --output
                    p_adc_readout_out   => s_adc_readout_tmr(v_tmr),

                    --debug
                    p_leds_out          => open
                            );
        end generate;
        g_bitclk280_serdes140 : if g_bitclk = 280 and g_adc_clocking_scheme = iddr280_serdes140 generate
            i_db6_adc_interface_decoder_iddr_serdes140 : entity tilecal.db6_adc_interface_decoder_iddr_bitclk280_serdes140
                generic map(
                    g_tmr_enabled => g_tmr_enabled
                    )
                port map (
                    p_master_reset_in   => '0',
                    --clock
                    p_clknet_in         => p_clknet_in,
                    p_db_reg_rx_in      => p_db_reg_rx_in,
                    --inputs
                    p_adc_bitclk_in     => p_adc_bitclk_in,
                    p_adc_bitclkdiv_in  => p_adc_bitclkdiv_in,
                    p_adc_frameclk_in   => p_adc_frameclk_iserdese_in,
                    p_adc_lg_data_in    => p_adc_lg_data_iserdese_in,
                    p_adc_hg_data_in    => p_adc_hg_data_iserdese_in,
                    p_adc_pll0_locked_in => p_adc_pll0_locked_in,
                    p_calibration_tap_in    => s_adc_idelay_calibration_tap,
                    p_calibration_done_in   => s_adc_idelay_calibration_done,
                    p_calibration_failed_in => s_adc_idelay_calibration_failed,

                    --control
                    p_adc_readout_control_in => p_adc_readout_control_in,

                    --output
                    p_adc_readout_out   => s_adc_readout_tmr(v_tmr),

                    --debug
                    p_leds_out          => open
                            );
        end generate;
    end generate;
    gen_adc_channel_voters: for v_adc in 0 to 5 generate

        i_entity_db6_tmr_voter_lg_data : entity tilecal.db6_tmr_voter --tilecal.db6_tmr_voter_sync_cdc
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).lg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).lg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).lg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_lg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.lg_data(v_adc)   
                );

        i_entity_db6_tmr_voter_hg_data : entity tilecal.db6_tmr_voter --tilecal.db6_tmr_voter_sync_cdc
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).hg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).hg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).hg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_hg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.hg_data(v_adc)   
                );

        i_entity_db6_tmr_voter_fc_data : entity tilecal.db6_tmr_voter --tilecal.db6_tmr_voter_sync_cdc
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).fc_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).fc_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).fc_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_fc(v_adc),
                p_std_logic_vector_out         => s_adc_readout.fc_data(v_adc)   
                );
        
        s_adc_readout.tmr_error(v_adc)<= s_adc_readout.tmr_error_lg(v_adc) or s_adc_readout.tmr_error_hg(v_adc) or s_adc_readout.tmr_error_fc(v_adc);

    end generate;
end generate;

end generate; -- gen_db6_adc_interface_iddr

-- SelectIO Interface Wizard front end (hss_adc, registered on the divided clkdiv --
-- see db6_adc_interface_io_hss.vhd -- instead of IDDRE1's raw undivided-bitclk output,
-- which needed an SRL pipeline stage tight enough to violate timing at 280 Mbps).
gen_db6_adc_interface_iserdese : if g_adc_clocking_scheme = hss_wizard generate

gen_tmr_disabled: if g_tmr_enabled = '0' generate
    p_adc_readout_out<=s_adc_readout;
    i_db6_adc_interface_decoder_iserdese : entity tilecal.db6_adc_interface_decoder_iserdese
            generic map(
                g_tmr_enabled => g_tmr_enabled
                )
        port map (
            p_master_reset_in   => p_master_reset_in,
            --clock
            p_clknet_in         => p_clknet_in,
            p_db_reg_rx_in      => p_db_reg_rx_in,
            --inputs
            p_adc_bitclk_in     => p_adc_bitclk_in,
            p_adc_bitclkdiv_in    => p_adc_bitclkdiv_in,
            p_frame_missalignment_out => p_adc_frame_missalignment_out,
            p_ctrl_reset_from_sm_in => p_adc_ctrl_reset_from_sm_in,
            p_adc_frameclk_in   => p_adc_frameclk_iserdese_in,
            p_adc_lg_data_in    => p_adc_lg_data_iserdese_in,
            p_adc_hg_data_in    => p_adc_hg_data_iserdese_in,
            p_adc_pll0_locked_in => p_adc_pll0_locked_in,

            --control
            p_adc_readout_control_in => p_adc_readout_control_in,

            --output
            p_adc_readout_out   => s_adc_readout,

            --debug
            p_leds_out          => open
                    );

end generate;

gen_tmr_enabled: if g_tmr_enabled = '1' generate
    p_adc_readout_out<=s_adc_readout;

    gen_tmr : for v_tmr in 0 to 2 generate
        i_db6_adc_interface_decoder_iserdese : entity tilecal.db6_adc_interface_decoder_iserdese
            generic map(
                g_tmr_enabled => g_tmr_enabled
                )
            port map (
                p_master_reset_in   => '0',
                --clock
                p_clknet_in         => p_clknet_in,
                p_db_reg_rx_in      => p_db_reg_rx_in,
                --inputs
                p_adc_bitclk_in     => p_adc_bitclk_in,
                p_adc_bitclkdiv_in  => p_adc_bitclkdiv_in,
                -- all three copies see the same inputs and run the same state machine,
                -- so they agree; only tmr copy 0's is used for the shared io feedback,
                -- avoiding fan-in from all three onto one signal.
                p_frame_missalignment_out => s_adc_frame_missalignment_tmr(v_tmr),
                p_ctrl_reset_from_sm_in => p_adc_ctrl_reset_from_sm_in,
                p_adc_frameclk_in   => p_adc_frameclk_iserdese_in,
                p_adc_lg_data_in    => p_adc_lg_data_iserdese_in,
                p_adc_hg_data_in    => p_adc_hg_data_iserdese_in,

                --control
                p_adc_readout_control_in => p_adc_readout_control_in,

                --output
                p_adc_readout_out   => s_adc_readout_tmr(v_tmr),

                --debug
                p_leds_out          => open
                        );
    end generate;

    p_adc_frame_missalignment_out <= s_adc_frame_missalignment_tmr(0);

    gen_adc_channel_voters: for v_adc in 0 to 5 generate

        i_entity_db6_tmr_voter_lg_data : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).lg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).lg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).lg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_lg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.lg_data(v_adc)
                );

        i_entity_db6_tmr_voter_hg_data : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).hg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).hg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).hg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_hg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.hg_data(v_adc)
                );

        i_entity_db6_tmr_voter_fc_data : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).fc_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).fc_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).fc_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_fc(v_adc),
                p_std_logic_vector_out         => s_adc_readout.fc_data(v_adc)
                );

        s_adc_readout.tmr_error(v_adc)<= s_adc_readout.tmr_error_lg(v_adc) or s_adc_readout.tmr_error_hg(v_adc) or s_adc_readout.tmr_error_fc(v_adc);

    end generate;
end generate;

end generate; -- gen_db6_adc_interface_iserdese

end behavioral;