---------------------------------------------------------------------------------
--   FileName:         i2c_master.vhd
--   Dependencies:     none
--   Design Software:  Quartus II 32-bit Version 11.1 Build 173 SJ Full Version
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
--   Version 1.0 11/1/2012 Scott Larson
--     Initial Public Release
--    
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;

ENTITY db6_integrator_i2c_master IS
PORT(
	clk       : IN     STD_LOGIC;                    --system clock
	p_clknet_in : in    t_db_clknet;
	divider   : in     std_logic_vector(15 downto 0);
	reset_n   : IN     STD_LOGIC;                    --active low reset
	ena       : IN     STD_LOGIC;                    --latch in command
	addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
	rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
	data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
	busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
	data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
	ack_error : INOUT STD_LOGIC;                    --flag if improper acknowledge from slave
	sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
	scl       : INOUT  STD_LOGIC;                   --serial clock output of i2c bus
	test0     : OUT  STD_LOGIC;
	test1     : OUT  STD_LOGIC);	 
END db6_integrator_i2c_master;


ARCHITECTURE logic OF db6_integrator_i2c_master IS
--	CONSTANT divider  :  INTEGER := (input_clk/bus_clk)/4; --number of clocks in 1/4 cycle of scl
--	CONSTANT divider  :  INTEGER := 27; --128; --number of clocks in 1/4 cycle of scl
--	CONSTANT dx2  :  INTEGER := divider*2;--256; --number of clocks in 1/4 cycle of scl
--	CONSTANT dm1  :  INTEGER := divider-1; --127; --divider-1
--	CONSTANT dx2m1  :  INTEGER := divider*2-1;--255; --divider*2-1
--	CONSTANT dx3m1  :  INTEGER := divider*3-1;--383; --divider*3-1
	TYPE machine IS(ready, start, command, slv_ack1, wr, rd, slv_ack2, mstr_ack, stop); --needed states
	SIGNAL  state     :  machine;                          --state machine
	SIGNAL  data_clk  :  STD_LOGIC;                        --clock edges for sda
	SIGNAL  scl_clk, scl_clk_in   :  STD_LOGIC;                        --constantly running internal scl
	SIGNAL  scl_ena, scl_ena_n   :  STD_LOGIC := '0';                 --enables internal scl to output
	SIGNAL  sda_int, sda_in   :  STD_LOGIC := '1';                 --internal sda
	SIGNAL  sda_ena_n :  STD_LOGIC;                        --enables internal sda to output
	SIGNAL  addr_rw   :  STD_LOGIC_VECTOR(7 DOWNTO 0);     --latched in address and read/write
	SIGNAL  data_tx   :  STD_LOGIC_VECTOR(7 DOWNTO 0);     --latched in data to write to slave
	SIGNAL  data_rx   :  STD_LOGIC_VECTOR(7 DOWNTO 0);     --data received from slave
	SIGNAL  bit_cnt   :  INTEGER RANGE 0 TO 7 := 7;        --tracks bit number in transaction
	SIGNAL  stretch   :  STD_LOGIC := '0';                 --identifies if slave is stretching scl
	SIGNAL  ckja      :  STD_LOGIC_VECTOR(3 DOWNTO 0);     --diagnostic counter
	SIGNAL  ipass     :  STD_LOGIC;                        --constantly running internal scl
	signal s_falling_edge, s_rising_edge : std_logic;
	
	signal s_divider : integer range 0 to 65535;
	signal s_bit_cnt : std_logic_vector(3 downto 0);
	signal s_count : std_logic_vector(31 downto 0);
	
		COMPONENT vio_integrator_i2c
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;
	
BEGIN


	--generate the timing for the bus clock (scl_clk) and the data clock (data_clk)
	PROCESS(p_clknet_in.cfgbus_clk40, reset_n)
		VARIABLE count : INTEGER RANGE 0 TO 65535;  --divider*4; --timing for clock generation
	BEGIN
		IF(reset_n = '0') THEN               --reset asserted
			stretch <= '0';
			count := 0;
		ELSIF rising_edge(p_clknet_in.cfgbus_clk40) THEN
            if divider = x"0000" then
              s_divider <= 512;
            else
              s_divider <= to_integer(unsigned(divider));
            end if;
            --s_count <=  std_logic_vector(to_unsigned(count,32));
            IF(count < s_divider) THEN       --end of timing cycle
                 IF(stretch = '0') THEN          --clock stretching from slave not detected
                    count := count + 1;		  --continue clock generation timing
                 else
                 end if;
            else
               count := 0;                      --reset timer
            --ckja <= ckja + 1;
            END IF;
            
            if (count < s_divider/4) then
                    scl_clk <= '0';
                    data_clk <= '0';			
            elsif (count > s_divider/4) and (count < s_divider*2/4) then
                    scl_clk <= '0';
                    data_clk <= '1';			
            elsif (count > s_divider*2/4) and (count < s_divider*3/4) then
                    scl_clk <= '1';--'Z';                --release scl
                    IF(scl_clk_in = '0') THEN             --detect if slave is stretching clock
                        stretch <= '1';
                    ELSE
                        stretch <= '0';
                    END IF;
                    data_clk <= '1';			
            elsif (count > s_divider*3/4) and (count < s_divider*4/4) then
                    scl_clk <= '1';--'Z';
                    data_clk <= '0';
            end if;
		END IF;
	END PROCESS;


	--state machine and writing to sda during scl low (data_clk rising edge)
	PROCESS(data_clk, reset_n)
	BEGIN
		IF(reset_n = '0') THEN                  --reset asserted
			state <= ready;                       --return to initial state
			busy <= '1';                          --indicate not available
			scl_ena <= '0';                       --sets scl high impedance
			sda_int <= '1';                       --sets sda high impedance
			bit_cnt <= 7;                         --restarts data bit counter
			data_rd <= "00000000";                --clear data read port
	 ELSIF(data_clk'EVENT AND data_clk = '1') THEN
	       s_falling_edge <= '0';
	       s_rising_edge <= '1';
			CASE state IS
				WHEN ready =>                       --idle state
				test0 <= '0';
			 test1 <= '0';
				 IF(ena = '1') THEN                --transaction requested
						busy <= '1';                    --flag busy
						addr_rw <= addr & rw;           --collect requested slave address and command
						data_tx <= data_wr;             --collect requested data to write
						state <= start;                 --go to start bit
					ELSE                              --remain idle
						busy <= '0';                    --unflag busy
						state <= ready;                 --remain idle
					END IF;
				WHEN start =>                       --start bit of transaction
					busy <= '1';                      --resume busy if continuous mode
					scl_ena <= '1';                   --enable scl output
					sda_int <= addr_rw(bit_cnt);      --set first address bit to bus
					state <= command;                 --go to command
				WHEN command =>                     --address and command byte of transaction
					IF(bit_cnt = 0) THEN              --command transmit finished
						sda_int <= '1';                 --release sda for slave acknowledge
						bit_cnt <= 7;                   --reset bit counter for "byte" states
						state <= slv_ack1;              --go to slave acknowledge (command)
					ELSE                              --next clock cycle of command state
						bit_cnt <= bit_cnt - 1;         --keep track of transaction bits
						sda_int <= addr_rw(bit_cnt-1);  --write address/command bit to bus
						state <= command;               --continue with command
					END IF;
				WHEN slv_ack1 =>                    --slave acknowledge bit (command)
					IF(addr_rw(0) = '0') THEN         --write command
						sda_int <= data_tx(bit_cnt);    --write first bit of data
						state <= wr;                    --go to write byte
					ELSE                              --read command
						sda_int <= '1';                 --release sda from incoming data
						state <= rd;                    --go to read byte
					END IF;
				WHEN wr =>                          --write byte of transaction
					busy <= '1';                      --resume busy if continuous mode
					IF(bit_cnt = 0) THEN              --write byte transmit finished
						sda_int <= '1';                 --release sda for slave acknowledge
						bit_cnt <= 7;                   --reset bit counter for "byte" states
						state <= slv_ack2;              --go to slave acknowledge (write)
					ELSE                              --next clock cycle of write state
						bit_cnt <= bit_cnt - 1;         --keep track of transaction bits
						sda_int <= data_tx(bit_cnt-1);  --write next bit to bus
						state <= wr;                    --continue writing
					END IF;
				WHEN rd =>                          --read byte of transaction
					busy <= '1';                      --resume busy if continuous mode
					IF(bit_cnt = 0) THEN              --read byte receive finished
						IF(ena = '1' AND rw = '1') THEN --continuing with another read
							sda_int <= '0';               --acknowledge the byte has been received
						ELSE                            --stopping or continuing with a write
							sda_int <= '1';               --send a no-acknowledge (before stop or repeated start)
						END IF;
						bit_cnt <= 7;                   --reset bit counter for "byte" states
						data_rd <= data_rx;             --output received data
						state <= mstr_ack;              --go to master acknowledge
					ELSE                              --next clock cycle of read state
						bit_cnt <= bit_cnt - 1;         --keep track of transaction bits
						state <= rd;                    --continue reading
					END IF;
				WHEN slv_ack2 =>                    --slave acknowledge bit (write)
					IF(ena = '1') THEN                --continue transaction
						busy <= '0';                    --continue is accepted
						addr_rw <= addr & rw;           --collect requested slave address and command
						data_tx <= data_wr;             --collect requested data to write
						IF(rw = '1') THEN               --continue transaction with a read
							state <= start;               --go to repeated start
						ELSE                            --continue transaction with another write
							sda_int <= data_wr(bit_cnt);  --write first bit of data
							state <= wr;                  --go to write byte
						END IF;
					ELSE                              --complete transaction
						scl_ena <= '0';                 --disable scl
						state <= stop;                  --go to stop bit
					END IF;
				WHEN mstr_ack =>                    --master acknowledge bit after a read
					IF(ena = '1') THEN                --continue transaction
						busy <= '0';                    --continue is accepted and data received is available on bus
						addr_rw <= addr & rw;           --collect requested slave address and command
						data_tx <= data_wr;             --collect requested data to write
						IF(rw = '0') THEN               --continue transaction with a write
							state <= start;               --repeated start
						ELSE                            --continue transaction with another read
							sda_int <= '1';               --release sda from incoming data
					test0 <= '1';
							state <= rd;                  --go to read byte
						END IF;
					ELSE                              --complete transaction
						test1 <= '1';
						scl_ena <= '0';                 --disable scl
						state <= stop;                  --go to stop bit
					END IF;
				WHEN stop =>		  --stop bit of transaction
					busy <= '0';			 --unflag busy
				state <= ready;
			END CASE;    
		END IF;


		--reading from sda during scl high (falling edge of data_clk)
		IF(reset_n = '0') THEN               --reset asserted
			ack_error <= '0';
		ELSIF(data_clk'EVENT AND data_clk = '0') THEN
           s_falling_edge <= '1';
	       s_rising_edge <= '0';
			CASE state IS
				WHEN start =>                    --starting new transaction
					ack_error <= '0';              --reset acknowledge error flag
				WHEN slv_ack1 =>                 --receiving slave acknowledge (command)
					ack_error <= sda_in OR ack_error; --set error output if no-acknowledge
				WHEN rd =>                       --receiving slave data
					data_rx(bit_cnt) <= sda_in;       --receive current slave data bit
				WHEN slv_ack2 =>                 --receiving slave acknowledge (write)
					ack_error <= sda_in OR ack_error; --set error output if no-acknowledge
				WHEN OTHERS =>
					NULL;
			END CASE;
		END IF;
		
	END PROCESS;  


	--set sda output
	WITH state SELECT
		sda_ena_n <=   data_clk WHEN start, --generate start condition
							NOT data_clk WHEN stop,   --generate stop condition
							sda_int WHEN OTHERS;      --set to internal sda signal    
			
	--set scl and sda outputs
--	scl <= scl_clk WHEN scl_ena = '1' ELSE 'Z';
--	sda <= '0' WHEN sda_ena_n = '0' ELSE 'Z';
	scl_ena_n <= (not scl_ena) or scl_clk;
	i_scl_IOBUF : IOBUF
    port map (
        O => scl_clk_in, -- 1-bit output: Buffer output
        I => scl_clk, -- 1-bit input: Buffer input
        IO => scl, -- 1-bit inout: Buffer inout (connect directly to top-level port)
        T => scl_ena_n -- 1-bit input: 3-state enable input
    );

    --sda_int
    i_sda_IOBUF : IOBUF
    port map (
        O => sda_in, -- 1-bit output: Buffer output
        I => '0', -- 1-bit input: Buffer input
        IO => sda, -- 1-bit inout: Buffer inout (connect directly to top-level port)
        T => sda_ena_n -- 1-bit input: 3-state enable input
    );
	
	
	
--    s_bit_cnt <= std_logic_vector(to_unsigned(bit_cnt,4));	
--i_vio_integrator_i2c : vio_integrator_i2c
--  PORT MAP (
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
	
END logic;
