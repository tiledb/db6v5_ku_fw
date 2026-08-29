----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/25/2020 11:33:15 AM
-- Design Name: 
-- Module Name: db6_gbt_gth_interface - Behavioral
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

library gbt;
use gbt.all;
use gbt.gbt_bank_package.all;
use gbt.vendor_specific_gbt_bank_package.all;
library tilecal;
use tilecal.db6_design_package.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity db6_gbt_gth_interface is 
   generic (   
        g_num_gth_links                 : integer := 2;                             --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
        g_enable_simple_gbt_encoder     : integer := 0;                              -- 1-> enabled
        --g_link_clk                      : integer := 0                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
        g_enable_ila_gbt_encoder        : integer := 1;
        g_tmr_enabled                   : integer := 0;
-- hog
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
--        XML_VER : std_logic_vector(31 downto 0); -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        XML_SHA : std_logic_vector(31 downto 0) -- 32 bit (optional) IPbus xml git commit hash (SHA).

   );
  Port (
        p_clknet_in : in t_db_clknet;
        p_master_reset_in : in std_logic_vector(31 downto 0);
        p_db_reg_rx_in : in t_db_reg_rx;
        
        --ref_clks
        p_ku_mgt                         : out t_ku_mgt;

        -- db6_mgt now lives in db7_io_box (GT wizard IP + differential pads owned there).
        -- These plain-logic ports replace the direct db6_mgt instantiation this file used to own.
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
        p_db6_sem_interface_in  : in t_db6_sem_interface;
        p_cfgbus_interface_in : in t_cfgbus_interface;
        p_sfp_interface_in : in t_sfp_interface;

        -- sfp+ reg block ram port b readback; folded into s_ku_mgt.sfp_tx_register below
        -- so it rides along with the rest of the sfp/gth status bundle
        p_sfp_tx_register_in : in t_sfp_reg_data_array
  );
end db6_gbt_gth_interface;

architecture Behavioral of db6_gbt_gth_interface is
attribute IOB: string;
attribute keep: string;
attribute dont_touch: string;

signal s_ku_mgt                         : t_ku_mgt;
--gbt_bank
signal s_db6_gbt_bank : t_db6_gbt_bank;
type t_gbt_encoder_interface_array is array (0 to g_num_gth_links-1) of t_gbt_encoder_interface;
signal s_gbt_encoder_interface, s_gbt_encoder_interface_in : t_gbt_encoder_interface_array;
signal s_gbt_encoder_interface_buffer : t_gbt_encoder_interface;
signal s_reset_gbt_bank, s_reset_gth : std_logic;

signal s_gth_txwordclk80_out, s_gth_txwordclk40_out, s_gth_rxwordclk40_out, s_gth_txoutclkfabric_out, s_gth_rxoutclkfabric_out : std_logic_vector(1 to g_num_gth_links);

begin

p_gbt_encoder_interface_out<=s_gbt_encoder_interface_buffer; --s_gbt_encoder_interface(0);
p_gbt_bank_out <= s_db6_gbt_bank;

gen_simple_gbt_encoder : if g_enable_simple_gbt_encoder = 1 generate
i_db6_gbt_encoder : entity tilecal.db6_gbt_encoder --tilecal.db6_gbt_encoder_test
    generic map (
        g_tmr_enabled => g_tmr_enabled,
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
--        XML_VER => XML_VER, -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        XML_SHA => XML_SHA -- 32 bit (optional) IPbus xml git commit hash (SHA).
    )
    port map (
        p_master_reset_in => p_master_reset_in(c_gbt_encoder_reset_bit),
        p_clknet_in => p_clknet_in,
        p_db_reg_rx_in => p_db_reg_rx_in,
        p_gbt_encoder_interface_out => s_gbt_encoder_interface(0),
        p_gbt_encoder_interface_in => s_gbt_encoder_interface_in(0),
        
        --interfaces
        p_mb_interface_in => p_mb_interface_in,
        p_sem_interface_in => p_sem_interface_in,
        p_tdo_remote_in => p_tdo_remote_in,
        p_system_management_interface_in => p_system_management_interface_in,
        p_gbtx_interface_in => p_gbtx_interface_in,
        p_serial_id_interface_in => p_serial_id_interface_in,
        p_sfp_ku_mgt_in => s_ku_mgt,
        p_db6_sem_interface_in => p_db6_sem_interface_in,
        p_cfgbus_interface_in => p_cfgbus_interface_in,
        p_sfp_interface_in => p_sfp_interface_in
    );
    gen_link_connections: for i in 0 to g_num_gth_links-1 generate
        s_db6_gbt_bank.tx_phase_i(i)<=s_gbt_encoder_interface(0).data_phase(0);
        s_db6_gbt_bank.gbt_cdc_counter_array_i(i)<=s_gbt_encoder_interface(0).gbt_cdc_counter;
        s_db6_gbt_bank.tx_phcomputed_o(i)<=s_gbt_encoder_interface(0).tx_phcomputed_o;
        s_db6_gbt_bank.tx_phaligned_o(i)<=s_gbt_encoder_interface(0).tx_phaligned_o;
    end generate;

        -- db6_mgt now instantiated once, in db7_io_box (s_ku_mgt <= p_ku_mgt_in relay
        -- is unconditional, below -- both link-count generate branches need it).
        -- This branch's per-link tx word mapping (preserved as-is: both links get the
        -- same encoder instance's word, matching the original whole-duplicate wiring):
        p_mgt_usrword_out(1) <= s_gbt_encoder_interface(0).mgt_txword;
        p_mgt_usrword_out(2) <= s_gbt_encoder_interface(0).mgt_txword;

end generate;



-- SFP/GBTx differential rx/tx pads and the db6_mgt instance that consumes them
-- now live in db7_io_box; s_mgt_diff_pair_rx/tx removed accordingly.

s_db6_gbt_bank.mgt_clk_i(0) <= p_clknet_in.gth_refclk_local(0);
s_db6_gbt_bank.mgt_clk_i(1) <= p_clknet_in.gth_refclk_local(1);

-- db6_mgt now lives in db7_io_box; s_ku_mgt is its p_ku_mgt_out relayed back in, with
-- sfp_tx_register overlaid on top (db6_mgt/the GT wizard knows nothing about it -- a
-- whole-record concurrent copy plus a separate concurrent field assignment would put
-- two drivers on those bits, so the override is done sequentially in one process,
-- same pattern as db7_io_box's mgt devspec_i overlay).
proc_ku_mgt_relay : process(p_ku_mgt_in, p_sfp_tx_register_in)
    variable v_ku_mgt : t_ku_mgt;
begin
    v_ku_mgt := p_ku_mgt_in;
    v_ku_mgt.sfp_tx_register := p_sfp_tx_register_in;
    s_ku_mgt <= v_ku_mgt;
end process;
p_ku_mgt <= s_ku_mgt;


s_reset_gbt_bank <= not s_ku_mgt.gtwiz_reset_tx_done_out(0);
s_reset_gth <= '0';


gen_multiple_gbt_encoder : if g_enable_simple_gbt_encoder = 0 generate
    -- db6_mgt now instantiated once, in db7_io_box (see gen_simple_gbt_encoder above
    -- for the shared s_ku_mgt <= p_ku_mgt_in relay). This branch's per-link tx word
    -- mapping (preserved as-is: link i+1 <= encoder instance i, independent per link):
    p_mgt_usrword_out(1) <= s_gbt_encoder_interface(0).mgt_txword;
    p_mgt_usrword_out(2) <= s_gbt_encoder_interface(1).mgt_txword;

    gen_link_connections: for i in 0 to g_num_gth_links-1 generate
        i_db6_gbt_encoder : entity tilecal.db6_gbt_encoder--tilecal.db6_gbt_encoder_test
          generic map (
                g_ch_number => i,
                g_tmr_enabled => g_tmr_enabled,
                g_num_gth_links=>g_num_gth_links,
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
--                XML_VER => XML_VER, -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--                XML_SHA => XML_SHA -- 32 bit (optional) IPbus xml git commit hash (SHA).
                
          )
          port map (
                p_master_reset_in => p_master_reset_in(c_gbt_encoder_reset_bit),
                p_clknet_in => p_clknet_in,
                p_db_reg_rx_in => p_db_reg_rx_in,
                p_gbt_encoder_interface_out => s_gbt_encoder_interface(i),
                p_gbt_encoder_interface_in => s_gbt_encoder_interface_in(i),
                
                --interfaces
                p_mb_interface_in => p_mb_interface_in,
                p_sem_interface_in => p_sem_interface_in,
                p_tdo_remote_in => p_tdo_remote_in,
                p_system_management_interface_in => p_system_management_interface_in,
                p_gbtx_interface_in => p_gbtx_interface_in,
                p_serial_id_interface_in => p_serial_id_interface_in,
                p_sfp_ku_mgt_in => s_ku_mgt,
                p_db6_sem_interface_in => p_db6_sem_interface_in,
                p_cfgbus_interface_in => p_cfgbus_interface_in,
                p_sfp_interface_in => p_sfp_interface_in
        
                );
        
        s_db6_gbt_bank.tx_phase_i(i)<=s_gbt_encoder_interface(i).data_phase(0);
        s_db6_gbt_bank.tx_phcomputed_o(i)<=s_gbt_encoder_interface(i).tx_phcomputed_o;
        s_db6_gbt_bank.tx_phaligned_o(i)<=s_gbt_encoder_interface(i).tx_phaligned_o;
        s_db6_gbt_bank.gbt_cdc_counter_array_i(i)<=s_gbt_encoder_interface(i).gbt_cdc_counter;


    end generate;       
end generate;





gen_link_connections: for i in 0 to g_num_gth_links-1 generate

    s_db6_gbt_bank.gbt_txclken_i(i) <= '1';
    s_db6_gbt_bank.gbt_rxclken_i(i) <= '1';
    s_gbt_encoder_interface_in(i).gbt_txclken_i <= '1';

    s_db6_gbt_bank.mgt_txreset_i(i) <= s_reset_gth or p_master_reset_in(c_gth_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_ch0_reset_bit+i);-- or s_reset_gth; -- or not p_clknet_in.locked_db; --'0';
    s_db6_gbt_bank.mgt_rxreset_i(i) <= s_reset_gth or p_master_reset_in(c_gth_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_ch0_reset_bit+i);-- or s_reset_gth; -- or not p_clknet_in.locked_db; --'0';
    s_db6_gbt_bank.gbt_txreset_i(i) <= p_master_reset_in(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_ch0_reset_bit+i) or s_reset_gbt_bank; -- or not p_clknet_in.locked_db; --'0';
    s_db6_gbt_bank.gbt_rxreset_i(i) <= p_master_reset_in(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_ch0_reset_bit+i) or s_reset_gbt_bank; -- or not p_clknet_in.locked_db; --'0';
 
    s_gbt_encoder_interface_in(i).gbt_txreset_i <= p_master_reset_in(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_reset_bit) or p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_ch0_reset_bit+i) or s_reset_gbt_bank; -- or not p_clknet_in.locked_db; --'0';
    s_gbt_encoder_interface_in(i).tx_encoding_sel_i <= '0'; -- 0-> wide bus
    s_gbt_encoder_interface_in(i).gbt_isdataflag_i <= '0';
    
    s_db6_gbt_bank.mgt_devspecific_i.drp_clk(i+1) <= p_clknet_in.osc_clk200;--p_clknet_in.cfgbus_clk40;
    s_db6_gbt_bank.mgt_devspecific_i.reset_freeRunningClock(1) <= p_clknet_in.osc_clk200;--p_clknet_in.cfgbus_clk40;
    -- rx_p/rx_n/tx_p/tx_n (the actual differential pads) are now set/read inside
    -- db7_io_box, which owns the db6_mgt instance and the SFP/GBTx pad ports.

    s_db6_gbt_bank.gbt_txframeclk_i(i)<= s_db6_gbt_bank.mgt_txwordclk_o(i); -- p_clknet_in.mmcm_refclk240; --p_clknet_in.mmcm_refclk80; --p_clknet_in.gth_tx_frameclk(i); --p_clknet_in.refclk80; --p_clknet_in.clk80;--p_clknet_in.gth_txwordclk80_out(i);
    s_db6_gbt_bank.gbt_rxframeclk_i(i)<=p_clknet_in.mmcm_refclk40;--p_clknet_in.gth_rxwordclk40_out(i);
    
    --gth configuration
    s_db6_gbt_bank.mgt_devspecific_i.conf_diffCtrl(i+1) <= "1000";
    s_db6_gbt_bank.mgt_devspecific_i.conf_preCursor(i+1) <= "10000";
    s_db6_gbt_bank.mgt_devspecific_i.conf_postCursor(i+1) <= "10000";

    s_db6_gbt_bank.mgt_devspecific_i.conf_txPol(i+1) <= '0';
    s_db6_gbt_bank.mgt_devspecific_i.conf_rxPol(i+1) <= '0';

end generate;

-- db7_io_box crossing: whole-vector/whole-record assignments, matching exactly what
-- used to be direct port-map associations to the local db6_mgt instance (same
-- leftmost-to-leftmost positional semantics between the "downto" t_db6_gbt_bank
-- fields and the "to"-indexed db6_mgt ports -- preserved as-is, not reordered).
p_mgt_txreset_out       <= s_db6_gbt_bank.mgt_txreset_i;
p_mgt_rxreset_out       <= s_db6_gbt_bank.mgt_rxreset_i;
p_mgt_autorsten_out     <= s_db6_gbt_bank.mgt_rstonbitslipen_i;
p_mgt_autorstoneven_out <= s_db6_gbt_bank.mgt_rstoneven_i;
p_mgt_devspec_i_out     <= s_db6_gbt_bank.mgt_devspecific_i;

s_db6_gbt_bank.mgt_txready_o      <= p_mgt_txready_in;
s_db6_gbt_bank.mgt_rxready_o      <= p_mgt_rxready_in;
s_db6_gbt_bank.mgt_headerlocked_o <= p_mgt_headerlocked_in;
s_db6_gbt_bank.mgt_rstcnt_o       <= p_mgt_rstcnt_in;
s_db6_gbt_bank.mgt_txwordclk_o    <= p_mgt_txusrclk_in;
s_db6_gbt_bank.mgt_rxwordclk_o    <= p_mgt_rxusrclk_in;
s_db6_gbt_bank.mgt_devspecific_o  <= p_mgt_devspec_o_in;

    
    
end Behavioral;


