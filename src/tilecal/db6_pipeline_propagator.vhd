----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/15/2024 03:27:20 AM
-- Design Name: 
-- Module Name: db6_pipeline_propagator - Behavioral
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

entity db6_pipeline_propagator is
    generic(
           g_pipeline_stages : integer :=0;
           g_pipeline_item_lenght : integer:=1
    );
    Port ( p_clk_in : in STD_LOGIC;
           p_pipeline_in : in std_logic_vector(g_pipeline_item_lenght-1 downto 0);
           p_pipeline_out : out std_logic_vector(g_pipeline_item_lenght-1 downto 0));
end db6_pipeline_propagator;

architecture Behavioral of db6_pipeline_propagator is
type t_pipeline is array (0 to g_pipeline_stages-1) of std_logic_vector(g_pipeline_item_lenght-1 downto 0);
signal s_pipeline : t_pipeline;
begin

    gen_0_pipeline_stages: if g_pipeline_stages = 0 generate
        p_pipeline_out <= p_pipeline_in;
    end generate;

    gen_1_pipeline_stages: if g_pipeline_stages = 1 generate
        proc_pipeline: process(p_clk_in)
        begin
            if rising_edge(p_clk_in) then
                p_pipeline_out <= p_pipeline_in;
            end if;
        end process;
    end generate;

    gen_x_pipeline_stages: if g_pipeline_stages > 1 generate
        p_pipeline_out<=s_pipeline(g_pipeline_stages-1);
        proc_pipeline: process(p_clk_in)
        begin
            if rising_edge(p_clk_in) then
                for s in 1 to g_pipeline_stages-1 loop
                    s_pipeline(s)<= s_pipeline(s-1); 
                    s_pipeline(0)<=p_pipeline_in;
                end loop;
            end if;
        end process;
    end generate;

end Behavioral;
