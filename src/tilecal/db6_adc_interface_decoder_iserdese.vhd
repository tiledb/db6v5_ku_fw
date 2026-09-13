----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.03.2023 17:08:33
-- Design Name: 
-- Module Name: db6_adc_interface_decoder_iserdese - Behavioral
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

entity db6_adc_interface_decoder_iserdese is
generic (
        g_tmr_enabled : std_logic := '1'
    );
  Port ( 
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;
        
        --inputs
        p_adc_bitclk_in : in std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_in : in std_logic_vector(5 downto 0);
        p_adc_frameclk_in : in t_byteslice_sr;
        p_frame_missalignment_out : out std_logic_vector(5 downto 0);
        p_ctrl_reset_from_sm_in : in std_logic_vector(5 downto 0);
        p_adc_lg_data_in : in t_byteslice_sr;
        p_adc_hg_data_in : in t_byteslice_sr;
        -- hss_adc's internal RX PLL0 lock, per channel (see db6_adc_interface_io_hss.vhd);
        -- mirrors the old iddr scheme's per-channel pll_adc_channel.locked_out (see
        -- db6_adc_interface_decoder_iddr_bitclk280.vhd) feeding channel_clk280_locked.
        p_adc_pll0_locked_in : in std_logic_vector(5 downto 0) := (others => '0');


        --control
        p_adc_readout_control_in : in t_adc_readout_control;
        
        --output
        p_adc_readout_out       : out t_adc_readout;
        
        --debug
        p_leds_out      : out std_logic_vector(3 downto 0)
  
  );
end db6_adc_interface_decoder_iserdese;

architecture Behavioral of db6_adc_interface_decoder_iserdese is

    signal s_ctrl_reset_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_frame_missalignment : std_logic_vector (5 downto 0) := (others => '0');

    signal s_adc_channel_fifo_fc, s_adc_channel_fifo_hg, s_adc_channel_fifo_lg : t_adc_channel_fifo;--t_adc_channel_fifo;

    -- fast-domain (p_adc_bitclkdiv_in) FSM-verified commit values, pre-CDC -- see
    -- proc_align_data below and the CDC stage that follows it.
    signal s_fc_data_fast, s_hg_data_fast, s_lg_data_fast : t_adc_data := (others => (others => '0'));
    -- toggles every time proc_align_data commits a new, complete fc/hg/lg word (both
    -- commit points below) -- the ONLY signal that actually crosses into cfgbus_clk40
    -- asynchronously; see the CDC stage below for why.
    signal s_data_toggle : std_logic_vector(5 downto 0) := (others => '0');

    -- 2026-09-12: CDC into p_clknet_in.cfgbus_clk40 -- replaces an earlier dual-tap
    -- canary-lock design (mirroring db6_adc_interface_decoder_iddr_bitclk280.vhd's
    -- proc_adc_tap_registers/proc_adc_cdc_lock) that turned out to violate this system's
    -- actual requirements once tested on hardware: (1) each channel independently picked
    -- whichever of two pipeline depths (differing by 4 p_adc_bitclkdiv_in cycles) first
    -- read the fc marker correctly, giving DIFFERENT, data-dependent latency channel to
    -- channel -- unacceptable for a multi-channel system that needs identical, fixed
    -- latency across all six ADCs (no elastic buffers, no per-channel phase drift), and
    -- (2) only fc_data was ever checked against the known marker; hg_data/lg_data were
    -- trusted by association even though they're separate physical registers with their
    -- own independent tear risk on any given cfgbus_clk40 edge. Observed on hardware as
    -- occasional single-bit "slips" with a fixed VIO test pattern, and as noisy,
    -- metastability-looking jumps with live analog data.
    --
    -- Fixed with a standard toggle/valid-handshake synchronizer instead: the ONLY signal
    -- actually sampled across the clock boundary is the single-bit s_data_toggle above,
    -- through a conventional 2-flop synchronizer (provably safe -- no multi-bit tearing is
    -- possible for a single bit). By the time a toggle transition is detected in
    -- cfgbus_clk40, the underlying fc/hg/lg data (written on the exact same
    -- p_adc_bitclkdiv_in edge as the toggle flip) has necessarily been stable for multiple
    -- destination clock cycles already, so it can be captured directly, atomically, and
    -- safely at that point -- same fixed number of cfgbus_clk40 cycles for every channel,
    -- no per-channel tap decision, no elastic buffering, no data-dependent latency. A
    -- given update may occasionally be superseded by a newer one before cfgbus_clk40
    -- catches up (proc_align_data commits roughly every 3-7 p_adc_bitclkdiv_in cycles,
    -- ~21-50ns, comparable to one 25ns cfgbus_clk40 period) -- harmless, since only the
    -- latest value is ever meaningful downstream (true even before any of this session's
    -- clock fixes, when this whole decoder ran on cfgbus_clk40 directly).
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

begin

p_adc_readout_out <= s_adc_readout;
s_ctrl_reset_from_sm <= p_ctrl_reset_from_sm_in;
gen_adc_channels: for v_adc in 0 to 5 generate

    p_frame_missalignment_out(v_adc) <= s_frame_missalignment(v_adc);

    -- status signals (see db6_adc_interface_decoder_iddr_bitclk280.vhd for the iddr-scheme
    -- equivalent): channel_clk280_locked mirrors the per-channel bit-clock PLL lock (there,
    -- a dedicated pll_adc_channel; here, hss_adc's own internal PLL0); channel_locked mirrors
    -- the frame-marker lock (there, a separate fc-pattern-match FSM; here, reusing this
    -- decoder's own frame alignment FSM below, which already tracks the same "11111110000000"
    -- pattern via s_frame_missalignment). channel_locked itself is set inside proc_cdc_capture
    -- below, re-checked against the marker on every captured cfgbus_clk40-domain update -- see
    -- that stage's header comment.
    s_adc_readout.channel_clk280_locked(v_adc) <= p_adc_pll0_locked_in(v_adc);

    proc_align_data : process (p_adc_bitclkdiv_in(v_adc), s_ctrl_reset_from_sm(v_adc), p_master_reset_in)
    variable v_state  : integer range 0 to 6;
    variable v_lg_data  : std_logic_vector(11 downto 0):=(others=>'0');
    variable v_hg_data  : std_logic_vector(11 downto 0):=(others=>'0');
    variable v_fc_data  : std_logic_vector(11 downto 0):=(others=>'0');
    begin
        if (s_ctrl_reset_from_sm(v_adc) = '1') or (p_master_reset_in = '1') then
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
                -- 2026-09-10: tried bit-reversed comparison constants (E/3/8 instead of
                -- 7/C/1) here, reasoning the comparison should use the same chronological
                -- bit order as the data-extraction concatenation just below (which reads
                -- p_adc_*_data_in(0)&(1)&(2)&(3)). Hardware testing showed this was a
                -- regression: channel_locked went from "0 but fc data looks plausible" to
                -- permanent all-zero on every signal (fc/hg/lg), i.e. the FSM now never
                -- completes a single successful 7-state traversal, whereas before it
                -- apparently did so often enough to produce visually sane fc data.
                --
                -- Cross-checked against the proven-working iddr280 decoder
                -- (db6_adc_interface_decoder_iddr_bitclk280.vhd's proc_shift_lg_in), which
                -- uses the identical (0)&(1)-style extraction convention on its own
                -- 2-bit-wide p_adc_frameclk_in slices. Reconstructing its check literals
                -- against its own known-good comparison pattern (proc_mon compares the
                -- fully-assembled fc_data against literal "11111110000000") shows the
                -- correct rule is: the raw sliced vector is compared *directly* against
                -- the literal using normal VHDL big-endian mapping (leftmost char = highest
                -- index) -- which, given the extraction's low-index-first concatenation, is
                -- already the bit-reversal of the chronological marker value. Applying that
                -- rule to this 4-bit case reproduces the *original* constants (7/C/1), not
                -- the "fixed" ones -- so this was reverted back.
                --
                -- channel_locked=0 with the original constants therefore has some other
                -- root cause (most likely a coarse/nibble-granularity phase or bitslip
                -- alignment issue specific to the hss_wizard ISERDES path, not an intra-
                -- nibble bit-order bug) -- not yet identified.
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

    -- CDC into p_clknet_in.cfgbus_clk40 -- see s_data_toggle/s_toggle_sync0 declaration
    -- above for the full design reasoning (toggle/valid-handshake synchronizer, fixed
    -- latency, no per-channel tap selection, no elastic buffering).
    proc_cdc_capture : process(p_clknet_in.cfgbus_clk40, s_ctrl_reset_from_sm(v_adc), p_master_reset_in)
    begin
        if (s_ctrl_reset_from_sm(v_adc) = '1') or (p_master_reset_in = '1') then
            s_toggle_sync0(v_adc) <= '0';
            s_toggle_sync1(v_adc) <= '0';
            s_toggle_sync1_prev(v_adc) <= '0';
            s_frame_missalignment_sync0(v_adc) <= '1';
            s_frame_missalignment_sync1(v_adc) <= '1';
            s_adc_readout.channel_locked(v_adc) <= '0';
        elsif rising_edge(p_clknet_in.cfgbus_clk40) then
            -- standard 2-flop synchronizer for the single-bit toggle, plus one more
            -- register to compare against for edge detection
            s_toggle_sync0(v_adc) <= s_data_toggle(v_adc);
            s_toggle_sync1(v_adc) <= s_toggle_sync0(v_adc);
            s_toggle_sync1_prev(v_adc) <= s_toggle_sync1(v_adc);

            s_frame_missalignment_sync0(v_adc) <= s_frame_missalignment(v_adc);
            s_frame_missalignment_sync1(v_adc) <= s_frame_missalignment_sync0(v_adc);

            if s_toggle_sync1(v_adc) /= s_toggle_sync1_prev(v_adc) then
                -- new word committed several p_adc_bitclkdiv_in cycles ago and stable
                -- since -- safe to capture atomically here, same fixed latency every
                -- channel, every update.
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
