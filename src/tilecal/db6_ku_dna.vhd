----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/19/2024 04:57:22 PM
-- Design Name: 
-- Module Name: db6_ku_dna - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;


entity db6_ku_dna is
    port (
        p_clk_in          : in  std_logic;
        p_reset_in        : in std_logic;
        p_done_out        : out std_logic;
        p_dna_value_out    : out std_logic_vector(95 downto 0)
    );
end entity db6_ku_dna;

architecture Behavioral of db6_ku_dna is
signal s_dout, s_done : std_logic :='0'; 
signal s_shift, s_read : std_logic :='0';
signal s_dna_value_sr, s_dna_value_out : std_logic_vector(95 downto 0);
signal s_counter: integer range 0 to 95;
type t_dna_sm is (st_init, st_load, st_sr, st_done, st_idle );
signal s_dna_sm : t_dna_sm:= st_init; 
begin

i_dna_porte2 : DNA_PORTE2
generic map (
   SIM_DNA_VALUE => X"000000000000000000000000"  -- Specifies a sample 96-bit DNA value for simulation.
)
port map (
   DOUT => s_dout,   -- 1-bit output: DNA output data.
   CLK => p_clk_in,     -- 1-bit input: Clock input.
   DIN => '0',     -- 1-bit input: User data input pin.
   READ => s_read,   -- 1-bit input: Active-High load DNA, active-Low read input.
   SHIFT => s_shift  -- 1-bit input: Active-High shift enable input.
);

p_done_out<=s_done;
p_dna_value_out<=s_dna_value_out;

proc_dna_sm: process(p_clk_in)
begin
    if rising_edge(p_clk_in) then
        case s_dna_sm is
            when st_init=>
                s_done<='0';
                s_counter<=0;
                s_shift<='0';
                
                if p_reset_in = '0' then
                    s_dna_sm<=st_load;
                    s_read<='1';
                else
                    s_read<='0';
                end if;
            when st_load=>
                s_read<='0';
                s_done<='0';
                
                if s_counter = 95 then
                    s_dna_sm<=st_sr;
                    s_counter<=0;
                    s_shift<='1';
                else
                    s_counter<=s_counter+1;
                    s_shift<='0';
                end if;
            when st_sr=>
                s_read<='0';
                s_done<='0';
                s_counter<=s_counter+1;
                s_shift<='1';
                s_dna_value_sr<=s_dout&s_dna_value_sr(95 downto 1);
                if s_counter = 95 then
                    s_dna_sm<=st_done;
                end if;

            when st_done=>
                s_done<='1';
                s_dna_value_out<=s_dna_value_sr;
                s_dna_sm<=st_idle;
                
            when st_idle=>
                if p_reset_in = '1' then
                    s_dna_sm<=st_init;
                end if;            
            when others=>
                s_dna_sm<=st_init;
        end case;
    end if;
end process;


end architecture Behavioral;
