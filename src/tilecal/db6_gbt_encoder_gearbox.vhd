----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.10.2022 14:31:16
-- Design Name: 
-- Module Name: db6_gbt_encoder_gearbox - Behavioral
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

library tilecal;
use tilecal.db6_design_package.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_gbt_encoder_gearbox is
  generic(
        g_ch_number : integer := 0;
        g_wordclkfreq : integer := 240
  );
  port (
        p_master_reset_in : std_logic;
		p_clknet_in : in t_db_clknet;
        p_db_reg_rx_in : in t_db_reg_rx;
        --p_gbt_tx_data_out       : out std_logic_vector(115 downto 0);
        p_gbt_encoder_interface_out         : out t_gbt_encoder_interface;
        p_gbt_encoder_interface_in         : in t_gbt_encoder_interface;
		p_sfp_ku_mgt_in                     : t_ku_mgt
		);
end db6_gbt_encoder_gearbox;

architecture Behavioral of db6_gbt_encoder_gearbox is

    signal s_data_buffer_lg, s_data_buffer_hg : std_logic_vector(115 downto 0);
    signal s_gbt_encoder_interface,s_gbt_encoder_interface_buffer : t_gbt_encoder_interface;
    
    signal s_cdc_reset_in, s_cdc_reset_out : std_logic;
    signal s_cdc_counter : integer range 0 to 3 := 0;
    signal s_data_phase,s_data_phase_sync : std_logic_vector(1 downto 0);

    constant c_pipeline_depth : integer := 2;

    -- 2026-09-12: CDC into p_clknet_in.gth_tx_wordclk(g_ch_number) (240MHz -- a clean 6x
    -- multiple of cfgbus_clk40, both ultimately GBTx-synchronous, but with an unknown,
    -- uncalibrated fixed phase offset between them: mesochronous, not the same clock, and
    -- not safe to sample directly). Replaces i_hg_pipeline/i_lg_pipeline, which used to
    -- clock a plain db6_pipeline_propagator (just a shift register, no synchronization
    -- safety at all) entirely off gth_tx_wordclk while its input came straight from
    -- cfgbus_clk40 -- a naive, unsynchronized multi-bit crossing with no protection
    -- whatsoever, invisible with a static test pattern (unchanging data can't visibly
    -- tear) but producing torn/incoherent hg/lg words with live, continuously-changing
    -- ADC data. Fixed the same way as db6_adc_interface_decoder_iserdese.vhd's
    -- proc_cdc_capture: only the single-bit p_gbt_encoder_interface_in.data_toggle
    -- (toggled every cfgbus_clk40 cycle in db6_gbt_encoder_formatter.vhd, alongside the
    -- hg/lg update) is actually sampled across the clock boundary, through a conventional
    -- 2-flop synchronizer (safe for one bit; a torn read just glitches cleanly to old or
    -- new). gth_tx_wordclk's 6x headroom over cfgbus_clk40 means every single toggle
    -- transition is reliably caught before the next one arrives, so once a transition is
    -- detected the hg/lg data (updated on the exact same cfgbus_clk40 edge as the toggle)
    -- has already been stable for a full source cycle and can be captured directly and
    -- safely -- same fixed latency every time, no elastic buffering.
    signal s_toggle_sync0, s_toggle_sync1, s_toggle_sync1_prev : std_logic := '0';

begin
    p_gbt_encoder_interface_out.gbt_tx_data_out.lg <= s_gbt_encoder_interface.gbt_tx_data_out.lg;--p_gbt_encoder_interface_in.gbt_tx_data_out.lg;
    p_gbt_encoder_interface_out.gbt_tx_data_out.hg <= s_gbt_encoder_interface.gbt_tx_data_out.lg;--p_gbt_encoder_interface_in.gbt_tx_data_out.hg;
    p_gbt_encoder_interface_out.gbt_tx_data_out.sync <= s_gbt_encoder_interface.gbt_tx_data_out.sync;
    p_gbt_encoder_interface_out.data_phase <= s_data_phase;
    p_gbt_encoder_interface_out.data_phase_sync <= s_data_phase_sync;
    
    p_gbt_encoder_interface_out.gbt_cdc_counter <= p_clknet_in.gbt_cdc_counter_array(g_ch_number);--s_cdc_counter;
    s_cdc_counter<=p_clknet_in.gbt_cdc_counter_array(g_ch_number);
    
    p_gbt_encoder_interface_out.gbt_bank_sync <=std_logic_vector(to_unsigned(s_cdc_counter,3));
    s_gbt_encoder_interface.gbt_tx_data_out.lg <= s_gbt_encoder_interface_buffer.gbt_tx_data_out.lg; --p_gbt_encoder_interface_in.gbt_tx_data_out.lg;
    s_gbt_encoder_interface.gbt_tx_data_out.hg <= s_gbt_encoder_interface_buffer.gbt_tx_data_out.hg; --p_gbt_encoder_interface_in.gbt_tx_data_out.hg;

    -- see s_toggle_sync0 declaration above for the full design reasoning. No explicit
    -- reset (matching proc_db_data_sync just below, and this file's p_master_reset_in
    -- port, which nothing in this architecture uses): the three sync flops' :='0' initial
    -- values start them equal, so no spurious edge is ever detected at power-up -- the
    -- synchronizer is inherently self-starting.
    proc_cdc_capture : process(p_clknet_in.gth_tx_wordclk(g_ch_number))
    begin
        if rising_edge(p_clknet_in.gth_tx_wordclk(g_ch_number)) then
            s_toggle_sync0 <= p_gbt_encoder_interface_in.data_toggle;
            s_toggle_sync1 <= s_toggle_sync0;
            s_toggle_sync1_prev <= s_toggle_sync1;

            if s_toggle_sync1 /= s_toggle_sync1_prev then
                s_gbt_encoder_interface_buffer.gbt_tx_data_out.hg <= p_gbt_encoder_interface_in.gbt_tx_data_out.hg;
                s_gbt_encoder_interface_buffer.gbt_tx_data_out.lg <= p_gbt_encoder_interface_in.gbt_tx_data_out.lg;
            end if;
        end if;
    end process;

    proc_db_data_sync : process(p_clknet_in.gth_tx_wordclk(g_ch_number))--(p_clknet_in.gth_tx_wordclk(g_ch_number), s_cdc_reset_out)--p_clknet_in.gth_tx_frameclk(g_ch_number))
    begin

        if rising_edge(p_clknet_in.gth_tx_wordclk(g_ch_number)) then --(p_clknet_in.gth_tx_wordclk(g_ch_number)) then--p_clknet_in.gth_tx_frameclk(g_ch_number)) then
            if p_clknet_in.gbt_cdc_counter_array(g_ch_number) = 0 then

                s_data_phase <= s_data_phase(0)&p_clknet_in.gbt_cdc_phase_array(g_ch_number);

                if p_clknet_in.gbt_cdc_phase_array(g_ch_number) = ((p_clknet_in.gbt_cdc_gearbox_phase(g_ch_number) or p_db_reg_rx_in(cfb_db_debug)(c_db_debug_gbt_cdc_phase_array+g_ch_number))) then -- '0' then
                    s_data_phase_sync<=s_data_phase_sync(0)&s_gbt_encoder_interface_buffer.gbt_tx_data_out.lg(89);
                    s_gbt_encoder_interface.gbt_tx_data_out.sync <= s_gbt_encoder_interface_buffer.gbt_tx_data_out.lg;
                else
                    s_data_phase_sync<=s_data_phase_sync(0)&p_gbt_encoder_interface_in.gbt_tx_data_out.hg(89);
                    s_gbt_encoder_interface.gbt_tx_data_out.sync <= s_gbt_encoder_interface_buffer.gbt_tx_data_out.hg;
                end if;
            end if;
        end if;            
    end process;
  


end Behavioral;
