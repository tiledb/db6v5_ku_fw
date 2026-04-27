----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.11.2022 17:51:54
-- Design Name: 
-- Module Name: db6_reset_synchronizer - Behavioral
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

entity db6_reset_synchronizer is
    generic(
           g_clk_steps : integer :=7    
    );
    Port ( p_clk_in : in STD_LOGIC;
           p_reset_in : in STD_LOGIC;
           p_reset_out : out STD_LOGIC);
end db6_reset_synchronizer;

architecture Behavioral of db6_reset_synchronizer is
signal s_reset_register : std_logic_vector(g_clk_steps downto 0):= (others => '0');
signal s_reset : std_logic := '0';
begin



gen_0_clk_steps: if g_clk_steps = 0 generate
    p_reset_out <= p_reset_in;

end generate;

gen_1_clk_steps: if g_clk_steps = 1 generate
    proc_reset : process(p_clk_in, p_reset_in)
    begin
        if p_reset_in = '1' then
            s_reset <= '1';
        elsif rising_edge(p_clk_in) then
            s_reset <= '0';
        end if;
    end process;
end generate;

gen_x_clk_steps: if g_clk_steps > 1 generate
    p_reset_out<=s_reset;
    proc_reset : process(p_clk_in, p_reset_in)
    begin
        if p_reset_in = '1' then
            s_reset_register <= (others => '1');
            s_reset <= '1';
        elsif rising_edge(p_clk_in) then
            for s in 1 to g_clk_steps-1 loop
                s_reset_register(s)<=s_reset_register(s-1);
                s_reset_register(0)<= '0';
            end loop;
            s_reset <= s_reset_register(g_clk_steps-1);
        end if;
    end process;
end generate;


end Behavioral;
