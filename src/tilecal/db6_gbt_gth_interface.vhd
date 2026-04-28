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
--        p_gth_refclk_gbtx_local_in    : in   t_diff_pair;
--        p_gth_refclk_gbtx_remote_in    : in   t_diff_pair;
--        p_gth_txwordclk80_out            : out std_logic_vector(g_num_gth_links-1 downto 0);
--        p_gth_txwordclk40_out            : out std_logic_vector(g_num_gth_links-1 downto 0);
--        p_gth_rxwordclk40_out            : out std_logic_vector(g_num_gth_links-1 downto 0);
--        p_gth_txoutclkfabric_out         : out std_logic_vector(g_num_gth_links-1 downto 0);
--        p_gth_rxoutclkfabric_out         : out std_logic_vector(g_num_gth_links-1 downto 0);
        p_ku_mgt                         : out t_ku_mgt;
    

      
        --sfp/gth
--        p_tx_sfp_out         : out  t_mgt_diff_pair;
--        p_rx_sfp_in         : in  t_mgt_diff_pair;
        p_tx_sfp_out  : out t_diff_pair_vector(1 downto 0);
        p_rx_sfp_in  : in t_diff_pair_vector(0 downto 0);
        
        --p_tx_gbtx_to_fpga_out : out t_diff_pair_vector(0 downto 0);
        p_rx_gbtx_from_fpga_in  : in t_diff_pair_vector(0 downto 0);
        --p_rx_gbtx_tx_in  : in t_diff_pair_vector(0 downto 0);
            
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
        p_sfp_interface_in : in t_sfp_interface
  );
end db6_gbt_gth_interface;

architecture Behavioral of db6_gbt_gth_interface is
attribute IOB: string;
attribute keep: string;
attribute dont_touch: string;

signal s_ku_mgt                         : t_ku_mgt;
--gbt_bank
signal s_mgt_diff_pair_rx, s_mgt_diff_pair_tx : t_mgt_diff_pair;
signal s_db6_gbt_bank : t_db6_gbt_bank;
--signal s_gbt_tx_data_out : std_logic_vector(115 downto 0);
type t_gbt_encoder_interface_array is array (0 to g_num_gth_links-1) of t_gbt_encoder_interface;
signal s_gbt_encoder_interface, s_gbt_encoder_interface_in : t_gbt_encoder_interface_array;
signal s_gbt_encoder_interface_buffer : t_gbt_encoder_interface;
signal s_reset_gbt_bank, s_reset_gth : std_logic;

--attribute keep of s_db6_gbt_bank, s_gbt_encoder_interface : signal is "true";
--attribute dont_touch of s_db6_gbt_bank, s_gbt_encoder_interface : signal is "true";

signal s_gth_txwordclk80_out, s_gth_txwordclk40_out, s_gth_rxwordclk40_out, s_gth_txoutclkfabric_out, s_gth_rxoutclkfabric_out : std_logic_vector(1 to g_num_gth_links);


--  COMPONENT ila_timing

--PORT (
--	clk : IN STD_LOGIC;



--	probe0 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
--	probe1 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
--	probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--	probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--);
--END COMPONENT  ;


begin

--  i_ila_timing_0 : ila_timing
--PORT MAP (
--	clk => p_clknet_in.gth_tx_wordclk(0),



--	probe0 => std_logic_vector(to_unsigned(p_clknet_in.gbt_cdc_counter_array(0),2)), 
--	probe1 => std_logic_vector(to_unsigned(p_clknet_in.gbt_cdc_counter_array(1),2)),
--	probe2(0) => p_clknet_in.gbt_cdc_phase_array(0),
--	probe3(0) => p_clknet_in.gbt_cdc_phase_array(1)
--);

--  i_ila_timing_1 : ila_timing
--PORT MAP (
--	clk => p_clknet_in.gth_tx_wordclk(1),



--	probe0 => std_logic_vector(to_unsigned(p_clknet_in.gbt_cdc_counter_array(0),2)), 
--	probe1 => std_logic_vector(to_unsigned(p_clknet_in.gbt_cdc_counter_array(1),2)),
--	probe2(0) => p_clknet_in.gbt_cdc_phase_array(0),
--	probe3(0) => p_clknet_in.gbt_cdc_phase_array(1)
--);


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
        --p_gbt_tx_data_out => s_gbt_tx_data_out,
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
--        s_db6_gbt_bank.gbt_txdata_i(i+1)<= s_gbt_encoder_interface(0).gbt_tx_data_out.sync(83 downto 0);
--        s_db6_gbt_bank.wb_txdata_i(i+1)<=s_gbt_encoder_interface(0).gbt_tx_data_out.sync(115 downto 84);
        s_db6_gbt_bank.tx_phase_i(i)<=s_gbt_encoder_interface(0).data_phase(0);
        s_db6_gbt_bank.gbt_cdc_counter_array_i(i)<=s_gbt_encoder_interface(0).gbt_cdc_counter;
        s_db6_gbt_bank.tx_phcomputed_o(i)<=s_gbt_encoder_interface(0).tx_phcomputed_o;
        s_db6_gbt_bank.tx_phaligned_o(i)<=s_gbt_encoder_interface(0).tx_phaligned_o;
    end generate;

--        proc_check_gbt_banck_sync: process(p_clknet_in.mmcm_refclk240)
--        begin
--            if rising_edge(p_clknet_in.mmcm_refclk240) then
--                if (p_clknet_in.gbt_cdc_counter = 2) and (p_clknet_in.gbt_cdc_phase = '1') then
--                    s_db6_gbt_bank.gbt_bank_sync <= std_logic_vector(to_unsigned(s_gbt_encoder_interface(0).gbt_cdc_counter,3));
--                end if;
--            end if;
--        end process;
    
        i_db6_mgt : entity tilecal.db6_mgt
            generic map (
                num_links                    => g_num_gth_links
            )
            port map (
                --========--
                -- db6 --
                --========--   
                p_clknet_in => p_clknet_in,
                p_ku_mgt_out => s_ku_mgt,
                p_db_reg_rx_in => p_db_reg_rx_in,
                
                --========--
                -- clocks --
                --========--   
                        
                mgt_refclk_i(1)                 => s_db6_gbt_bank.mgt_clk_i(0),
                mgt_refclk_i(2)                 => s_db6_gbt_bank.mgt_clk_i(1),
                mgt_txusrclk_o(1)            => s_db6_gbt_bank.mgt_txwordclk_o(0),  --! tx wordclock from the transceiver (could be used to clock the core with clocking enable)
                mgt_txusrclk_o(2)            => s_db6_gbt_bank.mgt_txwordclk_o(1),            
                mgt_rxusrclk_o(1)            => s_db6_gbt_bank.mgt_rxwordclk_o(0),  --! tx wordclock from the transceiver (could be used to clock the core with clocking enable)
                mgt_rxusrclk_o(2)            => s_db6_gbt_bank.mgt_rxwordclk_o(1),            
                
                --=============--
                -- resets      --
                --=============--
                mgt_txreset_i                => s_db6_gbt_bank.mgt_txreset_i,
                mgt_rxreset_i                => s_db6_gbt_bank.mgt_rxreset_i,
                
                --=============--
                -- status      --
                --=============--
                mgt_txready_o                => s_db6_gbt_bank.mgt_txready_o,
                mgt_rxready_o                => s_db6_gbt_bank.mgt_rxready_o,
    
                rx_headerlocked_o            => s_db6_gbt_bank.mgt_headerlocked_o,
                rx_headerflag_o              => open,--mgt_headerflag_s,
                mgt_rstcnt_o                 => s_db6_gbt_bank.mgt_rstcnt_o,
                    
                --==============--
                -- control      --
                --==============--				
                mgt_autorsten_i              => s_db6_gbt_bank.mgt_rstonbitslipen_i,
                mgt_autorstoneven_i          => s_db6_gbt_bank.mgt_rstoneven_i,
              
                --==============--
                -- data         --
                --==============--
                mgt_usrword_i(1)                => s_gbt_encoder_interface(0).mgt_txword,
                mgt_usrword_i(2)                => s_gbt_encoder_interface(0).mgt_txword,
                mgt_usrword_o                => open,
                
                --=============================--
                -- device specific connections --
                --=============================--
                mgt_devspec_i                => s_db6_gbt_bank.mgt_devspecific_i,
                mgt_devspec_o                => s_db6_gbt_bank.mgt_devspecific_o
            );
        
    
--        proc_check_db_gbt_encoder_sync : process(p_clknet_in.mmcm_refclk240, p_master_reset_in(c_gbt_encoder_reset_bit))
--        begin
--            if p_master_reset_in(c_gbt_encoder_reset_bit) = '1' then
            
--            elsif rising_edge(p_clknet_in.mmcm_refclk240) then
--                if (p_clknet_in.gbt_cdc_counter = 2) and (p_clknet_in.gbt_cdc_phase = '1') then
--                    s_gbt_encoder_interface_buffer.data_phase_sync<=s_gbt_encoder_interface(0).data_phase_sync;
--                    s_gbt_encoder_interface_buffer.data_phase<=s_gbt_encoder_interface(0).data_phase;
--                    s_gbt_encoder_interface_buffer.gbt_cdc_counter<= s_gbt_encoder_interface(0).gbt_cdc_counter;
--                end if;
--            end if;
--        end process;

    
end generate;



s_mgt_diff_pair_rx(0) <= p_rx_sfp_in(0);
s_mgt_diff_pair_rx(1) <= p_rx_gbtx_from_fpga_in(0);
--s_mgt_diff_pair_rx(2) <= p_rx_gbtx_tx_in(0);

p_tx_sfp_out(0) <= s_mgt_diff_pair_tx(0);
p_tx_sfp_out(1) <= s_mgt_diff_pair_tx(1);
--p_tx_gbtx_to_fpga_out(0) <= s_mgt_diff_pair_tx(2);

s_db6_gbt_bank.mgt_clk_i(0) <= p_clknet_in.gth_refclk_local(0);
s_db6_gbt_bank.mgt_clk_i(1) <= p_clknet_in.gth_refclk_local(1);

p_ku_mgt <= s_ku_mgt;


--proc_gbt_phase_align: process(p_clknet_in.mmcm_refclk40)
--begin
--    if rising_edge(p_clknet_in.mmcm_refclk40) then
--        if p_master_reset_in(c_clknet_reset_bit) = '1' or p_clknet_in.locked_db = '0' then
--            s_reset_gbt_bank <= not s_ku_mgt.gtwiz_reset_tx_done_out(0);
--            s_reset_gth <= not s_ku_mgt.gtwiz_reset_tx_done_out(0);
--        else
            s_reset_gbt_bank <= not s_ku_mgt.gtwiz_reset_tx_done_out(0);
            s_reset_gth <= '0';
--        end if;
--    end if;
--end process;


gen_multiple_gbt_encoder : if g_enable_simple_gbt_encoder = 0 generate
    i_db6_mgt : entity tilecal.db6_mgt
        generic map (
            num_links                    => g_num_gth_links
        )
        port map (
            --========--
            -- db6 --
            --========--   
            p_clknet_in => p_clknet_in,
            p_ku_mgt_out => s_ku_mgt,
            p_db_reg_rx_in => p_db_reg_rx_in,
            
            --========--
            -- clocks --
            --========--   
                    
            mgt_refclk_i(1)                 => s_db6_gbt_bank.mgt_clk_i(0),
            mgt_refclk_i(2)                 => s_db6_gbt_bank.mgt_clk_i(1),
            mgt_txusrclk_o(1)            => s_db6_gbt_bank.mgt_txwordclk_o(0),  --! tx wordclock from the transceiver (could be used to clock the core with clocking enable)
            mgt_txusrclk_o(2)            => s_db6_gbt_bank.mgt_txwordclk_o(1),            
            mgt_rxusrclk_o(1)            => s_db6_gbt_bank.mgt_rxwordclk_o(0),  --! tx wordclock from the transceiver (could be used to clock the core with clocking enable)
            mgt_rxusrclk_o(2)            => s_db6_gbt_bank.mgt_rxwordclk_o(1),            
            
            --=============--
            -- resets      --
            --=============--
            mgt_txreset_i                => s_db6_gbt_bank.mgt_txreset_i,
            mgt_rxreset_i                => s_db6_gbt_bank.mgt_rxreset_i,
            
            --=============--
            -- status      --
            --=============--
            mgt_txready_o                => s_db6_gbt_bank.mgt_txready_o,
            mgt_rxready_o                => s_db6_gbt_bank.mgt_rxready_o,
    
            rx_headerlocked_o            => s_db6_gbt_bank.mgt_headerlocked_o,
            rx_headerflag_o              => open,--mgt_headerflag_s,
            mgt_rstcnt_o                 => s_db6_gbt_bank.mgt_rstcnt_o,
                
            --==============--
            -- control      --
            --==============--				
            mgt_autorsten_i              => s_db6_gbt_bank.mgt_rstonbitslipen_i,
            mgt_autorstoneven_i          => s_db6_gbt_bank.mgt_rstoneven_i,
          
            --==============--
            -- data         --
            --==============--
            mgt_usrword_i(1)                => s_gbt_encoder_interface(0).mgt_txword,
            mgt_usrword_i(2)                => s_gbt_encoder_interface(1).mgt_txword,
            mgt_usrword_o                => open,
            
            --=============================--
            -- device specific connections --
            --=============================--
            mgt_devspec_i                => s_db6_gbt_bank.mgt_devspecific_i,
            mgt_devspec_o                => s_db6_gbt_bank.mgt_devspecific_o
        );

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
                --p_gbt_tx_data_out => s_gbt_tx_data_out,
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
    s_db6_gbt_bank.mgt_devspecific_i.rx_p(i+1) <= s_mgt_diff_pair_rx(i).p;
    s_db6_gbt_bank.mgt_devspecific_i.rx_n(i+1) <= s_mgt_diff_pair_rx(i).n;
    s_mgt_diff_pair_tx(i).p <= s_db6_gbt_bank.mgt_devspecific_o.tx_p(i+1);
    s_mgt_diff_pair_tx(i).n <= s_db6_gbt_bank.mgt_devspecific_o.tx_n(i+1);

    s_db6_gbt_bank.gbt_txframeclk_i(i)<= s_db6_gbt_bank.mgt_txwordclk_o(i); -- p_clknet_in.mmcm_refclk240; --p_clknet_in.mmcm_refclk80; --p_clknet_in.gth_tx_frameclk(i); --p_clknet_in.refclk80; --p_clknet_in.clk80;--p_clknet_in.gth_txwordclk80_out(i);
    s_db6_gbt_bank.gbt_rxframeclk_i(i)<=p_clknet_in.mmcm_refclk40;--p_clknet_in.gth_rxwordclk40_out(i);
    
    --gth configuration
--    s_db6_gbt_bank.mgt_devspecific_i.conf_diffCtrl(i+1) <= p_db_reg_rx_in(adv_cfg_gty_txdiffctrl)(3 downto 0); --   : gbt_devspec_reg4_A(1 to MAX_NUM_GBT_LINK);
--    s_db6_gbt_bank.mgt_devspecific_i.conf_preCursor(i+1) <= p_db_reg_rx_in(adv_cfg_gty_txprecursor)(4 downto 0); -- : gbt_devspec_reg5_A(1 to MAX_NUM_GBT_LINK);
--    s_db6_gbt_bank.mgt_devspecific_i.conf_postCursor(i+1) <= p_db_reg_rx_in(adv_cfg_gty_txpostcursor)(4 downto 0); -- : gbt_devspec_reg5_A(1 to MAX_NUM_GBT_LINK);
--    s_db6_gbt_bank.mgt_devspecific_i.conf_mainCursor(i+1) <= p_db_reg_rx_in(adv_cfg_gty_txmaincursor)(6 downto 0); -- : gbt_devspec_reg7_A(1 to MAX_NUM_GBT_LINK);
    s_db6_gbt_bank.mgt_devspecific_i.conf_diffCtrl(i+1) <= "1000";
    s_db6_gbt_bank.mgt_devspecific_i.conf_preCursor(i+1) <= "10000";
    s_db6_gbt_bank.mgt_devspecific_i.conf_postCursor(i+1) <= "10000"; 
--    s_db6_gbt_bank.mgt_devspecific_i.conf_mainCursor(i+1) <= "1000000";

    
    s_db6_gbt_bank.mgt_devspecific_i.conf_txPol(i+1) <= '0';
    s_db6_gbt_bank.mgt_devspecific_i.conf_rxPol(i+1) <= '0';
        
end generate;

    
    
end Behavioral;


