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
library UNISIM;
use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_system_management_interface is
    Port ( 
    p_clknet_in : in t_db_clknet;
    p_master_reset_in : in std_logic;
    p_db_reg_rx_in : in t_db_reg_rx;
    
    --xadc: plain logic; system_management IP (with the analog pads and i2c inout
    --it owns directly) now lives in db7_io_box.
    p_pgood_in       : in t_p_pgood_in;
    p_xadc_control_out : out t_xadc_control; -- di_in/daddr_in/den_in/dwe_in/dclk_in/reset_in, to the IP
    p_xadc_control_in  : in  t_xadc_control; -- drdy_out/do_out/alarms/status, from the IP

    -- device DNA (db6_ku_dna, moved here from db6_clock_interface); manual re-read
    -- trigger from the top-level debug vio, ORed with this module's own master reset
    p_dna_reset_in : in std_logic;

    --output
    p_system_management_interface_out : out t_system_management_interface; 
    
    --leds and debug_out
     p_leds_out : out  std_logic_vector(3 downto 0)
    
    );
end db6_system_management_interface;

architecture Behavioral of db6_system_management_interface is

attribute keep : string;
attribute dont_touch : string;

-- system_management IP component/instance moved to db7_io_box (owns the analog
-- pads and i2c inout directly, per https://www.xilinx.com/support/documentation/user_guides/ug580-ultrascale-sysmon.pdf).

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

signal s_xadc_clk40 : std_logic;

signal s_dna_read_out : std_logic_vector(95 downto 0);
signal s_dna_done_out : std_logic;

begin

i_db6_ku_dna : entity tilecal.db6_ku_dna
    port map (
        p_clk_in         => p_clknet_in.osc_clk40,
        p_reset_in       => p_dna_reset_in or p_master_reset_in,
        p_done_out       => s_dna_done_out,
        p_dna_value_out  => s_dna_read_out
    );

p_system_management_interface_out.ku_dna      <= s_dna_read_out;
p_system_management_interface_out.ku_dna_done <= s_dna_done_out;


-- BUFGMUX: Global Clock Mux Buffer
--          7 Series
-- Xilinx HDL Language Template, version 2026.1

-- BUFGMUX: Global Clock Mux Buffer
--          7 Series
-- Xilinx HDL Language Template, version 2026.1

--i_bufgmux : BUFGMUX
--port map (
--    o=>s_xadc_clk40,
--    i0=>p_clknet_in.osc_clk40,
--    i1=>p_clknet_in.cfgbus_clk40,
--    s=>p_clknet_in.gbtx_rxready(0)
--);

s_xadc_clk40 <= p_clknet_in.osc_clk40;
s_xadc_control.dclk_in <= s_xadc_clk40; --p_clknet_in.cfgbus_clk40;
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

-- system_management IP now instantiated in db7_io_box. Command fields
-- (di_in/daddr_in/den_in/dwe_in/dclk_in/reset_in) are computed by this file's own
-- logic below and relayed out whole-record; status/data fields the IP produces are
-- merged back in individually (never both directions on the same field, to avoid
-- putting two drivers on the same bits -- same pattern as the GT/MGT extraction).
p_xadc_control_out <= s_xadc_control;

s_xadc_control.drdy_out               <= p_xadc_control_in.drdy_out;
s_xadc_control.do_out                 <= p_xadc_control_in.do_out;
s_xadc_control.user_temp_alarm_out    <= p_xadc_control_in.user_temp_alarm_out;
s_xadc_control.vccint_alarm_out       <= p_xadc_control_in.vccint_alarm_out;
s_xadc_control.vccaux_alarm_out       <= p_xadc_control_in.vccaux_alarm_out;
s_xadc_control.user_supply0_alarm_out <= p_xadc_control_in.user_supply0_alarm_out;
s_xadc_control.user_supply1_alarm_out <= p_xadc_control_in.user_supply1_alarm_out;
s_xadc_control.user_supply2_alarm_out <= p_xadc_control_in.user_supply2_alarm_out;
s_xadc_control.ot_out                 <= p_xadc_control_in.ot_out;
s_xadc_control.channel_out            <= p_xadc_control_in.channel_out;
s_xadc_control.muxaddr_out            <= p_xadc_control_in.muxaddr_out;
s_xadc_control.eoc_out                <= p_xadc_control_in.eoc_out;
s_xadc_control.vbram_alarm_out        <= p_xadc_control_in.vbram_alarm_out;
s_xadc_control.alarm_out              <= p_xadc_control_in.alarm_out;
s_xadc_control.eos_out                <= p_xadc_control_in.eos_out;
s_xadc_control.busy_out               <= p_xadc_control_in.busy_out;
s_xadc_control.jtaglocked_out         <= p_xadc_control_in.jtaglocked_out;
s_xadc_control.jtagmodified_out       <= p_xadc_control_in.jtagmodified_out;
s_xadc_control.jtagbusy_out           <= p_xadc_control_in.jtagbusy_out;


p_system_management_interface_out.xadc_new_conversion <= s_new_conversion;
p_system_management_interface_out.xadc_channel_voltage <= s_xadc_channel_voltage; --s_xadc_control.do_out; --s_xadc_channel_voltage;
p_system_management_interface_out.xadc_channel <= s_xadc_channel;

s_xadc_control.reset_in <= p_master_reset_in;
s_xadc_control.den_in <= '1';
s_xadc_control.dwe_in <= '0';

proc_read_xadc : process(s_xadc_clk40) -- (p_clknet_in.cfgbus_clk40)


  begin
    --if rising_edge(p_clknet_in.cfgbus_clk40) then
    if rising_edge(s_xadc_clk40) then
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

