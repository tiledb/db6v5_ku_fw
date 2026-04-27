----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.10.2022 03:10:37
-- Design Name: 
-- Module Name: db6_tmr_voter - Behavioral
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

entity db6_tmr_voter_sync is
    generic (
        g_vector_width      : natural := 1
    );
    Port (  
            p_clk_in                       : std_logic;   
            p_std_logic_vector_0_in        : in std_logic_vector(g_vector_width-1 downto 0);
            p_std_logic_vector_1_in        : in std_logic_vector(g_vector_width-1 downto 0);
            p_std_logic_vector_2_in        : in std_logic_vector(g_vector_width-1 downto 0);
            p_tmr_error_out                : out std_logic;
            p_std_logic_vector_out         : out std_logic_vector(g_vector_width-1 downto 0)   
               );
end db6_tmr_voter_sync;

architecture Behavioral of db6_tmr_voter_sync is

begin



    proc_tmr_error : process(p_clk_in)
    begin

        if rising_edge(p_clk_in) then

            p_std_logic_vector_out <=   (p_std_logic_vector_0_in and p_std_logic_vector_1_in) or
                                        (p_std_logic_vector_1_in and p_std_logic_vector_2_in) or
                                        (p_std_logic_vector_2_in and p_std_logic_vector_0_in);
                                        
            if      (p_std_logic_vector_0_in /= p_std_logic_vector_1_in) or
                    (p_std_logic_vector_1_in /= p_std_logic_vector_2_in) or
                    (p_std_logic_vector_2_in /= p_std_logic_vector_0_in) then
                p_tmr_error_out<='1';
            else
                p_tmr_error_out<='0';
            
            end if;
        end if;    
    end process;

end Behavioral;
