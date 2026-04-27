----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/03/2020 02:15:55 PM
-- Design Name: 
-- Module Name: db6_i2c_master - Behavioral
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
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 1.0 11/01/2012 Scott Larson
--     Initial Public Release
--   Version 2.0 06/20/2014 Scott Larson
--     Added ability to interface with different slaves in the same transaction
--     Corrected ack_error bug where ack_error went 'Z' instead of '1' on error
--     Corrected timing of when ack_error signal clears
--   Version 2.1 10/21/2014 Scott Larson
--     Replaced gated clock with clock enable
--     Adjusted timing of SCL during start and stop conditions
--   Version 2.2 02/05/2015 Scott Larson
--     Corrected small SDA glitch introduced in version 2.1
-- 
--   Version 2.3 01/10/2021
--      Adapted it to Xilinx
--------------------------------------------------------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library tilecal;
use tilecal.db6_design_package.all;
library unisim;
use unisim.vcomponents.all;

entity db6_i2c_master is
--  generic(
--    g_input_clk : integer := 40_000_000; --input clock speed from user logic in hz
--    g_bus_clk   : integer := 400_000);   --speed the i2c bus (scl) will run at in hz
  port(
    --p_clknet_in       : in     t_db_clknet;                    --system clock
    p_clk_in            : in std_logic;
    p_master_reset_in   : in     std_logic;                    --active high reset
    p_divider_in        : in    std_logic_vector(15 downto 0);  -- i2c_speed
    p_enable_clk_stretch_in : in std_logic;
    p_ena_in       : in     std_logic;                    --latch in command
    p_addr_in      : in     std_logic_vector(6 downto 0); --address of target slave
    p_rw_in        : in     std_logic;                    --'0' is write, '1' is read
    p_data_in   : in     std_logic_vector(7 downto 0); --data to write to slave
    p_busy_out      : out    std_logic;                    --indicates transaction in progress
    p_data_out   : out    std_logic_vector(7 downto 0); --data read from slave
    p_ack_error_buffer : buffer std_logic;                    --flag if improper acknowledge from slave
    p_sda_inout       : inout  std_logic;                    --serial data output of i2c bus
    p_scl_inout       : inout  std_logic;                   --serial clock output of i2c bus
    p_sda_test_out    : out std_logic;
    p_scl_test_out    : out std_logic;
    p_read_state_out  : out std_logic;
    p_completed_transaction_out : out std_logic
    );
end db6_i2c_master;

architecture logic of db6_i2c_master is
--  constant c_divider  :  integer := (g_input_clk/g_bus_clk)/4; --number of clocks in 1/4 cycle of scl
  type t_machine is(st_ready, st_start, st_command, st_slv_ack1, st_wr, st_rd, st_slv_ack2, st_mstr_ack, st_stop); --needed states
  signal s_reset_n       : std_logic;
  signal s_state         : t_machine;                        --state machine
  signal s_data_clk      : std_logic;                      --data clock for sda
  signal s_data_clk_prev : std_logic;                      --data clock during previous system clock
  signal s_scl_clk, s_scl_in       : std_logic;                      --constantly running internal scl
  signal s_scl_ena, s_scl_ena_n, s_scl_clk_in       : std_logic := '0';               --enables internal scl to output
  signal s_sda_int, s_sda_in       : std_logic := '1';               --internal sda
  signal s_sda_ena_n     : std_logic;                      --enables internal sda to output
  signal s_addr_rw       : std_logic_vector(7 downto 0);   --latched in address and read/write
  signal s_data_tx       : std_logic_vector(7 downto 0);   --latched in data to write to slave
  signal s_data_rx       : std_logic_vector(7 downto 0);   --data received from slave
  signal s_bit_cnt       : integer range 0 to 7 := 7;      --tracks bit number in transaction
  signal s_stretch       : std_logic := '0';               --identifies if slave is stretching scl
  signal s_count : std_logic_vector(31 downto 0);
  signal s_falling_edge, s_rising_edge : std_logic;
  
  signal s_count_int : integer range 0 to 65535; --timing for clock generation
  signal s_divider : integer range 0 to 65535;
  
component vio_integrator_i2c
  port (
    clk : in std_logic;
    probe_in0 : in std_logic_vector(0 downto 0);
    probe_in1 : in std_logic_vector(0 downto 0);
    probe_in2 : in std_logic_vector(0 downto 0);
    probe_in3 : in std_logic_vector(0 downto 0);
    probe_in4 : in std_logic_vector(0 downto 0);
    probe_in5 : in std_logic_vector(0 downto 0);
    probe_in6 : in std_logic_vector(0 downto 0);
    probe_in7 : in std_logic_vector(0 downto 0);
    probe_in8 : in std_logic_vector(0 downto 0);
    probe_in9 : in std_logic_vector(7 downto 0);
    probe_in10 : in std_logic_vector(6 downto 0);
    probe_in11 : in std_logic_vector(3 downto 0);
    probe_in12 : in std_logic_vector(31 downto 0);
    probe_in13 : in std_logic_vector(0 downto 0);
    probe_in14 : in std_logic_vector(0 downto 0);
    probe_out0 : out std_logic_vector(0 downto 0)
  );
end component;


begin
  s_reset_n<= not p_master_reset_in;
	
--generate the timing for the bus clock (scl_clk) and the data clock (data_clk)
	process(p_clk_in, s_reset_n)
	begin
		if(s_reset_n = '0') then               --reset asserted
			s_stretch <= '0';
			s_count_int <= 0;
		elsif(rising_edge(p_clk_in)) then
		    s_count <=  std_logic_vector(to_unsigned(s_count_int,32));
            if p_divider_in = x"0000" then
		      s_divider <= 512;
		    else
		      s_divider <= to_integer(unsigned(p_divider_in));
		    end if;
		    if s_count_int < s_divider then
                if(s_stretch = '0') then          --clock stretching from slave not detected
                    s_count_int <= s_count_int + 1;		  --continue clock generation timing
                end if;
            else
                s_count_int <= 0;
            end if;
            
			if s_count_int < (s_divider/4) then  --first 1/4 cycle of clocking
                s_scl_clk <= '0';
                s_data_clk <= '0';
            elsif (s_count_int > (1*s_divider/4)) and (s_count_int < (2*s_divider/4)) then   --second 1/4 cycle of clocking
                s_scl_clk <= '0';
                s_data_clk <= '1';
            elsif (s_count_int > (2*s_divider/4)) and (s_count_int < (3*s_divider/4)) then--third 1/4 cycle of clocking
                s_scl_clk <= '1';--'z';                --release scl
                if(s_scl_clk_in = '0') then             --detect if slave is stretching clock
                    s_stretch <= '1' and p_enable_clk_stretch_in;
                else
                    s_stretch <= '0' and p_enable_clk_stretch_in;
                end if;
                s_data_clk <= '1';   
			elsif (s_count_int > (3*s_divider/4)) and (s_count_int < (4*s_divider/4)) then --last 1/4 cycle of clocking
                s_scl_clk <= '1';--'z';
                s_data_clk <= '0';
			end if;
		end if;
	end process;


	--state machine and writing to sda during scl low (data_clk rising edge)
	process(s_data_clk, s_reset_n)
	begin
		if(s_reset_n = '0') then                  --reset asserted
			s_state <= st_ready;                       --return to initial state
			p_busy_out <= '1';                          --indicate not available
			s_scl_ena <= '0';                       --sets scl high impedance
			s_sda_int <= '1';                       --sets sda high impedance
			s_bit_cnt <= 7;                         --restarts data bit counter
			p_data_out <= "00000000";                --clear data read port
	 elsif(s_data_clk'event and s_data_clk = '1') then
	       s_falling_edge <= '0';
	       s_rising_edge <= '1';
            case s_state is
				when st_ready =>                       --idle state
				p_read_state_out <= '0';
			    p_completed_transaction_out <= '0';
				 if(p_ena_in = '1') then                --transaction requested
						p_busy_out <= '1';                    --flag busy
						s_addr_rw <= p_addr_in & p_rw_in;           --collect requested slave address and command
						s_data_tx <= p_data_in;             --collect requested data to write
						s_state <= st_start;                 --go to start bit
					else                              --remain idle
						p_busy_out <= '0';                    --unflag busy
						s_state <= st_ready;                 --remain idle
					end if;
				when st_start =>                       --start bit of transaction
					p_busy_out <= '1';                      --resume busy if continuous mode
					s_scl_ena <= '1';                   --enable scl output
					s_sda_int <= s_addr_rw(s_bit_cnt);      --set first address bit to bus
					s_state <= st_command;                 --go to command
				when st_command =>                     --address and command byte of transaction
					if(s_bit_cnt = 0) then              --command transmit finished
						s_sda_int <= '1';                 --release sda for slave acknowledge
						s_bit_cnt <= 7;                   --reset bit counter for "byte" states
						s_state <= st_slv_ack1;              --go to slave acknowledge (command)
					else                              --next clock cycle of command state
						s_bit_cnt <= s_bit_cnt - 1;         --keep track of transaction bits
						s_sda_int <= s_addr_rw(s_bit_cnt-1);  --write address/command bit to bus
						s_state <= st_command;               --continue with command
					end if;
				when st_slv_ack1 =>                    --slave acknowledge bit (command)
					if(s_addr_rw(0) = '0') then         --write command
						s_sda_int <= s_data_tx(s_bit_cnt);    --write first bit of data
						s_state <= st_wr;                    --go to write byte
					else                              --read command
						s_sda_int <= '1';                 --release sda from incoming data
						s_state <= st_rd;                    --go to read byte
					end if;
				when st_wr =>                          --write byte of transaction
					p_busy_out <= '1';                      --resume busy if continuous mode
					if(s_bit_cnt = 0) then              --write byte transmit finished
						s_sda_int <= '1';                 --release sda for slave acknowledge
						s_bit_cnt <= 7;                   --reset bit counter for "byte" states
						s_state <= st_slv_ack2;              --go to slave acknowledge (write)
					else                              --next clock cycle of write state
						s_bit_cnt <= s_bit_cnt - 1;         --keep track of transaction bits
						s_sda_int <= s_data_tx(s_bit_cnt-1);  --write next bit to bus
						s_state <= st_wr;                    --continue writing
					end if;
				when st_rd =>                          --read byte of transaction
					p_busy_out <= '1';                      --resume busy if continuous mode
					if(s_bit_cnt = 0) then              --read byte receive finished
						if(p_ena_in = '1' and p_rw_in = '1') then --continuing with another read
							s_sda_int <= '0';               --acknowledge the byte has been received
						else                            --stopping or continuing with a write
							s_sda_int <= '1';               --send a no-acknowledge (before stop or repeated start)
						end if;
						s_bit_cnt <= 7;                   --reset bit counter for "byte" states
						p_data_out <= s_data_rx;             --output received data
						s_state <= st_mstr_ack;              --go to master acknowledge
					else                              --next clock cycle of read state
						s_bit_cnt <= s_bit_cnt - 1;         --keep track of transaction bits
						s_state <= st_rd;                    --continue reading
					end if;
				when st_slv_ack2 =>                    --slave acknowledge bit (write)
					if(p_ena_in = '1') then                --continue transaction
						p_busy_out <= '0';                    --continue is accepted
						s_addr_rw <= p_addr_in & p_rw_in;           --collect requested slave address and command
						s_data_tx <= p_data_in;             --collect requested data to write
						if(p_rw_in = '1') then               --continue transaction with a read
							s_state <= st_start;               --go to repeated start
						else                            --continue transaction with another write
							s_sda_int <= p_data_in(s_bit_cnt);  --write first bit of data
							s_state <= st_wr;                  --go to write byte
						end if;
					else                              --complete transaction
						s_scl_ena <= '0';                 --disable scl
						s_state <= st_stop;                  --go to stop bit
					end if;
				when st_mstr_ack =>                    --master acknowledge bit after a read
					if(p_ena_in = '1') then                --continue transaction
						p_busy_out <= '0';                    --continue is accepted and data received is available on bus
						s_addr_rw <= p_addr_in & p_rw_in;           --collect requested slave address and command
						s_data_tx <= p_data_in;             --collect requested data to write
						if(p_rw_in = '0') then               --continue transaction with a write
							s_state <= st_start;               --repeated start
						else                            --continue transaction with another read
							s_sda_int <= '1';               --release sda from incoming data
					        p_read_state_out <= '1';
							s_state <= st_rd;                  --go to read byte
						end if;
					else                              --complete transaction
						p_completed_transaction_out <= '1';
						s_scl_ena <= '0';                 --disable scl
						s_state <= st_stop;                  --go to stop bit
					end if;
				when st_stop =>		  --stop bit of transaction
				    p_busy_out <= '0';			 --unflag busy
				    s_state <= st_ready;
			end case;    
		end if;


		--reading from sda during scl high (falling edge of data_clk)
		if(s_reset_n = '0') then               --reset asserted
			p_ack_error_buffer <= '0';
		elsif(s_data_clk'event and s_data_clk = '0') then
           s_falling_edge <= '1';
	       s_rising_edge <= '0';
			case s_state is
				when st_start =>                    --starting new transaction
					p_ack_error_buffer <= '0';              --reset acknowledge error flag
				when st_slv_ack1 =>                 --receiving slave acknowledge (command)
					p_ack_error_buffer <= s_sda_in or p_ack_error_buffer; --set error output if no-acknowledge
				when st_rd =>                       --receiving slave data
					s_data_rx(s_bit_cnt) <= s_sda_in;       --receive current slave data bit
				when st_slv_ack2 =>                 --receiving slave acknowledge (write)
					p_ack_error_buffer <= s_sda_in or p_ack_error_buffer; --set error output if no-acknowledge
				when others =>
					null;
			end case;
		end if;
		
	end process;  


	--set sda output
	with s_state select
		s_sda_ena_n <=   s_data_clk when st_start, --generate start condition
							not s_data_clk when st_stop,   --generate stop condition
							s_sda_int when others;      --set to internal sda signal    
			
	--set scl and sda outputs
--	scl <= scl_clk when scl_ena = '1' else 'z';
--	sda <= '0' when sda_ena_n = '0' else 'z';
	s_scl_ena_n <= (not s_scl_ena) or s_scl_clk;
    p_scl_test_out <= s_scl_clk_in;
	i_scl_iobuf : iobuf
    port map (
        o => s_scl_clk_in, -- 1-bit output: buffer output
        i => s_scl_clk, -- 1-bit input: buffer input
        io => p_scl_inout, -- 1-bit inout: buffer inout (connect directly to top-level port)
        t => s_scl_ena_n -- 1-bit input: 3-state enable input
    );

    --sda_int
    p_sda_test_out <= s_sda_in;
    i_sda_iobuf : iobuf
    port map (
        o => s_sda_in, -- 1-bit output: buffer output
        i => '0', -- 1-bit input: buffer input
        io => p_sda_inout, -- 1-bit inout: buffer inout (connect directly to top-level port)
        t => s_sda_ena_n -- 1-bit input: 3-state enable input
    );
	
	
	
--    s_bit_cnt <= std_logic_vector(to_unsigned(bit_cnt,4));	
--i_vio_integrator_i2c : vio_integrator_i2c
--  port map (
--    clk => clk,
--    probe_in0(0) => scl_ena_n,
--    probe_in1(0) => sda_ena_n,
--    probe_in2(0) => sda_in, --scl_clk,
--    probe_in3(0) => scl_clk_in,
--    probe_in4(0) => scl_clk,
--    probe_in5(0) => stretch,
--    probe_in6(0) => s_rising_edge, --(others => '0'),
--    probe_in7(0) => s_falling_edge, --(others => '0'),
--    probe_in8(0) => reset_n,-- (others => '0'),
--    probe_in9 => data_rx, --(others => '0'),
--    probe_in10 => addr, --(others => '0'),
--    probe_in11 => s_bit_cnt,
--    probe_in12 => s_count,
--    probe_in13(0) => ena,
--    probe_in14(0) => data_clk,
--    probe_out0 => open
--  );
	
end logic;

