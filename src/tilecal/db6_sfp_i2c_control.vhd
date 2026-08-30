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
    
    -- IOBUF moved to db7_io_box; split O/I/T instead of inout, one pair per SFP.
    p_sda_drive_out : out std_logic_vector(1 downto 0);
    p_sda_tri_out   : out std_logic_vector(1 downto 0);
    p_sda_read_in   : in  std_logic_vector(1 downto 0);
    p_scl_drive_out : out std_logic_vector(1 downto 0);
    p_scl_tri_out   : out std_logic_vector(1 downto 0);
    p_scl_read_in   : in  std_logic_vector(1 downto 0);
    p_sfp_i2c_interface_out : out t_blk_mem_sfp_array;

    -- debug readback: port b of each sfp's reg block ram
    p_rx_register_in  : in  t_sfp_reg_addr_array;
    p_tx_register_out : out t_sfp_reg_data_array;

    -- sff-8472 A2h ddm fields, per side
    p_sfp_ddm_out : out t_sfp_regs_array;
    p_sfp_ddm_read_done_out : out std_logic_vector(1 downto 0)

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
    
    p_sda_drive_out => p_sda_drive_out(i),
    p_sda_tri_out   => p_sda_tri_out(i),
    p_sda_read_in   => p_sda_read_in(i),
    p_scl_drive_out => p_scl_drive_out(i),
    p_scl_tri_out   => p_scl_tri_out(i),
    p_scl_read_in   => p_scl_read_in(i),
    p_sfp_i2c_interface_out    => p_sfp_i2c_interface_out(i),

    p_rx_register_in  => p_rx_register_in(i),
    p_tx_register_out => p_tx_register_out(i),

    p_sfp_ddm_out => p_sfp_ddm_out(i),
    p_sfp_ddm_read_done_out => p_sfp_ddm_read_done_out(i)

    );

end generate;

end Behavioral;
