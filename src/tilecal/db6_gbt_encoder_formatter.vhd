----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.10.2022 14:31:16
-- Design Name: 
-- Module Name: db6_gbt_encoder_gearbox - Behavioral
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

library tilecal;
use tilecal.db6_design_package.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_gbt_encoder_formatter is
  generic (
      g_ch_number : integer := 0;
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
        --p_gbt_tx_data_out       : out std_logic_vector(115 downto 0);
        p_gbt_encoder_interface_out         : out t_gbt_encoder_interface;
		
		--interfaces
		p_mb_interface_in : in t_mb_interface;
		p_sem_interface_in : in t_sem_interface;
		p_tdo_remote_in	            : in	std_logic;
		p_system_management_interface_in : in t_system_management_interface;
		p_gbtx_interface_in : in t_gbtx_interface;
		p_serial_id_interface_in : in t_serial_id_interface;
		p_sfp_ku_mgt_in                     : in t_ku_mgt;
		p_db6_sem_interface_in : in t_db6_sem_interface;
		p_cfgbus_interface_in : in t_cfgbus_interface;
		p_sfp_interface_in    : in t_sfp_interface
		);
end db6_gbt_encoder_formatter;

architecture Behavioral of db6_gbt_encoder_formatter is

-- slow control data readout
    
--    signal s_sc_address          	    : integer range 0 to c_number_of_cfgbus_regs + c_number_of_gbttx_regs; --std_logic_vector(15 downto 0):=(others=>'0');
    
    signal s_adc_data_lg 	: std_logic_vector(71 downto 0) := (others => '0');
    signal s_adc_data_hg 	: std_logic_vector(71 downto 0) := (others => '0');
    signal s_adc_data_fc 	: std_logic_vector(71 downto 0) := (others => '0');    
    
    signal s_gbt_encoder_interface, s_gbt_encoder_interface_cdc : t_gbt_encoder_interface;

--    attribute keep : string;
--    attribute dont_touch : string;
--    attribute keep of s_adc_data_o_hg, s_adc_data_o_lg, s_adc_data_o_fc, s_gbt_encoder_interface  : signal is "true";
--    attribute dont_touch of s_adc_data_o_hg, s_adc_data_o_lg, s_gbt_encoder_interface, s_adc_data_o_fc  : signal is "true";    
    signal s_integrator_frame : std_logic_vector(9 downto 0);
    signal s_tdo : std_logic;
    
    
    constant c_pipeline_depth : integer := 3; --c_global_pipeline_depth;
    type t_gbt_encoder_interface_pipeline is array (0 to c_pipeline_depth-1) of t_gbt_encoder_interface;
    signal s_gbt_encoder_interface_pipeline: t_gbt_encoder_interface_pipeline;
    
    
-----------------debug

signal s_debug_tx_state : std_logic_vector (3 downto 0);
COMPONENT ila_tile_encoder_tx_debug

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
	probe5 : IN STD_LOGIC_VECTOR(1 DOWNTO 0)
);
END COMPONENT  ;

begin




-- assembling data words

--    p_gbt_encoder_interface_out<=s_gbt_encoder_interface_pipeline(c_pipeline_depth-1);--s_gbt_encoder_interface;



--    proc_gbt_interface_pipeline: process(p_clknet_in.gth_tx_wordclk(g_ch_number))
--    begin
--        if rising_edge(p_clknet_in.gth_tx_wordclk(g_ch_number)) then--(p_clknet_in.refclk40) then
--            for p in 0 to (c_pipeline_depth-1-1) loop
--                s_gbt_encoder_interface_pipeline(p+1)<=s_gbt_encoder_interface_pipeline(p);
--                s_gbt_encoder_interface_pipeline(0)<=s_gbt_encoder_interface_cdc;
--            end loop;
----            if (p_clknet_in.gbt_cdc_counter = 2) and (p_clknet_in.gbt_cdc_phase = '1')then
----                s_gbt_encoder_interface_cdc<=s_gbt_encoder_interface;
----            end if;
--        end if;    
--    end process;
--    s_gbt_encoder_interface_cdc<=s_gbt_encoder_interface;
    
    p_gbt_encoder_interface_out<=s_gbt_encoder_interface;

     proc_db_data_assembler : process(p_clknet_in.cfgbus_clk40)--(p_clknet_in.refclk40) --process(p_clknet_in.refclk40) -- (p_clknet_in.gth_txwordclk40_out(i))
        begin
            if rising_edge(p_clknet_in.cfgbus_clk40) then --(p_clknet_in.refclk40) then--(p_clknet_in.refclk40) then  --(p_clknet_in.gth_txwordclk40_out(i)) then
                s_tdo<=p_tdo_remote_in;
                s_gbt_encoder_interface.gbt_tx_data_out.lg(10 downto 0)    <= tilecal.db6_design_package.tile_link_crc_compute(
                                                    "00" &
                                                    s_gbt_encoder_interface.sc_switch(0) &
                                                    s_gbt_encoder_interface.sc_tx(0) &
                                                    s_integrator_frame(9 downto 5) &
                                                    s_tdo &
                                                    '0' &
                                                    p_clknet_in.bcr.bcr &
                                                    s_adc_data_lg
                                                    )(10 downto 0);
                s_gbt_encoder_interface.gbt_tx_data_out.lg(15 downto 11)   <= p_clknet_in.bcr.count(4 downto 0);
--                    if s_gbt_encoder_interface.tx_fc_lg = '0' then
                    s_gbt_encoder_interface.gbt_tx_data_out.lg(87 downto 16)   <= s_adc_data_lg;
--                    else
--                        s_gbt_encoder_interface.gbt_tx_data_out.lg(87 downto 16)   <= s_adc_data_o_fc;
--                    end if;
                s_gbt_encoder_interface.gbt_tx_data_out.lg(88)             <= p_clknet_in.bcr.bcr; 
                s_gbt_encoder_interface.gbt_tx_data_out.lg(89)             <= '0';
                s_gbt_encoder_interface.gbt_tx_data_out.lg(90)             <= s_tdo;
                s_gbt_encoder_interface.gbt_tx_data_out.lg(95 downto 91)   <= s_integrator_frame(9 downto 5);
                s_gbt_encoder_interface.gbt_tx_data_out.lg(111 downto 96)  <= s_gbt_encoder_interface.sc_tx(0);
                s_gbt_encoder_interface.gbt_tx_data_out.lg(113 downto 112) <= s_gbt_encoder_interface.sc_switch(0);
                s_gbt_encoder_interface.gbt_tx_data_out.lg(115 downto 114) <= "00";--p_adc_mon_in;

                s_gbt_encoder_interface.gbt_tx_data_out.hg(10 downto 0)    <= tilecal.db6_design_package.tile_link_crc_compute(
                                                    "00" &
                                                    s_gbt_encoder_interface.sc_switch(1) &
                                                    s_gbt_encoder_interface.sc_tx(1) &
                                                    s_integrator_frame(4 downto 0) &
                                                    s_tdo &
                                                    '1' &
                                                    p_clknet_in.bcr.bcr &
                                                    s_adc_data_hg
                                                    )(10 downto 0);                 
                s_gbt_encoder_interface.gbt_tx_data_out.hg(15 downto 11)   <= p_clknet_in.bcr.count(4 downto 0);
--                    if s_gbt_encoder_interface.tx_fc_hg = '0' then
                    s_gbt_encoder_interface.gbt_tx_data_out.hg(87 downto 16)   <= s_adc_data_hg;
--                    else
--                        s_gbt_tx_data.hg(87 downto 16)   <= s_adc_data_o_fc;
--                    end if;
                s_gbt_encoder_interface.gbt_tx_data_out.hg(88)             <= p_clknet_in.bcr.bcr;  -- bcr
                s_gbt_encoder_interface.gbt_tx_data_out.hg(89)             <= '1';  -- gain
                s_gbt_encoder_interface.gbt_tx_data_out.hg(90)             <= s_tdo;
                s_gbt_encoder_interface.gbt_tx_data_out.hg(95 downto 91)   <= s_integrator_frame(4 downto 0);
                s_gbt_encoder_interface.gbt_tx_data_out.hg(111 downto 96)  <= s_gbt_encoder_interface.sc_tx(1);
                s_gbt_encoder_interface.gbt_tx_data_out.hg(113 downto 112) <= s_gbt_encoder_interface.sc_switch(1);
                s_gbt_encoder_interface.gbt_tx_data_out.hg(115 downto 114) <= "00"; --p_adc_mon_in;
            end if;

        end process;


i_db6_gbt_encoder_adc_data : entity tilecal.db6_gbt_encoder_adc_data
  port map(
        p_master_reset_in => p_master_reset_in,
		p_clknet_in => p_clknet_in,
        p_db_reg_rx_in => p_db_reg_rx_in,

		--interfaces
		p_mb_interface_in => p_mb_interface_in,

        --outputs
        p_adc_data_lg_out => s_adc_data_lg,
		p_adc_data_hg_out => s_adc_data_hg,
		p_adc_data_fc_out => s_adc_data_fc
        
		);

i_db6_gbt_encoder_integrator : entity tilecal.db6_gbt_encoder_integrator 
  port map( 
        p_master_reset_in => p_master_reset_in,
        p_clknet_in => p_clknet_in,
        p_db_reg_rx_in => p_db_reg_rx_in,
        
        --interfaces
        p_mb_interface_in => p_mb_interface_in,
        
        --integrator processed data
        p_integrator_frame_out => s_integrator_frame
  );


i_db6_gbt_encoder_sc : entity tilecal.db6_gbt_encoder_sc
  generic map (
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
  port map(
        p_master_reset_in => p_master_reset_in,
		p_clknet_in => p_clknet_in,
        p_db_reg_rx_in => p_db_reg_rx_in,
        
		--interfaces
		p_mb_interface_in => p_mb_interface_in,
		p_sem_interface_in => p_sem_interface_in,
		p_system_management_interface_in => p_system_management_interface_in,
		p_gbtx_interface_in => p_gbtx_interface_in,
		p_serial_id_interface_in => p_serial_id_interface_in,
		p_sfp_ku_mgt_in => p_sfp_ku_mgt_in,
		p_db6_sem_interface_in => p_db6_sem_interface_in,
		p_cfgbus_interface_in => p_cfgbus_interface_in,
		p_sfp_interface_in => p_sfp_interface_in,
		
        p_sc_switch_out      => s_gbt_encoder_interface.sc_switch,
        p_sc_tx_out          => s_gbt_encoder_interface.sc_tx
		);


--	probe0(0) => p_clknet_in.bcr.bcr, 
--	probe1 => s_gbt_encoder_interface.sc_address, 
--	probe2 => s_gbt_encoder_interface.sc_data, 
--	probe3 => s_debug_tx_state, 
--	probe4 => s_gbt_encoder_interface.sc_switch(0),
--	probe5 => s_gbt_encoder_interface.sc_switch(1)
--);


end Behavioral;
