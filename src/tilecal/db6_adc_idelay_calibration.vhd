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
-- range: the most timing-margin-robust single sample point. lg/hg share the same
-- calibrated tap as fc per channel (same ADC chip, matched trace lengths, no
-- independent known pattern to calibrate them against separately). Once locked, the
-- tap is never touched again -- fixed latency, no elastic buffering, same
-- requirement as every other fix this session.
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
-- crossing fixed this session.
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

        p_start_in          : in  std_logic;                   -- e.g. adc_config_done
        p_channel_locked_in : in  std_logic_vector(5 downto 0); -- decoder's channel_locked (cfgbus_clk40 domain)

        p_fc_idelay_count_out  : out t_idelay_count;
        p_fc_idelay_load_out   : out std_logic_vector(5 downto 0);
        p_fc_idelay_en_vtc_out : out std_logic_vector(5 downto 0);
        p_lg_idelay_count_out  : out t_idelay_count;
        p_lg_idelay_load_out   : out std_logic_vector(5 downto 0);
        p_lg_idelay_en_vtc_out : out std_logic_vector(5 downto 0);
        p_hg_idelay_count_out  : out t_idelay_count;
        p_hg_idelay_load_out   : out std_logic_vector(5 downto 0);
        p_hg_idelay_en_vtc_out : out std_logic_vector(5 downto 0);

        p_calibration_done_out   : out std_logic_vector(5 downto 0);
        p_calibration_failed_out : out std_logic_vector(5 downto 0);
        p_calibration_tap_out    : out t_idelay_count -- debug: final chosen tap per channel
    );
end db6_adc_idelay_calibration;

architecture behavioral of db6_adc_idelay_calibration is

    constant c_idelay_max_tap : integer := 31; -- IDELAYE3, UltraScale+, single element (no cascade): 32 taps, 0-31

    type t_cal_state is (st_idle, st_req_load, st_wait_settle, st_observe, st_next_tap, st_finish_load, st_locked, st_failed);
    type t_cal_state_array is array (0 to 5) of t_cal_state;
    signal s_state : t_cal_state_array := (others => st_idle);

    type t_tap_array is array (0 to 5) of integer range 0 to c_idelay_max_tap;
    signal s_tap : t_tap_array := (others => 0);

    -- best contiguous all-locked tap run seen so far, and the run currently being tracked
    signal s_run_start, s_best_run_start : t_tap_array := (others => 0);
    type t_run_len_array is array (0 to 5) of integer range 0 to c_idelay_max_tap+1;
    signal s_run_len, s_best_run_len : t_run_len_array := (others => 0);

    constant c_settle_cycles : integer := 64;  -- cfgbus_clk40 cycles to let the decoder re-lock after a tap change
    constant c_observe_cycles : integer := 64; -- cfgbus_clk40 cycles the lock must hold, unbroken, to count the tap as good
    type t_wait_counter_array is array (0 to 5) of integer range 0 to c_settle_cycles;
    signal s_wait_counter : t_wait_counter_array := (others => 0);
    type t_observe_counter_array is array (0 to 5) of integer range 0 to c_observe_cycles;
    signal s_observe_counter : t_observe_counter_array := (others => 0);
    signal s_observe_ok : std_logic_vector(5 downto 0) := (others => '1');

    signal s_final_load : std_logic_vector(5 downto 0) := (others => '0');

    signal s_load_req : std_logic_vector(5 downto 0) := (others => '0');
    signal s_load_ack_sync0, s_load_ack_sync1 : std_logic_vector(5 downto 0) := (others => '0');
    signal s_load_req_sync0, s_load_req_sync1, s_load_req_sync1_prev : std_logic_vector(5 downto 0) := (others => '0');
    signal s_load_ack_fast : std_logic_vector(5 downto 0) := (others => '0');
    signal s_load_pulse_fast : std_logic_vector(5 downto 0) := (others => '0');

    signal s_cntvaluein : t_idelay_count := (others => (others => '0'));

    signal s_en_vtc : std_logic_vector(5 downto 0) := (others => '0');
    signal s_calibration_done, s_calibration_failed : std_logic_vector(5 downto 0) := (others => '0');
    signal s_calibration_tap : t_idelay_count := (others => (others => '0'));

begin

    p_fc_idelay_count_out <= s_cntvaluein;
    p_lg_idelay_count_out <= s_cntvaluein;
    p_hg_idelay_count_out <= s_cntvaluein;
    p_fc_idelay_load_out  <= s_load_pulse_fast;
    p_lg_idelay_load_out  <= s_load_pulse_fast;
    p_hg_idelay_load_out  <= s_load_pulse_fast;
    p_fc_idelay_en_vtc_out <= s_en_vtc;
    p_lg_idelay_en_vtc_out <= s_en_vtc;
    p_hg_idelay_en_vtc_out <= s_en_vtc;

    p_calibration_done_out   <= s_calibration_done;
    p_calibration_failed_out <= s_calibration_failed;
    p_calibration_tap_out    <= s_calibration_tap;

    gen_channel: for v_adc in 0 to 5 generate

        -- fast (p_adc_bitclk_in(v_adc)) domain: 2-flop sync the request level, issue a
        -- single-cycle LOAD pulse on the transition, mirror the synced level back as the ack.
        proc_fast_domain : process(p_adc_bitclk_in(v_adc))
        begin
            if rising_edge(p_adc_bitclk_in(v_adc)) then
                s_load_req_sync0(v_adc) <= s_load_req(v_adc);
                s_load_req_sync1(v_adc) <= s_load_req_sync0(v_adc);
                s_load_req_sync1_prev(v_adc) <= s_load_req_sync1(v_adc);

                if s_load_req_sync1(v_adc) /= s_load_req_sync1_prev(v_adc) then
                    s_load_pulse_fast(v_adc) <= '1';
                else
                    s_load_pulse_fast(v_adc) <= '0';
                end if;

                s_load_ack_fast(v_adc) <= s_load_req_sync1(v_adc);
            end if;
        end process;

        -- cfgbus_clk40 domain: sync the ack level back
        proc_ack_sync : process(p_clknet_in.cfgbus_clk40)
        begin
            if rising_edge(p_clknet_in.cfgbus_clk40) then
                s_load_ack_sync0(v_adc) <= s_load_ack_fast(v_adc);
                s_load_ack_sync1(v_adc) <= s_load_ack_sync0(v_adc);
            end if;
        end process;

        -- cfgbus_clk40 domain: tap sweep / lock-window search FSM. 2026-09-13: the only
        -- way back to st_idle from st_locked/st_failed used to be a full
        -- p_master_reset_in -- once locked, a LATER ADC reconfiguration (e.g. enabling
        -- OUTTEST test pattern mode, which involves db6_adc_config_driver.vhd's
        -- st_reset_adc sending an actual reset command to the physical ADC chip) never
        -- re-triggers this sweep, even though the ADC's LVDS serializer restarting can
        -- shift its output word-boundary phase. p_clknet_in.adc_config.force_recalibrate
        -- (new VIO button, see db6v5_top.vhd's probe_out10 bit 7) gives a lightweight
        -- way to force a fresh sweep without a disruptive full system reset.
        -- 2026-09-13: p_clknet_in.adc_config.force_adc_readout_reset (the broader,
        -- all-scheme front-end reset -- see its header comment) also forces a fresh
        -- sweep here, same as force_recalibrate alone did, so pulsing that one button
        -- covers both the front-end capture logic and this calibration engine.
        proc_calibration_fsm : process(p_clknet_in.cfgbus_clk40, p_master_reset_in, p_clknet_in.adc_config.force_recalibrate, p_clknet_in.adc_config.force_adc_readout_reset)
        begin
            if p_master_reset_in = '1' or p_clknet_in.adc_config.force_recalibrate = '1' or p_clknet_in.adc_config.force_adc_readout_reset = '1' then
                s_state(v_adc) <= st_idle;
                s_tap(v_adc) <= 0;
                s_run_len(v_adc) <= 0;
                s_best_run_len(v_adc) <= 0;
                s_load_req(v_adc) <= '0';
                s_final_load(v_adc) <= '0';
                s_en_vtc(v_adc) <= '0';
                s_calibration_done(v_adc) <= '0';
                s_calibration_failed(v_adc) <= '0';
            elsif rising_edge(p_clknet_in.cfgbus_clk40) then

                case s_state(v_adc) is

                    when st_idle =>
                        if p_start_in = '1' then
                            s_tap(v_adc) <= 0;
                            s_run_len(v_adc) <= 0;
                            s_best_run_len(v_adc) <= 0;
                            s_cntvaluein(v_adc) <= std_logic_vector(to_unsigned(0, 9));
                            s_final_load(v_adc) <= '0';
                            s_load_req(v_adc) <= not s_load_req(v_adc);
                            s_state(v_adc) <= st_req_load;
                        end if;

                    when st_req_load =>
                        if s_load_ack_sync1(v_adc) = s_load_req(v_adc) then
                            if s_final_load(v_adc) = '1' then
                                s_state(v_adc) <= st_locked;
                            else
                                s_wait_counter(v_adc) <= 0;
                                s_state(v_adc) <= st_wait_settle;
                            end if;
                        end if;

                    when st_wait_settle =>
                        if s_wait_counter(v_adc) = c_settle_cycles then
                            s_observe_counter(v_adc) <= 0;
                            s_observe_ok(v_adc) <= '1';
                            s_state(v_adc) <= st_observe;
                        else
                            s_wait_counter(v_adc) <= s_wait_counter(v_adc) + 1;
                        end if;

                    when st_observe =>
                        if p_channel_locked_in(v_adc) = '0' then
                            s_observe_ok(v_adc) <= '0';
                        end if;
                        if s_observe_counter(v_adc) = c_observe_cycles then
                            if s_observe_ok(v_adc) = '1' and p_channel_locked_in(v_adc) = '1' then
                                if s_run_len(v_adc) = 0 then
                                    s_run_start(v_adc) <= s_tap(v_adc);
                                end if;
                                s_run_len(v_adc) <= s_run_len(v_adc) + 1;
                                if s_run_len(v_adc) + 1 > s_best_run_len(v_adc) then
                                    s_best_run_len(v_adc) <= s_run_len(v_adc) + 1;
                                    s_best_run_start(v_adc) <= s_run_start(v_adc);
                                end if;
                            else
                                s_run_len(v_adc) <= 0;
                            end if;
                            s_state(v_adc) <= st_next_tap;
                        else
                            s_observe_counter(v_adc) <= s_observe_counter(v_adc) + 1;
                        end if;

                    when st_next_tap =>
                        if s_tap(v_adc) = c_idelay_max_tap then
                            s_state(v_adc) <= st_finish_load;
                        else
                            s_tap(v_adc) <= s_tap(v_adc) + 1;
                            s_cntvaluein(v_adc) <= std_logic_vector(to_unsigned(s_tap(v_adc) + 1, 9));
                            s_load_req(v_adc) <= not s_load_req(v_adc);
                            s_state(v_adc) <= st_req_load;
                        end if;

                    when st_finish_load =>
                        if s_best_run_len(v_adc) = 0 then
                            -- no tap ever held a clean lock for the full observe window: leave
                            -- idelay at 0 and flag it rather than silently picking a bad point.
                            s_calibration_failed(v_adc) <= '1';
                            s_state(v_adc) <= st_failed;
                        else
                            s_calibration_tap(v_adc) <= std_logic_vector(to_unsigned(s_best_run_start(v_adc) + s_best_run_len(v_adc)/2, 9));
                            s_cntvaluein(v_adc) <= std_logic_vector(to_unsigned(s_best_run_start(v_adc) + s_best_run_len(v_adc)/2, 9));
                            s_final_load(v_adc) <= '1';
                            s_load_req(v_adc) <= not s_load_req(v_adc);
                            s_state(v_adc) <= st_req_load;
                        end if;

                    when st_locked =>
                        s_en_vtc(v_adc) <= '1';
                        s_calibration_done(v_adc) <= '1';

                    when st_failed =>
                        null;

                    when others =>
                        null;

                end case;

            end if;
        end process;

    end generate;

end behavioral;
