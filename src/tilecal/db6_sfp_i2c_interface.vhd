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
    
    -- IOBUF moved to db7_io_box; split O/I/T instead of inout.
    p_sda_drive_out : out std_logic;
    p_sda_tri_out   : out std_logic;
    p_sda_read_in   : in  std_logic;
    p_scl_drive_out : out std_logic;
    p_scl_tri_out   : out std_logic;
    p_scl_read_in   : in  std_logic;
    p_sfp_i2c_interface_out : out t_blk_mem_sfp;

    -- debug readback: port B of the dual-port sfp reg block ram. rx_register picks the
    -- A2h byte address (0-127); tx_register carries that byte's value back out.
    p_rx_register_in  : in  std_logic_vector(6 downto 0);
    p_tx_register_out : out std_logic_vector(7 downto 0);

    -- sff-8472 A2h ddm fields, decoded from bytes 96-109 as they stream in below
    -- (see c_sfp_* constants in db6_design_package.vhd)
    p_sfp_ddm_out : out t_sfp_regs;

    -- pulses for one p_clk_in cycle each time a full 128-byte a2h snapshot completes
    -- (state 129 below); used upstream to latch a "first read done" boot flag
    p_sfp_ddm_read_done_out : out std_logic

    );
end db6_sfp_i2c_interface;

architecture behavior of db6_sfp_i2c_interface is
  constant c_sfp_diag_addr : std_logic_vector(6 downto 0) := "1010001";    --sfp+ digital diagnostics, 2-wire address 1010001X (A2h) per SFF-8472
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
--  signal s_humidity_data    : std_logic_vector(15 downto 0); --humidity data buffer
--  signal s_temperature_data : std_logic_vector(15 downto 0); --temperature data buffer

signal s_i2c_divider : std_logic_vector(15 downto 0) := x"0190";
signal s_i2c_clk_stretch : std_logic := '0';

signal s_scl_test, s_sda_test : std_logic;
signal s_reset : std_logic := '0';
signal s_reset_sm, s_reset_sm_from_vio : std_logic;

signal s_completed_transaction : std_logic;


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

-- ddm decode: bytes 96-109 of the A2h page (temperature, vcc, tx bias, tx power,
-- rx power, laser temperature, tec current -- 7 x 16-bit, msb first), latched as
-- they stream past in proc_main_sm and assembled into s_sfp_ddm below.
type t_sfp_ddm_bytes is array (0 to 13) of std_logic_vector(7 downto 0);
signal s_sfp_ddm_bytes : t_sfp_ddm_bytes := (others => (others => '0'));
signal s_sfp_ddm : t_sfp_regs;

signal s_sm_counter : integer :=0;
signal s_clk_counter : integer :=0;
constant c_clk_counter_delay : integer := 4000000;
signal s_busy_counter, s_sensor_reg_counter : integer:=0;
--signal s_address_counter : integer range 0 to 127;

signal s_busy_cnt   : integer :=0;               --counts the i2c busy signal transistions
signal s_pwr_up_cnt : integer :=0; --counts 100ms to wait before communicating
signal s_pause_cnt  : integer :=0;   

constant c_measurement_wait_time : integer := 2 * g_sys_clk_freq; -- 2 seconds between full diagnostic snapshots

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

-- port b: manual debug readback, addressed by p_rx_register_in
s_blk_mem_sfp.addrb <= p_rx_register_in;
s_blk_mem_sfp.dinb  <= (others => '0');
p_tx_register_out   <= s_blk_mem_sfp.doutb;

p_sfp_i2c_interface_out <= s_blk_mem_sfp;

s_sfp_ddm(c_sfp_temperature)       <= s_sfp_ddm_bytes(0)  & s_sfp_ddm_bytes(1);
s_sfp_ddm(c_sfp_vcc)               <= s_sfp_ddm_bytes(2)  & s_sfp_ddm_bytes(3);
s_sfp_ddm(c_sfp_tx_bias_current)   <= s_sfp_ddm_bytes(4)  & s_sfp_ddm_bytes(5);
s_sfp_ddm(c_sfp_tx_power)          <= s_sfp_ddm_bytes(6)  & s_sfp_ddm_bytes(7);
s_sfp_ddm(c_sfp_rx_power)          <= s_sfp_ddm_bytes(8)  & s_sfp_ddm_bytes(9);
s_sfp_ddm(c_sfp_laser_temperature) <= s_sfp_ddm_bytes(10) & s_sfp_ddm_bytes(11);
s_sfp_ddm(c_sfp_tec_current)       <= s_sfp_ddm_bytes(12) & s_sfp_ddm_bytes(13);
p_sfp_ddm_out <= s_sfp_ddm;

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
    p_sda_drive_out => p_sda_drive_out,
    p_sda_tri_out   => p_sda_tri_out,
    p_sda_read_in   => p_sda_read_in,
    p_scl_drive_out => p_scl_drive_out,
    p_scl_tri_out   => p_scl_tri_out,
    p_scl_read_in   => p_scl_read_in,
    p_sda_test_out    => s_sda_test,
    p_scl_test_out => s_scl_test
    );


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
      s_state <= st_pause;                       --return to start state
      s_reset<='1';
      s_sm_counter<=0;
    elsif rising_edge(p_clk_in) then   --rising edge of system clock
      s_reset<='0';
      p_sfp_ddm_read_done_out <= '0'; -- default; pulsed for one cycle in st_read_data/129 below
      case s_state is                         --state machine

        when st_pause =>
          s_sm_counter<=3;
          s_busy_cnt<=0;
          if(s_pause_cnt < c_measurement_wait_time) then  --2s not elapsed yet
            s_pause_cnt <= s_pause_cnt + 1;               --increment pause counter
          else                                      --2s elapsed
            s_pause_cnt <= 0;                           --reset pause counter
            s_state <= st_read_data;                       --advance to reading data results
          end if;

        -- read the full 128-byte fixed A2h diagnostic region (bytes 0-127, see SFF-8472
        -- Fig 4-1): write the register pointer to byte 0, then read 128 bytes back to
        -- back via a repeated start ("sequential read"), one byte per busy_cnt.
        when st_read_data =>
          s_sm_counter<=4;
          s_busy_prev <= s_i2c_busy;                          --capture the value of the previous i2c busy signal
          if(s_busy_prev = '0' and s_i2c_busy = '1') then     --i2c busy just went high: a new byte transaction started
            s_busy_cnt <= s_busy_cnt + 1;
          end if;
          case s_busy_cnt is
            when 0 =>                                       --no command latched in yet: present the register-pointer write
              s_i2c_ena <= '1';
              s_i2c_addr <= c_sfp_diag_addr;
              s_i2c_rw <= '0';                                  --write
              s_i2c_data_wr <= x"00";                           --start reading from byte 0
            when 1 =>                                          --write-pointer byte underway; switch to read for the
              s_i2c_rw <= '1';                                  --repeated start that begins the sequential read
            when 2 to 128 =>                                  --reading bytes 0 through 126
              if(s_i2c_busy = '0') then                         --previous byte's read has completed
                s_blk_mem_sfp.addra <= std_logic_vector(to_unsigned(s_busy_cnt-2,7));
                s_blk_mem_sfp.dina  <= s_i2c_data_rd;
                if (s_busy_cnt-2 >= 96) and (s_busy_cnt-2 <= 109) then --ddm fields (see t_sfp_ddm_bytes above)
                  s_sfp_ddm_bytes(s_busy_cnt-2-96) <= s_i2c_data_rd;
                end if;
              end if;
            when 129 =>                                       --last byte (127): nack it and stop after
              s_i2c_ena <= '0';
              if(s_i2c_busy = '0') then
                s_blk_mem_sfp.addra <= std_logic_vector(to_unsigned(s_busy_cnt-2,7));
                s_blk_mem_sfp.dina  <= s_i2c_data_rd;
                s_state <= st_pause;                         --snapshot done, wait for the next 2s cycle
                p_sfp_ddm_read_done_out <= '1';               --one-cycle pulse: full a2h snapshot completed
              end if;
            when others => null;
          end case;

        when others =>
          s_sm_counter<=6;
          s_state <= st_pause;

      end case;
    end if;
  end process;

end behavior;
