----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/31/2024 04:51:52 PM
-- Design Name: 
-- Module Name: db6_sfp_i2c_control - Behavioral
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

entity db6_sfp_i2c_control is
  generic(
    g_sys_clk_freq            : integer := 40_000_000;        --input clock speed from user logic in hz
    g_i2c_clk_freq            : integer := 400_000
    );
  port(
    p_clk_in               : in    std_logic;                                            --system clock
    p_reset_in           : in    std_logic;                                            --asynchronous active-low reset
    
    p_sfp_abs_in                : in std_logic_vector(1 downto 0);
    p_sfp_los_in                : in std_logic_vector(1 downto 0);
    p_sfp_tx_fault_in                : in std_logic_vector(1 downto 0);
    
    p_sfp_i2c_scl_inout 				: inout std_logic_vector(1 downto 0);
    p_sfp_i2c_sda_inout                 : inout std_logic_vector(1 downto 0);
    p_sfp_i2c_interface_out : out t_blk_mem_sfp_array

    );
end db6_sfp_i2c_control;

architecture Behavioral of db6_sfp_i2c_control is

begin


gen_sfp_i2c_interfaces : for i in 0 to 1 generate
i_db6_sfp_i2c_interface : entity tilecal.db6_sfp_i2c_interface
  generic map (
    g_sys_clk_freq => g_sys_clk_freq,        --input clock speed from user logic in hz
    g_i2c_clk_freq => g_i2c_clk_freq
    )
  port map (
    p_clk_in               => p_clk_in, --system clock
    p_reset_in             => '0', --asynchronous active-low reset
    
    p_sfp_abs_in           => p_sfp_abs_in(i),
    p_sfp_los_in           => p_sfp_los_in(i),
    p_sfp_tx_fault_in      => p_sfp_tx_fault_in(i),
    
    p_scl_inout    => p_sfp_i2c_scl_inout(i),
    p_sda_inout    => p_sfp_i2c_sda_inout(i),
    p_sfp_i2c_interface_out    => p_sfp_i2c_interface_out(i)

    );

end generate;

end Behavioral;
