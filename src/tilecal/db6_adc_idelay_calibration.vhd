----------------------------------------------------------------------------------
-- db6_adc_idelay_calibration
--
-- 2026-09-12: startup IDELAYE3 tap calibration for the iddr_bitclk280 ADC readout
-- (both iddr280 and iddr280_clkdiv g_adc_clocking_scheme variants -- see
-- db6_adc_interface_decoder_iddr_bitclk280.vhd's proc_cdc_capture header for why the
-- old dual-tap canary-lock CDC in that file was replaced: it only ever chose between
-- two fixed, discrete pipeline-depth taps, each independently per channel, which
-- could give a different fixed latency per channel and never actually centered the
-- sample point in the data eye -- it just tolerated being somewhere inside it. This
-- module instead sweeps the physical IDELAYE3 tap chain (the fine per-pin input
-- delay line in db6_adc_interface_io_iddr_bitclk280.vhd -- 32 taps, 0-31, on
-- UltraScale+) once at startup, uses the known fc marker pattern
-- ("11111110000000", the only signal with a pattern that can be checked bit-for-bit
-- -- see proc_mon/channel_locked in the decoder) to find the full contiguous range
-- of taps where the decoder holds a clean lock, and settles on the middle of that
-- range: the most timing-margin-robust single sample point. Once locked, the tap is
-- never touched again -- fixed latency, no elastic buffering, same requirement as
-- every other fix this session.
--
-- 2026-09-16: hg/lg used to just share fc's calibrated tap (same ADC chip, matched
-- trace lengths, no independent known pattern to calibrate them against separately
-- -- that assumption is what this header used to say). Found via real hardware
-- bring-up that this isn't reliable: Vivado's placement/routing isn't fully
-- deterministic run-to-run (documented elsewhere this project), so a compile can
-- shrink one lane's margin below another's on a given channel even with unchanged,
-- correctly-matched RTL/traces -- symptom was one channel's lg reading back a fixed,
-- reproducible bit-shifted value (e.g. commanded 0x0008 read back as 0x0002) while fc
-- stayed locked, with healthy post-route timing margin on the capture path (ruled
-- out as a real STA violation) and correct, symmetric decoder logic (ruled out as a
-- design bug) -- i.e. exactly what "no verification, just borrow fc's tap" predicts
-- once you stop assuming perfectly matched margins on every compile.
--
-- Fix: each of fc/hg/lg now gets its own fully independent tap sweep (gen_lane
-- below), not one shared value. fc's lock check is unchanged (its own marker via
-- p_channel_locked_in). hg/lg have no marker of their own in normal operation, but
-- the ADC chip (LTC2264-12) can be put into a known digital test-pattern mode via
-- SPI (see db6_mainboard_interface.vhd's proc_test_mode) -- confirmed on real
-- hardware that this does NOT affect fc's own output (fc keeps producing its normal
-- marker even while the data lanes are forced to the test pattern), so hg/lg's
-- pattern-compare search can run at the same time as fc's marker search, in the same
-- calibration window, no phase-splitting needed. db6_mainboard_interface.vhd's
-- proc_idelay_calibration_sequencer automatically puts the ADC into that mode with a
-- fixed known value (c_adc_idelay_calibration_test_pattern) before pulsing
-- p_start_in, and takes it back out once every channel reports done/failed here --
-- this module doesn't drive the ADC configuration itself, it just assumes
-- p_hg/lg_data_in already reflect that known pattern for the whole time p_start_in
-- through st_locked/st_failed takes.
--
-- Deliberately instantiated OUTSIDE db7_io_box (see db6_mainboard_interface.vhd):
-- this is plain fabric logic, and db7_io_box is meant to hold only physical,
-- non-triplicable IO primitives (the IDELAYE3/IDDRE1 themselves stay there, same
-- reasoning already applied to pll_adc_channel). A single shared calibration engine
-- here drives the (also single, non-triplicated) t_adc_readout_control idelay
-- fields that already fan out identically to all three TMR copies of the decoder --
-- same as every other shared, non-duplicated control signal in that record. Three
-- independent calibration engines each driving the one physical IDELAYE3 per pin
-- would simply conflict.
--
-- The one real clock-domain-crossing problem here: the tap-sweep/lock-observation
-- decision has to live in cfgbus_clk40 (that's where channel_locked, the feedback
-- signal, already lives), but IDELAYE3's LOAD input must be synchronous to its own
-- CLK (p_adc_bitclk_in(v_adc), ~280MHz, a different, per-channel clock domain with
-- an unknown, uncalibrated fixed phase relative to cfgbus_clk40 -- the same
-- mesochronous relationship called out elsewhere this session, just with
-- cfgbus_clk40 as the source here instead of the destination). Solved with a
-- standard two-phase level request/acknowledge handshake instead of a bare toggle
-- broadcast: the request level and the acknowledge level are each only ever sampled
-- once they've been stable/held (the requester never changes the request again
-- until it has seen the ack follow), so each individual 2-flop synchronizer
-- crossing is safe regardless of which direction is faster -- unlike the raw
-- multi-bit/short-pulse crossings fixed elsewhere this session, a held-level
-- handshake doesn't depend on a frequency-ratio safety margin at all. cntvaluein
-- (the 9-bit tap value) is only ever changed by the requester immediately before
-- toggling the request, and held stable through the whole subsequent settle+observe
-- window, so it is always stable well before the fast domain acts on it -- same
-- "stable before toggle, read only after toggle detected" reasoning as every other
-- crossing fixed this session. 2026-09-16: this whole handshake is now replicated
-- per-lane (gen_lane), not just per-channel -- each lane's IDELAYE3 LOAD is
-- independent, so each needs its own req/ack pair.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_adc_idelay_calibration is
    port (
        p_master_reset_in : in std_logic;
        p_clknet_in        : in t_db_clknet;                   -- cfgbus_clk40 domain for the FSM
        p_adc_bitclk_in    : in std_logic_vector(5 downto 0);  -- per-channel ~280MHz, IDELAYE3 clk domain

        p_start_in          : in  std_logic;                   -- pulse once the ADC is confirmed in its startup test-pattern mode (see db6_mainboard_interface.vhd's proc_idelay_calibration_sequencer) -- NOT the same as adc_config_done alone
        p_channel_locked_in : in  std_logic_vector(5 downto 0); -- decoder's channel_locked (cfgbus_clk40 domain) -- fc's lock check only

        -- 2026-09-16: independent hg/lg verification against a known ADC test
        -- pattern -- see this file's header. Live decoded words (cfgbus_clk40
        -- domain, from the decoder's own CDC), valid for calibration purposes only
        -- while the caller actually holds the ADC in test-pattern mode for the whole
        -- p_start_in..st_locked/st_failed window.
        p_hg_data_in          : in  t_adc_data;
        p_lg_data_in          : in  t_adc_data;
        p_expected_pattern_in : in  std_logic_vector(13 downto 0);

        p_fc_idelay_count_out  : out t_idelay_count;
        p_fc_idelay_load_out   : out std_logic_vector(5 downto 0);
        p_fc_idelay_en_vtc_out : out std_logic_vector(5 downto 0);
        p_lg_idelay_count_out  : out t_idelay_count;
        p_lg_idelay_load_out   : out std_logic_vector(5 downto 0);
        p_lg_idelay_en_vtc_out : out std_logic_vector(5 downto 0);
        p_hg_idelay_count_out  : out t_idelay_count;
        p_hg_idelay_load_out   : out std_logic_vector(5 downto 0);
        p_hg_idelay_en_vtc_out : out std_logic_vector(5 downto 0);

        p_calibration_done_out   : out std_logic_vector(5 downto 0); -- all 3 lanes locked
        p_calibration_failed_out : out std_logic_vector(5 downto 0); -- any lane failed to find a lock window
        p_calibration_tap_out    : out t_idelay_count -- debug only: fc's own chosen tap per channel (hg/lg can differ now -- see p_hg/lg_idelay_count_out for their real per-lane values)
    );
end db6_adc_idelay_calibration;

architecture behavioral of db6_adc_idelay_calibration is

    constant c_idelay_max_tap : integer := 31; -- IDELAYE3, UltraScale+, single element (no cascade): 32 taps, 0-31

    -- 2026-09-16: fc/hg/lg each get their own independent search now (see header) --
    -- indexed as a second generate dimension instead of 3x copy-pasting every
    -- process below, to keep the fc/hg/lg searches guaranteed identical in structure.
    constant c_lane_fc : integer := 0;
    constant c_lane_hg : integer := 1;
    constant c_lane_lg : integer := 2;
    constant c_num_lanes : integer := 3;

    type t_cal_state is (st_idle, st_req_load, st_wait_settle, st_observe, st_next_tap, st_finish_load, st_locked, st_failed);
    type t_cal_state_array is array (0 to 5, 0 to c_num_lanes-1) of t_cal_state;
    signal s_state : t_cal_state_array := (others => (others => st_idle));

    type t_tap_array is array (0 to 5, 0 to c_num_lanes-1) of integer range 0 to c_idelay_max_tap;
    -- best contiguous all-locked tap run seen so far, and the run currently being tracked
    signal s_tap, s_run_start, s_best_run_start : t_tap_array := (others => (others => 0));

    type t_run_len_array is array (0 to 5, 0 to c_num_lanes-1) of integer range 0 to c_idelay_max_tap+1;
    signal s_run_len, s_best_run_len : t_run_len_array := (others => (others => 0));

    constant c_settle_cycles : integer := 64;  -- cfgbus_clk40 cycles to let the decoder re-lock after a tap change
    constant c_observe_cycles : integer := 64; -- cfgbus_clk40 cycles the lock must hold, unbroken, to count the tap as good
    type t_wait_counter_array is array (0 to 5, 0 to c_num_lanes-1) of integer range 0 to c_settle_cycles;
    signal s_wait_counter : t_wait_counter_array := (others => (others => 0));
    type t_observe_counter_array is array (0 to 5, 0 to c_num_lanes-1) of integer range 0 to c_observe_cycles;
    signal s_observe_counter : t_observe_counter_array := (others => (others => 0));

    type t_lane_bit_array is array (0 to 5, 0 to c_num_lanes-1) of std_logic;
    signal s_observe_ok : t_lane_bit_array := (others => (others => '1'));
    signal s_final_load : t_lane_bit_array := (others => (others => '0'));

    signal s_load_req : t_lane_bit_array := (others => (others => '0'));
    signal s_load_ack_sync0, s_load_ack_sync1 : t_lane_bit_array := (others => (others => '0'));
    signal s_load_req_sync0, s_load_req_sync1, s_load_req_sync1_prev : t_lane_bit_array := (others => (others => '0'));
    signal s_load_ack_fast : t_lane_bit_array := (others => (others => '0'));
    signal s_load_pulse_fast : t_lane_bit_array := (others => (others => '0'));

    type t_cntvaluein_array is array (0 to 5, 0 to c_num_lanes-1) of std_logic_vector(8 downto 0);
    signal s_cntvaluein, s_calibration_tap : t_cntvaluein_array := (others => (others => (others => '0')));

    signal s_en_vtc, s_lane_done, s_lane_failed : t_lane_bit_array := (others => (others => '0'));

    -- per-lane, per-channel "is this tap good right now": fc uses the decoder's own
    -- marker-based channel_locked; hg/lg compare the live decoded word against the
    -- known calibration pattern (see this file's header for why that's valid at the
    -- same time as fc's marker check, not a separate phase).
    signal s_lane_locked : t_lane_bit_array;

    signal s_calibration_done, s_calibration_failed : std_logic_vector(5 downto 0) := (others => '0');

begin

    p_calibration_done_out   <= s_calibration_done;
    p_calibration_failed_out <= s_calibration_failed;

    gen_channel: for v_adc in 0 to 5 generate

        s_lane_locked(v_adc, c_lane_fc) <= p_channel_locked_in(v_adc);
        s_lane_locked(v_adc, c_lane_hg) <= '1' when p_hg_data_in(v_adc) = p_expected_pattern_in else '0';
        s_lane_locked(v_adc, c_lane_lg) <= '1' when p_lg_data_in(v_adc) = p_expected_pattern_in else '0';

        s_calibration_done(v_adc)   <= s_lane_done(v_adc, c_lane_fc) and s_lane_done(v_adc, c_lane_hg) and s_lane_done(v_adc, c_lane_lg);
        s_calibration_failed(v_adc) <= s_lane_failed(v_adc, c_lane_fc) or s_lane_failed(v_adc, c_lane_hg) or s_lane_failed(v_adc, c_lane_lg);

        p_fc_idelay_count_out(v_adc)  <= s_cntvaluein(v_adc, c_lane_fc);
        p_lg_idelay_count_out(v_adc)  <= s_cntvaluein(v_adc, c_lane_lg);
        p_hg_idelay_count_out(v_adc)  <= s_cntvaluein(v_adc, c_lane_hg);
        p_fc_idelay_load_out(v_adc)   <= s_load_pulse_fast(v_adc, c_lane_fc);
        p_lg_idelay_load_out(v_adc)   <= s_load_pulse_fast(v_adc, c_lane_lg);
        p_hg_idelay_load_out(v_adc)   <= s_load_pulse_fast(v_adc, c_lane_hg);
        p_fc_idelay_en_vtc_out(v_adc) <= s_en_vtc(v_adc, c_lane_fc);
        p_lg_idelay_en_vtc_out(v_adc) <= s_en_vtc(v_adc, c_lane_lg);
        p_hg_idelay_en_vtc_out(v_adc) <= s_en_vtc(v_adc, c_lane_hg);

        p_calibration_tap_out(v_adc) <= s_calibration_tap(v_adc, c_lane_fc);

        gen_lane: for v_lane in 0 to c_num_lanes-1 generate

            -- fast (p_adc_bitclk_in(v_adc)) domain: 2-flop sync the request level, issue a
            -- single-cycle LOAD pulse on the transition, mirror the synced level back as the ack.
            proc_fast_domain : process(p_adc_bitclk_in(v_adc))
            begin
                if rising_edge(p_adc_bitclk_in(v_adc)) then
                    s_load_req_sync0(v_adc, v_lane) <= s_load_req(v_adc, v_lane);
                    s_load_req_sync1(v_adc, v_lane) <= s_load_req_sync0(v_adc, v_lane);
                    s_load_req_sync1_prev(v_adc, v_lane) <= s_load_req_sync1(v_adc, v_lane);

                    if s_load_req_sync1(v_adc, v_lane) /= s_load_req_sync1_prev(v_adc, v_lane) then
                        s_load_pulse_fast(v_adc, v_lane) <= '1';
                    else
                        s_load_pulse_fast(v_adc, v_lane) <= '0';
                    end if;

                    s_load_ack_fast(v_adc, v_lane) <= s_load_req_sync1(v_adc, v_lane);
                end if;
            end process;

            -- cfgbus_clk40 domain: sync the ack level back
            proc_ack_sync : process(p_clknet_in.cfgbus_clk40)
            begin
                if rising_edge(p_clknet_in.cfgbus_clk40) then
                    s_load_ack_sync0(v_adc, v_lane) <= s_load_ack_fast(v_adc, v_lane);
                    s_load_ack_sync1(v_adc, v_lane) <= s_load_ack_sync0(v_adc, v_lane);
                end if;
            end process;

            -- cfgbus_clk40 domain: tap sweep / lock-window search FSM, one independent
            -- copy per lane (v_lane: 0=fc, 1=hg, 2=lg -- see s_lane_locked above for
            -- what "locked" means for each). 2026-09-13: the only way back to
            -- st_idle from st_locked/st_failed used to be a full p_master_reset_in --
            -- once locked, a LATER ADC reconfiguration (e.g. enabling OUTTEST test
            -- pattern mode, which involves db6_adc_config_driver.vhd's st_reset_adc
            -- sending an actual reset command to the physical ADC chip) never
            -- re-triggers this sweep, even though the ADC's LVDS serializer
            -- restarting can shift its output word-boundary phase.
            -- p_clknet_in.adc_config.force_recalibrate (VIO button, see
            -- db6v5_top.vhd's probe_out10 bit 7) gives a lightweight way to force a
            -- fresh sweep without a disruptive full system reset -- routed through
            -- db6_mainboard_interface.vhd's proc_idelay_calibration_sequencer so a
            -- manual recalibration replays the same safe test-pattern-mode dance as
            -- boot, not just this FSM alone. p_clknet_in.adc_config.force_adc_readout_reset
            -- (the broader, all-scheme front-end reset) also forces a fresh sweep
            -- here, same as force_recalibrate alone did.
            proc_calibration_fsm : process(p_clknet_in.cfgbus_clk40, p_master_reset_in, p_clknet_in.adc_config.force_recalibrate, p_clknet_in.adc_config.force_adc_readout_reset)
            begin
                if p_master_reset_in = '1' or p_clknet_in.adc_config.force_recalibrate = '1' or p_clknet_in.adc_config.force_adc_readout_reset = '1' then
                    s_state(v_adc, v_lane) <= st_idle;
                    s_tap(v_adc, v_lane) <= 0;
                    s_run_len(v_adc, v_lane) <= 0;
                    s_best_run_len(v_adc, v_lane) <= 0;
                    s_load_req(v_adc, v_lane) <= '0';
                    s_final_load(v_adc, v_lane) <= '0';
                    s_en_vtc(v_adc, v_lane) <= '0';
                    s_lane_done(v_adc, v_lane) <= '0';
                    s_lane_failed(v_adc, v_lane) <= '0';
                elsif rising_edge(p_clknet_in.cfgbus_clk40) then

                    case s_state(v_adc, v_lane) is

                        when st_idle =>
                            if p_start_in = '1' then
                                s_tap(v_adc, v_lane) <= 0;
                                s_run_len(v_adc, v_lane) <= 0;
                                s_best_run_len(v_adc, v_lane) <= 0;
                                s_cntvaluein(v_adc, v_lane) <= std_logic_vector(to_unsigned(0, 9));
                                s_final_load(v_adc, v_lane) <= '0';
                                s_load_req(v_adc, v_lane) <= not s_load_req(v_adc, v_lane);
                                s_state(v_adc, v_lane) <= st_req_load;
                            end if;

                        when st_req_load =>
                            if s_load_ack_sync1(v_adc, v_lane) = s_load_req(v_adc, v_lane) then
                                if s_final_load(v_adc, v_lane) = '1' then
                                    s_state(v_adc, v_lane) <= st_locked;
                                else
                                    s_wait_counter(v_adc, v_lane) <= 0;
                                    s_state(v_adc, v_lane) <= st_wait_settle;
                                end if;
                            end if;

                        when st_wait_settle =>
                            if s_wait_counter(v_adc, v_lane) = c_settle_cycles then
                                s_observe_counter(v_adc, v_lane) <= 0;
                                s_observe_ok(v_adc, v_lane) <= '1';
                                s_state(v_adc, v_lane) <= st_observe;
                            else
                                s_wait_counter(v_adc, v_lane) <= s_wait_counter(v_adc, v_lane) + 1;
                            end if;

                        when st_observe =>
                            if s_lane_locked(v_adc, v_lane) = '0' then
                                s_observe_ok(v_adc, v_lane) <= '0';
                            end if;
                            if s_observe_counter(v_adc, v_lane) = c_observe_cycles then
                                if s_observe_ok(v_adc, v_lane) = '1' and s_lane_locked(v_adc, v_lane) = '1' then
                                    if s_run_len(v_adc, v_lane) = 0 then
                                        s_run_start(v_adc, v_lane) <= s_tap(v_adc, v_lane);
                                    end if;
                                    s_run_len(v_adc, v_lane) <= s_run_len(v_adc, v_lane) + 1;
                                    if s_run_len(v_adc, v_lane) + 1 > s_best_run_len(v_adc, v_lane) then
                                        s_best_run_len(v_adc, v_lane) <= s_run_len(v_adc, v_lane) + 1;
                                        s_best_run_start(v_adc, v_lane) <= s_run_start(v_adc, v_lane);
                                    end if;
                                else
                                    s_run_len(v_adc, v_lane) <= 0;
                                end if;
                                s_state(v_adc, v_lane) <= st_next_tap;
                            else
                                s_observe_counter(v_adc, v_lane) <= s_observe_counter(v_adc, v_lane) + 1;
                            end if;

                        when st_next_tap =>
                            if s_tap(v_adc, v_lane) = c_idelay_max_tap then
                                s_state(v_adc, v_lane) <= st_finish_load;
                            else
                                s_tap(v_adc, v_lane) <= s_tap(v_adc, v_lane) + 1;
                                s_cntvaluein(v_adc, v_lane) <= std_logic_vector(to_unsigned(s_tap(v_adc, v_lane) + 1, 9));
                                s_load_req(v_adc, v_lane) <= not s_load_req(v_adc, v_lane);
                                s_state(v_adc, v_lane) <= st_req_load;
                            end if;

                        when st_finish_load =>
                            if s_best_run_len(v_adc, v_lane) = 0 then
                                -- no tap ever held a clean lock for the full observe window: leave
                                -- idelay at 0 and flag it rather than silently picking a bad point.
                                s_lane_failed(v_adc, v_lane) <= '1';
                                s_state(v_adc, v_lane) <= st_failed;
                            else
                                s_calibration_tap(v_adc, v_lane) <= std_logic_vector(to_unsigned(s_best_run_start(v_adc, v_lane) + s_best_run_len(v_adc, v_lane)/2, 9));
                                s_cntvaluein(v_adc, v_lane) <= std_logic_vector(to_unsigned(s_best_run_start(v_adc, v_lane) + s_best_run_len(v_adc, v_lane)/2, 9));
                                s_final_load(v_adc, v_lane) <= '1';
                                s_load_req(v_adc, v_lane) <= not s_load_req(v_adc, v_lane);
                                s_state(v_adc, v_lane) <= st_req_load;
                            end if;

                        when st_locked =>
                            s_en_vtc(v_adc, v_lane) <= '1';
                            s_lane_done(v_adc, v_lane) <= '1';

                        when st_failed =>
                            null;

                        when others =>
                            null;

                    end case;

                end if;
            end process;

        end generate; -- gen_lane

    end generate; -- gen_channel

end behavioral;
