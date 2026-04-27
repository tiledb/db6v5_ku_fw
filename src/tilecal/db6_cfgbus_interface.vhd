----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.10.2022 23:49:34
-- Design Name: 
-- Module Name: db6_cfgbus_interface - Behavioral
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

entity db6_cfgbus_interface is
    generic (
        g_tmr_enabled      : natural := 0;        -- 0 = no no_tmr, 1 = tmr
        g_vio_configbus_registers : natural :=0
    );
    Port (     
               p_master_reset_in        : in    std_logic;
               p_clknet_in              : in    t_db_clknet;
               p_cfgbus_data_local_in       : in t_cfgbus_data_in;
--               p_cfgbus_data_remote_in       : in t_cfgbus_data_in;      
               p_gbt_encoder_interface_in         : in t_gbt_encoder_interface;
               
               p_cfgbus_interface : out t_cfgbus_interface;
               
               --p_db_reg_rx_out      : out t_db_reg_rx;
               
               p_bcr_out    : out t_bcr;
               p_leds_out : out std_logic_vector(3 downto 0)
    );

end db6_cfgbus_interface;

architecture Behavioral of db6_cfgbus_interface is

signal s_cfgbus_bitslice_local, s_cfgbus_bitslice_remote : t_cfgbus_bitslice;
signal s_bcr_local, s_bcr_remote : t_bcr;
signal s_db_reg_rx_local, s_db_reg_rx_remote : t_db_reg_rx;

constant c_pipeline_depth : integer := c_global_pipeline_depth;
type t_db_reg_rx_pipeline is array (0 to c_pipeline_depth-1) of t_db_reg_rx;
type t_reg_r_strobe_pipeline is array (0 to c_pipeline_depth-1) of std_logic_vector(31 downto 0);
type t_bcr_pipeline is array(0 to c_pipeline_depth-1) of t_bcr;
signal s_db_reg_rx_pipeline : t_db_reg_rx_pipeline;
signal s_reg_r_strobe_pipeline : t_reg_r_strobe_pipeline; 
signal s_bcr_pipeline : t_bcr_pipeline;
signal s_tmr_error_local, s_tmr_error_remote : std_logic_vector(c_number_of_cfgbus_regs-1 downto 0);  
signal s_reg_rx_strobe_local, s_reg_rx_strobe_remote : std_logic_vector(31 downto 0); --integer range 0 to 15;
begin

p_cfgbus_interface.tmr_error_local <= s_tmr_error_local;
p_cfgbus_interface.tmr_error_remote <= s_tmr_error_remote;

--cfgbus multiplexes

p_bcr_out <= s_bcr_local;
p_cfgbus_interface.db_reg_rx <= s_db_reg_rx_local;
p_cfgbus_interface.reg_rx_strobe<= s_reg_rx_strobe_local;

--p_bcr_out <= s_bcr_pipeline(c_pipeline_depth-1);--s_bcr_local;
--p_cfgbus_interface.db_reg_rx <= s_db_reg_rx_pipeline(c_pipeline_depth-1);-- s_db_reg_rx_fifo(1);--s_db_reg_rx_local;
--p_cfgbus_interface.reg_rx_strobe<= s_reg_r_strobe_pipeline(c_pipeline_depth-1); --s_reg_r_strobe_fifo(1);-- s_reg_rx_strobe_local;

--proc_pipeline : process(p_clknet_in.mmcm_refclk240)
--begin
--    if rising_edge(p_clknet_in.mmcm_refclk240) then
--        for p in 0 to (c_pipeline_depth-1-1) loop
--            s_db_reg_rx_pipeline(p+1)<=s_db_reg_rx_pipeline(p);
--            s_reg_r_strobe_pipeline(p+1)<=s_reg_r_strobe_pipeline(p);
--            s_bcr_pipeline(p+1)<=s_bcr_pipeline(p);

--        end loop;
--        s_db_reg_rx_pipeline(0)<=s_db_reg_rx_local;
--        s_reg_r_strobe_pipeline(0)<=s_reg_rx_strobe_local;
--        s_bcr_pipeline(0)<=s_bcr_local;
--    end if;
--end process;


--i_db6_cfgbus_interface_mux : entity tilecal.db6_cfgbus_interface_mux_wrapper
--    generic map(
--        g_tmr_enabled      => 1        -- 0 = no no_tmr, 1 = tmr
--    )
--    Port map(     
--               p_master_reset_in        => p_master_reset_in,
--               p_clknet_in              => p_clknet_in,

--               p_db_reg_rx_local_in     => s_db_reg_rx_local,
--               p_db_reg_rx_remote_in    => s_db_reg_rx_remote,

--               p_bcr_local_in           => s_bcr_local,
--               p_bcr_remote_in          => s_bcr_remote,

--               p_db_reg_rx_out          => p_cfgbus_interface.db_reg_rx,
--               p_bcr_out                => p_bcr_out,
--               p_leds_out               => open
--    );

--local
db6_cfgbus_interface_io_iddr_local : entity tilecal.db6_cfgbus_interface_io_iddr 
    Port map (     
               p_master_reset_in        => p_master_reset_in,
               p_clknet_in              => p_clknet_in,
               p_iddr_clk_in            => p_clknet_in.cfgbus_clk40_local, --p_clknet_in.clk40, --p_clknet_in.cfgbus_clk40_local,
               p_iddr_freerun_clk_in    => p_clknet_in.osc_clk200,
               p_cfgbus_data_in         => p_cfgbus_data_local_in,
               p_cfgbus_bitslice_out    => s_cfgbus_bitslice_local,
               p_leds_out               => open
    );

db6_cfgbus_interface_decoder_iddr_local : entity tilecal.db6_cfgbus_interface_decoder_iddr_wrapper
    generic map(
        g_tmr_enabled      => g_tmr_enabled,        -- 0 = no no_tmr, 1 = tmr
        g_ila_sync_enabled => 0,
        g_vio_configbus_registers => 0
    )
    Port map (     
               p_master_reset_in        => p_master_reset_in,
               p_clknet_in              => p_clknet_in,
               p_iddr_clk_in            => p_clknet_in.cfgbus_clk40_local, --p_clknet_in.clk40, --p_clknet_in.cfgbus_clk40_local,
               p_cfgbus_bitslice_in     => s_cfgbus_bitslice_local,
               
               p_db_reg_rx_out          => s_db_reg_rx_local,
               p_bcr_out                => s_bcr_local,
               p_reg_rx_strobe_out      => s_reg_rx_strobe_local,
               
               p_tmr_enabled_out        => p_cfgbus_interface.tmr_enabled,
               p_tmr_error_out          => s_tmr_error_local,
               p_leds_out               => open
    );

--remote
--db6_cfgbus_interface_io_iddr_remote : entity tilecal.db6_cfgbus_interface_io_iddr 
--    Port map (     
--               p_master_reset_in        => p_master_reset_in,
--               p_clknet_in              => p_clknet_in,
--               p_iddr_clk_in            => p_clknet_in.cfgbus_clk40_local, --p_clknet_in.clk40, --p_clknet_in.cfgbus_clk40_local, --p_clknet_in.cfgbus_clk40_remote,
--               p_iddr_freerun_clk_in    => p_clknet_in.osc_clk200,
--               p_cfgbus_data_in         => p_cfgbus_data_remote_in,
--               p_cfgbus_bitslice_out    => s_cfgbus_bitslice_remote,
--               p_leds_out               => open
--    );

--db6_cfgbus_interface_decoder_iddr_remote : entity tilecal.db6_cfgbus_interface_decoder_iddr_wrapper
--    generic map(
--        g_tmr_enabled      => 0,        -- 0 = no no_tmr, 1 = tmr
--        g_ila_sync_enabled => 0,
--        g_vio_configbus_registers => 0
--    )
--    Port map (     
--               p_master_reset_in        => p_master_reset_in,
--               p_clknet_in              => p_clknet_in,
--               p_iddr_clk_in            => p_clknet_in.cfgbus_clk40_local, --p_clknet_in.clk40, --p_clknet_in.cfgbus_clk40_local, p_clknet_in.cfgbus_clk40_remote,
--               p_cfgbus_bitslice_in     => s_cfgbus_bitslice_remote,
               
--               p_db_reg_rx_out          => s_db_reg_rx_remote,
--               p_bcr_out                => s_bcr_remote,
               
--               p_tmr_error_out          => s_tmr_error_remote,
--               p_leds_out               => open
--    );



end Behavioral;
