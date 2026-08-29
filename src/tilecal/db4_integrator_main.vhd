----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/04/2021 11:26:34 PM
-- Design Name: 
-- Module Name: db4_integrator_main - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;

library tilecal;
use tilecal.db6_design_package.all;

entity db4_integrator_main is
generic(
        g_code_version : natural := 0 -- 0 -> modified, 1-> db4, 2 -> dummy
        
);
Port (
    p_clknet_in                  : in    t_db_clknet; 
	reset                   : IN std_logic;
	clk40                   : IN std_logic;	
	--clk80                   : IN std_logic;	
	Integrator_config_reg   : IN std_logic_vector(31 downto 0);	
	Integ1_request          : OUT std_logic_vector(15 downto 0);
	Integ2_request          : OUT std_logic_vector(15 downto 0);
	Integ1_data_out         : IN std_logic_vector(15 downto 0);
	Integ2_data_out         : IN std_logic_vector(15 downto 0);
	Integ1_EndOfRead        : IN std_logic; 
	Integ2_EndOfRead        : IN std_logic;
	
	GBT_Integrator          : OUT std_logic_vector(4 downto 0);
	EndOfOrbit              : IN std_logic;
	p_end_of_read_out           : out std_logic;
	CNTOrbit_O              : OUT std_logic_VECTOR (7 DOWNTO 0);
	p_bc_count_readout_out              : out std_logic_vector(15 downto 0);
	p_statea_out                : out std_logic_vector(3 downto 0);
	p_stateb_out                : out std_logic_vector(3 downto 0);
	p_integrator_adc_data_out      : out t_integrator_adc_data
	
	
);
end db4_integrator_main;

architecture Behavioral of db4_integrator_main is

	type state_request is (idle, requestch0, requestch1, requestch2,endch0,endch1,endch2);
	signal current_rq, next_rq   : state_request;

	signal s_bc_count_readout, s_bc_count_readout_reg : std_logic_vector(31 downto 0) := x"00000000"; 
	signal Orbit_cnt, Readout_rate : std_logic_vector(7 downto 0) := x"00";
	signal ResetOrbitCnt : std_logic;

	--type array_6chan is array (0 to 5) of std_logic_vector(15 downto 0); 
	--signal DataCh : array_6chan;
	signal DataCh : t_integrator_adc_data;

	signal chid : std_logic_vector(3 downto 0):= "0000"; 

	signal stateA : std_logic_vector(3 downto 0);
	signal stateB : std_logic_vector(3 downto 0);

	signal Integ1_EndOfReadi,Integ2_EndOfReadi : std_logic;
	signal s_end_of_readout : std_logic;

	ATTRIBUTE KEEP: STRING;
	ATTRIBUTE KEEP of stateA,stateB,Integ1_EndOfRead,Integ2_EndOfRead: signal is "TRUE";

begin

    p_statea_out <= statea;
    p_stateb_out <= stateb;
    p_end_of_read_out <= s_end_of_readout; --ResetOrbitCnt;



    CNTOrbit_O 		<= Orbit_cnt;
    Readout_rate 	<= Integrator_config_reg(7 downto 0);
    
    p_bc_count_readout_out<=s_bc_count_readout_reg(15+2 downto 0+2);
    
    ---------------------------------------------------------
    --- STATE MACHINE TO REQUEST THE READOUT OF CHANNELS ----
    ---------------------------------------------------------
    
    
    
    process(p_clknet_in.cfgbus_clk40, reset)
    begin
        if (reset='1') then
            current_rq <= idle;
            ResetOrbitCnt <= '1';
            s_end_of_readout <= '0';
            Orbit_cnt <= (others => '0');
        elsif rising_edge(p_clknet_in.cfgbus_clk40) then

            p_integrator_adc_data_out <= datach;
            if current_rq = idle then
                s_bc_count_readout<=x"00000001";
            else   
                s_bc_count_readout<=std_logic_vector(unsigned(s_bc_count_readout)+1);
--                    s_bcr_count_readout_reg<=std_logic_vector(unsigned(s_bcr_count_readout)+1);                                   
            end if;
            
                --current_rq <= next_rq;
            if EndOfOrbit = '1' then
                

            
                if (unsigned(orbit_cnt) > unsigned(Readout_rate)-1) then
                    ResetOrbitCnt <= '1';
                    Orbit_cnt <= (others => '0');
                    if current_rq = idle then
                        current_rq <= requestch0;
                    end if;	
                else
                    ResetOrbitCnt <= '0';
                    Orbit_cnt <= std_logic_vector(unsigned(Orbit_cnt)+1);
                end if;
            end if;
            
             case current_rq is
                when idle =>
--                    if s_end_of_readout = '1' then 
                        s_end_of_readout<='0';
--                    end if;
                    DataCh <= DataCh;
                    Integ1_EndOfReadi <='0';
                    Integ2_EndOfReadi <='0';
                    stateA <= x"1";
                    Integ1_request <= x"0000"; 
                    Integ2_request <= x"0000";
--                        ResetOrbitCnt <= '0';
--                    if(orbit_cnt >= Readout_rate) then
--                        current_rq <= requestch0;
--                    else
--                        current_rq <= idle;
--                    end if;
                
                when requestch0=>
                
                    s_end_of_readout<='0';
                    DataCh <= DataCh;
                    if (Integ1_EndOfRead='1') then
                        Integ1_EndOfReadi <= '1';
                    end if;
                    if (Integ2_EndOfRead='1') then
                        Integ2_EndOfReadi <= '1';
                    end if;
                    stateA <= x"2";
                    Integ1_request <= x"8000"; 
                    Integ2_request <= x"8000";
--                        ResetOrbitCnt <= '0';
                    if(Integ1_EndOfReadi ='1' and Integ2_EndOfReadi='1') then
                        current_rq <=endch0;
                    else
                        current_rq <= requestch0;
                    end if;
                    
                when endch0 =>
                    s_end_of_readout<='0';
                    DataCh(0) <= Integ1_data_out;
                    DataCh(3) <= Integ2_data_out;
                
                    if (Integ1_EndOfRead='0') then
                        Integ1_EndOfReadi <= '0';
                    end if;
                    if (Integ2_EndOfRead='0') then
                        Integ2_EndOfReadi <= '0';
                    end if;
                    stateA <= x"3";
                    Integ1_request <= x"0000"; 
                    Integ2_request <= x"0000";
--                        ResetOrbitCnt <= '0';
                    if(Integ1_EndOfReadi ='0' and Integ2_EndOfReadi='0') then
                        current_rq <=requestch1;
                    else
                        current_rq <= endch0;
                    end if;
                    
                when requestch1=> 
                    s_end_of_readout<='0';
                    DataCh <= DataCh;
                    if (Integ1_EndOfRead='1') then
                        Integ1_EndOfReadi <= '1';
                    end if;
                    if (Integ2_EndOfRead='1') then
                        Integ2_EndOfReadi <= '1';
                    end if;
                    stateA <= x"4";
                    Integ1_request <= x"8001"; 
                    Integ2_request <= x"8001";
--                        ResetOrbitCnt <= '0';
                    if( Integ1_EndOfReadi ='1' and Integ2_EndOfReadi='1') then
                        current_rq <=endch1;
                    else
                        current_rq <= requestch1;
                    end if;
                    
                when endch1 =>
                    s_end_of_readout<='0';
                    DataCh(1) <= Integ1_data_out;
                    DataCh(4) <= Integ2_data_out;
                    if (Integ1_EndOfRead='0') then
                        Integ1_EndOfReadi <= '0';
                    end if;
                    if (Integ2_EndOfRead='0') then
                        Integ2_EndOfReadi <= '0';
                    end if;
                    stateA <= x"5";
                    Integ1_request <= x"0000"; 
                    Integ2_request <= x"0000";
--                        ResetOrbitCnt <= '0';
                    if(Integ1_EndOfReadi ='0' and Integ2_EndOfReadi='0') then
                        current_rq <=requestch2;
                    else
                        current_rq <= endch1;
                    end if;
                    
                when requestch2 =>
                    s_end_of_readout<='0';
                    DataCh <= DataCh;
                    if (Integ1_EndOfRead='1') then
                        Integ1_EndOfReadi <= '1';
                    end if;
                    if (Integ2_EndOfRead='1') then
                        Integ2_EndOfReadi <= '1';
                    end if;
                    stateA <= x"6";
                    Integ1_request <= x"8002"; 
                    Integ2_request <= x"8002";
--                        ResetOrbitCnt <= '0';
                    if( Integ1_EndOfReadi ='1' and Integ2_EndOfReadi='1') then
                        current_rq <=endch2;
                    else
                        current_rq <= requestch2;
                    end if;
        
                when endch2 =>
                    
                    DataCh(2) <= Integ1_data_out;
                    DataCh(5) <= Integ2_data_out;
                    if (Integ1_EndOfRead='0') then
                        Integ1_EndOfReadi <= '0';
                    end if;
                    if (Integ2_EndOfRead='0') then
                        Integ2_EndOfReadi <= '0';
                    end if;
                    stateA <= x"f";
                    Integ1_request <= x"0000"; 
                    Integ2_request <= x"0000";
--                        ResetOrbitCnt <= '1';
                    if(Integ1_EndOfReadi ='0' and Integ2_EndOfReadi='0') then
                        current_rq <=idle;
                        s_bc_count_readout_reg<=std_logic_vector(unsigned(s_bc_count_readout)+1);
                        s_end_of_readout<='1';
                    else
                        current_rq <= endch2;
                        s_end_of_readout<='0';
                    end if;
            end case;
        end if;    
    end process;

end Behavioral;
