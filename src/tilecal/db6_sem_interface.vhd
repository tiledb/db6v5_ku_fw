----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.01.2023 13:37:42
-- Design Name: 
-- Module Name: db6_sem_interface - Behavioral
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


library tilecal;
use tilecal.db6_design_package.all;
library xilinx;


entity db6_sem_interface is
  Port (
            p_clknet_in                        : in t_db_clknet;
            p_master_reset_in       : in std_logic;
            p_db_reg_rx_in  : in t_db_reg_rx;
            p_sem_interface_out : out t_db6_sem_interface;
            p_sem_uart_tx_out : out std_logic;
            p_sem_uart_rx_in : in std_logic
   );
end db6_sem_interface;

architecture Behavioral of db6_sem_interface is


component sem_ultra_example_design
port (
    clk : in std_logic;

    -- Status interface
    p_status_heartbeat           : out std_logic;
    p_status_initialization      : out std_logic;
    p_status_observation         : out std_logic;
    p_status_correction          : out std_logic;
    p_status_classification      : out std_logic;
    p_status_injection           : out std_logic;
    p_status_diagnostic_scan     : out std_logic;
    p_status_detect_only         : out std_logic;
    p_status_essential           : out std_logic;
    p_status_uncorrectable       : out std_logic;

    p_command_code               : in std_logic_vector(39 downto 0);
    p_command_strobe             : in std_logic;
    p_command_busy               : out std_logic;

    p_status_halt                : out std_logic;
    p_status_irregular_sticky    : out std_logic;
    p_heartbeat_timeout_sticky   : out std_logic;
    p_heartbeat_timeout          : out std_logic;

    uart_tx                      : out std_logic;
    uart_rx                      : in std_logic;

    p_monitor_txdata             : out std_logic_vector(7 downto 0);
    p_monitor_txfull             : out std_logic;
    p_monitor_rxdata             : out std_logic_vector(7 downto 0);
    p_monitor_rxempty            : out std_logic;

    p_icap_clk                   : out std_logic;

    -- ICAP arbitration interface
    p_cap_rel                   : in std_logic;
    p_cap_gnt                   : in std_logic;
    p_cap_req                   : out std_logic
);
end component;

signal s_command_code : std_logic_vector(39 downto 0);
signal s_command_strobe : std_logic;
signal s_sem_interface : t_sem_interface;
signal s_command_strobe_buffer : std_logic; 


begin

p_sem_uart_tx_out<=s_sem_interface.uart_tx;
s_sem_interface.uart_rx<=p_sem_uart_rx_in;

i_db6_sem_interpreter : entity tilecal.db6_sem_interpreter
    port map (
        p_clknet_in                        => p_clknet_in,
        p_sem_interface_in => s_sem_interface,
        p_sem_interpreter_out   => p_sem_interface_out.sem_interpreter
   );
   
   
proc_cdc: process(p_clknet_in.cfgbus_clk40, p_master_reset_in)
begin
   
    if rising_edge(p_clknet_in.cfgbus_clk40) then

        p_sem_interface_out.sem_interface <= s_sem_interface;

    end if;
end process;

proc_sem_cfgbus_control: process(p_clknet_in.cfgbus_clk40, p_master_reset_in)
begin
    if p_master_reset_in = '1' then
        s_sem_interface.cap_gnt<='0';
    elsif rising_edge(p_clknet_in.cfgbus_clk40) then
        
            s_sem_interface.command_strobe <=s_command_strobe;
            s_sem_interface.command_code <=s_command_code;
            
            if p_db_reg_rx_in(cfb_sem_control)(c_sem_20bit_word_mux_bit) = '0' then
                s_command_code(19 downto 0)<=p_db_reg_rx_in(cfb_sem_control)(19 downto 0);
            else
                s_command_code(39 downto 20)<=p_db_reg_rx_in(cfb_sem_control)(19 downto 0);
            end if;
            s_command_strobe <= p_db_reg_rx_in(cfb_sem_control)(c_sem_command_strobe_bit);
            s_sem_interface.cap_gnt<=p_db_reg_rx_in(cfb_sem_control)(c_sem_cap_gnt_bit);
            s_sem_interface.cap_rel<=p_db_reg_rx_in(cfb_sem_control)(c_sem_cap_rel_bit);
    end if;
end process;

i_db6_sem_interface : sem_ultra_example_design
    port map (
  clk => p_clknet_in.osc_clk40,
-- Status interface
  p_status_heartbeat => s_sem_interface.status_heartbeat,
  p_status_initialization => s_sem_interface.status_initialization,
  p_status_observation => s_sem_interface.status_observation,
  p_status_correction => s_sem_interface.status_correction,
  p_status_classification => s_sem_interface.status_classification,
  p_status_injection => s_sem_interface.status_injection,
  p_status_diagnostic_scan => s_sem_interface.status_diagnostic_scan,
  p_status_detect_only => s_sem_interface.status_detect_only,  
  p_status_essential => s_sem_interface.status_essential,
  p_status_uncorrectable => s_sem_interface.status_uncorrectable,

-- UART interface
  uart_tx => s_sem_interface.uart_tx,
  uart_rx => s_sem_interface.uart_rx,

-- Command interface
  p_command_strobe => s_command_strobe,-- s_sem_interface.command_strobe,
  p_command_busy => s_sem_interface.command_busy,
  p_command_code => s_command_code, --s_sem_interface.command_code
  
  p_icap_clk => s_sem_interface.icap_clk_out,

--ICAP arbitration interface
  p_cap_rel => s_sem_interface.cap_rel,
  p_cap_gnt => s_sem_interface.cap_gnt,
  p_cap_req => s_sem_interface.cap_req
  );




end Behavioral;
