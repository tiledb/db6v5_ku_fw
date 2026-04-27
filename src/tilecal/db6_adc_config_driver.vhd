--=================================================================================================--
--##################################   Module Information   #######################################--
--=================================================================================================--
--                                                                                         
-- Company:               Stockholm University                                                        
-- Engineer:              Eduardo Valdes Santurio eduardo.valdes@cern.ch, eduardo.valdes@fysik.su.se
--                                                                                                 
-- Project Name:          Register Config module for the ADC deserializer for LTC2264-12                                                                
-- Module Name:           ADC_top                                        
--                                                                                                 
-- Language:              VHDL                                                                 
--                                                                                                   --
--
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--

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




entity db6_adc_config_driver is
  generic (
    g_bitclk        : integer := 280
    );
  Port ( 
        p_master_reset_in       : in std_logic;
        p_clknet_in 			: in  t_db_clknet;

        p_adc_register_config_from_readout_in : in t_adc_register_config;
        p_adc_register_config_from_configbus_in   : in t_adc_register_config;

        p_mb_config_trigger_out   : out std_logic;
        p_mb_config_done_in   : in t_mb_std_logic;
        p_adc_config_done_out   : out std_logic;
        p_fe_data_in           : in std_logic_vector(31 downto 0);
        p_fe_data_out           : out std_logic_vector(31 downto 0);
        p_leds_out              : out std_logic_vector(3 downto 0)        
  
  );
end db6_adc_config_driver;


architecture Behavioral of db6_adc_config_driver is

signal s_fe_data : std_logic_vector(31 downto 0):=(others=> '0');
signal s_adcs_config_flag : std_logic;

--signal s_adc_register_config_buffer : t_adc_register_config := c_adc_register_init_config;
signal s_adc_registers_buffer_default, s_adc_registers_buffer : t_adc_registers := c_adc_registers_init_14_bit;
signal s_mb_fpga_buffer : std_logic_vector(2 downto 0) := "100";
signal s_mb_pmt_buffer : std_logic_vector(1 downto 0):= "11";
signal s_mb_config_trigger, s_mb_config_trigger_reg: std_logic;

signal s_mb_config_done_buffer : t_mb_std_logic;
type t_adc_config_sm is (st_reset_adc, st_limbo, st_config_reg1, st_config_reg2,st_config_reg3, st_config_reg4, st_trigger_debounce, st_idle);
signal s_adc_config_st, s_next_st : t_adc_config_sm := st_idle;

signal s_leds : std_logic_vector(3 downto 0);

COMPONENT vio_adc_config_driver_status_control
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in15 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe_in16 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

begin

proc_mux_control : process(s_adcs_config_flag)
begin
    if s_adcs_config_flag = '0' then
        p_fe_data_out <= s_fe_data;
    else
        p_fe_data_out <= p_fe_data_in;
    end if;
end process;

p_adc_config_done_out <= s_adcs_config_flag;
p_leds_out <= s_leds;
--p_mb_config_trigger_out <= s_mb_config_trigger;

g_adc_registers_init_bitclk280 : if g_bitclk = 280 generate
    s_adc_registers_buffer_default <= c_adc_registers_init_14_bit;
end generate;
g_adc_registers_init_bitclk240 : if g_bitclk = 240 generate
    s_adc_registers_buffer_default <= c_adc_registers_init_12_bit;
end generate;


proc_config_mb_adc : process(p_clknet_in.cfgbus_clk40, p_master_reset_in)
--type t_adc_config_sm is (st_reset_adc, st_limbo, st_config_reg1, st_config_reg2,st_config_reg3, st_config_reg4, st_trigger_debounce, st_idle);
--variable v_adc_config_st, v_next_st : t_adc_config_sm := st_idle;
variable v_counter	: integer :=0;--:unsigned(31 downto 0):= (others=>'0');
begin
                
    if p_master_reset_in = '1' then
        s_fe_data(31 downto 24)    <= x"00"; --non used
        s_fe_data(23 downto 21)     <= "000"; --trigger action: 23 - T, 22 - E, 21 - R
        s_fe_data(20 downto 18)     <= "000"; --fpga select: 100 - all, 000 - A0, 001 - A1, ...
        s_fe_data(17 downto 16)     <= "00"; -- Tube select: 00 - tube 1, ... 11 - all tubes 
        s_fe_data(15 downto 13)     <= "000"; -- command?
        s_fe_data(12 downto 8)     <= "00000"; -- address
        s_fe_data(7 downto 0)         <= x"00"; -- data
        v_counter    :=0;--:= (others=>'0');            
        s_adc_config_st    <= st_reset_adc;    
        s_adcs_config_flag <= '0';
        s_mb_fpga_buffer <= "100";
        s_mb_pmt_buffer <= "11";
        s_adc_registers_buffer <= s_adc_registers_buffer_default;
        
    elsif rising_edge(p_clknet_in.cfgbus_clk40) then
        s_mb_config_trigger_reg<=s_mb_config_trigger;
        if s_mb_config_trigger_reg='0' and s_mb_config_trigger='1' then
            p_mb_config_trigger_out<='1';
        else
            p_mb_config_trigger_out<='0';
        end if;
    
        s_mb_config_done_buffer<=p_mb_config_done_in;        
        case s_adc_config_st is
            when st_limbo =>
            s_adcs_config_flag <= '0';
            s_fe_data(31 downto 24)    <= x"00"; --non used
            s_fe_data(23 downto 21)     <= "000"; --trigger action: 23 - T, 22 - E, 21 - R
            s_fe_data(20 downto 18)     <= "000"; --fpga select: 100 - all, 000 - A0, 001 - A1, ...
            s_fe_data(17 downto 16)     <= "00"; -- Tube select: 00 - tube 1, ... 11 - all tubes 
            s_fe_data(15 downto 13)     <= "000"; -- command?
            s_fe_data(12 downto 8)     <= "00000"; -- address
            s_fe_data(7 downto 0)         <= x"00"; -- data


            if v_counter = 20000000
                then
                v_counter   :=0;-- := (others=>'0');            
                s_adc_config_st    <= s_next_st;
            else
                v_counter := v_counter + 1;
            end if;                        
            when st_reset_adc =>
                s_adcs_config_flag <= '0';
                s_fe_data(31 downto 24)    <= x"00"; --non used
                s_fe_data(23 downto 21)     <= "100"; --trigger action: 23 - T, 22 - E, 21 - R
                s_fe_data(20 downto 18)     <= s_mb_fpga_buffer;--"100"; --fpga select: 100 - all, 000 - A0, 001 - A1, ...
                s_fe_data(17 downto 16)     <= s_mb_pmt_buffer;--"11"; -- Tube select: 00 - tube 1, ... 11 - all tubes 
                s_fe_data(15 downto 13)     <= "011"; -- command?
                s_fe_data(12 downto 8)     <= "00000"; -- address
            
                
                s_fe_data(7 downto 0)         <= s_adc_registers_buffer(0);--x"00";--s_adc_registers(0);--x"80"; -- data (re0 0 bit 7 resets the adcs)
                s_next_st <= st_config_reg1;
                
                if (s_mb_config_done_buffer.q0 = '1' and p_mb_config_done_in.q0 = '1')
                    --or (s_mb_config_done_buffer.q1 = '1' and p_mb_config_done_in.q1 = '0') 
                    or v_counter = 20000000
                    then
                    s_adc_config_st    <= st_limbo;
                    v_counter:=0;
                    s_mb_config_trigger<='0';
                else
                    v_counter:=v_counter+1;
                    s_mb_config_trigger<='1';
                end if;
                s_leds <= "0000";
                
            when st_config_reg1 =>
                s_adcs_config_flag <= '0'; 
                s_fe_data(31 downto 24)    <= x"00"; --non used
                s_fe_data(23 downto 21)     <= "100"; --trigger action: 23 - T, 22 - E, 21 - R
                s_fe_data(20 downto 18)     <= s_mb_fpga_buffer;--"100"; --fpga select: 100 - all, 000 - A0, 001 - A1, ...
                s_fe_data(17 downto 16)     <= s_mb_pmt_buffer;--"11"; -- Tube select: 00 - tube 1, ... 11 - all tubes 
                s_fe_data(15 downto 13)     <= "100"; -- command?
                s_fe_data(12 downto 8)     <= "00001"; -- address
                s_fe_data(7 downto 0)         <= s_adc_registers_buffer(1); --s_adc_registers(1);--x"00"; -- data (re0 0 bit 7 resets the adcs)
                s_next_st <= st_config_reg2;
                if (s_mb_config_done_buffer.q0 = '1' and p_mb_config_done_in.q0 = '1')
                    --or (s_mb_config_done_buffer.q1 = '1' and p_mb_config_done_in.q1 = '0')
                    or v_counter = 20000000
                    then
                    s_adc_config_st    <= st_limbo;
                    s_mb_config_trigger<='0';
                    v_counter:=0;
                else
                    v_counter:=v_counter+1;
                    s_mb_config_trigger<='1';
                end if;
                
                s_leds <= "0001";
            when st_config_reg2 =>
                s_adcs_config_flag <= '0'; 
                s_fe_data(31 downto 24)    <= x"00"; --non used
                s_fe_data(23 downto 21)     <= "100"; --trigger action: 23 - T, 22 - E, 21 - R
                s_fe_data(20 downto 18)     <= s_mb_fpga_buffer;--"100"; --fpga select: 100 - all, 000 - A0, 001 - A1, ...
                s_fe_data(17 downto 16)     <= s_mb_pmt_buffer;--"11"; -- Tube select: 00 - tube 1, ... 11 - all tubes 
                s_fe_data(15 downto 13)     <= "100"; -- command?
                s_fe_data(12 downto 8)     <= "00010"; -- address
                s_fe_data(7 downto 0)         <= s_adc_registers_buffer(2);--s_adc_registers(2);--x"b5"; -- data (re0 0 bit 7 resets the adcs)
                s_next_st<= st_config_reg3;
                if (s_mb_config_done_buffer.q0 = '1' and p_mb_config_done_in.q0 = '1')
                    --or (s_mb_config_done_buffer.q1 = '1' and p_mb_config_done_in.q1 = '0')
                    or v_counter = 20000000
                    then
                    s_adc_config_st    <= st_limbo;
                    s_mb_config_trigger<='0';
                    v_counter:=0;
                else
                    v_counter:=v_counter+1;
                    s_mb_config_trigger<='1';
                end if;
                s_leds <= "0011";
                
            when st_config_reg3 => 
                s_adcs_config_flag <= '0'; 
                s_fe_data(31 downto 24)    <= x"00";                    
                s_fe_data(23 downto 21)     <= "100";
                s_fe_data(20 downto 18)     <= s_mb_fpga_buffer;--"100";
                s_fe_data(17 downto 16)     <= s_mb_pmt_buffer;--"11";
                s_fe_data(15 downto 13)     <= "100";
                s_fe_data(12 downto 8)     <= "00011";
                s_fe_data(7 downto 0)         <= s_adc_registers_buffer(3);--s_adc_registers(3);-- x"b5";
                s_next_st<= st_config_reg4;
                if (s_mb_config_done_buffer.q0 = '1' and p_mb_config_done_in.q0 = '1')
                    --or (s_mb_config_done_buffer.q1 = '1' and p_mb_config_done_in.q1 = '0')
                    or v_counter = 20000000
                    then
                    s_adc_config_st    <= st_limbo;
                    s_mb_config_trigger<='0';
                    v_counter:=0;
                else
                    v_counter:=v_counter+1;
                    s_mb_config_trigger<='1';
                end if;
                s_leds <= "0111";
                
            when st_config_reg4 => 
                s_adcs_config_flag <= '0'; 
                s_fe_data(31 downto 24)    <= x"00";                    
                s_fe_data(23 downto 21)     <= "100";
                s_fe_data(20 downto 18)     <= s_mb_fpga_buffer;--"100";
                s_fe_data(17 downto 16)     <= s_mb_pmt_buffer;--"11";
                s_fe_data(15 downto 13)     <= "100";
                s_fe_data(12 downto 8)     <= "00100";
                s_fe_data(7 downto 0)         <= s_adc_registers_buffer(4);--s_adc_registers(4); --x"b5";
                s_next_st<= st_trigger_debounce;
                if (s_mb_config_done_buffer.q0 = '1' and p_mb_config_done_in.q0 = '1')
                    --or (s_mb_config_done_buffer.q1 = '1' and p_mb_config_done_in.q1 = '0')
                    or v_counter = 20000000
                    then
                    s_adc_config_st    <= st_limbo;
                    s_mb_config_trigger<='0';
                    v_counter:=0;
                else
                    v_counter:=v_counter+1;
                    s_mb_config_trigger<='1';
                end if;
                s_leds <= "1111";
            
            when st_trigger_debounce =>
                s_adcs_config_flag <= '0';
                if p_adc_register_config_from_readout_in.trigger_mb_adc_config = '0' and p_adc_register_config_from_configbus_in.trigger_mb_adc_config = '0' then
                    s_adc_config_st    <= st_idle;
                end if;
            
            when st_idle => 
                
                s_adc_config_st    <= st_idle;
                
                if p_adc_register_config_from_readout_in.mode = '0' then
                    s_leds <= "0110";                            
                    s_adc_registers_buffer <= p_adc_register_config_from_configbus_in.adc_registers; 
    
                    s_mb_fpga_buffer <=  p_adc_register_config_from_configbus_in.mb_fpga_select;
                    s_mb_pmt_buffer <=  p_adc_register_config_from_configbus_in.mb_pmt_select;
                      
                   
                    if p_adc_register_config_from_configbus_in.trigger_mb_adc_config = '1' then
                        s_fe_data(31 downto 24)    <= x"00"; --non used
                        s_fe_data(23 downto 21)     <= "000"; --trigger action: 23 - T, 22 - E, 21 - R
                        s_fe_data(20 downto 18)     <= "000"; --fpga select: 100 - all, 000 - A0, 001 - A1, ...
                        s_fe_data(17 downto 16)     <= "00"; -- Tube select: 00 - tube 1, ... 11 - all tubes 
                        s_fe_data(15 downto 13)     <= "000"; -- command?
                        s_fe_data(12 downto 8)     <= "00000"; -- address
                        s_fe_data(7 downto 0)         <= x"00"; -- data
                        v_counter    :=0;--:= (others=>'0');            
                        s_adc_config_st    <= st_reset_adc;    
                        s_adcs_config_flag <= '0';
                    else
                        s_adcs_config_flag <= '1';
                        --s_fe_data <= p_fe_data_in;
                    end if;
    
                else
                    s_leds <= "0111";
                        
                    s_mb_fpga_buffer <= p_adc_register_config_from_readout_in.mb_fpga_select;
                    s_mb_pmt_buffer <= p_adc_register_config_from_readout_in.mb_pmt_select;
                    s_adc_registers_buffer <= p_adc_register_config_from_readout_in.adc_registers;
                    
                    if p_adc_register_config_from_readout_in.trigger_mb_adc_config = '1' then
                        s_fe_data(31 downto 24)    <= x"00"; --non used
                        s_fe_data(23 downto 21)     <= "000"; --trigger action: 23 - T, 22 - E, 21 - R
                        s_fe_data(20 downto 18)     <= "000"; --fpga select: 100 - all, 000 - A0, 001 - A1, ...
                        s_fe_data(17 downto 16)     <= "00"; -- Tube select: 00 - tube 1, ... 11 - all tubes 
                        s_fe_data(15 downto 13)     <= "000"; -- command?
                        s_fe_data(12 downto 8)     <= "00000"; -- address
                        s_fe_data(7 downto 0)         <= x"00"; -- data
                        v_counter    :=0;--:= (others=>'0');            
                        s_adc_config_st    <= st_reset_adc;    
                        s_adcs_config_flag <= '0';
                    else
                        s_adcs_config_flag <= '1';
                        --s_fe_data <= p_fe_data_in;
                    end if;
         
                end if;
                
                
    
                
            when others => 
                s_fe_data(31 downto 24)	<= x"00";					
                s_fe_data(23 downto 21) 	<= "000";
                s_fe_data(20 downto 18) 	<= "000";
                s_fe_data(17 downto 16) 	<= "00";
                s_fe_data(15 downto 13) 	<= "000";
                s_fe_data(12 downto 8) 	<= "00000";
                s_fe_data(7 downto 0) 		<= x"00";
                s_adc_config_st	<= st_reset_adc;
                s_adcs_config_flag <= '1';
        end case;
    end if;

    
    
end process;

--i_vio_adc_config_driver_status_control : vio_adc_config_driver_status_control
--  PORT MAP (
--    clk => p_clknet_in.osc_clk40,
--    probe_in0(0) => s_adcs_config_flag,
--    probe_in1 => s_adc_registers_buffer(0),
--    probe_in2 => s_adc_registers_buffer(1),
--    probe_in3 => s_adc_registers_buffer(2),
--    probe_in4 => s_adc_registers_buffer(3),
--    probe_in5 => s_adc_registers_buffer(4),
--    probe_in6 => s_fe_data(31 downto 24),
--    probe_in7 => s_fe_data(23 downto 21),
--    probe_in8 => s_fe_data(20 downto 18),
--    probe_in9 => s_fe_data(17 downto 16),
--    probe_in10 => s_fe_data(15 downto 13),
--    probe_in11 => s_fe_data(12 downto 8),
--    probe_in12 => s_fe_data(7 downto 0),
--    probe_in13 => s_leds,
--    probe_in14(0) => s_adcs_config_flag,
--    probe_in15(0) => s_mb_config_done_buffer.q0,
--    probe_in15(1) => s_mb_config_done_buffer.q1,
--    probe_in16(0) => s_mb_config_trigger
    
--  );


end Behavioral;

