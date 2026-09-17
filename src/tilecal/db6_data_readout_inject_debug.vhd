----------------------------------------------------------------------------------
-- db6_data_readout_inject_debug
--
-- 2026-09-14: pulse-injection debug module for the adc readout data path. When
-- enabled, replaces the live hg_data/lg_data of every channel (t_adc_data, all 6
-- channels get the same injected sample -- this is a shared debug waveform, not a
-- per-channel one) with a value read out of a 3564-deep (c_lhc_bunches_between_bcr)
-- True Dual Port RAM, addressed by the free-running p_clknet_in.bcr.count -- so the
-- injected waveform repeats once per orbit, in lock-step with the real beam-crossing
-- pattern the GBT encoder timestamps its data against (see db6_gbt_encoder_formatter).
--
--   * port a is the always-on playback port: continuously reads
--     ram[bcr.count mod 3564] every cfgbus_clk40 cycle, read-only.
--   * port b is the manual read/write access port, shared between the
--     cfb_db_inject_pulse register (db_reg_rx/tx, host side) and
--     p_data_readout_inject_control_in (probe_out19, vio_db_debug side) -- a 0->1
--     edge on either side's ram_we writes that side's ram_wdata at its ram_addr;
--     between writes, port b's address is whichever side is driving a nonzero
--     ram_addr (same "don't drive both at once" idiom as s_gbtx_reg_readback_address
--     in db6v5_top.vhd), so doutb tracks that commanded address for readback.
--   * each stored word's 12 MSBs (13 downto 2, matching real ADC data's own
--     "(13 downto 2)" truncation in db6_gbt_encoder_adc_data) are a SIGNED
--     (two's complement) offset from p_data_readout_inject_control_in.pedestal --
--     a negative stored value reads back as an undershoot below the pedestal
--     baseline. The sum saturates to the unsigned 12 bit range (0..4095) rather
--     than wrapping.
--   * enable is the OR of cfb_db_inject_pulse's own enable bit and probe_out19's
--     enable bit -- either source can turn injection on.
--
-- g_data_readout_inject_debug gates all of the above: when 0, no injection logic
-- (and no block ram) is built -- hg_data/lg_data/status pass straight through.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_data_readout_inject_debug is
    generic (
        g_data_readout_inject_debug : natural := 0 --! 1 = build the injection logic + ram, 0 = disabled (pure passthrough)
    );
    port (
        p_master_reset_in                    : in  std_logic;
        p_clknet_in                          : in  t_db_clknet; --! cfgbus_clk40 used as the ram/pedestal clock; bcr.count is port a's free-running playback address
        p_db_reg_rx_in                       : in  t_db_reg_rx; --! cfb_db_inject_pulse: enable/ram_we/ram_wdata/ram_addr, see db6_design_package.vhd
        p_data_readout_inject_control_in     : in  t_debug_control_data_readout_inject; --! vio-driven enable/pedestal/ram_addr/ram_wdata/ram_we
        p_adc_readout_in                     : in  t_adc_readout; --! source hg_data/lg_data (passthrough when disabled/not enabled)
        p_hg_data_out                        : out t_adc_data; --! injected (all 6 channels, same value) or passthrough p_adc_readout_in.hg_data
        p_lg_data_out                        : out t_adc_data; --! injected (all 6 channels, same value) or passthrough p_adc_readout_in.lg_data
        p_data_readout_inject_status_out     : out t_data_readout_inject_debug_status --! vio-facing active flag + port b readback
    );
end db6_data_readout_inject_debug;

architecture behavioral of db6_data_readout_inject_debug is

    -- Vivado Block Memory Generator core, True Dual Port RAM, 14 bit wide, 3564 deep
    -- (c_lhc_bunches_between_bcr), no output register on either port (single-cycle
    -- read latency), loaded from constraints/db7_blk_mem_data_readout_inject.coe --
    -- generate with the same settings as blk_mem_gbtx_regs (src/ip/vivado_2025_2/),
    -- just True Dual Port / width 14 / depth 3564 / that coe as the init file.
    component blk_mem_data_readout_inject
        port (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(11 downto 0);
            dina  : in  std_logic_vector(13 downto 0);
            douta : out std_logic_vector(13 downto 0);
            clkb  : in  std_logic;
            web   : in  std_logic_vector(0 downto 0);
            addrb : in  std_logic_vector(11 downto 0);
            dinb  : in  std_logic_vector(13 downto 0);
            doutb : out std_logic_vector(13 downto 0)
        );
    end component;

    signal s_blk_mem : t_blk_mem_data_readout_inject;

    signal s_reg_ram_we_d1, s_vio_ram_we_d1 : std_logic := '0';
    signal s_enable_eff                     : std_logic := '0';
    signal s_injected_word                  : std_logic_vector(13 downto 0) := (others => '0');

begin

    gen_data_readout_inject_debug_enabled : if g_data_readout_inject_debug = 1 generate

        i_blk_mem_data_readout_inject : blk_mem_data_readout_inject
            port map(
                clka  => p_clknet_in.cfgbus_clk40,
                wea   => "0",
                addra => p_clknet_in.bcr.count(11 downto 0),
                dina  => (others => '0'),
                douta => s_blk_mem.douta,
                clkb  => p_clknet_in.cfgbus_clk40,
                web   => s_blk_mem.web,
                addrb => s_blk_mem.addrb,
                dinb  => s_blk_mem.dinb,
                doutb => s_blk_mem.doutb
            );

        s_enable_eff <= p_db_reg_rx_in(cfb_db_inject_pulse)(c_db_inject_pulse_enable_bit) or p_data_readout_inject_control_in.enable;

        proc_ram_port_b_access : process(p_clknet_in.cfgbus_clk40, p_master_reset_in)
        begin
            if p_master_reset_in = '1' then
                s_reg_ram_we_d1 <= '0';
                s_vio_ram_we_d1 <= '0';
                s_blk_mem.web   <= "0";
                s_blk_mem.addrb <= (others => '0');
                s_blk_mem.dinb  <= (others => '0');
            elsif rising_edge(p_clknet_in.cfgbus_clk40) then
                s_reg_ram_we_d1 <= p_db_reg_rx_in(cfb_db_inject_pulse)(c_db_inject_pulse_ram_we_bit);
                s_vio_ram_we_d1 <= p_data_readout_inject_control_in.ram_we;

                if p_db_reg_rx_in(cfb_db_inject_pulse)(c_db_inject_pulse_ram_we_bit) /= s_reg_ram_we_d1 then
                    -- register side toggled: one-cycle write, priority over the vio side
                    s_blk_mem.web   <= "1";
                    s_blk_mem.addrb <= p_db_reg_rx_in(cfb_db_inject_pulse)(c_db_inject_pulse_ram_addr_msb_bit downto c_db_inject_pulse_ram_addr_lsb_bit);
                    s_blk_mem.dinb  <= p_db_reg_rx_in(cfb_db_inject_pulse)(c_db_inject_pulse_ram_wdata_msb_bit downto c_db_inject_pulse_ram_wdata_lsb_bit);
                elsif p_data_readout_inject_control_in.ram_we = '1' and s_vio_ram_we_d1 = '0' then
                    -- vio side 0->1 edge: one-cycle write
                    s_blk_mem.web   <= "1";
                    s_blk_mem.addrb <= p_data_readout_inject_control_in.ram_addr;
                    s_blk_mem.dinb  <= p_data_readout_inject_control_in.ram_wdata;
                else
                    s_blk_mem.web   <= "0";
                    -- no write this cycle: park port b's address at whichever side is
                    -- driving it nonzero, so doutb reflects the commanded address
                    -- (same idiom as s_gbtx_reg_readback_address in db6v5_top.vhd)
                    s_blk_mem.addrb <= p_db_reg_rx_in(cfb_db_inject_pulse)(c_db_inject_pulse_ram_addr_msb_bit downto c_db_inject_pulse_ram_addr_lsb_bit)
                                        or p_data_readout_inject_control_in.ram_addr;
                end if;
            end if;
        end process;

        -- signed (two's complement) 12 bit ram sample + 13 bit unsigned pedestal,
        -- saturating to the unsigned 12 bit range -- widened to 16 bits so the sum
        -- (up to 2047+8191=10238) never overflows before the saturation check.
        proc_pedestal_add : process(p_clknet_in.cfgbus_clk40, p_master_reset_in)
            variable v_sum : signed(15 downto 0);
        begin
            if p_master_reset_in = '1' then
                s_injected_word <= (others => '0');
            elsif rising_edge(p_clknet_in.cfgbus_clk40) then
                v_sum := resize(signed(s_blk_mem.douta(13 downto 2)), 16)
                       + resize(signed('0' & p_data_readout_inject_control_in.pedestal), 16);
                if v_sum < 0 then
                    s_injected_word <= (others => '0');
                elsif v_sum > 4095 then
                    s_injected_word <= "111111111111" & "00"; -- saturated: 4095 in the top 12 bits
                else
                    s_injected_word <= std_logic_vector(v_sum(11 downto 0)) & "00";
                end if;
            end if;
        end process;

        gen_channel_mux : for ch in 0 to 5 generate
            p_hg_data_out(ch) <= s_injected_word when s_enable_eff = '1' else p_adc_readout_in.hg_data(ch);
            p_lg_data_out(ch) <= s_injected_word when s_enable_eff = '1' else p_adc_readout_in.lg_data(ch);
        end generate;

        p_data_readout_inject_status_out.active      <= s_enable_eff;
        p_data_readout_inject_status_out.ram_rdata   <= s_blk_mem.doutb;
        -- 2026-09-17: the live word actually going out on hg_data/lg_data this cycle
        -- (zero when injection isn't enabled, matching every channel's real output
        -- in that case) -- see t_data_readout_inject_debug_status's header comment.
        p_data_readout_inject_status_out.word_active <= s_injected_word when s_enable_eff = '1' else (others => '0');

    end generate;

    gen_data_readout_inject_debug_disabled : if g_data_readout_inject_debug = 0 generate
        p_hg_data_out                    <= p_adc_readout_in.hg_data;
        p_lg_data_out                    <= p_adc_readout_in.lg_data;
        p_data_readout_inject_status_out <= (active => '0', ram_rdata => (others => '0'), word_active => (others => '0'));
    end generate;

end behavioral;
