

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

--library gbt;
--use gbt.all;
--use gbt.gbt_bank_package.all;
--use gbt.vendor_specific_gbt_bank_package.all;
library tilecal;
use tilecal.db6_design_package.all;

entity db6v5_top is
generic (
    g_priority_side : std_logic_vector(1 downto 0) := "01";                 --! side to priotitize
    g_num_gth_links                 : integer := c_gbt_bank_number_of_links;                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
    g_num_gth_ref_clks             : integer := c_number_of_gth_refclks;
    g_include_sem                   : integer :=1;
    g_include_debug_interface       : integer :=1;
    
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
    HOG_SHA : std_logic_vector(31 downto 0); -- 32 bit Hog submodule git commit hash (SHA).
    XML_VER : std_logic_vector(31 downto 0); -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
    XML_SHA : std_logic_vector(31 downto 0) -- 32 bit (optional) IPbus xml git commit hash (SHA).
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
      --p_gbt_cfgbus_clk40_remote_in : in   t_diff_pair;
--      p_gbt_mb_q0_clk40_local_in : in   t_diff_pair; 
--      p_gbt_mb_q1_clk40_local_in : in   t_diff_pair;
      --p_gbt_mb_q0_clk40_remote_in : in   t_diff_pair;
      --p_gbt_mb_q1_clk40_remote_in : in   t_diff_pair;
      p_gbt_tp_q0_clk40_local_in : in   t_diff_pair; 
      --p_gbt_tp_q1_clk40_local_in : in   t_diff_pair;
      --p_gbt_tp_q0_clk40_remote_in : in   t_diff_pair;
      --p_gbt_tp_q1_clk40_remote_in : in   t_diff_pair;

      
      -- leds
      p_leds_out :  out std_logic_vector(3 downto 0);
      
      --db_side
      p_db_side_in : in std_logic_vector(0 downto 0);
      
      --md_number
      p_md_number_in : in std_logic_vector(3 downto 0);
      
      --configbus
      p_cfgbus_data_local_in : in t_cfgbus_data_in;
--      p_cfgbus_data_remote_in : in t_cfgbus_data_in;

      --mgt
      --gth_refclk
      p_gth_refclk_gbtx_local_in    : in   t_diff_pair_vector((g_num_gth_ref_clks -1) downto 0);
      --p_gth_refclk_gbtx_remote_in    : in   t_diff_pair_vector((g_num_gth_ref_clks -1) downto 0);

      
      --sfp/gth
      p_tx_sfp_out  : out t_diff_pair_vector(1 downto 0);
      p_rx_sfp_in  : in t_diff_pair_vector(0 downto 0);
      
      --p_tx_gbtx_to_fpga_out : out t_diff_pair_vector(0 downto 0);
      p_rx_gbtx_from_fpga_in  : in t_diff_pair_vector(0 downto 0);
      --p_rx_gbtx_tx_in  : in t_diff_pair_vector(0 downto 0);

      
      --commbus mgt
--      p_commbus_gth_tx_out  : out t_diff_pair_vector(1 downto 0);
--      p_commbus_gth_rx_in  : in t_diff_pair_vector(1 downto 0);
--      p_commbus_gth_loopback_tx_out : out t_diff_pair_vector(0 downto 0);
--      p_commbus_gth_loopback_rx_in : in t_diff_pair_vector(0 downto 0);

      --sfp interface
      p_sfp_i2c_scl_inout 				: inout std_logic_vector(1 downto 0);
      p_sfp_i2c_sda_inout                 : inout std_logic_vector(1 downto 0);      
      p_sfp_abs_in                : in std_logic_vector(1 downto 0);
      p_sfp_los_in                : in std_logic_vector(1 downto 0);
      p_sfp_tx_fault_in                : in std_logic_vector(1 downto 0);

      
      --mb_interface
--      p_gbt_mb_q0_clk40_out: out   t_diff_pair;
--      p_gbt_mb_q1_clk40_out: out   t_diff_pair;
      
      p_adc_bitclk_in : in t_adc_clk_in;
      p_adc_frameclk_in : in t_adc_clk_in;
--      p_adc_gbtx_frameclk_in : in t_adc_clk_in;
      p_adc_lg_data_in : in t_adc_data_in;
      p_adc_hg_data_in : in t_adc_data_in;
     
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
	
	    p_tdo_remote_in	    : in    std_logic;		
	

---- cs interface
----      cs0_p                  : out std_logic;    
----      cs0_n                  : out std_logic;    
----      cs1_p                  : out std_logic;    
----      cs1_n                  : out std_logic;    
----      cs2_p                  : in std_logic;    
----      cs2_n                  : in std_logic;    
----      cs3_p                  : in std_logic;    
----      cs3_n                  : in std_logic;    
--    p_cs_nreq_p_out, p_cs_nreq_n_out : out std_logic;
--    p_cs_miso_p_out, p_cs_miso_n_out : out std_logic;
--    p_cs_mosi_p_in, p_cs_mosi_n_in : in  std_logic;
--    p_cs_sclk_p_in, p_cs_sclk_n_in : in  std_logic;


--      -- gbtx signals
      p_gbtx_rxready_in          : in std_logic_vector(0 downto 0); -- 0 local, 1 remote
      --p_gbtx_txready_in          : in std_logic_vector(1 downto 0); -- 0 local, 1 remote
      p_gbtx_datavalid_in        : in std_logic_vector(0 downto 0); -- 0 local, 1 remote
      p_gbtx_configsel_out       : out std_logic_vector(0 downto 0); -- 0 local, 1 remote
      p_gbtx_i2c_scl_inout 				: inout std_logic_vector(0 downto 0);
      p_gbtx_i2c_sda_inout                 : inout std_logic_vector(0 downto 0);
--      p_gbtx_i2c_rem_enable_out : out std_logic;
--      p_gbtx_loc_reset_inout          : inout std_logic;
--      p_gbtx_rem_reset_inout          : inout std_logic;
        

    
-- --serial id
--      p_serial_id_sda_inout : inout std_logic; 
--      p_serial_id_scl_inout : inout std_logic;
  
--  --mainboard jtag chain
--      p_mb_tms_out : out std_logic;
--      p_mb_tck_out : out std_logic;
--      p_mb_tdi_out : out std_logic;
--      p_mb_tdo_in : in std_logic;
      
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
    p_adc_channel_pedestal_test_underflow_out : out std_logic
    
--    p_cht8305c_sda_inout : inout std_logic;
--    p_cht8305c_scl_inout : inout std_logic
-- proasic interface
--        p_ku_hard_reset : out std_logic      
--  -- power good monitoring
--    p_pgood_in : in std_logic_vector (3 downto 0);
       
--  --fpga inter communication 
        --commbus ddr
--        p_commbus_ddr_tx_out  : out t_diff_pair;
--        p_commbus_ddr_loopback_tx_out  : out t_diff_pair;
--        p_commbus_ddr_clk_out  : out t_diff_pair;
--        p_commbus_ddr_rx_in  : in t_diff_pair;
--        p_commbus_ddr_loopback_rx_in  : in t_diff_pair;
--        p_commbus_ddr_clk_in  : in t_diff_pair

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
signal s_db6_sem_interface : t_db6_sem_interface;

signal s_gbtx_control : t_gbtx_control;

signal s_counter : integer range 0 to 31 :=0;
signal s_leds_out : std_logic_vector(3 downto 0):= (others=> '0');
signal s_skip_main_sm : std_logic;
attribute keep of s_sfp_interface, s_sfp_control, s_gbtx_interface, s_mb_interface, s_sem_interface, s_system_management_interface, s_gbtx_control, s_serial_id_interface : signal is "TRUE";
attribute dont_touch of s_sfp_interface, s_sfp_control, s_gbtx_interface, s_mb_interface, s_sem_interface, s_system_management_interface, s_gbtx_control, s_serial_id_interface : signal is "TRUE";


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

begin  -- rtl


--i_vio_hog : vio_hog
--  PORT MAP (
--    clk => s_clknet.osc_clk40,
--    probe_in0 => GLOBAL_DATE, -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
--    probe_in1 => GLOBAL_TIME, -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
--    probe_in2 => GLOBAL_VER,  -- 32 bit Last version Tag when the project was modified. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--    probe_in3 => GLOBAL_SHA,  -- 32 bit Git hash (SHA) of the last commit when the project was modified.
--    probe_in4 => TOP_VER,  -- 32 bit Git hash (SHA) of the last commit when the project was modified.
--    probe_in5 => TOP_SHA, -- 32 bit Top directory version, containing the hog.conf file and other files.
--    probe_in6 => CON_VER, -- 32 bit The version of the constraint files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--    probe_in7 => CON_SHA, -- 32 bit The git commit hash (SHA) of the constraint files.
--    probe_in8 => HOG_VER, -- 32 bit Hog submodule version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--    probe_in9 => HOG_SHA, -- 32 bit Hog submodule git commit hash (SHA).
--    probe_in10 => XML_VER, -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--    probe_in11 => XML_SHA, -- 32 bit (optional) IPbus xml git commit hash (SHA).
--    probe_in12 => (others=> '0'),
--    probe_in13 => (others=> '0'),
--    probe_in14 => (others=> '0'),
--    probe_in15 => (others=> '0')
--  );


--top connections
--p_gbt_mb_q0_clk40_out <= s_clknet.mb_clk40_q0_dp;
--p_gbt_mb_q1_clk40_out <= s_clknet.mb_clk40_q1_dp;

p_mb_fpga_reset_low.q0 <= s_clknet.mb_fpga_reset_low.q0 and (not s_master_reset(c_mb0_reset_bit)); --s_mb_interface.mb_reset.q0 and s_clknet.mb_fpga_reset_low.q0;
p_mb_fpga_reset_low.q1 <= s_clknet.mb_fpga_reset_low.q1 and (not s_master_reset(c_mb1_reset_bit)); --s_mb_interface.mb_reset.q1 and s_clknet.mb_fpga_reset_low.q1;

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
        --leds
        p_leds_out => s_leds(leds_clk_interface)
        
    );
        --mainboard interface
i_db6_mainboard_interface : entity tilecal.db6_mainboard_interface
      Port map(
        p_master_reset_in => s_master_reset,
        p_clknet_in  => s_clknet,
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,
        -- adc interface
        p_adc_bitclk_in => p_adc_bitclk_in,
        p_adc_frameclk_in => p_adc_frameclk_in,
--        p_adc_gbtx_frameclk_in => p_adc_gbtx_frameclk_in,
        p_adc_lg_data_in => p_adc_lg_data_in,
        p_adc_hg_data_in => p_adc_hg_data_in,
        -- mb interface
        p_ssel_out         => p_ssel_out,
        p_sclk_out         => p_sclk_out,
        p_sdata_out     => p_sdata_out,
        p_sdata_in    => p_sdata_in,
        --cis interface
        p_tph_out               => p_tph_out,
        p_tpl_out               => p_tpl_out,
        --integrator
        p_integrator_sda_inout.q0   => p_integrator_sda_inout.q0,
        p_integrator_sda_inout.q1   => p_integrator_sda_inout.q1,
        p_integrator_scl_inout.q0   => p_integrator_scl_inout.q0,
        p_integrator_scl_inout.q1   => p_integrator_scl_inout.q1,   
        
        p_mb_interface_out          => s_mb_interface,
        
        --leds
        p_leds_out => s_leds(leds_mb_interface)

    
  );

i_db6_sfp_interface : entity tilecal.db6_sfp_interface
   generic map (   
        g_num_gth_links                => g_num_gth_links,          --! num_links: number of links instantiated by the core (altera: up to 6, xilinx: up to 4)
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
        HOG_SHA => HOG_SHA, -- 32 bit Hog submodule git commit hash (SHA).
        XML_VER => XML_VER, -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        XML_SHA => XML_SHA -- 32 bit (optional) IPbus xml git commit hash (SHA).

        )
  port map(
        p_clknet_in => s_clknet,
        p_master_reset_in => s_master_reset,
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,
        p_gbt_encoder_interface_out => s_gbt_encoder_interface,
        
        --refclk inputs
        --p_gth_refclk_gbtx_local_in    => p_gth_refclk_gbtx_local_in,
        --p_gth_refclk_gbtx_remote_in    => p_gth_refclk_gbtx_remote_in,
--        p_gth_txwordclk80_out => s_clkin.gth_txwordclk80_in,
--        p_gth_rxwordclk40_out => s_clkin.gth_rxwordclk40_in,
--        p_gth_txoutclkfabric_out => s_clkin.gth_txoutclkfabric_out,
--        p_gth_rxoutclkfabric_out => s_clkin.gth_rxoutclkfabric_out,
        p_ku_mgt => s_sfp_ku_mgt,
        
        --sfp/gth
        p_tx_sfp_out  => p_tx_sfp_out,
        p_rx_sfp_in  => p_rx_sfp_in,
        p_sfp_abs_in => p_sfp_abs_in,
        p_sfp_los_in => p_sfp_los_in,
        p_sfp_tx_fault_in => p_sfp_tx_fault_in,
        
        --p_tx_gbtx_to_fpga_out => p_tx_gbtx_to_fpga_out,
        p_rx_gbtx_from_fpga_in => p_rx_gbtx_from_fpga_in,
        --p_rx_gbtx_tx_in => p_rx_gbtx_tx_in,
        --p_rx_gbtx_tx_in(0).p => '1',-- p_rx_gbtx_tx_in,
        --p_rx_gbtx_tx_in(0).n => '0',        
        p_sfp_i2c_scl_inout(0) => p_sfp_i2c_scl_inout(0),
        p_sfp_i2c_scl_inout(1) => p_sfp_i2c_scl_inout(1),
        p_sfp_i2c_sda_inout(0) => p_sfp_i2c_sda_inout(0),
        p_sfp_i2c_sda_inout(1) => p_sfp_i2c_sda_inout(1), 
        p_sfp_control_in => s_sfp_control,
        p_sfp_interface_out => s_sfp_interface,
        
        --tdo from remote fpga
        p_tdo_remote_in => p_tdo_remote_in,
        
        --interfaces
        p_gbt_bank_out => s_db6_gbt_bank,
        p_mb_interface_in => s_mb_interface,
        p_sem_interface_in => s_sem_interface,
        p_system_management_interface_in => s_system_management_interface,
        p_gbtx_interface_in => s_gbtx_interface,
        p_serial_id_interface_in => s_serial_id_interface, 
        p_db6_sem_interface_in => s_db6_sem_interface,
        p_cfgbus_interface_in => s_cfgbus_interface,
        --leds
        p_leds_out => s_leds(leds_sfp_interface)
  );


--inter xilinx fpga communication
--i_db6_commbus_interface : entity tilecal.db6_commbus_interface
--   generic map (   
--        g_num_gth_links                 => g_num_gth_links                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
--   )
--  port map ( 
--        p_clknet_in => s_clknet,
--        p_master_reset_in => s_master_reset,
--        p_db_reg_rx_in => s_db_reg_rx,
        
--        p_commbus_gth_tx_out  => p_commbus_gth_tx_out,
--        p_commbus_gth_rx_in  => p_commbus_gth_rx_in,
--        p_commbus_gth_loopback_tx_out => p_commbus_gth_loopback_tx_out,
--        p_commbus_gth_loopback_rx_in => p_commbus_gth_loopback_rx_in,

--        p_commbus_ddr_tx_out => p_commbus_ddr_tx_out,
--        p_commbus_ddr_loopback_tx_out => p_commbus_ddr_loopback_tx_out,
--        p_commbus_ddr_clk_out => p_commbus_ddr_clk_out,
--        p_commbus_ddr_rx_in => p_commbus_ddr_rx_in,
--        p_commbus_ddr_loopback_rx_in => p_commbus_ddr_loopback_rx_in,
--        p_commbus_ddr_clk_in => p_commbus_ddr_clk_in,
        
--        --tdo from remote fpga
--        p_tdo_remote_in => p_tdo_remote_in,
        
--        --interfaces
--        p_mb_interface_in => s_mb_interface,
--        p_sem_interface_in => s_sem_interface,
--        p_system_management_interface_in => s_system_management_interface,
--        p_gbtx_interface_in => s_gbtx_interface,
--        p_serial_id_interface_in => s_serial_id_interface
        
--      );



-- system manager (pgoods, temps, vccint... legacy xadc module)
i_db6_system_management_interface : entity tilecal.db6_system_management_interface
    port map ( 
        p_clknet_in => s_clknet,
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,
        p_master_reset_in => s_master_reset(c_master_reset_bit),
        
        --xadc pins to top level
        p_xadc_analog_in => p_xadc_analog_in,
        p_pgood_in => p_pgood_in, 
        
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
        
        p_cfgbus_data_local_in => p_cfgbus_data_local_in,
--        p_cfgbus_data_remote_in => p_cfgbus_data_remote_in, --(others => ('1','0')),--p_cfgbus_data_remote_in,
        --p_db_reg_rx_out => s_db_reg_rx,
        p_cfgbus_interface => s_cfgbus_interface,
        p_bcr_out => s_clkin.bcr,
        
        p_db_reg_rx_in => s_cfgbus_interface.db_reg_rx,
        p_gbt_encoder_interface_in => s_gbt_encoder_interface,
        
        
        
        p_gbtx_control_in => s_gbtx_control,
        p_gbtx_i2c_rem_enable_out => open, --p_gbtx_i2c_rem_enable_out,
        p_gbtx_interface_out => s_gbtx_interface,
        p_scl_inout(0) =>p_gbtx_i2c_scl_inout(0),
        p_sda_inout(0) =>p_gbtx_i2c_sda_inout(0),
        p_gbtx_configsel_out(0) => p_gbtx_configsel_out(0),
        
            
        p_leds_out => open
);

-- id serial interface
--i_db6_serial_id_interface : entity tilecal.db6_serial_id_interface
--  port map ( 
--        p_master_reset_in => s_master_reset,
--        p_clknet_in => s_clknet,
--        p_db_reg_rx_in => s_db_reg_rx,
        
--        p_scl_inout 	=> p_serial_id_scl_inout,
--        p_sda_inout    => p_serial_id_sda_inout,
        
--        p_serial_id_interface_out => s_serial_id_interface,
    
--        p_leds_out => open

--  );


---- clock selection signals, state machines and mux
---- https://www.xilinx.com/support/documentation/user_guides/ug576-ultrascale-gth-transceivers. (table 2-8)

--s_clkin.txsysclksel <= "11"; -- 00 = CPLL, 10 = QPLL0, 11 = QPLL1
--s_clkin.rxsysclksel <= "11"; -- 00 = CPLL, 10 = QPLL0, 11 = QPLL1

--s_clkin.txoutclksel <= "101"; -- 3'b000: Static 1, 3'b001: TXOUTCLKPCS path, 3'b010: TXOUTCLKPMA path, 3'b011: TXPLLREFCLK_DIV1 path, 3'b100: TXPLLREFCLK_DIV2 path, 3'b101: TXPROGDIVCLK
--s_clkin.rxoutclksel <= "101"; -- 3'b000: Static 1, 3'b001: TXOUTCLKPCS path, 3'b010: TXOUTCLKPMA path, 3'b011: TXPLLREFCLK_DIV1 path, 3'b100: TXPLLREFCLK_DIV2 path, 3'b101: TXPROGDIVCLK
 
--s_clkin.txpllclksel <="10"; -- 00 = CPLL, 10 = QPLL1, 11 = QPLL0
--s_clkin.rxpllclksel <="10"; -- 00 = CPLL, 10 = QPLL1, 11 = QPLL0

--s_clkin.clksel<= '0'; 
----s_clkin.cpllclksel <= "111"; --"111"; --"010"; -- 000: Reserved, 001: GTREFCLK0 selected, 010: GTREFCLK1 selected, 011: GTNORTHREFCLK0 selected, 100: GTNORTHREFCLK1 selected, 101: GTSOUTHREFCLK0 selected, 110: GTSOUTHREFCLK1 selected, 111: GTGREFCLK selected
----s_clkin.qpllclksel <= "111"; --"111"; --"010"; -- 000: Reserved, 001: GTREFCLK0 selected, 010: GTREFCLK1 selected, 011: GTNORTHREFCLK0 selected, 100: GTNORTHREFCLK1 selected, 101: GTSOUTHREFCLK0 selected, 110: GTSOUTHREFCLK1 selected, 111: GTGREFCLK selected
--s_clkin.qpllclksel <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);
--s_clkin.cpllclksel  <= s_cfgbus_interface.db_reg_rx(cfb_tx_control)(2 downto 0);

--proc_refclk_select: process(s_clknet.gbtx_rxready)
--begin
--    case s_clknet.gbtx_rxready is
--        when "10"=>
--            s_clkin.clksel <= '0';
--            s_clkin.cpllclksel <= "001";
--            s_clkin.qpllclksel <= "001";
--        when "01"=>
--            s_clkin.clksel<= '1';
--            s_clkin.cpllclksel <= "010";
--            s_clkin.qpllclksel <= "010";
--        when others=>
--            s_clkin.clksel<= '0';
--            s_clkin.cpllclksel <= "001";
--            s_clkin.qpllclksel <= "001";
--    end case;
--end process;

--leds 
--p_leds_out <= s_leds(to_integer(unsigned(s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0))));
--proc_leds_mux : process(s_clknet.osc_clk100)
--begin
--    if rising_edge(s_clknet.osc_clk100) then
--        if p_md_number_in = "1111" then
--            p_leds_out <= s_leds(to_integer(unsigned(s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0))));
--        else
--            p_leds_out <= p_md_number_in;--s_leds(to_integer(unsigned((p_md_number_in))));
--        end if;
--    end if;    
--end process;
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
            HOG_SHA => HOG_SHA, -- 32 bit Hog submodule git commit hash (SHA).
            XML_VER => XML_VER, -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
            XML_SHA => XML_SHA -- 32 bit (optional) IPbus xml git commit hash (SHA).
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






--i_db6_leds_interface : entity tilecal.db6_leds_interface
--  port map ( 
--            p_clknet_in                        =>  s_clknet,
--            p_db_reg_rx_in                     =>  s_cfgbus_interface.db_reg_rx,
--            p_leds_in                          => s_leds,
--            p_leds_out                         => p_leds_out
--  );




--proc_led_mux: process(s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0))
--begin
--    if s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0) <= "0000" then
--        s_leds_out<=std_logic_vector(to_unsigned(s_counter,4));
--        s_clkin.db_leds<=std_logic_vector(to_unsigned(s_counter,4));
--    else
--        s_leds_out<= s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0);
--        s_clkin.db_leds<=s_cfgbus_interface.db_reg_rx(cfb_db_debug)(3 downto 0);
--    end if;
--end process;

p_leds_out<=s_leds_out;


s_skip_main_sm <= ((s_clknet.skip_main_sm or s_cfgbus_interface.db_reg_rx(cfb_db_debug)(c_db_debug_skip_main_sm))); 
proc_startup_sm : process(s_clknet.clk_100hz,s_cfgbus_interface.db_reg_rx(cfb_strobe_reg)(c_dbmaster_reset_bit))
variable v_counter : integer range 0 to 65535 :=1;
--constant c_max_count : integer range 0 to 15 := 5;
begin
    if s_cfgbus_interface.db_reg_rx(cfb_strobe_reg)(c_dbmaster_reset_bit) = '1' then
        s_counter <= 0;
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
                v_counter:=0;
                s_counter <=s_counter+1;
                --s_counter <= 3;
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
                s_master_reset_async <= x"FFFFFFFF";
                s_gbtx_control.gbtx_default_config <= '1';
                s_gbtx_control.gbtx_trigger_i2c_operation <= '1';
                s_gbtx_control.gbtx_i2c_read_write_operation <= '0';
                
            when 2 =>
                v_counter:=0;
                s_master_reset_async <= x"FFFFFFFF";
                s_gbtx_control.gbtx_default_config <= '1';
                s_gbtx_control.gbtx_trigger_i2c_operation <= '0';
                s_gbtx_control.gbtx_i2c_read_write_operation <= '0';
                if (s_gbtx_interface.busy = '0') 
                    or (s_skip_main_sm = '1')
                then --and (s_clknet.gbtx_rxready(0) = '1') then        
                        s_counter <=s_counter+1;
                else
                    s_counter <=2;
                end if;
            when 3 =>
                v_counter:=0;
                s_counter <=s_counter+1;
                s_gbtx_control.gbtx_default_config <= '0';
                s_master_reset_async(c_dbmaster_reset_bit) <= '0';--x"FFFFFFF" & "1110";
            when 4 =>
                v_counter:=0;
                s_counter <=s_counter+1;
                s_master_reset_async(c_clknet_reset_bit) <= '0';
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
                    s_counter <=0;
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
                v_counter:=0;
                if v_counter<63 then
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
                v_counter:=0;
                s_counter <=s_counter+1;
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
                    s_counter <=0;
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
    

