----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Eduardo Valdes
--         : Sam Silverstein
-- 
-- Create Date: 09/05/2020 12:24:37 AM
-- Design Name: 
-- Module Name: db6_system_management_interface - Behavioral
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

entity db6_system_management_interface is
    Port ( 
    p_clknet_in : in t_db_clknet;
    p_master_reset_in : in std_logic;
    p_db_reg_rx_in : in t_db_reg_rx;
    
    --xadc pins to top level
    p_xadc_analog_in : in t_xadc_analog_in;
    p_pgood_in       : in t_p_pgood_in;
    
    
    --output
    p_system_management_interface_out : out t_system_management_interface; 
    
    --leds and debug_out
     p_leds_out : out  std_logic_vector(3 downto 0)
    
    );
end db6_system_management_interface;

architecture Behavioral of db6_system_management_interface is

attribute keep : string;
attribute dont_touch : string;

--https://www.xilinx.com/support/documentation/user_guides/ug580-ultrascale-sysmon.pdf
COMPONENT system_management
  PORT (
    di_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    daddr_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    den_in : IN STD_LOGIC;
    dwe_in : IN STD_LOGIC;
    drdy_out : OUT STD_LOGIC;
    do_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    dclk_in : IN STD_LOGIC;
    reset_in : IN STD_LOGIC;
    vp : IN STD_LOGIC;
    vn : IN STD_LOGIC;
    vauxp0 : IN STD_LOGIC;
    vauxn0 : IN STD_LOGIC;
    vauxp1 : IN STD_LOGIC;
    vauxn1 : IN STD_LOGIC;
    vauxp2 : IN STD_LOGIC;
    vauxn2 : IN STD_LOGIC;
    vauxp3 : IN STD_LOGIC;
    vauxn3 : IN STD_LOGIC;
    vauxp4 : IN STD_LOGIC;
    vauxn4 : IN STD_LOGIC;
    vauxp5 : IN STD_LOGIC;
    vauxn5 : IN STD_LOGIC;
    vauxp6 : IN STD_LOGIC;
    vauxn6 : IN STD_LOGIC;
    vauxp7 : IN STD_LOGIC;
    vauxn7 : IN STD_LOGIC;
    vauxp8 : IN STD_LOGIC;
    vauxn8 : IN STD_LOGIC;
    vauxp9 : IN STD_LOGIC;
    vauxn9 : IN STD_LOGIC;
    vauxp10 : IN STD_LOGIC;
    vauxn10 : IN STD_LOGIC;
    vauxp11 : IN STD_LOGIC;
    vauxn11 : IN STD_LOGIC;
    vauxp12 : IN STD_LOGIC;
    vauxn12 : IN STD_LOGIC;
    vauxp13 : IN STD_LOGIC;
    vauxn13 : IN STD_LOGIC;
    vauxp14 : IN STD_LOGIC;
    vauxn14 : IN STD_LOGIC;
    vauxp15 : IN STD_LOGIC;
    vauxn15 : IN STD_LOGIC;
    user_temp_alarm_out : OUT STD_LOGIC;
    vccint_alarm_out : OUT STD_LOGIC;
    vccaux_alarm_out : OUT STD_LOGIC;
    user_supply0_alarm_out : OUT STD_LOGIC;
    user_supply1_alarm_out : OUT STD_LOGIC;
    user_supply2_alarm_out : OUT STD_LOGIC;
    --user_supply3_alarm_out : OUT STD_LOGIC;
    ot_out : OUT STD_LOGIC;
    channel_out : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    muxaddr_out : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    eoc_out : OUT STD_LOGIC;
    vbram_alarm_out : OUT STD_LOGIC;
    alarm_out : OUT STD_LOGIC;
    eos_out : OUT STD_LOGIC;
    busy_out : OUT STD_LOGIC;
    jtaglocked_out : OUT STD_LOGIC;
    jtagmodified_out : OUT STD_LOGIC;
    jtagbusy_out : OUT STD_LOGIC
    --i2c_sda : INOUT STD_LOGIC;
    --i2c_sclk : INOUT STD_LOGIC
  );
END COMPONENT;

--signal s_xadc_data : t_xadc_data;
--signal s_xadc_voltages : t_xadc_voltages;
--signal s_pgood : t_pgood;
signal s_pgood : std_logic_vector(c_number_of_pgood_channels downto 0);

--debug

--signal s_xadc_mode_debug : std_logic := '1';
--signal s_reset_debug : std_logic;
signal s_xadc_control : t_xadc_control;

attribute keep of s_xadc_control, s_pgood : signal is "true";
attribute dont_touch of s_xadc_control, s_pgood : signal is "true";

signal s_xadc_channel_voltage : std_logic_vector(15 downto 0);
signal s_xadc_channel : std_logic_vector(7 downto 0);

signal s_selected_channel : integer range 0 to 32 := 0; 
type t_sm_xadc_ram_read is (st_set_address, st_wait_for_drdy,st_read_value);
signal sm_xadc_ram_read : t_sm_xadc_ram_read := st_set_address;
signal s_new_conversion : std_logic := '0';
signal s_eoc : std_logic;

--debug

COMPONENT vio_xadc_interface_debug
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in15 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in16 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in17 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in18 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_in19 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;


COMPONENT ila_xadc_debug

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe8 : IN STD_LOGIC_VECTOR(5 DOWNTO 0); 
	probe9 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
	probe10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe14 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
	probe15 : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
);
END COMPONENT  ;

begin

s_xadc_control.dclk_in <= p_clknet_in.cfgbus_clk40;
s_xadc_control.di_in <= (others => '0');

--p_system_management_interface_out.xadc_voltages <= s_xadc_voltages;
p_system_management_interface_out.xadc_channel_voltage <= s_xadc_channel_voltage;

proc_pgood: process(p_clknet_in.cfgbus_clk40)
begin
    if rising_edge(p_clknet_in.cfgbus_clk40) then

--        s_pgood.db_1v2 <= p_pgood_in.db_1v2_5v0;        
--        s_pgood.db_5v0 <= p_pgood_in.db_1v2_5v0;
--        s_pgood.db_3v3 <= p_pgood_in.db_1v5_3v3;
--        s_pgood.db_1v5 <= p_pgood_in.db_1v5_3v3;
--        s_pgood.db_1v0 <= p_pgood_in.db_1v0_0v95;
--        s_pgood.db_0v95 <= p_pgood_in.db_1v0_0v95;
--        s_pgood.db_2v5 <= p_pgood_in.db_1v8_2v5;
--        s_pgood.db_1v8 <= p_pgood_in.db_1v8_2v5;
        
        
--        s_pgood.mb_3v3 <= p_pgood_in.mb_5v0_n_3v3;
--        s_pgood.mb_5v0_n <= p_pgood_in.mb_5v0_n_3v3;
--        s_pgood.mb_5v0 <= p_pgood_in.mb_5v0_1v8;
--        s_pgood.mb_1v8 <= p_pgood_in.mb_5v0_1v8;
--        s_pgood.mb_1v2  <= p_pgood_in.mb_2v5_1v2;
--        s_pgood.mb_2v5  <= p_pgood_in.mb_2v5_1v2;
--        s_pgood.mb_10v0  <= p_pgood_in.mb_10v0;       

        s_pgood(c_pgood_db_1v2_bit) <= p_pgood_in.db_1v2_5v0;
        s_pgood(c_pgood_db_5v0_bit) <= p_pgood_in.db_1v2_5v0;
        s_pgood(c_pgood_db_1v5_bit) <= p_pgood_in.db_1v5_3v3;
        s_pgood(c_pgood_db_3v3_bit) <= p_pgood_in.db_1v5_3v3;
        s_pgood(c_pgood_db_0v95_bit) <= p_pgood_in.db_1v0_0v95;
        s_pgood(c_pgood_db_1v0_bit) <= p_pgood_in.db_1v0_0v95;
        s_pgood(c_pgood_db_1v8_bit) <= p_pgood_in.db_1v8_2v5;
        s_pgood(c_pgood_db_2v5_bit) <= p_pgood_in.db_1v8_2v5;
        s_pgood(c_pgood_mb_3v3_bit) <= p_pgood_in.mb_5v0_n_3v3;
        s_pgood(c_pgood_mb_5v0_n_bit) <= p_pgood_in.mb_5v0_n_3v3;
        s_pgood(c_pgood_mb_5v0_bit) <= p_pgood_in.mb_5v0_1v8;
        s_pgood(c_pgood_mb_1v8_bit) <= p_pgood_in.mb_5v0_1v8;
        s_pgood(c_pgood_mb_1v2_bit) <= p_pgood_in.mb_2v5_1v2;
        s_pgood(c_pgood_mb_2v5_bit) <= p_pgood_in.mb_2v5_1v2;
        s_pgood(c_pgood_mb_10v0_bit) <= p_pgood_in.mb_10v0;

    end if;
end process;



p_system_management_interface_out.p_good <= s_pgood;

p_system_management_interface_out.xadc_control <= s_xadc_control;

i_system_management : system_management
  PORT MAP (
    di_in => s_xadc_control.di_in,
    daddr_in => s_xadc_control.daddr_in,
    den_in => s_xadc_control.den_in,
    dwe_in => s_xadc_control.dwe_in,
    drdy_out => s_xadc_control.drdy_out,
    do_out => s_xadc_control.do_out,
    dclk_in => s_xadc_control.dclk_in,
    reset_in => s_xadc_control.reset_in,
    vp => p_xadc_analog_in.v.p,
    vn => p_xadc_analog_in.v.n,
    vauxp0 => p_xadc_analog_in.vaux0.p,
    vauxn0 => p_xadc_analog_in.vaux0.n,
    vauxp1 => p_xadc_analog_in.vaux1.p,
    vauxn1 => p_xadc_analog_in.vaux1.n,
    vauxp2 => p_xadc_analog_in.vaux2.p,
    vauxn2 => p_xadc_analog_in.vaux2.n,
    vauxp3 => p_xadc_analog_in.vaux3.p,
    vauxn3 => p_xadc_analog_in.vaux3.n,
    vauxp4 => p_xadc_analog_in.vaux4.p,
    vauxn4 => p_xadc_analog_in.vaux4.n,
    vauxp5 => p_xadc_analog_in.vaux5.p,
    vauxn5 => p_xadc_analog_in.vaux5.n,
    vauxp6 => p_xadc_analog_in.vaux6.p,
    vauxn6 => p_xadc_analog_in.vaux6.n,
    vauxp7 => p_xadc_analog_in.vaux7.p,
    vauxn7 => p_xadc_analog_in.vaux7.n,
    vauxp8 => p_xadc_analog_in.vaux8.p,
    vauxn8 => p_xadc_analog_in.vaux8.n,
    vauxp9 => p_xadc_analog_in.vaux9.p,
    vauxn9 => p_xadc_analog_in.vaux9.n,
    vauxp10 => p_xadc_analog_in.vaux10.p,
    vauxn10 => p_xadc_analog_in.vaux10.n,
    vauxp11 => p_xadc_analog_in.vaux11.p,
    vauxn11 => p_xadc_analog_in.vaux11.n,
    vauxp12 => p_xadc_analog_in.vaux12.p,
    vauxn12 => p_xadc_analog_in.vaux12.n,
    vauxp13 => p_xadc_analog_in.vaux13.p,
    vauxn13 => p_xadc_analog_in.vaux13.n,
    vauxp14 => p_xadc_analog_in.vaux14.p,
    vauxn14 => p_xadc_analog_in.vaux14.n,
    vauxp15 => p_xadc_analog_in.vaux15.p,
    vauxn15 => p_xadc_analog_in.vaux15.n,
    user_temp_alarm_out => s_xadc_control.user_temp_alarm_out,
    vccint_alarm_out => s_xadc_control.vccint_alarm_out,
    vccaux_alarm_out => s_xadc_control.vccaux_alarm_out,
    user_supply0_alarm_out => s_xadc_control.user_supply0_alarm_out,
    user_supply1_alarm_out => s_xadc_control.user_supply1_alarm_out,
    user_supply2_alarm_out => s_xadc_control.user_supply2_alarm_out,
    --user_supply3_alarm_out => s_xadc_control.user_supply3_alarm_out,
    ot_out => s_xadc_control.ot_out,
    channel_out => s_xadc_control.channel_out,
    muxaddr_out => s_xadc_control.muxaddr_out,
    eoc_out => s_xadc_control.eoc_out,
    vbram_alarm_out => s_xadc_control.vbram_alarm_out,
    alarm_out => s_xadc_control.alarm_out,
    eos_out => s_xadc_control.eos_out,
    busy_out => s_xadc_control.busy_out,
    jtaglocked_out => s_xadc_control.jtaglocked_out,
    jtagmodified_out => s_xadc_control.jtagmodified_out,
    jtagbusy_out => s_xadc_control.jtagbusy_out
--    i2c_sda => s_xadc_control.i2c_sda,
--    i2c_sclk => s_xadc_control.i2c_sclk
  );


p_system_management_interface_out.xadc_new_conversion <= s_new_conversion;
p_system_management_interface_out.xadc_channel_voltage <= s_xadc_channel_voltage; --s_xadc_control.do_out; --s_xadc_channel_voltage;
p_system_management_interface_out.xadc_channel <= s_xadc_channel;

s_xadc_control.reset_in <= p_master_reset_in;
s_xadc_control.den_in <= '1';
s_xadc_control.dwe_in <= '0';

proc_read_xadc : process (p_clknet_in.cfgbus_clk40)


  begin
    if rising_edge(p_clknet_in.cfgbus_clk40) then

        p_leds_out <= "0000";--s_xadc_data.temperature(15) & (s_xadc_data.temperature(14) or s_xadc_data.temperature(13) or s_xadc_data.temperature(12)) & s_xadc_data.temperature(11) & s_xadc_data.temperature(10);
        
        -- xadc is running in continuous mode, so check each clock cycle for a new end-of-conversion
        s_eoc <= s_xadc_control.eoc_out;
        if (s_eoc = '0' and s_xadc_control.eoc_out = '1') and (s_xadc_control.jtaglocked_out = '0') then
            s_new_conversion <= '1';
            if s_selected_channel < c_n_db_xadc_channels then
                s_selected_channel <= s_selected_channel+1;
            else
                s_selected_channel <= 0;
            end if;
        else
            s_new_conversion <= '0';
            --p_system_management_interface_out.xadc_selected_channel <= s_selected_channel;
            s_xadc_control.daddr_in <= c_db_drp_xadc_addresses(s_selected_channel);
            
            if s_xadc_control.drdy_out = '1' then
                --s_xadc_voltages(s_selected_channel) <= s_xadc_control.do_out;
                s_xadc_channel_voltage <= s_xadc_control.do_out;
                s_xadc_channel <= s_xadc_control.daddr_in;
--                p_system_management_interface_out.xadc_channel_voltage <= s_xadc_control.do_out; --s_xadc_channel_voltage;
            end if;
            
        end if;

    end if; -- clock edge
end process;

--s_xadc_data.temperature <= s_xadc_voltages(0);
--s_xadc_data.vccint <= s_xadc_voltages(1);
--s_xadc_data.vccaux <= s_xadc_voltages(2);
--s_xadc_data.mb_10v_voltage <= s_xadc_voltages(3);
--s_xadc_data.mb_1v2_voltage <= s_xadc_voltages(4);
--s_xadc_data.mb_2v5_voltage <= s_xadc_voltages(5);
--s_xadc_data.mb_1v8_voltage <= s_xadc_voltages(6);
--s_xadc_data.mb_5v_voltage <= s_xadc_voltages(7);
--s_xadc_data.mb_5vn_voltage <= s_xadc_voltages(8);
--s_xadc_data.db_3v3_current <= s_xadc_voltages(9);
--s_xadc_data.db_2v5_current <= s_xadc_voltages(10);
--s_xadc_data.db_1v8_current <= s_xadc_voltages(11);
--s_xadc_data.db_1v5_current <= s_xadc_voltages(12);
--s_xadc_data.db_1v2_current <= s_xadc_voltages(13);
--s_xadc_data.db_0v9_current <= s_xadc_voltages(14);
--s_xadc_data.db_0v85_current <= s_xadc_voltages(15);
--s_xadc_data.db_sense_1 <= s_xadc_voltages(16);
--s_xadc_data.db_sense_2 <= s_xadc_voltages(17);
--s_xadc_data.db_sense_3 <= s_xadc_voltages(18);


--debug

--   i_vio_xadc_interface_debug : vio_xadc_interface_debug
--        port map (
--        clk => p_clknet_in.refclk40,
--        probe_out0 => open, --s_reset_debug,
--        probe_out1 => open, --s_xadc_mode_debug,
--        probe_in0 => "0000", --p_pgood_in,
--        probe_in1 => s_xadc_data.temperature,
--        probe_in2 => s_xadc_data.vccint,
--        probe_in3 => s_xadc_data.vccaux,
--        probe_in4 => s_xadc_data.mb_10v_voltage,
--        probe_in5 => s_xadc_data.mb_1v2_voltage,
--        probe_in6 => s_xadc_data.mb_2v5_voltage,
--        probe_in7 => s_xadc_data.mb_1v8_voltage,
--        probe_in8 => s_xadc_data.mb_5v_voltage,
--        probe_in9 => s_xadc_data.mb_5vn_voltage,
--        probe_in10 => s_xadc_data.db_3v3_current,
--        probe_in11 => s_xadc_data.db_2v5_current,
--        probe_in12 => s_xadc_data.db_1v8_current,
--        probe_in13 => s_xadc_data.db_1v5_current,
--        probe_in14 => s_xadc_data.db_1v2_current,
--        probe_in15 => s_xadc_data.db_0v9_current,
--        probe_in16 => s_xadc_data.db_0v85_current,
--        probe_in17 => s_xadc_data.db_sense_1,
--        probe_in18 => s_xadc_data.db_sense_1,
--        probe_in19 => s_xadc_data.db_sense_1
--      ); 


--ila_xadc_debugi_ila_xadc_debug : ila_xadc_debug
--PORT MAP (
--	clk => p_clknet_in.refclk40,

--	probe0 => s_xadc_control.di_in, 
--	probe1 => s_xadc_control.daddr_in, 
--	probe2(0) => s_xadc_control.den_in, 
--	probe3(0) => s_xadc_control.dwe_in, 
--	probe4(0) => s_xadc_control.drdy_out, 
--	probe5 => s_xadc_control.do_out, 
--	probe6(0) => s_xadc_control.reset_in, 
--	probe7(0) => s_xadc_control.eoc_out, 
--	probe8 => s_xadc_control.channel_out, 
--	probe9 => s_xadc_control.muxaddr_out, 
--	probe10(0) => s_xadc_control.busy_out, 
--	probe11(0) => s_xadc_control.busy_out, 
--	probe12(0) => s_xadc_control.jtaglocked_out, 
--	probe13(0) => s_new_conversion, 
--	probe14 => s_xadc_voltages(s_selected_channel),
--	probe15 => std_logic_vector(to_unsigned(s_selected_channel,16))
--);


--i_ila_xadc_interface_debug : ila_xadc_interface_debug
--PORT MAP (
--	clk => p_clk_in,



--	probe0 => s_adc_data_master, 
--	probe1 => s_di_in, 
--	probe2 => s_do_out, 
--	probe3 => s_daddr_in, 
--	probe4 => s_channel_out, 
--	probe5(0) => s_dwe_in, 
--	probe6(0) => s_busy_out, 
--	probe7(0) => s_den_in, 
--	probe8(0) => s_drdy_out,
--	probe9(0) => s_reset_in
--);

end Behavioral;

