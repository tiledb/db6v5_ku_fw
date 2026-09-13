----------------------------------------------------------------------------------
-- db6_data_readout_debug
--
-- 2026-09-13: debug capture buffer for the adc readout data path. Continuously shifts
-- the live per-channel frameclk(fc)/hg/lg samples (p_adc_readout_in, t_adc_readout)
-- through a 16-stage pipeline, and freezes a snapshot of all 16 stages into a capture
-- buffer once armed and the free-running bcr counter reaches a requested value:
--
--   * p_data_readout_debug_control_in.trigger going 0->1 arms the capture (waiting for
--     the bcr match below). It must return to 0 before the next 0->1 edge is honoured
--     -- a held/re-asserted '1' does not re-arm or re-trigger anything.
--   * once armed, the first clock where p_clknet_in.bcr.count equals
--     p_data_readout_debug_control_in.bcr_number freezes the current contents of the
--     16-deep fc/hg/lg pipelines into the capture buffer, sets status.captured, and
--     disarms (no further bcr matches are captured until the next 0->1 edge).
--   * status.captured clears as soon as trigger returns to 0, which is also the
--     precondition for the next arm -- so "captured" reads as "a capture is done and
--     the operator hasn't dropped trigger yet" rather than a separate handshake bit.
--
-- Readback avoids one wide vio probe per sample: sample_index (0-15) and
-- channel_select (0-5) mux a single 14-bit sample of each of fc/hg/lg out of the
-- capture buffer onto status.fc_data/hg_data/lg_data.
--
-- g_data_readout_debug gates all of the above: when 0, no capture logic is built and
-- status is held at its default (all-zero) value.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_data_readout_debug is
    generic (
        g_data_readout_debug : natural := 0 --! 1 = build the capture logic, 0 = disabled (status held at default)
    );
    port (
        p_master_reset_in                : in  std_logic;
        p_clknet_in                       : in  t_db_clknet; --! cfgbus_clk40 used as the capture clock (same domain p_adc_readout_in is registered in); bcr.count is the free-running trigger reference
        p_adc_readout_in                  : in  t_adc_readout; --! source fc_data/hg_data/lg_data, one sample per channel per clock
        p_data_readout_debug_control_in   : in  t_debug_control_data_readout; --! vio-driven trigger/bcr_number/sample_index/channel_select
        p_data_readout_debug_status_out   : out t_data_readout_debug_status --! vio-facing captured flag + muxed sample readback
    );
end db6_data_readout_debug;

architecture behavioral of db6_data_readout_debug is

    constant c_pipeline_depth : integer := 16;

    type t_data_readout_debug_pipeline is array (0 to c_pipeline_depth-1) of t_adc_data;
    constant c_pipeline_init : t_data_readout_debug_pipeline := (others => (others => (others => '0')));

    signal s_pipeline_fc, s_pipeline_hg, s_pipeline_lg : t_data_readout_debug_pipeline := c_pipeline_init;
    signal s_captured_fc, s_captured_hg, s_captured_lg : t_data_readout_debug_pipeline := c_pipeline_init;

    signal s_trigger_d1 : std_logic := '0';
    signal s_armed      : std_logic := '0';
    signal s_captured   : std_logic := '0';

begin

    gen_data_readout_debug_enabled : if g_data_readout_debug = 1 generate

        proc_capture : process(p_clknet_in.cfgbus_clk40, p_master_reset_in)
        begin
            if p_master_reset_in = '1' then
                s_trigger_d1  <= '0';
                s_armed       <= '0';
                s_captured    <= '0';
                s_pipeline_fc <= c_pipeline_init;
                s_pipeline_hg <= c_pipeline_init;
                s_pipeline_lg <= c_pipeline_init;
                s_captured_fc <= c_pipeline_init;
                s_captured_hg <= c_pipeline_init;
                s_captured_lg <= c_pipeline_init;
            elsif rising_edge(p_clknet_in.cfgbus_clk40) then
                s_trigger_d1 <= p_data_readout_debug_control_in.trigger;

                -- free-running 16-deep shift, always active regardless of arm state
                s_pipeline_fc <= p_adc_readout_in.fc_data & s_pipeline_fc(0 to c_pipeline_depth-2);
                s_pipeline_hg <= p_adc_readout_in.hg_data & s_pipeline_hg(0 to c_pipeline_depth-2);
                s_pipeline_lg <= p_adc_readout_in.lg_data & s_pipeline_lg(0 to c_pipeline_depth-2);

                if p_data_readout_debug_control_in.trigger = '1' and s_trigger_d1 = '0' and s_armed = '0' then
                    -- 0->1 edge: arm, start waiting for the requested bcr count
                    s_armed    <= '1';
                    s_captured <= '0';
                elsif s_armed = '1' and p_clknet_in.bcr.count = p_data_readout_debug_control_in.bcr_number then
                    -- bcr match while armed: freeze the pipeline and disarm
                    s_captured_fc <= s_pipeline_fc;
                    s_captured_hg <= s_pipeline_hg;
                    s_captured_lg <= s_pipeline_lg;
                    s_captured    <= '1';
                    s_armed       <= '0';
                elsif p_data_readout_debug_control_in.trigger = '0' then
                    -- trigger released: clear captured (ready to arm again) and make
                    -- sure a bcr match can never land while un-armed and un-triggered
                    s_armed    <= '0';
                    s_captured <= '0';
                end if;
            end if;
        end process;

        p_data_readout_debug_status_out.captured <= s_captured;
        p_data_readout_debug_status_out.fc_data  <= s_captured_fc(to_integer(unsigned(p_data_readout_debug_control_in.sample_index)))(to_integer(unsigned(p_data_readout_debug_control_in.channel_select)));
        p_data_readout_debug_status_out.hg_data  <= s_captured_hg(to_integer(unsigned(p_data_readout_debug_control_in.sample_index)))(to_integer(unsigned(p_data_readout_debug_control_in.channel_select)));
        p_data_readout_debug_status_out.lg_data  <= s_captured_lg(to_integer(unsigned(p_data_readout_debug_control_in.sample_index)))(to_integer(unsigned(p_data_readout_debug_control_in.channel_select)));

    end generate;

    gen_data_readout_debug_disabled : if g_data_readout_debug = 0 generate
        p_data_readout_debug_status_out <= (captured => '0', hg_data => (others => '0'), lg_data => (others => '0'), fc_data => (others => '0'));
    end generate;

end behavioral;
