----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/12/2024 11:51:21 PM
-- Design Name: 
-- Module Name: db6_sfp_i2c_interface - Behavioral
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tilecal;
use tilecal.db6_design_package.all;


entity db6_sfp_i2c_interface is
  generic(
    g_sys_clk_freq            : integer := 40_000_000;        --input clock speed from user logic in hz
    g_i2c_clk_freq            : integer := 400_000
    );
  port(
    p_clk_in               : in    std_logic;                                            --system clock
    p_reset_in           : in    std_logic;                                            --asynchronous active-low reset

    p_sfp_abs_in                : in std_logic;
    p_sfp_los_in                : in std_logic;
    p_sfp_tx_fault_in                : in std_logic;
    
    p_scl_inout               : inout std_logic;                                            --i2c serial clock
    p_sda_inout               : inout std_logic;                                            --i2c serial data
    p_sfp_i2c_interface_out : out t_blk_mem_sfp

    );
end db6_sfp_i2c_interface;

architecture behavior of db6_sfp_i2c_interface is
  constant c_sfp_addr : std_logic_vector(6 downto 0) := "1010000";         --i2c address of the sfp (SFF-8472-r12)
  type t_sm is(st_start, st_configure, st_initiate, st_pause, st_read_data, st_output_result); --needed states
  signal s_state            : t_sm :=st_pause;                       --state machine
  signal s_i2c_ena          : std_logic;                     --i2c enable signal
  signal s_i2c_addr         : std_logic_vector(6 downto 0);  --i2c address signal
  signal s_i2c_rw           : std_logic;                     --i2c read/write command signal
  signal s_i2c_data_wr      : std_logic_vector(7 downto 0);  --i2c write data
  signal s_i2c_data_rd      : std_logic_vector(7 downto 0);  --i2c read data
  signal s_i2c_busy         : std_logic;                     --i2c busy signal
  signal s_i2c_ack_err      : std_logic;                     --i2c slave acknowledge error flag
  signal s_busy_prev        : std_logic;                     --previous value of i2c busy signal
  signal s_measurement_wait_time          : integer;                       --clock cycles needed for measurement
  signal s_rh_res_bits      : std_logic_vector(1 downto 0);  --bits to set humidity resolution in sensor register
  signal s_temp_res_bit     : std_logic;                     --bit to set temperature resolution in sensor register
--  signal s_humidity_data    : std_logic_vector(15 downto 0); --humidity data buffer
--  signal s_temperature_data : std_logic_vector(15 downto 0); --temperature data buffer
  signal s_data_reg : std_logic_vector(7 downto 0); --data buffer

signal s_i2c_divider : std_logic_vector(15 downto 0) := x"0190";
signal s_i2c_clk_stretch : std_logic := '0';

signal s_scl_test, s_sda_test : std_logic;
signal s_reset : std_logic := '0';
signal s_reset_sm, s_reset_sm_from_vio : std_logic;

signal s_completed_transaction : std_logic;


type t_sfp_reg_map is array (0 to 5) of std_logic_vector(7 downto 0);
constant c_total_register_number : integer := 5;
signal s_sfp_reg_map : t_sfp_reg_map := (x"00",x"01",x"02",x"03",x"FE",x"FF");
signal s_sfp_regs : t_sfp_regs;
signal s_reg_counter : integer :=0;



COMPONENT blk_mem_sfp
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    clkb : IN STD_LOGIC;
    web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addrb : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    dinb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) 
  );
END COMPONENT;

COMPONENT ila_sfp_i2c_interface

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(6 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(6 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
);
END COMPONENT  ;

COMPONENT vio_sfp_i2c_interface
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    probe_out2 : OUT STD_LOGIC_VECTOR(6 DOWNTO 0) 
  );
END COMPONENT;

signal s_blk_mem_sfp : t_blk_mem_sfp;

signal s_sm_counter : integer :=0;
signal s_clk_counter : integer :=0;
constant c_clk_counter_delay : integer := 4000000;
signal s_busy_counter, s_sensor_reg_counter : integer:=0;
--signal s_address_counter : integer range 0 to 127;

signal s_busy_cnt   : integer :=0;               --counts the i2c busy signal transistions
signal s_pwr_up_cnt : integer :=0; --counts 100ms to wait before communicating
signal s_pause_cnt  : integer :=0;   

constant c_measurement_wait_time : integer := 40000000;

begin

i_blk_mem_sfp : blk_mem_sfp
  PORT MAP (
    clka => s_blk_mem_sfp.clka,
    wea => s_blk_mem_sfp.wea,
    addra => s_blk_mem_sfp.addra,
    dina => s_blk_mem_sfp.dina,
    douta => s_blk_mem_sfp.douta,
    clkb => s_blk_mem_sfp.clkb,
    web => s_blk_mem_sfp.web,
    addrb => s_blk_mem_sfp.addrb,
    dinb => s_blk_mem_sfp.dinb,
    doutb => s_blk_mem_sfp.doutb
  );

s_blk_mem_sfp.clka <= p_clk_in;
s_blk_mem_sfp.clkb <= p_clk_in;

s_blk_mem_sfp.wea(0) <= '1';
s_blk_mem_sfp.web(0) <= '0';

p_sfp_i2c_interface_out <= s_blk_mem_sfp;

  --instantiate the i2c master

i_db7_simple_i2c_master : entity tilecal.db7_simple_i2c_master
  generic map(
    g_input_clk => g_sys_clk_freq, --input clock speed from user logic in Hz
    g_bus_clk => g_i2c_clk_freq)   --speed the i2c bus (scl) will run at in Hz
  port map(
    p_clk_in            => p_clk_in, -- system clk
    p_reset_in   => s_reset,
    p_ena_in       => s_i2c_ena,                  --latch in command
    p_addr_in      => s_i2c_addr,
    p_rw_in        => s_i2c_rw,
    p_data_wr_in      => s_i2c_data_wr,
    p_busy_out     => s_i2c_busy,
    p_data_rd_out     => s_i2c_data_rd,
    p_ack_error_out => s_i2c_ack_err,
    p_sda_inout       => p_sda_inout,
    p_scl_inout       => p_scl_inout,
    p_sda_test_out    => s_sda_test,
    p_scl_test_out => s_scl_test
    );


--s_i2c_divider<=std_logic_vector(to_unsigned(g_sys_clk_freq/g_i2c_clk_freq,16));--x"0190"; --400 will give 100mhz
--s_i2c_clk_stretch <= '1';

--i_db6_i2c_master : entity tilecal.db6_i2c_master
--  port map(
--        p_clk_in            => p_clk_in, -- system clk
--        p_master_reset_in   => s_reset,
--        p_divider_in        => s_i2c_divider,--x"0000", -- i2c_speed (period)
--        p_enable_clk_stretch_in => s_i2c_clk_stretch, --'1',
--        p_ena_in       => s_i2c_ena,
--        p_addr_in      => s_i2c_addr,
--        p_rw_in        => s_i2c_rw,
--        p_data_in      => s_i2c_data_wr,
--        p_busy_out     => s_i2c_busy,
--        p_data_out     => s_i2c_data_rd,
--        p_ack_error_buffer => s_i2c_ack_err,
--        p_sda_inout       => p_sda_inout,
--        p_scl_inout       => p_scl_inout,
--        p_sda_test_out    => s_sda_test,
--        p_scl_test_out => s_scl_test,
--        p_read_state_out  => open,
--        p_completed_transaction_out => s_completed_transaction
--    );


               
          
  s_reset_sm<=p_reset_in or s_reset_sm_from_vio;             

  proc_main_sm : process(p_clk_in, s_reset_sm)
   -- variable v_busy_cnt   : integer range 0 to 4 := 0;               --counts the i2c busy signal transistions
   -- variable v_pwr_up_cnt : integer range 0 to g_sys_clk_freq/10 := 0; --counts 100ms to wait before communicating
   -- variable v_pause_cnt  : integer;                                 --counter to wait for measurements to complete
  begin
  
    if(s_reset_sm = '1') then                --reset activated
      s_pwr_up_cnt <= 0;                      --clear power up counter
      s_i2c_ena <= '0';                       --clear i2c enable
      s_busy_cnt <= 0;                        --clear busy counter
      s_pause_cnt <= 0;                       --clear pause counter
      s_sfp_regs <= (others=>(others => '0')); --clear the registers
      s_state <= st_pause;                       --return to start state
      s_busy_cnt <= 0;                                  --reset busy_cnt for next transaction
      s_reset<='1';
      s_sm_counter<=0;
    elsif rising_edge(p_clk_in) then   --rising edge of system clock
      s_reset<='0';
      case s_state is                         --state machine
      
        when st_pause =>
          s_sm_counter<=3;
          s_busy_cnt<=0;
          if(s_pause_cnt < c_measurement_wait_time) then  --measurement times not met
            s_pause_cnt <= s_pause_cnt + 1;               --increment pause counter
          else                                      --measurement times met
            s_pause_cnt <= 0;                           --reset pause counter
            s_state <= st_read_data;                       --advance to reading data results
          end if;
       
        --retreive the relative humidity and temperature measurement results 
        when st_read_data =>
          s_sm_counter<=4;
          s_busy_prev <= s_i2c_busy;                          --capture the value of the previous i2c busy signal
          if(s_busy_prev = '0' and s_i2c_busy = '1') then     --i2c busy just went high
            s_busy_cnt <= s_busy_cnt + 1;                       --counts the times busy has gone from low to high during transaction
          end if;
          case s_busy_cnt is                                --busy_cnt keeps track of which command we are on
            when 0 =>                                       --no command latched in yet
              s_i2c_ena <= '1';                                 --initiate the transaction
              --s_i2c_addr <= c_sfp_addr;                    --set the address of the hygrometer
              s_i2c_rw <= '1';                                  --command 1 is a read
              s_i2c_data_wr <= "00000000"; --std_logic_vector(to_unsigned(s_reg_counter,8)); --s_sfp_reg_map(s_reg_counter);                    --set the register pointer to the target register
            when 1 to 127 =>                                      --1st busy high: command 1 latched
              s_i2c_ena <= '1';                                 --deassert enable to stop transaction after command 2
              if(s_i2c_busy = '0') then                         --indicates data read in command 1 is ready
                s_blk_mem_sfp.addra <=std_logic_vector(to_unsigned(s_busy_cnt-1,7));
                s_blk_mem_sfp.dina <= s_i2c_data_rd;
              end if;
            when 128 =>
              s_i2c_ena <= '0';
              if(s_i2c_busy = '0') then                         --indicates data read in command 1 is ready
                s_blk_mem_sfp.addra <=std_logic_vector(to_unsigned(s_busy_cnt-1,7));
                s_blk_mem_sfp.dina <= s_data_reg;
                s_state <= st_pause;                         --advance to output the result
              else

              end if;
            when others => null;
          end case;
  
        when others =>
          s_sm_counter<=6;
          s_state <= st_pause;

      end case;
    end if;
  end process;  
  
  
  
  
--i_ila_sfp_i2c_interface : ila_sfp_i2c_interface
--PORT MAP (
--	clk => p_clk_in,

--	probe0 => s_blk_mem_sfp.addra, 
--	probe1 => s_blk_mem_sfp.dina, 
--	probe2 => s_blk_mem_sfp.douta, 
--	probe3 => s_blk_mem_sfp.addrb, 
--	probe4 => s_blk_mem_sfp.dinb, 
--	probe5 => s_blk_mem_sfp.doutb, 
--	probe6 => s_i2c_data_rd, 
--	probe7 => s_i2c_data_wr, 
--	probe8(0) => s_i2c_ena,
--	probe9(0) => s_i2c_busy
--);
    
  
--i_vio_sfp_i2c_interface : vio_sfp_i2c_interface
--  PORT MAP (
--    clk => p_clk_in,
--    probe_in0 => s_blk_mem_sfp.addra,
--    probe_in1 => s_blk_mem_sfp.dina,
--    probe_in2 => std_logic_vector(to_unsigned(s_busy_cnt,8)),--s_blk_mem_sfp.douta,
--    probe_in3 => s_blk_mem_sfp.addrb,
--    probe_in4 => s_blk_mem_sfp.dinb,
--    probe_in5 => s_blk_mem_sfp.doutb,
--    probe_in6 => s_i2c_data_rd,
--    probe_in7 => s_i2c_data_wr,
--    probe_in8(0) => s_i2c_ena,
--    probe_in9(0) => s_i2c_busy,
--    probe_in10 => std_logic_vector(to_unsigned(s_sm_counter,8)),
--    probe_in11 => '0'& s_i2c_addr,
--    probe_out0(0) => s_reset_sm_from_vio,
--    probe_out1 => s_blk_mem_sfp.addrb,
--    probe_out2 => s_i2c_addr
--  );
 
  
end behavior;


------------------------------------------------------------------------------------
---- Company: 
---- Engineer: 
---- 
---- Create Date: 06/26/2024 05:12:34 PM
---- Design Name: 
---- Module Name: db6_cht8305c_interface - Behavioral
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


--entity db6_cht8305c_interface is
--    Port ( p_clk_in : in STD_LOGIC;
--            p_reset_in : in std_logic;
--            p_sensor_interface_out : out t_cht8305c_regs;
--            p_sda_inout : inout std_logic;
--            p_scl_inout : inout std_logic
            
--    );
--end db6_cht8305c_interface;

--architecture Behavioral of db6_cht8305c_interface is

--signal s_i2c_divider : std_logic_vector(15 downto 0) := x"0190";
--signal s_i2c_clk_stretch : std_logic := '0';

--signal s_scl_test, s_sda_test : std_logic;
--signal s_reset : std_logic := '1';
--signal s_ena, s_rw, s_busy, s_ack_error : std_logic;
--signal s_addr: std_logic_vector (6 downto 0);
--signal s_data_rd, s_data_wr: std_logic_vector(7 downto 0);
--signal s_data_rd_reg : std_logic_vector(15 downto 0);
--signal s_verify_bus : std_logic;
--signal s_busy_reg, s_busy_counter_reset : std_logic;

--signal s_reset_sm, s_reset_sm_from_vio : std_logic;

--signal s_completed_transaction : std_logic;

--signal s_cht8305c_regs : t_cht8305c_regs;

--signal s_sm_counter : integer :=0;
--signal s_clk_counter : integer :=0;
--constant c_clk_counter_delay : integer := 4000000;
--signal s_busy_counter, s_sensor_reg_counter : integer:=0;


--type t_cht8305c_reg_map is array (0 to 5) of std_logic_vector(7 downto 0);
--constant c_total_register_number : integer := 6;
--signal s_cht8305c_reg_map : t_cht8305c_reg_map := (x"00",x"01",x"02",x"03",x"FE",x"FF");

--COMPONENT vio_cht8305c
--  PORT (
--    clk : IN STD_LOGIC;
--    probe_in0 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe_in1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe_in2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe_in3 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe_in4 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe_in5 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe_in6 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe_in7 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe_in8 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    
--    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0) 
--  );
--END COMPONENT;

--------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
--COMPONENT ila_cht8305c

--PORT (
--	clk : IN STD_LOGIC;



--	probe0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
--	probe1 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
--	probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
--	probe9 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
--	probe10 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--	probe11 : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
--);
--END COMPONENT  ;


--begin

--s_i2c_divider<=x"0190"; --400 will give 100mhz
--s_i2c_clk_stretch <= '1';

--i_db6_i2c_master : entity tilecal.db6_i2c_master
--  port map(
--        p_clk_in            => p_clk_in, -- system clk
--        p_master_reset_in   => s_reset,
--        p_divider_in        => s_i2c_divider,--x"0000", -- i2c_speed (period)
--        p_enable_clk_stretch_in => s_i2c_clk_stretch, --'1',
--        p_ena_in       => s_ena,
--        p_addr_in      => s_addr,
--        p_rw_in        => s_rw,
--        p_data_in      => s_data_wr,
--        p_busy_out     => s_busy,
--        p_data_out     => s_data_rd,
--        p_ack_error_buffer => s_ack_error,
--        p_sda_inout       => p_sda_inout,
--        p_scl_inout       => p_scl_inout,
--        p_sda_test_out    => s_sda_test,
--        p_scl_test_out => s_scl_test,
--        p_read_state_out  => open,
--        p_completed_transaction_out => s_completed_transaction
--    );


--s_reset_sm<=p_reset_in or s_reset_sm_from_vio;


--proc_sensor_sm : process(s_reset_sm, p_clk_in)
--begin
--    if s_reset_sm = '1' then
--        s_sm_counter <= 0;
--        s_reset<='1';
--        s_addr<="0000000";
--        s_busy_counter<=0;
--        s_sensor_reg_counter<=0;
--        s_busy_counter_reset<='0';
        
--    elsif rising_edge(p_clk_in) then
--        s_busy_reg<=s_busy;
--        if s_busy_counter_reset='0' then
--            if s_busy_reg = '0' and s_busy = '1' then
--                s_busy_counter<=s_busy_counter+1;
--            end if;
--        else
--            s_busy_counter<=0;
--        end if;
        
--        case s_sm_counter is
--            --start
--            when 0 =>
--                s_reset<='0';
--                s_ena<='0';
--                s_addr<="1000000";
--                s_rw<='0';
--                s_data_wr<=x"00";
--                s_busy_counter<=0;
                
--                if s_clk_counter<c_clk_counter_delay then
--                    s_clk_counter<=s_clk_counter+1;
--                    s_busy_counter_reset<='1';
--                else
--                    s_clk_counter<=0;
--                    s_sm_counter<=s_sm_counter+2;--+1;
--                    s_busy_counter_reset<='0';
--                end if;
--            --configure
--            when 1 =>
--                s_addr<="1000000";
--                case s_busy_counter is
--                    when 0 =>
--                        s_busy_counter_reset<='0';
--                        s_ena<='1';
--                        s_rw<='0';
--                        s_data_wr<=s_cht8305c_reg_map(c_cht8305c_config);
--                    when 1 =>
--                        s_busy_counter_reset<='0';
--                        s_data_wr<="000"&"1"&"0"&"0"&"00";       
--                    when 2 =>
                        
--                        s_data_wr<="00000000";
--                        if s_busy = '0' then
--                            s_busy_counter_reset<='1';
--                            s_sm_counter<=s_sm_counter+1;
--                        else
--                            s_busy_counter_reset<='0';                            
--                        end if;
--                    when others=>
--                        null;
--                end case;
                        
--            when 2 =>
--                s_reset<='0';
--                s_addr<="1000000";
--                s_rw<='1';
--                s_data_wr<=s_cht8305c_reg_map(s_sensor_reg_counter);
--                case s_busy_counter is
--                    when 0 =>
--                        s_ena<='1';
--                        s_busy_counter_reset<='0';
--                    when 1 =>
--                        s_busy_counter_reset<='0';
--                        if s_busy = '0' then 
--                            s_data_rd_reg(15 downto 8) <= s_data_rd; 
--                        end if;
--                    when 2 =>
--                        if s_busy = '0' then 
--                            s_data_rd_reg(7 downto 0) <= s_data_rd;
--                            s_busy_counter_reset<='1';
--                            s_cht8305c_regs(s_sensor_reg_counter)<=s_data_rd_reg;
--                            if s_sensor_reg_counter<c_total_register_number then
--                                s_sensor_reg_counter<=s_sensor_reg_counter+1;
--                            else
--                                s_sensor_reg_counter<=0;
--                                s_sm_counter<=s_sm_counter+1;
--                                s_ena<='0';        
--                            end if;
--                        else
--                            s_busy_counter_reset<='0';
--                        end if;
                        
                        
--                    when others =>
--                        null;
--                end case;
            
--            when 3 =>
                            
--                case s_busy_counter is
--                    when 0 =>
--                        s_busy_counter_reset<='0';
--                        s_ena<='1';
--                        s_rw<='0';
--                        s_data_wr<=s_cht8305c_reg_map(c_cht8305c_temperature);
--                    when 1 =>
--                        s_busy_counter_reset<='0';
--                        s_data_wr<= (others=> '0');       
--                    when 2 =>
--                        s_data_wr<= (others=> '0');
--                        if s_busy = '0' then
--                            s_busy_counter_reset<='1';
--                            s_sm_counter<=s_sm_counter+1;
--                        else
--                            s_busy_counter_reset<='0';                            
--                        end if;
--                    when others=>
--                        null;
--                end case;
                                        
                
                
--            when 3 =>
--                s_reset<='1';
--                s_ena<='0';
--                if s_clk_counter<c_clk_counter_delay then
--                    s_clk_counter<=s_clk_counter+1;
--                    s_busy_counter_reset<='1';
--                else
--                    s_clk_counter<=0;
--                    s_sm_counter<=2;
--                    s_busy_counter_reset<='0';
--                end if;
            
--            when others =>
--                s_sm_counter<=0;
--        end case;
--    end if;
--end process;


--i_vio_cht8305c : vio_cht8305c
--  PORT MAP (
--    clk => p_clk_in,
--    probe_in0 => s_cht8305c_regs(c_cht8305c_temperature),
--    probe_in1 => s_cht8305c_regs(c_cht8305c_humidity),
--    probe_in2 => s_cht8305c_regs(c_cht8305c_config),
--    probe_in3 => s_cht8305c_regs(c_cht8305c_alert),
--    probe_in4 => s_cht8305c_regs(c_cht8305c_manufacturer),
--    probe_in5 => s_cht8305c_regs(c_cht8305c_id),
--    probe_in6(15 downto 12) => std_logic_vector(to_unsigned(s_sm_counter,4)),
--    probe_in6(11 downto 8) => std_logic_vector(to_unsigned(s_busy_counter,4)),
--    probe_in6(7) => s_reset,
--    probe_in6(6) => s_busy_counter_reset,
--    probe_in6(5) => s_ena,
--    probe_in6(4) => s_rw,
--    probe_in6(3) => s_ack_error,
--    probe_in6(2) => s_completed_transaction,
--    probe_in6(1) => s_sda_test,
--    probe_in6(0) => s_scl_test,
--    probe_in7(15 downto 12) => std_logic_vector(to_unsigned(s_sensor_reg_counter,4)), --(others=> '0'),
--    probe_in7(11 downto 0) => (others=> '0'),
--    probe_in8 => s_data_rd_reg,
--    probe_out0(0) => s_reset_sm_from_vio,
--    probe_out1 => open
--  );

--i_ila_cht8305c : ila_cht8305c
--PORT MAP (
--	clk => p_clk_in,



--	probe0 => std_logic_vector(to_unsigned(s_sm_counter,4)), 
--	probe1 => std_logic_vector(to_unsigned(s_busy_counter,4)), 
--	probe2(0) => s_reset, 
--	probe3(0) => s_busy_counter_reset, 
--	probe4(0) => s_ena, 
--	probe5(0) => s_ack_error, 
--	probe6(0) => s_completed_transaction, 
--	probe7(0) => s_sda_test, 
--	probe8(0) => s_scl_test, 
--	probe9 => std_logic_vector(to_unsigned(s_sensor_reg_counter,4)), 
--	probe10 => x"0000",
--	probe11 => s_data_rd_reg
--);


--end Behavioral;
