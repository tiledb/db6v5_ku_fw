----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Sam Silverstein 
--         : Eduardo Valdes
-- Create Date: 08/28/2018 02:56:16 PM
-- Design Name: 
-- Module Name: db6_clock_interface - Behavioral
-- Project Name: tilecal daughterboard rev 5 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:  db6_clock_interface. 
--                       
-- 
----------------------------------------------------------------------------------

-- common libraries --
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
-- XILINX libraries --
library UNISIM;
use UNISIM.VCOMPONENTS.all;
-- user defined libraries --

library tilecal;
use tilecal.db6_design_package.all;


entity db6_clock_interface is

    generic (
        g_priority_side : std_logic_vector(1 downto 0) := "01";                 --! side to priotitize
        g_num_gth_links                 : integer := 1;                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
        g_num_gth_ref_clks             : integer := c_number_of_gth_refclks;
        g_vio_clknet_status            : integer := 1; --1;--1;
        g_clk_generation               : natural := 0;   -- 2-> advanced bufg_gt, 1 -> use bug_gt, 0 -> use mmcm for gtg_refclk
        g_slow_clk_generation          : natural := 1;   -- 1 -> use slow_clk_gen, 0 -> no use slow clk gen
        g_use_mmcm_mb_quads            : natural := 0;   -- 1 -> use mmcms for b ttc, 0 -> mb ttc directly to IO
        g_use_oddr                     : natural := 0;   -- -> use oddr to generate ttc, 0-> use direct obuf
        GLOBAL_DATE : std_logic_vector(31 downto 0); -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME : std_logic_vector(31 downto 0) -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)

        );
    port(
    --clocks
    p_clkin_in                       : in t_db_clkin;
    p_clknet_out                        : out t_db_clknet;

    --control signals
    p_master_reset_in   : in std_logic;
    p_cfgbus_interface_in : t_cfgbus_interface;
    --p_db_reg_rx_in  : in t_db_reg_rx;
    --p_clk_sel_in   : in std_logic
    
    --leds
    p_leds_out : out std_logic_vector(3 downto 0)
    
    );

end db6_clock_interface;



architecture RTL of db6_clock_interface is

attribute IOB: string;
attribute keep: string;
attribute dont_touch: string;

--components

component mmcm_osc_clk
port
 (-- Clock in ports
  clk_in1           : in     std_logic;
  -- Clock out ports
  p_clk_40_out          : out    std_logic;
  p_clk_80_out          : out    std_logic;
  p_clk_160_out          : out    std_logic;
  p_clk_280_out          : out    std_logic;
  p_clk_40_90_out          : out    std_logic;
  p_clk_40_180_out          : out    std_logic;
  p_clk_40_270_out          : out    std_logic;
  -- Dynamic reconfiguration ports
  p_daddr_in             : in     std_logic_vector(6 downto 0);
  p_dclk_in              : in     std_logic;
  p_den_in               : in     std_logic;
  p_din_in                : in     std_logic_vector(15 downto 0);
  p_dout_out                : out    std_logic_vector(15 downto 0);
  p_dwe_in               : in     std_logic;
  p_drdy_out              : out    std_logic;
  -- Dynamic phase shift ports
  p_psclk_in             : in     std_logic;
  p_psen_in              : in     std_logic;
  p_psincdec_in          : in     std_logic;
  p_psdone_out            : out    std_logic;
  -- Status and control signals
  p_reset_in             : in     std_logic;
  p_input_clk_stopped_out : out    std_logic;
  p_clkfb_stopped_out : out    std_logic;
  p_locked_out            : out    std_logic;
  p_cddcdone_out          : out    std_logic; 
  p_cddcreq_in           : in     std_logic
  
 );
end component;

component pll_osc_clk
port
 (-- Clock in ports
  -- Clock out ports
  p_clk40_out          : out    std_logic;
  p_clk200_out          : out    std_logic;
  -- Dynamic reconfiguration ports
  p_daddr_in             : in     std_logic_vector(6 downto 0);
  p_dclk_in              : in     std_logic;
  p_den_in               : in     std_logic;
  p_din_in                : in     std_logic_vector(15 downto 0);
  p_dout_out                : out    std_logic_vector(15 downto 0);
  p_dwe_in               : in     std_logic;
  p_drdy_out              : out    std_logic;
  -- Status and control signals
  p_reset_in             : in     std_logic;
  p_locked_out            : out    std_logic;
  p_clk_in           : in     std_logic
 );
end component;

component mmcm_gbt40_db
port
 (-- Clock in ports
  p_clk_in         : in     std_logic;
  --clk_in2_p         : in     std_logic;
  --clk_in2_n         : in     std_logic;
  --p_clk_sel_in           : in     std_logic;
  -- Clock out ports
  p_clk40_out          : out    std_logic;
  p_clk80_out          : out    std_logic;
  p_clk160_out          : out    std_logic;
  p_clk280_out          : out    std_logic;
  p_clk40_90_out          : out    std_logic;
  p_clk40_180_out          : out    std_logic;
  p_clk40_270_out          : out    std_logic;
  -- Dynamic reconfiguration ports
  p_daddr_in             : in     std_logic_vector(6 downto 0);
  p_dclk_in              : in     std_logic;
  p_den_in               : in     std_logic;
  p_din_in                : in     std_logic_vector(15 downto 0);
  p_dout_out                : out    std_logic_vector(15 downto 0);
  p_dwe_in               : in     std_logic;
  p_drdy_out              : out    std_logic;
  -- Dynamic phase shift ports
  p_psclk_in             : in     std_logic;
  p_psen_in              : in     std_logic;
  p_psincdec_in          : in     std_logic;
  p_psdone_out            : out    std_logic;
  -- Status and control signals
  p_reset_in             : in     std_logic;
  p_input_clk_stopped_out : out    std_logic;
  p_clkfb_stopped_out : out    std_logic;
  p_locked_out            : out    std_logic;
  p_cddcdone_out          : out    std_logic; 
  p_cddcreq_in           : in     std_logic;
  clk_in1_p         : in     std_logic;
  clk_in1_n         : in     std_logic
 );
end component;

component mmcm_gbt40_cfgbus
port
 (-- Clock in ports
  p_clk_in         : in     std_logic;
  --clk_in2           : in     std_logic;
  --p_clk_sel_in           : in     std_logic;
  -- Clock out ports
  p_clk40_out          : out    std_logic;
  p_clk40_90_out          : out    std_logic;
  p_clk40_180_out          : out    std_logic;
  p_clk40_270_out          : out    std_logic;
  p_clk80_out          : out    std_logic;
  p_clk160_out          : out    std_logic;
  p_clk280_out          : out    std_logic;
  -- Dynamic reconfiguration ports
  p_daddr_in             : in     std_logic_vector(6 downto 0);
  p_dclk_in              : in     std_logic;
  p_den_in               : in     std_logic;
  p_din_in                : in     std_logic_vector(15 downto 0);
  p_dout_out                : out    std_logic_vector(15 downto 0);
  p_dwe_in               : in     std_logic;
  p_drdy_out              : out    std_logic;
  -- Dynamic phase shift ports
  p_psclk_in             : in     std_logic;
  p_psen_in              : in     std_logic;
  p_psincdec_in          : in     std_logic;
  p_psdone_out            : out    std_logic;
  -- Status and control signals
  p_reset_in             : in     std_logic;
  p_input_clk_stopped_out : out    std_logic;
  p_clkfb_stopped_out : out    std_logic;
  p_locked_out            : out    std_logic;
  p_cddcdone_out          : out    std_logic; 
  p_cddcreq_in           : in     std_logic
  --clk_in1           : in     std_logic
 );
end component;


component mmcm_gbt40_mb
port
 (-- Clock in ports
  p_clk_in         : in     std_logic;
  --clk_in2_p         : in     std_logic;
  --clk_in2_n         : in     std_logic;
  --p_clk_sel_in           : in     std_logic;
  -- Clock out ports
  p_clk40_out          : out    std_logic;
  p_clk40_90_out          : out    std_logic;
  p_clk40_180_out          : out    std_logic;
  p_clk40_270_out          : out    std_logic;
  p_clk80_out          : out    std_logic;
  p_clk280_out          : out    std_logic;
  p_clk560_out          : out    std_logic;
  -- Dynamic reconfiguration ports
  p_daddr_in             : in     std_logic_vector(6 downto 0);
  p_dclk_in              : in     std_logic;
  p_den_in               : in     std_logic;
  p_din_in                : in     std_logic_vector(15 downto 0);
  p_dout_out                : out    std_logic_vector(15 downto 0);
  p_dwe_in               : in     std_logic;
  p_drdy_out              : out    std_logic;
  -- Dynamic phase shift ports
  p_psclk_in             : in     std_logic;
  p_psen_in              : in     std_logic;
  p_psincdec_in          : in     std_logic;
  p_psdone_out            : out    std_logic;
  -- Status and control signals
  p_reset_in             : in     std_logic;
  p_input_clk_stopped_out : out    std_logic;
  p_clkfb_stopped_out : out    std_logic;
  p_locked_out            : out    std_logic;
  p_cddcdone_out          : out    std_logic; 
  p_cddcreq_in           : in     std_logic
  --clk_in1_p         : in     std_logic;
  --clk_in1_n         : in     std_logic
 );
end component;

component mmcm_gbt40_db6
port
 (-- Clock in ports
  -- Clock out ports
  p_clk40_out          : out    std_logic;
  p_clk80_out          : out    std_logic;
  p_clk120_out          : out    std_logic;
  p_clk160_out          : out    std_logic;
  p_clk240_out          : out    std_logic;
  -- Dynamic reconfiguration ports
  p_daddr_in             : in     std_logic_vector(6 downto 0);
  p_dclk_in              : in     std_logic;
  p_den_in               : in     std_logic;
  p_din_in                : in     std_logic_vector(15 downto 0);
  p_dout_out                : out    std_logic_vector(15 downto 0);
  p_dwe_in               : in     std_logic;
  p_drdy_out              : out    std_logic;
  -- Dynamic phase shift ports
  p_psclk_in             : in     std_logic;
  p_psen_in              : in     std_logic;
  p_psincdec_in          : in     std_logic;
  p_psdone_out            : out    std_logic;
  -- Status and control signals
  p_reset_in             : in     std_logic;
  p_input_clk_stopped_out : out     std_logic;
  p_locked_out            : out    std_logic;
  p_cddcdone_out          : out    std_logic; 
  p_cddcreq_in           : in     std_logic;
  clk_in1           : in     std_logic
 );
end component;

component mmcm_gtg_refclk
port
 (-- Clock in ports
  -- Clock out ports
--  p_clk40_out          : out    std_logic;
  p_clk80_out          : out    std_logic;
  p_clk240_out          : out    std_logic;
--  p_clk160_out          : out    std_logic;
  -- Status and control signals
  reset             : in     std_logic;
  p_locked_out            : out    std_logic;
  clk_in1           : in     std_logic
 );
end component;

component mmcm_cis_interface
port
 (-- Clock in ports
  -- Clock out ports
  --p_clk640_out          : out    std_logic;
  p_clk320_out          : out    std_logic;
  -- Status and control signals
  p_locked_out            : out    std_logic;
  p_clk40_in           : in     std_logic
 );
end component;

component mmcm_gth_refclk
port
 (-- Clock in ports
  -- Clock out ports
  p_clk80_out          : out    std_logic;
  -- Status and control signals
  reset             : in     std_logic;
  p_locked_out            : out    std_logic;
  clk_in1           : in     std_logic
 );
end component;

--signals
signal s_clknet_out : t_db_clknet;
attribute keep of s_clknet_out : signal is "TRUE";
attribute dont_touch of s_clknet_out : signal is "TRUE";

signal s_db_clkin_local : std_logic_vector(0 downto 0);

signal s_pll_osc, s_mmcm_osc, s_mmcm_gbt40_db, s_mmcm_gbt40_cfgbus, s_mmcm_gbt40_db6, s_mmcm_gbt40_mb_q0, s_mmcm_gbt40_mb_q1, s_mmcm_gtg_refclk, s_mmcm_cis_interface : t_mmcm_control;

signal s_gbt40_q0_delay_control, s_gbt40_q1_delay_control: t_delay_control;
signal s_gbt40_q0_clk_shape,s_gbt40_q1_clk_shape : std_logic_vector(1 downto 0) := ('1','0');

type t_sm_sync is (st_syncying,st_wait,st_synced);
type t_sm_sync_array is array (0 to g_num_gth_links-1) of t_sm_sync;
signal s_sm_data_sync_array : t_sm_sync_array := (st_syncying,st_syncying);
signal s_sm_data_sync, s_sm_cis_sync, s_sm_tx_sync : t_sm_sync := st_syncying;
signal s_bcr_cis, s_bcr_buffer_cis :std_logic :='0';
signal s_bcr_array, s_bcr_buffer_array : std_logic_vector(g_num_gth_links-1 downto 0) :=(others=>'0');

signal s_osc_clk100, s_clk40, s_tp_clk40_q0_local, s_tp_clk320_q0_local, s_tp_clk40_q1_local, s_tp_clk40_q0_remote, s_tp_clk40_q1_remote : std_logic;

type t_bufg_gt_sync is record
    cesync : std_logic; -- 1-bit output: synchronized ce
    clrsync : std_logic; -- 1-bit output: synchronized clr
    ce : std_logic; -- 1-bit input: asynchronous enable
    clk : std_logic; -- 1-bit input: clock
    clr : std_logic; -- 1-bit input: asynchronous clea
end record;
type t_bufg_gt_sync_gth_outclkfabric is array (g_num_gth_links-1 downto 0) of t_bufg_gt_sync;
signal s_bufg_gt_sync_gth_txoutclkfabric, s_bufg_gt_sync_gth_rxoutclkfabric : t_bufg_gt_sync_gth_outclkfabric;

type t_bufg_gt is record
    o : std_logic; -- 1-bit output: buffer
    ce : std_logic; -- 1-bit input: buffer enable
    cemask  : std_logic; -- 1-bit input: ce mask
    clr  : std_logic; -- 1-bit input: asynchronous clear
    clrmask : std_logic; -- 1-bit input: clr mask
    div : std_logic; -- 3-bit input: dymanic divide value
    i  : std_logic; -- 1-bit input: buffer
end record;
type t_bufg_gt_gth_outclkfabric is array (g_num_gth_links-1 downto 0) of t_bufg_gt;
signal s_bufg_gt_gth_txoutclkfabric, s_bufg_gt_gth_rxoutclkfabric : t_bufg_gt_gth_outclkfabric;

COMPONENT counter_binary_32bit
  PORT (
    CLK : IN STD_LOGIC;
    CE : IN STD_LOGIC;
    SCLR : IN STD_LOGIC;
    LOAD : IN STD_LOGIC;
    L : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    Q : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

signal s_counter_binary_ms : t_counter_binary_32bit;
signal s_counter_binary_s : t_counter_binary_32bit;
signal s_counter_binary_100khz : t_counter_binary_32bit;


COMPONENT vio_clknet_status
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in15 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in16 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in17 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in18 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in19 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in20 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in21 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_in22 : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
    probe_in23 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in24 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in25 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in26 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in27 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in28 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in29 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in30 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in31 : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    probe_in32 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    probe_in33 : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    probe_in34 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    probe_in35 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    probe_in36 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    probe_in37 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in38 : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
    probe_in39 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in40 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in41 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
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
    probe_in55 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in56 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in57 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in58 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in59 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in60 : IN STD_LOGIC_VECTOR(95 DOWNTO 0);
    probe_in61 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in62 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_in63 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out2 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out3 : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_out4 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out5 : OUT STD_LOGIC_VECTOR(39 DOWNTO 0);
    probe_out6 : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_out7 : out std_logic_vector(0 downto 0);
    probe_out8 : out std_logic_vector(11 downto 0);
    probe_out9 : out std_logic_vector(11 downto 0);
    probe_out10 : out std_logic_vector(2 downto 0);
    probe_out11 : out std_logic_vector(25 downto 0)
  );
END COMPONENT;

component pll_gbt_wordclk
port
 (-- Clock in ports
  -- Clock out ports
  p_clk240_out          : out    std_logic;
  -- Status and control signals
  p_locked_out            : out    std_logic;
  p_clk_in           : in     std_logic
 );
end component;

component pll_dskclk
port
 (-- Clock in ports
  -- Clock out ports
  p_clk320_out          : out    std_logic;
  -- Status and control signals
  p_locked_out            : out    std_logic;
  p_clk_in           : in     std_logic
 );
end component;


signal s_dna_reset : std_logic;
signal s_dna_done_out : std_logic;
signal s_dna_read_out : std_logic_vector(95 downto 0);


signal s_clkin_in                       : t_db_clkin;

signal s_reset_clknet_from_vio : std_logic;
signal s_reset_main_sm_from_vio : std_logic;
signal s_gth_clksel_from_vio : std_logic_vector(2 downto 0); 
--signal s_cesync, s_clrsync : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);

--attribute keep of p_clk_sel_in, s_gbt40_q0_delay_control, s_gbt40_q1_delay_control, s_osc_clk100, s_clk40, s_tp_clk40_q0_local, s_tp_clk40_q1_local, s_tp_clk40_q0_remote, s_tp_clk40_q1_remote : signal is "TRUE";
--attribute dont_touch of p_clk_sel_in, s_gbt40_q0_delay_control, s_gbt40_q1_delay_control, s_osc_clk100, s_clk40, s_tp_clk40_q0_local, s_tp_clk40_q1_local, s_tp_clk40_q0_remote, s_tp_clk40_q1_remote : signal is "TRUE";

--attribute dont_touch of s_clknet_out : signal is "TRUE";
--attribute keep of s_clknet_out : signal is "TRUE";

signal s_cdc_reset_array_out, s_cdc_reset_array_in : std_logic_vector(g_num_gth_links-1 downto 0);
signal s_cdc_reset_out, s_cdc_reset_in : std_logic;

type t_BUFG_GT_SYNC_array is array (g_num_gth_ref_clks - 1 downto  0) of t_BUFG_GT_SYNC;
signal s_gth_refclk_remote_BUFG_GT_SYNC, s_gth_refclk_local_BUFG_GT_SYNC, s_gth_refclk40_local_BUFG_GT_SYNC: t_BUFG_GT_SYNC_array;

signal s_reset_mb : t_mb_std_logic;

signal s_wordclk_locked : std_logic_vector(g_num_gth_links-1 downto 0);

signal s_running_time_s : std_logic_vector(31 downto 0) := (others=> '0');

begin  -- RTL

--s_clknet_out.cfgbus_clk40 <= s_clknet_out.cfgbus_clk40_local;

-- general signal connections

p_clknet_out<=s_clknet_out;

s_clknet_out.mmcm_gbt40_mb_q0 <= s_mmcm_gbt40_mb_q0;
s_clknet_out.mmcm_gbt40_mb_q1 <= s_mmcm_gbt40_mb_q1;
s_clknet_out.db_leds <= s_clkin_in.db_leds;
s_clknet_out.running_time <= s_running_time_s;
s_clknet_out.bcr<=p_clkin_in.bcr;
s_clknet_out.clksel <= p_clkin_in.clksel;
s_clknet_out.gth_wordclk_sel <= p_clkin_in.gth_wordclk_sel;
s_clknet_out.qpllclksel <= p_clkin_in.qpllclksel; --s_gth_clksel_from_vio; --p_clkin_in.qpllclksel;
s_clknet_out.cpllclksel <= p_clkin_in.qpllclksel; --s_gth_clksel_from_vio; --p_clkin_in.cpllclksel;
s_clknet_out.txsysclksel <= p_clkin_in.txsysclksel;
s_clknet_out.rxsysclksel <= p_clkin_in.rxsysclksel;
s_clknet_out.rxoutclksel <= p_clkin_in.rxoutclksel;
s_clknet_out.txoutclksel <= p_clkin_in.txoutclksel;

s_clknet_out.txpllclksel <= p_clkin_in.txpllclksel;
s_clknet_out.rxpllclksel <= p_clkin_in.rxpllclksel;

gen_ref_clks : for i in 0 to g_num_gth_ref_clks -1 generate

    i_gth_refclk_local: ibufds_gte3
     generic map
     (
         refclk_en_tx_path=>'0',
         refclk_hrow_ck_sel=>"01",
         refclk_icntl_rx=>"00"
     )
     port map
     (
        ceb => '0',
        i  => p_clkin_in.gth_refclk_gbtx_local(i).p,
        ib => p_clkin_in.gth_refclk_gbtx_local(i).n,
        o => s_clknet_out.gth_refclk_local(i),
        odiv2 => s_gth_refclk_local_BUFG_GT_SYNC(i).clk
     );

end generate;
                            
            s_clknet_out.mb_fpga_reset_low.q0 <= s_mmcm_gbt40_mb_q0.locked_out and (not p_cfgbus_interface_in.db_reg_rx(cfb_strobe_reg)(c_mb0_reset_bit)) and s_clknet_out.locked_db and not s_reset_mb.q0;
            s_clknet_out.mb_fpga_reset_low.q1 <= s_mmcm_gbt40_mb_q1.locked_out and (not p_cfgbus_interface_in.db_reg_rx(cfb_strobe_reg)(c_mb1_reset_bit)) and s_clknet_out.locked_db and not s_reset_mb.q1;
            
            s_mmcm_gbt40_mb_q0.reset_in <= p_cfgbus_interface_in.db_reg_rx(cfb_strobe_reg)(c_clknet_reset_bit);

    
         
    s_clknet_out.refclk40 <= s_clknet_out.cfgbus_clk40; --s_clknet_out.gth_refclk40(0); --s_clknet_out.cfgbus_clk40;
    s_clknet_out.mmcm_refclk40 <= s_clknet_out.cfgbus_clk40;
--    s_clknet_out.gbt_cdc_counter <= p_clkin_in.gbt_encoder_interface.gbt_cdc_counter;
--    s_clknet_out.refclk80 <= s_clknet_out.gth_refclk80(0); --p_clkin_in.sfp_ku_mgt.tx_frameclk(0);--s_clknet_out.gth_refclk80(0); --s_clknet_out.gth_refclkdiv2_local(0);           
    s_clknet_out.gth_tx_frameclk <= p_clkin_in.sfp_ku_mgt.tx_frameclk;
    s_clknet_out.gth_tx_frameclk40 <= p_clkin_in.sfp_ku_mgt.tx_frameclk40;
    gen_gbt_wordclk240 : for i in 0 to c_gbt_bank_number_of_links-1 generate
        s_clknet_out.gth_tx_wordclk(i) <= p_clkin_in.db6_gbt_bank.mgt_txwordclk_o(i);
        i_pll_gbt_wordclk : pll_gbt_wordclk
           port map ( 
          -- Clock out ports  
           p_clk240_out => open,
          -- Status and control signals                
           p_locked_out => s_wordclk_locked(i),
           -- Clock in ports
           p_clk_in => p_clkin_in.db6_gbt_bank.mgt_txwordclk_o(i)
         );
    end generate;
        
--    s_clknet_out.gth_tx_frameclk40(0) <= s_clknet_out.mmcm_refclk40;
--    s_clknet_out.gth_tx_frameclk40(1) <= s_clknet_out.mmcm_refclk40;
--    i_mmcm_gth_refclk : mmcm_gth_refclk
--       port map ( 
--      -- Clock out ports  
--       p_clk80_out => s_clknet_out.refclk80, 
--      -- Status and control signals                
--       reset => s_gth_refclk_local_BUFG_GT_SYNC(0).CLR,
--       p_locked_out => open,
--       -- Clock in ports
--       clk_in1 => s_clknet_out.gth_refclk80(0)
--     );
--        s_clknet_out.mmcm_refclk240<=s_clknet_out.gth_tx_wordclk(0);
--        i_mmcm_gtg_refclk : mmcm_gtg_refclk
--            port map ( 
--            -- Clock out ports
----            p_clk40_out => open, --s_clknet_out.mmcm_refclk40, --open, ----s_clknet_out.cfgbus_clk40, --s_clknet_out.clk80,  
--            p_clk80_out => open, --s_clknet_out.mmcm_refclk80, --s_clknet_out.clk80,
--            p_clk240_out => open, --s_clknet_out.mmcm_refclk240,
----            p_clk160_out => s_clknet_out.mmcm_refclk160,
--            -- Status and control signals                
--            reset => s_mmcm_gtg_refclk.reset_in,
--            p_locked_out => s_mmcm_gtg_refclk.locked_out,
--            -- Clock in ports
--            clk_in1 => s_clknet_out.cfgbus_clk40_local
--        );
        
        s_mmcm_gtg_refclk.reset_in <= p_cfgbus_interface_in.db_reg_rx(cfb_strobe_reg)(c_clknet_reset_bit);
         
        s_clknet_out.cfgbus_clk40 <= s_clknet_out.cfgbus_clk40_local;
        s_clknet_out.locked_db <= s_mmcm_gtg_refclk.locked_out;-- and not s_cdc_reset_out;
        s_clknet_out.db_side <= p_clkin_in.db_side;
        


    proc_cdc_reset : process(s_clknet_out.cfgbus_clk40)
    begin
        if rising_edge(s_clknet_out.cfgbus_clk40) then
            s_cdc_reset_in <= (p_master_reset_in) or (not s_mmcm_gtg_refclk.locked_out) or (not s_clkin_in.sfp_ku_mgt.gtwiz_reset_tx_done_out(0)) or (s_reset_clknet_from_vio);
        end if;
    end process;

    gen_reset_sync_links : for i in 0 to g_num_gth_links-1 generate
    
        i_db6_reset_synchronizer : entity tilecal.db6_reset_synchronizer
        generic map(
               g_clk_steps => 6 
        )
        Port map ( p_clk_in => s_clknet_out.gth_tx_wordclk(i),--s_clknet_out.mmcm_refclk240,
                   p_reset_in => s_cdc_reset_in,
                   p_reset_out => s_cdc_reset_array_out(i));


        proc_cdc_gen : process(s_clknet_out.gth_tx_wordclk(i), s_cdc_reset_array_out(i))--p_clknet_in.gth_tx_frameclk(g_ch_number))
        begin
            if (s_cdc_reset_array_out(i) = '1') then
                s_clknet_out.gbt_cdc_counter_array(i) <= 0;
                s_clknet_out.gbt_cdc_phase_array(i) <= '0';
                s_sm_data_sync_array(i) <= st_syncying;
            elsif rising_edge(s_clknet_out.gth_tx_wordclk(i)) then--p_clknet_in.gth_tx_frameclk(g_ch_number)) then

                case s_clknet_out.gbt_cdc_counter_array(i) is
                    when 0 =>
                        s_clknet_out.gbt_cdc_counter_array(i)<= 1; --s_clknet_out.gbt_cdc_counter+1;
                        s_bcr_array(i)<=p_clkin_in.bcr.bcr;--p_clkin_in.gbt_encoder_interface.gbt_tx_data_out.lg(88);
                        s_bcr_buffer_array(i)<=s_bcr_array(i);
                        case s_sm_data_sync_array(i) is
                            when st_syncying =>
                                s_clknet_out.gbt_cdc_phase_array(i) <= not s_clknet_out.gbt_cdc_phase_array(i);
                                if (s_bcr_array(i) = '1') and (s_clknet_out.bcr.bcr_locked = '1') then
                                    s_sm_data_sync_array(i) <= st_wait;
                                end if;
                            when st_wait =>
                                if (s_bcr_array(i) = '1') and (s_bcr_buffer_array(i) ='0') then
--                                if (  p_clkin_in.bcr.bcr = '1') and (s_bcr_array(i) ='0') then
                                    s_clknet_out.gbt_cdc_phase_array(i) <= '1';
                                    s_sm_data_sync_array(i) <= st_synced;
                                else
                                    s_clknet_out.gbt_cdc_phase_array(i) <= not s_clknet_out.gbt_cdc_phase_array(i);
                                end if;
                            when st_synced =>
                                s_clknet_out.gbt_cdc_phase_array(i) <= not s_clknet_out.gbt_cdc_phase_array(i);
                                if (s_clknet_out.bcr.bcr_locked = '0') then
                                    s_sm_data_sync_array(i) <= st_syncying;
                                end if;
                            when others =>
                                s_sm_data_sync_array(i) <= st_syncying;
                        end case;
                    when 1 =>
                        s_clknet_out.gbt_cdc_counter_array(i)<= 2;--s_clknet_out.gbt_cdc_counter+1;
                    when 2 =>
                        s_clknet_out.gbt_cdc_counter_array(i)<=0;
                    when others =>
                        s_clknet_out.gbt_cdc_counter_array(i)<=0;
                end case;
            end if;
        end process;
     
    end generate;

    s_clknet_out.gbt_cdc_counter<= s_clknet_out.gbt_cdc_counter_array(0);
    s_clknet_out.gbt_cdc_phase<=s_clknet_out.gbt_cdc_phase_array(0);
    s_cdc_reset_out <= s_cdc_reset_array_out(0) and s_cdc_reset_array_out(1);
 
        
    
    s_mmcm_gtg_refclk.locked_out<=s_wordclk_locked(0) and s_wordclk_locked(1);--s_mmcm_cis_interface.locked_out;
--    i_mmcm_cis_interface : mmcm_cis_interface
--       port map ( 
--      -- Clock out ports  
----       p_clk640_out => s_clknet_out.mmcm_refclk640,
--       p_clk320_out => s_clknet_out.mmcm_refclk320,
--      -- Status and control signals                
--       p_locked_out => s_mmcm_cis_interface.locked_out,
--       -- Clock in ports
--       p_clk40_in => s_clknet_out.cfgbus_clk40_local
--     );
--    s_mmcm_gtg_refclk.locked_out<=s_clknet_out.locked_tp_q0;
--    s_clknet_out.mmcm_refclk320<=s_tp_clk40_q0_local;

--s_clknet_out.tp_clk40.q0<=s_tp_clk40_q0_local;
--s_clknet_out.tp_clk40.q1 <= s_tp_clk40_q1_local;

-- i_ibufds_tp_clk40_q0_local : ibufgds
-- generic map (
--    diff_term => true, -- differential termination
--    iostandard => "sub_lvds")
-- port map (
--    o => s_tp_clk320_q0_local,  -- clock buffer output
--    i => p_clkin_in.tp_q0_clkin_local.p,  -- diff_p clock buffer input (connect directly to top-level port)
--    ib => p_clkin_in.tp_q0_clkin_local.n -- diff_n clock buffer input (connect directly to top-level port)
-- );

s_clknet_out.cis_hss_clk80 <= p_clkin_in.cis_hss_clkin_local;

-- i_ibufds_tp_clk40_q1_local : ibufgds
-- generic map (
--    diff_term => true, -- differential termination
--    iostandard => "sub_lvds")
-- port map (
--    o => s_tp_clk40_q1_local,  -- clock buffer output
--    i => p_clkin_in.tp_q1_clkin_local.p,  -- diff_p clock buffer input (connect directly to top-level port)
--    ib => p_clkin_in.tp_q1_clkin_local.n -- diff_n clock buffer input (connect directly to top-level port)
-- );    

--i_pll_dskclk : pll_dskclk
--   port map ( 
--  -- Clock out ports  
--   p_clk320_out => s_clknet_out.mmcm_refclk320,
--  -- Status and control signals                
--   p_locked_out => s_clknet_out.locked_tp_q0,
--   -- Clock in ports
--   p_clk_in => s_tp_clk320_q0_local
-- );
----s_clknet_out.mmcm_refclk320 <= s_tp_clk320_q0_local;
--s_mmcm_cis_interface.locked_out<=s_clknet_out.locked_tp_q0;


--proc_cis_cdc_gen : process(s_clknet_out.mmcm_refclk320, s_cdc_reset_in)
--begin
--    if (s_cdc_reset_in = '1') then
--        s_clknet_out.cis_cdc_counter <= 0;
--        s_clknet_out.cis_cdc_phase <= '0';
--        s_sm_cis_sync <= st_syncying;
--    elsif rising_edge(s_clknet_out.mmcm_refclk320) then
            
--            case s_sm_cis_sync is
--                when st_syncying =>
--                    s_bcr_cis<=p_clkin_in.bcr.bcr;
--                    s_bcr_buffer_cis<=s_bcr_cis; 
--                    if (s_bcr_cis = '1') and (s_clknet_out.bcr.bcr_locked = '1') then
--                        s_clknet_out.cis_cdc_counter <= 0;
--                        s_clknet_out.cis_cdc_phase <= '0';
--                        s_sm_cis_sync <= st_wait;
--                    end if;
--                when st_wait =>
--                    s_bcr_cis<=p_clkin_in.bcr.bcr;
--                    s_bcr_buffer_cis<=s_bcr_cis; 
--                    if (s_bcr_cis = '1') and (s_bcr_buffer_cis ='0') then
--                        s_sm_cis_sync <= st_synced;
--                        s_clknet_out.cis_cdc_counter <= s_clknet_out.cis_cdc_counter+1;
--                    end if;
--                when st_synced =>
--                    if (s_clknet_out.bcr.bcr_locked = '1') then
                        
--                        case s_clknet_out.cis_cdc_counter is
--                            when 0 to 3 =>
--                                s_clknet_out.cis_cdc_counter <= s_clknet_out.cis_cdc_counter+1;
--                                s_clknet_out.cis_cdc_phase <= '1';
--                            when 4 to 6 =>
--                                s_clknet_out.cis_cdc_counter <= s_clknet_out.cis_cdc_counter+1;
--                                s_clknet_out.cis_cdc_phase <= '0';
--                            when 7 =>
--                                s_clknet_out.cis_cdc_counter <= 0;
--                                s_clknet_out.cis_cdc_phase <= '0';
--                            when others =>
--                                null;
--                        end case;
----                            if s_clknet_out.cis_cdc_counter<7 then--15 then
----                                s_clknet_out.cis_cdc_counter <= s_clknet_out.cis_cdc_counter+1;
----                            else
----                                s_clknet_out.cis_cdc_counter <= 0;
----                            end if;
                        
----                            s_clknet_out.cis_cdc_phase <= '1';                        
--                    else
--                        s_sm_cis_sync <= st_syncying;
--                    end if;

--                when others =>
--                    s_sm_cis_sync <= st_syncying;
--            end case;
--    end if;
--end process;

    
    
    
    
    
s_clknet_out.gbtx_rxready(0) <= p_clkin_in.gbtx_rxready(0);

s_clknet_out.md_number <= p_clkin_in.md_number;

s_clknet_out.gbtx_datavalid <= p_clkin_in.gbtx_datavalid;

s_clknet_out.osc_clk100 <= s_osc_clk100;

------------------------------------
-- MMCM IP component declarations --
------------------------------------
--https://www.xilinx.com/support/documentation/ip_documentation/clk_wiz/v6_0/pg065-clk-wiz.pdf
--https://www.xilinx.com/support/documentation/sw_manuals/xilinx2014_1/ug974-vivado-ultrascale-libraries.pdf

 i_ibufds_osc_clk : ibufds
 generic map (
    diff_term => true, -- differential termination
    iostandard => "sub_lvds")
 port map (
    o => s_osc_clk100,  -- clock buffer output
    i => p_clkin_in.osc_clkin.p,  -- diff_p clock buffer input (connect directly to top-level port)
    ib => p_clkin_in.osc_clkin.n -- diff_n clock buffer input (connect directly to top-level port)
 );


i_pll_osc_clk : pll_osc_clk
   port map ( 
  -- Clock out ports  
   p_clk40_out => s_clknet_out.osc_clk40,
   p_clk200_out => s_clknet_out.osc_clk200,
  -- Dynamic reconfiguration ports             
   p_daddr_in => s_pll_osc.daddr_in,
   p_dclk_in => s_osc_clk100,
   p_den_in => s_pll_osc.den_in,
   p_din_in => s_pll_osc.din_in,
   p_dout_out => s_pll_osc.dout_out,
   p_drdy_out => s_pll_osc.drdy_out,
   p_dwe_in => s_pll_osc.dwe_in,
  -- Status and control signals                
   p_reset_in => s_pll_osc.reset_in,
   p_locked_out => s_pll_osc.locked_out,
   -- Clock in ports
   p_clk_in => s_osc_clk100
 );

s_pll_osc.daddr_in <= (others =>'0');
s_pll_osc.den_in <= '0';
s_pll_osc.din_in <= (others =>'0');
s_pll_osc.dwe_in <= '0';
s_pll_osc.psclk_in <= '0';
s_pll_osc.psen_in <= '0';
s_pll_osc.psincdec_in <= '0';
s_pll_osc.reset_in <= '0';
s_pll_osc.cddcreq_in <= '0';
s_clknet_out.locked_osc <= s_pll_osc.locked_out;


 i_ibufds_cfgbus_local : ibufds
 generic map (
    diff_term => true, -- differential termination
    iostandard => "sub_lvds")
 port map (
    o => s_clknet_out.cfgbus_clk40_local,  -- clock buffer output
    i => p_clkin_in.cfgbus_clkin_local.p,  -- diff_p clock buffer input (connect directly to top-level port)
    ib => p_clkin_in.cfgbus_clkin_local.n -- diff_n clock buffer input (connect directly to top-level port)
 );


-- i_ibufds_mmcm_gbt40_mb_q0_local : ibufds
-- generic map (
--    diff_term => true, -- differential termination
--    iostandard => "sub_lvds")
-- port map (
--    o =>  s_clknet_out.mb_clk40_q0_local,  -- clock buffer output
--    i => p_clkin_in.mb_q0_clkin_local.p,  -- diff_p clock buffer input (connect directly to top-level port)
--    ib => p_clkin_in.mb_q0_clkin_local.n -- diff_n clock buffer input (connect directly to top-level port)
-- );


-- i_ibufds_mmcm_gbt40_mb_q1_local : ibufds
-- generic map (
--    diff_term => true, -- differential termination
--    iostandard => "sub_lvds")
-- port map (
--    o => s_clknet_out.mb_clk40_q1_local,  -- clock buffer output
--    i => p_clkin_in.mb_q1_clkin_local.p,  -- diff_p clock buffer input (connect directly to top-level port)
--    ib => p_clkin_in.mb_q1_clkin_local.n -- diff_n clock buffer input (connect directly to top-level port)
-- );


    s_mmcm_gbt40_mb_q0.locked_out <= '1';
    s_mmcm_gbt40_mb_q1.locked_out <= '1';
    s_clknet_out.locked_mb_q0 <= s_mmcm_gbt40_mb_q0.locked_out;
    s_clknet_out.locked_mb_q1 <= s_mmcm_gbt40_mb_q1.locked_out;





 
    gen_clk_generation : if g_slow_clk_generation = 1 generate 

        i_counter_binary_ms : counter_binary_32bit
          PORT MAP (
            CLK => s_counter_binary_ms.clk,
            CE => s_counter_binary_ms.ce,
            SCLR => s_counter_binary_ms.sclr,
            LOAD => s_counter_binary_ms.load,
            L => s_counter_binary_ms.l,
            Q => s_counter_binary_ms.q
          );
        
        s_counter_binary_ms.clk <= s_clknet_out.osc_clk40;
        s_counter_binary_ms.ce <= '1';
        s_counter_binary_ms.load <= '0';
        s_counter_binary_ms.l <= (others=> '0');
        

        proc_clk_100hz : process(s_clknet_out.osc_clk40)
        begin
            if rising_edge(s_clknet_out.osc_clk40) then
            
                if s_counter_binary_ms.q = x"000030D40" then -- x"2625A00" then -- x"1312D00" then --"00000001001100010010110100000000" then
                    s_counter_binary_ms.sclr <= '1';
                    --s_clknet_out.clk_1hz <= not s_clknet_out.clk_1hz; -- x"2625A00"
                    s_clknet_out.clk_100hz <= not s_clknet_out.clk_100hz;
                else        
                    s_counter_binary_ms.sclr <= '0';
                end if;
            
            end if;
        end process;
        
        i_counter_binary_s : counter_binary_32bit
          PORT MAP (
            CLK => s_counter_binary_s.clk,
            CE => s_counter_binary_s.ce,
            SCLR => s_counter_binary_s.sclr,
            LOAD => s_counter_binary_s.load,
            L => s_counter_binary_s.l,
            Q => s_counter_binary_s.q
          );
        
        s_counter_binary_s.clk <= s_clknet_out.osc_clk40;
        s_counter_binary_s.ce <= '1';
        s_counter_binary_s.load <= '0';
        s_counter_binary_s.l <= (others=> '0');
        
        proc_clk_khz : process(s_clknet_out.osc_clk40)
        begin
            if rising_edge(s_clknet_out.osc_clk40) then
            
                if s_counter_binary_s.q = x"1312D00" then
                    s_clknet_out.clk_1hz <= not s_clknet_out.clk_1hz; -- x"2625A00"
                    s_counter_binary_s.sclr <= '1';
                    s_running_time_s<=std_logic_vector(unsigned(s_running_time_s)+1);
--                    s_clknet_out.clk_1khz <= not s_clknet_out.clk_1khz;
                else        
                    s_counter_binary_s.sclr <= '0';
                end if;
            
            end if;
        end process;
        

    end generate;

--leds
p_leds_out(3) <= p_clkin_in.bcr.bcr_locked;
p_leds_out(2) <= p_clkin_in.sfp_ku_mgt.qpll1lock_out(0);
p_leds_out(1) <= s_mmcm_gbt40_db6.locked_out;--s_mmcm_gbt40_mb_q0.locked_out;
p_leds_out(0) <= s_mmcm_gbt40_mb_q1.locked_out and s_mmcm_gbt40_mb_q1.locked_out;


i_db6_ku_dna : entity tilecal.db6_ku_dna  
    port map(            
        p_clk_in => s_clknet_out.osc_clk40,
        p_reset_in => s_dna_reset or p_master_reset_in,  
        p_done_out => s_dna_done_out,
        p_dna_value_out => s_dna_read_out
    );                

s_clknet_out.ku_dna<=s_dna_read_out;


gen_vio_clknet_status : if g_vio_clknet_status = 1 generate

--proc_clock_cross_domain : process(s_clknet_out.osc_clk100)
--begin
--    if rising_edge(s_clknet_out.osc_clk100) then
        s_clkin_in <= p_clkin_in;
--    end if;
--end process;

    i_vio_clknet_status : vio_clknet_status
      PORT MAP (
        clk => s_clknet_out.osc_clk40,
        probe_in0(0) => s_clkin_in.bcr.bcr_locked,
        probe_in1(0) => s_clknet_out.locked_db, -- '0', --p_clkin_in.bcr.bcr_local,--p_clkin_in.clksel,
        probe_in2 => s_clkin_in.qpllclksel,
        probe_in3(0) => s_clkin_in.bcr.bcr_tmr_error,-- p_clkin_in.cpllclksel,
        probe_in3(1) => s_clkin_in.bcr.bcr_locked_tmr_error,
        probe_in3(2) => s_clkin_in.bcr.count_tmr_error,
        probe_in4 => s_clkin_in.txsysclksel,
        probe_in5 => s_clkin_in.rxsysclksel,
        --probe_in5(1) => p_cfgbus_interface_in.tmr_error_remote,
        probe_in6 => s_clkin_in.rxoutclksel,
        probe_in7 => s_clkin_in.txoutclksel,
        probe_in8(0) => s_mmcm_gbt40_db6.locked_out,
        probe_in9(0) => s_clknet_out.clk_1hz,--s_clknet_out.clk_1hz,-- s_mmcm_gbt40_cfgbus.locked_out,
        probe_in10(0) => s_clkin_in.mb_interface.mb_driver.mb_tx_collission_out.q0,-- s_mmcm_gbt40_mb_q0.locked_out,
        probe_in11(0) => s_clkin_in.mb_interface.mb_driver.mb_tx_collission_out.q1,--s_mmcm_gbt40_mb_q1.locked_out,
        probe_in12(0) => s_gth_refclk_local_BUFG_GT_SYNC(0).CE,
        probe_in12(1) => s_gth_refclk_local_BUFG_GT_SYNC(0).CLR,
        probe_in13 => s_clkin_in.db6_gbt_bank.tx_phcomputed_o(0)&s_clkin_in.db6_gbt_bank.tx_phcomputed_o(1)&s_clkin_in.db6_gbt_bank.tx_phaligned_o(0)&s_clkin_in.db6_gbt_bank.tx_phaligned_o(1), --"0000",-- p_clkin_in.db6_gbt_bank.tx_phcomputed_o(0)&p_clkin_in.db6_gbt_bank.tx_phcomputed_o(1)&p_clkin_in.db6_gbt_bank.tx_phaligned_o(0)&p_clkin_in.db6_gbt_bank.tx_phaligned_o(1), --p_clkin_in.sfp_ku_mgt.leds_out,--p_clkin_in.sfp_ku_mgt.leds_out,
        probe_in14(0) => s_clknet_out.mb_fpga_reset_low.q0 and s_clknet_out.mb_fpga_reset_low.q1,
        probe_in15(0) => s_clkin_in.gbtx_rxready(0),
        probe_in16(0) => s_clknet_out.locked_tp_q0, --"0",
        probe_in17 => "0",
        probe_in18(0) => s_clknet_out.gth_wordclk_sel,--s_clkin_in.sfp_ku_mgt.gtwiz_reset_rx_done_out,
        probe_in19 =>"0",
        probe_in20 => "0",
        probe_in21(0) => s_clknet_out.gbt_cdc_gearbox_phase(0) or p_cfgbus_interface_in.db_reg_rx(cfb_db_debug)(c_db_debug_gbt_cdc_phase_array),--"00",
        probe_in21(1) => s_clknet_out.gbt_cdc_gearbox_phase(1) or p_cfgbus_interface_in.db_reg_rx(cfb_db_debug)(c_db_debug_gbt_cdc_phase_array+1),
        probe_in22(0) => s_clkin_in.sfp_ku_mgt.qpll1refclklost_out(0),
        probe_in22(1) => s_clkin_in.sfp_ku_mgt.gtwiz_reset_tx_done_out(0),
        probe_in22(2) => s_clkin_in.sfp_ku_mgt.qpll1fbclklost_out(0),
        probe_in22(3) => s_clkin_in.sfp_ku_mgt.qpll1refclklost_out(0),
        probe_in22(4) => s_clkin_in.sfp_ku_mgt.gtwiz_buffbypass_tx_done_out(0),
        probe_in22(5) => s_clkin_in.sfp_ku_mgt.gtwiz_buffbypass_tx_error_out(0),
        probe_in22(6) => s_clkin_in.sfp_ku_mgt.qpll1lock_out(0) and s_clkin_in.sfp_ku_mgt.qpll1lock_out(1),
        probe_in22(7) => s_clkin_in.sfp_ku_mgt.qpll1fbclklost_out(0),
        probe_in22(8) => s_clkin_in.sfp_ku_mgt.gtwiz_buffbypass_tx_start_user_in(0),
        probe_in22(9) => s_clkin_in.sfp_ku_mgt.gtwiz_reset_tx_done_out(0),
        probe_in22(10) => s_clkin_in.sfp_ku_mgt.gtwiz_reset_rx_cdr_stable_out(0),
        probe_in23(31 downto 30) => p_clkin_in.sfp_interface.mod_abs,--"0",
        probe_in23(29 downto 28) => p_clkin_in.sfp_interface.mod_los,--"0",
        probe_in23(27 downto 26) => p_clkin_in.sfp_interface.tx_fault,--"0",
        probe_in23(25 downto 0) => (others=>'0'),--"0",
        
        probe_in24(0) => p_clkin_in.mb_interface.adc_readout_control.adc_config_done,--s_clkin_in.sfp_ku_mgt.gtwiz_reset_rx_done_out,
        probe_in25 => s_clkin_in.db_leds,
        probe_in26(0) => s_clkin_in.db_side(0),--p_clkin_in.sfp_ku_mgt.cplllock_out(0),
        probe_in27 => "0",
        probe_in28(0) => s_clkin_in.db6_sem_interface.sem_interface.cap_gnt,--s_clkin_in.sfp_ku_mgt.gtwiz_reset_rx_cdr_stable_out,        
        probe_in29(0) => s_clkin_in.db6_sem_interface.sem_interface.cap_rel,--s_clkin_in.sfp_ku_mgt.gtwiz_buffbypass_rx_done_out,
        probe_in30(0) => s_clkin_in.db6_sem_interface.sem_interface.cap_req,--s_clkin_in.sfp_ku_mgt.gtwiz_buffbypass_rx_error_out,
        probe_in31(11 downto 6) => s_clkin_in.mb_interface.adc_readout.channel_pedestal_test_overflow,
        probe_in31(5 downto 0) => s_clkin_in.mb_interface.adc_readout.channel_pedestal_test_underflow,
        probe_in32(47 downto 40) => s_clkin_in.gbtx_interface.blk_mem_gbtx_regs.dina,--(others => '0'),
        probe_in32(39 downto 31) => s_clkin_in.gbtx_interface.blk_mem_gbtx_regs.addra,
        probe_in32(30) => s_clkin_in.gbtx_interface.busy,
        probe_in32(29 downto 21) => s_clkin_in.gbtx_interface.gbtx_control.gbtx_reg_address(8 downto 0),
        probe_in32(20) => s_clkin_in.gbtx_interface.gbtx_control.gbtx_trigger_i2c_operation,
        probe_in32(19 downto 12) => s_clkin_in.gbtx_interface.gbtx_control.gbtx_reg_value,
        probe_in32(11) => s_clkin_in.gbtx_interface.gbtx_control.gbtx_i2c_read_write_operation,
        probe_in32(10 downto 3) => s_clkin_in.gbtx_interface.blk_mem_gbtx_regs.douta,
        probe_in32(2) => s_clkin_in.gbtx_interface.gbtx_control.gbtx_default_config,
        probe_in32(1 downto 0) => (others => '0'),
        probe_in33(5 downto 0) => s_clkin_in.mb_interface.adc_readout.channel_clk280_locked,
        probe_in33(11 downto 6) => s_clkin_in.mb_interface.adc_readout.channel_missed_locked,
        probe_in33(17 downto 12) => s_clkin_in.mb_interface.adc_readout.channel_locked,
        probe_in33(23) => s_clkin_in.mb_interface.adc_readout.channel_missed_bit_count(5),
        probe_in33(22) => s_clkin_in.mb_interface.adc_readout.channel_missed_bit_count(4),
        probe_in33(21) => s_clkin_in.mb_interface.adc_readout.channel_missed_bit_count(3),
        probe_in33(20) => s_clkin_in.mb_interface.adc_readout.channel_missed_bit_count(2),
        probe_in33(19) => s_clkin_in.mb_interface.adc_readout.channel_missed_bit_count(1),
        probe_in33(18) => s_clkin_in.mb_interface.adc_readout.channel_missed_bit_count(0),
        probe_in34 => s_clkin_in.mb_interface.adc_readout.tmr_error_lg,
        probe_in35 => s_clkin_in.mb_interface.adc_readout.tmr_error_hg,
        probe_in36 => s_clkin_in.mb_interface.adc_readout.tmr_error_fc,
        probe_in37 => '0' & s_running_time_s(31 downto 1), --(others => '0'), -- p_cfgbus_interface_in.tmr_error_local(15 downto 0),
        probe_in38(18) => s_clkin_in.mb_interface.mb_integrator.end_of_read_quadrant.q0,
        probe_in38(17) => s_clkin_in.mb_interface.mb_integrator.end_of_read_quadrant.q1,
        probe_in38(16) => s_clkin_in.mb_interface.mb_integrator.end_of_read,
        probe_in38(15 downto 0) => s_clkin_in.mb_interface.mb_integrator.bc_count_readout,
--        probe_in38(7 downto 6) => s_clkin_in.gbt_encoder_interface.data_phase_sync,
--        probe_in38(5 downto 4) => s_clkin_in.gbt_encoder_interface.data_phase,
--        probe_in38(3 downto 0) => s_clkin_in.db_leds, --"0000",
        probe_in39 => s_clkin_in.db6_gbt_bank.gbt_bank_sync,
        probe_in40 => s_clkin_in.md_number,
        probe_in41 => p_cfgbus_interface_in.db_reg_rx(to_integer(unsigned(p_cfgbus_interface_in.db_reg_rx(cfb_loopback)(3 downto 0)))),       

        probe_in42(0) => s_clkin_in.db6_sem_interface.sem_interface.status_heartbeat,
        probe_in43(0) => s_clkin_in.db6_sem_interface.sem_interface.status_initialization,
        probe_in44(0) => s_clkin_in.db6_sem_interface.sem_interface.status_observation,
        probe_in45(0) => s_clkin_in.db6_sem_interface.sem_interface.status_correction,
        probe_in46(0) => s_clkin_in.db6_sem_interface.sem_interface.status_classification,
        probe_in47(0) => s_clkin_in.db6_sem_interface.sem_interface.status_injection,
        probe_in48(0) => s_clkin_in.db6_sem_interface.sem_interface.status_essential,
        
        probe_in49(0) => s_clkin_in.db6_sem_interface.sem_interface.status_detect_only,
        probe_in50(0) => s_clkin_in.db6_sem_interface.sem_interface.command_busy,
        probe_in51(0) => s_clkin_in.db6_sem_interface.sem_interface.monitor_txfull,
        probe_in52(0) => s_clkin_in.db6_sem_interface.sem_interface.status_uncorrectable,
        probe_in53(0) => s_clkin_in.db6_sem_interface.sem_interface.status_diagnostic_scan,
        probe_in54(0) => s_clkin_in.db6_sem_interface.sem_interface.command_strobe,
        probe_in55 => s_clkin_in.db6_sem_interface.sem_interpreter.correctable_errors,
        probe_in56 => s_clkin_in.db6_sem_interface.sem_interpreter.uncorrectable_errors,
        probe_in57 => s_clkin_in.db6_sem_interface.sem_interface.command_code(39 downto 8),

        probe_in58 => GLOBAL_DATE,
        probe_in59 => GLOBAL_TIME,
        
        probe_in60 => s_dna_read_out,
        probe_in61(0) => s_dna_done_out,
        probe_in62 => s_wordclk_locked(1 downto 0),
        probe_in63 => s_cdc_reset_array_out(1 downto 0),
        
        probe_out0(0) => s_reset_mb.q0,
        probe_out0(1) => s_reset_mb.q1,
        probe_out0(2) => s_dna_reset,
        probe_out0(3) => s_reset_main_sm_from_vio,
        probe_out0(4) => s_reset_clknet_from_vio,
        probe_out0(5) => s_clknet_out.skip_main_sm,
        
        probe_out1(0) => s_clknet_out.force_gtx_i2c_config,
        probe_out2 => open,
        probe_out3 => s_gth_clksel_from_vio,
        probe_out4 => open,
        probe_out5 => open,
        probe_out6 => s_clknet_out.gbt_cdc_gearbox_phase,
        probe_out7 => open,
        
        probe_out8 => s_clknet_out.adc_readout_high_threshold,
        probe_out9 => s_clknet_out.adc_readout_low_threshold,
        probe_out10 => s_clknet_out.adc_readout_threshold_select_channel,
        
        probe_out11(25) => s_clknet_out.cis_enable,
        probe_out11(24) => s_clknet_out.cis_gain, 
        probe_out11(23 downto 12) => s_clknet_out.cis_bcid_charge,  
        probe_out11(11 downto 0) => s_clknet_out.cis_bcid_discharge
        
      );
end generate;


end RTL;