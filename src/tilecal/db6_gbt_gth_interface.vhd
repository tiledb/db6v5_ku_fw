----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/25/2020 11:33:15 AM
-- Design Name: 
-- Module Name: db6_gbt_gth_interface - Behavioral
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

library gbt;
use gbt.all;
use gbt.gbt_bank_package.all;
use gbt.vendor_specific_gbt_bank_package.all;
library tilecal;
use tilecal.db6_design_package.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity db6_gbt_gth_interface is 
   generic (   
        g_num_gth_links                 : integer := 2;                             --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
        g_enable_simple_gbt_encoder     : integer := 0;                              -- 1-> enabled
        --g_link_clk                      : integer := 0                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
        g_enable_ila_gbt_encoder        : integer := 1;
        g_tmr_enabled                   : integer := 0;
-- hog
        GLOBAL_DATE : std_logic_vector(31 downto 0); -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME : std_logic_vector(31 downto 0) -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
        -- 2026-09-12: GLOBAL_VER/SHA, TOP_VER/SHA, CON_VER/SHA, HOG_VER/SHA (and the
        -- already-dead XML_VER/SHA) removed -- pass-through only, down to
        -- db6_gbt_encoder.vhd; see db6_gbt_encoder_sc.vhd's header for why.

   );
  Port (
        p_clknet_in : in t_db_clknet;
        p_master_reset_in : in std_logic_vector(31 downto 0);
        p_db_reg_rx_in : in t_db_reg_rx;
        
        --ref_clks
        p_ku_mgt                         : out t_ku_mgt;

        -- db6_mgt now lives in db7_io_box (GT wizard IP + differential pads owned there).
        -- These plain-logic ports replace the direct db6_mgt instantiation this file used to own.
        p_ku_mgt_in                      : in t_ku_mgt;
        p_mgt_txusrclk_in                : in std_logic_vector(1 to g_num_gth_links);
        p_mgt_rxusrclk_in                : in std_logic_vector(1 to g_num_gth_links);
        p_mgt_txreset_out                : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_rxreset_out                : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_txready_in                 : in std_logic_vector(1 to g_num_gth_links);
        p_mgt_rxready_in                 : in std_logic_vector(1 to g_num_gth_links);
        p_mgt_headerlocked_in            : in std_logic_vector(1 to g_num_gth_links);
        p_mgt_rstcnt_in                  : in gbt_reg8_A(1 to g_num_gth_links);
        p_mgt_autorsten_out              : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_autorstoneven_out          : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_usrword_out                : out word_mxnbit_A(1 to g_num_gth_links);
        p_mgt_devspec_i_out              : out mgtDeviceSpecific_i_R;
        p_mgt_devspec_o_in               : in mgtDeviceSpecific_o_R;

        --tdo from other fpga
        p_tdo_remote_in	            : in	std_logic;
        
        --interfaces
        p_gbt_encoder_interface_out         : out t_gbt_encoder_interface;
        p_gbt_bank_out                      : out t_db6_gbt_bank;         
        p_mb_interface_in : in t_mb_interface;
        p_sem_interface_in : in t_sem_interface;
        p_system_management_interface_in : in t_system_management_interface;
        p_gbtx_interface_in : in t_gbtx_interface;
        p_serial_id_interface_in : in t_serial_id_interface;
        p_db6_sem_interface_in  : in t_db6_sem_interface;
        p_cfgbus_interface_in : in t_cfgbus_interface;
        p_sfp_interface_in : in t_sfp_interface;

        -- sfp+ reg block ram port b readback; folded into s_ku_mgt.sfp_tx_register below
        -- so it rides along with the rest of the sfp/gth status bundle
        p_sfp_tx_register_in : in t_sfp_reg_data_array
  );
end db6_gbt_gth_interface;

architecture Behavioral of db6_gbt_gth_interface is
attribute IOB: string;
attribute keep: string;
attribute dont_touch: string;

signal s_ku_mgt                         : t_ku_mgt;
--gbt_bank
signal s_db6_gbt_bank : t_db6_gbt_bank;
type t_gbt_encoder_interface_array is array (0 to g_num_gth_links-1) of t_gbt_encoder_interface;
signal s_gbt_encoder_interface, s_gbt_encoder_interface_in : t_gbt_encoder_interface_array;
signal s_gbt_encoder_interface_buffer : t_gbt_encoder_interface;
signal s_reset_gbt_bank, s_reset_gth : std_logic;

signal s_gth_txwordclk80_out, s_gth_txwordclk40_out, s_gth_rxwordclk40_out, s_gth_txoutclkfabric_out, s_gth_rxoutclkfabric_out : std_logic_vector(1 to g_num_gth_links);

-- 2026-09-13: dual-uplink deterministic sync (see gen_simple_gbt_encoder below) --
-- link 0's canonical .sync word (from i_db6_gbt_encoder, gth_tx_wordclk(0) domain) is
-- CDC'd into gth_tx_wordclk(1) with the same fixed-latency toggle+2-flop technique
-- used throughout this codebase (see db6_gbt_encoder_gearbox.vhd's proc_cdc_capture),
-- then fed to a genuinely independent db6_gbt_tx/db6_gbt_tx_gearbox pair clocked by
-- link 1's own gth_tx_wordclk(1) -- replacing a naive raw mgt_txword fan-out that
-- drove link 1's GT TX interface directly from a register only valid in link 0's
-- clock domain (an unsynchronized crossing on a continuously-changing bus).
signal s_sync_commit_toggle_link0 : std_logic := '0';
signal s_sync_toggle_sync0_link1, s_sync_toggle_sync1_link1, s_sync_toggle_sync1_prev_link1 : std_logic := '0';
signal s_sync_captured_link1 : std_logic_vector(115 downto 0) := (others => '0');
signal s_sync_counter_link1 : integer range 0 to 2 := 0;
signal s_link1_tx_frame : std_logic_vector(119 downto 0);
signal s_link1_tx_phaligned, s_link1_tx_phcomputed : std_logic;

-- comparator (see t_gbt_encoder_interface's dual_link_sync_mismatch_* fields) --
-- 2026-09-14 redesign: the original version CDC'd both link 0's canonical .sync and
-- link 1's captured copy independently into cfgbus_clk40 (40MHz) for comparison
-- there. That is backwards from every other safe crossing in this codebase: .sync
-- commits roughly once per 3 gth_tx_wordclk cycles (~12.5ns), FASTER than
-- cfgbus_clk40's own 25ns period, so cfgbus_clk40 cannot reliably observe every
-- commit -- it aliases/misses transitions and ends up comparing two DIFFERENT
-- generations of data, causing near-constant false-positive mismatches (reported
-- 2026-09-14: cleared count immediately saturates back to 0xFF). The actual
-- CDC into s_sync_captured_link1 above (gth_tx_wordclk(1), same nominal frequency as
-- the wordclock(0) source, ~3x margin -- same safety reasoning as this codebase's
-- other fast-to-fast crossings) is NOT the bug and needs no verification against a
-- slow domain. Instead: a SECOND, fully independent toggle-sync+capture chain
-- (own flops, same source signals) runs in parallel in the SAME gth_tx_wordclk(1)
-- domain -- comparing it against the primary chain is a genuine TMR-style hardware
-- fault check (SEU/routing glitch in either chain), not a generation-alignment race,
-- since both chains observe the identical source at the identical rate. The
-- resulting sticky/count only change on an actual fault, so THEY are safe to read
-- via a plain 2-flop synchronizer into cfgbus_clk40 (slow-changing signal, no
-- aliasing risk -- same as reading channel_locked or any other status flag).
signal s_sync_toggle_sync0_link1_b, s_sync_toggle_sync1_link1_b, s_sync_toggle_sync1_prev_link1_b : std_logic := '0';
signal s_sync_captured_link1_b : std_logic_vector(115 downto 0) := (others => '0');
signal s_dual_link_sync_mismatch_sticky_fast : std_logic := '0'; -- gth_tx_wordclk(1) domain
signal s_dual_link_sync_mismatch_count_fast : unsigned(7 downto 0) := (others => '0'); -- gth_tx_wordclk(1) domain
signal s_mismatch_sticky_sync0, s_mismatch_sticky_sync1 : std_logic := '0';
signal s_mismatch_count_sync0, s_mismatch_count_sync1 : std_logic_vector(7 downto 0) := (others => '0');

begin

p_gbt_encoder_interface_out<=s_gbt_encoder_interface_buffer; --s_gbt_encoder_interface(0);
p_gbt_bank_out <= s_db6_gbt_bank;

gen_simple_gbt_encoder : if g_enable_simple_gbt_encoder = 1 generate
i_db6_gbt_encoder : entity tilecal.db6_gbt_encoder --tilecal.db6_gbt_encoder_test
    generic map (
        g_tmr_enabled => g_tmr_enabled,
        -- hog
        GLOBAL_DATE => GLOBAL_DATE, -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME => GLOBAL_TIME -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
    )
    port map (
        p_master_reset_in => p_master_reset_in(c_gbt_encoder_reset_bit),
        p_clknet_in => p_clknet_in,
        p_db_reg_rx_in => p_db_reg_rx_in,
        p_gbt_encoder_interface_out => s_gbt_encoder_interface(0),
        p_gbt_encoder_interface_in => s_gbt_encoder_interface_in(0),
        
        --interfaces
        p_mb_interface_in => p_mb_interface_in,
        p_sem_interface_in => p_sem_interface_in,
        p_tdo_remote_in => p_tdo_remote_in,
        p_system_management_interface_in => p_system_management_interface_in,
        p_gbtx_interface_in => p_gbtx_interface_in,
        p_serial_id_interface_in => p_serial_id_interface_in,
        p_sfp_ku_mgt_in => s_ku_mgt,
        p_db6_sem_interface_in => p_db6_sem_interface_in,
        p_cfgbus_interface_in => p_cfgbus_interface_in,
        p_sfp_interface_in => p_sfp_interface_in
    );
    -- link 0: status/counter reporting straight from the canonical encoder instance
    -- (unchanged).
    s_db6_gbt_bank.tx_phase_i(0)<=s_gbt_encoder_interface(0).data_phase(0);
    s_db6_gbt_bank.gbt_cdc_counter_array_i(0)<=s_gbt_encoder_interface(0).gbt_cdc_counter;
    s_db6_gbt_bank.tx_phcomputed_o(0)<=s_gbt_encoder_interface(0).tx_phcomputed_o;
    s_db6_gbt_bank.tx_phaligned_o(0)<=s_gbt_encoder_interface(0).tx_phaligned_o;

    -- link 1: reports its OWN genuinely independent gearbox's status/counter now
    -- (i_db6_gbt_tx_gearbox_link1 below), not a copy of link 0's.
    s_db6_gbt_bank.tx_phase_i(1)<=s_gbt_encoder_interface(0).data_phase(0);
    s_db6_gbt_bank.gbt_cdc_counter_array_i(1)<=s_sync_counter_link1;
    s_db6_gbt_bank.tx_phcomputed_o(1)<=s_link1_tx_phcomputed;
    s_db6_gbt_bank.tx_phaligned_o(1)<=s_link1_tx_phaligned;

    -- db6_mgt now instantiated once, in db7_io_box (s_ku_mgt <= p_ku_mgt_in relay
    -- is unconditional, below -- both link-count generate branches need it).
    -- link 0: direct output of the canonical encoder instance.
    p_mgt_usrword_out(1) <= s_gbt_encoder_interface(0).mgt_txword;

    -- toggles once per canonical .sync commit (mirrors the exact condition
    -- db6_gbt_encoder_gearbox.vhd's proc_db_data_sync uses to write .sync), in link
    -- 0's own gth_tx_wordclk(0) domain.
    proc_sync_commit_toggle : process(p_clknet_in.gth_tx_wordclk(0))
    begin
        if rising_edge(p_clknet_in.gth_tx_wordclk(0)) then
            if p_clknet_in.gbt_cdc_counter_array(0) = 0 then
                s_sync_commit_toggle_link0 <= not s_sync_commit_toggle_link0;
            end if;
        end if;
    end process;

    -- link 1: fixed-latency CDC of link 0's canonical .sync word into
    -- gth_tx_wordclk(1), a genuinely independent clock domain -- 2-flop toggle
    -- synchronizer, capture only on detected transition (same proven pattern as
    -- db6_gbt_encoder_gearbox.vhd's proc_cdc_capture; by the time a transition is
    -- detected here, .sync has been stable in link 0's domain for a full commit
    -- period (~3 gth_tx_wordclk(0) cycles), so the captured value is always valid).
    -- s_sync_counter_link1 free-runs 0->1->2->0 (matching GBT_WORD_RATIO=3) but
    -- RESETS to 0 on every detected commit, giving link 1's own db6_gbt_tx/
    -- db6_gbt_tx_gearbox pair a gbt_cdc_counter_i that is always correctly phased to
    -- when fresh data actually arrived in its own domain -- fixed, deterministic
    -- latency behind link 0, no elastic buffering.
    proc_sync_cdc_link1 : process(p_clknet_in.gth_tx_wordclk(1))
    begin
        if rising_edge(p_clknet_in.gth_tx_wordclk(1)) then
            s_sync_toggle_sync0_link1 <= s_sync_commit_toggle_link0;
            s_sync_toggle_sync1_link1 <= s_sync_toggle_sync0_link1;
            s_sync_toggle_sync1_prev_link1 <= s_sync_toggle_sync1_link1;

            if s_sync_toggle_sync1_link1 /= s_sync_toggle_sync1_prev_link1 then
                s_sync_captured_link1 <= s_gbt_encoder_interface(0).gbt_tx_data_out.sync;
                s_sync_counter_link1 <= 0;
            elsif s_sync_counter_link1 = 2 then
                s_sync_counter_link1 <= 0;
            else
                s_sync_counter_link1 <= s_sync_counter_link1 + 1;
            end if;
        end if;
    end process;

    i_db6_gbt_tx_link1 : entity tilecal.db6_gbt_tx
        generic map (
            tx_encoding => WIDE_BUS
        )
        port map (
            tx_reset_i               => s_gbt_encoder_interface_in(1).gbt_txreset_i,
            tx_frameclk_i             => p_clknet_in.gth_tx_wordclk(1),
            tx_clken_i                => s_gbt_encoder_interface_in(1).gbt_txclken_i,
            tx_encoding_sel_i         => s_gbt_encoder_interface_in(1).tx_encoding_sel_i,
            tx_isdata_sel_i           => s_gbt_encoder_interface_in(1).gbt_isdataflag_i,
            tx_data_i                 => s_sync_captured_link1(83 downto 0),
            tx_extra_data_widebus_i   => s_sync_captured_link1(115 downto 84),
            gbt_cdc_counter_i         => s_sync_counter_link1,
            tx_frame_o                => s_link1_tx_frame
        );

    i_db6_gbt_tx_gearbox_link1 : entity tilecal.db6_gbt_tx_gearbox
        generic map (
            tx_optimization => LATENCY_OPTIMIZED
        )
        port map (
            tx_reset_i        => s_gbt_encoder_interface_in(1).gbt_txreset_i,
            tx_frameclk_i      => p_clknet_in.gth_tx_wordclk(1),
            tx_clken_i         => s_gbt_encoder_interface_in(1).gbt_txclken_i,
            tx_wordclk_i       => p_clknet_in.gth_tx_wordclk(1),
            tx_phaligned_o     => s_link1_tx_phaligned,
            tx_phcomputed_o    => s_link1_tx_phcomputed,
            tx_frame_i         => s_link1_tx_frame,
            gbt_cdc_counter_i  => s_sync_counter_link1,
            tx_word_o          => p_mgt_usrword_out(2)
        );

    -- redundant (TMR-style) second capture chain, own flops, same source signals as
    -- proc_sync_cdc_link1 above -- see this file's comparator signal-declaration
    -- header comment for why this replaces the old cfgbus_clk40-domain compare.
    proc_sync_cdc_link1_b : process(p_clknet_in.gth_tx_wordclk(1))
    begin
        if rising_edge(p_clknet_in.gth_tx_wordclk(1)) then
            s_sync_toggle_sync0_link1_b <= s_sync_commit_toggle_link0;
            s_sync_toggle_sync1_link1_b <= s_sync_toggle_sync0_link1_b;
            s_sync_toggle_sync1_prev_link1_b <= s_sync_toggle_sync1_link1_b;

            if s_sync_toggle_sync1_link1_b /= s_sync_toggle_sync1_prev_link1_b then
                s_sync_captured_link1_b <= s_gbt_encoder_interface(0).gbt_tx_data_out.sync;
            end if;
        end if;
    end process;

    -- compare the two redundant chains in the SAME fast domain they're captured in
    -- (no generation-alignment race -- both observe the identical source at the
    -- identical rate). p_clknet_in.clear_dual_link_mismatch (new VIO button) clears
    -- without a full master reset -- see t_db_clknet's identically-named field
    -- (db6_design_package.vhd), a flat field (t_db_clknet has no .clknet
    -- sub-record; that nesting only exists on t_debug_control, one level up).
    proc_fast_compare : process(p_clknet_in.gth_tx_wordclk(1), p_master_reset_in, p_clknet_in.clear_dual_link_mismatch)
    begin
        if p_master_reset_in(c_gbt_encoder_reset_bit) = '1' or p_clknet_in.clear_dual_link_mismatch = '1' then
            s_dual_link_sync_mismatch_sticky_fast <= '0';
            s_dual_link_sync_mismatch_count_fast <= (others => '0');
        elsif rising_edge(p_clknet_in.gth_tx_wordclk(1)) then
            if s_sync_captured_link1 /= s_sync_captured_link1_b then
                s_dual_link_sync_mismatch_sticky_fast <= '1';
                if s_dual_link_sync_mismatch_count_fast /= x"FF" then
                    s_dual_link_sync_mismatch_count_fast <= s_dual_link_sync_mismatch_count_fast + 1;
                end if;
            end if;
        end if;
    end process;

    -- sticky/count only ever change on an actual fault (essentially never in normal
    -- operation), so a plain 2-flop synchronizer into cfgbus_clk40 is safe here --
    -- same as reading any other slow-changing status flag (e.g. channel_locked).
    proc_mismatch_status_sync : process(p_clknet_in.cfgbus_clk40)
    begin
        if rising_edge(p_clknet_in.cfgbus_clk40) then
            s_mismatch_sticky_sync0 <= s_dual_link_sync_mismatch_sticky_fast;
            s_mismatch_sticky_sync1 <= s_mismatch_sticky_sync0;
            s_mismatch_count_sync0 <= std_logic_vector(s_dual_link_sync_mismatch_count_fast);
            s_mismatch_count_sync1 <= s_mismatch_count_sync0;
        end if;
    end process;
    s_gbt_encoder_interface_buffer.dual_link_sync_mismatch_sticky <= s_mismatch_sticky_sync1;
    s_gbt_encoder_interface_buffer.dual_link_sync_mismatch_count <= s_mismatch_count_sync1;

end generate;



-- SFP/GBTx differential rx/tx pads and the db6_mgt instance that consumes them
-- now live in db7_io_box; s_mgt_diff_pair_rx/tx removed accordingly.

s_db6_gbt_bank.mgt_clk_i(0) <= p_clknet_in.gth_refclk_local(0);
s_db6_gbt_bank.mgt_clk_i(1) <= p_clknet_in.gth_refclk_local(1);

-- db6_mgt now lives in db7_io_box; s_ku_mgt is its p_ku_mgt_out relayed back in, with
-- sfp_tx_register overlaid on top (db6_mgt/the GT wizard knows nothing about it -- a
-- whole-record concurrent copy plus a separate concurrent field assignment would put
-- two drivers on those bits, so the override is done sequentially in one process,
-- same pattern as db7_io_box's mgt devspec_i overlay).
proc_ku_mgt_relay : process(p_ku_mgt_in, p_sfp_tx_register_in)
    variable v_ku_mgt : t_ku_mgt;
begin
    v_ku_mgt := p_ku_mgt_in;
    v_ku_mgt.sfp_tx_register := p_sfp_tx_register_in;
    s_ku_mgt <= v_ku_mgt;
end process;
p_ku_mgt <= s_ku_mgt;


s_reset_gbt_bank <= not s_ku_mgt.gtwiz_reset_tx_done_out(0);
s_reset_gth <= '0';


gen_multiple_gbt_encoder : if g_enable_simple_gbt_encoder = 0 generate
    -- db6_mgt now instantiated once, in db7_io_box (see gen_simple_gbt_encoder above
    -- for the shared s_ku_mgt <= p_ku_mgt_in relay). This branch's per-link tx word
    -- mapping (preserved as-is: link i+1 <= encoder instance i, independent per link):
    p_mgt_usrword_out(1) <= s_gbt_encoder_interface(0).mgt_txword;
    p_mgt_usrword_out(2) <= s_gbt_encoder_interface(1).mgt_txword;

    gen_link_connections: for i in 0 to g_num_gth_links-1 generate
        i_db6_gbt_encoder : entity tilecal.db6_gbt_encoder--tilecal.db6_gbt_encoder_test
          generic map (
                g_ch_number => i,
                g_tmr_enabled => g_tmr_enabled,
                g_num_gth_links=>g_num_gth_links,
                -- hog
                GLOBAL_DATE => GLOBAL_DATE, -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
                GLOBAL_TIME => GLOBAL_TIME -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
                
          )
          port map (
                p_master_reset_in => p_master_reset_in(c_gbt_encoder_reset_bit),
                p_clknet_in => p_clknet_in,
                p_db_reg_rx_in => p_db_reg_rx_in,
                p_gbt_encoder_interface_out => s_gbt_encoder_interface(i),
                p_gbt_encoder_interface_in => s_gbt_encoder_interface_in(i),
                
                --interfaces
                p_mb_interface_in => p_mb_interface_in,
                p_sem_interface_in => p_sem_interface_in,
                p_tdo_remote_in => p_tdo_remote_in,
                p_system_management_interface_in => p_system_management_interface_in,
                p_gbtx_interface_in => p_gbtx_interface_in,
                p_serial_id_interface_in => p_serial_id_interface_in,
                p_sfp_ku_mgt_in => s_ku_mgt,
                p_db6_sem_interface_in => p_db6_sem_interface_in,
                p_cfgbus_interface_in => p_cfgbus_interface_in,
                p_sfp_interface_in => p_sfp_interface_in
        
                );
        
        s_db6_gbt_bank.tx_phase_i(i)<=s_gbt_encoder_interface(i).data_phase(0);
        s_db6_gbt_bank.tx_phcomputed_o(i)<=s_gbt_encoder_interface(i).tx_phcomputed_o;
        s_db6_gbt_bank.tx_phaligned_o(i)<=s_gbt_encoder_interface(i).tx_phaligned_o;
        s_db6_gbt_bank.gbt_cdc_counter_array_i(i)<=s_gbt_encoder_interface(i).gbt_cdc_counter;


    end generate;       
end generate;





gen_link_connections: for i in 0 to g_num_gth_links-1 generate

    s_db6_gbt_bank.gbt_txclken_i(i) <= '1';
    s_db6_gbt_bank.gbt_rxclken_i(i) <= '1';
    s_gbt_encoder_interface_in(i).gbt_txclken_i <= '1';

    s_db6_gbt_bank.mgt_txreset_i(i) <= s_reset_gth or p_master_reset_in(c_gth_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_ch0_reset_bit+i);-- or s_reset_gth; -- or not p_clknet_in.locked_db; --'0';
    s_db6_gbt_bank.mgt_rxreset_i(i) <= s_reset_gth or p_master_reset_in(c_gth_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_ch0_reset_bit+i);-- or s_reset_gth; -- or not p_clknet_in.locked_db; --'0';
    s_db6_gbt_bank.gbt_txreset_i(i) <= p_master_reset_in(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_ch0_reset_bit+i) or s_reset_gbt_bank; -- or not p_clknet_in.locked_db; --'0';
    s_db6_gbt_bank.gbt_rxreset_i(i) <= p_master_reset_in(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_ch0_reset_bit+i) or s_reset_gbt_bank; -- or not p_clknet_in.locked_db; --'0';
 
    s_gbt_encoder_interface_in(i).gbt_txreset_i <= p_master_reset_in(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_ch0_reset_bit+i) or s_reset_gbt_bank; -- or not p_clknet_in.locked_db; --'0';
    s_gbt_encoder_interface_in(i).tx_encoding_sel_i <= '0'; -- 0-> wide bus
    s_gbt_encoder_interface_in(i).gbt_isdataflag_i <= '0';
    
    s_db6_gbt_bank.mgt_devspecific_i.drp_clk(i+1) <= p_clknet_in.osc_clk200;--p_clknet_in.cfgbus_clk40;
    s_db6_gbt_bank.mgt_devspecific_i.reset_freeRunningClock(1) <= p_clknet_in.osc_clk200;--p_clknet_in.cfgbus_clk40;
    -- rx_p/rx_n/tx_p/tx_n (the actual differential pads) are now set/read inside
    -- db7_io_box, which owns the db6_mgt instance and the SFP/GBTx pad ports.

    s_db6_gbt_bank.gbt_txframeclk_i(i)<= s_db6_gbt_bank.mgt_txwordclk_o(i); -- p_clknet_in.mmcm_refclk240; --p_clknet_in.mmcm_refclk80; --p_clknet_in.gth_tx_frameclk(i); --p_clknet_in.refclk80; --p_clknet_in.clk80;--p_clknet_in.gth_txwordclk80_out(i);
    s_db6_gbt_bank.gbt_rxframeclk_i(i)<=p_clknet_in.mmcm_refclk40;--p_clknet_in.gth_rxwordclk40_out(i);
    
    --gth configuration
    s_db6_gbt_bank.mgt_devspecific_i.conf_diffCtrl(i+1) <= "1000";
    s_db6_gbt_bank.mgt_devspecific_i.conf_preCursor(i+1) <= "10000";
    s_db6_gbt_bank.mgt_devspecific_i.conf_postCursor(i+1) <= "10000";

    s_db6_gbt_bank.mgt_devspecific_i.conf_txPol(i+1) <= '0';
    s_db6_gbt_bank.mgt_devspecific_i.conf_rxPol(i+1) <= '0';

end generate;

-- db7_io_box crossing: whole-vector/whole-record assignments, matching exactly what
-- used to be direct port-map associations to the local db6_mgt instance (same
-- leftmost-to-leftmost positional semantics between the "downto" t_db6_gbt_bank
-- fields and the "to"-indexed db6_mgt ports -- preserved as-is, not reordered).
p_mgt_txreset_out       <= s_db6_gbt_bank.mgt_txreset_i;
p_mgt_rxreset_out       <= s_db6_gbt_bank.mgt_rxreset_i;
p_mgt_autorsten_out     <= s_db6_gbt_bank.mgt_rstonbitslipen_i;
p_mgt_autorstoneven_out <= s_db6_gbt_bank.mgt_rstoneven_i;
p_mgt_devspec_i_out     <= s_db6_gbt_bank.mgt_devspecific_i;

s_db6_gbt_bank.mgt_txready_o      <= p_mgt_txready_in;
s_db6_gbt_bank.mgt_rxready_o      <= p_mgt_rxready_in;
s_db6_gbt_bank.mgt_headerlocked_o <= p_mgt_headerlocked_in;
s_db6_gbt_bank.mgt_rstcnt_o       <= p_mgt_rstcnt_in;
s_db6_gbt_bank.mgt_txwordclk_o    <= p_mgt_txusrclk_in;
s_db6_gbt_bank.mgt_rxwordclk_o    <= p_mgt_rxusrclk_in;
s_db6_gbt_bank.mgt_devspecific_o  <= p_mgt_devspec_o_in;

    
    
end Behavioral;


