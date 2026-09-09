---------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.10.2022 00:26:50
-- Design Name: 
-- Module Name: db6_adc_interface_decoder_iddr - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

library tilecal;
use tilecal.db6_design_package.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity db6_adc_interface_decoder_iddr_bitclk280 is
    generic (
        g_tmr_enabled : std_logic := '1';
        g_adc_clocking_scheme : t_adc_clocking_scheme := iddr280
    );
    port (
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;

        --inputs
        p_adc_bitclk_in : in std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_in : in std_logic_vector(5 downto 0);
        p_adc_frameclk_in : in t_bitslice_sr;
--        p_frame_missalignment_in : in std_logic_vector(5 downto 0);
--        p_adc_gbtx_frameclk_in : in std_logic_vector(5 downto 0);
        p_adc_lg_data_in : in t_bitslice_sr;
        p_adc_hg_data_in : in t_bitslice_sr;
        -- per-channel pll_adc_channel lock, generated in db6_adc_interface_io_iddr_bitclk280
        -- (not here -- a PLL can't be triplicated; see that file's p_adc_pll0_locked_out)
        p_adc_pll0_locked_in : in std_logic_vector(5 downto 0) := (others => '0');

        --control
        p_adc_readout_control_in : in t_adc_readout_control;
        
        --output
        p_adc_readout_out       : out t_adc_readout;
        
        --debug
        p_leds_out      : out std_logic_vector(3 downto 0)
				);
end db6_adc_interface_decoder_iddr_bitclk280;

architecture Behavioral of db6_adc_interface_decoder_iddr_bitclk280 is

    signal s_adc_channel_fifo_fc, s_adc_channel_fifo_hg, s_adc_channel_fifo_lg : t_adc_channel_fifo; --t_adc_channel_fifo_cdc;--t_adc_channel_fifo;
    signal s_adc_input_fc_buffer, s_adc_input_fc_cdc_buffer, s_adc_input_lg_cdc_buffer, s_adc_input_lg_buffer, s_adc_input_hg_cdc_buffer, s_adc_input_hg_buffer : t_adc_data; --t_adc_oversample_data_type;--t_adc_data;

    -- p_adc_bitclk_in(v_adc) -> cfgbus_clk40 crossing (see proc_adc_cdc_lock below): a second
    -- copy of the deserialized word, pipelined for more p_adc_bitclk_in cycles than the "a" tap
    -- above so its cfgbus_clk40 sampling hazard window can never coincide with tap a's.
    signal s_adc_input_fc_cdc_buffer_b, s_adc_input_lg_cdc_buffer_b, s_adc_input_hg_cdc_buffer_b : t_adc_data;
    -- both taps registered into cfgbus_clk40 (the only place the cross-domain hazard exists;
    -- everything downstream of these is ordinary same-domain synchronous logic)
    signal s_tap_a_reg_fc, s_tap_a_reg_lg, s_tap_a_reg_hg : t_adc_data;
    signal s_tap_b_reg_fc, s_tap_b_reg_lg, s_tap_b_reg_hg : t_adc_data;
    -- '0' = tap a selected, '1' = tap b selected; locked once a tap reads a consistently
    -- valid fc frame marker, then held fixed (fixed latency, no per-word re-arbitration)
    signal s_cdc_tap_select, s_cdc_tap_locked : std_logic_vector(5 downto 0) := (others => '0');
    type t_cdc_lock_counter is array (0 to 5) of integer range 0 to 15;
    signal s_cdc_lock_counter : t_cdc_lock_counter := (others => 0);

    -- iddr280_clkdiv only: BCR-referenced calibration of the tap-select decision, running
    -- in the p_adc_bitclkdiv_in(v_adc) domain (see gen_tap_select_iddr280_clkdiv below,
    -- mirrors db6_clock_interface.vhd's proc_cdc_gen)
    signal s_bcr_sync0, s_bcr_sync1 : std_logic_vector(5 downto 0) := (others => '0');
    signal s_bclkdiv_tap_a_fc, s_bclkdiv_tap_b_fc : t_adc_data;
    signal s_bclkdiv_tap_select, s_bclkdiv_tap_locked : std_logic_vector(5 downto 0) := (others => '0');
    -- single bit, safe regardless of relative clock rate: select/locked crossed from
    -- p_adc_bitclkdiv_in into cfgbus_clk40 via an ordinary double-flop synchronizer
    signal s_tap_select_sync0, s_tap_select_sync1 : std_logic_vector(5 downto 0) := (others => '0');
    signal s_tap_locked_sync0, s_tap_locked_sync1 : std_logic_vector(5 downto 0) := (others => '0');
    signal s_channel_frame_missalignemt, s_channel_frame_missalignemt_reg, s_channel_frame_missalignemt_buffer_lg, s_channel_frame_missalignemt_buffer_hg , s_channel_frame_missalignemt_buffer_delayed, s_channel_frame_missalignemt_reset : std_logic_vector (5 downto 0) := (others => '1');
    signal s_channel_phase, s_channel_locked,s_channel_missed_locked, s_channel_missed_bit_count : std_logic_vector(5 downto 0);
    type t_cdc_transition is array (0 to 5) of std_logic;
    signal s_cdc_transition : t_cdc_transition := (others=> '0');
    type t_counter_array is array (0 to 5) of integer range 0 to 31;
    type t_counter_std_logic_vector_array is array (0 to 5) of std_logic_vector(3 downto 0);
    signal s_counter_array_debug, s_counter_cdc_array_debug, s_counter_cdc_align_array_debug : t_counter_std_logic_vector_array;
    
    signal s_adc_lg_data_sr, s_adc_hg_data_sr, s_adc_fc_data_sr : t_bitslice_sr;
    
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
            channel_clk280_stopped => (others=>'0'),
            channel_valid_fc_frame_counter => (others =>(others=>'0')),
            channel_invalid_fc_frame_counter => (others =>(others=>'0')),
            channel_valid_divclk_frame_counter => (others =>(others=>'0')),
            --channel_valid_lg_frame_counter => (others =>(others=>'0')),
            channel_invalid_lg_frame_counter => (others =>(others=>'0')),
            --channel_valid_hg_frame_counter => (others =>(others=>'0')),
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
    
    type t_channel_counter_integer is array (0 to 5) of integer;
    signal s_channel_valid_fc_frame_counter, s_channel_invalid_fc_frame_counter, s_channel_initial_difference_counter, s_channel_difference_counter, s_channel_local_counter : t_channel_counter_integer;

    signal s_invalid_frame_flag, s_first_frame_counted, s_first_count_aligned, s_first_state_achieved  : std_logic_vector(5 downto 0) := (others => '0' );
    
    type t_sync_bitclkdiv_state is array (0 to 5) of integer range 0 to 14;
    signal s_sync_bitclkdiv_state_lg, s_sync_bitclkdiv_state_hg: t_sync_bitclkdiv_state;
    type t_counter_sm is array (0 to 5) of integer range 0 to 14;
    signal s_counter_sm : t_counter_sm :=(others=>0);
    signal s_cdc_reset_in, s_cdc_reset_out : std_logic_vector(5 downto 0);
    signal s_calculated : std_logic_vector(5 downto 0);
    constant c_pipeline_depth : integer := 7;--c_global_pipeline_depth;
    -- tap b: offset from tap a by 4 p_adc_bitclk_in cycles (~14.3ns of a ~25ns word period,
    -- i.e. more than half a period) -- see proc_adc_cdc_lock
    constant c_pipeline_depth_b : integer := c_pipeline_depth + 4;

--debug
COMPONENT vio_adc_readout_cdc
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
    probe_in6 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in15 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in16 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in17 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END COMPONENT;
    
begin

p_adc_readout_out <= s_adc_readout;

gen_adc_channels: for v_adc in 0 to 5 generate


    s_adc_readout.channel_clk280_locked(v_adc) <= p_adc_pll0_locked_in(v_adc);

    
    
        proc_mon : process(p_clknet_in.cfgbus_clk40, s_cdc_reset_in(v_adc)) -- odd data bits clocked in on rising edge of adc clocks
        type t_mon_sm is (st_start, st_calculate, st_monitor);
        variable v_mon_st : t_mon_sm :=st_start;
        begin
        
            if s_cdc_reset_in(v_adc) = '1' then
                s_channel_valid_fc_frame_counter(v_adc)<= 0;
                s_channel_invalid_fc_frame_counter(v_adc)<= 0;
                s_channel_local_counter(v_adc)<=0;
                s_channel_locked(v_adc)<= '0';
                s_channel_missed_locked(v_adc)<= '0';
                s_channel_missed_bit_count(v_adc)<='0';
                v_mon_st:=st_start;
            elsif rising_edge(p_clknet_in.cfgbus_clk40) then
            
                if to_integer(unsigned(s_adc_readout.hg_data(v_adc)))>to_integer(unsigned(p_clknet_in.adc_readout_high_threshold)) then
                    s_adc_readout.channel_pedestal_test_overflow(v_adc)<='1';
                else
                    s_adc_readout.channel_pedestal_test_overflow(v_adc)<='0';
                end if;
                if to_integer(unsigned(s_adc_readout.hg_data(v_adc)))<to_integer(unsigned(p_clknet_in.adc_readout_low_threshold)) then
                    s_adc_readout.channel_pedestal_test_underflow(v_adc)<='1';
                else
                    s_adc_readout.channel_pedestal_test_underflow(v_adc)<='0';
                end if;

            
                case v_mon_st is
                    when st_start=>
                        if s_adc_readout.fc_data(v_adc) = "11111110000000" then
                            s_channel_local_counter(v_adc)<=s_channel_local_counter(v_adc)+1;
                            s_channel_valid_fc_frame_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '1';
                            v_mon_st:=st_calculate;
                        else
                            s_channel_locked(v_adc)<= '0';
                            s_channel_valid_fc_frame_counter(v_adc)<= 0;
                            s_channel_invalid_fc_frame_counter(v_adc)<= 0;
                            s_channel_local_counter(v_adc)<=0;
                        end if;
    
                    when st_calculate=>
                        if s_calculated(v_adc) = '0' then
                            s_channel_initial_difference_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc) - s_channel_local_counter(v_adc);
                        end if;
                        s_channel_local_counter(v_adc)<=s_channel_local_counter(v_adc)+1;
                        if s_adc_readout.fc_data(v_adc) = "11111110000000" then
                            s_channel_valid_fc_frame_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '1';
                            v_mon_st:=st_monitor;
                            s_calculated(v_adc) <= '1';
                        else
                            s_channel_invalid_fc_frame_counter(v_adc)<=s_channel_invalid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '0';
                        end if;
                        
                    when st_monitor=>
                        s_channel_difference_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc) - s_channel_local_counter(v_adc);
                        s_channel_local_counter(v_adc)<=s_channel_local_counter(v_adc)+1;
                        
                        if (s_channel_difference_counter(v_adc) = s_channel_initial_difference_counter(v_adc)) then
                        else
                            s_channel_missed_bit_count(v_adc)<='1';
                        end if;
                        
                        if s_adc_readout.fc_data(v_adc) = "11111110000000" then
                            s_channel_valid_fc_frame_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '1';
                        else
                            s_channel_invalid_fc_frame_counter(v_adc)<=s_channel_invalid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '0';
                            s_channel_missed_locked(v_adc) <= '1';
                        end if;                
                    when others=>
                        v_mon_st:=st_start;
                end case;
            end if;
            
        end process;

        -- p_adc_bitclk_in(v_adc) -> cfgbus_clk40 crossing: the two clocks are the same nominal
        -- frequency but come from independent PLLs with an unknown, fixed (not drifting) phase
        -- offset. A plain single-register sample of the 14-bit word (as this used to be) can
        -- land on the ~25ns word-update boundary and capture a bit-incoherent mix of the old
        -- and new word -- and since the phase offset is fixed, it does that on *every* sample,
        -- not just rarely, until the next power-up happens to land on a different offset.
        --
        -- Fix: register both the tap-a and tap-b copies of the word into cfgbus_clk40 (each
        -- individually still has that same hazard -- this is the only step where it exists),
        -- then use fc_data's known-constant "11111110000000" frame marker as a self-checking
        -- canary on the *already-registered* values: a torn sample won't match it, and tap b's
        -- hazard window (offset ~14ns from tap a's, more than half the ~25ns period) can never
        -- coincide with tap a's. Lock onto whichever tap first reads consistently valid and
        -- hold that choice -- fixed pipeline latency for the life of the lock, no per-word
        -- re-arbitration, no FIFO. Loss of lock on the selected tap is reported (channel_locked
        -- below) rather than silently swapping taps mid-stream.
        -- common to both schemes: register both taps into cfgbus_clk40 (the only place the
        -- raw p_adc_bitclk_in(v_adc) -> cfgbus_clk40 hazard exists for the data itself)
        proc_adc_tap_registers : process(p_clknet_in.cfgbus_clk40)
        begin
            if rising_edge(p_clknet_in.cfgbus_clk40) then
                s_tap_a_reg_fc(v_adc) <= s_adc_input_fc_cdc_buffer(v_adc);
                s_tap_a_reg_lg(v_adc) <= s_adc_input_lg_cdc_buffer(v_adc);
                s_tap_a_reg_hg(v_adc) <= s_adc_input_hg_cdc_buffer(v_adc);
                s_tap_b_reg_fc(v_adc) <= s_adc_input_fc_cdc_buffer_b(v_adc);
                s_tap_b_reg_lg(v_adc) <= s_adc_input_lg_cdc_buffer_b(v_adc);
                s_tap_b_reg_hg(v_adc) <= s_adc_input_hg_cdc_buffer_b(v_adc);
            end if;
        end process;

        -- iddr280: free-running canary lock straight in cfgbus_clk40 (see the header comment
        -- above proc_adc_tap_registers for the reasoning). Locks within 16 valid words of reset.
        gen_tap_select_iddr280 : if g_adc_clocking_scheme = iddr280 generate
            proc_adc_cdc_lock : process(p_clknet_in.cfgbus_clk40, s_cdc_reset_in(v_adc))
            begin
                if s_cdc_reset_in(v_adc) = '1' then
                    s_cdc_tap_select(v_adc) <= '0';
                    s_cdc_tap_locked(v_adc) <= '0';
                    s_cdc_lock_counter(v_adc) <= 0;
                elsif rising_edge(p_clknet_in.cfgbus_clk40) then
                    if s_cdc_tap_locked(v_adc) = '0' then
                        if s_tap_a_reg_fc(v_adc) = "11111110000000" then
                            if s_cdc_lock_counter(v_adc) = 15 then
                                s_cdc_tap_select(v_adc) <= '0';
                                s_cdc_tap_locked(v_adc) <= '1';
                            else
                                s_cdc_lock_counter(v_adc) <= s_cdc_lock_counter(v_adc) + 1;
                            end if;
                        elsif s_tap_b_reg_fc(v_adc) = "11111110000000" then
                            if s_cdc_lock_counter(v_adc) = 15 then
                                s_cdc_tap_select(v_adc) <= '1';
                                s_cdc_tap_locked(v_adc) <= '1';
                            else
                                s_cdc_lock_counter(v_adc) <= s_cdc_lock_counter(v_adc) + 1;
                            end if;
                        else
                            s_cdc_lock_counter(v_adc) <= 0;
                        end if;
                    else
                        -- locked: keep the selected tap; flag loss rather than swapping mid-stream
                        if ((s_cdc_tap_select(v_adc) = '0' and s_tap_a_reg_fc(v_adc) /= "11111110000000") or
                            (s_cdc_tap_select(v_adc) = '1' and s_tap_b_reg_fc(v_adc) /= "11111110000000")) then
                            s_cdc_tap_locked(v_adc) <= '0';
                            s_cdc_lock_counter(v_adc) <= 0;
                        end if;
                    end if;
                end if;
            end process;
        end generate;

        -- iddr280_clkdiv: same dual-tap canary data path, but the tap-select decision is
        -- calibrated in the p_adc_bitclkdiv_in(v_adc) domain (a true divided sibling of
        -- p_adc_bitclk_in via BUFGCE_DIV, close to the IOs -- see
        -- db6_adc_interface_io_iddr_bitclk280.vhd -- so registering bitclk280-domain signals
        -- here is an ordinary, STA-checked related-clock path, not a blind CDC) and
        -- re-evaluated only on the cycle after a BCR edge -- tying recalibration cadence to
        -- the actual accelerator orbit clock, mirroring db6_clock_interface.vhd's
        -- proc_cdc_gen -- rather than a free-running counter. Only the resulting single-bit
        -- select/locked decision then needs to cross into cfgbus_clk40, which an ordinary
        -- double-flop synchronizer handles safely regardless of relative clock rate (unlike
        -- the multi-bit word itself). Trade-off: since bcr only pulses once per orbit,
        -- initial lock after reset can take up to one orbit, versus ~16 words for iddr280.
        gen_tap_select_iddr280_clkdiv : if g_adc_clocking_scheme = iddr280_clkdiv generate

            proc_bclkdiv_tap_registers : process(p_adc_bitclkdiv_in(v_adc))
            begin
                if rising_edge(p_adc_bitclkdiv_in(v_adc)) then
                    s_bclkdiv_tap_a_fc(v_adc) <= s_adc_input_fc_cdc_buffer(v_adc);
                    s_bclkdiv_tap_b_fc(v_adc) <= s_adc_input_fc_cdc_buffer_b(v_adc);
                    s_bcr_sync0(v_adc) <= p_clknet_in.bcr.bcr;
                    s_bcr_sync1(v_adc) <= s_bcr_sync0(v_adc);
                end if;
            end process;

            proc_bclkdiv_cdc_lock : process(p_adc_bitclkdiv_in(v_adc), s_cdc_reset_in(v_adc))
            begin
                if s_cdc_reset_in(v_adc) = '1' then
                    s_bclkdiv_tap_select(v_adc) <= '0';
                    s_bclkdiv_tap_locked(v_adc) <= '0';
                elsif rising_edge(p_adc_bitclkdiv_in(v_adc)) then
                    if s_bcr_sync1(v_adc) = '0' and s_bcr_sync0(v_adc) = '1' then -- synchronized bcr rising edge
                        if s_bclkdiv_tap_locked(v_adc) = '0' then
                            if s_bclkdiv_tap_a_fc(v_adc) = "11111110000000" then
                                s_bclkdiv_tap_select(v_adc) <= '0';
                                s_bclkdiv_tap_locked(v_adc) <= '1';
                            elsif s_bclkdiv_tap_b_fc(v_adc) = "11111110000000" then
                                s_bclkdiv_tap_select(v_adc) <= '1';
                                s_bclkdiv_tap_locked(v_adc) <= '1';
                            end if;
                        else
                            -- locked: keep the selected tap; flag loss rather than swapping mid-stream
                            if ((s_bclkdiv_tap_select(v_adc) = '0' and s_bclkdiv_tap_a_fc(v_adc) /= "11111110000000") or
                                (s_bclkdiv_tap_select(v_adc) = '1' and s_bclkdiv_tap_b_fc(v_adc) /= "11111110000000")) then
                                s_bclkdiv_tap_locked(v_adc) <= '0';
                            end if;
                        end if;
                    end if;
                end if;
            end process;

            proc_tap_select_sync : process(p_clknet_in.cfgbus_clk40)
            begin
                if rising_edge(p_clknet_in.cfgbus_clk40) then
                    s_tap_select_sync0(v_adc) <= s_bclkdiv_tap_select(v_adc);
                    s_tap_select_sync1(v_adc) <= s_tap_select_sync0(v_adc);
                    s_tap_locked_sync0(v_adc) <= s_bclkdiv_tap_locked(v_adc);
                    s_tap_locked_sync1(v_adc) <= s_tap_locked_sync0(v_adc);
                end if;
            end process;

            s_cdc_tap_select(v_adc) <= s_tap_select_sync1(v_adc);
            s_cdc_tap_locked(v_adc) <= s_tap_locked_sync1(v_adc);

        end generate;

        s_adc_readout.fc_data(v_adc) <= s_tap_b_reg_fc(v_adc) when s_cdc_tap_select(v_adc) = '1' else s_tap_a_reg_fc(v_adc);
        s_adc_readout.lg_data(v_adc) <= s_tap_b_reg_lg(v_adc) when s_cdc_tap_select(v_adc) = '1' else s_tap_a_reg_lg(v_adc);
        s_adc_readout.hg_data(v_adc) <= s_tap_b_reg_hg(v_adc) when s_cdc_tap_select(v_adc) = '1' else s_tap_a_reg_hg(v_adc);

        s_cdc_reset_in(v_adc)<= (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_5_bit-v_adc)) or
                          (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)) or
                          (p_master_reset_in) or
                          (not p_clknet_in.mb_fpga_reset_low.q0) or
                          (not p_clknet_in.mb_fpga_reset_low.q1) or
                          (not p_adc_readout_control_in.adc_config_done);
                    

        s_adc_readout.channel_invalid_fc_frame_counter(v_adc) <= std_logic_vector(to_unsigned(s_channel_valid_fc_frame_counter(v_adc), c_adc_counters_depth));
        s_adc_readout.channel_valid_fc_frame_counter(v_adc) <= std_logic_vector(to_unsigned(s_channel_invalid_fc_frame_counter(v_adc), c_adc_counters_depth));
        
        s_adc_readout.channel_locked(v_adc)<=s_channel_locked(v_adc);
        s_adc_readout.channel_missed_locked(v_adc)<=s_channel_missed_locked(v_adc);
        s_adc_readout.channel_missed_bit_count(v_adc)<=s_channel_missed_bit_count(v_adc);
        
--        s_adc_readout.channel_frame_missalignemt(v_adc) <= s_channel_frame_missalignemt_reg(v_adc);


        i_adc_data_lg_pipeline : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_lg(v_adc).dout,
                       p_pipeline_out => s_adc_input_lg_cdc_buffer(v_adc));--s_adc_readout.lg_data(v_adc));
        i_adc_data_hg_pipeline : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_hg(v_adc).dout,
                       p_pipeline_out => s_adc_input_hg_cdc_buffer(v_adc));--s_adc_readout.hg_data(v_adc));
        i_adc_data_fc_pipeline : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_fc(v_adc).dout,
                       p_pipeline_out => s_adc_input_fc_cdc_buffer(v_adc));--s_adc_readout.fc_data(v_adc));

        -- tap b for proc_adc_cdc_lock (see above): same source, offset pipeline depth
        i_adc_data_lg_pipeline_b : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth_b,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_lg(v_adc).dout,
                       p_pipeline_out => s_adc_input_lg_cdc_buffer_b(v_adc));
        i_adc_data_hg_pipeline_b : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth_b,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_hg(v_adc).dout,
                       p_pipeline_out => s_adc_input_hg_cdc_buffer_b(v_adc));
        i_adc_data_fc_pipeline_b : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth_b,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_fc(v_adc).dout,
                       p_pipeline_out => s_adc_input_fc_cdc_buffer_b(v_adc));


        s_adc_channel_fifo_fc(v_adc).dout <= s_adc_channel_fifo_fc(v_adc).din;
        s_adc_channel_fifo_lg(v_adc).dout <= s_adc_channel_fifo_lg(v_adc).din;
        s_adc_channel_fifo_hg(v_adc).dout <= s_adc_channel_fifo_hg(v_adc).din;


        proc_shift_lg_in : process(p_adc_bitclk_in(v_adc), s_cdc_reset_in(v_adc)) -- odd data bits clocked in on rising edge of adc clocks 
        begin
        
            if s_cdc_reset_in(v_adc) = '1' then
                s_sync_bitclkdiv_state_lg(v_adc) <= 0;
            elsif rising_edge(p_adc_bitclk_in(v_adc)) then
                case s_sync_bitclkdiv_state_lg(v_adc) is

                    when 0 =>
                            s_adc_channel_fifo_lg(v_adc).din<=(others=>'1');
                            s_adc_channel_fifo_hg(v_adc).din<=(others=>'1');
                            s_adc_channel_fifo_fc(v_adc).din<=(others=>'1');
                            
                        if ((p_adc_frameclk_in(v_adc)= "11")) then -- and (s_adc_fc_data_sr(v_adc)="00")) then
                            s_sync_bitclkdiv_state_lg(v_adc)<=2;
                            s_adc_input_lg_buffer(v_adc)(13 downto 12) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(13 downto 12) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(13 downto 12) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                            
                            
                        end if;

                    when 1 =>

                        s_adc_channel_fifo_lg(v_adc).din<=s_adc_input_lg_buffer(v_adc);
                        s_adc_channel_fifo_hg(v_adc).din<=s_adc_input_hg_buffer(v_adc);
                        s_adc_channel_fifo_fc(v_adc).din<=s_adc_input_fc_buffer(v_adc);

                        if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=2;
                            s_adc_input_lg_buffer(v_adc)(13 downto 12) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(13 downto 12) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(13 downto 12) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;

                    when 2 =>
                        s_first_state_achieved(v_adc)<='1';
                        if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=3;
                            s_adc_input_lg_buffer(v_adc)(11 downto 10) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(11 downto 10) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(11 downto 10) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;
                    when 3 =>
                        if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=4;
                            s_adc_input_lg_buffer(v_adc)(9 downto 8) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(9 downto 8) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(9 downto 8) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                         else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;                       
                    when 4 =>
                        if (p_adc_frameclk_in(v_adc)= "01") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=5;
                            s_adc_input_lg_buffer(v_adc)(7 downto 6) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(7 downto 6) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(7 downto 6) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;   
                    when 5 =>
                        if (p_adc_frameclk_in(v_adc)= "00") then
                            s_invalid_frame_flag(v_adc)<='0';
                            s_sync_bitclkdiv_state_lg(v_adc)<=6;
                            s_adc_input_lg_buffer(v_adc)(5 downto 4) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(5 downto 4) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(5 downto 4) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;       
                    when 6 =>
                        if ((p_adc_frameclk_in(v_adc)= "00")) then
                            s_sync_bitclkdiv_state_lg(v_adc)<=7;
                            s_adc_input_lg_buffer(v_adc)(3 downto 2) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(3 downto 2) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(3 downto 2) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if; 
                    when 7 =>
                        s_channel_phase(v_adc)<='0';
                        if ((p_adc_frameclk_in(v_adc)= "00")) then
                            s_sync_bitclkdiv_state_lg(v_adc)<=1;
                            s_adc_input_lg_buffer(v_adc)(1 downto 0) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(1 downto 0) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(1 downto 0) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;

                    when others =>
                        s_sync_bitclkdiv_state_lg(v_adc)<=0;
                end case;
            end if;
        end process;



    
end generate;

end behavioral;
