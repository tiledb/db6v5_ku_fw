----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/10/2024 01:03:14 AM
-- Design Name: 
-- Module Name: db6_debug_interface - Behavioral
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

library xilinx;

library tilecal;
use tilecal.db6_design_package.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_debug_interface is
   generic (   
        g_tmr_enabled                   : integer := 0;
-- hog
        GLOBAL_DATE : std_logic_vector(31 downto 0); -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME : std_logic_vector(31 downto 0); -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_VER : std_logic_vector(31 downto 0); -- 32 bit Last version Tag when the project was modified. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        GLOBAL_SHA : std_logic_vector(31 downto 0); -- 32 bit Git hash (SHA) of the last commit when the project was modified.
        TOP_VER : std_logic_vector(31 downto 0); -- 32 bit Top directory version, containing the hog.conf file and other files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        TOP_SHA : std_logic_vector(31 downto 0); -- 32 bit Top directory version, containing the hog.conf file and other files.
        CON_VER : std_logic_vector(31 downto 0); -- 32 bit The version of the constraint files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        CON_SHA : std_logic_vector(31 downto 0); -- 32 bit The git commit hash (SHA) of the constraint files.
        HOG_VER : std_logic_vector(31 downto 0); -- 32 bit Hog submodule version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        HOG_SHA : std_logic_vector(31 downto 0); -- 32 bit Hog submodule git commit hash (SHA).
        XML_VER : std_logic_vector(31 downto 0); -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        XML_SHA : std_logic_vector(31 downto 0) -- 32 bit (optional) IPbus xml git commit hash (SHA).

   );
  Port ( 
    p_master_reset_in : in std_logic_vector(31 downto 0);
    p_clknet_in                        : in t_db_clknet;
    p_db_reg_rx_debug_out : out t_db_reg_rx;
  
      --interfaces
    p_gbt_encoder_interface_in         : in t_gbt_encoder_interface;
    p_gbt_bank_in                      : in t_db6_gbt_bank;         
    p_mb_interface_in : in t_mb_interface;
    p_sem_interface_in : in t_sem_interface;
    p_system_management_interface_in : in t_system_management_interface;
    p_gbtx_interface_in : in t_gbtx_interface;
    p_serial_id_interface_in : in t_serial_id_interface;
    p_db6_sem_interface_in  : in t_db6_sem_interface;
    p_cfgbus_interface_in : in t_cfgbus_interface;
    
    p_leds_in             : in std_logic_vector(3 downto 0);
    
    p_debug_interface_uart_tx_out : out std_logic;
    p_debug_interface_uart_rx_in : in std_logic
    
--    p_cht8305c_sda_inout : inout std_logic;
--    p_cht8305c_scl_inout : inout std_logic
     
  );
end db6_debug_interface;


architecture Behavioral of db6_debug_interface is


component sem_ultra_uart
port (
    icap_clk         : in  std_logic;

    uart_tx          : out std_logic;
    uart_rx          : in  std_logic;

    monitor_txdata   : in  std_logic_vector(7 downto 0);
    monitor_txwrite  : in  std_logic;
    monitor_txfull   : out std_logic;

    monitor_rxdata   : out std_logic_vector(7 downto 0);
    monitor_rxread   : in  std_logic;
    monitor_rxempty  : out std_logic
);
end component;

signal s_monitor_txdata, s_monitor_rxdata : std_logic_vector(7 downto 0);
signal s_monitor_txwrite, s_monitor_txfull, s_monitor_rxread, s_monitor_rxempty : std_logic;

type t_debug_string is array (natural range <>)  of character;
subtype t_debug_string_64 is t_debug_string(0 to 63);
subtype t_debug_string_32 is t_debug_string(0 to 31);
subtype t_debug_string_16 is t_debug_string(0 to 15);
subtype t_debug_string_8 is t_debug_string(0 to 7);
subtype t_debug_string_2 is t_debug_string(0 to 1);
subtype t_debug_string_1 is t_debug_string(0 to 0);

signal s_debug_string_reg, s_debug_string_reg_d : t_debug_string_16 :="PiroDBDebugUART!";--&CR&LF;
--signal s_debug_string_reg : t_debug_string_64; 
--constant c_test_string : t_debug_string_64 := "Piro DB6 UART Debug Bridge!                                     ";
--                                            "0123456789012345678901234567890123456789012345678901234567890123456789"

signal s_tx_char_reg, s_rx_char_reg : character;
signal s_monitor_txdata_reg : std_logic_vector(7 downto 0);

--constant c_rtn : std_logic_vector(7 downto 0) := 0x"0D";
--constant c_rtn : character := CR;

signal s_char_counter : integer range 0 to 63:=0;
signal s_item_counter, s_xadc_item_counter : integer range 0 to 63:=0;

signal s_rx_clock_delay_counter, s_tx_clock_delay_counter : integer range 0 to 20000000;



function f_byte_to_hexchar(input_byte : std_logic_vector(3 downto 0)) return character is
begin
        case input_byte is
            when "0000" => return '0';
            when "0001" => return '1';
            when "0010" => return '2';
            when "0011" => return '3';
            when "0100" => return '4';
            when "0101" => return '5';
            when "0110" => return '6';
            when "0111" => return '7';
            when "1000" => return '8';
            when "1001" => return '9';
            when "1010" => return 'A';
            when "1011" => return 'B';
            when "1100" => return 'C';
            when "1101" => return 'D';
            when "1110" => return 'E';
            when "1111" => return 'F';
            when others => return '?'; -- Default to '?' if input does not match known 4-bit groups
        end case;

end f_byte_to_hexchar;


function f_bit_to_char(input_bit : std_logic) return character is
begin
    if input_bit = '0' then
        return '0';
    else
        return '1';
    end if;
end f_bit_to_char;


function f_32bit_vector_to_char_array (input_vector : std_logic_vector(31 downto 0)) return t_debug_string_32 is variable result : t_debug_string_32;
begin
    for i in 0 to 31 loop
        if input_vector(i) = '0' then
            result(i) := '0';
        else
            result(i) := '1';
        end if;
    end loop;
    return result;
end f_32bit_vector_to_char_array;

function f_32bit_vector_to_hex_32char_array (input_vector : std_logic_vector(31 downto 0)) return t_debug_string_32 is variable result : t_debug_string_32;
begin
    for i in 0 to 7 loop
        result(i) := f_byte_to_hexchar(input_vector((((i+1)*4)-1) downto i*4));
    end loop;
    result(8 to 31):= (others=>' ');
    return result;
end f_32bit_vector_to_hex_32char_array ;

function f_32bit_vector_to_hex_8char_array (input_vector : std_logic_vector(31 downto 0)) return t_debug_string_8 is variable result : t_debug_string_8;
begin
    for i in 0 to 7 loop
        result(i):=f_byte_to_hexchar(input_vector((((i+1)*4)-1) downto i*4));
    end loop;
    
    return result;
end f_32bit_vector_to_hex_8char_array ;

function f_8bit_vector_to_hex_2char_array (input_vector : std_logic_vector(7 downto 0)) return t_debug_string_2 is variable result : t_debug_string_2;
begin
    for i in 0 to 1 loop
        result(i):=f_byte_to_hexchar(input_vector((((i+1)*4)-1) downto i*4));
    end loop;
    
    return result;
end f_8bit_vector_to_hex_2char_array ;


function f_reverse_32bit_vector (input_vector : std_logic_vector(31 downto 0)) return std_logic_vector is variable result : std_logic_vector(31 downto 0);
begin
    for i in 0 to 31 loop
        result(i) := input_vector(31-i);
    end loop;
    return result;
end f_reverse_32bit_vector;


function f_nibble_reverse_32bit_vector (input_vector : std_logic_vector(31 downto 0)) return std_logic_vector is variable result : std_logic_vector(31 downto 0);
begin
    for i in 0 to 7 loop
        result((4*(i+1))-1 downto 4*i) := input_vector((4*((7-i)+1))-1 downto (4*(7-i)));
    end loop;
    return result;
end f_nibble_reverse_32bit_vector;


function f_nibble_reverse_8bit_vector (input_vector : std_logic_vector(7 downto 0)) return std_logic_vector is variable result : std_logic_vector(7 downto 0);
begin
    for i in 0 to 1 loop
        result((4*(i+1))-1 downto 4*i) := input_vector((4*((1-i)+1))-1 downto (4*(1-i)));
    end loop;
    return result;
end f_nibble_reverse_8bit_vector;


COMPONENT ila_db6_debug_interface

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe8 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	probe9 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
);
END COMPONENT  ;

constant c_number_of_debug_items : integer := 5;
type t_debug_string_32_array is array (0 to c_number_of_debug_items-1) of t_debug_string_32;
type t_debug_string_8_array is array (0 to c_number_of_debug_items-1) of t_debug_string_8;
type t_debug_string_2_array is array (0 to c_number_of_debug_items-1) of t_debug_string_2;
type t_debug_string_1_array is array (0 to c_number_of_debug_items-1) of t_debug_string_1;

--signal s_debug_string_values_array : t_debug_string_32_array := (others=>(others=>' '));
signal s_debug_string_values_array : t_debug_string_8_array := (others=>(others=>' '));

signal s_xadc_channel_counter : integer := 0; 


COMPONENT xadc_debug_ram
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    clkb : IN STD_LOGIC;
    web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addrb : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    dinb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) 
  );
END COMPONENT;
signal s_xadc_voltage : std_logic_vector(15 downto 0);


begin

--i_db6_cht8305c_interface : entity tilecal.db6_cht8305c_interface
--    Port map ( p_clk_in => p_clknet_in.osc_clk40,
--            p_reset_in => '0',
--            p_sensor_interface_out => open,
--            p_sda_inout => p_cht8305c_sda_inout,
--            p_scl_inout => p_cht8305c_scl_inout
            
--    );





s_debug_string_values_array(0)<="00000000";
s_debug_string_values_array(1)<= f_32bit_vector_to_hex_8char_array (f_nibble_reverse_32bit_vector(GLOBAL_DATE));
s_debug_string_values_array(2)<= f_32bit_vector_to_hex_8char_array (f_nibble_reverse_32bit_vector(GLOBAL_TIME));
s_debug_string_values_array(3)<= f_32bit_vector_to_hex_8char_array (f_nibble_reverse_32bit_vector(x"0000000"&p_leds_in));


i_xadc_debug_ram : xadc_debug_ram
  PORT MAP (
    clka => p_clknet_in.cfgbus_clk40,
    wea => "1",
    addra => p_system_management_interface_in.xadc_channel(4 downto 0),
    dina => p_system_management_interface_in.xadc_channel_voltage,
    douta => open,
    clkb => p_clknet_in.osc_clk40,
    web => "0",
    addrb => c_db_drp_xadc_addresses(s_xadc_item_counter)(4 downto 0),
    dinb => (others=>'0'),
    doutb => s_xadc_voltage
  );


proc_send_string: process(p_clknet_in.osc_clk40)
type t_sm_uart_tx_control is (st_init,st_tx,st_prep,st_end);
variable v_sm_uart_tx_control  : t_sm_uart_tx_control  :=st_init;

type t_sm_uart_tx_data_control is (st_hog,st_xadc,st_cfgbus,st_debug);
variable v_sm_uart_tx_data_control  : t_sm_uart_tx_data_control  :=st_xadc;
variable v_debug_string_data : t_debug_string_8;
variable v_debug_string_header : t_debug_string_1;
variable v_debug_string_item : t_debug_string_2;
constant c_st_hog_items : integer :=12;
constant c_st_xadc_items : integer :=c_n_db_xadc_channels;
begin
    if rising_edge(p_clknet_in.osc_clk40) then
    
        s_debug_string_reg<=":" & v_debug_string_header&":"&v_debug_string_item&":"& v_debug_string_data &":" &":";
        
        
            case v_sm_uart_tx_data_control is
                when st_hog=>
                    v_debug_string_header := "H";
                    
                    if v_sm_uart_tx_control = st_end then
                    
                        v_debug_string_item:=f_8bit_vector_to_hex_2char_array(f_nibble_reverse_8bit_vector(std_logic_vector(to_unsigned(s_item_counter,8))));
                        case s_item_counter is
                            when 0=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(GLOBAL_DATE));
                                s_item_counter <= s_item_counter+1;
                            when 1=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(GLOBAL_TIME));
                                s_item_counter <= s_item_counter+1;
                            when 2=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(GLOBAL_VER));
                                s_item_counter <= s_item_counter+1;
                            when 3=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(GLOBAL_SHA));
                                s_item_counter <= s_item_counter+1;
                            when 4=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(TOP_VER));
                                s_item_counter <= s_item_counter+1;
                            when 5=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(TOP_SHA));
                                s_item_counter <= s_item_counter+1;
                            when 6=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(CON_VER));
                                s_item_counter <= s_item_counter+1;
                            when 7=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(CON_SHA));
                                s_item_counter <= s_item_counter+1;
                            when 8=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(HOG_VER));
                                s_item_counter <= s_item_counter+1;
                            when 9=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(HOG_SHA));
                                s_item_counter <= s_item_counter+1;
                            when 10=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(XML_VER));
                                s_item_counter <= s_item_counter+1;
                            when 11=>
                                v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector(XML_SHA));
                                s_item_counter <= s_item_counter+1;
                            when others=>
                                s_item_counter<=0;
                                s_xadc_item_counter<=0;
                                v_sm_uart_tx_data_control:=st_xadc;
                        end case;
                    end if;
                
                when st_xadc=>
                    v_debug_string_header := "A";
                    if s_xadc_item_counter < c_st_xadc_items then
                        if v_sm_uart_tx_control = st_end then
                            v_debug_string_item:=f_8bit_vector_to_hex_2char_array(f_nibble_reverse_8bit_vector(c_db_drp_xadc_addresses(s_xadc_item_counter)));
                            v_debug_string_data:=f_32bit_vector_to_hex_8char_array(f_nibble_reverse_32bit_vector("0000000000000000"&s_xadc_voltage));
                            s_xadc_item_counter<=s_xadc_item_counter+1;
                        end if;
                    else
                        s_item_counter<=0;
                        s_xadc_item_counter<=0;
                        v_sm_uart_tx_data_control:=st_hog;
                    end if;
                    
                when others=>
                    v_sm_uart_tx_data_control:=st_hog;
            
            end case;
        
        
        case v_sm_uart_tx_control is
            when st_init=>
                s_char_counter<=0;
                s_monitor_txwrite<='0';
                v_sm_uart_tx_control:=st_prep;
            when st_prep=>
                s_char_counter<=0;
                s_monitor_txwrite<='0';
                
                if s_tx_clock_delay_counter < 10000000 then
                    s_tx_clock_delay_counter<=s_tx_clock_delay_counter+1;
                else
                    s_debug_string_reg_d<=s_debug_string_reg;
                    s_tx_clock_delay_counter<=0;
                    v_sm_uart_tx_control:=st_tx;
                    --s_tx_char_reg<=s_debug_string_reg_d(s_char_counter);
                end if;

            when st_tx=>
                
                if s_monitor_txfull = '0' then
                    if s_monitor_txwrite <= '0' then
                        s_monitor_txwrite <= '1';
                        case s_char_counter is
                            when 0 to 15=>
                                s_tx_char_reg<=s_debug_string_reg_d(s_char_counter);
                                s_char_counter<=s_char_counter+1;
                            when 16=>
                                --s_tx_char_reg<=CR;
                                s_char_counter<=s_char_counter+1;
                            when 17=>
                                s_tx_char_reg<=LF;
                                s_char_counter<=s_char_counter+1;
                            when others=>
                                s_char_counter<=0;
                                v_sm_uart_tx_control:=st_end;                                
                        end case;
                    else
                        s_monitor_txwrite <= '0';
                    end if;
                else
                    s_monitor_txwrite <= '0';
                end if;
            
            when st_end=>
                v_sm_uart_tx_control:=st_init;
                s_char_counter<=0;
                s_monitor_txwrite<='0';
                                
            when others=>
                null;
        end case;
        
    end if;
end process;


proc_receive_string: process(p_clknet_in.osc_clk40)
type t_sm_uart_rx_control is (st_rx,st_prep,st_end);
variable v_sm_uart_rx_control  : t_sm_uart_rx_control  :=st_prep;
begin
    if rising_edge(p_clknet_in.osc_clk40) then
        case v_sm_uart_rx_control is
            when st_prep=>

                s_monitor_rxread <= '0';
                if s_rx_clock_delay_counter < 10000000 then
                    s_rx_clock_delay_counter <=s_rx_clock_delay_counter +1;
                else
                    s_rx_clock_delay_counter <=0;
                    if s_monitor_rxempty = '0' then
                        v_sm_uart_rx_control:=st_rx;
                    end if;
                end if;

            when st_rx=>
                if s_monitor_rxempty = '0' then
                    if s_monitor_rxread <= '0' then
                        s_monitor_rxread <= '1';
                    else               
                        s_monitor_rxread <= '0';
                        s_rx_char_reg<=character'val(to_integer(unsigned(s_monitor_rxdata)));
                    end if;
                else
                    v_sm_uart_rx_control:=st_end;
                end if;
            
            when st_end=>
                s_monitor_rxread <= '0';
                v_sm_uart_rx_control:=st_prep;            
            when others=>
                null;
        end case;
        
    end if;
end process;


--i_db6_c2v_interpreter : entity tilecal.db6_c2v_interpreter
--    Port map (
--        p_char_in => s_char_reg,
--        p_vector_out => s_monitor_txdata_reg
--        );

s_monitor_txdata_reg <= std_logic_vector(to_unsigned(character'pos(s_tx_char_reg), 8));


s_monitor_txdata <= s_monitor_txdata_reg;


  i_debug_uart : sem_ultra_uart
    port map(
     icap_clk => p_clknet_in.osc_clk40,
     uart_tx => p_debug_interface_uart_tx_out,
     uart_rx => p_debug_interface_uart_rx_in,
     monitor_txdata => s_monitor_txdata,
     monitor_txwrite => s_monitor_txwrite,
     monitor_txfull => s_monitor_txfull,
     monitor_rxdata => s_monitor_rxdata,
     monitor_rxread => s_monitor_rxread,
     monitor_rxempty => s_monitor_rxempty
     );




--i_ila_db6_debug_interface : ila_db6_debug_interface
--PORT MAP (
--	clk => p_clknet_in.osc_clk40,



--	probe0 => s_monitor_txdata, 
--	probe1 => s_monitor_rxdata, 
--	probe2(0) => s_monitor_txwrite, 
--	probe3(0) => s_monitor_txfull, 
--	probe4(0) => s_monitor_rxread, 
--	probe5(0) => s_monitor_rxempty, 
--	probe6 => "0", 
--	probe7 => std_logic_vector(to_unsigned(s_char_counter,8)), 
--	probe8 => std_logic_vector(to_unsigned(s_xadc_item_counter,8)),
--	probe9 => std_logic_vector(to_unsigned(s_item_counter,8))
--);


end Behavioral;



------------------------------------------------------------------------------------
---- Company: 
---- Engineer: 
---- 
---- Create Date: 03/10/2024 01:03:14 AM
---- Design Name: 
---- Module Name: db6_debug_interface - Behavioral
---- Project Name: 
---- Target Devices: 
---- Tool Versions: 
---- Description: 
---- 
---- Dependencies: 
---- 
---- Revision:
---- Revision 0.01 - File Created
---- Additional Comments:
---- 
------------------------------------------------------------------------------------


--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;

--library tilecal;
--use tilecal.db6_design_package.all;

---- Uncomment the following library declaration if using
---- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx leaf cells in this code.
----library UNISIM;
----use UNISIM.VComponents.all;

--entity db6_debug_interface is
--   generic (   
--        g_tmr_enabled                   : integer := 0;
---- hog
--        GLOBAL_DATE : std_logic_vector(31 downto 0); -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
--        GLOBAL_TIME : std_logic_vector(31 downto 0); -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
--        GLOBAL_VER : std_logic_vector(31 downto 0); -- 32 bit Last version Tag when the project was modified. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        GLOBAL_SHA : std_logic_vector(31 downto 0); -- 32 bit Git hash (SHA) of the last commit when the project was modified.
--        TOP_VER : std_logic_vector(31 downto 0); -- 32 bit Top directory version, containing the hog.conf file and other files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        TOP_SHA : std_logic_vector(31 downto 0); -- 32 bit Top directory version, containing the hog.conf file and other files.
--        CON_VER : std_logic_vector(31 downto 0); -- 32 bit The version of the constraint files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        CON_SHA : std_logic_vector(31 downto 0); -- 32 bit The git commit hash (SHA) of the constraint files.
--        HOG_VER : std_logic_vector(31 downto 0); -- 32 bit Hog submodule version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        HOG_SHA : std_logic_vector(31 downto 0); -- 32 bit Hog submodule git commit hash (SHA).
--        XML_VER : std_logic_vector(31 downto 0); -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        XML_SHA : std_logic_vector(31 downto 0) -- 32 bit (optional) IPbus xml git commit hash (SHA).

--   );
--  Port ( 
--    p_master_reset_in : in std_logic_vector(31 downto 0);
--    p_clknet_in                        : in t_db_clknet;
--    p_db_reg_rx_debug_out : out t_db_reg_rx;
  
--      --interfaces
--    p_gbt_encoder_interface_in         : in t_gbt_encoder_interface;
--    p_gbt_bank_in                      : in t_db6_gbt_bank;         
--    p_mb_interface_in : in t_mb_interface;
--    p_sem_interface_in : in t_sem_interface;
--    p_system_management_interface_in : in t_system_management_interface;
--    p_gbtx_interface_in : in t_gbtx_interface;
--    p_serial_id_interface_in : in t_serial_id_interface;
--    p_db6_sem_interface_in  : in t_db6_sem_interface;
--    p_cfgbus_interface_in : in t_cfgbus_interface;
    
--    p_leds_in             : in std_logic_vector(3 downto 0);
    
--    p_debug_interface_uart_tx_out : out std_logic;
--    p_debug_interface_uart_rx_in : in std_logic
     
--  );
--end db6_debug_interface;


--architecture Behavioral of db6_debug_interface is



--signal s_monitor_txdata, s_monitor_rxdata : std_logic_vector(7 downto 0);
--signal s_monitor_txwrite, s_monitor_txfull, s_monitor_rxread, s_monitor_rxempty : std_logic;

--type t_debug_string is array (natural range <>)  of character;
--subtype t_debug_string_64 is t_debug_string(0 to 63);
--subtype t_debug_string_32 is t_debug_string(0 to 31);
--subtype t_debug_string_16 is t_debug_string(0 to 15);
--subtype t_debug_string_8 is t_debug_string(0 to 7);
--subtype t_debug_string_2 is t_debug_string(0 to 1);
--subtype t_debug_string_1 is t_debug_string(0 to 0);

--signal s_debug_string_reg : t_debug_string_16;
----signal s_debug_string_reg : t_debug_string_64; 
----constant c_test_string : t_debug_string_64 := "Piro DB6 UART Debug Bridge!                                     ";
----                                            "0123456789012345678901234567890123456789012345678901234567890123456789"

--signal s_tx_char_reg, s_rx_char_reg : character;
--signal s_monitor_txdata_reg : std_logic_vector(7 downto 0);

----constant c_rtn : std_logic_vector(7 downto 0) := 0x"0D";
----constant c_rtn : character := CR;

--signal s_char_counter : integer range 0 to 63:=0;
--signal s_item_counter : integer range 0 to 63:=0;

--signal s_rx_clock_delay_counter, s_tx_clock_delay_counter : integer range 0 to 20000000;



--function f_byte_to_hexchar(input_byte : std_logic_vector(3 downto 0)) return character is
--begin
--        case input_byte is
--            when "0000" => return '0';
--            when "0001" => return '1';
--            when "0010" => return '2';
--            when "0011" => return '3';
--            when "0100" => return '4';
--            when "0101" => return '5';
--            when "0110" => return '6';
--            when "0111" => return '7';
--            when "1000" => return '8';
--            when "1001" => return '9';
--            when "1010" => return 'A';
--            when "1011" => return 'B';
--            when "1100" => return 'C';
--            when "1101" => return 'D';
--            when "1110" => return 'E';
--            when "1111" => return 'F';
--            when others => return '?'; -- Default to '?' if input does not match known 4-bit groups
--        end case;

--end f_byte_to_hexchar;


--function f_bit_to_char(input_bit : std_logic) return character is
--begin
--    if input_bit = '0' then
--        return '0';
--    else
--        return '1';
--    end if;
--end f_bit_to_char;


--function f_32bit_vector_to_char_array (input_vector : std_logic_vector(31 downto 0)) return t_debug_string_32 is variable result : t_debug_string_32;
--begin
--    for i in 0 to 31 loop
--        if input_vector(i) = '0' then
--            result(i) := '0';
--        else
--            result(i) := '1';
--        end if;
--    end loop;
--    return result;
--end f_32bit_vector_to_char_array;

--function f_32bit_vector_to_hex_32char_array (input_vector : std_logic_vector(31 downto 0)) return t_debug_string_32 is variable result : t_debug_string_32;
--begin
--    for i in 0 to 7 loop
--        result(i) := f_byte_to_hexchar(input_vector((((i+1)*4)-1) downto i*4));
--    end loop;
--    result(8 to 31):= (others=>' ');
--    return result;
--end f_32bit_vector_to_hex_32char_array ;

--function f_32bit_vector_to_hex_8char_array (input_vector : std_logic_vector(31 downto 0)) return t_debug_string_8 is variable result : t_debug_string_8;
--begin
--    for i in 0 to 7 loop
--        result(i):=f_byte_to_hexchar(input_vector((((i+1)*4)-1) downto i*4));
--    end loop;
    
--    return result;
--end f_32bit_vector_to_hex_8char_array ;

--function f_reverse_32bit_vector (input_vector : std_logic_vector(31 downto 0)) return std_logic_vector is variable result : std_logic_vector(31 downto 0);
--begin
--    for i in 0 to 31 loop
--        result(i) := input_vector(31-i);
--    end loop;
--    return result;
--end f_reverse_32bit_vector;


--function f_nibble_reverse_32bit_vector (input_vector : std_logic_vector(31 downto 0)) return std_logic_vector is variable result : std_logic_vector(31 downto 0);
--begin
--    for i in 0 to 7 loop
--        result((4*(i+1))-1 downto 4*i) := input_vector((4*((7-i)+1))-1 downto (4*(7-i)));
--    end loop;
--    return result;
--end f_nibble_reverse_32bit_vector;

--COMPONENT ila_db6_debug_interface

--PORT (
--	clk : IN STD_LOGIC;



--	probe0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
--	probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
--	probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe7 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
--	probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--	probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--);
--END COMPONENT  ;

--constant c_number_of_debug_items : integer := 5;
--type t_debug_string_32_array is array (0 to c_number_of_debug_items-1) of t_debug_string_32;
--type t_debug_string_8_array is array (0 to c_number_of_debug_items-1) of t_debug_string_8;
--type t_debug_string_2_array is array (0 to c_number_of_debug_items-1) of t_debug_string_2;
--type t_debug_string_1_array is array (0 to c_number_of_debug_items-1) of t_debug_string_1;
----signal s_debug_string_labels_array : t_debug_string_32_array := (
----"Piro DB6 UART Debug Bridge!     ",
----"GLOBAL_DATE                     ",
----"GLOBAL_TIME                     ",
----"PLEDS                           ",
----"XADC                            "

----); 

----signal s_debug_string_labels_array : t_debug_string_8_array := (
----"DB6DBG  ",
----"DATE    ",
----"TIME    ",
----"PLEDS   ",
----"XADC    "

----); 

--signal s_debug_string_header_array : t_debug_string_1_array := (
--"D",
--"H",
--"C",
--"A",
--"S"
--); 
--signal s_debug_string_item_array : t_debug_string_2_array := (
--"00",
--"00",
--"00",
--"00",
--"00"
--); 

----signal s_debug_string_values_array : t_debug_string_32_array := (others=>(others=>' '));
--signal s_debug_string_values_array : t_debug_string_8_array := (others=>(others=>' '));

--signal s_xadc_channel_counter : integer := 0; 

--begin


----s_debug_string_reg <= c_test_string(0 to 62) & CR;
----s_debug_string_values_array(0)<="00000000000000000000000000000000";
----s_debug_string_values_array(1)<= f_32bit_vector_to_hex_32char_array (GLOBAL_DATE);
----s_debug_string_values_array(2)<= f_32bit_vector_to_hex_32char_array (GLOBAL_TIME);
----s_debug_string_values_array(3)<= f_32bit_vector_to_hex_32char_array (x"0000000"&p_leds_in);


--s_debug_string_values_array(0)<="00000000";
--s_debug_string_values_array(1)<= f_32bit_vector_to_hex_8char_array (f_nibble_reverse_32bit_vector(GLOBAL_DATE));
--s_debug_string_values_array(2)<= f_32bit_vector_to_hex_8char_array (f_nibble_reverse_32bit_vector(GLOBAL_TIME));
--s_debug_string_values_array(3)<= f_32bit_vector_to_hex_8char_array (f_nibble_reverse_32bit_vector(x"0000000"&p_leds_in));



------xadc
----proc_xadc : process(p_clknet_in.osc_clk40)
----begin
----    if rising_edge(p_clknet_in.osc_clk40) then
----        if c_n_db_xadc_channels
----        p_system_management_interface_in.xadc_channel 
        
----    end if;
----end process;




--proc_send_string: process(p_clknet_in.osc_clk40)
--type t_sm_uart_tx_control is (st_tx,st_prep,st_end);
--variable v_sm_uart_tx_control  : t_sm_uart_tx_control  :=st_prep;
--begin
--    if rising_edge(p_clknet_in.osc_clk40) then
--        case v_sm_uart_tx_control is
--            when st_prep=>
--                s_char_counter<=0;
--                s_monitor_txwrite<='0';
----                s_debug_string_reg<= s_debug_string_labels_array(s_item_counter)(0 to 29)&":"&s_debug_string_values_array(s_item_counter)&CR;
----                s_debug_string_reg<= s_debug_string_labels_array(s_item_counter)(0 to 5)&":"&s_debug_string_values_array(s_item_counter)&CR;
                
--                if s_tx_clock_delay_counter < 10000000 then
--                    s_tx_clock_delay_counter<=s_tx_clock_delay_counter+1;
--                else
--                    s_tx_clock_delay_counter<=0;
--                    v_sm_uart_tx_control:=st_tx;
--                    s_tx_char_reg<=s_debug_string_reg(s_char_counter);
--                end if;

--            when st_tx=>
                
--                if s_monitor_txfull = '0' then
--                    if s_monitor_txwrite <= '0' then
--                        s_monitor_txwrite <= '1';
--                        if s_char_counter< 15 then
--                            s_char_counter<=s_char_counter+1;
--                        else
--                            s_char_counter<=0;
--                            v_sm_uart_tx_control:=st_end;
--                        end if;
--                    else               
--                        s_monitor_txwrite <= '0';
--                        s_tx_char_reg<=s_debug_string_reg(s_char_counter);
--                    end if;
--                else
--                    s_monitor_txwrite <= '0';
--                end if;
            
--            when st_end=>
--                if s_item_counter < c_number_of_debug_items then
--                    s_item_counter <=s_item_counter +1;
--                else
--                    s_item_counter <=0;
--                end if;
--                v_sm_uart_tx_control:=st_prep;
--                s_char_counter<=0;
--                s_monitor_txwrite<='0';
                                
--            when others=>
--                null;
--        end case;
        
--    end if;
--end process;


--proc_receive_string: process(p_clknet_in.osc_clk40)
--type t_sm_uart_rx_control is (st_rx,st_prep,st_end);
--variable v_sm_uart_rx_control  : t_sm_uart_rx_control  :=st_prep;
--begin
--    if rising_edge(p_clknet_in.osc_clk40) then
--        case v_sm_uart_rx_control is
--            when st_prep=>

--                s_monitor_rxread <= '0';
--                if s_rx_clock_delay_counter < 10000000 then
--                    s_rx_clock_delay_counter <=s_rx_clock_delay_counter +1;
--                else
--                    s_rx_clock_delay_counter <=0;
--                    if s_monitor_rxempty = '0' then
--                        v_sm_uart_rx_control:=st_rx;
--                    end if;
--                end if;

--            when st_rx=>
--                if s_monitor_rxempty = '0' then
--                    if s_monitor_rxread <= '0' then
--                        s_monitor_rxread <= '1';
--                    else               
--                        s_monitor_rxread <= '0';
--                        s_rx_char_reg<=character'val(to_integer(unsigned(s_monitor_rxdata)));
--                    end if;
--                else
--                    v_sm_uart_rx_control:=st_end;
--                end if;
            
--            when st_end=>
--                s_monitor_rxread <= '0';
--                v_sm_uart_rx_control:=st_prep;            
--            when others=>
--                null;
--        end case;
        
--    end if;
--end process;


----i_db6_c2v_interpreter : entity tilecal.db6_c2v_interpreter
----    Port map (
----        p_char_in => s_char_reg,
----        p_vector_out => s_monitor_txdata_reg
----        );

--s_monitor_txdata_reg <= std_logic_vector(to_unsigned(character'pos(s_tx_char_reg), 8));


--s_monitor_txdata <= s_monitor_txdata_reg;


--  i_debug_uart : entity tilecal.sem_ultra_uart
--    port map(
--     icap_clk => p_clknet_in.osc_clk40,
--     uart_tx => p_debug_interface_uart_tx_out,
--     uart_rx => p_debug_interface_uart_rx_in,
--     monitor_txdata => s_monitor_txdata,
--     monitor_txwrite => s_monitor_txwrite,
--     monitor_txfull => s_monitor_txfull,
--     monitor_rxdata => s_monitor_rxdata,
--     monitor_rxread => s_monitor_rxread,
--     monitor_rxempty => s_monitor_rxempty
--     );




----i_ila_db6_debug_interface : ila_db6_debug_interface
----PORT MAP (
----	clk => p_clknet_in.osc_clk40,



----	probe0 => s_monitor_txdata, 
----	probe1 => s_monitor_rxdata, 
----	probe2(0) => s_monitor_txwrite, 
----	probe3(0) => s_monitor_txfull, 
----	probe4(0) => s_monitor_rxread, 
----	probe5(0) => s_monitor_rxempty, 
----	probe6 => "0", 
----	probe7 => std_logic_vector(to_unsigned(s_char_counter,8)), 
----	probe8 => "0",
----	probe9 => "0"
----);


--end Behavioral;
