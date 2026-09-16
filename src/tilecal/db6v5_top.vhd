

----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Sam Silverstein 
--         : Eduardo Valdes
-- Create Date: 08/28/2018 02:56:16 PM
-- Design Name: 
-- Module Name: db6_top - Behavioral
-- Project Name: tilecal daughterboard rev 5 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:  Top level file for operating the DaughterBoard. 
--                       Intended for use on both sides of the DB
-- 
----------------------------------------------------------------------------------


-- common libraries --
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
-- xilinx libraries --
library unisim;
use unisim.vcomponents.all;
-- user defined libraries --

library gbt;
use gbt.all;
use gbt.gbt_bank_package.all;
use gbt.vendor_specific_gbt_bank_package.all;
library tilecal;
use tilecal.db6_design_package.all;

entity db6v5_top is
generic (
    g_priority_side : std_logic_vector(1 downto 0) := "01";                 --! side to priotitize
    g_num_gth_links                 : integer := c_gbt_bank_number_of_links;                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
    g_num_gth_ref_clks             : integer := c_number_of_gth_refclks;
    g_include_sem                   : integer :=1;
    g_include_debug_interface       : integer :=1;
    g_adc_clocking_scheme : t_adc_clocking_scheme := iddr280_serdes140;
    -- 2026-09-14: build-time enable/disable for i_db6_data_readout_debug and
    -- i_db6_data_readout_inject_debug (0 = logic not built, status/output held at
    -- default/passthrough -- see each entity's own g_* generic and header)
    g_data_readout_debug            : integer := 1;
    g_data_readout_inject_debug     : integer := 1;
    
    
    --hog
    GLOBAL_DATE : std_logic_vector(31 downto 0); -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
    GLOBAL_TIME : std_logic_vector(31 downto 0); -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
    GLOBAL_VER : std_logic_vector(31 downto 0); -- 32 bit Last version Tag when the project was modified. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
    GLOBAL_SHA : std_logic_vector(31 downto 0); -- 32 bit Git hash (SHA) of the last commit when the project was modified.
    TOP_VER : std_logic_vector(31 downto 0); -- 32 bit Top directory version, containing the hog.conf file and other files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
    TOP_SHA : std_logic_vector(31 downto 0); -- 32 bit Top directory version, containing the hog.conf file and other files.
    CON_VER : std_logic_vector(31 downto 0); -- 32 bit The version of the constraint files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
    CON_SHA : std_logic_vector(31 downto 0); -- 32 bit The git commit hash (SHA) of the constraint files.
    HOG_VER : std_logic_vector(31 downto 0); -- 32 bit Hog submodule version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
    HOG_SHA : std_logic_vector(31 downto 0) -- 32 bit Hog submodule git commit hash (SHA).
--    XML_VER : std_logic_vector(31 downto 0); -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--    XML_SHA : std_logic_vector(31 downto 0) -- 32 bit (optional) IPbus xml git commit hash (SHA).
    --<MYLIB>_VER : std_logic_vector(31 downto 0); -- 32 bit (one per library, i.e. .src list file) Version of the files contained in the .src file. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
    --<MYLIB>_SHA : std_logic_vector(31 downto 0); -- 32 bit (one per library, i.e. .src list file) Git commit hash of the files contained in the .src file (SHA).
    --<MYEXTLIB>_SHA : std_logic_vector(31 downto 0); -- 32 bit (one per external library) Git commit hash (SHA) of the .ext file.
    --FLAVOUR : integer --  flavour used for generating this bit file, set if your project uses Hog flavours to produce bit files for different devices
    );

  port
    (
      --osc clk
      p_osc_clk_in           : in   t_diff_pair;
      
      --gbtx clks
      p_gbt_cfgbus_clk40_local_in : in   t_diff_pair;
      p_gbt_cis_hss_clk80_local_in : in t_diff_pair;
      p_gbt_tp_q0_clk40_local_in : in   t_diff_pair;


      -- leds
      p_leds_out :  out std_logic_vector(3 downto 0);
      
      --db_side
      p_db_side_in : in std_logic_vector(0 downto 0);
      
      --md_number
      p_md_number_in : in std_logic_vector(3 downto 0);
      
      --configbus
      p_cfgbus_data_local_in : in t_cfgbus_data_in;

      --mgt
      --gth_refclk
      p_gth_refclk_gbtx_local_in    : in   t_diff_pair_vector((g_num_gth_ref_clks -1) downto 0);

      --sfp/gth
      p_tx_sfp_out  : out t_diff_pair_vector(1 downto 0);
      p_rx_sfp_in  : in t_diff_pair_vector(0 downto 0);
      p_rx_gbtx_from_fpga_in  : in t_diff_pair_vector(0 downto 0);

      --sfp interface
      p_sfp_i2c_scl_inout 				: inout std_logic_vector(1 downto 0);
      p_sfp_i2c_sda_inout                 : inout std_logic_vector(1 downto 0);      
      p_sfp_abs_in                : in std_logic_vector(1 downto 0);
      p_sfp_los_in                : in std_logic_vector(1 downto 0);
      p_sfp_tx_fault_in                : in std_logic_vector(1 downto 0);

      
      --mb_interface
      p_adc_bitclk_in : in t_adc_clk_in;
      p_adc_frameclk_in : in t_adc_clk_in;
      -- hss_adc's PLL/RIU clock-distribution hardware is shared across the whole I/O
      -- bank (locked CONFIG.PLL_SHARING=1, not a configurable choice for this device's
      -- HP banks in Native+FIFO RX mode), so each channel's hss_adc instance also
      -- claims 2 placeholder bitslice positions elsewhere in that channel's bank,
      -- regardless of pin configuration -- these carry no real data but are I/O-bound
      -- cells that must be placed on a real, otherwise-unused pin (see
      -- db6_adc_interface_io_hss.vhd header and constraints/db6v5.xdc for the actual
      -- per-channel pin, which is whatever the wizard itself natively assigns for
      -- that channel's bank).
      p_adc_hss_aux0_in : in std_logic_vector(5 downto 0);
      p_adc_hss_aux1_in : in std_logic_vector(5 downto 0);
      p_adc_hss_aux2_in : in std_logic_vector(5 downto 0);
      p_adc_lg_data_in : in t_adc_data_in;
      p_adc_hg_data_in : in t_adc_data_in;
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

--mb_driver
        p_ssel_out         : out t_mb_diff_pair;
        p_sclk_out         : out t_mb_diff_pair;
        p_sdata_out     : out t_mb_diff_pair;
        p_sdata_in    : in  t_mb_diff_pair;

--cis_interface
        --cis interface
        p_tph_out               : out t_mb_diff_pair;
        p_tpl_out               : out t_mb_diff_pair;

      
--      --xadc and system management
        p_xadc_analog_in : in t_xadc_analog_in;
        p_pgood_in       : in t_p_pgood_in;
        p_xadc_i2c_inout : inout t_i2c_bus;	
	    p_tdo_remote_in	    : in    std_logic;

      -- gbtx signals
      p_gbtx_rxready_in          : in std_logic_vector(0 downto 0); -- 0 local, 1 remote
      --p_gbtx_txready_in          : in std_logic_vector(1 downto 0); -- 0 local, 1 remote
      p_gbtx_datavalid_in        : in std_logic_vector(0 downto 0); -- 0 local, 1 remote
      p_gbtx_configsel_out       : out std_logic_vector(0 downto 0); -- 0 local, 1 remote
      p_gbtx_i2c_scl_inout 				: inout std_logic_vector(0 downto 0);
      p_gbtx_i2c_sda_inout                 : inout std_logic_vector(0 downto 0);

      --mainboard jtag chain
      p_mb_tms_out : out t_mb_std_logic;
      p_mb_tck_out : out t_mb_std_logic;
      p_mb_tdi_out : out t_mb_std_logic;
      p_mb_tdo_in : in t_mb_std_logic;
      
--   --mainboard reset fpgas
    p_mb_fpga_reset_low         : out t_mb_std_logic;
        
    
-- integrator
    p_integrator_sda_inout   :      inout t_mb_std_logic;
    p_integrator_scl_inout   :      inout t_mb_std_logic;   
    
-- sem    
    p_sem_uart_tx_out : out std_logic;
    p_sem_uart_rx_in : in std_logic;
    
-- debug and test
    p_debug_interface_uart_tx_out  : out std_logic;
    p_debug_interface_uart_rx_in   : in std_logic;
    
    p_adc_channel_pedestal_test_overflow_out : out std_logic;
    p_adc_channel_pedestal_test_underflow_out : out std_logic;

    -- proasic interface
      p_proasic_tms_out : out std_logic;
      p_proasic_tck_out : out std_logic;
      p_proasic_tdi_out : out std_logic;
      p_proasic_tdo_in : in std_logic;
      p_proasic_trst_out : out std_logic

      );

end db6v5_top;

architecture rtl of db6v5_top is
attribute IOB: string;
attribute keep: string;
attribute dont_touch: string;

--signals
--clock signals
signal s_clknet : t_db_clknet;
signal s_clkin, s_clkin_async : t_db_clkin;
--signal s_clk_sel : std_logic := '0';
--signal s_cpll_clk_sel : std_logic_vector(2 downto 0);
--signal s_qpll_clk_sel : std_logic_vector(2 downto 0);


--reset signals
signal s_master_reset_async, s_master_reset : std_logic_vector(31 downto 0) := (others => '1');

--led signals
signal s_leds : t_led_regs;--: std_logic_vector(3 downto 0); 

--register signals
--signal s_db_reg_rx : t_db_reg_rx;
signal s_cfgbus_interface : t_cfgbus_interface;
--interface signals
signal s_mb_interface          : t_mb_interface;
signal s_sem_interface     : t_sem_interface;
signal s_system_management_interface : t_system_management_interface;
signal s_gbtx_interface : t_gbtx_interface;
signal s_gbt_encoder_interface : t_gbt_encoder_interface;
signal s_serial_id_interface : t_serial_id_interface;
signal s_sfp_control : t_sfp_control;
signal s_db6_gbt_bank : t_db6_gbt_bank;
signal s_sfp_interface : t_sfp_interface;
signal s_sfp_ku_mgt : t_ku_mgt;
-- reg block ram port b addresses, settable directly from vio_clknet_status debug probes
signal s_sfp_reg_address_vio : t_sfp_reg_addr_array;
-- mb boundary-scan/gbtx reg readback vio address overrides retired (their probe_out
-- slots -- old probe_out14/15/16 -- were reclaimed for db7_is25lp256_driver's manual
-- override, see i_vio_clknet_status below); tied off, only the cfb_* db_reg_rx path remains.
signal s_mb_boundary_scan_reg_address_vio : t_sfp_reg_addr_array;
signal s_gbtx_reg_readback_address_vio : std_logic_vector(8 downto 0);
signal s_gbtx_reg_readback_address : std_logic_vector(8 downto 0);
signal s_db6_sem_interface : t_db6_sem_interface;

signal s_gbtx_control : t_gbtx_control;

signal s_counter : integer range 0 to 31 :=0;
signal s_leds_out : std_logic_vector(3 downto 0):= (others=> '0');
signal s_skip_main_sm : std_logic;


signal s_mb_fpga_reset_low : t_mb_std_logic;
signal s_mb_fpga_reset_low_out : t_mb_std_logic;
-- manual vio-driven force of the altera companion fpga reset; moved out of
-- t_clknet_debug_control into its own dedicated signal (mirrored into
-- t_mb_interface.mb_reset by db6_mainboard_interface.vhd) for consistency
-- 2026-09-12: was a bare t_mb_std_logic signal threaded through a dedicated
-- p_mb_reset_vio_in port on db6_mainboard_interface; now a proper t_mb_interface
-- (only .mb_reset populated -- see p_mb_interface_in on that entity).
signal s_mb_interface_in : t_mb_interface;
-- fires a one-shot boundary-scan trigger ~1s (100 ticks of clk_100hz) after each
-- side's s_mb_fpga_reset_low_out releases -- see proc_mb_boundary_scan_timed_trigger
signal s_mb_boundary_scan_timed_trigger : t_mb_std_logic := (q0 => '0', q1 => '0');

-- sticky "performed at least once since master reset" flags for the bootup gbtx
-- register write/read (proc_startup_sm states 1-2 / 11) and sfp+ a2h read
-- (free-running in db6_sfp_i2c_interface); mb boundary scan's own equivalent flag
-- lives in t_mb_interface.mb_boundary_scan_boot_done (see db6_mainboard_interface.vhd)
signal s_boot_gbtx_write_done : std_logic := '0';
signal s_boot_gbtx_read_done  : std_logic := '0';
signal s_boot_sfp_read_done   : std_logic_vector(1 downto 0) := (others => '0');

-- GLOBAL_DATE/GLOBAL_TIME generics, mirrored into named signals so vio_db_debug's
-- ltx keeps a real probe label (see the concurrent assignment right after "begin" below)
signal c_global_date : std_logic_vector(31 downto 0);
signal c_global_time : std_logic_vector(31 downto 0);
-- cfgbus loopback mux cannot live in the vio port map (to_integer/unsigned is an
-- operation); named net so the ltx probe keeps a real label
signal s_vio_cfgbus_loopback_reg : std_logic_vector(31 downto 0);
attribute dont_touch of c_global_date, c_global_time, s_vio_cfgbus_loopback_reg : signal is "TRUE";

-- vio_db_debug now lives here instead of inside db6_clock_interface; these carry
-- exactly what it needs across that module boundary (see db6_design_package.vhd).
signal s_clknet_debug_status  : t_clknet_debug_status;
-- 2026-09-12: t_clknet_debug_control (flat grab-bag) replaced by t_debug_control,
-- grouped per module (.clknet/.adc_readout/.adc_config/.cis/.flash -- see
-- db6_design_package.vhd); also now carries the revived vio_adc_config controls
-- (.adc_config) that used to need a second, separate, never-instantiated VIO core.
signal s_clknet_debug_control : t_debug_control;
signal s_dna_reset             : std_logic;
-- 2026-09-13: db6_data_readout_debug's vio-facing status readback (see that entity)
signal s_data_readout_debug_status : t_data_readout_debug_status;

-- 2026-09-14: db6_data_readout_inject_debug (see that entity's header). s_adc_hg_injected/
-- s_adc_lg_injected are its per-channel outputs (injected or passthrough, per enable);
-- s_mb_interface_gbt_tx is s_mb_interface with those two fields spliced in (plus the
-- inject status fields) via proc_mb_interface_gbt_tx_mux below, and is what actually
-- feeds the gbt encoder chain (i_db6_sfp_interface's p_mb_interface_in) -- every other
-- consumer of s_mb_interface (debug_interface, vio probes, the readout capture debug
-- above) keeps seeing raw, un-injected adc data.
signal s_adc_hg_injected : t_adc_data;
signal s_adc_lg_injected : t_adc_data;
signal s_data_readout_inject_status : t_data_readout_inject_debug_status;
signal s_mb_interface_gbt_tx : t_mb_interface;

-- 2026-09-12: vio_clknet_status replaced by vio_db_debug (see i_vio_db_debug below) with
-- a curated probe set -- dead/unconnected probes dropped, SEM status/counters dropped
-- (now exposed via db_reg_tx instead -- see stb_sem_error_counters/stb_sem_injected_errors
-- in db6_design_package.vhd), and mb_tx_collision/gbt_cdc_gearbox_phase (both directions)/
-- gth_wordclk_sel/tmr_error_lg_hg_fc/mb_integrator/gbt_bank_sync dropped per direct
-- request. New: idelay calibration tap/done/failed (see db6_adc_idelay_calibration.vhd).
-- Every probe below is its own dedicated, dont_touch-protected staging signal (not a raw
-- port-map expression) so its name survives synthesis into the ltx file regardless of
-- what it's built from -- several old probes concatenated bits from multiple unrelated
-- signals with no guarantee of a readable ltx label at all.

-- t_adc_readout group
signal s_vio_dbg_adc_channel_locked, s_vio_dbg_adc_channel_missed_locked,
       s_vio_dbg_adc_channel_clk280_locked, s_vio_dbg_adc_channel_missed_bit_count,
       s_vio_dbg_adc_pedestal_overflow, s_vio_dbg_adc_pedestal_underflow : std_logic_vector(5 downto 0);
signal s_vio_dbg_adc_config_done, s_vio_dbg_adc_readout_initialized : std_logic_vector(0 downto 0);
-- 2026-09-12: idelay tap dropped its combining staging signal -- probe_in8 below is now
-- fed directly, per-channel, from s_mb_interface.adc_readout.fc_idelay_count(n) so each
-- channel keeps a distinct, human-readable ltx name instead of one opaque 54-bit blob.
signal s_vio_dbg_adc_idelay_calibration_done, s_vio_dbg_adc_idelay_calibration_failed : std_logic_vector(5 downto 0);
attribute dont_touch of
    s_vio_dbg_adc_channel_locked, s_vio_dbg_adc_channel_missed_locked,
    s_vio_dbg_adc_channel_clk280_locked, s_vio_dbg_adc_channel_missed_bit_count,
    s_vio_dbg_adc_pedestal_overflow, s_vio_dbg_adc_pedestal_underflow,
    s_vio_dbg_adc_config_done, s_vio_dbg_adc_readout_initialized,
    s_vio_dbg_adc_idelay_calibration_done, s_vio_dbg_adc_idelay_calibration_failed
    : signal is "TRUE";

-- t_db_clknet / system clock+reset health group
signal s_vio_dbg_bcr_locked, s_vio_dbg_locked_db, s_vio_dbg_mmcm_gbt40_db6_locked, s_vio_dbg_clk_1hz,
       s_vio_dbg_mb_fpga_reset_low_q0, s_vio_dbg_gbtx_rxready, s_vio_dbg_locked_tp_q0,
       s_vio_dbg_mb_fpga_reset_low_q1, s_vio_dbg_db_side,
       s_vio_dbg_dna_done : std_logic_vector(0 downto 0);
-- 2026-09-12: qpllclksel/txsysclksel/rxsysclksel/rxoutclksel/txoutclksel/qpll1lock/
-- wordclk_locked/cdc_reset_array grouped into one t_gth_link_debug signal instead of
-- 8 independently-connected staging signals (see db6_design_package.vhd)
signal s_vio_dbg_link : t_gth_link_debug;
signal s_vio_dbg_gbt_cdc_phase_override_rb, s_vio_dbg_mb_jtag_done : std_logic_vector(1 downto 0);
signal s_vio_dbg_db_leds : std_logic_vector(3 downto 0);
-- 2026-09-12: bcr_tmr_error/tx_ph/gth_status/sfp_module_status/gbtx_shadow dropped their
-- combining staging signals -- each is now fed directly, per-field, from its real named
-- source at the probe_in port map below (item 1 rewiring: separate port-map associations
-- per bit-range keep each field's own ltx name instead of one opaque blob per probe).
signal s_vio_dbg_running_time, s_vio_dbg_mb_jtag_id_q0, s_vio_dbg_mb_jtag_id_q1 : std_logic_vector(31 downto 0);
signal s_vio_dbg_md_number : std_logic_vector(3 downto 0);
signal s_vio_dbg_dna : std_logic_vector(7 downto 0);
signal s_vio_dbg_sfp_addr_echo0, s_vio_dbg_sfp_addr_echo1 : std_logic_vector(6 downto 0);
signal s_vio_dbg_gbtx_config_readback : std_logic_vector(7 downto 0);
signal s_vio_dbg_hss_rst_seq_done, s_vio_dbg_hss_fifo_data_valid : std_logic_vector(5 downto 0);
signal s_vio_dbg_boot_done_mb_bs_q0, s_vio_dbg_boot_done_mb_bs_q1, s_vio_dbg_boot_done_gbtx_write,
       s_vio_dbg_boot_done_gbtx_read, s_vio_dbg_boot_done_sfp_q0, s_vio_dbg_boot_done_sfp_q1 : std_logic_vector(0 downto 0);
attribute dont_touch of
    s_vio_dbg_bcr_locked, s_vio_dbg_locked_db, s_vio_dbg_link,
    s_vio_dbg_mmcm_gbt40_db6_locked, s_vio_dbg_clk_1hz, s_vio_dbg_gbt_cdc_phase_override_rb,
    s_vio_dbg_mb_fpga_reset_low_q0, s_vio_dbg_gbtx_rxready, s_vio_dbg_locked_tp_q0,
    s_vio_dbg_mb_fpga_reset_low_q1,
    s_vio_dbg_db_leds, s_vio_dbg_db_side, s_vio_dbg_running_time, s_vio_dbg_md_number,
    s_vio_dbg_dna, s_vio_dbg_dna_done,
    s_vio_dbg_mb_jtag_id_q0, s_vio_dbg_mb_jtag_id_q1, s_vio_dbg_mb_jtag_done, s_vio_dbg_sfp_addr_echo0,
    s_vio_dbg_sfp_addr_echo1, s_vio_dbg_gbtx_config_readback, s_vio_dbg_hss_rst_seq_done,
    s_vio_dbg_hss_fifo_data_valid, s_vio_dbg_boot_done_mb_bs_q0, s_vio_dbg_boot_done_mb_bs_q1,
    s_vio_dbg_boot_done_gbtx_write, s_vio_dbg_boot_done_gbtx_read, s_vio_dbg_boot_done_sfp_q0,
    s_vio_dbg_boot_done_sfp_q1
    : signal is "TRUE";

-- plugin-critical group (flash/sfp_i2c/sfp_ddm -- names/widths match extras/vio_monitor plugins)
signal s_vio_dbg_flash_status, s_vio_dbg_flash_rdata : std_logic_vector(31 downto 0);
signal s_vio_dbg_sfp_shadow_q0, s_vio_dbg_sfp_shadow_q1 : std_logic_vector(7 downto 0);
signal s_vio_dbg_ddm_temp_q0, s_vio_dbg_ddm_temp_q1, s_vio_dbg_ddm_vcc_q0, s_vio_dbg_ddm_vcc_q1,
       s_vio_dbg_ddm_txbias_q0, s_vio_dbg_ddm_txbias_q1, s_vio_dbg_ddm_txpower_q0, s_vio_dbg_ddm_txpower_q1,
       s_vio_dbg_ddm_rxpower_q0, s_vio_dbg_ddm_rxpower_q1, s_vio_dbg_ddm_lasertemp_q0, s_vio_dbg_ddm_lasertemp_q1,
       s_vio_dbg_ddm_teccurrent_q0, s_vio_dbg_ddm_teccurrent_q1 : std_logic_vector(15 downto 0);
attribute dont_touch of
    s_vio_dbg_flash_status, s_vio_dbg_flash_rdata, s_vio_dbg_sfp_shadow_q0, s_vio_dbg_sfp_shadow_q1,
    s_vio_dbg_ddm_temp_q0, s_vio_dbg_ddm_temp_q1, s_vio_dbg_ddm_vcc_q0, s_vio_dbg_ddm_vcc_q1,
    s_vio_dbg_ddm_txbias_q0, s_vio_dbg_ddm_txbias_q1, s_vio_dbg_ddm_txpower_q0, s_vio_dbg_ddm_txpower_q1,
    s_vio_dbg_ddm_rxpower_q0, s_vio_dbg_ddm_rxpower_q1, s_vio_dbg_ddm_lasertemp_q0, s_vio_dbg_ddm_lasertemp_q1,
    s_vio_dbg_ddm_teccurrent_q0, s_vio_dbg_ddm_teccurrent_q1
    : signal is "TRUE";

-- t_adc_readout_control (calibration thresholds) + system control group
signal s_vio_dbg_adc_high_thresh, s_vio_dbg_adc_low_thresh : std_logic_vector(11 downto 0);
signal s_vio_dbg_adc_thresh_sel_ch : std_logic_vector(2 downto 0);
-- 2026-09-12: reset_controls/force_gtx_i2c_config/cis_manual_control/
-- mb_fpga_reset_low_ctrl/flash_manual_access dropped their combining staging signals --
-- each is now driven directly, per-field, straight into its real destination signal at
-- the probe_out port map below (item 1 rewiring).
signal s_vio_dbg_sfp_addr_out_q0, s_vio_dbg_sfp_addr_out_q1 : std_logic_vector(6 downto 0);
attribute dont_touch of
    s_vio_dbg_adc_high_thresh, s_vio_dbg_adc_low_thresh, s_vio_dbg_adc_thresh_sel_ch,
    s_vio_dbg_sfp_addr_out_q0, s_vio_dbg_sfp_addr_out_q1
    : signal is "TRUE";

-- 2026-09-13: db6_adc_config_driver.vhd status readback (t_adc_config_driver_debug_status
-- -- see db6_design_package.vhd) and the dual-uplink sync mismatch comparator
-- (t_gbt_encoder_interface's dual_link_sync_mismatch_* -- see db6_gbt_gth_interface.vhd)
-- are wired directly off s_mb_interface/s_gbt_encoder_interface's record fields at the
-- probe_in port map below (matching probe_in74-77's convention), not staging signals --
-- both those signals are already keep/dont_touch-protected as wholes, so the ltx label
-- comes out bracket-hierarchical (e.g. s_mb_interface[adc_config_driver_debug][state]),
-- matching probe_out10-16's adc_config[...] style instead of a flat s_vio_dbg_* name.

-- db7_io_box: mainboard driver serial bus, plain-logic side (stage 1 of IO isolation migration)
signal s_mb_driver_ssel, s_mb_driver_sclk, s_mb_driver_sdata_tx, s_mb_driver_sdata_rx : t_mb_std_logic;

-- db7_io_box: ADC interface, plain-logic side (stage 2)
signal s_adc_bitclk, s_adc_bitclkdiv, s_frame_missalignment : std_logic_vector(5 downto 0);
signal s_adc_frameclk, s_adc_lg_data, s_adc_hg_data : t_bitslice_sr; -- iddr only
-- iddr280/iddr280_clkdiv: per-channel pll_adc_channel lock, generated in db7_io_box (a PLL
-- can't be triplicated) and consumed as plain status by db6_mainboard_interface's decoder
signal s_adc_pll0_locked : std_logic_vector(5 downto 0);

-- ADC readout front end, hss (SelectIO wizard) only (see db6_adc_interface.vhd / db7_io_box.vhd);
-- selected instead of the iddr signals above via g_adc_clocking_scheme below.
signal s_adc_frameclk_iserdese, s_adc_lg_data_iserdese, s_adc_hg_data_iserdese : t_byteslice_sr;
signal s_adc_frame_missalignment_iserdese, s_adc_ctrl_reset_from_sm_iserdese : std_logic_vector(5 downto 0);

-- hss_adc per-channel internal status (reset-sequence-done / fifo valid; pll0_locked
-- removed -- redundant with channel_clk280_locked/pll_adc_channel in iddr mode), for
-- vio_clknet_status hardware debug (see db6_adc_interface_io_hss.vhd)
signal s_adc_rst_seq_done, s_adc_fifo_data_valid : std_logic_vector(5 downto 0);

-- deserialized gbtx_clk40/80 data, per channel (see db6_adc_interface_io_hss.vhd
-- header) -- not consumed anywhere yet
signal s_gbtx_clk40_data, s_gbtx_clk80_data : t_byteslice_sr;

-- db7_io_box: CFGBUS local, plain-logic side (stage 2)
signal s_cfgbus_bitslice_local : t_cfgbus_bitslice;

-- db7_io_box: CIS interface, plain-logic side (stage 2)
signal s_tph, s_tpl : t_mb_std_logic;

-- db7_io_box: GT/MGT (SFP/GBTx), plain-logic side (stage 3)
signal s_ku_mgt_from_box : t_ku_mgt;
signal s_mgt_txusrclk, s_mgt_rxusrclk : std_logic_vector(1 to g_num_gth_links);
signal s_mgt_txreset, s_mgt_rxreset : std_logic_vector(1 to g_num_gth_links);
signal s_mgt_txready, s_mgt_rxready : std_logic_vector(1 to g_num_gth_links);
signal s_mgt_headerlocked : std_logic_vector(1 to g_num_gth_links);
signal s_mgt_rstcnt : gbt_reg8_A(1 to g_num_gth_links);
signal s_mgt_autorsten, s_mgt_autorstoneven : std_logic_vector(1 to g_num_gth_links);
signal s_mgt_usrword : word_mxnbit_A(1 to g_num_gth_links);
signal s_mgt_devspec_i : mgtDeviceSpecific_i_R;
signal s_mgt_devspec_o : mgtDeviceSpecific_o_R;

-- db7_io_box: clock wizards, plain-logic side (stage 4)
signal s_gth_refclk_local : std_logic_vector(g_num_gth_ref_clks-1 downto 0);
signal s_osc_clk100, s_osc_clk40, s_osc_clk200, s_osc_locked : std_logic;
signal s_cfgbus_clk40_local : std_logic;

-- db7_io_box: XADC, plain-logic side (stage 5)
signal s_xadc_control_to_box, s_xadc_control_from_box : t_xadc_control;

-- db7_io_box: IS25LP256 config flash (STARTUPE3), plain-logic side
signal s_flash_control_to_box, s_flash_control_from_box : t_is25lp256_control;

-- db7_io_box: I2C inout buses (SFP/GBTx/integrator), plain-logic side (stage 6)
signal s_sfp_sda_drive, s_sfp_sda_tri, s_sfp_sda_read : std_logic_vector(1 downto 0);
signal s_sfp_scl_drive, s_sfp_scl_tri, s_sfp_scl_read : std_logic_vector(1 downto 0);
signal s_gbtx_sda_drive, s_gbtx_sda_tri, s_gbtx_sda_read : std_logic_vector(0 downto 0);
signal s_gbtx_scl_drive, s_gbtx_scl_tri, s_gbtx_scl_read : std_logic_vector(0 downto 0);
signal s_integrator_sda_drive, s_integrator_sda_tri, s_integrator_sda_read : t_mb_std_logic;
signal s_integrator_scl_drive, s_integrator_scl_tri, s_integrator_scl_read : t_mb_std_logic;

attribute keep of s_sfp_interface, s_sfp_control, s_gbtx_interface, s_mb_interface, s_sem_interface, s_system_management_interface, s_gbtx_control, s_serial_id_interface, s_boot_gbtx_write_done, s_boot_gbtx_read_done, s_boot_sfp_read_done, s_clknet_debug_control : signal is "TRUE";
attribute dont_touch of s_sfp_interface, s_sfp_control, s_gbtx_interface, s_mb_interface, s_sem_interface, s_system_management_interface, s_gbtx_control, s_serial_id_interface, s_boot_gbtx_write_done, s_boot_gbtx_read_done, s_boot_sfp_read_done, s_clknet_debug_control : signal is "TRUE";


COMPONENT vio_leds_debug
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
    probe_in15 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END COMPONENT;

signal scl_i, scl_o, scl_t, sda_i, sda_o, sda_t : t_mb_std_logic;
COMPONENT vio_i2c_bus
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out2 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out3 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out4 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out5 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
    
  );
END COMPONENT;

COMPONENT vio_hog
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in15 : IN STD_LOGIC_VECTOR(31 DOWNTO 0) 
  );
END COMPONENT;



-- 2026-09-12: replaces vio_clknet_status -- see the vio_db_debug header comment near
-- its signal declarations above for the full list of what changed and why.
COMPONENT vio_db_debug
  PORT (
    clk : IN STD_LOGIC;
    -- t_adc_readout group
    probe_in0  : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- channel_locked
    probe_in1  : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- channel_missed_locked
    probe_in2  : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- channel_clk280_locked
    probe_in3  : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- channel_missed_bit_count
    probe_in4  : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- channel_pedestal_test_overflow
    probe_in5  : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- channel_pedestal_test_underflow
    probe_in6  : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- adc_config_done
    probe_in7  : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- readout_initialized
    probe_in8  : IN STD_LOGIC_VECTOR(53 DOWNTO 0); -- idelay calibration tap (6ch x 9bit; fc/lg/hg identical)
    probe_in9  : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- idelay calibration done
    probe_in10 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- idelay calibration failed
    -- t_db_clknet / system clock+reset health group
    probe_in11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- bcr_locked
    probe_in12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- locked_db
    probe_in13 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);  -- qpllclksel
    probe_in14 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);  -- bcr tmr error bits
    probe_in15 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);  -- txsysclksel
    probe_in16 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);  -- rxsysclksel
    probe_in17 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);  -- rxoutclksel
    probe_in18 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);  -- txoutclksel
    probe_in19 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- mmcm_gbt40_db6_locked
    probe_in20 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- clk_1hz
    probe_in21 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);  -- gbt cdc phase override readback
    probe_in22 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);  -- tx_phcomputed/tx_phaligned
    probe_in23 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- mb_fpga_reset_low q0
    probe_in24 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- gbtx_rxready
    probe_in25 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- locked_tp_q0
    probe_in26 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- mb_fpga_reset_low q1
    probe_in27 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- qpll1lock
    probe_in28 : IN STD_LOGIC_VECTOR(10 DOWNTO 0); -- GTH wizard status bits
    probe_in29 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- sfp module status (mod_abs/mod_los/tx_fault)
    probe_in30 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);  -- db_leds
    probe_in31 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- db_side
    probe_in32 : IN STD_LOGIC_VECTOR(45 DOWNTO 0); -- gbtx i2c/reg shadow
    probe_in33 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- running_time
    probe_in34 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);  -- md_number
    probe_in35 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- cfgbus loopback debug
    probe_in36 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- global_date
    probe_in37 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- global_time
    probe_in38 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- device dna
    probe_in39 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- device dna done
    probe_in40 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);  -- gbt wordclk_locked
    probe_in41 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);  -- gbt cdc_reset_array
    probe_in42 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- mb_jtag_id q0
    probe_in43 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- mb_jtag_id q1
    probe_in44 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);  -- mb_jtag_done q0/q1
    probe_in45 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);  -- sfp reg addr echo, side 0
    probe_in46 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);  -- sfp reg addr echo, side 1
    probe_in47 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- gbtx config shadow readback
    probe_in48 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- hss_adc rst_seq_done (hss_wizard only)
    probe_in49 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- hss_adc fifo_data_valid (hss_wizard only)
    probe_in50 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- boot-done: mb boundary-scan q0
    probe_in51 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- boot-done: mb boundary-scan q1
    probe_in52 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- boot-done: gbtx write
    probe_in53 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- boot-done: gbtx read
    probe_in54 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- boot-done: sfp+ a2h read q0
    probe_in55 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- boot-done: sfp+ a2h read q1
    -- plugin-critical group (flash/sfp_i2c/sfp_ddm -- names/widths match extras/vio_monitor plugins)
    probe_in56 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- flash_status
    probe_in57 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- flash_rdata
    probe_in58 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm temperature q0
    probe_in59 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm temperature q1
    probe_in60 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm vcc q0
    probe_in61 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm vcc q1
    probe_in62 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm tx_bias_current q0
    probe_in63 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm tx_bias_current q1
    probe_in64 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm tx_power q0
    probe_in65 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm tx_power q1
    probe_in66 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm rx_power q0
    probe_in67 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm rx_power q1
    probe_in68 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm laser_temperature q0
    probe_in69 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm laser_temperature q1
    probe_in70 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm tec_current q0
    probe_in71 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); -- sfp ddm tec_current q1
    probe_in72 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- sfp+ reg block ram shadow readback, side 0
    probe_in73 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- sfp+ reg block ram shadow readback, side 1
    -- db6_data_readout_debug readback (t_data_readout_debug_status -- see
    -- db6_design_package.vhd / db6_data_readout_debug.vhd)
    probe_in74 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- data_readout: captured
    probe_in75 : IN STD_LOGIC_VECTOR(13 DOWNTO 0); -- data_readout: hg_data (muxed sample)
    probe_in76 : IN STD_LOGIC_VECTOR(13 DOWNTO 0); -- data_readout: lg_data (muxed sample)
    probe_in77 : IN STD_LOGIC_VECTOR(13 DOWNTO 0); -- data_readout: fc_data (muxed sample)
    -- db6_adc_config_driver status readback (t_adc_config_driver_debug_status -- see
    -- db6_design_package.vhd / db6_adc_config_driver.vhd). registers_buffer split one
    -- probe per byte (A0..A4), matching probe_out11-15's adc_register_x_raw naming.
    probe_in78 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);  -- adc_config_driver: FSM state (encoded, see proc_state_encode)
    probe_in79 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config_driver: registers_buffer(0) (A0, as latched/sent)
    probe_in80 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config_driver: registers_buffer(1) (A1, as latched/sent)
    probe_in81 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config_driver: registers_buffer(2) (A2, as latched/sent)
    probe_in82 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config_driver: registers_buffer(3) (A3, as latched/sent)
    probe_in83 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config_driver: registers_buffer(4) (A4, as latched/sent)
    probe_in84 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);  -- adc_config_driver: leds
    probe_in85 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- adc_config_driver: trigger_internal
    probe_in86 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);  -- adc_config_driver: mb_config_done q0/q1
    -- dual-uplink sync mismatch comparator (t_gbt_encoder_interface -- see
    -- db6_design_package.vhd / db6_gbt_gth_interface.vhd)
    probe_in87 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);  -- gbt: dual_link_sync_mismatch_sticky
    probe_in88 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- gbt: dual_link_sync_mismatch_count
    -- db6_data_readout_inject_debug readback (t_data_readout_inject_debug_status --
    -- see db6_design_package.vhd / db6_data_readout_inject_debug.vhd). NEW PROBE --
    -- regenerate vio_db_debug's .xcix in Vivado (IP catalog -> re-customize -> add
    -- one more probe_in, width 15) before this will elaborate against real hardware;
    -- see the "Vivado IP probe regen cache gotcha" note for the .cache/ip step.
    probe_in89 : IN STD_LOGIC_VECTOR(14 DOWNTO 0); -- data_readout_inject: active(14) & ram_rdata(13:0)
    -- t_adc_readout_control (calibration thresholds) + system control group
    probe_out0 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0); -- adc_readout_high_threshold
    probe_out1 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0); -- adc_readout_low_threshold
    probe_out2 : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);  -- adc_readout_threshold_select_channel
    probe_out3 : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);  -- reset controls: q0/q1/dna_reset/reset_clknet/skip_main_sm/clear_dual_link_mismatch
    probe_out4 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);  -- force_gtx_i2c_config
    probe_out5 : OUT STD_LOGIC_VECTOR(25 DOWNTO 0); -- CIS manual control
    probe_out6 : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  -- mb_fpga_reset_low control
    probe_out7 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);  -- sfp+ reg block ram address, side 0
    probe_out8 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);  -- sfp+ reg block ram address, side 1
    probe_out9  : OUT STD_LOGIC_VECTOR(96 DOWNTO 0); -- flash manual access override
    -- revived vio_adc_config controls (t_debug_control_adc_config -- see
    -- db6_design_package.vhd / db6_mainboard_interface.vhd). 2026-09-13: this probe's
    -- VIO INIT value was 0x0 (mb_fpga_select="000"=FPGA A0 only, mb_pmt_select="00"=
    -- tube 1 only per db6_adc_config_driver.vhd's own s_fe_data comments), unlike the
    -- configbus path (db6_mainboard_interface.vhd's s_adc_register_config_from_configbus,
    -- hardcoded "100"/"11" = all/all) -- triggering a config write with mode=1 and
    -- fpga/pmt_select left untouched silently targeted only A0/tube1, looking like a
    -- no-op if that wasn't the intended target. Set to 0x70 in the .xci (mode=0,
    -- trigger=0, mb_fpga_select="100", mb_pmt_select="11" -- see bit layout in the
    -- probe_out10 port map below) so the VIO path defaults to the same always-broadcast
    -- convention as the configbus path.
    probe_out10 : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);  -- adc_config: mode/trigger/fpga_select/pmt_select/force_recalibrate/force_adc_readout_reset
    probe_out11 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config: adc_register_0 (A0)
    probe_out12 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config: adc_register_1 (A1)
    probe_out13 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config: adc_register_2 (A2)
    probe_out14 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config: adc_register_3_raw (A3, manual)
    probe_out15 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- adc_config: adc_register_4_raw (A4, manual)
    probe_out16 : OUT STD_LOGIC_VECTOR(14 DOWNTO 0); -- adc_config: test_pattern_enable/test_pattern_value
    -- db6_data_readout_debug controls (t_debug_control_data_readout -- see
    -- db6_design_package.vhd / db6_data_readout_debug.vhd)
    probe_out17 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- data_readout: trigger/sample_index/channel_select
    probe_out18 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- data_readout: bcr_number
    -- db6_data_readout_inject_debug controls (t_debug_control_data_readout_inject --
    -- see db6_design_package.vhd / db6_data_readout_inject_debug.vhd). NEW PROBE --
    -- see the probe_in89 comment above, add one more probe_out, width 41, alongside it.
    probe_out19 : OUT STD_LOGIC_VECTOR(40 DOWNTO 0)  -- data_readout_inject: enable(40) & ram_we(39) & pedestal(38:26) & ram_addr(25:14) & ram_wdata(13:0)
  );
END COMPONENT;


COMPONENT vio_mb_jtag_debug
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out2 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out3 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out4 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out5 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out6 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    
  );
END COMPONENT;


begin  -- rtl

-- GLOBAL_DATE/GLOBAL_TIME are entity generics (compile-time literals, populated by
-- Hog at build time); wiring a generic straight into a vio probe leaves no real net
-- for synthesis to name, so the ltx probe label comes out generic/meaningless. Route
-- through a named signal instead so vio_clknet_status's ltx keeps a sensible label.
c_global_date <= GLOBAL_DATE;
c_global_time <= GLOBAL_TIME;
s_vio_cfgbus_loopback_reg <= s_cfgbus_interface.db_reg_rx(to_integer(unsigned(s_cfgbus_interface.db_reg_rx(cfb_loopback)(3 downto 0))));

-- vio_db_debug staging signal assignments (see the signal declarations above for why
-- each one is a dedicated dont_touch signal rather than a raw port-map expression).

-- t_adc_readout group
s_vio_dbg_adc_channel_locked <= s_mb_interface.adc_readout.channel_locked;
s_vio_dbg_adc_channel_missed_locked <= s_mb_interface.adc_readout.channel_missed_locked;
s_vio_dbg_adc_channel_clk280_locked <= s_mb_interface.adc_readout.channel_clk280_locked;
s_vio_dbg_adc_channel_missed_bit_count <= s_mb_interface.adc_readout.channel_missed_bit_count;
s_vio_dbg_adc_pedestal_overflow <= s_mb_interface.adc_readout.channel_pedestal_test_overflow;
s_vio_dbg_adc_pedestal_underflow <= s_mb_interface.adc_readout.channel_pedestal_test_underflow;
s_vio_dbg_adc_config_done(0) <= s_mb_interface.adc_readout_control.adc_config_done;
s_vio_dbg_adc_readout_initialized(0) <= s_mb_interface.adc_readout.readout_initialized;
s_vio_dbg_adc_idelay_calibration_done <= s_mb_interface.adc_readout.channel_idelay_calibration_done;
s_vio_dbg_adc_idelay_calibration_failed <= s_mb_interface.adc_readout.channel_idelay_calibration_failed;

-- t_db_clknet / system clock+reset health group
s_vio_dbg_bcr_locked(0) <= s_clkin.bcr.bcr_locked;
s_vio_dbg_locked_db(0) <= s_clknet.locked_db;
-- t_gth_link_debug group (see db6_design_package.vhd)
s_vio_dbg_link.qpllclksel <= s_clkin.qpllclksel;
-- bcr_tmr_error's 3 bits go straight to probe_in14 below now (item 1 rewiring)
s_vio_dbg_link.txsysclksel <= s_clkin.txsysclksel;
s_vio_dbg_link.rxsysclksel <= s_clkin.rxsysclksel;
s_vio_dbg_link.rxoutclksel <= s_clkin.rxoutclksel;
s_vio_dbg_link.txoutclksel <= s_clkin.txoutclksel;
s_vio_dbg_mmcm_gbt40_db6_locked(0) <= s_clknet_debug_status.mmcm_gbt40_db6_locked;
s_vio_dbg_clk_1hz(0) <= s_clknet.clk_1hz;
s_vio_dbg_gbt_cdc_phase_override_rb(0) <= s_cfgbus_interface.db_reg_rx(cfb_db_debug)(c_db_debug_gbt_cdc_phase_array);
s_vio_dbg_gbt_cdc_phase_override_rb(1) <= s_cfgbus_interface.db_reg_rx(cfb_db_debug)(c_db_debug_gbt_cdc_phase_array + 1);
-- tx_ph's 4 bits go straight to probe_in22 below now (item 1 rewiring)
s_vio_dbg_mb_fpga_reset_low_q0(0) <= s_clknet.mb_fpga_reset_low.q0;
s_vio_dbg_gbtx_rxready(0) <= p_gbtx_rxready_in(0);
s_vio_dbg_locked_tp_q0(0) <= s_clknet.locked_tp_q0;
s_vio_dbg_mb_fpga_reset_low_q1(0) <= s_clknet.mb_fpga_reset_low.q1;
s_vio_dbg_link.qpll1lock <= s_sfp_ku_mgt.qpll1lock_out(1);
-- gth_status's 11 bits go straight to probe_in28 below now (item 1 rewiring)
-- sfp_module_status's 6 bits go straight to probe_in29 below now (item 1 rewiring)
s_vio_dbg_db_leds <= s_clkin.db_leds;
s_vio_dbg_db_side(0) <= p_db_side_in(0);
-- gbtx_shadow's fields go straight to probe_in32 below now (item 1 rewiring)
s_vio_dbg_running_time <= s_clknet.running_time;
s_vio_dbg_md_number <= p_md_number_in;
s_vio_dbg_dna <= s_system_management_interface.ku_dna(7 downto 0);
s_vio_dbg_dna_done(0) <= s_system_management_interface.ku_dna_done;
s_vio_dbg_link.wordclk_locked <= s_clknet_debug_status.wordclk_locked;
s_vio_dbg_link.cdc_reset_array <= s_clknet_debug_status.cdc_reset_array;
s_vio_dbg_mb_jtag_id_q0 <= s_mb_interface.mb_jtag_id.q0;
s_vio_dbg_mb_jtag_id_q1 <= s_mb_interface.mb_jtag_id.q1;
s_vio_dbg_mb_jtag_done(0) <= s_mb_interface.mb_jtag_done.q0;
s_vio_dbg_mb_jtag_done(1) <= s_mb_interface.mb_jtag_done.q1;
s_vio_dbg_sfp_addr_echo0 <= s_cfgbus_interface.db_reg_rx(cfb_sfp_reg_address)(6 downto 0);
s_vio_dbg_sfp_addr_echo1 <= s_cfgbus_interface.db_reg_rx(cfb_sfp_reg_address)(14 downto 8);
s_vio_dbg_gbtx_config_readback <= s_gbtx_interface.gbtx_config_readback.doutb;
s_vio_dbg_hss_rst_seq_done <= s_adc_rst_seq_done;
s_vio_dbg_hss_fifo_data_valid <= s_adc_fifo_data_valid;
s_vio_dbg_boot_done_mb_bs_q0(0) <= s_mb_interface.mb_boundary_scan_boot_done.q0;
s_vio_dbg_boot_done_mb_bs_q1(0) <= s_mb_interface.mb_boundary_scan_boot_done.q1;
s_vio_dbg_boot_done_gbtx_write(0) <= s_boot_gbtx_write_done;
s_vio_dbg_boot_done_gbtx_read(0) <= s_boot_gbtx_read_done;
s_vio_dbg_boot_done_sfp_q0(0) <= s_boot_sfp_read_done(0);
s_vio_dbg_boot_done_sfp_q1(0) <= s_boot_sfp_read_done(1);

-- db6_adc_config_driver status readback + dual-uplink sync mismatch comparator: wired
-- directly at the probe_in port map below (see the signal declarations above for why).

-- plugin-critical group
s_vio_dbg_flash_status <= s_system_management_interface.flash_status;
s_vio_dbg_flash_rdata <= s_system_management_interface.flash_rdata;
s_vio_dbg_ddm_temp_q0 <= s_sfp_interface.ddm(0)(c_sfp_temperature);
s_vio_dbg_ddm_temp_q1 <= s_sfp_interface.ddm(1)(c_sfp_temperature);
s_vio_dbg_ddm_vcc_q0 <= s_sfp_interface.ddm(0)(c_sfp_vcc);
s_vio_dbg_ddm_vcc_q1 <= s_sfp_interface.ddm(1)(c_sfp_vcc);
s_vio_dbg_ddm_txbias_q0 <= s_sfp_interface.ddm(0)(c_sfp_tx_bias_current);
s_vio_dbg_ddm_txbias_q1 <= s_sfp_interface.ddm(1)(c_sfp_tx_bias_current);
s_vio_dbg_ddm_txpower_q0 <= s_sfp_interface.ddm(0)(c_sfp_tx_power);
s_vio_dbg_ddm_txpower_q1 <= s_sfp_interface.ddm(1)(c_sfp_tx_power);
s_vio_dbg_ddm_rxpower_q0 <= s_sfp_interface.ddm(0)(c_sfp_rx_power);
s_vio_dbg_ddm_rxpower_q1 <= s_sfp_interface.ddm(1)(c_sfp_rx_power);
s_vio_dbg_ddm_lasertemp_q0 <= s_sfp_interface.ddm(0)(c_sfp_laser_temperature);
s_vio_dbg_ddm_lasertemp_q1 <= s_sfp_interface.ddm(1)(c_sfp_laser_temperature);
s_vio_dbg_ddm_teccurrent_q0 <= s_sfp_interface.ddm(0)(c_sfp_tec_current);
s_vio_dbg_ddm_teccurrent_q1 <= s_sfp_interface.ddm(1)(c_sfp_tec_current);
s_vio_dbg_sfp_shadow_q0 <= s_sfp_ku_mgt.sfp_tx_register(0);
s_vio_dbg_sfp_shadow_q1 <= s_sfp_ku_mgt.sfp_tx_register(1);

-- t_adc_readout_control (calibration thresholds) + system control group -- probe_out driven
-- straight from the vio instantiation below, these are just the readback/passthrough side
s_clknet_debug_control.adc_readout.high_threshold <= s_vio_dbg_adc_high_thresh;
s_clknet_debug_control.adc_readout.low_threshold <= s_vio_dbg_adc_low_thresh;
s_clknet_debug_control.adc_readout.threshold_select_channel <= s_vio_dbg_adc_thresh_sel_ch;
-- reset_controls/force_gtx_i2c_config/cis_manual_control/mb_fpga_reset_low_ctrl/
-- flash_manual_access all now driven directly from the probe_out port map below
-- (item 1 rewiring) -- 2026-09-12 fixed a pre-existing typo here in the process
-- ("s_vio_dbg_sfp_addr_outs_q0", an undeclared identifier -- should have been
-- s_vio_dbg_sfp_addr_out_q0, the signal probe_out7 actually drives).
s_sfp_reg_address_vio(0) <= s_vio_dbg_sfp_addr_out_q0;
s_sfp_reg_address_vio(1) <= s_vio_dbg_sfp_addr_out_q1;

-- kept as an internal signal (rather than reading the p_mb_fpga_reset_low out port
-- directly) so proc_mb_boundary_scan_timed_trigger below can watch it release.
-- 2026-09-12: fixed a pre-existing typo on the q1 line ("as_mb_reset_vio", an
-- undeclared identifier -- should have been the q1 sibling of the q0 line above).
-- Both now reference s_mb_interface_in.mb_reset (see that signal's declaration).
s_mb_fpga_reset_low_out.q0 <= not s_mb_interface_in.mb_reset.q0 and s_clknet.mb_fpga_reset_low.q0 and not s_mb_fpga_reset_low.q0 and (not s_master_reset(c_mb0_reset_bit));
s_mb_fpga_reset_low_out.q1 <= not s_mb_interface_in.mb_reset.q1 and s_clknet.mb_fpga_reset_low.q1 and not s_mb_fpga_reset_low.q1 and (not s_master_reset(c_mb1_reset_bit));
p_mb_fpga_reset_low <= s_mb_fpga_reset_low_out;

-- fires a one-shot boundary-scan trigger ~1s after each side's altera companion
-- fpga reset (p_mb_fpga_reset_low, active low) releases, so the scan captures the
-- chip's io state once it's had time to boot/configure, not right at reset release.
proc_mb_boundary_scan_timed_trigger : process(s_clknet.clk_100hz)
variable v_reset_low_prev : t_mb_std_logic := (q0 => '0', q1 => '0');
variable v_delay_cnt_q0, v_delay_cnt_q1 : integer range 0 to 99 := 0;
variable v_delay_running_q0, v_delay_running_q1 : std_logic := '0';
begin
    if rising_edge(s_clknet.clk_100hz) then

        s_mb_boundary_scan_timed_trigger.q0 <= '0';
        s_mb_boundary_scan_timed_trigger.q1 <= '0';

        if v_reset_low_prev.q0 = '0' and s_mb_fpga_reset_low_out.q0 = '1' then -- rising edge: reset released
            v_delay_running_q0 := '1';
            v_delay_cnt_q0 := 0;
        elsif v_delay_running_q0 = '1' then
            if v_delay_cnt_q0 < 99 then
                v_delay_cnt_q0 := v_delay_cnt_q0 + 1;
            else
                s_mb_boundary_scan_timed_trigger.q0 <= '1';
                v_delay_running_q0 := '0';
            end if;
        end if;

        if v_reset_low_prev.q1 = '0' and s_mb_fpga_reset_low_out.q1 = '1' then -- rising edge: reset released
            v_delay_running_q1 := '1';
            v_delay_cnt_q1 := 0;
        elsif v_delay_running_q1 = '1' then
            if v_delay_cnt_q1 < 99 then
                v_delay_cnt_q1 := v_delay_cnt_q1 + 1;
            else
                s_mb_boundary_scan_timed_trigger.q1 <= '1';
                v_delay_running_q1 := '0';
            end if;
        end if;

        v_reset_low_prev := s_mb_fpga_reset_low_out;

    end if;
end process;


-- db6_altera_jtag_driver now lives in db6_mainboard_interface, gated by a
-- configbus enable bit instead of this vio; probe_in0-3 stay as a read-only
-- view of the resulting t_mb_interface registers. Proasic jtag was removed
-- (db6_proasic_jtag_driver was dead code); its probes are tied off.
--i_vio_mb_jtag_debug : vio_mb_jtag_debug
--  PORT MAP (
--    clk => s_clknet.osc_clk100,
--    probe_in0(0) => s_mb_interface.mb_jtag_done.q0,
--    probe_in1 => s_mb_interface.mb_jtag_id.q0,
--    probe_in2(0) => s_mb_interface.mb_jtag_done.q1,
--    probe_in3 => s_mb_interface.mb_jtag_id.q1,
--    probe_in4(0) => '0',
--    probe_in5 => (others => '0'),
--    probe_in6 => (others => '0'),
--    probe_out0 => open,
--    probe_out1 => open,
--    probe_out2 => open,
--    probe_out3(0) => s_mb_fpga_reset_low.q0,
--    probe_out4(0) => s_mb_fpga_reset_low.q1,
--    probe_out5 => open,
--    probe_out6 => open
--  );



--p_ku_hard_reset <= not s_cfgbus_interface.db_reg_rx(cfb_db_debug)(c_fpga_hard_reset_bit);



--clock interface
i_db6_clock_interface : entity tilecal.db6_clock_interface
   generic map (   
        g_num_gth_links                => g_num_gth_links,          --! num_links: number of links instantiated by the core (altera: up to 6, xilinx: up to 4)
        g_num_gth_ref_clks             => g_num_gth_ref_clks,
        GLOBAL_DATE => GLOBAL_DATE, -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME => GLOBAL_TIME -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)

        )
    port map(
        --status input
        p_clkin_in.db_side => p_db_side_in,
        p_clkin_in.md_number => p_md_number_in,
        p_clkin_in.gbtx_rxready(0) => p_gbtx_rxready_in(0),
        p_clkin_in.gbtx_rxready(1) => '0', --p_gbtx_rxready_in(0),
        p_clkin_in.gbtx_datavalid(0)=> p_gbtx_datavalid_in(0),
        p_clkin_in.gbtx_datavalid(1)=> '0', --p_gbtx_datavalid_in(0),
        --clocks
        p_clkin_in.osc_clkin => p_osc_clk_in,
        --p_clkinputs_in.db_clkin_local => p_gbt_db_clk40_local_in,
        --p_clkinputs_in.db_clkin_remote => p_gbt_db_clk40_remote_in,
        p_clkin_in.cfgbus_clkin_local => p_gbt_cfgbus_clk40_local_in,
        p_clkin_in.cis_hss_clkin_local => p_gbt_cis_hss_clk80_local_in,
        p_clkin_in.cfgbus_clkin_remote => ('0','0'),--p_gbt_cfgbus_clk40_remote_in,
        p_clkin_in.mb_q0_clkin_local => ('1','0'), --p_gbt_mb_q0_clk40_local_in,
        p_clkin_in.mb_q1_clkin_local => ('1','0'), --p_gbt_mb_q1_clk40_local_in,
        p_clkin_in.mb_q0_clkin_remote => ('1','0'),--p_gbt_mb_q0_clk40_remote_in,
        p_clkin_in.mb_q1_clkin_remote => ('1','0'),--p_gbt_mb_q1_clk40_remote_in,
        p_clkin_in.tp_q0_clkin_local => p_gbt_tp_q0_clk40_local_in, --('1','0'), --p_gbt_tp_q0_clk40_local_in,
        p_clkin_in.tp_q1_clkin_local => ('1','0'), --p_gbt_tp_q1_clk40_local_in,
        p_clkin_in.tp_q0_clkin_remote => ('1','0'),--p_gbt_tp_q0_clk40_remote_in,
        p_clkin_in.tp_q1_clkin_remote => ('1','0'),--p_gbt_tp_q1_clk40_remote_in,
        p_clkin_in.gth_refclk_gbtx_local => p_gth_refclk_gbtx_local_in,
        p_clkin_in.gth_refclk_gbtx_remote => (others => ('1','0')), --p_gth_refclk_gbtx_remote_in,
        p_clkin_in.gth_txwordclk80_in => s_clkin.gth_txwordclk80_in,
        p_clkin_in.gth_txwordclk40_in => s_clkin.gth_txwordclk40_in,
        p_clkin_in.gth_rxwordclk40_in => s_clkin.gth_rxwordclk40_in,
        p_clkin_in.gth_txoutclkfabric_out => s_clkin.gth_txoutclkfabric_out,
        p_clkin_in.gth_rxoutclkfabric_out => s_clkin.gth_rxoutclkfabric_out,
        p_clkin_in.clksel => s_clkin.clksel,
        p_clkin_in.gth_wordclk_sel => s_clkin.gth_wordclk_sel,
        p_clkin_in.cpllclksel => s_clkin.cpllclksel,
        p_clkin_in.qpllclksel => s_clkin.qpllclksel,
        p_clkin_in.txsysclksel => s_clkin.txsysclksel,
        p_clkin_in.rxsysclksel => s_clkin.rxsysclksel,
        p_clkin_in.txoutclksel => s_clkin.txoutclksel,
        p_clkin_in.rxoutclksel => s_clkin.rxoutclksel,
        p_clkin_in.txpllclksel => s_clkin.txpllclksel,
        p_clkin_in.rxpllclksel => s_clkin.rxpllclksel,
        p_clkin_in.sfp_ku_mgt => s_sfp_ku_mgt,
        p_clkin_in.db6_gbt_bank => s_db6_gbt_bank,
        p_clkin_in.gbt_encoder_interface => s_gbt_encoder_interface,
        p_clkin_in.mb_interface => s_mb_interface,
        p_clkin_in.gbtx_interface => s_gbtx_interface,
        p_clkin_in.db6_sem_interface => s_db6_sem_interface,
        p_clkin_in.sfp_interface => s_sfp_interface,
        p_clkin_in.bcr => s_clkin.bcr,
        p_clkin_in.db_leds => s_clkin.db_leds,
        
        
        p_clknet_out => s_clknet,

        --control signals
        p_master_reset_in => s_master_reset(c_clknet_reset_bit),
        --p_db_reg_rx_in => s_db_reg_rx,
        p_cfgbus_interface_in => s_cfgbus_interface,

        -- vio_clknet_status lives here now; see i_vio_clknet_status below
        p_clknet_debug_status_out => s_clknet_debug_status,
        p_clknet_debug_control_in => s_clknet_debug_control,
        p_mb_reset_vio_in => s_mb_interface_in.mb_reset,

        -- plain-logic side of the raw pads/wizards now in db7_io_box
        p_gth_refclk_local_in   => s_gth_refclk_local,
        p_osc_clk100_in         => s_osc_clk100,
        p_osc_clk40_in          => s_osc_clk40,
        p_osc_clk200_in         => s_osc_clk200,
        p_osc_locked_in         => s_osc_locked,
        p_cfgbus_clk40_local_in => s_cfgbus_clk40_local,

        --leds
        p_leds_out => s_leds(leds_clk_interface)

    );



        --mainboard interface
i_db6_mainboard_interface : entity tilecal.db6_mainboard_interface
      generic map(
        -- iddr280 | iddr280_clkdiv | hss_wizard (must match i_db7_io_box below)
        -- 2026-09-12: switched to iddr280_clkdiv to test -- hss_wizard kept showing
        -- per-channel bitslip on live ADC data even after fixing the raw-domain CDC and
        -- the GBT encoder gearbox CDC; trying the IDDRE1-based datapath instead, which
        -- doesn't go through the SelectIO Wizard/ISERDES3 path at all.
        g_adc_clocking_scheme => g_adc_clocking_scheme,
        -- mb boundary-scan (sample) feature kill switch: false because triggering
        -- any jtag instruction change freezes this altera companion fpga's firmware
        -- until reset (confirmed via the ir-only bisection test mode). flip to true
        -- only once that's understood/fixed on the altera side, or for a
        -- mainboard/firmware revision confirmed not to have the issue.
        g_enable_mb_boundary_scan => false
        )
      Port map(
        p_master_reset_in => s_master_reset,
        p_clknet_in  => s_clknet,
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,
        -- adc interface (plain logic; pads reached via i_db7_io_box below)
        p_adc_bitclk_in => s_adc_bitclk,
        p_adc_bitclkdiv_in => s_adc_bitclkdiv,
        p_frame_missalignment_in => s_frame_missalignment,
        p_adc_frameclk_in => s_adc_frameclk,
        p_adc_lg_data_in => s_adc_lg_data,
        p_adc_hg_data_in => s_adc_hg_data,
        p_adc_pll0_locked_in => s_adc_pll0_locked,
        p_adc_frameclk_iserdese_in => s_adc_frameclk_iserdese,
        p_adc_lg_data_iserdese_in  => s_adc_lg_data_iserdese,
        p_adc_hg_data_iserdese_in  => s_adc_hg_data_iserdese,
        p_adc_frame_missalignment_out => s_adc_frame_missalignment_iserdese,
        p_adc_ctrl_reset_from_sm_in   => s_adc_ctrl_reset_from_sm_iserdese,
        -- mb interface (plain logic; pads reached via i_db7_io_box below)
        p_ssel_out         => s_mb_driver_ssel,
        p_sclk_out         => s_mb_driver_sclk,
        p_sdata_out     => s_mb_driver_sdata_tx,
        p_sdata_in    => s_mb_driver_sdata_rx,
        --cis interface (plain logic; pads reached via i_db7_io_box below)
        p_tph_out               => s_tph,
        p_tpl_out               => s_tpl,
        --mainboard jtag chain (pads driven directly, no io box primitives needed)
        p_mb_jtag_tck_out => p_mb_tck_out,
        p_mb_jtag_tms_out => p_mb_tms_out,
        p_mb_jtag_tdi_out => p_mb_tdi_out,
        p_mb_jtag_tdo_in  => p_mb_tdo_in,
        p_mb_boundary_scan_reg_address_vio_in => s_mb_boundary_scan_reg_address_vio,
        p_boundary_scan_timed_trigger_in => s_mb_boundary_scan_timed_trigger,
        p_mb_interface_in => s_mb_interface_in,
        --integrator
        p_integrator_sda_drive_out => s_integrator_sda_drive,
        p_integrator_sda_tri_out   => s_integrator_sda_tri,
        p_integrator_sda_read_in   => s_integrator_sda_read,
        p_integrator_scl_drive_out => s_integrator_scl_drive,
        p_integrator_scl_tri_out   => s_integrator_scl_tri,
        p_integrator_scl_read_in   => s_integrator_scl_read,
        
        p_mb_interface_out          => s_mb_interface,
        
        --leds
        p_leds_out => s_leds(leds_mb_interface)

    
  );

-- IO isolation boundary (stage 2: + ADC/CFGBUS/CIS IO, see db7_io_box.vhd header)
i_db7_io_box : entity tilecal.db7_io_box
    generic map (
        g_num_gth_links    => g_num_gth_links,
        g_num_gth_ref_clks => g_num_gth_ref_clks,
        -- iddr280 | iddr280_clkdiv | hss_wizard (must match i_db6_mainboard_interface above)
        g_adc_clocking_scheme => g_adc_clocking_scheme
    )
    port map (
        p_clknet_in    => s_clknet,
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,

        p_ssel_out  => p_ssel_out,
        p_sclk_out  => p_sclk_out,
        p_sdata_out => p_sdata_out,
        p_sdata_in  => p_sdata_in,

        p_mb_driver_ssel_in      => s_mb_driver_ssel,
        p_mb_driver_sclk_in      => s_mb_driver_sclk,
        p_mb_driver_sdata_tx_in  => s_mb_driver_sdata_tx,
        p_mb_driver_sdata_rx_out => s_mb_driver_sdata_rx,

        p_adc_master_reset_in => s_master_reset(c_adc_readout_reset_bit),
        p_adc_bitclk_in       => p_adc_bitclk_in,
        p_adc_frameclk_in     => p_adc_frameclk_in,
        p_adc_hss_aux0_in     => p_adc_hss_aux0_in,
        p_adc_hss_aux1_in     => p_adc_hss_aux1_in,
        p_adc_hss_aux2_in     => p_adc_hss_aux2_in,
        p_adc_lg_data_in      => p_adc_lg_data_in,
        p_adc_hg_data_in      => p_adc_hg_data_in,
        p_gbtx_clk40_b68_in   => p_gbtx_clk40_b68_in,
        p_gbtx_clk40_b67_in   => p_gbtx_clk40_b67_in,
        p_gbtx_clk40_b66_in   => p_gbtx_clk40_b66_in,
        p_gbtx_clk40_b47_in   => p_gbtx_clk40_b47_in,
        p_gbtx_clk40_b46_in   => p_gbtx_clk40_b46_in,
        p_gbtx_clk40_b44_in   => p_gbtx_clk40_b44_in,
        p_gbtx_clk80_b68_in   => p_gbtx_clk80_b68_in,
        p_gbtx_clk80_b67_in   => p_gbtx_clk80_b67_in,
        p_gbtx_clk80_b66_in   => p_gbtx_clk80_b66_in,
        p_gbtx_clk80_b47_in   => p_gbtx_clk80_b47_in,
        p_gbtx_clk80_b46_in   => p_gbtx_clk80_b46_in,
        p_gbtx_clk80_b44_in   => p_gbtx_clk80_b44_in,
        p_gbtx_clk40_data_out => s_gbtx_clk40_data,
        p_gbtx_clk80_data_out => s_gbtx_clk80_data,
        p_adc_bitclk_out           => s_adc_bitclk,
        p_adc_bitclkdiv_out        => s_adc_bitclkdiv,
        p_frame_missalignment_out  => s_frame_missalignment,
        p_adc_frameclk_out         => s_adc_frameclk,
        p_adc_lg_data_out          => s_adc_lg_data,
        p_adc_hg_data_out          => s_adc_hg_data,
        p_adc_pll0_locked_out      => s_adc_pll0_locked,
        p_adc_idelay_ctrl_in       => s_mb_interface.adc_readout_control,
        p_adc_frame_missalignment_in => s_adc_frame_missalignment_iserdese,
        p_adc_ctrl_reset_from_sm_out => s_adc_ctrl_reset_from_sm_iserdese,
        p_adc_frameclk_iserdese_out  => s_adc_frameclk_iserdese,
        p_adc_lg_data_iserdese_out   => s_adc_lg_data_iserdese,
        p_adc_hg_data_iserdese_out   => s_adc_hg_data_iserdese,
        p_adc_rst_seq_done_out    => s_adc_rst_seq_done,
        p_adc_fifo_data_valid_out => s_adc_fifo_data_valid,

        p_cfgbus_master_reset_in => s_master_reset(c_cfgbus_reset_bit),
        p_cfgbus_data_local_in   => p_cfgbus_data_local_in,
        p_cfgbus_bitslice_local_out => s_cfgbus_bitslice_local,

        p_cis_master_reset_in => s_master_reset(c_cis_reset_bit),
        p_tph_out => p_tph_out,
        p_tpl_out => p_tpl_out,
        p_tph_in  => s_tph,
        p_tpl_in  => s_tpl,

        p_tx_sfp_out           => p_tx_sfp_out,
        p_rx_sfp_in            => p_rx_sfp_in,
        p_rx_gbtx_from_fpga_in => p_rx_gbtx_from_fpga_in,

        p_ku_mgt_out            => s_ku_mgt_from_box,
        p_mgt_txusrclk_out      => s_mgt_txusrclk,
        p_mgt_rxusrclk_out      => s_mgt_rxusrclk,
        p_mgt_txreset_in        => s_mgt_txreset,
        p_mgt_rxreset_in        => s_mgt_rxreset,
        p_mgt_txready_out       => s_mgt_txready,
        p_mgt_rxready_out       => s_mgt_rxready,
        p_mgt_headerlocked_out  => s_mgt_headerlocked,
        p_mgt_rstcnt_out        => s_mgt_rstcnt,
        p_mgt_autorsten_in      => s_mgt_autorsten,
        p_mgt_autorstoneven_in  => s_mgt_autorstoneven,
        p_mgt_usrword_in        => s_mgt_usrword,
        p_mgt_devspec_i_in      => s_mgt_devspec_i,
        p_mgt_devspec_o_out     => s_mgt_devspec_o,

        p_osc_clk_in            => p_osc_clk_in,
        p_gth_refclk_gbtx_local_in => p_gth_refclk_gbtx_local_in,
        p_gbt_cfgbus_clk40_local_in => p_gbt_cfgbus_clk40_local_in,

        p_gth_refclk_local_out  => s_gth_refclk_local,
        p_osc_clk100_out        => s_osc_clk100,
        p_osc_clk40_out         => s_osc_clk40,
        p_osc_clk200_out        => s_osc_clk200,
        p_osc_locked_out        => s_osc_locked,
        p_cfgbus_clk40_local_out => s_cfgbus_clk40_local,

        p_xadc_analog_in  => p_xadc_analog_in,
        p_xadc_i2c_inout  => p_xadc_i2c_inout,
        p_xadc_control_in  => s_xadc_control_to_box,
        p_xadc_control_out => s_xadc_control_from_box,

        p_sfp_i2c_scl_inout    => p_sfp_i2c_scl_inout,
        p_sfp_i2c_sda_inout    => p_sfp_i2c_sda_inout,
        p_gbtx_i2c_scl_inout   => p_gbtx_i2c_scl_inout,
        p_gbtx_i2c_sda_inout   => p_gbtx_i2c_sda_inout,
        p_integrator_sda_inout => p_integrator_sda_inout,
        p_integrator_scl_inout => p_integrator_scl_inout,

        p_sfp_sda_drive_in  => s_sfp_sda_drive,
        p_sfp_sda_tri_in    => s_sfp_sda_tri,
        p_sfp_sda_read_out  => s_sfp_sda_read,
        p_sfp_scl_drive_in  => s_sfp_scl_drive,
        p_sfp_scl_tri_in    => s_sfp_scl_tri,
        p_sfp_scl_read_out  => s_sfp_scl_read,
        p_gbtx_sda_drive_in => s_gbtx_sda_drive,
        p_gbtx_sda_tri_in   => s_gbtx_sda_tri,
        p_gbtx_sda_read_out => s_gbtx_sda_read,
        p_gbtx_scl_drive_in => s_gbtx_scl_drive,
        p_gbtx_scl_tri_in   => s_gbtx_scl_tri,
        p_gbtx_scl_read_out => s_gbtx_scl_read,
        p_integrator_sda_drive_in => s_integrator_sda_drive,
        p_integrator_sda_tri_in   => s_integrator_sda_tri,
        p_integrator_sda_read_out => s_integrator_sda_read,
        p_integrator_scl_drive_in => s_integrator_scl_drive,
        p_integrator_scl_tri_in   => s_integrator_scl_tri,
        p_integrator_scl_read_out => s_integrator_scl_read,

        p_proasic_tms_out  => p_proasic_tms_out,
        p_proasic_tck_out  => p_proasic_tck_out,
        p_proasic_tdi_out  => p_proasic_tdi_out,
        p_proasic_tdo_in   => p_proasic_tdo_in,
        p_proasic_trst_out => p_proasic_trst_out,

        p_flash_control_in  => s_flash_control_to_box,
        p_flash_control_out => s_flash_control_from_box
    );

i_db6_sfp_interface : entity tilecal.db6_sfp_interface
   generic map (   
        g_num_gth_links                => g_num_gth_links,          --! num_links: number of links instantiated by the core (altera: up to 6, xilinx: up to 4)
        -- hog
        GLOBAL_DATE => GLOBAL_DATE, -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME => GLOBAL_TIME -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
        )
  port map(
        p_clknet_in => s_clknet,
        p_master_reset_in => s_master_reset,
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,
        p_gbt_encoder_interface_out => s_gbt_encoder_interface,
        
        p_ku_mgt => s_sfp_ku_mgt,

        -- db6_mgt now lives in db7_io_box; pads reached via i_db7_io_box below.
        p_ku_mgt_in              => s_ku_mgt_from_box,
        p_mgt_txusrclk_in        => s_mgt_txusrclk,
        p_mgt_rxusrclk_in        => s_mgt_rxusrclk,
        p_mgt_txreset_out        => s_mgt_txreset,
        p_mgt_rxreset_out        => s_mgt_rxreset,
        p_mgt_txready_in         => s_mgt_txready,
        p_mgt_rxready_in         => s_mgt_rxready,
        p_mgt_headerlocked_in    => s_mgt_headerlocked,
        p_mgt_rstcnt_in          => s_mgt_rstcnt,
        p_mgt_autorsten_out      => s_mgt_autorsten,
        p_mgt_autorstoneven_out  => s_mgt_autorstoneven,
        p_mgt_usrword_out        => s_mgt_usrword,
        p_mgt_devspec_i_out      => s_mgt_devspec_i,
        p_mgt_devspec_o_in       => s_mgt_devspec_o,

        p_sfp_abs_in => p_sfp_abs_in,
        p_sfp_los_in => p_sfp_los_in,
        p_sfp_tx_fault_in => p_sfp_tx_fault_in,

        p_sda_drive_out => s_sfp_sda_drive,
        p_sda_tri_out   => s_sfp_sda_tri,
        p_sda_read_in   => s_sfp_sda_read,
        p_scl_drive_out => s_sfp_scl_drive,
        p_scl_tri_out   => s_sfp_scl_tri,
        p_scl_read_in   => s_sfp_scl_read,
        p_sfp_control_in => s_sfp_control,
        p_sfp_interface_out => s_sfp_interface,
        p_sfp_reg_address_vio_in => s_sfp_reg_address_vio,

        --tdo from remote fpga
        p_tdo_remote_in => p_tdo_remote_in,
        
        --interfaces
        p_gbt_bank_out => s_db6_gbt_bank,
        -- 2026-09-14: s_mb_interface_gbt_tx (not raw s_mb_interface) so
        -- db6_data_readout_inject_debug's hg_data/lg_data override reaches the gbt
        -- encoder chain -- see that signal's declaration comment above.
        p_mb_interface_in => s_mb_interface_gbt_tx,
        p_sem_interface_in => s_sem_interface,
        p_system_management_interface_in => s_system_management_interface,
        p_gbtx_interface_in => s_gbtx_interface,
        p_serial_id_interface_in => s_serial_id_interface, 
        p_db6_sem_interface_in => s_db6_sem_interface,
        p_cfgbus_interface_in => s_cfgbus_interface,
        --leds
        p_leds_out => s_leds(leds_sfp_interface)
  );


-- system manager (pgoods, temps, vccint... legacy xadc module)
i_db6_system_management_interface : entity tilecal.db6_system_management_interface
    port map ( 
        p_clknet_in => s_clknet,
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,
        p_master_reset_in => s_master_reset_async(c_master_reset_bit),
        
        --xadc: plain logic; pad reached via i_db7_io_box below
        p_pgood_in => p_pgood_in,
        p_xadc_control_out => s_xadc_control_to_box,
        p_xadc_control_in  => s_xadc_control_from_box,

        --device dna (db6_ku_dna, moved here from db6_clock_interface); manual re-read
        --trigger from vio_clknet_status
        p_dna_reset_in => s_dna_reset,

        --is25lp256 config flash: plain logic; STARTUPE3 reached via i_db7_io_box below
        p_flash_control_out => s_flash_control_to_box,
        p_flash_control_in  => s_flash_control_from_box,

        --output
        p_system_management_interface_out => s_system_management_interface, 
        
        --leds and debug_out
        p_leds_out => s_leds(leds_system_management)
    
    );

--gbtx interface (includes configbus) 
i_db6_gbtx_interface : entity tilecal.db6_gbtx_interface
  port map(       
        p_clknet_in => s_clknet,
        p_master_reset_in  => s_master_reset,
        
        p_cfgbus_data_local_in => s_cfgbus_bitslice_local, -- plain logic; pad reached via i_db7_io_box
        p_cfgbus_interface => s_cfgbus_interface,
        p_bcr_out => s_clkin.bcr,
        
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,
        p_gbt_encoder_interface_in => s_gbt_encoder_interface,
        
        
        
        p_gbtx_control_in => s_gbtx_control,
        p_gbtx_i2c_rem_enable_out => open, --p_gbtx_i2c_rem_enable_out,
        p_gbtx_interface_out => s_gbtx_interface,
        p_sda_drive_out => s_gbtx_sda_drive,
        p_sda_tri_out   => s_gbtx_sda_tri,
        p_sda_read_in   => s_gbtx_sda_read,
        p_scl_drive_out => s_gbtx_scl_drive,
        p_scl_tri_out   => s_gbtx_scl_tri,
        p_scl_read_in   => s_gbtx_scl_read,
        p_gbtx_configsel_out(0) => p_gbtx_configsel_out(0),
        p_gbtx_reg_readback_address_in => s_gbtx_reg_readback_address,

        p_leds_out => open
);

-- gbtx register readback ram port b address: configbus command ORed with the vio
-- debug probe_out (don't drive both non-zero at once)
s_gbtx_reg_readback_address <= s_cfgbus_interface.db_reg_rx(cfb_gbtx_reg_readback_address)(8 downto 0) or s_gbtx_reg_readback_address_vio;

gen_include_sem : if g_include_sem = 1 generate
    i_db6_sem_interface : entity tilecal.db6_sem_interface
        port map(
                p_clknet_in             => s_clknet,
                p_master_reset_in       => s_master_reset(c_sem_reset_bit),
                p_db_reg_rx_in  => s_cfgbus_interface.db_reg_rx,
                p_sem_interface_out => s_db6_sem_interface,
                p_sem_uart_rx_in => p_sem_uart_rx_in,
                p_sem_uart_tx_out => p_sem_uart_tx_out 
       );
end generate;


gen_include_debug_interface : if g_include_debug_interface = 1 generate
    i_db6_debug_interface : entity tilecal.db6_debug_interface
       generic map(   
            g_tmr_enabled                   => 0,
            -- hog
            GLOBAL_DATE => GLOBAL_DATE, -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
            GLOBAL_TIME => GLOBAL_TIME, -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
            GLOBAL_VER => GLOBAL_VER,  -- 32 bit Last version Tag when the project was modified. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
            GLOBAL_SHA => GLOBAL_SHA,  -- 32 bit Git hash (SHA) of the last commit when the project was modified.
            TOP_VER => TOP_VER, -- 32 bit Top directory version, containing the hog.conf file and other files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
            TOP_SHA => TOP_SHA, -- 32 bit Top directory version, containing the hog.conf file and other files.
            CON_VER => CON_VER, -- 32 bit The version of the constraint files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
            CON_SHA => CON_SHA, -- 32 bit The git commit hash (SHA) of the constraint files.
            HOG_VER => HOG_VER, -- 32 bit Hog submodule version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
            HOG_SHA => HOG_SHA -- 32 bit Hog submodule git commit hash (SHA).
--            XML_VER => XML_VER, -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--            XML_SHA => XML_SHA -- 32 bit (optional) IPbus xml git commit hash (SHA).
       )
      port map( 
        p_master_reset_in => (others=>'0'),
        p_clknet_in  => s_clknet,
        p_db_reg_rx_debug_out => open,
      
          --interfaces
        p_gbt_encoder_interface_in => s_gbt_encoder_interface,  
        p_gbt_bank_in => s_db6_gbt_bank,
        p_mb_interface_in => s_mb_interface,
        p_sem_interface_in => s_sem_interface,
        p_system_management_interface_in => s_system_management_interface,
        p_gbtx_interface_in => s_gbtx_interface,
        p_serial_id_interface_in => s_serial_id_interface, 
        p_db6_sem_interface_in => s_db6_sem_interface,
        p_cfgbus_interface_in => s_cfgbus_interface,
        
        p_leds_in             => s_leds_out,
        
        p_debug_interface_uart_tx_out => p_debug_interface_uart_tx_out,
        p_debug_interface_uart_rx_in => p_debug_interface_uart_rx_in
--        p_cht8305c_sda_inout => p_cht8305c_sda_inout,
--        p_cht8305c_scl_inout => p_cht8305c_scl_inout
         
      );
end generate;

p_leds_out<=s_leds_out;


s_skip_main_sm <= ((s_clknet.skip_main_sm or s_cfgbus_interface.db_reg_rx(cfb_db_debug)(c_db_debug_skip_main_sm))); 
proc_startup_sm : process(s_clknet.clk_100hz,s_cfgbus_interface.db_reg_rx(cfb_strobe_reg)(c_dbmaster_reset_bit))
variable v_counter : integer range 0 to 65535 :=1;
variable v_gbtx_retries : integer range 0 to 31:=1;
-- distinguishes the two visits state 11 needs (trigger pulse, then wait for
-- busy='0') without adding a 16th state -- see "when 11" below
variable v_gbtx_read_triggered : std_logic := '0';
--constant c_max_count : integer range 0 to 15 := 5;
begin
    if s_cfgbus_interface.db_reg_rx(cfb_strobe_reg)(c_dbmaster_reset_bit) = '1' then
        s_counter <= 0;
        s_boot_gbtx_write_done <= '0';
        s_boot_gbtx_read_done  <= '0';
    elsif rising_edge(s_clknet.clk_100hz) then

        if s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0) <= "0000" then
            s_leds_out<=std_logic_vector(to_unsigned(s_counter,4));
            s_clkin.db_leds<=std_logic_vector(to_unsigned(s_counter,4));
        else
            s_leds_out<= s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0);
            s_clkin.db_leds<=s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0);
        end if;
        case s_counter is
            when 0 =>
                v_gbtx_retries:=0;
                v_gbtx_read_triggered:='0';
                if v_counter < 255 then
                    v_counter:=v_counter+1;
                else
                    s_counter <= s_counter+1;
                end if;
                s_master_reset_async <= x"FFFFFFFF";
                s_gbtx_control.gbtx_default_config <= '1';
                s_gbtx_control.gbtx_trigger_i2c_operation <= '0';
                s_gbtx_control.gbtx_i2c_read_write_operation <= '0';
                
                s_clkin_async.qpllclksel <= "010";--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.cpllclksel  <= "010";--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.gth_wordclk_sel <= '1';--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(3);
            when 1 =>
                v_counter:=0;
                s_counter <=s_counter+1;
                s_master_reset_async <= x"FFFFFFF6";
                s_gbtx_control.gbtx_default_config <= '1';
                s_gbtx_control.gbtx_trigger_i2c_operation <= p_md_number_in(0) or s_clknet.force_gtx_i2c_config; --'1';
                s_gbtx_control.gbtx_i2c_read_write_operation <= '0';
                
                s_clkin_async.qpllclksel <= "010";--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.cpllclksel  <= "010";--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.gth_wordclk_sel <= '1';--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(3);
                
            when 2 =>
                v_counter:=0;
                s_master_reset_async <= x"FFFFFFF6";
                s_gbtx_control.gbtx_default_config <= '1';
                s_gbtx_control.gbtx_trigger_i2c_operation <= '0';
                s_gbtx_control.gbtx_i2c_read_write_operation <= '0';
                if (s_gbtx_interface.busy = '0') 
                    or (s_skip_main_sm = '1')
--                    or (p_md_number_in(0) = '0')
                then --and (s_clknet.gbtx_rxready(0) = '1') then
                        s_counter <=s_counter+1;
                        s_boot_gbtx_write_done <= '1'; -- first default-config write completed
                else
                    s_counter <=2;
                end if;
            when 3 =>
                v_counter:=0;
                s_counter <=s_counter+1;
                s_gbtx_control.gbtx_default_config <= '0';
                s_master_reset_async(c_dbmaster_reset_bit) <= '0';--x"FFFFFFF" & "1110";
            when 4 =>
               
                s_master_reset_async(c_clknet_reset_bit) <= '0';
                if s_clknet.gbtx_rxready(0) = '1' then
                    s_counter <= s_counter + 1;
                else
                    if v_counter < 511 then
                        v_counter:=v_counter+1;
                    else
                        if v_gbtx_retries<31 then
                            v_counter:=0;
                            v_gbtx_retries:=v_gbtx_retries+1;
                            s_counter <= 1;
                        else
                            s_counter <= s_counter + 1;
                        end if;
                    end if;    
                end if;

            when 5 =>
                if v_counter < 63 then
                    v_counter:=v_counter+1;
                else
                    v_counter:=0;
                    s_counter <=s_counter+1;
                end if;
                s_master_reset_async(c_cfgbus_reset_bit) <= '0';
  
                s_master_reset_async(c_mb1_reset_bit) <= '0';
                s_master_reset_async(c_mb0_reset_bit) <= '0';
                
                s_master_reset_async(c_gth_buffbypass_tx_start_use_bit downto c_gth_reset_tx_pll_and_datapath_bit) <= "1111";
                s_master_reset_async(c_gth_ch1_reset_bit downto c_gbt_ch0_reset_bit) <= "1111";
                
                s_master_reset_async(c_gbt_reset_bit) <= '1';                
                s_master_reset_async(c_gth_reset_bit) <= '1';
                s_master_reset_async(c_gbt_encoder_reset_bit) <= '1';
                
                s_clkin_async.qpllclksel <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0); --"111";--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.cpllclksel  <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0); --"111";--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.gth_wordclk_sel <= '1';--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(3);

            when 6 =>
                s_master_reset_async(c_gth_buffbypass_tx_start_use_bit downto c_gth_reset_tx_pll_and_datapath_bit) <= "0000";
                s_master_reset_async(c_gth_ch1_reset_bit downto c_gbt_ch0_reset_bit) <= "0000";
                
                s_master_reset_async(c_gbt_reset_bit) <= '0';                
                s_master_reset_async(c_gth_reset_bit) <= '0';
                s_master_reset_async(c_gbt_encoder_reset_bit) <= '0';
                if v_counter<63 then
                    v_counter:=v_counter+1;
                    if ((s_sfp_ku_mgt.qpll1lock_out = "11") 
                        and (s_sfp_ku_mgt.gtwiz_buffbypass_tx_done_out="1") 
                        and (s_sfp_ku_mgt.gtwiz_reset_tx_done_out = "1"))
                        or (s_skip_main_sm = '0')
                    then
                        s_counter <=s_counter+1;
                        v_counter:=0;
                    end if;
                else
                    s_counter <=1;
                    v_counter:=0;
                end if; 
            when 7 =>
                if v_counter<63 then
                    v_counter:=v_counter+1;
                    if (s_db6_gbt_bank.tx_phcomputed_o(0)= '1' and s_db6_gbt_bank.tx_phcomputed_o(1)= '1'
                        and s_db6_gbt_bank.tx_phaligned_o(0)= '1' and s_db6_gbt_bank.tx_phaligned_o(1)= '1')
                        or (s_skip_main_sm = '0')
                        --and s_db6_gbt_bank.gbt_bank_sync = "111" 
                        then
                        s_counter <=s_counter+1;
                        v_counter:=0;
                    end if;
                else
                    s_counter <=5;
--                    s_counter <=s_counter+1;
                    v_counter:=0;
                end if;
                s_master_reset_async(c_adc_config_reset_bit) <= '1';
                s_master_reset_async(c_cis_reset_bit) <= '1';
                s_master_reset_async(c_integrator_reset_bit) <= '1';
            when 8 =>            
                if v_counter<255 then
                    v_counter:=v_counter+1;
                    if (s_mb_interface.adc_readout_control.adc_config_done = '1')
                    or (s_skip_main_sm = '1')
                    then
                        s_counter <=s_counter+1;
                        v_counter:=0;
                    end if;
                else
                    s_counter <=7;
                    v_counter:=0;               
                end if;
                s_master_reset_async(c_adc_config_reset_bit) <= '0';
                s_master_reset_async(c_cis_reset_bit) <= '0';
                s_master_reset_async(c_integrator_reset_bit) <= '0';
            when 9 =>
                v_counter:=0;
                s_counter <=s_counter+1;
                s_master_reset_async(c_adc_readout_reset_bit) <= '0';                
                s_master_reset_async(c_adc_readout_reset_channel_5_bit downto c_adc_readout_reset_channel_0_bit) <= "000000";
            when 10 => 
                v_counter:=0;
                s_counter <=s_counter+1;

--                s_clkin_async.qpllclksel <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);--"111";--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
--                s_clkin_async.cpllclksel  <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);--"111";--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
--                s_clkin_async.gth_wordclk_sel <= '1';--s_cfgbus_interface.db_reg_rx(cfb_tx_control)(3);
                
--                s_master_reset_async(c_gbt_reset_bit) <= '1';                
--                s_master_reset_async(c_gth_reset_bit) <= '1';
--                s_master_reset_async(c_gbt_encoder_reset_bit) <= '1';
--                s_master_reset_async(c_gth_buffbypass_tx_start_use_bit downto c_gth_reset_tx_pll_and_datapath_bit) <= "1111";
--                s_master_reset_async(c_gth_ch1_reset_bit downto c_gbt_ch0_reset_bit) <= "1111";
            when 11 =>
                -- gbtx register readback: read the whole gbtx register map back
                -- over i2c into blk_mem_gbtx_regs_readback (independent of the
                -- write-side blk_mem_gbtx_regs), now that boot-up is essentially
                -- complete (gbtx_rxready confirmed at state 4, adc config done at
                -- state 8). mirrors the write trigger/wait pattern at states 1/2,
                -- but folded into one state (via v_gbtx_read_triggered) since all
                -- 15 state slots are otherwise already in use.
                v_counter:=0;
                if v_gbtx_read_triggered = '0' then
                    s_gbtx_control.gbtx_i2c_read_write_operation <= '1';
                    s_gbtx_control.gbtx_trigger_i2c_operation <= '1';
                    v_gbtx_read_triggered := '1';
                else
                    s_gbtx_control.gbtx_trigger_i2c_operation <= '0';
                    if (s_gbtx_interface.busy = '0') or (s_skip_main_sm = '1') then
                        s_gbtx_control.gbtx_i2c_read_write_operation <= '0';
                        v_gbtx_read_triggered := '0';
                        s_counter <=s_counter+1;
                        s_boot_gbtx_read_done <= '1'; -- first full register readback completed
                    end if;
                end if;
            when 12 =>
                s_clkin_async.qpllclksel <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.cpllclksel  <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.gth_wordclk_sel <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(3);
                v_counter:=0;            
                s_counter <=s_counter+1;
            when 13 =>
                v_counter:=0;
                s_counter <=s_counter+1;
            when 14 =>
                v_counter :=0;
                s_master_reset_async<=x"00000000";
                if s_clknet.bcr.bcr_locked = '1' or (s_skip_main_sm = '1') then
                    s_counter <=s_counter+1;
                end if;
                if p_gbtx_rxready_in = "0" and (s_skip_main_sm = '0')then
                    s_counter <=1;
                end if;
--            when 15 =>

            when others =>
                
                s_clkin_async.qpllclksel <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.cpllclksel  <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
                s_clkin_async.gth_wordclk_sel <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(3);
                s_master_reset_async<=x"00000000";
                --p_leds_out <= s_leds(to_integer(unsigned(s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0))));
--                if s_cfgbus_interface.db_reg_rx(cfb_strobe_reg)(c_dbmaster_reset_bit) = '1' then --s_clknet.bcr.bcr_locked = '0' then  --s_clknet.gbtx_rxready(0) = '0' then
--                    s_counter<= 0;
--                end if;
            
        end case;

    end if;

end process;

-- latches "at least one sfp+ a2h ddm snapshot completed" per side, sticky until
-- master reset; same osc_clk40 domain as s_sfp_interface.ddm_read_done's source
-- (db6_sfp_i2c_interface's p_clk_in) and as vio_clknet_status's clk, so no CDC needed
proc_boot_sfp_read_done : process(s_clknet.osc_clk40)
begin
    if rising_edge(s_clknet.osc_clk40) then
        if s_cfgbus_interface.db_reg_rx(cfb_strobe_reg)(c_dbmaster_reset_bit) = '1' then
            s_boot_sfp_read_done <= (others => '0');
        else
            s_boot_sfp_read_done <= s_boot_sfp_read_done or s_sfp_interface.ddm_read_done;
        end if;
    end if;
end process;

proc_sync_master_reset: process(s_clknet.cfgbus_clk40, s_master_reset_async)
begin
    if s_master_reset_async(c_dbmaster_reset_bit) = '1' then
        s_master_reset<=x"FFFFFFFF";
    elsif rising_edge(s_clknet.cfgbus_clk40) then
        -- clock selection signals, state machines and mux
        -- https://www.xilinx.com/support/documentation/user_guides/ug576-ultrascale-gth-transceivers. (table 2-8)
        --s_master_reset(c_dbmaster_reset_bit) <= '0';
        s_master_reset <= s_master_reset_async;
        s_clkin.qpllclksel<=s_clkin_async.qpllclksel;
        s_clkin.cpllclksel<=s_clkin_async.cpllclksel;
        s_clkin.gth_wordclk_sel<=s_clkin_async.gth_wordclk_sel;
        
        s_clkin.txsysclksel <= "11"; -- 00 = CPLL, 10 = QPLL0, 11 = QPLL1
        s_clkin.rxsysclksel <= "11"; -- 00 = CPLL, 10 = QPLL0, 11 = QPLL1
        
        s_clkin.txoutclksel <= "101"; -- 3'b000: Static 1, 3'b001: TXOUTCLKPCS path, 3'b010: TXOUTCLKPMA path, 3'b011: TXPLLREFCLK_DIV1 path, 3'b100: TXPLLREFCLK_DIV2 path, 3'b101: TXPROGDIVCLK
        s_clkin.rxoutclksel <= "101"; -- 3'b000: Static 1, 3'b001: TXOUTCLKPCS path, 3'b010: TXOUTCLKPMA path, 3'b011: TXPLLREFCLK_DIV1 path, 3'b100: TXPLLREFCLK_DIV2 path, 3'b101: TXPROGDIVCLK
         
        s_clkin.txpllclksel <="10"; -- 00 = CPLL, 10 = QPLL1, 11 = QPLL0
        s_clkin.rxpllclksel <="10"; -- 00 = CPLL, 10 = QPLL1, 11 = QPLL0
        
        s_clkin.clksel<= '0'; 
        --s_clkin.cpllclksel <= "111"; --"111"; --"010"; -- 000: Reserved, 001: GTREFCLK0 selected, 010: GTREFCLK1 selected, 011: GTNORTHREFCLK0 selected, 100: GTNORTHREFCLK1 selected, 101: GTSOUTHREFCLK0 selected, 110: GTSOUTHREFCLK1 selected, 111: GTGREFCLK selected
        --s_clkin.qpllclksel <= "111"; --"111"; --"010"; -- 000: Reserved, 001: GTREFCLK0 selected, 010: GTREFCLK1 selected, 011: GTNORTHREFCLK0 selected, 100: GTNORTHREFCLK1 selected, 101: GTSOUTHREFCLK0 selected, 110: GTSOUTHREFCLK1 selected, 111: GTGREFCLK selected
--        s_clkin.qpllclksel <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
--        s_clkin.cpllclksel  <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
        
    end if;
end process;


s_leds(leds_user)<= s_cfgbus_interface.db_reg_rx(cfb_db_debug)(7 downto 4);

s_leds(leds_main_sm)(0) <= s_clknet.clk_1hz;
s_leds(leds_main_sm)(1) <= s_clknet.bcr.bcr_locked;
s_leds(leds_main_sm)(2) <= s_sfp_ku_mgt.qpll1lock_out(0);
s_leds(leds_main_sm)(3) <= s_clknet.mmcm_gbt40_mb_q0.locked_out or s_clknet.mmcm_gbt40_mb_q1.locked_out;

p_adc_channel_pedestal_test_overflow_mux : process(s_clknet.adc_readout_threshold_select_channel)
begin
--    case s_clknet.adc_readout_threshold_select_channel is
--        when x"000" =>
            p_adc_channel_pedestal_test_overflow_out<=s_mb_interface.adc_readout.channel_pedestal_test_overflow(to_integer(unsigned(s_clknet.adc_readout_threshold_select_channel)));
            p_adc_channel_pedestal_test_underflow_out<=s_mb_interface.adc_readout.channel_pedestal_test_underflow(to_integer(unsigned(s_clknet.adc_readout_threshold_select_channel)));
--        when x"001" =>
--        when x"010" =>
--        when x"011" =>
--        when x"100" =>
--        when x"101" =>
--        when others =>
        
--    end case;
end process;


-- 2026-09-13: debug capture buffer for the adc readout data path -- see that entity's
-- header for the trigger/bcr-match/readback-mux behaviour. g_data_readout_debug => 0
-- disables it (status held at default) without touching any of the wiring below.
i_db6_data_readout_debug : entity tilecal.db6_data_readout_debug
    generic map(
        g_data_readout_debug => g_data_readout_debug
    )
    port map(
        p_master_reset_in               => s_master_reset(c_adc_config_reset_bit),
        p_clknet_in                     => s_clknet,
        p_adc_readout_in                => s_mb_interface.adc_readout,
        p_data_readout_debug_control_in => s_clknet_debug_control.data_readout,
        p_data_readout_debug_status_out => s_data_readout_debug_status
    );

-- 2026-09-14: pulse-injection debug module -- see that entity's header. Only feeds
-- the gbt encoder chain (via s_mb_interface_gbt_tx below); the readout capture debug
-- above and every other s_mb_interface consumer still see raw adc data.
i_db6_data_readout_inject_debug : entity tilecal.db6_data_readout_inject_debug
    generic map(
        g_data_readout_inject_debug => g_data_readout_inject_debug
    )
    port map(
        p_master_reset_in                => s_master_reset(c_adc_config_reset_bit),
        p_clknet_in                      => s_clknet,
        p_db_reg_rx_in                   => s_cfgbus_interface.db_reg_rx,
        p_data_readout_inject_control_in => s_clknet_debug_control.data_readout_inject,
        p_adc_readout_in                 => s_mb_interface.adc_readout,
        p_hg_data_out                    => s_adc_hg_injected,
        p_lg_data_out                    => s_adc_lg_injected,
        p_data_readout_inject_status_out => s_data_readout_inject_status
    );

-- splice the (possibly injected) hg_data/lg_data and inject status into a private
-- copy of s_mb_interface that only feeds the gbt encoder data path -- see the signal
-- declaration comment above for why this can't just be done as field-by-field
-- concurrent assignments onto s_mb_interface itself (would be a second driver).
proc_mb_interface_gbt_tx_mux : process(s_mb_interface, s_adc_hg_injected, s_adc_lg_injected, s_data_readout_inject_status)
begin
    s_mb_interface_gbt_tx <= s_mb_interface;
    s_mb_interface_gbt_tx.adc_readout.hg_data                     <= s_adc_hg_injected;
    s_mb_interface_gbt_tx.adc_readout.lg_data                     <= s_adc_lg_injected;
    s_mb_interface_gbt_tx.adc_readout.data_readout_inject_active    <= s_data_readout_inject_status.active;
    s_mb_interface_gbt_tx.adc_readout.data_readout_inject_ram_rdata <= s_data_readout_inject_status.ram_rdata;
end process;

-- vio_clknet_status moved here from inside db6_clock_interface (probe_in/out widths are
-- fixed by the IP -- all 64 original probe_in bits are already spoken for, so mb jtag
-- id/done ride on the new probe_in64-66 added when the IP was regenerated). Combinational
-- operators are not allowed in the port map (unnamed nets, meaningless ltx labels) --
-- AND/OR/concat operands are split onto separate probes, reusing probe_in12 (dead
-- BUFG_GT_SYNC CE/CLR) and the previously tied-off probe_in17/19.
i_vio_db_debug : vio_db_debug
  PORT MAP (
    clk => s_clknet.osc_clk40,
    probe_in0  => s_vio_dbg_adc_channel_locked,
    probe_in1  => s_vio_dbg_adc_channel_missed_locked,
    probe_in2  => s_vio_dbg_adc_channel_clk280_locked,
    probe_in3  => s_vio_dbg_adc_channel_missed_bit_count,
    probe_in4  => s_vio_dbg_adc_pedestal_overflow,
    probe_in5  => s_vio_dbg_adc_pedestal_underflow,
    probe_in6  => s_vio_dbg_adc_config_done,
    probe_in7  => s_vio_dbg_adc_readout_initialized,
    -- split per-channel (item 1 rewiring) so each channel keeps its own ltx name
    -- instead of one opaque 54-bit blob (fc/lg/hg share the same tap -- see
    -- db6_adc_interface_decoder_iddr_bitclk280.vhd)
    probe_in8(8 downto 0)   => s_mb_interface.adc_readout.fc_idelay_count(0),
    probe_in8(17 downto 9)  => s_mb_interface.adc_readout.fc_idelay_count(1),
    probe_in8(26 downto 18) => s_mb_interface.adc_readout.fc_idelay_count(2),
    probe_in8(35 downto 27) => s_mb_interface.adc_readout.fc_idelay_count(3),
    probe_in8(44 downto 36) => s_mb_interface.adc_readout.fc_idelay_count(4),
    probe_in8(53 downto 45) => s_mb_interface.adc_readout.fc_idelay_count(5),
    probe_in9  => s_vio_dbg_adc_idelay_calibration_done,
    probe_in10 => s_vio_dbg_adc_idelay_calibration_failed,
    probe_in11 => s_vio_dbg_bcr_locked,
    probe_in12 => s_vio_dbg_locked_db,
    probe_in13 => s_vio_dbg_link.qpllclksel,
    probe_in14(0) => s_clkin.bcr.bcr_tmr_error,
    probe_in14(1) => s_clkin.bcr.bcr_locked_tmr_error,
    probe_in14(2) => s_clkin.bcr.count_tmr_error,
    probe_in15 => s_vio_dbg_link.txsysclksel,
    probe_in16 => s_vio_dbg_link.rxsysclksel,
    probe_in17 => s_vio_dbg_link.rxoutclksel,
    probe_in18 => s_vio_dbg_link.txoutclksel,
    probe_in19 => s_vio_dbg_mmcm_gbt40_db6_locked,
    probe_in20 => s_vio_dbg_clk_1hz,
    probe_in21 => s_vio_dbg_gbt_cdc_phase_override_rb,
    probe_in22(3) => s_db6_gbt_bank.tx_phcomputed_o(0),
    probe_in22(2) => s_db6_gbt_bank.tx_phcomputed_o(1),
    probe_in22(1) => s_db6_gbt_bank.tx_phaligned_o(0),
    probe_in22(0) => s_db6_gbt_bank.tx_phaligned_o(1),
    probe_in23 => s_vio_dbg_mb_fpga_reset_low_q0,
    probe_in24 => s_vio_dbg_gbtx_rxready,
    probe_in25 => s_vio_dbg_locked_tp_q0,
    probe_in26 => s_vio_dbg_mb_fpga_reset_low_q1,
    probe_in27(0) => s_vio_dbg_link.qpll1lock,
    probe_in28(0)  => s_sfp_ku_mgt.qpll1refclklost_out(0),
    probe_in28(1)  => s_sfp_ku_mgt.gtwiz_reset_tx_done_out(0),
    probe_in28(2)  => s_sfp_ku_mgt.qpll1fbclklost_out(0),
    probe_in28(3)  => s_sfp_ku_mgt.qpll1refclklost_out(0),
    probe_in28(4)  => s_sfp_ku_mgt.gtwiz_buffbypass_tx_done_out(0),
    probe_in28(5)  => s_sfp_ku_mgt.gtwiz_buffbypass_tx_error_out(0),
    probe_in28(6)  => s_sfp_ku_mgt.qpll1lock_out(0),
    probe_in28(7)  => s_sfp_ku_mgt.qpll1fbclklost_out(0),
    probe_in28(8)  => s_sfp_ku_mgt.gtwiz_buffbypass_tx_start_user_in(0),
    probe_in28(9)  => s_sfp_ku_mgt.gtwiz_reset_tx_done_out(0),
    probe_in28(10) => s_sfp_ku_mgt.gtwiz_reset_rx_cdr_stable_out(0),
    probe_in29(5 downto 4) => s_sfp_interface.mod_abs,
    probe_in29(3 downto 2) => s_sfp_interface.mod_los,
    probe_in29(1 downto 0) => s_sfp_interface.tx_fault,
    probe_in30 => s_vio_dbg_db_leds,
    probe_in31 => s_vio_dbg_db_side,
    probe_in32(45 downto 38) => s_gbtx_interface.blk_mem_gbtx_regs.dina,
    probe_in32(37 downto 29) => s_gbtx_interface.blk_mem_gbtx_regs.addra,
    probe_in32(28)           => s_gbtx_interface.busy,
    probe_in32(27 downto 19) => s_gbtx_interface.gbtx_control.gbtx_reg_address(8 downto 0),
    probe_in32(18)           => s_gbtx_interface.gbtx_control.gbtx_trigger_i2c_operation,
    probe_in32(17 downto 10) => s_gbtx_interface.gbtx_control.gbtx_reg_value,
    probe_in32(9)            => s_gbtx_interface.gbtx_control.gbtx_i2c_read_write_operation,
    probe_in32(8 downto 1)   => s_gbtx_interface.blk_mem_gbtx_regs.douta,
    probe_in32(0)            => s_gbtx_interface.gbtx_control.gbtx_default_config,
    probe_in33 => s_vio_dbg_running_time,
    probe_in34 => s_vio_dbg_md_number,
    probe_in35 => s_vio_cfgbus_loopback_reg,
    probe_in36 => c_global_date,
    probe_in37 => c_global_time,
    probe_in38 => s_vio_dbg_dna,
    probe_in39 => s_vio_dbg_dna_done,
    probe_in40 => s_vio_dbg_link.wordclk_locked,
    probe_in41 => s_vio_dbg_link.cdc_reset_array,
    probe_in42 => s_vio_dbg_mb_jtag_id_q0,
    probe_in43 => s_vio_dbg_mb_jtag_id_q1,
    probe_in44 => s_vio_dbg_mb_jtag_done,
    probe_in45 => s_vio_dbg_sfp_addr_echo0,
    probe_in46 => s_vio_dbg_sfp_addr_echo1,
    probe_in47 => s_vio_dbg_gbtx_config_readback,
    probe_in48 => s_vio_dbg_hss_rst_seq_done,
    probe_in49 => s_vio_dbg_hss_fifo_data_valid,
    probe_in50 => s_vio_dbg_boot_done_mb_bs_q0,
    probe_in51 => s_vio_dbg_boot_done_mb_bs_q1,
    probe_in52 => s_vio_dbg_boot_done_gbtx_write,
    probe_in53 => s_vio_dbg_boot_done_gbtx_read,
    probe_in54 => s_vio_dbg_boot_done_sfp_q0,
    probe_in55 => s_vio_dbg_boot_done_sfp_q1,
    probe_in56 => s_vio_dbg_flash_status,
    probe_in57 => s_vio_dbg_flash_rdata,
    probe_in58 => s_vio_dbg_ddm_temp_q0,
    probe_in59 => s_vio_dbg_ddm_temp_q1,
    probe_in60 => s_vio_dbg_ddm_vcc_q0,
    probe_in61 => s_vio_dbg_ddm_vcc_q1,
    probe_in62 => s_vio_dbg_ddm_txbias_q0,
    probe_in63 => s_vio_dbg_ddm_txbias_q1,
    probe_in64 => s_vio_dbg_ddm_txpower_q0,
    probe_in65 => s_vio_dbg_ddm_txpower_q1,
    probe_in66 => s_vio_dbg_ddm_rxpower_q0,
    probe_in67 => s_vio_dbg_ddm_rxpower_q1,
    probe_in68 => s_vio_dbg_ddm_lasertemp_q0,
    probe_in69 => s_vio_dbg_ddm_lasertemp_q1,
    probe_in70 => s_vio_dbg_ddm_teccurrent_q0,
    probe_in71 => s_vio_dbg_ddm_teccurrent_q1,
    probe_in72 => s_vio_dbg_sfp_shadow_q0,
    probe_in73 => s_vio_dbg_sfp_shadow_q1,
    probe_in74(0) => s_data_readout_debug_status.captured,
    probe_in75    => s_data_readout_debug_status.hg_data,
    probe_in76    => s_data_readout_debug_status.lg_data,
    probe_in77    => s_data_readout_debug_status.fc_data,
    probe_in78 => s_mb_interface.adc_config_driver_debug.state,
    probe_in79 => s_mb_interface.adc_config_driver_debug.registers_buffer(0),
    probe_in80 => s_mb_interface.adc_config_driver_debug.registers_buffer(1),
    probe_in81 => s_mb_interface.adc_config_driver_debug.registers_buffer(2),
    probe_in82 => s_mb_interface.adc_config_driver_debug.registers_buffer(3),
    probe_in83 => s_mb_interface.adc_config_driver_debug.registers_buffer(4),
    probe_in84 => s_mb_interface.adc_config_driver_debug.leds,
    probe_in85(0) => s_mb_interface.adc_config_driver_debug.trigger_internal,
    probe_in86 => s_mb_interface.adc_config_driver_debug.mb_config_done,
    probe_in87(0) => s_gbt_encoder_interface.dual_link_sync_mismatch_sticky,
    probe_in88 => s_gbt_encoder_interface.dual_link_sync_mismatch_count,
    probe_in89(14)          => s_data_readout_inject_status.active,
    probe_in89(13 downto 0) => s_data_readout_inject_status.ram_rdata,

    probe_out0 => s_vio_dbg_adc_high_thresh,
    probe_out1 => s_vio_dbg_adc_low_thresh,
    probe_out2 => s_vio_dbg_adc_thresh_sel_ch,
    probe_out3(0) => s_mb_interface_in.mb_reset.q0,
    probe_out3(1) => s_mb_interface_in.mb_reset.q1,
    probe_out3(2) => s_dna_reset,
    probe_out3(3) => s_clknet_debug_control.clknet.reset_clknet,
    probe_out3(4) => s_clknet_debug_control.clknet.skip_main_sm,
    probe_out3(5) => s_clknet_debug_control.clknet.clear_dual_link_mismatch,
    probe_out4(0) => s_clknet_debug_control.clknet.force_gtx_i2c_config,
    probe_out5(25)          => s_clknet_debug_control.cis.enable,
    probe_out5(24)          => s_clknet_debug_control.cis.gain,
    probe_out5(23 downto 12) => s_clknet_debug_control.cis.bcid_charge,
    probe_out5(11 downto 0)  => s_clknet_debug_control.cis.bcid_discharge,
    probe_out6(0) => s_mb_fpga_reset_low.q0,
    probe_out6(1) => s_mb_fpga_reset_low.q1,
    probe_out7 => s_vio_dbg_sfp_addr_out_q0,
    probe_out8 => s_vio_dbg_sfp_addr_out_q1,
    probe_out9(96 downto 65) => s_clknet_debug_control.flash.manual_address,
    probe_out9(64 downto 33) => s_clknet_debug_control.flash.manual_command,
    probe_out9(32)           => s_clknet_debug_control.flash.manual_write_floor_enable,
    probe_out9(31 downto 0)  => s_clknet_debug_control.flash.manual_write_floor,
    probe_out10(0)          => s_clknet_debug_control.adc_config.mode,
    probe_out10(1)          => s_clknet_debug_control.adc_config.trigger_mb_adc_config,
    probe_out10(4 downto 2) => s_clknet_debug_control.adc_config.mb_fpga_select,
    probe_out10(6 downto 5) => s_clknet_debug_control.adc_config.mb_pmt_select,
    probe_out10(7)          => s_clknet_debug_control.adc_config.force_recalibrate,
    probe_out10(8)          => s_clknet_debug_control.adc_config.force_adc_readout_reset,
    probe_out11 => s_clknet_debug_control.adc_config.adc_register_0,
    probe_out12 => s_clknet_debug_control.adc_config.adc_register_1,
    probe_out13 => s_clknet_debug_control.adc_config.adc_register_2,
    probe_out14 => s_clknet_debug_control.adc_config.adc_register_3_raw,
    probe_out15 => s_clknet_debug_control.adc_config.adc_register_4_raw,
    probe_out16(0)           => s_clknet_debug_control.adc_config.test_pattern_enable,
    probe_out16(14 downto 1) => s_clknet_debug_control.adc_config.test_pattern_value,
    probe_out17(0)           => s_clknet_debug_control.data_readout.trigger,
    probe_out17(4 downto 1)  => s_clknet_debug_control.data_readout.sample_index,
    probe_out17(7 downto 5)  => s_clknet_debug_control.data_readout.channel_select,
    probe_out18              => s_clknet_debug_control.data_readout.bcr_number,
    probe_out19(40)           => s_clknet_debug_control.data_readout_inject.enable,
    probe_out19(39)           => s_clknet_debug_control.data_readout_inject.ram_we,
    probe_out19(38 downto 26) => s_clknet_debug_control.data_readout_inject.pedestal,
    probe_out19(25 downto 14) => s_clknet_debug_control.data_readout_inject.ram_addr,
    probe_out19(13 downto 0)  => s_clknet_debug_control.data_readout_inject.ram_wdata
  );

-- mb boundary-scan/gbtx reg readback vio address overrides retired (see the
-- s_mb_boundary_scan_reg_address_vio/s_gbtx_reg_readback_address_vio declaration
-- comment above) -- tied off since their probe_out driver is gone.
s_mb_boundary_scan_reg_address_vio <= (others => (others => '0'));
s_gbtx_reg_readback_address_vio    <= (others => '0');


--i_vio_leds_debug : vio_leds_debug
--  PORT MAP (
--    clk => s_clknet.clk40,
--    probe_in0 => s_leds(leds_main_sm),
--    probe_in1 => s_leds(leds_clk_interface),
--    probe_in2 => s_leds(leds_cfgbus_interface),
--    probe_in3 => s_leds(leds_gbtx_i2c),
--    probe_in4 => s_leds(leds_mb0_mmcm),
--    probe_in5 => s_leds(leds_mb1_mmcm),
--    probe_in6 => s_leds(leds_serial_id),
--    probe_in7 => s_leds(leds_system),
--    probe_in8 => s_leds(leds_commbus),
--    probe_in9 => s_leds(leds_gbtx_reg_config),
--    probe_in10 => s_leds(leds_system_management),
--    probe_in11 => s_leds(leds_mb_interface),
--    probe_in12 => s_leds(leds_sfp_interface),
--    probe_in13 => s_leds(13),
--    probe_in14 => s_leds(14),
--    probe_in15 => s_leds(leds_user)
--  );



end rtl;
    

