----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Eduardo Valdes Santurio
-- 
-- Create Date: 04/23/2020 04:15:18 PM
-- Design Name: 
-- Module Name: db6_mainboard_interface - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_mainboard_interface is
  generic (
            g_vio_adc_readout : natural :=0;
            g_clocking_mode : natural :=0; -- 0/1/2 -> iddr, 3 -> selectio wizard (hss_adc)
            g_bitclk        : integer := 280
            );
  Port ( 
        p_master_reset_in : in std_logic_vector(31 downto 0);
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in : in t_db_reg_rx;
        
        --adc readout (plain logic; IO primitives in db6_adc_interface_io_iddr_bitclk280/240.vhd, instantiated from db7_io_box)
        p_adc_bitclk_in : in std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_in : in std_logic_vector(5 downto 0);
        p_frame_missalignment_in : in std_logic_vector(5 downto 0); -- iddr only
        p_adc_frameclk_in : in t_bitslice_sr; -- iddr only
        p_adc_lg_data_in : in t_bitslice_sr;  -- iddr only
        p_adc_hg_data_in : in t_bitslice_sr;  -- iddr only

        -- adc readout, iserdese only (see db6_adc_interface.vhd / db7_io_box.vhd for why
        -- these are separate, wider ports rather than reusing the iddr ones above)
        p_adc_frameclk_iserdese_in   : in  t_byteslice_sr;
        p_adc_lg_data_iserdese_in    : in  t_byteslice_sr;
        p_adc_hg_data_iserdese_in    : in  t_byteslice_sr;
        p_adc_pll0_locked_in         : in  std_logic_vector(5 downto 0) := (others => '0'); -- iserdese/hss only
        p_adc_frame_missalignment_out : out std_logic_vector(5 downto 0);
        p_adc_ctrl_reset_from_sm_in   : in  std_logic_vector(5 downto 0);

        --mb_driver (plain logic; IO primitives live in db6_mainboard_driver_io.vhd, instantiated from db7_io_box)
        p_ssel_out         : out t_mb_std_logic;
        p_sclk_out         : out t_mb_std_logic;
        p_sdata_out     : out t_mb_std_logic;
        p_sdata_in    : in  t_mb_std_logic;

        --cis interface (plain logic; hss_cis IP in db6_cis_interface_hss_io.vhd, instantiated from db7_io_box)
        p_tph_out               : out t_mb_std_logic;
        p_tpl_out               : out t_mb_std_logic;

        --mainboard jtag chain (db6_jtag_readers_controller drives these directly, no pad primitives needed)
        p_mb_jtag_tck_out : out t_mb_std_logic;
        p_mb_jtag_tms_out : out t_mb_std_logic;
        p_mb_jtag_tdi_out : out t_mb_std_logic;
        p_mb_jtag_tdo_in  : in  t_mb_std_logic;

        -- boundary-scan reg block ram port b address, direct from a vio debug
        -- probe_out (ORed with cfb_mb_boundary_scan_reg_address below -- don't
        -- drive both non-zero at once)
        p_mb_boundary_scan_reg_address_vio_in : in t_sfp_reg_addr_array;

        -- one-shot boundary-scan trigger, fired ~1s after p_mb_fpga_reset_low
        -- releases (see proc_mb_boundary_scan_timed_trigger in db6v5_top.vhd)
        p_boundary_scan_timed_trigger_in : in t_mb_std_logic;

        p_mb_interface_out          : out t_mb_interface;
        
        --integrator
        -- IOBUF moved to db7_io_box; split O/I/T instead of inout.
        p_integrator_sda_drive_out : out t_mb_std_logic;
        p_integrator_sda_tri_out   : out t_mb_std_logic;
        p_integrator_sda_read_in   : in  t_mb_std_logic;
        p_integrator_scl_drive_out : out t_mb_std_logic;
        p_integrator_scl_tri_out   : out t_mb_std_logic;
        p_integrator_scl_read_in   : in  t_mb_std_logic;
        
        p_leds_out : out std_logic_vector(3 downto 0)
  );
end db6_mainboard_interface;

architecture Behavioral of db6_mainboard_interface is
attribute IOB: string;
attribute keep: string;
attribute dont_touch: string;


--adc readout
signal s_adc_readout_control, s_adc_readout_control_out : t_adc_readout_control:=
(
--        adc_mode	: std_logic;
        db_side              => "1",
        channel_reset       => (others => '0'),
		fc_idelay_ctrl_reset => (others => '0'),
        fc_idelay_load  => (others => '0'),
        fc_idelay_en_vtc => (others => '1'),
        fc_idelay_count => (others =>(others => '0')),

        lg_idelay_ctrl_reset => (others => '0'),
        lg_idelay_load => (others => '0'),
        lg_idelay_en_vtc => (others => '0'),
        lg_idelay_count => (others =>(others => '0')),
        lg_bitslip => (others =>(others => '0')),
        
        hg_idelay_ctrl_reset => (others => '0'),
        hg_idelay_load => (others => '0'),
        hg_idelay_en_vtc => (others => '0'),
        hg_bitslip => (others =>(others => '0')),
        hg_idelay_count => (others =>(others => '0')),
        
        channel_enable_test_pattern => (others=>'0'),
        channel_reset_test_pattern => (others=>'0'),
        channel_lg_data_test_pattern => (others => (others=> '0')),
        channel_hg_data_test_pattern => (others => (others=> '0')),

        channel_lg_pedestal_test_lower => (others => (others=> '0')),
        channel_lg_pedestal_test_higher => (others => (others=> '0')),
        channel_hg_pedestal_test_lower => (others => (others=> '0')),
        channel_hg_pedestal_test_higher => (others => (others=> '0')),
        
        
        adc_config_done => '0'

);
signal s_adc_readout : t_adc_readout;
signal s_cis_interface : t_cis_interface;
--attribute keep of s_adc_readout_control, s_adc_readout : signal is "TRUE";
--attribute dont_touch of s_adc_readout_control, s_adc_readout : signal is "TRUE";


--mb driver

signal s_mb_driver : t_mb_driver;
signal s_mb_txword_in      :  std_logic_vector (31 downto 0);
signal s_mb_config_trigger_out : std_logic;
--signal s_mb_rxword_out       : t_mb_rxword;
--signal s_mb_done_out       : t_mb_std_logic;
--attribute keep of s_mb_txword_in, s_mb_driver : signal is "TRUE";
--attribute dont_touch of s_mb_txword_in, s_mb_driver : signal is "TRUE";

--adc_config
signal s_adc_register_config_from_configbus, s_adc_register_config_from_readout : t_adc_register_config := c_adc_register_init_config_14_bit;

--attribute keep of s_adc_register_config_from_configbus, s_adc_register_config_from_readout : signal is "TRUE";

-- integrator
signal s_mb_integrator : t_mb_integrator;
--attribute keep of s_mb_integrator : signal is "TRUE";

-- mainboard jtag id reader
signal s_mb_jtag_enable : t_mb_std_logic;
signal s_mb_jtag_id     : t_mb_std_logic_vector_32;
signal s_mb_jtag_done   : t_mb_std_logic;

-- auto-read: one full jtag id readout per side, fired on the falling edge (release) of
-- that side's p_master_reset_in bit. s_mbX_reset_sync_ff1/2 is a 2-ff synchronizer
-- bringing the bit into the jtag controller's osc_clk200 domain (p_master_reset_in is
-- registered on cfgbus_clk40 at db6v5_top); ff3 is ff2 delayed one more cycle so the
-- edge compare (ff3='1' and ff2='0') is done entirely on settled, synchronized values.
signal s_mb0_reset_sync_ff1, s_mb0_reset_sync_ff2, s_mb0_reset_sync_ff3 : std_logic := '1';
signal s_mb1_reset_sync_ff1, s_mb1_reset_sync_ff2, s_mb1_reset_sync_ff3 : std_logic := '1';
-- auto-read: one idcode scan then one boundary scan per side, fired on the falling
-- edge (release) of that side's p_master_reset_in bit -- see proc_mb_jtag_auto_read.
type t_mb_jtag_auto_read_sm is (st_idle, st_read_id, st_gap, st_read_boundary);
signal s_mb_jtag_auto_read_sm_q0, s_mb_jtag_auto_read_sm_q1 : t_mb_jtag_auto_read_sm := st_idle;
signal s_mb_jtag_auto_trigger : t_mb_std_logic := (q0 => '0', q1 => '0');
signal s_mb_boundary_scan_auto_trigger : t_mb_std_logic := (q0 => '0', q1 => '0');
-- db6_altera_jtag_driver only re-checks its st_done exit condition (both start
-- inputs low) once per jtag tick pair, i.e. every 2*g_clk_div = 100 osc_clk200
-- cycles (see i_db6_jtag_readers_controller g_clk_div=>50 below); a single-cycle
-- low pulse on both start signals -- as st_gap used to produce -- is essentially
-- always missed by that ~100-cycle sampling and, since it never recurs, leaves the
-- driver deadlocked in st_done forever (boundary scan then never starts, even
-- though the chained idcode read that preceded it completes fine). st_gap now
-- holds for c_jtag_gap_cycles instead of one cycle, comfortably covering at least
-- one full sampling window.
constant c_jtag_gap_cycles : integer := 256;
signal s_mb_jtag_gap_cnt_q0, s_mb_jtag_gap_cnt_q1 : integer range 0 to c_jtag_gap_cycles-1 := 0;

-- mainboard boundary-scan (sample) reader -- see db6_altera_jtag_driver.vhd /
-- db6_jtag_readers_controller.vhd
signal s_mb_boundary_scan_enable : t_mb_std_logic;
signal s_mb_boundary_scan        : t_mb_boundary_scan_array;
signal s_mb_boundary_scan_done   : t_mb_std_logic;
-- sticky "first boundary scan since this side's fpga reset completed" flag, latched
-- in proc_mb_jtag_auto_read below; cleared on that side's master reset assertion
signal s_boot_boundary_scan_done : t_mb_std_logic := (q0 => '0', q1 => '0');
signal s_mb_boundary_scan_rx_register : t_sfp_reg_addr_array;
-- readback byte is not re-exposed separately: it's already available at
-- t_mb_interface.mb_boundary_scan(N).mem.doutb below

-- 2-ff synchronizer bringing the clk_100hz-domain timed trigger pulse (see
-- proc_mb_boundary_scan_timed_trigger in db6v5_top.vhd) into osc_clk200, mirroring
-- the s_mb0/1_reset_sync_ff pattern above
signal s_boundary_scan_timed_trigger_sync_ff1, s_boundary_scan_timed_trigger_sync_ff2 : t_mb_std_logic := (q0 => '0', q1 => '0');

COMPONENT vio_adc_config_driver
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out2 : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_out3 : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_out4 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_out5 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_out6 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_out7 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_out8 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_out9 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out10 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out11 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;
signal s_adc_config_reset : std_logic;
signal s_adc_config_leds, s_db6_adc_interface_leds, a_db6_mainboard_driver_leds : std_logic_vector(3 downto 0);


COMPONENT vio_adc_readout
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in15 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in16 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in17 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in18 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in19 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in20 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in21 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in22 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in23 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in24 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in25 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in26 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in27 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in28 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in29 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in30 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in31 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in32 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in33 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in34 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in35 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in36 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in37 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in38 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in39 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in40 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in41 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in42 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in43 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);    
    probe_in44 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in45 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in46 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in47 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in48 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in49 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in50 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in51 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in52 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in53 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in54 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in55 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in56 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in57 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in58 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in59 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in60 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    
    
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;
signal s_reset_adc_interface, s_reset_adc_interface_from_vio : std_logic;

COMPONENT vio_adc_readout_pattern_test
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in15 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in16 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in17 : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_in18 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in19 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in20 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in21 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in22 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in23 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in24 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in25 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in26 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in27 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in28 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in29 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in30 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in31 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in32 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in33 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in34 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in35 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in36 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in37 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in38 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in39 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in40 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in41 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in42 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in43 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in44 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in45 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in46 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in47 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in48 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in49 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in50 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in51 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in52 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in53 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out2 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out3 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out4 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out5 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out6 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out7 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out8 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out9 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out10 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out11 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out12 : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
    probe_out13 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

signal s_enable_test_pattern, s_reset_test_pattern  : std_logic;

begin

p_mb_interface_out.adc_readout <= s_adc_readout;
p_mb_interface_out.adc_readout_control <= s_adc_readout_control;

p_mb_interface_out.mb_reset.q0 <= '1'; --p_clknet_in.mb_fpga_reset_low.q0;
p_mb_interface_out.mb_reset.q1 <= '1'; --p_clknet_in.mb_fpga_reset_low.q1;

s_reset_adc_interface <= p_master_reset_in(c_adc_readout_reset_bit) or s_reset_adc_interface_from_vio;

gen_db6_adc_interface_iddr : if g_clocking_mode /= 3 generate

    p_adc_frame_missalignment_out <= (others => '0');

    i_db6_adc_interface_iddr : entity tilecal.db6_adc_interface
      generic map(
        g_tmr_enabled      => '0',       -- 0 = no no_tmr, 1 = tmr
        g_bitclk           => g_bitclk,
        g_clocking_mode    => g_clocking_mode
        )
      Port map (
            p_master_reset_in => s_reset_adc_interface,
            p_clknet_in => p_clknet_in,
            p_db_reg_rx_in => p_db_reg_rx_in,
            p_adc_bitclk_in => p_adc_bitclk_in,
            p_adc_bitclkdiv_in => p_adc_bitclkdiv_in,
            p_frame_missalignment_in => p_frame_missalignment_in,
            p_adc_frameclk_in => p_adc_frameclk_in,
            p_adc_lg_data_in => p_adc_lg_data_in,
            p_adc_hg_data_in => p_adc_hg_data_in,
            p_adc_frameclk_iserdese_in => (others => (others => '0')),
            p_adc_lg_data_iserdese_in  => (others => (others => '0')),
            p_adc_hg_data_iserdese_in  => (others => (others => '0')),
            p_adc_pll0_locked_in       => (others => '0'),
            p_adc_frame_missalignment_out => open,
            p_adc_ctrl_reset_from_sm_in   => (others => '0'),
            p_adc_readout_control_in => s_adc_readout_control,
--            p_adc_gbtx_frameclk_in =>p_adc_gbtx_frameclk_in,
--            p_adc_readout_control_out => s_adc_readout_control_out,
            p_adc_readout_out => s_adc_readout,
            p_leds_out       => s_db6_adc_interface_leds
      );
end generate;

-- SelectIO Interface Wizard front end (hss_adc): registered on the divided clkdiv
-- instead of IDDRE1's raw undivided-bitclk output, which needed an SRL pipeline stage
-- tight enough to violate timing at 280 Mbps (see db6_adc_interface_io_hss.vhd /
-- db6_adc_interface.vhd).
gen_db6_adc_interface_iserdese : if g_clocking_mode = 3 generate

    i_db6_adc_interface_iserdese : entity tilecal.db6_adc_interface
      generic map(
        g_tmr_enabled      => '0',       -- 0 = no no_tmr, 1 = tmr
        g_bitclk           => g_bitclk,
        g_clocking_mode    => g_clocking_mode
        )
      Port map (
            p_master_reset_in => s_reset_adc_interface,
            p_clknet_in => p_clknet_in,
            p_db_reg_rx_in => p_db_reg_rx_in,
            p_adc_bitclk_in => p_adc_bitclk_in,
            p_adc_bitclkdiv_in => p_adc_bitclkdiv_in,
            p_frame_missalignment_in => (others => '0'),
            p_adc_frameclk_in => (others => (others => '0')),
            p_adc_lg_data_in  => (others => (others => '0')),
            p_adc_hg_data_in  => (others => (others => '0')),
            p_adc_frameclk_iserdese_in => p_adc_frameclk_iserdese_in,
            p_adc_lg_data_iserdese_in  => p_adc_lg_data_iserdese_in,
            p_adc_hg_data_iserdese_in  => p_adc_hg_data_iserdese_in,
            p_adc_pll0_locked_in       => p_adc_pll0_locked_in,
            p_adc_frame_missalignment_out => p_adc_frame_missalignment_out,
            p_adc_ctrl_reset_from_sm_in   => p_adc_ctrl_reset_from_sm_in,
            p_adc_readout_control_in => s_adc_readout_control,
            p_adc_readout_out => s_adc_readout,
            p_leds_out       => s_db6_adc_interface_leds
      );
end generate;

        s_adc_readout_control.db_side <= p_clknet_in.db_side;
        
--        s_adc_readout_control.fc_idelay_count <= (others => (others=> '0'));
--        s_adc_readout_control.fc_idelay_ctrl_reset <= ((others=> '0'));
--        s_adc_readout_control.fc_idelay_load<= ((others=> '0'));
--        s_adc_readout_control.fc_idelay_en_vtc<= ((others=> '0'));
      
--        s_adc_readout_control.lg_idelay_count(0)<= p_db_reg_rx_in(adc_readout_idelay3_lg_0)(8 downto 0);
--        s_adc_readout_control.hg_idelay_count(0)<= p_db_reg_rx_in(adc_readout_idelay3_hg_0)(8 downto 0);
--        s_adc_readout_control.fc_idelay_count(0)<= p_db_reg_rx_in(adc_readout_idelay3_fc_0)(8 downto 0);
--        s_adc_readout_control.lg_idelay_count(1)<= p_db_reg_rx_in(adc_readout_idelay3_lg_1)(8 downto 0);
--        s_adc_readout_control.hg_idelay_count(1)<= p_db_reg_rx_in(adc_readout_idelay3_hg_1)(8 downto 0);
--        s_adc_readout_control.fc_idelay_count(1)<= p_db_reg_rx_in(adc_readout_idelay3_fc_1)(8 downto 0);
--        s_adc_readout_control.lg_idelay_count(2)<= p_db_reg_rx_in(adc_readout_idelay3_lg_2)(8 downto 0);
--        s_adc_readout_control.hg_idelay_count(2)<= p_db_reg_rx_in(adc_readout_idelay3_hg_2)(8 downto 0);
--        s_adc_readout_control.fc_idelay_count(2)<= p_db_reg_rx_in(adc_readout_idelay3_fc_2)(8 downto 0);
--        s_adc_readout_control.lg_idelay_count(3)<= p_db_reg_rx_in(adc_readout_idelay3_lg_3)(8 downto 0);
--        s_adc_readout_control.hg_idelay_count(3)<= p_db_reg_rx_in(adc_readout_idelay3_hg_3)(8 downto 0);
--        s_adc_readout_control.fc_idelay_count(3)<= p_db_reg_rx_in(adc_readout_idelay3_fc_3)(8 downto 0);
--        s_adc_readout_control.lg_idelay_count(4)<= p_db_reg_rx_in(adc_readout_idelay3_lg_4)(8 downto 0);
--        s_adc_readout_control.hg_idelay_count(4)<= p_db_reg_rx_in(adc_readout_idelay3_hg_4)(8 downto 0);
--        s_adc_readout_control.fc_idelay_count(4)<= p_db_reg_rx_in(adc_readout_idelay3_fc_4)(8 downto 0);
--        s_adc_readout_control.lg_idelay_count(5)<= p_db_reg_rx_in(adc_readout_idelay3_lg_5)(8 downto 0);
--        s_adc_readout_control.hg_idelay_count(5)<= p_db_reg_rx_in(adc_readout_idelay3_hg_5)(8 downto 0);
--        s_adc_readout_control.fc_idelay_count(5)<= p_db_reg_rx_in(adc_readout_idelay3_fc_5)(8 downto 0);
        
--        s_adc_readout_control.lg_idelay_ctrl_reset(0)<= p_db_reg_rx_in(adc_readout_idelay3_lg_0)(15);
--        s_adc_readout_control.hg_idelay_ctrl_reset(0)<= p_db_reg_rx_in(adc_readout_idelay3_hg_0)(15);
--        s_adc_readout_control.fc_idelay_ctrl_reset(0)<= p_db_reg_rx_in(adc_readout_idelay3_fc_0)(15);
--        s_adc_readout_control.lg_idelay_ctrl_reset(1)<= p_db_reg_rx_in(adc_readout_idelay3_lg_1)(15);
--        s_adc_readout_control.hg_idelay_ctrl_reset(1)<= p_db_reg_rx_in(adc_readout_idelay3_hg_1)(15);
--        s_adc_readout_control.fc_idelay_ctrl_reset(1)<= p_db_reg_rx_in(adc_readout_idelay3_fc_1)(15);
--        s_adc_readout_control.lg_idelay_ctrl_reset(2)<= p_db_reg_rx_in(adc_readout_idelay3_lg_2)(15);
--        s_adc_readout_control.hg_idelay_ctrl_reset(2)<= p_db_reg_rx_in(adc_readout_idelay3_hg_2)(15);
--        s_adc_readout_control.fc_idelay_ctrl_reset(2)<= p_db_reg_rx_in(adc_readout_idelay3_fc_2)(15);
--        s_adc_readout_control.lg_idelay_ctrl_reset(3)<= p_db_reg_rx_in(adc_readout_idelay3_lg_3)(15);
--        s_adc_readout_control.hg_idelay_ctrl_reset(3)<= p_db_reg_rx_in(adc_readout_idelay3_hg_3)(15);
--        s_adc_readout_control.fc_idelay_ctrl_reset(3)<= p_db_reg_rx_in(adc_readout_idelay3_fc_3)(15);
--        s_adc_readout_control.lg_idelay_ctrl_reset(4)<= p_db_reg_rx_in(adc_readout_idelay3_lg_4)(15);
--        s_adc_readout_control.hg_idelay_ctrl_reset(4)<= p_db_reg_rx_in(adc_readout_idelay3_hg_4)(15);
--        s_adc_readout_control.fc_idelay_ctrl_reset(4)<= p_db_reg_rx_in(adc_readout_idelay3_fc_4)(15);
--        s_adc_readout_control.lg_idelay_ctrl_reset(5)<= p_db_reg_rx_in(adc_readout_idelay3_lg_5)(15);
--        s_adc_readout_control.hg_idelay_ctrl_reset(5)<= p_db_reg_rx_in(adc_readout_idelay3_hg_5)(15);
--        s_adc_readout_control.fc_idelay_ctrl_reset(5)<= p_db_reg_rx_in(adc_readout_idelay3_fc_5)(15);        
        
--        s_adc_readout_control.lg_idelay_load(0)<=p_db_reg_rx_in(adc_readout_idelay3_lg_0)(9);
--        s_adc_readout_control.hg_idelay_load(0)<=p_db_reg_rx_in(adc_readout_idelay3_hg_0)(9);
--        s_adc_readout_control.fc_idelay_load(0)<=p_db_reg_rx_in(adc_readout_idelay3_fc_0)(9);
--        s_adc_readout_control.lg_idelay_load(1)<=p_db_reg_rx_in(adc_readout_idelay3_lg_1)(9);
--        s_adc_readout_control.hg_idelay_load(1)<=p_db_reg_rx_in(adc_readout_idelay3_hg_1)(9);
--        s_adc_readout_control.fc_idelay_load(1)<=p_db_reg_rx_in(adc_readout_idelay3_fc_1)(9);
--        s_adc_readout_control.lg_idelay_load(2)<=p_db_reg_rx_in(adc_readout_idelay3_lg_2)(9);
--        s_adc_readout_control.hg_idelay_load(2)<=p_db_reg_rx_in(adc_readout_idelay3_hg_2)(9);
--        s_adc_readout_control.fc_idelay_load(2)<=p_db_reg_rx_in(adc_readout_idelay3_fc_2)(9);
--        s_adc_readout_control.lg_idelay_load(3)<=p_db_reg_rx_in(adc_readout_idelay3_lg_3)(9);
--        s_adc_readout_control.hg_idelay_load(3)<=p_db_reg_rx_in(adc_readout_idelay3_hg_3)(9);
--        s_adc_readout_control.fc_idelay_load(3)<=p_db_reg_rx_in(adc_readout_idelay3_fc_3)(9);
--        s_adc_readout_control.lg_idelay_load(4)<=p_db_reg_rx_in(adc_readout_idelay3_lg_4)(9);
--        s_adc_readout_control.hg_idelay_load(4)<=p_db_reg_rx_in(adc_readout_idelay3_hg_4)(9);
--        s_adc_readout_control.fc_idelay_load(4)<=p_db_reg_rx_in(adc_readout_idelay3_fc_4)(9);
--        s_adc_readout_control.lg_idelay_load(5)<=p_db_reg_rx_in(adc_readout_idelay3_lg_5)(9);
--        s_adc_readout_control.hg_idelay_load(5)<=p_db_reg_rx_in(adc_readout_idelay3_hg_5)(9);
--        s_adc_readout_control.fc_idelay_load(5)<=p_db_reg_rx_in(adc_readout_idelay3_fc_5)(9);
        
--        s_adc_readout_control.lg_idelay_en_vtc(0)<=p_db_reg_rx_in(adc_readout_idelay3_lg_0)(10);
--        s_adc_readout_control.hg_idelay_en_vtc(0)<=p_db_reg_rx_in(adc_readout_idelay3_hg_0)(10);
--        s_adc_readout_control.fc_idelay_en_vtc(0)<=p_db_reg_rx_in(adc_readout_idelay3_fc_0)(10);
--        s_adc_readout_control.lg_idelay_en_vtc(1)<=p_db_reg_rx_in(adc_readout_idelay3_lg_1)(10);
--        s_adc_readout_control.hg_idelay_en_vtc(1)<=p_db_reg_rx_in(adc_readout_idelay3_hg_1)(10);
--        s_adc_readout_control.fc_idelay_en_vtc(1)<=p_db_reg_rx_in(adc_readout_idelay3_fc_1)(10);
--        s_adc_readout_control.lg_idelay_en_vtc(2)<=p_db_reg_rx_in(adc_readout_idelay3_lg_2)(10);
--        s_adc_readout_control.hg_idelay_en_vtc(2)<=p_db_reg_rx_in(adc_readout_idelay3_hg_2)(10);
--        s_adc_readout_control.fc_idelay_en_vtc(2)<=p_db_reg_rx_in(adc_readout_idelay3_fc_2)(10);
--        s_adc_readout_control.lg_idelay_en_vtc(3)<=p_db_reg_rx_in(adc_readout_idelay3_lg_3)(10);
--        s_adc_readout_control.hg_idelay_en_vtc(3)<=p_db_reg_rx_in(adc_readout_idelay3_hg_3)(10);
--        s_adc_readout_control.fc_idelay_en_vtc(3)<=p_db_reg_rx_in(adc_readout_idelay3_fc_3)(10);
--        s_adc_readout_control.lg_idelay_en_vtc(4)<=p_db_reg_rx_in(adc_readout_idelay3_lg_4)(10);
--        s_adc_readout_control.hg_idelay_en_vtc(4)<=p_db_reg_rx_in(adc_readout_idelay3_hg_4)(10);
--        s_adc_readout_control.fc_idelay_en_vtc(4)<=p_db_reg_rx_in(adc_readout_idelay3_fc_4)(10);
--        s_adc_readout_control.lg_idelay_en_vtc(5)<=p_db_reg_rx_in(adc_readout_idelay3_lg_5)(10);
--        s_adc_readout_control.hg_idelay_en_vtc(5)<=p_db_reg_rx_in(adc_readout_idelay3_hg_5)(10);
--        s_adc_readout_control.fc_idelay_en_vtc(5)<=p_db_reg_rx_in(adc_readout_idelay3_fc_5)(10);

        s_adc_readout_control.lg_idelay_en_vtc(0)<= '1';
        s_adc_readout_control.hg_idelay_en_vtc(0)<= '1';
        s_adc_readout_control.fc_idelay_en_vtc(0)<= '1';
        s_adc_readout_control.lg_idelay_en_vtc(1)<= '1';
        s_adc_readout_control.hg_idelay_en_vtc(1)<= '1';
        s_adc_readout_control.fc_idelay_en_vtc(1)<= '1';
        s_adc_readout_control.lg_idelay_en_vtc(2)<= '1';
        s_adc_readout_control.hg_idelay_en_vtc(2)<= '1';
        s_adc_readout_control.fc_idelay_en_vtc(2)<= '1';
        s_adc_readout_control.lg_idelay_en_vtc(3)<= '1';
        s_adc_readout_control.hg_idelay_en_vtc(3)<= '1';
        s_adc_readout_control.fc_idelay_en_vtc(3)<= '1';
        s_adc_readout_control.lg_idelay_en_vtc(4)<= '1';
        s_adc_readout_control.hg_idelay_en_vtc(4)<= '1';
        s_adc_readout_control.fc_idelay_en_vtc(4)<= '1';
        s_adc_readout_control.lg_idelay_en_vtc(5)<= '1';
        s_adc_readout_control.hg_idelay_en_vtc(5)<= '1';
        s_adc_readout_control.fc_idelay_en_vtc(5)<= '1';
        
--        s_adc_readout_control.lg_bitslip(0)<=p_db_reg_rx_in(adc_readout_idelay3_lg_0)(14 downto 11);
--        s_adc_readout_control.hg_bitslip(0)<=p_db_reg_rx_in(adc_readout_idelay3_hg_0)(14 downto 11);
--        s_adc_readout_control.lg_bitslip(1)<=p_db_reg_rx_in(adc_readout_idelay3_lg_1)(14 downto 11);
--        s_adc_readout_control.hg_bitslip(1)<=p_db_reg_rx_in(adc_readout_idelay3_hg_1)(14 downto 11);
--        s_adc_readout_control.lg_bitslip(2)<=p_db_reg_rx_in(adc_readout_idelay3_lg_2)(14 downto 11);
--        s_adc_readout_control.hg_bitslip(2)<=p_db_reg_rx_in(adc_readout_idelay3_hg_2)(14 downto 11);
--        s_adc_readout_control.lg_bitslip(3)<=p_db_reg_rx_in(adc_readout_idelay3_lg_3)(14 downto 11);
--        s_adc_readout_control.hg_bitslip(3)<=p_db_reg_rx_in(adc_readout_idelay3_hg_3)(14 downto 11);
--        s_adc_readout_control.lg_bitslip(4)<=p_db_reg_rx_in(adc_readout_idelay3_lg_4)(14 downto 11);
--        s_adc_readout_control.hg_bitslip(4)<=p_db_reg_rx_in(adc_readout_idelay3_hg_4)(14 downto 11);
--        s_adc_readout_control.lg_bitslip(5)<=p_db_reg_rx_in(adc_readout_idelay3_lg_5)(14 downto 11);
--        s_adc_readout_control.hg_bitslip(5)<=p_db_reg_rx_in(adc_readout_idelay3_hg_5)(14 downto 11);
        
--        s_adc_readout_control.channel_lg_pedestal_test_lower(0)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_0)(13 downto 0);
--        s_adc_readout_control.channel_lg_pedestal_test_higher(0)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_0)(29 downto 16);
--        s_adc_readout_control.channel_lg_pedestal_test_lower(1)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_1)(13 downto 0);
--        s_adc_readout_control.channel_lg_pedestal_test_higher(1)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_1)(29 downto 16);
--        s_adc_readout_control.channel_lg_pedestal_test_lower(2)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_2)(13 downto 0);
--        s_adc_readout_control.channel_lg_pedestal_test_higher(2)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_2)(29 downto 16);
--        s_adc_readout_control.channel_lg_pedestal_test_lower(3)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_3)(13 downto 0);
--        s_adc_readout_control.channel_lg_pedestal_test_higher(3)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_3)(29 downto 16);
--        s_adc_readout_control.channel_lg_pedestal_test_lower(4)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_4)(13 downto 0);
--        s_adc_readout_control.channel_lg_pedestal_test_higher(4)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_4)(29 downto 16);
--        s_adc_readout_control.channel_lg_pedestal_test_lower(5)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_5)(13 downto 0);
--        s_adc_readout_control.channel_lg_pedestal_test_higher(5)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_lg_5)(29 downto 16);

--        s_adc_readout_control.channel_hg_pedestal_test_lower(0)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_0)(13 downto 0);
--        s_adc_readout_control.channel_hg_pedestal_test_higher(0)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_0)(29 downto 16);
--        s_adc_readout_control.channel_hg_pedestal_test_lower(1)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_1)(13 downto 0);
--        s_adc_readout_control.channel_hg_pedestal_test_higher(1)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_1)(29 downto 16);
--        s_adc_readout_control.channel_hg_pedestal_test_lower(2)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_2)(13 downto 0);
--        s_adc_readout_control.channel_hg_pedestal_test_higher(2)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_2)(29 downto 16);
--        s_adc_readout_control.channel_hg_pedestal_test_lower(3)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_3)(13 downto 0);
--        s_adc_readout_control.channel_hg_pedestal_test_higher(3)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_3)(29 downto 16);
--        s_adc_readout_control.channel_hg_pedestal_test_lower(4)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_4)(13 downto 0);
--        s_adc_readout_control.channel_hg_pedestal_test_higher(4)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_4)(29 downto 16);
--        s_adc_readout_control.channel_hg_pedestal_test_lower(5)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_5)(13 downto 0);
--        s_adc_readout_control.channel_hg_pedestal_test_higher(5)<=p_db_reg_rx_in(adc_readout_pedestal_stability_test_hg_5)(29 downto 16);

-- mainboard driver
p_mb_interface_out.mb_driver <= s_mb_driver;
i_db6_mainboard_driver : entity tilecal.db6_mainboard_driver
	port map(
        --p_db_side_in     => p_clknet_in.db_side,
        p_master_reset_in => s_adc_config_reset,--p_master_reset_in(c_adc_config_reset_bit),
        p_clknet_in       => p_clknet_in,
        p_ssel_out         => p_ssel_out,
        p_sclk_out         => p_sclk_out,
        p_sdata_out         => p_sdata_out,
        p_sdata_in      => p_sdata_in, 
        p_mb_txword_in      => s_mb_txword_in, --p_db_reg_rx_in(cfb_mb_adc_config),--s_mb_txword_in,
        p_mb_rxword_out       => s_mb_driver.rxword_out, --s_mb_rxword_out,
        p_mb_tx_collision_out =>  s_mb_driver.mb_tx_collission_out,
        p_mb_config_trigger_in => s_mb_config_trigger_out,
        p_rx_done_out       => s_mb_driver.rx_done_out, --s_mb_done_out,
        p_tx_done_out       => s_mb_driver.tx_done_out, --s_mb_done_out,
        p_leds_out       => a_db6_mainboard_driver_leds
);

-- mainboard jtag id reader: enable is the manual configbus bit (decoupled from vios)
-- ORed with the auto-read trigger below (fires once per mb0/mb1 reset release); id/done
-- are registered into p_mb_interface_out for downstream consumers.
s_mb_jtag_enable.q0 <= s_mb_jtag_auto_trigger.q0 or p_db_reg_rx_in(cfb_db_debug)(c_db_debug_mb_jtag_read_enable_q0);
s_mb_jtag_enable.q1 <= s_mb_jtag_auto_trigger.q1 or p_db_reg_rx_in(cfb_db_debug)(c_db_debug_mb_jtag_read_enable_q1);

-- boundary-scan (sample) reader: auto-read trigger below (chained after the idcode
-- scan, same reset-release event) ORed with the manual configbus debug bit, plus a
-- shared reg-block-ram port b address command (per side)
s_mb_boundary_scan_enable.q0 <= s_mb_boundary_scan_auto_trigger.q0 or s_boundary_scan_timed_trigger_sync_ff2.q0 or p_db_reg_rx_in(cfb_db_debug)(c_db_debug_mb_boundary_scan_enable_q0);
s_mb_boundary_scan_enable.q1 <= s_mb_boundary_scan_auto_trigger.q1 or s_boundary_scan_timed_trigger_sync_ff2.q1 or p_db_reg_rx_in(cfb_db_debug)(c_db_debug_mb_boundary_scan_enable_q1);
s_mb_boundary_scan_rx_register(0) <= p_db_reg_rx_in(cfb_mb_boundary_scan_reg_address)(6 downto 0) or p_mb_boundary_scan_reg_address_vio_in(0);
s_mb_boundary_scan_rx_register(1) <= p_db_reg_rx_in(cfb_mb_boundary_scan_reg_address)(14 downto 8) or p_mb_boundary_scan_reg_address_vio_in(1);

proc_mb_jtag_auto_read : process(p_clknet_in.osc_clk200)
begin
    if rising_edge(p_clknet_in.osc_clk200) then

        s_mb0_reset_sync_ff1 <= p_master_reset_in(c_mb0_reset_bit);
        s_mb0_reset_sync_ff2 <= s_mb0_reset_sync_ff1;
        s_mb0_reset_sync_ff3 <= s_mb0_reset_sync_ff2;

        s_mb1_reset_sync_ff1 <= p_master_reset_in(c_mb1_reset_bit);
        s_mb1_reset_sync_ff2 <= s_mb1_reset_sync_ff1;
        s_mb1_reset_sync_ff3 <= s_mb1_reset_sync_ff2;

        s_boundary_scan_timed_trigger_sync_ff1 <= p_boundary_scan_timed_trigger_in;
        s_boundary_scan_timed_trigger_sync_ff2 <= s_boundary_scan_timed_trigger_sync_ff1;

        if s_mb0_reset_sync_ff1 = '1' then
            s_boot_boundary_scan_done.q0 <= '0';
        elsif s_mb_boundary_scan_done.q0 = '1' then
            s_boot_boundary_scan_done.q0 <= '1';
        end if;
        if s_mb1_reset_sync_ff1 = '1' then
            s_boot_boundary_scan_done.q1 <= '0';
        elsif s_mb_boundary_scan_done.q1 = '1' then
            s_boot_boundary_scan_done.q1 <= '1';
        end if;

        case s_mb_jtag_auto_read_sm_q0 is
            when st_idle =>
                if s_mb0_reset_sync_ff3 = '1' and s_mb0_reset_sync_ff2 = '0' then -- falling edge: mb0 reset released
                    s_mb_jtag_auto_trigger.q0  <= '1';
                    s_mb_jtag_auto_read_sm_q0  <= st_read_id;
                end if;
            when st_read_id =>
                if s_mb_jtag_done.q0 = '1' then
                    s_mb_jtag_auto_trigger.q0  <= '0';
                    s_mb_jtag_auto_read_sm_q0  <= st_gap;
                end if;
            when st_gap =>
                -- both auto-triggers held low for c_jtag_gap_cycles (see declaration
                -- above) so the driver's st_done state definitely samples them low
                -- and returns to st_idle before the boundary-scan start pulse arrives
                if s_mb_jtag_gap_cnt_q0 = c_jtag_gap_cycles-1 then
                    s_mb_jtag_gap_cnt_q0 <= 0;
                    s_mb_boundary_scan_auto_trigger.q0 <= '1';
                    s_mb_jtag_auto_read_sm_q0          <= st_read_boundary;
                else
                    s_mb_jtag_gap_cnt_q0 <= s_mb_jtag_gap_cnt_q0 + 1;
                end if;
            when st_read_boundary =>
                if s_mb_boundary_scan_done.q0 = '1' then
                    s_mb_boundary_scan_auto_trigger.q0  <= '0';
                    s_mb_jtag_auto_read_sm_q0           <= st_idle;
                end if;
            when others =>
                s_mb_jtag_auto_read_sm_q0 <= st_idle;
        end case;

        case s_mb_jtag_auto_read_sm_q1 is
            when st_idle =>
                if s_mb1_reset_sync_ff3 = '1' and s_mb1_reset_sync_ff2 = '0' then -- falling edge: mb1 reset released
                    s_mb_jtag_auto_trigger.q1  <= '1';
                    s_mb_jtag_auto_read_sm_q1  <= st_read_id;
                end if;
            when st_read_id =>
                if s_mb_jtag_done.q1 = '1' then
                    s_mb_jtag_auto_trigger.q1  <= '0';
                    s_mb_jtag_auto_read_sm_q1  <= st_gap;
                end if;
            when st_gap =>
                if s_mb_jtag_gap_cnt_q1 = c_jtag_gap_cycles-1 then
                    s_mb_jtag_gap_cnt_q1 <= 0;
                    s_mb_boundary_scan_auto_trigger.q1 <= '1';
                    s_mb_jtag_auto_read_sm_q1          <= st_read_boundary;
                else
                    s_mb_jtag_gap_cnt_q1 <= s_mb_jtag_gap_cnt_q1 + 1;
                end if;
            when st_read_boundary =>
                if s_mb_boundary_scan_done.q1 = '1' then
                    s_mb_boundary_scan_auto_trigger.q1  <= '0';
                    s_mb_jtag_auto_read_sm_q1           <= st_idle;
                end if;
            when others =>
                s_mb_jtag_auto_read_sm_q1 <= st_idle;
        end case;

    end if;
end process;

p_mb_interface_out.mb_jtag_id   <= s_mb_jtag_id;
p_mb_interface_out.mb_jtag_done <= s_mb_jtag_done;
p_mb_interface_out.mb_boundary_scan      <= s_mb_boundary_scan;
p_mb_interface_out.mb_boundary_scan_done <= s_mb_boundary_scan_done;
p_mb_interface_out.mb_boundary_scan_boot_done <= s_boot_boundary_scan_done;

i_db6_jtag_readers_controller : entity tilecal.db6_jtag_readers_controller
    generic map (
        g_clk_div => 50
    )
    port map (
        p_clk_in       => p_clknet_in.osc_clk200,
        p_enable_in    => s_mb_jtag_enable,
        p_enable_boundary_scan_in => s_mb_boundary_scan_enable,
        p_boundary_scan_out       => s_mb_boundary_scan,
        p_boundary_scan_done_out  => s_mb_boundary_scan_done,
        p_bs_rx_register_in       => s_mb_boundary_scan_rx_register,
        p_bs_tx_register_out      => open,
        p_jtag_tck_out => p_mb_jtag_tck_out,
        p_jtag_tms_out => p_mb_jtag_tms_out,
        p_jtag_tdi_out => p_mb_jtag_tdi_out,
        p_jtag_tdo_in  => p_mb_jtag_tdo_in,
        p_id_out       => s_mb_jtag_id,
        p_done_out     => s_mb_jtag_done
    );


s_adc_register_config_from_configbus.mb_fpga_select <= "100";-- all fpgas --p_db_reg_rx_in(adc_config_module)(2 downto 0);
s_adc_register_config_from_configbus.mb_pmt_select <= "11";--all tubes --p_db_reg_rx_in(adc_config_module)(4 downto 3);
s_adc_register_config_from_configbus.adc_registers(1) <= p_db_reg_rx_in(cfb_loopback)(31 downto 24);
s_adc_register_config_from_configbus.adc_registers(2) <= p_db_reg_rx_in(cfb_loopback)(23 downto 16);     
s_adc_register_config_from_configbus.adc_registers(3) <= p_db_reg_rx_in(cfb_loopback)(15 downto 8);
s_adc_register_config_from_configbus.adc_registers(4) <= p_db_reg_rx_in(cfb_loopback)(7 downto 0);
s_adc_register_config_from_configbus.mode <= p_db_reg_rx_in(cfb_db_debug)(c_db_debug_mb_adc_config_mode);
s_adc_register_config_from_configbus.trigger_mb_adc_config <= p_db_reg_rx_in(cfb_db_debug)(c_db_debug_mb_adc_config_trigger);

s_adc_register_config_from_readout <= s_adc_readout.mb_adc_config_control;
s_adc_config_reset <= p_master_reset_in(c_adc_config_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_adc_config_reset_bit);

i_db6_adc_config_driver  : entity tilecal.db6_adc_config_driver 
    generic map(
    g_bitclk           => g_bitclk
    )
    port map( 
        p_master_reset_in    => s_adc_config_reset, --p_adc_config_reset_in,--p_db_reg_rx_in(cfb_strobe_reg)(c_adc_config_reset_bit),
        p_clknet_in 			=> p_clknet_in,
        p_adc_register_config_from_readout_in => s_adc_register_config_from_readout,
        p_adc_register_config_from_configbus_in => s_adc_register_config_from_configbus,
        p_adc_config_done_out   => s_adc_readout_control.adc_config_done,
        p_mb_config_trigger_out => s_mb_config_trigger_out,
        p_mb_config_done_in   => s_mb_driver.tx_done_out,
        p_fe_data_out           => s_mb_txword_in,
        p_fe_data_in            =>  p_db_reg_rx_in(cfb_mb_adc_config),
        p_leds_out => s_adc_config_leds
  );

--------------------------------------------------------------------------------------------------------------------------
--adc_readout! 

--i_vio_adc_config_driver : vio_adc_config_driver
--  PORT MAP (
--    clk => p_clknet_in.clk40,
--    probe_in0(0) => s_adc_register_config_from_configbus.mode,
--    probe_in1(0) => s_adc_register_config_from_configbus.trigger_mb_adc_config,
--    probe_in2 => s_adc_register_config_from_configbus.mb_fpga_select,
--    probe_in3 => s_adc_register_config_from_configbus.mb_pmt_select,
--    probe_in4 => s_adc_register_config_from_configbus.adc_registers(0),
--    probe_in5 => s_adc_register_config_from_configbus.adc_registers(1),
--    probe_in6 => s_adc_register_config_from_configbus.adc_registers(2),
--    probe_in7 => s_adc_register_config_from_configbus.adc_registers(3),
--    probe_in8 => s_adc_register_config_from_configbus.adc_registers(4),
--    probe_in9(0) => s_reset_adc_config,
--    probe_in10 => s_adc_config_leds,
--    probe_in11 => a_db6_mainboard_driver_leds,
--    probe_out0(0) => s_adc_register_config_from_configbus.mode,
--    probe_out1(0) => s_adc_register_config_from_configbus.trigger_mb_adc_config,
--    probe_out2 => s_adc_register_config_from_configbus.mb_fpga_select,
--    probe_out3 => s_adc_register_config_from_configbus.mb_pmt_select,
--    probe_out4 => s_adc_register_config_from_configbus.adc_registers(0),
--    probe_out5 => s_adc_register_config_from_configbus.adc_registers(1),
--    probe_out6 => s_adc_register_config_from_configbus.adc_registers(2),
--    probe_out7 => s_adc_register_config_from_configbus.adc_registers(3),
--    probe_out8 => s_adc_register_config_from_configbus.adc_registers(4),
--    probe_out9(0) => s_reset_adc_config,
--    probe_out10(0) => p_mb_interface_out.mb_reset.q0,
--    probe_out11(0) => p_mb_interface_out.mb_reset.q1
--  );

gen_vio_adc_readout : if g_vio_adc_readout = 1 generate

    i_vio_adc_readout : vio_adc_readout
      PORT MAP (
        clk => p_clknet_in.refclk40,
        probe_in0 => s_adc_readout.lg_data(5),
        probe_in1 => s_adc_readout.hg_data(5),
        probe_in2 => s_adc_readout.fc_data(5),
        probe_in3 => s_adc_readout.lg_data(4),
        probe_in4 => s_adc_readout.hg_data(4),
        probe_in5 => s_adc_readout.fc_data(4),
        probe_in6 => s_adc_readout.lg_data(3),
        probe_in7 => s_adc_readout.hg_data(3),
        probe_in8 => s_adc_readout.fc_data(3),
        probe_in9 => s_adc_readout.lg_data(2),
        probe_in10 => s_adc_readout.hg_data(2),
        probe_in11 => s_adc_readout.fc_data(2),
        probe_in12 => s_adc_readout.lg_data(1),
        probe_in13 => s_adc_readout.hg_data(1),
        probe_in14 => s_adc_readout.fc_data(1),
        probe_in15 => s_adc_readout.lg_data(0),
        probe_in16 => s_adc_readout.hg_data(0),
        probe_in17 => s_adc_readout.fc_data(0),
        probe_in18(47 downto 0) =>(others=>'0'), -- s_adc_readout.channel_valid_fc_frame_counter(5)(47 downto 0),
--        probe_in18(8 downto 0) => s_adc_readout_control_out.lg_idelay_count(5),
        probe_in19(47 downto 0) => (others=>'0'), --s_adc_readout.channel_valid_fc_frame_counter(4)(47 downto 0),
--        probe_in19(8 downto 0) => s_adc_readout_control_out.lg_idelay_count(4),
        probe_in20(47 downto 0) => (others=>'0'), --s_adc_readout.channel_valid_fc_frame_counter(3)(47 downto 0),
--        probe_in20(8 downto 0) => s_adc_readout_control_out.lg_idelay_count(3),
        probe_in21(47 downto 0) => (others=>'0'), --s_adc_readout.channel_valid_fc_frame_counter(2)(47 downto 0),
--        probe_in21(8 downto 0) => s_adc_readout_control_out.lg_idelay_count(2),
        probe_in22(47 downto 0) => (others=>'0'), --s_adc_readout.channel_valid_fc_frame_counter(1)(47 downto 0),
--        probe_in22(8 downto 0) => s_adc_readout_control_out.lg_idelay_count(1),
        probe_in23(47 downto 0) => (others=>'0'), --s_adc_readout.channel_valid_fc_frame_counter(0)(47 downto 0),
--        probe_in23(8 downto 0) => s_adc_readout_control_out.lg_idelay_count(0),
        probe_in24 => s_db6_adc_interface_leds,
        probe_in25(47 downto 0) => (others=>'0'), --s_adc_readout.channel_invalid_fc_frame_counter(5)(47 downto 0),
--        probe_in25(8 downto 0) => s_adc_readout_control_out.fc_idelay_count(5),
        probe_in26(47 downto 0) => (others=>'0'), --s_adc_readout.channel_invalid_fc_frame_counter(4)(47 downto 0),
--        probe_in26(8 downto 0) => s_adc_readout_control_out.fc_idelay_count(4),
        probe_in27(47 downto 0) => (others=>'0'), --s_adc_readout.channel_invalid_fc_frame_counter(3)(47 downto 0),
--        probe_in27(8 downto 0) => s_adc_readout_control_out.fc_idelay_count(3),
        probe_in28(47 downto 0) => (others=>'0'), --s_adc_readout.channel_invalid_fc_frame_counter(2)(47 downto 0),
--        probe_in28(8 downto 0) => s_adc_readout_control_out.fc_idelay_count(2),
        probe_in29(47 downto 0) => (others=>'0'), --s_adc_readout.channel_invalid_fc_frame_counter(1)(47 downto 0),
--        probe_in29(8 downto 0) => s_adc_readout_control_out.fc_idelay_count(1),
        probe_in30(47 downto 0) => (others=>'0'), --s_adc_readout.channel_invalid_fc_frame_counter(0)(47 downto 0),
--        probe_in30(8 downto 0) => s_adc_readout_control_out.fc_idelay_count(0),
        probe_in31(0) => s_adc_readout.channel_locked(0),
        probe_in32(0) => s_adc_readout.channel_locked(1),
        probe_in33(0) => s_adc_readout.channel_locked(2),
        probe_in34(0) => s_adc_readout.channel_locked(3),
        probe_in35(0) => s_adc_readout.channel_locked(4),
        probe_in36(0) => s_adc_readout.channel_locked(5),
--        probe_in31(0) => s_adc_readout.channel_fifo_block_ram_fc(0).prog_full,
--        probe_in32(0) => s_adc_readout.channel_fifo_block_ram_fc(1).prog_full,
--        probe_in33(0) => s_adc_readout.channel_fifo_block_ram_fc(2).prog_full,
--        probe_in34(0) => s_adc_readout.channel_fifo_block_ram_fc(3).prog_full,
--        probe_in35(0) => s_adc_readout.channel_fifo_block_ram_fc(4).prog_full,
--        probe_in36(0) => s_adc_readout.channel_fifo_block_ram_fc(5).prog_full,

        
        probe_in37(0) => s_adc_readout.channel_missed_locked(0),
        probe_in38(0) => s_adc_readout.channel_missed_locked(1),
        probe_in39(0) => s_adc_readout.channel_missed_locked(2),
        probe_in40(0) => s_adc_readout.channel_missed_locked(3),
        probe_in41(0) => s_adc_readout.channel_missed_locked(4),
        probe_in42(0) => s_adc_readout.channel_missed_locked(5),
--        probe_in37(0) => s_adc_readout.channel_fifo_block_ram_hg(0).prog_full,
--        probe_in38(0) => s_adc_readout.channel_fifo_block_ram_hg(1).prog_full,
--        probe_in39(0) => s_adc_readout.channel_fifo_block_ram_hg(2).prog_full,
--        probe_in40(0) => s_adc_readout.channel_fifo_block_ram_hg(3).prog_full,
--        probe_in41(0) => s_adc_readout.channel_fifo_block_ram_hg(4).prog_full,
--        probe_in42(0) => s_adc_readout.channel_fifo_block_ram_hg(5).prog_full,
        
        probe_in43(0) => s_adc_readout.channel_frame_missalignemt(0),-- s_adc_readout.channel_clk280_locked(0),
        probe_in44(0) => s_adc_readout.channel_frame_missalignemt(1),--s_adc_readout.channel_clk280_locked(1),
        probe_in45(0) => s_adc_readout.channel_frame_missalignemt(2),--s_adc_readout.channel_clk280_locked(2),
        probe_in46(0) => s_adc_readout.channel_frame_missalignemt(3),--s_adc_readout.channel_clk280_locked(3),
        probe_in47(0) => s_adc_readout.channel_frame_missalignemt(4),--s_adc_readout.channel_clk280_locked(4),
        probe_in48(0) => s_adc_readout.channel_frame_missalignemt(5),--s_adc_readout.channel_clk280_locked(5),
--        probe_in43(0) => s_adc_readout.channel_fifo_block_ram_fc(0).prog_empty,
--        probe_in44(0) => s_adc_readout.channel_fifo_block_ram_fc(1).prog_empty,
--        probe_in45(0) => s_adc_readout.channel_fifo_block_ram_fc(2).prog_empty,
--        probe_in46(0) => s_adc_readout.channel_fifo_block_ram_fc(3).prog_empty,
--        probe_in47(0) => s_adc_readout.channel_fifo_block_ram_fc(4).prog_empty,
--        probe_in48(0) => s_adc_readout.channel_fifo_block_ram_fc(5).prog_empty,
        
        probe_in49(0) => s_adc_readout.channel_phase_offset(0), --channel_clk280_stopped(0),
        probe_in50(0) => s_adc_readout.channel_phase_offset(1), --channel_clk280_stopped(1),
        probe_in51(0) => s_adc_readout.channel_phase_offset(2), --channel_clk280_stopped(2),
        probe_in52(0) => s_adc_readout.channel_phase_offset(3), --channel_clk280_stopped(3),
        probe_in53(0) => s_adc_readout.channel_phase_offset(4), --channel_clk280_stopped(4),
        probe_in54(0) => s_adc_readout.channel_phase_offset(5), --channel_clk280_stopped(5),
--        probe_in49(0) => s_adc_readout.channel_fifo_block_ram_hg(0).prog_empty,
--        probe_in50(0) => s_adc_readout.channel_fifo_block_ram_hg(1).prog_empty,
--        probe_in51(0) => s_adc_readout.channel_fifo_block_ram_hg(2).prog_empty,
--        probe_in52(0) => s_adc_readout.channel_fifo_block_ram_hg(3).prog_empty,
--        probe_in53(0) => s_adc_readout.channel_fifo_block_ram_hg(4).prog_empty,
--        probe_in54(0) => s_adc_readout.channel_fifo_block_ram_hg(5).prog_empty,
        
        probe_in55 => (others=>'0'), --s_adc_readout.channel_valid_divclk_frame_counter(0)(47 downto 0),--s_adc_readout.channel_leds(0),
        probe_in56 => (others=>'0'), --s_adc_readout.channel_valid_divclk_frame_counter(1)(47 downto 0),--s_adc_readout.channel_leds(1),
        probe_in57 => (others=>'0'), --s_adc_readout.channel_valid_divclk_frame_counter(2)(47 downto 0),--s_adc_readout.channel_leds(2),
        probe_in58 => (others=>'0'), --s_adc_readout.channel_valid_divclk_frame_counter(3)(47 downto 0),--s_adc_readout.channel_leds(3),
        probe_in59 => (others=>'0'), --s_adc_readout.channel_valid_divclk_frame_counter(4)(47 downto 0),--s_adc_readout.channel_leds(4),
        probe_in60 => (others=>'0'), --s_adc_readout.channel_valid_divclk_frame_counter(5)(47 downto 0),--s_adc_readout.channel_leds(5),
--        probe_in55 => s_adc_readout.channel_fifo_block_ram_hg(0).rd_data_count(3 downto 0),
--        probe_in56 => s_adc_readout.channel_fifo_block_ram_hg(0).wr_data_count(3 downto 0),
--        probe_in57 => s_adc_readout.channel_fifo_block_ram_fc(0).rd_data_count(3 downto 0),
--        probe_in58 => s_adc_readout.channel_fifo_block_ram_fc(0).wr_data_count(3 downto 0),
--        probe_in59 => s_adc_readout.channel_fifo_block_ram_lg(0).rd_data_count(3 downto 0),
--        probe_in60 => s_adc_readout.channel_fifo_block_ram_lg(0).wr_data_count(3 downto 0),
    
        probe_out0(0) => s_reset_adc_interface_from_vio
      );
end generate;
--------------------------------------------------------------------------------------------------------------------------
--pattern test! 

--i_vio_adc_readout_pattern_test : vio_adc_readout_pattern_test
--  PORT MAP (
--    clk =>  p_clknet_in.clk40,
--    probe_in0 => s_adc_readout.lg_data(5),
--    probe_in1 => s_adc_readout.hg_data(5),
--    probe_in2 => s_adc_readout.fc_data(5),
--    probe_in3 => s_adc_readout.lg_data(4),
--    probe_in4 => s_adc_readout.hg_data(4),
--    probe_in5 => s_adc_readout.fc_data(4),
--    probe_in6 => s_adc_readout.lg_data(3),
--    probe_in7 => s_adc_readout.hg_data(3),
--    probe_in8 => s_adc_readout.fc_data(3),
--    probe_in9 => s_adc_readout.lg_data(2),
--    probe_in10 => s_adc_readout.hg_data(2),
--    probe_in11 => s_adc_readout.fc_data(2),
--    probe_in12 => s_adc_readout.lg_data(1),
--    probe_in13 => s_adc_readout.hg_data(1),
--    probe_in14 => s_adc_readout.fc_data(1),
--    probe_in15 => s_adc_readout.lg_data(0),
--    probe_in16 => s_adc_readout.hg_data(0),
--    probe_in17 => s_adc_readout.fc_data(0),
--    probe_in18 => s_adc_readout.channel_valid_fc_frame_counter(5),
--    probe_in19 => s_adc_readout.channel_valid_fc_frame_counter(4),
--    probe_in20 => s_adc_readout.channel_valid_fc_frame_counter(3),
--    probe_in21 => s_adc_readout.channel_valid_fc_frame_counter(2),
--    probe_in22 => s_adc_readout.channel_valid_fc_frame_counter(1),
--    probe_in23 => s_adc_readout.channel_valid_fc_frame_counter(0),
--    probe_in24 => s_adc_readout.channel_valid_divclk_frame_counter(5),
--    probe_in25 => s_adc_readout.channel_valid_divclk_frame_counter(4),
--    probe_in26 => s_adc_readout.channel_valid_divclk_frame_counter(3),
--    probe_in27 => s_adc_readout.channel_valid_divclk_frame_counter(2),
--    probe_in28 => s_adc_readout.channel_valid_divclk_frame_counter(1),
--    probe_in29 => s_adc_readout.channel_valid_divclk_frame_counter(0),
--    probe_in30 => s_adc_readout.channel_invalid_lg_frame_counter(5),
--    probe_in31 => s_adc_readout.channel_invalid_lg_frame_counter(4),
--    probe_in32 => s_adc_readout.channel_invalid_lg_frame_counter(3),
--    probe_in33 => s_adc_readout.channel_invalid_lg_frame_counter(2),
--    probe_in34 => s_adc_readout.channel_invalid_lg_frame_counter(1),
--    probe_in35 => s_adc_readout.channel_invalid_lg_frame_counter(0),
--    probe_in36 => s_adc_readout.channel_invalid_hg_frame_counter(5),
--    probe_in37 => s_adc_readout.channel_invalid_hg_frame_counter(4),
--    probe_in38 => s_adc_readout.channel_invalid_hg_frame_counter(3),
--    probe_in39 => s_adc_readout.channel_invalid_hg_frame_counter(2),
--    probe_in40 => s_adc_readout.channel_invalid_hg_frame_counter(1),
--    probe_in41 => s_adc_readout.channel_invalid_hg_frame_counter(0),
--    probe_in42 => s_adc_readout.channel_pedestal_test_overflow_hg_counter(0),
--    probe_in43 => s_adc_readout.channel_pedestal_test_overflow_hg_counter(1),
--    probe_in44 => s_adc_readout.channel_pedestal_test_overflow_hg_counter(2),
--    probe_in45 => s_adc_readout.channel_pedestal_test_overflow_hg_counter(3),
--    probe_in46 => s_adc_readout.channel_pedestal_test_overflow_hg_counter(4),
--    probe_in47 => s_adc_readout.channel_pedestal_test_overflow_hg_counter(5),
--    probe_in48 => s_adc_readout.channel_pedestal_test_underflow_hg_counter(0),
--    probe_in49 => s_adc_readout.channel_pedestal_test_underflow_hg_counter(1),
--    probe_in50 => s_adc_readout.channel_pedestal_test_underflow_hg_counter(2),
--    probe_in51 => s_adc_readout.channel_pedestal_test_underflow_hg_counter(3),
--    probe_in52 => s_adc_readout.channel_pedestal_test_underflow_hg_counter(4),
--    probe_in53 => s_adc_readout.channel_pedestal_test_underflow_hg_counter(5),
    
--    probe_out0(0) => s_enable_test_pattern,
--    probe_out1 => s_adc_readout_control.channel_lg_data_test_pattern(5),
--    probe_out2 => s_adc_readout_control.channel_lg_data_test_pattern(4),
--    probe_out3 => s_adc_readout_control.channel_lg_data_test_pattern(3),
--    probe_out4 => s_adc_readout_control.channel_lg_data_test_pattern(2),
--    probe_out5 => s_adc_readout_control.channel_lg_data_test_pattern(1),
--    probe_out6 => s_adc_readout_control.channel_lg_data_test_pattern(0),
--    probe_out7 => s_adc_readout_control.channel_hg_data_test_pattern(5),
--    probe_out8 => s_adc_readout_control.channel_hg_data_test_pattern(4),
--    probe_out9 => s_adc_readout_control.channel_hg_data_test_pattern(3),
--    probe_out10 => s_adc_readout_control.channel_hg_data_test_pattern(2),
--    probe_out11 => s_adc_readout_control.channel_hg_data_test_pattern(1),
--    probe_out12 => s_adc_readout_control.channel_hg_data_test_pattern(0),
--    probe_out13(0) => s_reset_test_pattern
--  );

--s_adc_readout_control.channel_enable_test_pattern(5) <= s_enable_test_pattern;
--s_adc_readout_control.channel_enable_test_pattern(4) <= s_enable_test_pattern;
--s_adc_readout_control.channel_enable_test_pattern(3) <= s_enable_test_pattern;
--s_adc_readout_control.channel_enable_test_pattern(2) <= s_enable_test_pattern;
--s_adc_readout_control.channel_enable_test_pattern(1) <= s_enable_test_pattern;
--s_adc_readout_control.channel_enable_test_pattern(0) <= s_enable_test_pattern;

--s_adc_readout_control.channel_reset_test_pattern(5) <= s_reset_test_pattern;
--s_adc_readout_control.channel_reset_test_pattern(4) <= s_reset_test_pattern;
--s_adc_readout_control.channel_reset_test_pattern(3) <= s_reset_test_pattern;
--s_adc_readout_control.channel_reset_test_pattern(2) <= s_reset_test_pattern;
--s_adc_readout_control.channel_reset_test_pattern(1) <= s_reset_test_pattern;
--s_adc_readout_control.channel_reset_test_pattern(0) <= s_reset_test_pattern;

s_adc_readout_control.channel_reset(5) <= p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_0_bit);
s_adc_readout_control.channel_reset(4) <= p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_1_bit);
s_adc_readout_control.channel_reset(3) <= p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_2_bit);
s_adc_readout_control.channel_reset(2) <= p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_3_bit);
s_adc_readout_control.channel_reset(1) <= p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_4_bit);
s_adc_readout_control.channel_reset(0) <= p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_5_bit);

--------------------------------------------------------------------------------------------------------------------------
p_mb_interface_out.cis_interface <= s_cis_interface;
i_db6_cis_interface : entity tilecal.db6_cis_interface
  generic map(
    g_tmr_enabled => 0
  )
  port map( 
        p_clknet_in           => p_clknet_in,
        p_master_reset_in     => p_master_reset_in(c_cis_reset_bit),
        p_db_reg_rx_in        =>p_db_reg_rx_in,
        p_tph_out             => p_tph_out,
        p_tpl_out             => p_tpl_out,
        p_cis_interface_out   => s_cis_interface
  );


p_mb_interface_out.mb_integrator <= s_mb_integrator;
i_db6_integrator_interface : entity tilecal.db6_integrator_interface
port map( 
	p_master_reset_in                   => p_master_reset_in(c_integrator_reset_bit),
    p_clknet_in                  => p_clknet_in,
	p_db_reg_rx_in               => p_db_reg_rx_in,
    p_integrator_sda_drive_out => p_integrator_sda_drive_out,
    p_integrator_sda_tri_out   => p_integrator_sda_tri_out,
    p_integrator_sda_read_in   => p_integrator_sda_read_in,
    p_integrator_scl_drive_out => p_integrator_scl_drive_out,
    p_integrator_scl_tri_out   => p_integrator_scl_tri_out,
    p_integrator_scl_read_in   => p_integrator_scl_read_in, 	
    p_mb_integrator_out          => s_mb_integrator
);


p_leds_out(3) <= s_mb_driver.rx_done_out.q0;
p_leds_out(2) <= s_mb_driver.rx_done_out.q1;
p_leds_out(1) <= s_adc_readout.readout_initialized;
p_leds_out(0) <= s_adc_readout_control.adc_config_done;



end Behavioral;
