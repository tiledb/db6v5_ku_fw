----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/02/2020 12:55:38 PM
-- Design Name: 
-- Module Name: db6_sfp_interface - Behavioral
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
--library UNISIM;
--use UNISIM.VComponents.all;

library gbt;
use gbt.all;
use gbt.gbt_bank_package.all;
use gbt.vendor_specific_gbt_bank_package.all;
library tilecal;
use tilecal.db6_design_package.all;


entity db6_sfp_interface is

   generic (   
        g_num_gth_links                 : integer := 2;                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
-- hog
        GLOBAL_DATE : std_logic_vector(31 downto 0); -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME : std_logic_vector(31 downto 0) -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
        -- 2026-09-12: GLOBAL_VER/SHA, TOP_VER/SHA, CON_VER/SHA, HOG_VER/SHA (and the
        -- already-dead XML_VER/SHA) removed -- pass-through only, down to
        -- db6_gbt_gth_interface.vhd; see db6_gbt_encoder_sc.vhd's header for why.
   );

  Port (
        p_clknet_in : in t_db_clknet;
        p_master_reset_in : in std_logic_vector(31 downto 0);
        p_db_reg_rx_in : in t_db_reg_rx;
        
        --ref_clks
        p_ku_mgt                         : out t_ku_mgt;

        -- db6_mgt now lives in db7_io_box; plain-logic pass-through to/from
        -- db6_gbt_gth_interface (see that file's header for the port meanings).
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

        p_sfp_abs_in                : in std_logic_vector(1 downto 0);
        p_sfp_los_in                : in std_logic_vector(1 downto 0);
        p_sfp_tx_fault_in                : in std_logic_vector(1 downto 0);

        -- IOBUF moved to db7_io_box; split O/I/T instead of inout.
        p_sda_drive_out : out std_logic_vector(1 downto 0);
        p_sda_tri_out   : out std_logic_vector(1 downto 0);
        p_sda_read_in   : in  std_logic_vector(1 downto 0);
        p_scl_drive_out : out std_logic_vector(1 downto 0);
        p_scl_tri_out   : out std_logic_vector(1 downto 0);
        p_scl_read_in   : in  std_logic_vector(1 downto 0);
        p_sfp_control_in                       : in t_sfp_control;
        p_sfp_interface_out             : out t_sfp_interface;

        -- sfp+ reg block ram port b address, direct from a vio debug probe_out
        -- (ORed with cfb_sfp_reg_address below -- don't drive both non-zero at once)
        p_sfp_reg_address_vio_in : in t_sfp_reg_addr_array;

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
        p_db6_sem_interface_in : in t_db6_sem_interface;
        p_cfgbus_interface_in : in t_cfgbus_interface;
        
        --leds
        p_leds_out : out std_logic_vector(3 downto 0)
  );
end db6_sfp_interface;


architecture Behavioral of db6_sfp_interface is

signal s_gbt_encoder_interface : t_gbt_encoder_interface;
signal s_sfp_interface : t_sfp_interface;

-- sfp+ reg block ram port b readback: address is commanded by db_reg_rx
-- (cfb_sfp_reg_address), value is folded into t_ku_mgt (see db6_gbt_gth_interface).
signal s_sfp_rx_register : t_sfp_reg_addr_array;
signal s_sfp_tx_register : t_sfp_reg_data_array;

begin

s_sfp_rx_register(0) <= p_db_reg_rx_in(cfb_sfp_reg_address)(6 downto 0) or p_sfp_reg_address_vio_in(0);
s_sfp_rx_register(1) <= p_db_reg_rx_in(cfb_sfp_reg_address)(14 downto 8) or p_sfp_reg_address_vio_in(1);


i_db6_gbt_gth_interface : entity tilecal.db6_gbt_gth_interface
   generic map (
        g_num_gth_links                => g_num_gth_links,         --! num_links: number of links instantiated by the core (altera: up to 6, xilinx: up to 4)
        -- 2026-09-12: was relying on the entity's own default (0, gen_multiple_gbt_encoder
        -- -- two fully independent per-link encoder+CDC chains, one per GTH link's own
        -- independent, asynchronous gth_tx_wordclk). Switched on explicitly: the two
        -- links' word clocks are genuinely unrelated clock domains (each is that GTH
        -- channel's own TXOUTCLK), so two independently-resynchronized encoders can never
        -- fully guarantee bit-identical output at every instant -- a system requirement
        -- here (see db6_gbt_encoder_gearbox.vhd's 2026-09-12 CDC fix). gen_simple_gbt_encoder
        -- encodes once, in a single clock domain, and combinationally duplicates that one
        -- register's value to both links -- bit-identical by construction, no independent
        -- re-encoding, no double CDC risk.
        g_enable_simple_gbt_encoder    => 1,
    -- hog
        GLOBAL_DATE => GLOBAL_DATE, -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME => GLOBAL_TIME -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
        )
  port map(
        p_clknet_in => p_clknet_in,
        p_master_reset_in => p_master_reset_in,
        p_db_reg_rx_in => p_db_reg_rx_in,
        p_gbt_encoder_interface_out => p_gbt_encoder_interface_out,
        
        p_ku_mgt                     => p_ku_mgt,

        p_ku_mgt_in              => p_ku_mgt_in,
        p_mgt_txusrclk_in        => p_mgt_txusrclk_in,
        p_mgt_rxusrclk_in        => p_mgt_rxusrclk_in,
        p_mgt_txreset_out        => p_mgt_txreset_out,
        p_mgt_rxreset_out        => p_mgt_rxreset_out,
        p_mgt_txready_in         => p_mgt_txready_in,
        p_mgt_rxready_in         => p_mgt_rxready_in,
        p_mgt_headerlocked_in    => p_mgt_headerlocked_in,
        p_mgt_rstcnt_in          => p_mgt_rstcnt_in,
        p_mgt_autorsten_out      => p_mgt_autorsten_out,
        p_mgt_autorstoneven_out  => p_mgt_autorstoneven_out,
        p_mgt_usrword_out        => p_mgt_usrword_out,
        p_mgt_devspec_i_out      => p_mgt_devspec_i_out,
        p_mgt_devspec_o_in       => p_mgt_devspec_o_in,

        --tdo from remote fpga
        p_tdo_remote_in => p_tdo_remote_in,
        
        --interfaces
        p_gbt_bank_out => p_gbt_bank_out,
        p_mb_interface_in => p_mb_interface_in,
        p_sem_interface_in => p_sem_interface_in,
        p_system_management_interface_in => p_system_management_interface_in,
        p_gbtx_interface_in => p_gbtx_interface_in,
        p_serial_id_interface_in => p_serial_id_interface_in,
        p_db6_sem_interface_in => p_db6_sem_interface_in,
        p_cfgbus_interface_in => p_cfgbus_interface_in,
        p_sfp_interface_in => s_sfp_interface,

        p_sfp_tx_register_in => s_sfp_tx_register
  );



p_sfp_interface_out<= s_sfp_interface;

s_sfp_interface.tx_fault <=p_sfp_tx_fault_in;
s_sfp_interface.mod_abs <=p_sfp_los_in;
s_sfp_interface.mod_los <=p_sfp_los_in;



i_db6_sfp_i2c_control : entity tilecal.db6_sfp_i2c_control
  generic map (
    g_sys_clk_freq => 40_000_000,        --input clock speed from user logic in hz
    g_i2c_clk_freq => 100_000
    )
  port map (
    p_clk_in               => p_clknet_in.osc_clk40, --system clock
    p_reset_in             => p_master_reset_in(c_dbmaster_reset_bit),--'0', --asynchronous active-low reset
    
    p_sfp_abs_in           => p_sfp_abs_in,
    p_sfp_los_in           => p_sfp_los_in,
    p_sfp_tx_fault_in      => p_sfp_tx_fault_in,
    
    p_sda_drive_out => p_sda_drive_out,
    p_sda_tri_out   => p_sda_tri_out,
    p_sda_read_in   => p_sda_read_in,
    p_scl_drive_out => p_scl_drive_out,
    p_scl_tri_out   => p_scl_tri_out,
    p_scl_read_in   => p_scl_read_in,
    p_sfp_i2c_interface_out    => s_sfp_interface.i2c_interface,

    p_rx_register_in  => s_sfp_rx_register,
    p_tx_register_out => s_sfp_tx_register,

    p_sfp_ddm_out => s_sfp_interface.ddm,
    p_sfp_ddm_read_done_out => s_sfp_interface.ddm_read_done

    );

end Behavioral;
