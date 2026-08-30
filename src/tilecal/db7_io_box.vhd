----------------------------------------------------------------------------------
-- Module Name: db7_io_box - rtl
-- Additional Comments:
--   IO isolation boundary. Sits directly under db6v5_top: every signal that
--   touches a physical top-level pad or an IO/GT/clocking-primitive-owning IP
--   core is meant to route through here, so the rest of the design is pure
--   fabric logic and can later be triplicated (TMR) without fighting over
--   physical IO primitives.
--
--   STATUS: staged migration, see ~/.claude/plans/peppy-yawning-platypus.md.
--   Covered so far:
--     - mainboard-driver serial IO (ssel/sclk/sdata OBUFDS/IBUFDS)
--     - ADC interface IO (IBUFDS/IBUFGDS/IDELAYE3/IDDRE1, bitclk280 variant
--       only -- matches the only configuration actually instantiated by
--       db6_mainboard_interface today; the bitclk240 and ISERDES variants are
--       unused alternates, not migrated)
--     - CFGBUS IO (IBUFDS/IDELAYE3/IDDRE1)
--     - CIS HSS IO (hss_cis SelectIO wizard IP)
--     - GT/MGT (SFP/GBTx): db6_mgt (GTHE3/GTHE4 wizard IP + differential rx/tx
--       pads), single instance (collapses the two mutually-exclusive, identical
--       instantiations db6_gbt_gth_interface.vhd used to hold, one per
--       g_enable_simple_gbt_encoder branch)
--     - Clock wizards: only the GT refclk IBUFDS_GTE3, the oscillator
--       IBUFDS+pll_osc_clk, and the CFGBUS-local IBUFDS were actually active in
--       db6_clock_interface.vhd -- every other clocking-wizard component
--       declared there (mmcm_gbt40_db/cfgbus/db6, mmcm_gth_refclk, mmcm_osc_clk)
--       was already dead/commented-out code, not migrated. pll_gbt_wordclk was
--       NOT migrated either: it clocks off an already-internal GT word clock
--       (p_clkin_in.db6_gbt_bank.mgt_txwordclk_o), never touches a pad.
--     - XADC: system_management IP (analog pads + i2c inout owned directly by
--       the IP itself, no intervening logic to preserve)
--     - I2C inout buses (SFP x2, GBTx, integrator x2): each bit-banged master
--       (db7_simple_i2c_master.vhd, db6_i2c_master.vhd, db6_integrator_i2c_master.vhd)
--       already isolated its own IOBUF internally with clean O/I/T signals, so this
--       was a mechanical extraction, not a logic change -- 5 IOBUF pairs total.
--     - Proasic JTAG pads: db6_proasic_jtag_driver was never wired up (dead file,
--       now removed) and the mainboard jtag driver was misused to toggle these
--       pins instead. With no driver left, the pads are simply held tri-stated
--       here.
--
--   This completes the staged db7_io_box migration.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library gbt;
use gbt.all;
use gbt.gbt_bank_package.all;
use gbt.vendor_specific_gbt_bank_package.all;
library tilecal;
use tilecal.db6_design_package.all;

entity db7_io_box is
    generic (
        g_num_gth_links    : integer := 2;
        g_num_gth_ref_clks : integer := 1;
        g_clocking_mode : integer := 0 -- 0/1/2 -> iddr (see db6_adc_interface_io_iddr_bitclk280), 3 -> selectio wizard (hss_adc). Must match db6_mainboard_interface's.
    );
    port (
        -- internal (non-pad) signals needed by the wrapped IO files
        p_clknet_in    : in t_db_clknet;
        p_db_reg_rx_in : in t_db_reg_rx;

        -- mainboard driver serial bus (ssel/sclk/sdata) -- pads
        p_ssel_out  : out t_mb_diff_pair;
        p_sclk_out  : out t_mb_diff_pair;
        p_sdata_out : out t_mb_diff_pair;
        p_sdata_in  : in  t_mb_diff_pair;

        -- mainboard driver serial bus -- plain logic side (to/from db6_mainboard_driver)
        p_mb_driver_ssel_in      : in  t_mb_std_logic;
        p_mb_driver_sclk_in      : in  t_mb_std_logic;
        p_mb_driver_sdata_tx_in  : in  t_mb_std_logic;
        p_mb_driver_sdata_rx_out : out t_mb_std_logic;

        -- ADC interface -- pads (bitclk280 variant)
        p_adc_master_reset_in : in std_logic;
        p_adc_bitclk_in   : in t_adc_clk_in;
        p_adc_frameclk_in : in t_adc_clk_in;
        -- g_clocking_mode=3 (hss) only: hss_adc PLL/RIU sharing placeholder pins,
        -- one bit per channel (see db6_adc_interface_io_hss.vhd header).
        p_adc_hss_aux0_in : in std_logic_vector(5 downto 0);
        p_adc_hss_aux1_in : in std_logic_vector(5 downto 0);
        p_adc_hss_aux2_in : in std_logic_vector(5 downto 0);
        p_adc_lg_data_in  : in t_adc_data_in;
        p_adc_hg_data_in  : in t_adc_data_in;
        -- GBTx-forwarded 40MHz/80MHz clocks, per bank, deserialized as data on the
        -- same per-channel hss_adc instance (see db6_adc_interface_io_hss.vhd header)
        p_gbtx_clk40_b68_in : in t_diff_pair;
        p_gbtx_clk40_b67_in : in t_diff_pair;
        p_gbtx_clk40_b66_in : in t_diff_pair;
        p_gbtx_clk40_b47_in : in t_diff_pair;
        p_gbtx_clk40_b46_in : in t_diff_pair;
        p_gbtx_clk40_b44_in : in t_diff_pair;
        p_gbtx_clk80_b68_in : in t_diff_pair;
        p_gbtx_clk80_b67_in : in t_diff_pair;
        p_gbtx_clk80_b66_in : in t_diff_pair;
        p_gbtx_clk80_b47_in : in t_diff_pair;
        p_gbtx_clk80_b46_in : in t_diff_pair;
        p_gbtx_clk80_b44_in : in t_diff_pair;
        p_gbtx_clk40_data_out : out t_byteslice_sr;
        p_gbtx_clk80_data_out : out t_byteslice_sr;

        -- ADC interface -- plain logic side (to db6_adc_interface). frameclk/lg/hg use
        -- separate ports per readout mode since iddr (2 bits/channel) and hss
        -- (8-bit container, 4 meaningful bits/channel) aren't the same width; only one
        -- set is actually driven, per g_clocking_mode (see db6_adc_interface_io_iddr_bitclk280
        -- / db6_adc_interface_io_hss).
        p_adc_bitclk_out          : out std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_out       : out std_logic_vector(5 downto 0);
        p_frame_missalignment_out : out std_logic_vector(5 downto 0); -- iddr only
        p_adc_frameclk_out        : out t_bitslice_sr;  -- iddr only
        p_adc_lg_data_out         : out t_bitslice_sr;  -- iddr only
        p_adc_hg_data_out         : out t_bitslice_sr;  -- iddr only

        -- g_clocking_mode=3 (hss) only: closed-loop resync between io_hss (here) and
        -- db6_adc_interface_decoder_iserdese (in db6_mainboard_interface) -- the decoder
        -- tracks frame alignment from the marker bits and reports it back here.
        -- ctrl_reset_from_sm is tied '0' by db6_adc_interface_io_hss (hss_adc uses
        -- RX_DELAY_TYPE=FIXED, so there's no idelay resync state machine driving it).
        p_adc_frame_missalignment_in : in  std_logic_vector(5 downto 0);
        p_adc_ctrl_reset_from_sm_out : out std_logic_vector(5 downto 0);
        p_adc_frameclk_iserdese_out  : out t_byteslice_sr;
        p_adc_lg_data_iserdese_out   : out t_byteslice_sr;
        p_adc_hg_data_iserdese_out   : out t_byteslice_sr;
        -- g_clocking_mode=3 (hss) only: per-channel hss_adc internal status for
        -- hardware debug (see db6_adc_interface_io_hss.vhd)
        p_adc_pll0_locked_out     : out std_logic_vector(5 downto 0);
        p_adc_rst_seq_done_out    : out std_logic_vector(5 downto 0);
        p_adc_fifo_data_valid_out : out std_logic_vector(5 downto 0);

        -- CFGBUS local -- pad
        p_cfgbus_master_reset_in : in std_logic;
        p_cfgbus_data_local_in   : in t_cfgbus_data_in;

        -- CFGBUS local -- plain logic side (to db6_gbtx_interface / db6_cfgbus_interface)
        p_cfgbus_bitslice_local_out : out t_cfgbus_bitslice;

        -- CIS interface -- pads
        p_cis_master_reset_in : in std_logic;
        p_tph_out : out t_mb_diff_pair;
        p_tpl_out : out t_mb_diff_pair;

        -- CIS interface -- plain logic side (to/from db6_cis_driver_hss)
        p_tph_in : in t_mb_std_logic;
        p_tpl_in : in t_mb_std_logic;

        -- GT/MGT (SFP/GBTx) -- pads
        p_tx_sfp_out           : out t_diff_pair_vector(1 downto 0);
        p_rx_sfp_in            : in  t_diff_pair_vector(0 downto 0);
        p_rx_gbtx_from_fpga_in : in  t_diff_pair_vector(0 downto 0);

        -- GT/MGT -- plain logic side (to/from db6_gbt_gth_interface, via db6_sfp_interface)
        p_ku_mgt_out            : out t_ku_mgt;
        p_mgt_txusrclk_out      : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_rxusrclk_out      : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_txreset_in        : in  std_logic_vector(1 to g_num_gth_links);
        p_mgt_rxreset_in        : in  std_logic_vector(1 to g_num_gth_links);
        p_mgt_txready_out       : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_rxready_out       : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_headerlocked_out  : out std_logic_vector(1 to g_num_gth_links);
        p_mgt_rstcnt_out        : out gbt_reg8_A(1 to g_num_gth_links);
        p_mgt_autorsten_in      : in  std_logic_vector(1 to g_num_gth_links);
        p_mgt_autorstoneven_in  : in  std_logic_vector(1 to g_num_gth_links);
        p_mgt_usrword_in        : in  word_mxnbit_A(1 to g_num_gth_links);
        p_mgt_devspec_i_in      : in  mgtDeviceSpecific_i_R;
        p_mgt_devspec_o_out     : out mgtDeviceSpecific_o_R;

        -- Clock wizards -- pads
        p_osc_clk_in                : in t_diff_pair;
        p_gth_refclk_gbtx_local_in  : in t_diff_pair_vector(g_num_gth_ref_clks - 1 downto 0);
        p_gbt_cfgbus_clk40_local_in : in t_diff_pair;

        -- Clock wizards -- plain logic side (to db6_clock_interface)
        p_gth_refclk_local_out   : out std_logic_vector(g_num_gth_ref_clks - 1 downto 0);
        p_osc_clk100_out         : out std_logic;
        p_osc_clk40_out          : out std_logic;
        p_osc_clk200_out         : out std_logic;
        p_osc_locked_out         : out std_logic;
        p_cfgbus_clk40_local_out : out std_logic;

        -- XADC -- pads
        p_xadc_analog_in : in    t_xadc_analog_in;
        p_xadc_i2c_inout : inout t_i2c_bus;

        -- XADC -- plain logic side (to/from db6_system_management_interface)
        p_xadc_control_in  : in  t_xadc_control;
        p_xadc_control_out : out t_xadc_control;

        -- I2C -- pads
        p_sfp_i2c_scl_inout        : inout std_logic_vector(1 downto 0);
        p_sfp_i2c_sda_inout        : inout std_logic_vector(1 downto 0);
        p_gbtx_i2c_scl_inout       : inout std_logic_vector(0 downto 0);
        p_gbtx_i2c_sda_inout       : inout std_logic_vector(0 downto 0);
        p_integrator_sda_inout     : inout t_mb_std_logic;
        p_integrator_scl_inout     : inout t_mb_std_logic;

        -- I2C -- plain logic side (to/from the bit-banged masters)
        p_sfp_sda_drive_in  : in  std_logic_vector(1 downto 0);
        p_sfp_sda_tri_in    : in  std_logic_vector(1 downto 0);
        p_sfp_sda_read_out  : out std_logic_vector(1 downto 0);
        p_sfp_scl_drive_in  : in  std_logic_vector(1 downto 0);
        p_sfp_scl_tri_in    : in  std_logic_vector(1 downto 0);
        p_sfp_scl_read_out  : out std_logic_vector(1 downto 0);
        p_gbtx_sda_drive_in : in  std_logic_vector(0 downto 0);
        p_gbtx_sda_tri_in   : in  std_logic_vector(0 downto 0);
        p_gbtx_sda_read_out : out std_logic_vector(0 downto 0);
        p_gbtx_scl_drive_in : in  std_logic_vector(0 downto 0);
        p_gbtx_scl_tri_in   : in  std_logic_vector(0 downto 0);
        p_gbtx_scl_read_out : out std_logic_vector(0 downto 0);
        p_integrator_sda_drive_in : in  t_mb_std_logic;
        p_integrator_sda_tri_in   : in  t_mb_std_logic;
        p_integrator_sda_read_out : out t_mb_std_logic;
        p_integrator_scl_drive_in : in  t_mb_std_logic;
        p_integrator_scl_tri_in   : in  t_mb_std_logic;
        p_integrator_scl_read_out : out t_mb_std_logic;

        -- Proasic JTAG -- pads. Driver removed; held tri-stated (floating).
        p_proasic_tms_out  : out std_logic;
        p_proasic_tck_out  : out std_logic;
        p_proasic_tdi_out  : out std_logic;
        p_proasic_tdo_in   : in  std_logic;
        p_proasic_trst_out : out std_logic
    );
end db7_io_box;

architecture rtl of db7_io_box is

    -- db6_adc_interface_io_iddr_bitclk280's p_adc_readout_control_in port is dead code
    -- upstream (never referenced in that file's architecture body) -- give it a legal
    -- connection without threading the real control record through this boundary.
    signal s_adc_readout_control_unused : t_adc_readout_control;

    -- GT/MGT: db6_mgt's device-specific in/out records. rx_p/rx_n (in) and tx_p/tx_n
    -- (out) are the actual differential pad connections; everything else in these
    -- records is pure logic config supplied by db6_gbt_gth_interface via
    -- p_mgt_devspec_i_in / read back out via p_mgt_devspec_o_out.
    signal s_mgt_devspec_i : mgtDeviceSpecific_i_R;
    signal s_mgt_devspec_o : mgtDeviceSpecific_o_R;
    signal s_mgt_diff_pair_rx, s_mgt_diff_pair_tx : t_mgt_diff_pair;

    -- Clock wizards: pll_osc_clk's DRP is tied off (no dynamic reconfig in this
    -- design, matches db6_clock_interface.vhd's original hard-tied '0'/(others=>'0')).
    signal s_osc_clk100 : std_logic;
    signal s_pll_osc_daddr : std_logic_vector(6 downto 0) := (others => '0');
    signal s_pll_osc_din   : std_logic_vector(15 downto 0) := (others => '0');

    -- Matches the component declaration in db6_clock_interface.vhd exactly (Vivado-managed IP).
    component pll_osc_clk
    port (
      p_clk40_out  : out std_logic;
      p_clk200_out : out std_logic;
      p_daddr_in   : in  std_logic_vector(6 downto 0);
      p_dclk_in    : in  std_logic;
      p_den_in     : in  std_logic;
      p_din_in     : in  std_logic_vector(15 downto 0);
      p_dout_out   : out std_logic_vector(15 downto 0);
      p_dwe_in     : in  std_logic;
      p_drdy_out   : out std_logic;
      p_reset_in   : in  std_logic;
      p_locked_out : out std_logic;
      p_clk_in     : in  std_logic
    );
    end component;

    -- Matches the component declaration db6_system_management_interface.vhd used to
    -- hold, exactly (Vivado-managed IP).
    component system_management
    port (
        di_in : in std_logic_vector(15 downto 0);
        daddr_in : in std_logic_vector(7 downto 0);
        den_in : in std_logic;
        dwe_in : in std_logic;
        drdy_out : out std_logic;
        do_out : out std_logic_vector(15 downto 0);
        dclk_in : in std_logic;
        reset_in : in std_logic;
        vp : in std_logic;
        vn : in std_logic;
        vauxp0 : in std_logic; vauxn0 : in std_logic;
        vauxp1 : in std_logic; vauxn1 : in std_logic;
        vauxp2 : in std_logic; vauxn2 : in std_logic;
        vauxp3 : in std_logic; vauxn3 : in std_logic;
        vauxp4 : in std_logic; vauxn4 : in std_logic;
        vauxp5 : in std_logic; vauxn5 : in std_logic;
        vauxp6 : in std_logic; vauxn6 : in std_logic;
        vauxp7 : in std_logic; vauxn7 : in std_logic;
        vauxp8 : in std_logic; vauxn8 : in std_logic;
        vauxp9 : in std_logic; vauxn9 : in std_logic;
        vauxp10 : in std_logic; vauxn10 : in std_logic;
        vauxp11 : in std_logic; vauxn11 : in std_logic;
        vauxp12 : in std_logic; vauxn12 : in std_logic;
        vauxp13 : in std_logic; vauxn13 : in std_logic;
        vauxp14 : in std_logic; vauxn14 : in std_logic;
        vauxp15 : in std_logic; vauxn15 : in std_logic;
        user_temp_alarm_out : out std_logic;
        vccint_alarm_out : out std_logic;
        vccaux_alarm_out : out std_logic;
        user_supply0_alarm_out : out std_logic;
        user_supply1_alarm_out : out std_logic;
        user_supply2_alarm_out : out std_logic;
        ot_out : out std_logic;
        channel_out : out std_logic_vector(5 downto 0);
        muxaddr_out : out std_logic_vector(4 downto 0);
        eoc_out : out std_logic;
        vbram_alarm_out : out std_logic;
        alarm_out : out std_logic;
        eos_out : out std_logic;
        busy_out : out std_logic;
        jtaglocked_out : out std_logic;
        jtagmodified_out : out std_logic;
        jtagbusy_out : out std_logic;
        i2c_sda : inout std_logic;
        i2c_sclk : inout std_logic
    );
    end component;

begin

-- Proasic JTAG pads: no driver left (db6_proasic_jtag_driver removed), float them.
p_proasic_tms_out  <= 'Z';
p_proasic_tck_out  <= 'Z';
p_proasic_tdi_out  <= 'Z';
p_proasic_trst_out <= 'Z';

i_db6_mainboard_driver_io : entity tilecal.db6_mainboard_driver_io
    port map (
        p_ssel_out     => p_ssel_out,
        p_sclk_out     => p_sclk_out,
        p_sdata_out    => p_sdata_out,
        p_sdata_in     => p_sdata_in,

        p_ssel_in      => p_mb_driver_ssel_in,
        p_sclk_in      => p_mb_driver_sclk_in,
        p_sdata_tx_in  => p_mb_driver_sdata_tx_in,
        p_sdata_rx_out => p_mb_driver_sdata_rx_out
    );

-- ADC readout front end: iddr (IDDRE1, off the undivided bitclk) or hss (SelectIO
-- Interface Wizard, hss_adc -- see db6_adc_interface_io_hss.vhd), selected by
-- g_clocking_mode. Only one is ever elaborated.
gen_db6_adc_interface_iddr : if g_clocking_mode /= 3 generate
    i_db6_adc_interface_io_iddr : entity tilecal.db6_adc_interface_io_iddr_bitclk280
        generic map (
            g_clocking_mode => g_clocking_mode
            )
        port map (
            p_master_reset_in => p_adc_master_reset_in,
            p_clknet_in        => p_clknet_in,
            p_db_reg_rx_in      => p_db_reg_rx_in,
            p_adc_bitclk_in     => p_adc_bitclk_in,
            p_adc_frameclk_in   => p_adc_frameclk_in,
            p_adc_lg_data_in    => p_adc_lg_data_in,
            p_adc_hg_data_in    => p_adc_hg_data_in,

            p_adc_bitclk_out          => p_adc_bitclk_out,
            p_adc_bitclkdiv_out       => p_adc_bitclkdiv_out,
            p_frame_missalignment_out => p_frame_missalignment_out,
            p_adc_frameclk_out        => p_adc_frameclk_out,
            p_adc_lg_data_out         => p_adc_lg_data_out,
            p_adc_hg_data_out         => p_adc_hg_data_out,

            p_adc_readout_control_in => s_adc_readout_control_unused,

            p_leds_out => open
        );

    p_adc_ctrl_reset_from_sm_out <= (others => '0');
    p_adc_frameclk_iserdese_out  <= (others => (others => '0'));
    p_adc_lg_data_iserdese_out   <= (others => (others => '0'));
    p_adc_hg_data_iserdese_out   <= (others => (others => '0'));
    p_adc_pll0_locked_out        <= (others => '0');
    p_adc_rst_seq_done_out       <= (others => '0');
    p_adc_fifo_data_valid_out    <= (others => '0');
    p_gbtx_clk40_data_out        <= (others => (others => '0'));
    p_gbtx_clk80_data_out        <= (others => (others => '0'));
end generate;

gen_db6_adc_interface_hss : if g_clocking_mode = 3 generate
    i_db6_adc_interface_io_hss : entity tilecal.db6_adc_interface_io_hss
        port map (
            p_master_reset_in => p_adc_master_reset_in,
            p_clknet_in        => p_clknet_in,
            p_db_reg_rx_in      => p_db_reg_rx_in,
            p_adc_bitclk_in     => p_adc_bitclk_in,
            p_adc_frameclk_in   => p_adc_frameclk_in,
            p_adc_hss_aux0_in   => p_adc_hss_aux0_in,
            p_adc_hss_aux1_in   => p_adc_hss_aux1_in,
            p_adc_hss_aux2_in   => p_adc_hss_aux2_in,
            p_adc_lg_data_in    => p_adc_lg_data_in,
            p_adc_hg_data_in    => p_adc_hg_data_in,
            p_gbtx_clk40_b68_in => p_gbtx_clk40_b68_in,
            p_gbtx_clk40_b67_in => p_gbtx_clk40_b67_in,
            p_gbtx_clk40_b66_in => p_gbtx_clk40_b66_in,
            p_gbtx_clk40_b47_in => p_gbtx_clk40_b47_in,
            p_gbtx_clk40_b46_in => p_gbtx_clk40_b46_in,
            p_gbtx_clk40_b44_in => p_gbtx_clk40_b44_in,
            p_gbtx_clk80_b68_in => p_gbtx_clk80_b68_in,
            p_gbtx_clk80_b67_in => p_gbtx_clk80_b67_in,
            p_gbtx_clk80_b66_in => p_gbtx_clk80_b66_in,
            p_gbtx_clk80_b47_in => p_gbtx_clk80_b47_in,
            p_gbtx_clk80_b46_in => p_gbtx_clk80_b46_in,
            p_gbtx_clk80_b44_in => p_gbtx_clk80_b44_in,
            p_gbtx_clk40_data_out => p_gbtx_clk40_data_out,
            p_gbtx_clk80_data_out => p_gbtx_clk80_data_out,

            p_adc_bitclk_out          => p_adc_bitclk_out,
            p_adc_bitclkdiv_out       => p_adc_bitclkdiv_out,
            p_frame_missalignment_in  => p_adc_frame_missalignment_in,
            p_ctrl_reset_from_sm_out  => p_adc_ctrl_reset_from_sm_out,
            p_adc_frameclk_out        => p_adc_frameclk_iserdese_out,
            p_adc_lg_data_out         => p_adc_lg_data_iserdese_out,
            p_adc_hg_data_out         => p_adc_hg_data_iserdese_out,

            p_adc_readout_control_in => s_adc_readout_control_unused,

            p_leds_out => open,
            p_pll0_locked_out     => p_adc_pll0_locked_out,
            p_rst_seq_done_out    => p_adc_rst_seq_done_out,
            p_fifo_data_valid_out => p_adc_fifo_data_valid_out
        );

    p_frame_missalignment_out <= (others => '0');
    p_adc_frameclk_out        <= (others => (others => '0'));
    p_adc_lg_data_out         <= (others => (others => '0'));
    p_adc_hg_data_out         <= (others => (others => '0'));
end generate;

i_db6_cfgbus_interface_io_iddr : entity tilecal.db6_cfgbus_interface_io_iddr
    port map (
        p_master_reset_in     => p_cfgbus_master_reset_in,
        p_clknet_in           => p_clknet_in,
        p_iddr_clk_in         => p_clknet_in.cfgbus_clk40_local,
        p_iddr_freerun_clk_in => p_clknet_in.osc_clk200,
        p_cfgbus_data_in      => p_cfgbus_data_local_in,
        p_cfgbus_bitslice_out => p_cfgbus_bitslice_local_out,
        p_leds_out            => open
    );

i_db6_cis_interface_hss_io : entity tilecal.db6_cis_interface_hss_io
    port map (
        p_clknet_in       => p_clknet_in,
        p_db_reg_rx_in    => p_db_reg_rx_in,
        p_master_reset_in => p_cis_master_reset_in,
        p_tph_out         => p_tph_out,
        p_tpl_out         => p_tpl_out,
        p_tph_in          => p_tph_in,
        p_tpl_in          => p_tpl_in
    );

-- GT/MGT: pack rx pads into the per-link array (link 1 = SFP, link 2 = GBTx-from-FPGA,
-- matching db6_gbt_gth_interface's original s_mgt_diff_pair_rx(0)/(1) mapping), and
-- unpack tx pads from db6_mgt's output. A single process overlays the pad-derived
-- rx_p/rx_n fields onto the logic-supplied device-specific record: doing this with
-- separate concurrent assignments (whole-record copy + per-field override) would put
-- two drivers on the same bits and resolve to 'X'.
s_mgt_diff_pair_rx(0) <= p_rx_sfp_in(0);
s_mgt_diff_pair_rx(1) <= p_rx_gbtx_from_fpga_in(0);

gen_mgt_tx_pads : for i in 0 to g_num_gth_links - 1 generate
    s_mgt_diff_pair_tx(i).p <= s_mgt_devspec_o.tx_p(i + 1);
    s_mgt_diff_pair_tx(i).n <= s_mgt_devspec_o.tx_n(i + 1);
end generate;
p_tx_sfp_out(0) <= s_mgt_diff_pair_tx(0);
p_tx_sfp_out(1) <= s_mgt_diff_pair_tx(1);

p_mgt_devspec_o_out <= s_mgt_devspec_o;

proc_mgt_devspec_i_overlay : process(p_mgt_devspec_i_in, s_mgt_diff_pair_rx)
    variable v_devspec_i : mgtDeviceSpecific_i_R;
begin
    v_devspec_i := p_mgt_devspec_i_in;
    for i in 0 to g_num_gth_links - 1 loop
        v_devspec_i.rx_p(i + 1) := s_mgt_diff_pair_rx(i).p;
        v_devspec_i.rx_n(i + 1) := s_mgt_diff_pair_rx(i).n;
    end loop;
    s_mgt_devspec_i <= v_devspec_i;
end process;

i_db6_mgt : entity tilecal.db6_mgt
    generic map (
        num_links => g_num_gth_links
    )
    port map (
        p_clknet_in    => p_clknet_in,
        p_ku_mgt_out   => p_ku_mgt_out,
        p_db_reg_rx_in => p_db_reg_rx_in,

        mgt_refclk_i(1) => p_clknet_in.gth_refclk_local(0),
        mgt_refclk_i(2) => p_clknet_in.gth_refclk_local(1),
        mgt_txusrclk_o  => p_mgt_txusrclk_out,
        mgt_rxusrclk_o  => p_mgt_rxusrclk_out,

        mgt_txreset_i => p_mgt_txreset_in,
        mgt_rxreset_i => p_mgt_rxreset_in,

        mgt_txready_o => p_mgt_txready_out,
        mgt_rxready_o => p_mgt_rxready_out,

        rx_headerlocked_o => p_mgt_headerlocked_out,
        rx_headerflag_o   => open,
        mgt_rstcnt_o      => p_mgt_rstcnt_out,

        mgt_autorsten_i     => p_mgt_autorsten_in,
        mgt_autorstoneven_i => p_mgt_autorstoneven_in,

        mgt_usrword_i => p_mgt_usrword_in,
        mgt_usrword_o => open,

        mgt_devspec_i => s_mgt_devspec_i,
        mgt_devspec_o => s_mgt_devspec_o
    );

-- GT refclk buffers (one per link), feeding db6_mgt directly above and relayed
-- out as plain logic for db6_clock_interface's other (mostly debug) consumers.
gen_gth_refclk : for i in 0 to g_num_gth_ref_clks - 1 generate
    i_gth_refclk_local : ibufds_gte3
        generic map (
            refclk_en_tx_path  => '0',
            refclk_hrow_ck_sel => "01",
            refclk_icntl_rx    => "00"
        )
        port map (
            ceb   => '0',
            i     => p_gth_refclk_gbtx_local_in(i).p,
            ib    => p_gth_refclk_gbtx_local_in(i).n,
            o     => p_gth_refclk_local_out(i),
            odiv2 => open
        );
end generate;

-- Oscillator: IBUFDS + pll_osc_clk (DRP tied off, matching original behavior).
i_ibufds_osc_clk : ibufds
    generic map (
        diff_term  => true,
        iostandard => "sub_lvds")
    port map (
        o  => s_osc_clk100,
        i  => p_osc_clk_in.p,
        ib => p_osc_clk_in.n
    );
p_osc_clk100_out <= s_osc_clk100;

i_pll_osc_clk : pll_osc_clk
    port map (
        p_clk40_out  => p_osc_clk40_out,
        p_clk200_out => p_osc_clk200_out,
        p_daddr_in   => s_pll_osc_daddr,
        p_dclk_in    => s_osc_clk100,
        p_den_in     => '0',
        p_din_in     => s_pll_osc_din,
        p_dout_out   => open,
        p_dwe_in     => '0',
        p_drdy_out   => open,
        p_reset_in   => '0',
        p_locked_out => p_osc_locked_out,
        p_clk_in     => s_osc_clk100
    );

-- CFGBUS local clock: IBUFDS only (no wizard follows it).
i_ibufds_cfgbus_local : ibufds
    generic map (
        diff_term  => true,
        iostandard => "sub_lvds")
    port map (
        o  => p_cfgbus_clk40_local_out,
        i  => p_gbt_cfgbus_clk40_local_in.p,
        ib => p_gbt_cfgbus_clk40_local_in.n
    );

i_system_management : system_management
    port map (
        di_in    => p_xadc_control_in.di_in,
        daddr_in => p_xadc_control_in.daddr_in,
        den_in   => p_xadc_control_in.den_in,
        dwe_in   => p_xadc_control_in.dwe_in,
        drdy_out => p_xadc_control_out.drdy_out,
        do_out   => p_xadc_control_out.do_out,
        dclk_in  => p_xadc_control_in.dclk_in,
        reset_in => p_xadc_control_in.reset_in,
        vp => p_xadc_analog_in.v.p,       vn => p_xadc_analog_in.v.n,
        vauxp0 => p_xadc_analog_in.vaux0.p,   vauxn0 => p_xadc_analog_in.vaux0.n,
        vauxp1 => p_xadc_analog_in.vaux1.p,   vauxn1 => p_xadc_analog_in.vaux1.n,
        vauxp2 => p_xadc_analog_in.vaux2.p,   vauxn2 => p_xadc_analog_in.vaux2.n,
        vauxp3 => p_xadc_analog_in.vaux3.p,   vauxn3 => p_xadc_analog_in.vaux3.n,
        vauxp4 => p_xadc_analog_in.vaux4.p,   vauxn4 => p_xadc_analog_in.vaux4.n,
        vauxp5 => p_xadc_analog_in.vaux5.p,   vauxn5 => p_xadc_analog_in.vaux5.n,
        vauxp6 => p_xadc_analog_in.vaux6.p,   vauxn6 => p_xadc_analog_in.vaux6.n,
        vauxp7 => p_xadc_analog_in.vaux7.p,   vauxn7 => p_xadc_analog_in.vaux7.n,
        vauxp8 => p_xadc_analog_in.vaux8.p,   vauxn8 => p_xadc_analog_in.vaux8.n,
        vauxp9 => p_xadc_analog_in.vaux9.p,   vauxn9 => p_xadc_analog_in.vaux9.n,
        vauxp10 => p_xadc_analog_in.vaux10.p, vauxn10 => p_xadc_analog_in.vaux10.n,
        vauxp11 => p_xadc_analog_in.vaux11.p, vauxn11 => p_xadc_analog_in.vaux11.n,
        vauxp12 => p_xadc_analog_in.vaux12.p, vauxn12 => p_xadc_analog_in.vaux12.n,
        vauxp13 => p_xadc_analog_in.vaux13.p, vauxn13 => p_xadc_analog_in.vaux13.n,
        vauxp14 => p_xadc_analog_in.vaux14.p, vauxn14 => p_xadc_analog_in.vaux14.n,
        vauxp15 => p_xadc_analog_in.vaux15.p, vauxn15 => p_xadc_analog_in.vaux15.n,
        user_temp_alarm_out    => p_xadc_control_out.user_temp_alarm_out,
        vccint_alarm_out       => p_xadc_control_out.vccint_alarm_out,
        vccaux_alarm_out       => p_xadc_control_out.vccaux_alarm_out,
        user_supply0_alarm_out => p_xadc_control_out.user_supply0_alarm_out,
        user_supply1_alarm_out => p_xadc_control_out.user_supply1_alarm_out,
        user_supply2_alarm_out => p_xadc_control_out.user_supply2_alarm_out,
        ot_out           => p_xadc_control_out.ot_out,
        channel_out      => p_xadc_control_out.channel_out,
        muxaddr_out      => p_xadc_control_out.muxaddr_out,
        eoc_out          => p_xadc_control_out.eoc_out,
        vbram_alarm_out  => p_xadc_control_out.vbram_alarm_out,
        alarm_out        => p_xadc_control_out.alarm_out,
        eos_out          => p_xadc_control_out.eos_out,
        busy_out         => p_xadc_control_out.busy_out,
        jtaglocked_out   => p_xadc_control_out.jtaglocked_out,
        jtagmodified_out => p_xadc_control_out.jtagmodified_out,
        jtagbusy_out     => p_xadc_control_out.jtagbusy_out,
        i2c_sda  => p_xadc_i2c_inout.sda,
        i2c_sclk => p_xadc_i2c_inout.scl
    );

-- I2C IOBUFs: each master already computed clean drive/tri/read-back signals
-- internally (this is a mechanical relocation of the primitive, not a logic change).
gen_sfp_i2c : for i in 0 to 1 generate
    i_sfp_sda_iobuf : iobuf
        port map (
            o  => p_sfp_sda_read_out(i),
            i  => p_sfp_sda_drive_in(i),
            io => p_sfp_i2c_sda_inout(i),
            t  => p_sfp_sda_tri_in(i)
        );
    i_sfp_scl_iobuf : iobuf
        port map (
            o  => p_sfp_scl_read_out(i),
            i  => p_sfp_scl_drive_in(i),
            io => p_sfp_i2c_scl_inout(i),
            t  => p_sfp_scl_tri_in(i)
        );
end generate;

i_gbtx_sda_iobuf : iobuf
    port map (
        o  => p_gbtx_sda_read_out(0),
        i  => p_gbtx_sda_drive_in(0),
        io => p_gbtx_i2c_sda_inout(0),
        t  => p_gbtx_sda_tri_in(0)
    );
i_gbtx_scl_iobuf : iobuf
    port map (
        o  => p_gbtx_scl_read_out(0),
        i  => p_gbtx_scl_drive_in(0),
        io => p_gbtx_i2c_scl_inout(0),
        t  => p_gbtx_scl_tri_in(0)
    );

i_integrator_sda_q0_iobuf : iobuf
    port map (
        o  => p_integrator_sda_read_out.q0,
        i  => p_integrator_sda_drive_in.q0,
        io => p_integrator_sda_inout.q0,
        t  => p_integrator_sda_tri_in.q0
    );
i_integrator_sda_q1_iobuf : iobuf
    port map (
        o  => p_integrator_sda_read_out.q1,
        i  => p_integrator_sda_drive_in.q1,
        io => p_integrator_sda_inout.q1,
        t  => p_integrator_sda_tri_in.q1
    );
i_integrator_scl_q0_iobuf : iobuf
    port map (
        o  => p_integrator_scl_read_out.q0,
        i  => p_integrator_scl_drive_in.q0,
        io => p_integrator_scl_inout.q0,
        t  => p_integrator_scl_tri_in.q0
    );
i_integrator_scl_q1_iobuf : iobuf
    port map (
        o  => p_integrator_scl_read_out.q1,
        i  => p_integrator_scl_drive_in.q1,
        io => p_integrator_scl_inout.q1,
        t  => p_integrator_scl_tri_in.q1
    );

end rtl;
