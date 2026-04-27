----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.10.2022 21:35:53
-- Design Name: 
-- Module Name: db6_cis_interface_driver - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_cis_interface_driver is
    generic (
        g_ila_cis_interface : natural := 0      -- 0 =no ila, 1 = ila enabled
        );
  Port ( 
        p_clknet_in                        : in t_db_clknet;
        p_master_reset_in       : in std_logic;
        p_db_reg_rx_in  : in t_db_reg_rx;
        p_tph_out               : out t_mb_std_logic;
        p_tpl_out               : out t_mb_std_logic
  );
end db6_cis_interface_driver;

architecture Behavioral of db6_cis_interface_driver is

    COMPONENT ila_cis_interface3
    PORT (
        clk : IN STD_LOGIC;
    
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END COMPONENT  ;
    
    signal s_tph, s_tpl : t_mb_std_logic;
    signal s_tph_fixed_phase, s_tpl_fixed_phase : t_mb_std_logic;
    signal s_master_reset : std_logic;
    
begin

    proc_mux_clks : process(p_db_reg_rx_in(cfb_db_debug)(c_db_debug_cis_tp_clk_mux))
    begin
        if p_db_reg_rx_in(cfb_db_debug)(c_db_debug_cis_tp_clk_mux) = '0' then
            p_tph_out <= s_tph;
            p_tpl_out <= s_tpl;
        else
            p_tph_out <= s_tph_fixed_phase;
            p_tpl_out <= s_tpl_fixed_phase;        
        end if;
    end process;

    
    s_master_reset <= p_master_reset_in or p_db_reg_rx_in(cfb_strobe_reg)(c_cis_reset_bit);
    
i_db6_cis_driver_q0 : entity tilecal.db6_cis_driver_cdc
        Port map(
        p_clk240_in                     => p_clknet_in.mmcm_refclk240,
        p_cdc_counter_in                => p_clknet_in.gbt_cdc_counter,
        p_cdc_phase_in                  => p_clknet_in.gbt_cdc_phase,
        p_clk40_deskew_in               => p_clknet_in.tp_clk40.q0,
        p_cis_config_reg_in             => p_db_reg_rx_in(cfb_cis_config),
        p_master_reset_in               => s_master_reset,
        p_bcr_count_in                  => p_clknet_in.bcr.count,
        p_tph_out                       => s_tph.q0,
        p_tpl_out                       => s_tpl.q0
        );

i_db6_cis_driver_q1 : entity tilecal.db6_cis_driver_cdc
        Port map(
        p_clk240_in                     => p_clknet_in.mmcm_refclk240,
        p_cdc_counter_in                => p_clknet_in.gbt_cdc_counter,
        p_cdc_phase_in                  => p_clknet_in.gbt_cdc_phase,
        p_clk40_deskew_in               => p_clknet_in.tp_clk40.q1,
        p_cis_config_reg_in             => p_db_reg_rx_in(cfb_cis_config),
        p_master_reset_in               => s_master_reset,
        p_bcr_count_in                  => p_clknet_in.bcr.count,
        p_tph_out                       => s_tph.q1,
        p_tpl_out                       => s_tpl.q1
        );

i_db6_cis_driver_q0_fixed_phase : entity tilecal.db6_cis_driver_cdc
        Port map(
        p_clk240_in                     => p_clknet_in.mmcm_refclk240,
        p_cdc_counter_in                => p_clknet_in.gbt_cdc_counter,
        p_cdc_phase_in                  => p_clknet_in.gbt_cdc_phase,
        p_clk40_deskew_in               => p_clknet_in.refclk40,
        p_cis_config_reg_in             => p_db_reg_rx_in(cfb_cis_config),
        p_master_reset_in               => s_master_reset,
        p_bcr_count_in                  => p_clknet_in.bcr.count,
        p_tph_out                       => s_tph_fixed_phase.q0,
        p_tpl_out                       => s_tpl_fixed_phase.q0
        );

i_db6_cis_driver_q1_fixed_phase : entity tilecal.db6_cis_driver_cdc
        Port map(
        p_clk240_in                     => p_clknet_in.mmcm_refclk240,
        p_cdc_counter_in                => p_clknet_in.gbt_cdc_counter,
        p_cdc_phase_in                  => p_clknet_in.gbt_cdc_phase,
        p_clk40_deskew_in               => p_clknet_in.refclk40,
        p_cis_config_reg_in             => p_db_reg_rx_in(cfb_cis_config),
        p_master_reset_in               => s_master_reset,
        p_bcr_count_in                  => p_clknet_in.bcr.count,
        p_tph_out                       => s_tph_fixed_phase.q1,
        p_tpl_out                       => s_tpl_fixed_phase.q1
        );


end Behavioral;


------------------------------------------------------------------------------------
---- Company: 
---- Engineer: 
---- 
---- Create Date: 28.10.2022 21:35:53
---- Design Name: 
---- Module Name: db6_cis_interface_driver - Behavioral
---- Project Name: 
---- Target Devices: 
---- Tool Versions: 
---- Description: 
---- 
---- Dependencies: 
---- 
---- Revision:
---- Revision 0.01 - File Created
---- Additional Comments:
---- 
------------------------------------------------------------------------------------


--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;

--library tilecal;
--use tilecal.db6_design_package.all;

---- Uncomment the following library declaration if using
---- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx leaf cells in this code.
----library UNISIM;
----use UNISIM.VComponents.all;

--entity db6_cis_interface_driver is
--    generic (
--        g_ila_cis_interface : natural := 0      -- 0 =no ila, 1 = ila enabled
--        );
--  Port ( 
--        p_clknet_in                        : in t_db_clknet;
--        p_master_reset_in       : in std_logic;
--        p_db_reg_rx_in  : in t_db_reg_rx;
--        p_tph_out               : out t_mb_std_logic;
--        p_tpl_out               : out t_mb_std_logic
--  );
--end db6_cis_interface_driver;

--architecture Behavioral of db6_cis_interface_driver is

--    signal s_cis_enable_q0, s_cis_enable_q1     : std_logic                     := '0';
--    signal s_cis_gain_q0, s_cis_gain_q1       : std_logic                     := '0';
--    signal s_cis_bcid_charge_q0, s_cis_bcid_charge_q1       	: std_logic_vector(11 downto 0) := x"000";
--    signal s_cis_bcid_discharge_q0, s_cis_bcid_discharge_q1       : std_logic_vector(11 downto 0) := x"000";
--    signal s_tph, s_tpl : t_mb_std_logic;
--    signal s_bc_number_q0, s_bc_number_q1 : std_logic_vector(31 downto 0);
    
--    signal s_cis_config_reg, s_cis_config_cdc_reg : std_logic_vector(31 downto 0);
--    signal s_cis_config_reg_q0, s_cis_config_cdc_reg_q0, s_cis_config_reg_q1, s_cis_config_cdc_reg_q1 : std_logic_vector(31 downto 0);
--    signal s_cdc_flag : std_logic; 
--    signal s_cdc_flag_q0, s_cdc_flag_q1 : std_logic;
    
--    type t_sm_cis is (st_idle , st_charge_lg, st_charge_hg);
--    signal sm_cis_q0, sm_cis_next_q0, sm_cis_q1, sm_cis_next_q1   : t_sm_cis ;
    
--    COMPONENT ila_cis_interface3
--    PORT (
--        clk : IN STD_LOGIC;
    
--        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe2 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
--        probe3 : IN STD_LOGIC_VECTOR(11 DOWNTO 0); 
--        probe4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
--        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--        probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--        probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--    );
--    END COMPONENT  ;
    

--begin

--    p_tph_out <= s_tph;
--    p_tpl_out <= s_tpl;
    

----s_bc_number_q0 <= p_clknet_in.bcr.count;

----proc_cdc : process(p_clknet_in.refclk40,p_master_reset_in, p_db_reg_rx_in(cfb_strobe_reg)(c_cis_reset_bit))
----begin
----    if (p_master_reset_in = '1') or (p_db_reg_rx_in(cfb_strobe_reg)(c_cis_reset_bit)='1') then
----        s_cdc_flag<='0';
----    elsif rising_edge(p_clknet_in.refclk40) then
----        s_cis_config_cdc_reg<=p_db_reg_rx_in(cfb_cis_config);
----        if s_cis_config_cdc_reg=p_db_reg_rx_in(cfb_cis_config) then
----            s_cdc_flag<='1';
----        else
----            s_cis_config_reg<=p_db_reg_rx_in(cfb_cis_config);
----            s_cdc_flag<='0';
----        end if;
----    end if; 

----end process;


--proc_cis_driver_q0 : process(p_clknet_in.tp_clk40.q0,p_master_reset_in, p_db_reg_rx_in(cfb_strobe_reg)(c_cis_reset_bit))
--begin
--	if (p_master_reset_in = '1') or (p_db_reg_rx_in(cfb_strobe_reg)(c_cis_reset_bit)) = '1' then
--	   sm_cis_q0 <= st_idle;
--	   sm_cis_next_q0 <= st_idle;
--	   s_bc_number_q0 <= x"00000000"; 
--	elsif rising_edge(p_clknet_in.tp_clk40.q0) then
	
--        sm_cis_q0 <= sm_cis_next_q0;
--        s_cis_config_reg_q0<=p_db_reg_rx_in(cfb_cis_config);
--        s_cis_config_cdc_reg_q0<=s_cis_config_reg_q0;
--        if s_cis_config_cdc_reg_q0=p_db_reg_rx_in(cfb_cis_config) then
--            s_cis_enable_q0 			<= s_cis_config_reg_q0(0);
--            s_cis_gain_q0 				<= s_cis_config_reg_q0(1);  
--            s_cis_bcid_charge_q0 		<= s_cis_config_reg_q0(13 downto 2);  
--            s_cis_bcid_discharge_q0 	<= s_cis_config_reg_q0(25 downto 14);
--        end if;

----        if (s_cdc_flag='1') then
----            s_cis_enable_q0 			<= s_cis_config_reg(0);
----            s_cis_gain_q0 				<= s_cis_config_reg(1);  
----            s_cis_bcid_charge_q0 		<= s_cis_config_reg(13 downto 2);  
----            s_cis_bcid_discharge_q0 	<= s_cis_config_reg(25 downto 14);
----        end if;
        
--        if (p_clknet_in.bcr.bcr = '0') or (to_integer(unsigned(s_bc_number_q0))<c_lhc_bunches_between_bcr) then
--            s_bc_number_q0 <= std_logic_vector(to_unsigned(to_integer(unsigned(s_bc_number_q0)) +1,32));            
--        else
--            s_bc_number_q0 <= x"00000000";
--        end if;
        
--        case sm_cis_q0 is
--            when st_idle =>

--                s_tph.q0     <= '0';
--                s_tpl.q0     <= '0';
--                if (s_bc_number_q0(11 downto 0) = s_cis_bcid_charge_q0 and s_cis_enable_q0 ='1') then
--                    if (s_cis_gain_q0 ='0') then
--                        sm_cis_next_q0 <= st_charge_lg;
--                    else
--                        sm_cis_next_q0 <= st_charge_hg;
--                    end if;
--                else
--                    sm_cis_next_q0 <= st_idle;
--                end if;

--            when st_charge_lg => 
--                s_tph.q0     <= '0';
--                s_tpl.q0     <= '1';
--                if ( s_bc_number_q0(11 downto 0) = s_cis_bcid_discharge_q0) then
--                    sm_cis_next_q0 <= st_idle;
--                else 
--                    sm_cis_next_q0 <= st_charge_lg;
--                end if;

--            when st_charge_hg => 
--                s_tph.q0     <= '1';
--                s_tpl.q0     <= '0';
--                if ( s_bc_number_q0(11 downto 0) = s_cis_bcid_discharge_q0) then
--                    sm_cis_next_q0 <= st_idle;
--                else 
--                    sm_cis_next_q0 <= st_charge_hg;
--                end if;
--            when others=>
--                sm_cis_next_q0 <= st_idle;
--        end case;

--	end if;
--end process;



----s_bc_number_q1 <= p_clknet_in.bcr.count;

--proc_cis_driver_q1 : process(p_clknet_in.tp_clk40.q1,p_master_reset_in, p_db_reg_rx_in(cfb_strobe_reg)(c_cis_reset_bit))
--begin
	
--    if (p_master_reset_in = '1') or (p_db_reg_rx_in(cfb_strobe_reg)(c_cis_reset_bit)) = '1' then
--	   sm_cis_q1 <= st_idle;
--	   sm_cis_next_q1 <= st_idle;
--	elsif (rising_edge(p_clknet_in.tp_clk40.q1)) then
--        sm_cis_q1 <= sm_cis_next_q1;
--        s_cis_config_reg_q1<=p_db_reg_rx_in(cfb_cis_config);
--        s_cis_config_cdc_reg_q1<=s_cis_config_reg_q1;
--        if s_cis_config_cdc_reg_q1=p_db_reg_rx_in(cfb_cis_config) then
--            s_cis_enable_q1 			<= s_cis_config_reg_q1(0);
--            s_cis_gain_q1 				<= s_cis_config_reg_q1(1);  
--            s_cis_bcid_charge_q1 		<= s_cis_config_reg_q1(13 downto 2);  
--            s_cis_bcid_discharge_q1 	<= s_cis_config_reg_q1(25 downto 14);
--        end if;

----        if (s_cdc_flag='1') then
----            s_cis_enable_q1 			<= s_cis_config_reg(0);
----            s_cis_gain_q1 				<= s_cis_config_reg(1);  
----            s_cis_bcid_charge_q1 		<= s_cis_config_reg(13 downto 2);  
----            s_cis_bcid_discharge_q1 	<= s_cis_config_reg(25 downto 14);    
----        end if;

--        if (p_clknet_in.bcr.bcr = '0')  or (to_integer(unsigned(s_bc_number_q1))<c_lhc_bunches_between_bcr) then
--            s_bc_number_q1 <= std_logic_vector(to_unsigned(to_integer(unsigned(s_bc_number_q1)) +1,32));
--        else
--            s_bc_number_q1 <= x"00000000";
--        end if;
    
--        case sm_cis_q1 is
--            when st_idle => 
--                s_tph.q1     <= '0';
--                s_tpl.q1     <= '0';
--                if (s_bc_number_q1(11 downto 0) = s_cis_bcid_charge_q1 and s_cis_enable_q1 ='1') then
--                    if (s_cis_gain_q1 ='0') then
--                        sm_cis_next_q1 <= st_charge_lg;
--                    else
--                        sm_cis_next_q1 <= st_charge_hg;
--                    end if;
--                else
--                    sm_cis_next_q1 <= st_idle;
--                end if;

--            when st_charge_lg => 
--                s_tph.q1     <= '0';
--                s_tpl.q1     <= '1';
--                if ( s_bc_number_q1(11 downto 0) = s_cis_bcid_discharge_q1) then
--                    sm_cis_next_q1 <= st_idle;
--                else 
--                    sm_cis_next_q1 <= st_charge_lg;
--                end if;

--            when st_charge_hg => 
--                s_tph.q1     <= '1';
--                s_tpl.q1     <= '0';
--                if ( s_bc_number_q1(11 downto 0) = s_cis_bcid_discharge_q1) then
--                    sm_cis_next_q1 <= st_idle;
--                else 
--                    sm_cis_next_q1 <= st_charge_hg;
--                end if;
--            when others=>
--                sm_cis_next_q1 <= st_idle;
--        end case;

--	end if;
--end process;

--gen_ila_cis_interface : if g_ila_cis_interface = 1 generate
--    i_ila_cis_interface3 : ila_cis_interface3
--    PORT MAP (
--        clk => p_clknet_in.cfgbus_clk40,
        
--        probe0(0) => s_cis_enable_q0, 
--        probe1(0) => s_cis_gain_q0, 
--        probe2 => s_cis_bcid_charge_q0, 
--        probe3 => s_cis_bcid_discharge_q0, 
--        probe4 => s_bc_number_q0, 
--        probe5(0) => s_tpl.q0, 
--        probe6(0) => s_tph.q0, 
--        probe7(0) => s_tph.q1, 
--        probe8(0) => s_tpl.q1, 
--        probe9(0) => p_master_reset_in, 
--        probe10(0) => s_cis_gain_q0, 
--        probe11(0) => s_cis_enable_q0, 
--        probe12(0) => p_clknet_in.bcr.bcr,
--        probe13 => "1"
--    );
--end generate;   

--end Behavioral;
