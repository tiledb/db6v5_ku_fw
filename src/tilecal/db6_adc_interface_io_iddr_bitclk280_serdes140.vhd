----------------------------------------------------------------------------------
-- db6_adc_interface_io_iddr_bitclk280_serdes140
--
-- 2026-09-13: g_adc_clocking_scheme=iddr280_serdes140 -- a hand-written alternative to
-- both iddr280/iddr280_clkdiv (raw IDDRE1, 1:2, registered on the undivided 280MHz bit
-- clock -- see db6_adc_interface_io_iddr_bitclk280.vhd's header: "needed an SRL pipeline
-- stage tight enough to violate timing at 280 Mbps") and hss_wizard (Xilinx's
-- high_speed_selectio_wiz IP, db6_adc_interface_io_hss.vhd), replicating the SAME
-- underlying fix the wizard uses -- native ISERDESE3 1:4 deserialization registered on
-- a divided CLKDIV, not a raw half-DDR-period capture -- without pulling in the wizard
-- IP or its internal RX FIFO/second PLL.
--
-- Why this closes the timing violation that iddr280/iddr280_clkdiv has: that violation
-- (see db6_adc_interface_decoder_iddr_bitclk280.vhd's proc_cdc_capture history, and this
-- session's placement investigation) is ISERDESE3's own fixed ~1.2ns internal CLK_B->Q
-- delay eating most of the 1.785ns half-period budget at 280MHz DDR, with 0 logic levels
-- left to optimize and 0 further placement margin found after multiple independent
-- placement strategies. DATA_WIDTH=4 native mode still uses the identical ISERDESE3
-- primitive with the identical internal delay, but only hands data to the fabric once
-- every 2 full CLK cycles (280MHz/2 = 140MHz CLKDIV, hence "_serdes140" -- 2 DDR edges
-- per CLKDIV cycle x 2 CLKDIV cycles = 4 bits/word), on a clock relationship (CLK/CLKDIV
-- from the same BUFGCE_DIV, per Xilinx's own SelectIO reference architecture -- see
-- gen_bufgce_div_reset_sync below, copied verbatim from the already-hardware-proven
-- iddr280_clkdiv pattern) that Vivado's STA treats as a full CLKDIV-period budget, not a
-- half-period one -- 4x the timing margin for the exact same fixed silicon delay.
--
-- IBUFDS/IDELAYE3 pin-level chain and the per-channel pll_adc_channel lock check are
-- otherwise unchanged from db6_adc_interface_io_iddr_bitclk280.vhd (copied verbatim) --
-- same physical pins, same db6_adc_idelay_calibration.vhd-driven tap calibration. One
-- real difference, found via a genuine DRC (REQP-1742), not a preference: each
-- IDELAYE3's CLK must be the SAME net as its paired ISERDESE3's CLKDIV, not the raw bit
-- clock -- iddr280/iddr280_clkdiv's IDELAYE3+IDDRE1 pairing has no such requirement
-- (IDDRE1 has no CLKDIV at all), so this wasn't obvious from that file. refclk_frequency
-- is 140.00 here (was 280.00) to match. Output shape (t_byteslice_sr,
-- low 4 bits meaningful per cycle) matches db6_adc_interface_io_hss.vhd's convention so
-- this scheme's decoder (db6_adc_interface_decoder_iddr_bitclk280_serdes140.vhd) could
-- be modeled closely on db6_adc_interface_decoder_iserdese.vhd's already-hardware-tested
-- word-assembly/marker-search FSM and toggle-based CDC into cfgbus_clk40, rather than
-- re-deriving that logic from scratch.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library tilecal;
use tilecal.db6_design_package.all;

library UNISIM;
use UNISIM.VComponents.all;

entity db6_adc_interface_io_iddr_bitclk280_serdes140 is
    generic (
        g_common_delay_value_fc : t_idelay_integer_array := (0,0,0,0,0,0);
        g_common_delay_value_lg : t_idelay_integer_array := (0,0,0,0,0,0);
        g_common_delay_value_hg : t_idelay_integer_array := (0,0,0,0,0,0)
    );
    port (
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;
        --inputs
        p_adc_bitclk_in   : in t_adc_clk_in;
        p_adc_frameclk_in : in t_adc_clk_in;
        p_adc_lg_data_in  : in t_adc_data_in;
        p_adc_hg_data_in  : in t_adc_data_in;

        --outputs
        p_adc_bitclk_out      : out std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_out   : out std_logic_vector(5 downto 0); -- 140MHz CLKDIV, this scheme's decoder clock
        p_adc_frameclk_out    : out t_byteslice_sr; -- low 4 bits meaningful, see header
        p_adc_lg_data_out     : out t_byteslice_sr;
        p_adc_hg_data_out     : out t_byteslice_sr;
        -- per-channel pll_adc_channel lock (see db6_adc_interface_io_iddr_bitclk280.vhd's
        -- identical p_adc_pll0_locked_out for why this lives here, not in the decoder)
        p_adc_pll0_locked_out : out std_logic_vector(5 downto 0);

        --control
        p_adc_readout_control_in : in t_adc_readout_control;

        --debug
        p_leds_out : out std_logic_vector(3 downto 0)
    );
end db6_adc_interface_io_iddr_bitclk280_serdes140;

architecture Behavioral of db6_adc_interface_io_iddr_bitclk280_serdes140 is

    signal s_bitclk_se : std_logic_vector(5 downto 0) := (others => '0');
    signal s_bitclkdiv : std_logic_vector(5 downto 0) := (others => '0');
    signal s_data_lg, s_data_hg, s_data_fc : t_byteslice_sr := (others => (others => '0'));

    signal s_lg_delay_control_array, s_hg_delay_control_array, s_fc_delay_control_array : t_adc_readout_delay_control_array := (others => c_delay_control);

    signal s_lg_idelay_count_in_from_hw, s_hg_idelay_count_in_from_hw, s_hg_idelay_count_in_from_sm, s_lg_idelay_count_in_from_sm : t_idelay_integer_array;
    signal s_fc_idelay_count_in_from_sm : t_idelay_count := (others => (others => '0'));
    signal s_lg_idelay_ctrl_load_from_sm, s_hg_idelay_ctrl_load_from_sm, s_fc_idelay_ctrl_load_from_sm : std_logic_vector(5 downto 0) := (others => '0');
    signal s_lg_idelay_ctrl_en_vtc_from_sm, s_hg_idelay_ctrl_en_vtc_from_sm, s_fc_idelay_ctrl_en_vtc_from_sm : std_logic_vector(5 downto 0) := (others => '0');

    signal s_iserdes_rst : std_logic_vector(5 downto 0) := (others => '1');
    signal s_iserdes_rst_sync0, s_iserdes_rst_sync1 : std_logic_vector(5 downto 0) := (others => '1');
    signal s_bufgce_div_ctrl_reset_async, s_bufgce_div_ctrl_reset_sync : std_logic_vector(5 downto 0) := (others => '0');

    -- per-channel bitclk280 presence/lock check -- see
    -- db6_adc_interface_io_iddr_bitclk280.vhd's identical component/usage
    component pll_adc_channel
    port (
      p_clk280_out : out std_logic;
      p_locked_out : out std_logic;
      p_clk_in     : in  std_logic
     );
    end component;
    signal s_pll_adc_channel_locked : std_logic_vector(5 downto 0);

begin

p_adc_bitclk_out    <= s_bitclk_se;
p_adc_bitclkdiv_out <= s_bitclkdiv;
p_adc_pll0_locked_out <= s_pll_adc_channel_locked;
p_adc_frameclk_out <= s_data_fc;
p_adc_lg_data_out  <= s_data_lg;
p_adc_hg_data_out  <= s_data_hg;
p_leds_out <= (others => '0');

-- differential to single-ended conversion of adc inputs from fmc (identical to
-- db6_adc_interface_io_iddr_bitclk280.vhd's gen_adc_data_diff_to_se)
gen_adc_data_diff_to_se : for i in 0 to 5 generate

    i_IBUFDS_DATA0 : IBUFDS -- ADC output Low gain
      generic map (IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_lg_delay_control_array(i).idatain,
        I  => p_adc_lg_data_in(i).p,
        IB => p_adc_lg_data_in(i).n
        );

    i_IBUFDS_DATA1 : IBUFDS -- ADC output High gain
      generic map (IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_hg_delay_control_array(i).idatain,
        I  => p_adc_hg_data_in(i).p,
        IB => p_adc_hg_data_in(i).n
        );

    i_IBUFDS_FRMCLK : IBUFDS -- ADC frame clock
      generic map (IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_fc_delay_control_array(i).idatain,
        I  => p_adc_frameclk_in(i).p,
        IB => p_adc_frameclk_in(i).n
        );

    i_IBUFGDS_BITCLK : IBUFGDS -- ADC bit clock (280MHz, 560Mbps DDR)
      generic map (IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_bitclk_se(i),
        I  => p_adc_bitclk_in(i).p,
        IB => p_adc_bitclk_in(i).n
        );

    -- CLKDIV for ISERDESE3's native 1:4 mode -- must come from the same net as CLK
    -- (here, via a dedicated BUFGCE_DIV, per Xilinx's SelectIO reference architecture --
    -- see this file's header) so Vivado's STA treats CLK->CLKDIV as a proper divided
    -- clock relationship. bufgce_divide=2: 2 CLK cycles (4 DDR edges, but only every
    -- other edge advances the SERDES's internal bit-fill counter meaningfully at
    -- DATA_WIDTH=4) fill one 4-bit word -- CLKDIV = CLK/2 = 140MHz.
    i_BUFGCE_DIV_BITCLKDIV : BUFGCE_DIV
        generic map (
            BUFGCE_DIVIDE   => 2,
            IS_CE_INVERTED  => '0',
            IS_CLR_INVERTED => '0',
            IS_I_INVERTED   => '0'
            )
        port map (
            O   => s_bitclkdiv(i),
            CE  => '1',
            CLR => s_bufgce_div_ctrl_reset_sync(i),
            I   => s_bitclk_se(i)
        );

    i_pll_adc_channel : pll_adc_channel
        port map (
            p_clk280_out => open,
            p_locked_out => s_pll_adc_channel_locked(i),
            p_clk_in     => s_bitclk_se(i)
        );

    -- 2026-09-13: p_clknet_in.adc_config.force_adc_readout_reset added alongside the
    -- existing configbus-driven reset sources -- see t_debug_control_adc_config's
    -- header comment (db6_design_package.vhd). Also resets the ISERDESE3 RST sync
    -- below (proc_iserdes_rst_sync), since it shares this same async signal.
    s_bufgce_div_ctrl_reset_async(i) <= p_master_reset_in or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_0_bit+i)) or p_clknet_in.adc_config.force_adc_readout_reset;

    -- standard 2-flop reset synchronizer for BUFGCE_DIV's CLR, on its own input clock --
    -- copied verbatim from db6_adc_interface_io_iddr_bitclk280.vhd's
    -- gen_bufgce_div_reset_sync/proc_bufgce_div_reset_sync (proven on hardware there).
    -- This primitive tolerates any fixed starting phase; only this scheme's decoder FSM
    -- needs to find word alignment, exactly like the iddr280_clkdiv/hss_wizard schemes.
    proc_bufgce_div_reset_sync : process(s_bitclk_se(i), s_bufgce_div_ctrl_reset_async(i))
        variable v_reset_sync : std_logic := '1';
    begin
        if s_bufgce_div_ctrl_reset_async(i) = '1' then
            v_reset_sync := '1';
            s_bufgce_div_ctrl_reset_sync(i) <= '1';
        elsif rising_edge(s_bitclk_se(i)) then
            s_bufgce_div_ctrl_reset_sync(i) <= v_reset_sync;
            v_reset_sync := '0';
        end if;
    end process;

end generate;

gen_adc_channels: for v_adc in 0 to 5 generate

    -- IDELAYE3 per-pin skew compensation, identical to
    -- db6_adc_interface_io_iddr_bitclk280.vhd's gen_adc_channels (var_load, driven by
    -- db6_adc_idelay_calibration.vhd via p_adc_readout_control_in)
    i_idelaye3_data_lg : idelaye3
        generic map (
            SIM_DEVICE => "ULTRASCALE",
            cascade => "none",
            delay_format => "count",
            delay_src => "idatain",
            delay_type => "var_load",
            delay_value => g_common_delay_value_lg(v_adc),
            is_clk_inverted => '0',
            is_rst_inverted => '0',
            refclk_frequency => 140.00,
            update_mode => "async"
            )
            port map (
            casc_out => s_lg_delay_control_array(v_adc).casc_out,
            cntvalueout => s_lg_delay_control_array(v_adc).cntvalueout,
            dataout => s_lg_delay_control_array(v_adc).dataout,
            casc_in => s_lg_delay_control_array(v_adc).casc_in,
            casc_return =>  s_lg_delay_control_array(v_adc).casc_return,
            ce => s_lg_delay_control_array(v_adc).ce,
            clk => s_lg_delay_control_array(v_adc).clk,
            cntvaluein => s_lg_delay_control_array(v_adc).cntvaluein,
            datain => s_lg_delay_control_array(v_adc).datain,
            en_vtc => s_lg_delay_control_array(v_adc).en_vtc,
            idatain => s_lg_delay_control_array(v_adc).idatain,
            inc => s_lg_delay_control_array(v_adc).inc,
            load => s_lg_delay_control_array(v_adc).load,
            rst => s_lg_delay_control_array(v_adc).rst
    );
    s_lg_delay_control_array(v_adc).clk <= s_bitclkdiv(v_adc);
    s_lg_delay_control_array(v_adc).rst <= '0';
    s_lg_delay_control_array(v_adc).load <= s_lg_idelay_ctrl_load_from_sm(v_adc);
    s_lg_delay_control_array(v_adc).en_vtc <= s_lg_idelay_ctrl_en_vtc_from_sm(v_adc);
    s_lg_delay_control_array(v_adc).cntvaluein <= std_logic_vector(to_unsigned(s_lg_idelay_count_in_from_sm(v_adc) + s_lg_idelay_count_in_from_hw(v_adc),9));

    i_idelaye3_data_hg : idelaye3
        generic map (
            SIM_DEVICE => "ULTRASCALE",
            cascade => "none",
            delay_format => "count",
            delay_src => "idatain",
            delay_type => "var_load",
            delay_value => g_common_delay_value_hg(v_adc),
            is_clk_inverted => '0',
            is_rst_inverted => '0',
            refclk_frequency => 140.00,
            update_mode => "async"
            )
            port map (
            casc_out => s_hg_delay_control_array(v_adc).casc_out,
            cntvalueout => s_hg_delay_control_array(v_adc).cntvalueout,
            dataout => s_hg_delay_control_array(v_adc).dataout,
            casc_in => s_hg_delay_control_array(v_adc).casc_in,
            casc_return =>  s_hg_delay_control_array(v_adc).casc_return,
            ce => s_hg_delay_control_array(v_adc).ce,
            clk => s_hg_delay_control_array(v_adc).clk,
            cntvaluein => s_hg_delay_control_array(v_adc).cntvaluein,
            datain => s_hg_delay_control_array(v_adc).datain,
            en_vtc => s_hg_delay_control_array(v_adc).en_vtc,
            idatain => s_hg_delay_control_array(v_adc).idatain,
            inc => s_hg_delay_control_array(v_adc).inc,
            load => s_hg_delay_control_array(v_adc).load,
            rst => s_hg_delay_control_array(v_adc).rst
    );
    s_hg_delay_control_array(v_adc).clk <= s_bitclkdiv(v_adc);
    s_hg_delay_control_array(v_adc).rst <= '0';
    s_hg_delay_control_array(v_adc).load <= s_hg_idelay_ctrl_load_from_sm(v_adc);
    s_hg_delay_control_array(v_adc).en_vtc <= s_hg_idelay_ctrl_en_vtc_from_sm(v_adc);
    s_hg_delay_control_array(v_adc).cntvaluein <= std_logic_vector(to_unsigned(s_hg_idelay_count_in_from_sm(v_adc) + s_hg_idelay_count_in_from_hw(v_adc),9));

    i_idelaye3_data_fc : idelaye3
        generic map (
            SIM_DEVICE => "ULTRASCALE",
            cascade => "none",
            delay_format => "count",
            delay_src => "idatain",
            delay_type => "var_load",
            delay_value => g_common_delay_value_fc(v_adc),
            is_clk_inverted => '0',
            is_rst_inverted => '0',
            refclk_frequency => 140.00,
            update_mode => "async"
            )
            port map (
            casc_out => s_fc_delay_control_array(v_adc).casc_out,
            cntvalueout => s_fc_delay_control_array(v_adc).cntvalueout,
            dataout => s_fc_delay_control_array(v_adc).dataout,
            casc_in => s_fc_delay_control_array(v_adc).casc_in,
            casc_return =>  s_fc_delay_control_array(v_adc).casc_return,
            ce => s_fc_delay_control_array(v_adc).ce,
            clk => s_fc_delay_control_array(v_adc).clk,
            cntvaluein => s_fc_delay_control_array(v_adc).cntvaluein,
            datain => s_fc_delay_control_array(v_adc).datain,
            en_vtc => s_fc_delay_control_array(v_adc).en_vtc,
            idatain => s_fc_delay_control_array(v_adc).idatain,
            inc => s_fc_delay_control_array(v_adc).inc,
            load => s_fc_delay_control_array(v_adc).load,
            rst => s_fc_delay_control_array(v_adc).rst
    );
    s_fc_delay_control_array(v_adc).clk <= s_bitclkdiv(v_adc);
    s_fc_delay_control_array(v_adc).rst <= '0';
    s_fc_delay_control_array(v_adc).load <= s_fc_idelay_ctrl_load_from_sm(v_adc);
    s_fc_delay_control_array(v_adc).en_vtc <= s_fc_idelay_ctrl_en_vtc_from_sm(v_adc);
    s_fc_delay_control_array(v_adc).cntvaluein <= s_fc_idelay_count_in_from_sm(v_adc);

    -- native ISERDESE3, DATA_WIDTH=4, registered on CLKDIV (140MHz) instead of a raw
    -- half-DDR-period capture -- see this file's header for why this avoids the
    -- iddr280/iddr280_clkdiv violation. FIFO_ENABLE=FALSE: no internal RX FIFO/second
    -- clock domain (unlike hss_wizard) -- CLKDIV IS this scheme's fabric-facing clock,
    -- consumed directly by db6_adc_interface_decoder_iddr_bitclk280_serdes140.vhd.
    -- is_clk_inverted/is_clk_b_inverted mirrors db6_adc_interface_io_iddr_bitclk280.vhd's
    -- IDDRE1 usage (c/cb driven by the same net, internal inversion generic instead of
    -- two physically different clock nets).
    i_iserdese3_lg : ISERDESE3
        generic map (
            DATA_WIDTH => 4,
            DDR_CLK_EDGE => "OPPOSITE_EDGE",
            FIFO_ENABLE => "FALSE",
            FIFO_SYNC_MODE => "FALSE",
            IS_CLK_B_INVERTED => '1',
            IS_CLK_INVERTED => '0',
            IS_RST_INVERTED => '0',
            SIM_DEVICE => "ULTRASCALE"
            )
        port map (
            Q => s_data_lg(v_adc),
            CLK => s_bitclk_se(v_adc),
            CLK_B => s_bitclk_se(v_adc),
            CLKDIV => s_bitclkdiv(v_adc),
            D => s_lg_delay_control_array(v_adc).dataout,
            RST => s_iserdes_rst(v_adc),
            FIFO_RD_CLK => '0',
            FIFO_RD_EN => '0',
            FIFO_EMPTY => open,
            INTERNAL_DIVCLK => open
        );

    i_iserdese3_hg : ISERDESE3
        generic map (
            DATA_WIDTH => 4,
            DDR_CLK_EDGE => "OPPOSITE_EDGE",
            FIFO_ENABLE => "FALSE",
            FIFO_SYNC_MODE => "FALSE",
            IS_CLK_B_INVERTED => '1',
            IS_CLK_INVERTED => '0',
            IS_RST_INVERTED => '0',
            SIM_DEVICE => "ULTRASCALE"
            )
        port map (
            Q => s_data_hg(v_adc),
            CLK => s_bitclk_se(v_adc),
            CLK_B => s_bitclk_se(v_adc),
            CLKDIV => s_bitclkdiv(v_adc),
            D => s_hg_delay_control_array(v_adc).dataout,
            RST => s_iserdes_rst(v_adc),
            FIFO_RD_CLK => '0',
            FIFO_RD_EN => '0',
            FIFO_EMPTY => open,
            INTERNAL_DIVCLK => open
        );

    i_iserdese3_fc : ISERDESE3
        generic map (
            DATA_WIDTH => 4,
            DDR_CLK_EDGE => "OPPOSITE_EDGE",
            FIFO_ENABLE => "FALSE",
            FIFO_SYNC_MODE => "FALSE",
            IS_CLK_B_INVERTED => '1',
            IS_CLK_INVERTED => '0',
            IS_RST_INVERTED => '0',
            SIM_DEVICE => "ULTRASCALE"
            )
        port map (
            Q => s_data_fc(v_adc),
            CLK => s_bitclk_se(v_adc),
            CLK_B => s_bitclk_se(v_adc),
            CLKDIV => s_bitclkdiv(v_adc),
            D => s_fc_delay_control_array(v_adc).dataout,
            RST => s_iserdes_rst(v_adc),
            FIFO_RD_CLK => '0',
            FIFO_RD_EN => '0',
            FIFO_EMPTY => open,
            INTERNAL_DIVCLK => open
        );

    -- IDDRE1's "tie r/rst low, never reset" convention (copied here originally) does NOT
    -- apply to ISERDESE3: unlike IDDRE1's plain DDR flip-flop pair, native ISERDESE3
    -- SERDES mode has an internal word-boundary/bit-fill state machine that per UG571
    -- must be held in RST through configuration and released SYNCHRONOUSLY TO CLKDIV
    -- only after CLK/CLKDIV are running -- otherwise Q never produces valid data (this
    -- was the root cause of the 2026-09-13 hardware bring-up symptom: all-zero data,
    -- locked=0, missalignment=1 on every channel). Async-assert on the same master-reset
    -- condition driving this channel's BUFGCE_DIV CLR, 2-flop synchronous release on
    -- CLKDIV once it is confirmed toggling.
    proc_iserdes_rst_sync : process(s_bitclkdiv(v_adc), s_bufgce_div_ctrl_reset_async(v_adc))
    begin
        if s_bufgce_div_ctrl_reset_async(v_adc) = '1' then
            s_iserdes_rst_sync0(v_adc) <= '1';
            s_iserdes_rst_sync1(v_adc) <= '1';
        elsif rising_edge(s_bitclkdiv(v_adc)) then
            s_iserdes_rst_sync0(v_adc) <= '0';
            s_iserdes_rst_sync1(v_adc) <= s_iserdes_rst_sync0(v_adc);
        end if;
    end process;

    s_iserdes_rst(v_adc) <= s_iserdes_rst_sync1(v_adc);

    s_lg_idelay_count_in_from_sm(v_adc) <= to_integer(unsigned(p_adc_readout_control_in.lg_idelay_count(v_adc)));
    s_hg_idelay_count_in_from_sm(v_adc) <= to_integer(unsigned(p_adc_readout_control_in.hg_idelay_count(v_adc)));
    s_fc_idelay_count_in_from_sm(v_adc) <= p_adc_readout_control_in.fc_idelay_count(v_adc);
    s_lg_idelay_ctrl_load_from_sm(v_adc) <= p_adc_readout_control_in.lg_idelay_load(v_adc);
    s_hg_idelay_ctrl_load_from_sm(v_adc) <= p_adc_readout_control_in.hg_idelay_load(v_adc);
    s_fc_idelay_ctrl_load_from_sm(v_adc) <= p_adc_readout_control_in.fc_idelay_load(v_adc);
    s_lg_idelay_ctrl_en_vtc_from_sm(v_adc) <= p_adc_readout_control_in.lg_idelay_en_vtc(v_adc);
    s_hg_idelay_ctrl_en_vtc_from_sm(v_adc) <= p_adc_readout_control_in.hg_idelay_en_vtc(v_adc);
    s_fc_idelay_ctrl_en_vtc_from_sm(v_adc) <= p_adc_readout_control_in.fc_idelay_en_vtc(v_adc);
    s_lg_idelay_count_in_from_hw(v_adc) <= 0;
    s_hg_idelay_count_in_from_hw(v_adc) <= 0;

end generate;

end Behavioral;
