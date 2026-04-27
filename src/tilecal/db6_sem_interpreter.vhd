----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/30/2022 03:24:32 AM
-- Design Name: 
-- Module Name: db6_sem_interpreter - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_sem_interpreter is
  Port (
        p_clknet_in                        : in t_db_clknet;
        p_sem_interface_in : in t_sem_interface;
        p_sem_interpreter_out   : out t_sem_interpreter
   );
end db6_sem_interpreter;

architecture Behavioral of db6_sem_interpreter is

signal s_sem_interpreter : t_sem_interpreter;
type t_sem_state is (st_idle, st_init, st_obs, st_correct, st_class, st_inject, st_det_only, st_diag_scan);
signal s_sem_state, s_sem_last_state : t_sem_state := st_idle;
signal s_error_injected, s_error_total, s_error_corrected, s_error_uncorrectable : integer := 0;



begin
p_sem_interpreter_out <= s_sem_interpreter;

p_sem_monitor : process (p_clknet_in.cfgbus_clk40)
--    variable v_error_injected, v_error_total, v_error_corrected, v_error_uncorrectable : integer := 0;
--    type t_sem_state is (st_idle, st_init, st_obs, st_correct, st_class, st_inject, st_det_only, st_diag_scan);
--    variable v_sem_state, v_sem_last_state : t_sem_state := st_idle;
     
begin
    if rising_edge (p_clknet_in.cfgbus_clk40) then
        s_sem_last_state <= s_sem_state;
        
        if p_sem_interface_in.status_initialization = '1' then
            s_sem_state <= st_init;
        elsif p_sem_interface_in.status_observation = '1' then
            s_sem_state <= st_obs;
        elsif p_sem_interface_in.status_correction = '1' then
            s_sem_state <= st_correct;
        elsif p_sem_interface_in.status_classification = '1' then
            s_sem_state <= st_class;
        elsif p_sem_interface_in.status_injection = '1' then
            s_sem_state <= st_inject;
        --elsif p_basys3_seu_sem_sem_example.status_detect_only = '1' then
        --    v_sem_state := st_det_only;
        --elsif p_basys3_seu_sem_sem_example.status_diagnostic_scan = '1' then
        --   v_sem_state := st_diag_scan;
        else
            s_sem_state <= st_idle;  
        end if;  
    
        case s_sem_last_state is
            when st_inject =>
                if s_sem_state = st_idle then 
                    s_error_injected <= s_error_injected+1;
                end if;
            
            when st_obs =>
                if s_sem_state = st_correct then
                    s_error_total <= s_error_total + 1;
                end if;
                
            when st_class =>
                if s_sem_state = st_obs then
                    s_error_corrected <= s_error_corrected + 1;
                end if;
                if s_sem_state = st_idle then
                    s_error_uncorrectable <= s_error_uncorrectable+1;
                end if;
            when others =>  -- Idle state
                null;
        end case;
    end if; 
    
    s_sem_interpreter.total_errors <= std_logic_vector(to_unsigned(s_error_total, s_sem_interpreter.total_errors'length)); 
    s_sem_interpreter.correctable_errors <= std_logic_vector(to_unsigned(s_error_corrected, s_sem_interpreter.correctable_errors'length));
    s_sem_interpreter.uncorrectable_errors <= std_logic_vector(to_unsigned(s_error_uncorrectable, s_sem_interpreter.uncorrectable_errors'length));
    s_sem_interpreter.injected_errors <= std_logic_vector(to_unsigned(s_error_injected, s_sem_interpreter.injected_errors'length));
    s_sem_interpreter.sem_fatal_error <= p_sem_interface_in.status_classification and 
                                            p_sem_interface_in.status_observation and
                                            p_sem_interface_in.status_correction and
                                            p_sem_interface_in.status_essential;
                                            
end process;






end Behavioral;

--constant c_gnd : std_logic :='0';
--type t_sem_control is record 
    
--    status_heartbeat : std_logic;
--    status_initialization : std_logic;
--    status_observation : std_logic;
--    status_correction : std_logic;
--    status_classification : std_logic;
--    status_injection : std_logic;
--    status_diagnostic_scan : std_logic;
--    status_detect_only : std_logic;
--    status_essential : std_logic;
--    status_uncorrectable : std_logic;
    
--    total_errors : std_logic_vector(31 downto 0);
--    correctable_errors : std_logic_vector(31 downto 0);
--    uncorrectable_errors : std_logic_vector(31 downto 0);
--    injected_errors : std_logic_vector(31 downto 0);
    
--end record;
--signal s_sem_control : t_sem_control;





--i_piro_sem : entity tilecal.piro_sem_support_wrapper
--port map
--(
--    p_clk_in => p_clk_in,
    
--    p_status_heartbeat_out => s_sem_control.status_heartbeat,
--    p_status_initialization_out => s_sem_control.status_initialization,
--    p_status_observation_out => s_sem_control.status_observation,
--    p_status_correction_out => s_sem_control.status_correction,
--    p_status_classification_out => s_sem_control.status_classification,
--    p_status_injection_out => s_sem_control.status_injection,
--    p_status_diagnostic_scan_out => s_sem_control.status_diagnostic_scan,
--    p_status_detect_only_out => s_sem_control.status_detect_only,
--    p_status_essential_out => s_sem_control.status_essential,
--    p_status_uncorrectable_out => s_sem_control.status_uncorrectable,
    
    
--    p_uart_tx_out => p_sem_uart_tx_out,
--    p_uart_rx_in => p_sem_uart_rx_in

--);




