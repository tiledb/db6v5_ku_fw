----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.01.2023 16:03:37
-- Design Name: 
-- Module Name: db6_gbt_encoder_integrator - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
library tilecal;
use tilecal.db6_design_package.all;

entity db6_gbt_encoder_integrator is
  Port ( 
            p_master_reset_in : std_logic;
            p_clknet_in : in t_db_clknet;
            p_db_reg_rx_in : in t_db_reg_rx;
            
            --interfaces
            p_mb_interface_in : in t_mb_interface;
            
            --integrator processed data
            p_integrator_frame_out : out std_logic_vector(9 downto 0)
  
  );
end db6_gbt_encoder_integrator;

architecture Behavioral of db6_gbt_encoder_integrator is

	type t_integrator_encoder_sm is (st_idle_tx, st_buffer_data, st_transmit_chid_data1, st_transmit_data2_data3, st_transmit_data4_endoftransmit, st_waitbcr);
	signal s_integrator_encoder_sm   : t_integrator_encoder_sm;
    signal s_integrator_channel_id : std_logic_vector(3 downto 0);
    signal s_integrator_frame : std_logic_vector(9 downto 0);
    signal s_mb_integrator : t_mb_integrator;
    signal s_bcr_count_readout, s_bcr_count_readout_reg : std_logic_vector(7 downto 0);
    
    COMPONENT ila_gbt_decoder_integrator

    PORT (
        clk : IN STD_LOGIC;
    
    
    
        probe0 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(9 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END COMPONENT  ;

begin


p_integrator_frame_out <= s_integrator_frame;

proc_integrator_frame_formatter : process(p_clknet_in.cfgbus_clk40, p_master_reset_in) --process(p_clknet_in.refclk40, p_master_reset_in)
begin
    if (p_master_reset_in = '1') or (p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_encoder_reset_bit) = '1') or (p_clknet_in.locked_db = '0') then
        s_integrator_frame <= (others => '0');
        s_integrator_encoder_sm <= st_idle_tx;
        
    elsif rising_edge(p_clknet_in.cfgbus_clk40) then--(p_clknet_in.refclk40) then
        --integrator encoder
        case s_integrator_encoder_sm is
            when st_idle_tx =>

                s_integrator_frame <= "00000" & "00000";
                if (p_mb_interface_in.mb_integrator.end_of_read = '1') then
                    s_integrator_encoder_sm <= st_buffer_data; --st_transmit_chid_data1;
                else
                    s_integrator_encoder_sm <= st_idle_tx;
                end if;
            
            when st_buffer_data =>
                s_mb_integrator <= p_mb_interface_in.mb_integrator;
                s_integrator_encoder_sm <= st_transmit_chid_data1;
                
            when st_transmit_chid_data1 =>
                s_integrator_frame <= "1" & s_integrator_channel_id &  "1" & s_mb_integrator.integrator_adc_data(to_integer(unsigned(s_integrator_channel_id)))(3 downto 0);
                s_integrator_encoder_sm <= st_transmit_data2_data3;
            
            when st_transmit_data2_data3 =>
                s_integrator_frame <= "1" & s_mb_integrator.integrator_adc_data(to_integer(unsigned(s_integrator_channel_id)))(7 downto 4) &  "1" & p_mb_interface_in.mb_integrator.integrator_adc_data(to_integer(unsigned(s_integrator_channel_id)))(11 downto 8);
                s_integrator_encoder_sm <= st_transmit_data4_endoftransmit;
    
            when st_transmit_data4_endoftransmit =>
                s_integrator_frame <= "1" & s_mb_integrator.integrator_adc_data(to_integer(unsigned(s_integrator_channel_id)))(15 downto 12) & "00000";
                
                if(s_integrator_channel_id=x"5") then
                    s_integrator_encoder_sm <= st_waitbcr;
                else
                    s_integrator_channel_id <= std_logic_vector(to_unsigned((to_integer(unsigned(s_integrator_channel_id))) + 1,4));
                    s_integrator_encoder_sm <= st_transmit_chid_data1;
                end if;
                
            when st_waitbcr =>
                s_integrator_channel_id <= "0000";                  
                s_integrator_frame <= "00000" & "00000";
                    if p_clknet_in.bcr.bcr = '1' then
                        s_integrator_encoder_sm <= st_idle_tx;
                    end if;
            when others =>
                s_integrator_encoder_sm <= st_idle_tx;
          
        end case;
    end if;

end process; 
    
--    i_ila_gbt_decoder_integrator : ila_gbt_decoder_integrator
--PORT MAP (
--	clk => p_clknet_in.cfgbus_clk40,--p_clknet_in.bcr.bcr,--p_clknet_in.mmcm_refclk240,


--	probe0 => std_logic_vector(to_unsigned(p_clknet_in.gbt_cdc_counter,2)), 
--	probe1(0) => p_clknet_in.gbt_cdc_phase, 
--	probe2 => s_integrator_frame, 
--	probe3 => s_integrator_channel_id, 
--	probe4(0) => p_clknet_in.bcr.bcr, 
--	probe5(0) => p_mb_interface_in.mb_integrator.end_of_read,
--	probe6 => "0"
--);            
                
end Behavioral;
