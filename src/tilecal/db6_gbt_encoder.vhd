----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Eduardo Valdes Santurio
--           Fernando Carrio
--           Samuel Silverstein
--           Alberto Valero 
--
-- Create Date: 09/14/2020 02:22:15 AM
-- Design Name: 
-- Module Name: db6_gbt_encoder - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: this module assembles the gbt words to send to the gbt_wrapper
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

library tilecal;
use tilecal.db6_design_package.all;

--use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;

-- uncomment the following library declaration if instantiating
-- any xilinx primitives in this code.
library unisim;
use unisim.vcomponents.all;

library gbt;
use gbt.vendor_specific_gbt_bank_package.all;
use gbt.gbt_bank_package.all;

entity db6_gbt_encoder is
   generic (
        g_ch_number : integer := 0;
        g_num_gth_links                 : integer := 1;                            --! NUM_LINKS: number of links instantiated by the core (Altera: up to 6, Xilinx: up to 4)
        g_tmr_enabled                   : natural := 0;        -- 0 = no no_tmr, 1 = tmr
--        g_ila_encoder                   : integer := 0;
--        g_vio_gbt_encoder               : integer := 0
        g_enable_ila_gbt_encoder        : integer := 0;
        g_enable_ila_gbt_gearbox        : integer := 0;
        g_gbt_tx_encoding               : integer range 0 to 2 := wide_bus;
        
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
  port (
        p_master_reset_in : std_logic;
		p_clknet_in : in t_db_clknet;
        p_db_reg_rx_in : in t_db_reg_rx;
        p_gbt_encoder_interface_in         : in t_gbt_encoder_interface;
        p_gbt_encoder_interface_out         : out t_gbt_encoder_interface;

		--interfaces
		p_mb_interface_in : in t_mb_interface;
		p_sem_interface_in : in t_sem_interface;
		p_tdo_remote_in	            : in	std_logic;
		p_system_management_interface_in : in t_system_management_interface;
		p_gbtx_interface_in : in t_gbtx_interface;
		p_serial_id_interface_in : in t_serial_id_interface;
		p_sfp_ku_mgt_in                     : in t_ku_mgt;
		p_db6_sem_interface_in    : in t_db6_sem_interface;
		p_cfgbus_interface_in : in t_cfgbus_interface;
		p_sfp_interface_in : in t_sfp_interface
		);
		
end db6_gbt_encoder;

architecture behavioral of db6_gbt_encoder is

    COMPONENT vio_gbt_encoder
      PORT (
        clk : IN STD_LOGIC;
        probe_in0 : IN STD_LOGIC_VECTOR(115 DOWNTO 0);
        probe_in1 : IN STD_LOGIC_VECTOR(115 DOWNTO 0);
        probe_in2 : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        probe_in3 : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        probe_out0 : OUT STD_LOGIC_VECTOR(115 DOWNTO 0);
        probe_out1 : OUT STD_LOGIC_VECTOR(115 DOWNTO 0);
        probe_out2 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0) 
      );
    END COMPONENT;
    
    signal s_gbt_tx_data_from_vio : t_gbt_tx_data;
    signal s_gbt_encoder_interface_buffer, s_gbt_encoder_interface : t_gbt_encoder_interface;
    signal s_gbt_encoder_interface_tmr, s_gbt_encoder_interface_buffer_tmr : t_gbt_encoder_interface_tmr;

------- debug
signal s_gbt_encoder_interface_debug         : t_gbt_encoder_interface;
signal s_lg_crc, s_hg_crc, s_sync_crc : std_logic_vector(10 downto 0);
signal s_lg_crc_count, s_hg_crc_count, s_sync_crc_count : std_logic_vector(4 downto 0);
type t_adc_gbt_encoder_debug is array (0 to 5) of std_logic_vector(11 downto 0);
signal s_lg_adc, s_hg_adc, s_sync_adc : t_adc_gbt_encoder_debug;
signal s_lg_bcr, s_hg_bcr, s_sync_bcr, s_lg_tdo, s_hg_tdo, s_sync_tdo, s_lg_gain, s_hg_gain, s_sync_gain : std_logic;
signal s_lg_integrator, s_hg_integrator, s_sync_integrator : std_logic_vector(4 downto 0);
signal s_lg_sc, s_hg_sc, s_sync_sc : std_logic_vector(15 downto 0);
signal s_lg_switches, s_hg_switches, s_sync_switches : std_logic_vector(1 downto 0);
signal s_tmr_voter_lg, s_tmr_voter_hg, s_tmr_voter_sync : std_logic;
COMPONENT ila_gbt_encoder

PORT (
	clk : IN STD_LOGIC;

	probe0 : IN STD_LOGIC_VECTOR(10 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(10 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe8 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe9 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe10 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe11 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe12 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe13 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe14 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe15 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
	probe16 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe17 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe18 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe19 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe20 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe21 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe22 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
	probe23 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
	probe24 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe25 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe26 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
	probe27 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
	probe28 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
	probe29 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
	probe30 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe31 : IN STD_LOGIC_VECTOR(4 DOWNTO 0)
);
END COMPONENT  ;
    
    
begin
gen_tmr_disabled : if g_tmr_enabled = 0 generate
    p_gbt_encoder_interface_out<= s_gbt_encoder_interface;
    
    i_db6_gbt_encoder_formatter : entity tilecal.db6_gbt_encoder_formatter
      generic map(
        g_ch_number => g_ch_number,
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
            p_master_reset_in                 => p_master_reset_in,
            p_clknet_in                       => p_clknet_in,
            p_db_reg_rx_in                    => p_db_reg_rx_in,
            p_gbt_encoder_interface_out         => s_gbt_encoder_interface_buffer,
            
            --interfaces
            p_mb_interface_in                 => p_mb_interface_in,
            p_sem_interface_in                => p_sem_interface_in,
            p_tdo_remote_in                   => p_tdo_remote_in,
            p_system_management_interface_in  => p_system_management_interface_in,
            p_gbtx_interface_in               => p_gbtx_interface_in,
            p_serial_id_interface_in          => p_serial_id_interface_in,
            p_sfp_ku_mgt_in                   => p_sfp_ku_mgt_in,
            p_db6_sem_interface_in            => p_db6_sem_interface_in,
            p_cfgbus_interface_in             => p_cfgbus_interface_in,
            p_sfp_interface_in                => p_sfp_interface_in
            );
    
    i_db6_gbt_encoder_gearbox : entity tilecal.db6_gbt_encoder_gearbox
      generic map(
            g_ch_number => g_ch_number
      )
      port map (
            p_master_reset_in                 => p_master_reset_in,
            p_clknet_in                       => p_clknet_in,
            p_db_reg_rx_in                    => p_db_reg_rx_in,
            p_gbt_encoder_interface_out         => s_gbt_encoder_interface,
            p_gbt_encoder_interface_in         => s_gbt_encoder_interface_buffer,
            p_sfp_ku_mgt_in                   => p_sfp_ku_mgt_in
            );

    i_db6_gbt_txdatapath: entity tilecal.db6_gbt_tx        
        generic map (            
            tx_encoding                        => g_gbt_tx_encoding
        )
            port map (                
            tx_reset_i                         => p_gbt_encoder_interface_in.gbt_txreset_i,
            tx_frameclk_i                      => p_clknet_in.gth_tx_wordclk(g_ch_number),
            tx_clken_i                         => p_gbt_encoder_interface_in.gbt_txclken_i,
            
            tx_encoding_sel_i                  => p_gbt_encoder_interface_in.tx_encoding_sel_i,					 
            tx_isdata_sel_i                    => p_gbt_encoder_interface_in.gbt_isdataflag_i, 
            
            tx_data_i                          => s_gbt_encoder_interface.gbt_tx_data_out.sync(83 downto 0),
            tx_extra_data_widebus_i            => s_gbt_encoder_interface.gbt_tx_data_out.sync(115 downto 84),
            
            gbt_cdc_counter_i                  => s_gbt_encoder_interface.gbt_cdc_counter,
            tx_frame_o                         => s_gbt_encoder_interface.gbt_txencdata
        );                    

        i_db6_gbt_txgearbox: entity tilecal.db6_gbt_tx_gearbox    
          generic map (
            tx_optimization                        => g_gbt_tx_encoding
          )
          port map (
            tx_reset_i                             => p_gbt_encoder_interface_in.gbt_txreset_i,
            tx_frameclk_i                          => p_clknet_in.gth_tx_wordclk(g_ch_number),
            tx_clken_i                             => p_gbt_encoder_interface_in.gbt_txclken_i,
            tx_wordclk_i                           => p_clknet_in.gth_tx_wordclk(g_ch_number), --s_ku_mgt.tx_wordclk(i-1), --mgt_txwordclk_s(i),--p_clknet_in.clk240, --p_clknet_in.gth_txwordclk240(i+1),-- mgt_txwordclk_s(i),
             ---------------------------------------
            tx_phaligned_o                         => p_gbt_encoder_interface_out.tx_phaligned_o,
            tx_phcomputed_o                        => p_gbt_encoder_interface_out.tx_phcomputed_o,
                
            tx_frame_i                             => s_gbt_encoder_interface.gbt_txencdata,
            gbt_cdc_counter_i                      => s_gbt_encoder_interface.gbt_cdc_counter, --p_clknet_in.gbt_cdc_counter,--s_gbt_encoder_interface.gbt_cdc_counter,
            tx_word_o                              => s_gbt_encoder_interface.mgt_txword
      );
    
end generate;

gen_tmr_enabled : if g_tmr_enabled = 1 generate

    gen_tmr : for v_tmr in 0 to 2 generate

        i_db6_gbt_encoder_formatter : entity tilecal.db6_gbt_encoder_formatter
          generic map(
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
                p_master_reset_in                 => p_master_reset_in,
                p_clknet_in                       => p_clknet_in,
                p_db_reg_rx_in                    => p_db_reg_rx_in,
                p_gbt_encoder_interface_out         => s_gbt_encoder_interface_buffer_tmr(v_tmr),
                
                --interfaces
                p_mb_interface_in                 => p_mb_interface_in,
                p_sem_interface_in                => p_sem_interface_in,
                p_tdo_remote_in                   => p_tdo_remote_in,
                p_system_management_interface_in  => p_system_management_interface_in,
                p_gbtx_interface_in               => p_gbtx_interface_in,
                p_serial_id_interface_in          => p_serial_id_interface_in,
                p_sfp_ku_mgt_in                   => p_sfp_ku_mgt_in,
                p_db6_sem_interface_in            => p_db6_sem_interface_in,
                p_cfgbus_interface_in             => p_cfgbus_interface_in,
                p_sfp_interface_in                => p_sfp_interface_in
                );
        
        i_db6_gbt_encoder_gearbox : entity tilecal.db6_gbt_encoder_gearbox
          generic map(
                g_ch_number => g_ch_number
          )        
          port map (
                p_master_reset_in                 => p_master_reset_in,
                p_clknet_in                       => p_clknet_in,
                p_db_reg_rx_in                    => p_db_reg_rx_in,
                p_gbt_encoder_interface_out         => s_gbt_encoder_interface_tmr(v_tmr),
                p_gbt_encoder_interface_in         => s_gbt_encoder_interface_buffer_tmr(v_tmr),
                p_sfp_ku_mgt_in                   => p_sfp_ku_mgt_in
                );


        i_db6_gbt_txdatapath: entity tilecal.db6_gbt_tx        
            generic map (            
                tx_encoding                        => g_gbt_tx_encoding
            )
                port map (                
                tx_reset_i                         => p_gbt_encoder_interface_in.gbt_txreset_i,
                tx_frameclk_i                      => p_clknet_in.gth_tx_wordclk(g_ch_number),
                tx_clken_i                         => p_gbt_encoder_interface_in.gbt_txclken_i,
                
                tx_encoding_sel_i                  => p_gbt_encoder_interface_in.tx_encoding_sel_i,					 
                tx_isdata_sel_i                    => p_gbt_encoder_interface_in.gbt_isdataflag_i, 
                
                tx_data_i                          => s_gbt_encoder_interface_tmr(v_tmr).gbt_tx_data_out.sync(83 downto 0),
                tx_extra_data_widebus_i            => s_gbt_encoder_interface_tmr(v_tmr).gbt_tx_data_out.sync(115 downto 84),
                
                gbt_cdc_counter_i                  => p_clknet_in.gbt_cdc_counter,--s_gbt_encoder_interface_tmr(v_tmr).gbt_cdc_counter,
                tx_frame_o                         => s_gbt_encoder_interface_tmr(v_tmr).gbt_txencdata
            );                    
    
            i_db6_gbt_txgearbox: entity tilecal.db6_gbt_tx_gearbox    
              generic map (
                tx_optimization                        => g_gbt_tx_encoding
              )
              port map (
                tx_reset_i                             => p_gbt_encoder_interface_in.gbt_txreset_i,
                tx_frameclk_i                          => p_clknet_in.gth_tx_wordclk(g_ch_number),
                tx_clken_i                             => p_gbt_encoder_interface_in.gbt_txclken_i,
                tx_wordclk_i                           => p_clknet_in.gth_tx_wordclk(g_ch_number), --s_ku_mgt.tx_wordclk(i-1), --mgt_txwordclk_s(i),--p_clknet_in.clk240, --p_clknet_in.gth_txwordclk240(i+1),-- mgt_txwordclk_s(i),
                 ---------------------------------------
                tx_phaligned_o                         => s_gbt_encoder_interface_tmr(v_tmr).tx_phaligned_o,
                tx_phcomputed_o                        => s_gbt_encoder_interface_tmr(v_tmr).tx_phcomputed_o,
                    
                tx_frame_i                             => s_gbt_encoder_interface_tmr(v_tmr).gbt_txencdata,
                gbt_cdc_counter_i                      => p_clknet_in.gbt_cdc_counter,--s_gbt_encoder_interface_tmr(v_tmr).gbt_cdc_counter,
                tx_word_o                              => s_gbt_encoder_interface_tmr(v_tmr).mgt_txword
          );
    
    end generate;

    i_entity_db6_tmr_voter_mgt_txword : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 40
    )
    Port map (     
            p_std_logic_vector_0_in        => (s_gbt_encoder_interface_tmr(0).mgt_txword),
            p_std_logic_vector_1_in        => (s_gbt_encoder_interface_tmr(1).mgt_txword),
            p_std_logic_vector_2_in        => (s_gbt_encoder_interface_tmr(2).mgt_txword),
            p_tmr_error_out                => p_gbt_encoder_interface_out.tmr_error,--s_tmr_voter_sync, --open,
            p_std_logic_vector_out         => p_gbt_encoder_interface_out.mgt_txword   
            );


    i_entity_db6_tmr_voter_tx_phcomputed_o : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 1
    )
    Port map (     
            p_std_logic_vector_0_in(0)        => (s_gbt_encoder_interface_tmr(0).tx_phcomputed_o),
            p_std_logic_vector_1_in(0)        => (s_gbt_encoder_interface_tmr(1).tx_phcomputed_o),
            p_std_logic_vector_2_in(0)        => (s_gbt_encoder_interface_tmr(2).tx_phcomputed_o),
            p_tmr_error_out                => open,--p_gbt_encoder_interface_out.tmr_error,--s_tmr_voter_sync, --open,
            p_std_logic_vector_out(0)         => p_gbt_encoder_interface_out.tx_phcomputed_o   
            );    


    i_entity_db6_tmr_voter_tx_phaligned_o : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 1
    )
    Port map (     
            p_std_logic_vector_0_in(0)        => (s_gbt_encoder_interface_tmr(0).tx_phaligned_o),
            p_std_logic_vector_1_in(0)        => (s_gbt_encoder_interface_tmr(1).tx_phaligned_o),
            p_std_logic_vector_2_in(0)        => (s_gbt_encoder_interface_tmr(2).tx_phaligned_o),
            p_tmr_error_out                => open,--p_gbt_encoder_interface_out.tmr_error,--s_tmr_voter_sync, --open,
            p_std_logic_vector_out(0)         => p_gbt_encoder_interface_out.tx_phaligned_o   
            );    

    i_entity_db6_tmr_voter_data_phase : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 2
    )
    Port map (     
            p_std_logic_vector_0_in        => (s_gbt_encoder_interface_tmr(0).data_phase),
            p_std_logic_vector_1_in        => (s_gbt_encoder_interface_tmr(1).data_phase),
            p_std_logic_vector_2_in        => (s_gbt_encoder_interface_tmr(2).data_phase),
            p_tmr_error_out                => open,--p_gbt_encoder_interface_out.tmr_error,--s_tmr_voter_sync, --open,
            p_std_logic_vector_out         => p_gbt_encoder_interface_out.data_phase   
            ); 

    i_entity_db6_tmr_voter_data_phase_sync : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 2
    )
    Port map (     
            p_std_logic_vector_0_in        => (s_gbt_encoder_interface_tmr(0).data_phase_sync),
            p_std_logic_vector_1_in        => (s_gbt_encoder_interface_tmr(1).data_phase_sync),
            p_std_logic_vector_2_in        => (s_gbt_encoder_interface_tmr(2).data_phase_sync),
            p_tmr_error_out                => open,--p_gbt_encoder_interface_out.tmr_error,--s_tmr_voter_sync, --open,
            p_std_logic_vector_out         => p_gbt_encoder_interface_out.data_phase_sync   
            ); 

    i_entity_db6_tmr_voter_gbt_bank_sync : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 3
    )
    Port map (     
            p_std_logic_vector_0_in        => (s_gbt_encoder_interface_tmr(0).gbt_bank_sync),
            p_std_logic_vector_1_in        => (s_gbt_encoder_interface_tmr(1).gbt_bank_sync),
            p_std_logic_vector_2_in        => (s_gbt_encoder_interface_tmr(2).gbt_bank_sync),
            p_tmr_error_out                => open,--p_gbt_encoder_interface_out.tmr_error,--s_tmr_voter_sync, --open,
            p_std_logic_vector_out         => p_gbt_encoder_interface_out.gbt_bank_sync   
            ); 
                
    
end generate;


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--debug
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

gen_enable_ila_gbt_encoder : if g_enable_ila_gbt_encoder=1 generate
    
    
    i_entity_db6_tmr_voter_data_debug_hg : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 116
    )
    Port map (     
            p_std_logic_vector_0_in        => (s_gbt_encoder_interface_tmr(0).gbt_tx_data_out.hg),
            p_std_logic_vector_1_in        => (s_gbt_encoder_interface_tmr(1).gbt_tx_data_out.hg),
            p_std_logic_vector_2_in        => (s_gbt_encoder_interface_tmr(2).gbt_tx_data_out.hg),
            p_tmr_error_out                => s_tmr_voter_hg, --open,
            p_std_logic_vector_out         => s_gbt_encoder_interface_debug.gbt_tx_data_out.hg   
            );

    i_entity_db6_tmr_voter_data_debug_lg : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 116
    )
    Port map (     
            p_std_logic_vector_0_in        => (s_gbt_encoder_interface_tmr(0).gbt_tx_data_out.lg),
            p_std_logic_vector_1_in        => (s_gbt_encoder_interface_tmr(1).gbt_tx_data_out.lg),
            p_std_logic_vector_2_in        => (s_gbt_encoder_interface_tmr(2).gbt_tx_data_out.lg),
            p_tmr_error_out                => s_tmr_voter_lg,--open,
            p_std_logic_vector_out         => s_gbt_encoder_interface_debug.gbt_tx_data_out.lg   
            );
    
    s_lg_crc <= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(10 downto 0);
    s_hg_crc <= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(10 downto 0);
    s_lg_crc_count <= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(15 downto 11);
    s_hg_crc_count <= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(15 downto 11);
    
    
    g_gbt_encoder_adc_debug : for v_adc in 0 to 5 generate
        s_lg_adc(v_adc)<= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(27 + (12*v_adc) downto 16 + 12*v_adc);
        s_hg_adc(v_adc)<= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(27 + (12*v_adc) downto 16 + 12*v_adc);
    end generate;
    
    s_lg_bcr <= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(88);
    s_hg_bcr <= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(88);
    s_lg_gain <= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(89);
    s_hg_gain <= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(89);
    s_lg_tdo <= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(90);
    s_hg_tdo <= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(90);
    
    s_lg_integrator <= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(95 downto 91);
    s_hg_integrator <= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(95 downto 91);
    
    s_lg_sc <= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(111 downto 96);
    s_hg_sc <= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(111 downto 96);
    
    s_lg_switches <= s_gbt_encoder_interface_debug.gbt_tx_data_out.lg(113 downto 112);
    s_hg_switches <= s_gbt_encoder_interface_debug.gbt_tx_data_out.hg(113 downto 112);
    
    
    i_ila_gbt_encoder : ila_gbt_encoder
    PORT MAP (
        clk => p_clknet_in.cfgbus_clk40,
    
    
    
        probe0 => s_lg_crc, 
        probe1 => s_hg_crc, 
        probe2 => s_lg_crc_count, 
        probe3 => s_hg_crc_count, 
        probe4 => s_lg_adc(0), 
        probe5 => s_hg_adc(0), 
        probe6 => s_lg_adc(1), 
        probe7 => s_hg_adc(1), 
        probe8 => s_lg_adc(2), 
        probe9 => s_hg_adc(2), 
        probe10 => s_lg_adc(3), 
        probe11 => s_hg_adc(3), 
        probe12 => s_lg_adc(4), 
        probe13 => s_hg_adc(4), 
        probe14 => s_lg_adc(5), 
        probe15 => s_hg_adc(5), 
        probe16(0) => s_lg_bcr, 
        probe17(0) => s_hg_bcr, 
        probe18(0) => s_lg_gain, 
        probe19(0) => s_hg_gain, 
        probe20(0) => s_lg_tdo, 
        probe21(0) => s_hg_tdo, 
        probe22 => s_lg_integrator, 
        probe23 => s_hg_integrator, 
        probe24 => s_lg_sc, 
        probe25 => s_hg_sc, 
        probe26 => s_lg_switches, 
        probe27 => s_hg_switches, 
        probe28(0) => s_tmr_voter_lg,--(others => '0'),
        probe28(1) => s_tmr_voter_hg,
        probe29(0) => s_tmr_voter_sync, --(others => '0'),
        probe29(1) => s_tmr_voter_sync,
        probe30(0) => p_clknet_in.bcr.bcr,
        probe31 => p_clknet_in.bcr.count(4 downto 0)
    );
end generate;

gen_enable_ila_gbt_gearbox : if g_enable_ila_gbt_gearbox=1 generate
    
    
    i_entity_db6_tmr_voter_data_debug_sync : entity tilecal.db6_tmr_voter
    generic map(
        g_vector_width      => 116
    )
    Port map (     
            p_std_logic_vector_0_in        => (s_gbt_encoder_interface_tmr(0).gbt_tx_data_out.sync),
            p_std_logic_vector_1_in        => (s_gbt_encoder_interface_tmr(1).gbt_tx_data_out.sync),
            p_std_logic_vector_2_in        => (s_gbt_encoder_interface_tmr(2).gbt_tx_data_out.sync),
            p_tmr_error_out                => s_tmr_voter_hg, --open,
            p_std_logic_vector_out         => s_gbt_encoder_interface_debug.gbt_tx_data_out.sync   
            );


    
    s_sync_crc <= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(10 downto 0);
    s_sync_crc_count <= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(15 downto 11);
    
    
    g_gbt_encoder_adc_debug : for v_adc in 0 to 5 generate
        s_sync_adc(v_adc)<= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(27 + (12*v_adc) downto 16 + 12*v_adc);
    end generate;
    
    s_sync_bcr <= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(88);
    s_sync_gain <= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(89);
    s_sync_tdo <= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(90);
    
    s_sync_integrator <= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(95 downto 91);
    
    s_sync_sc <= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(111 downto 96);
    
    s_sync_switches <= s_gbt_encoder_interface_debug.gbt_tx_data_out.sync(113 downto 112);
    
    
    i_ila_gbt_encoder : ila_gbt_encoder
    PORT MAP (
        clk => p_clknet_in.mmcm_refclk80,
    
        probe0 => s_sync_crc, 
        probe1 => s_hg_crc, 
        probe2 => s_sync_crc_count, 
        probe3 => (others => '0'), --s_hg_crc_count
        probe4 => s_sync_adc(0), 
        probe5 => (others => '0'), --s_hg_adc(0), 
        probe6 => s_sync_adc(1), 
        probe7 => (others => '0'), --s_hg_adc(1), 
        probe8 => s_sync_adc(2), 
        probe9 => (others => '0'), --s_hg_adc(2), 
        probe10 => s_sync_adc(3), 
        probe11 => (others => '0'), --s_hg_adc(3), 
        probe12 => s_sync_adc(4), 
        probe13 => (others => '0'), --s_hg_adc(4), 
        probe14 => s_sync_adc(5), 
        probe15 => (others => '0'), --s_hg_adc(5), 
        probe16(0) => s_sync_bcr, 
        probe17(0) => '0', --s_hg_bcr, 
        probe18(0) => s_sync_gain, 
        probe19(0) => '0', --s_hg_gain, 
        probe20(0) => s_sync_tdo, 
        probe21(0) => '0', --s_hg_tdo, 
        probe22 => s_sync_integrator, 
        probe23 => (others => '0'), --s_hg_integrator, 
        probe24 => s_sync_sc, 
        probe25 => (others => '0'), --s_hg_sc, 
        probe26 => s_sync_switches, 
        probe27 => (others => '0'), --s_hg_switches, 
        probe28(0) => s_tmr_voter_sync,--(others => '0'),
        probe28(1) => '0', --s_tmr_voter_hg,
        probe29(0) => s_tmr_voter_sync, --(others => '0'),
        probe29(1) => s_tmr_voter_sync,
        probe30(0) => p_clknet_in.bcr.bcr,
        probe31 => p_clknet_in.bcr.count(4 downto 0)
    );
end generate;

end behavioral;
