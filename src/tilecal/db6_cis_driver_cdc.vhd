----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.03.2023 04:47:23
-- Design Name: 
-- Module Name: db6_cis_driver - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_cis_driver_cdc is
        Port (
        p_clk240_in                        : in std_logic;
        p_cdc_counter_in                        : in integer range 0 to 3;
        p_cdc_phase_in                        : in std_logic;
        p_clk40_deskew_in                        : in std_logic;
        p_cis_config_reg_in                  : in std_logic_vector(31 downto 0);
        p_master_reset_in       : in std_logic;
        p_bcr_count_in                  : in std_logic_vector(31 downto 0);
        p_tph_out               : out std_logic;
        p_tpl_out               : out std_logic
        );
end db6_cis_driver_cdc;

architecture Behavioral of db6_cis_driver_cdc is

    signal s_cis_enable     : std_logic                     := '0';
    signal s_cis_gain       : std_logic                     := '0';
    signal s_cis_bcid_charge       	: std_logic_vector(11 downto 0) := x"000";
    signal s_cis_bcid_discharge       : std_logic_vector(11 downto 0) := x"000";
    signal s_bc_number : std_logic_vector(31 downto 0);
    signal s_tph, s_tpl : std_logic;

begin

	s_cis_enable 			<= p_cis_config_reg_in(0);
	s_cis_gain 				<= p_cis_config_reg_in(1);  
	s_cis_bcid_charge 		<= p_cis_config_reg_in(13 downto 2);  
	s_cis_bcid_discharge 	<= p_cis_config_reg_in(25 downto 14);
    s_bc_number <= p_bcr_count_in;

proc_cis_driver : process(p_clk240_in, p_master_reset_in, s_cis_enable)
type t_sm_cis is (st_idle , st_charge_lg, st_charge_hg);
variable sm_cis, sm_cis_next   : t_sm_cis ;
begin
    if (p_master_reset_in = '1' or s_cis_enable ='0') then
        sm_cis := st_idle;
        s_tph     <= '0';
        s_tpl     <= '0';
	elsif (rising_edge(p_clk240_in)) then
	   if (p_cdc_counter_in = 2) and (p_cdc_phase_in = '1') then
            sm_cis := sm_cis_next;
            
            case sm_cis is
                when st_idle => 
                    s_tph     <= '0';
                    s_tpl     <= '0';
                    if (s_bc_number(11 downto 0) = s_cis_bcid_charge and s_cis_enable ='1') then
                        if (s_cis_gain ='0') then
                            sm_cis_next := st_charge_lg;
                        else
                            sm_cis_next := st_charge_hg;
                        end if;
                    else
                        sm_cis_next := st_idle;
                    end if;
    
                when st_charge_lg => 
                    s_tph     <= '0';
                    s_tpl     <= '1';
                    if ( s_bc_number(11 downto 0) = s_cis_bcid_discharge) then
                        sm_cis_next := st_idle;
                    else 
                        sm_cis_next := st_charge_lg;
                    end if;
    
                when st_charge_hg => 
                    s_tph     <= '1';
                    s_tpl     <= '0';
                    if ( s_bc_number(11 downto 0) = s_cis_bcid_discharge) then
                        sm_cis_next := st_idle;
                    else 
                        sm_cis_next := st_charge_hg;
                    end if;
                when others=>
                    sm_cis_next := st_idle;
            end case;
        end if;
    end if;
end process;
proc_deskew_cdc : process(p_clk40_deskew_in)
begin
	if (rising_edge(p_clk40_deskew_in)) then
	   p_tph_out <= s_tph;
	   p_tpl_out <= s_tpl;
	end if;
end process;

end Behavioral;


