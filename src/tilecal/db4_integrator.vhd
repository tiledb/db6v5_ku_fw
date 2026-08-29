----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/04/2021 11:30:24 PM
-- Design Name: 
-- Module Name: db4_integrator - Behavioral
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
----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:29:59 02/12/2014 
-- Design Name: 
-- Module Name:    integrator - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

library tilecal;
use tilecal.db6_design_package.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db4_integrator is
generic (g_i2c_master : natural := 1); -- 0 -> db6, 1 - db4

Port ( 
    p_clknet_in                  : in    t_db_clknet;
    p_reset_in                   : in    std_logic;
    CLK_IN     : in    STD_LOGIC;
--	IGBK_IN        : in    STD_LOGIC;
    Integrator_config_reg : in std_logic_vector(31 downto 0);
	INTEG_DATA_IN  : in    STD_LOGIC_VECTOR (15 downto 0);
	INTEG_DATA_OUT : out   STD_LOGIC_VECTOR (15 downto 0);
	EndOfRead      : out std_logic;
	-- IOBUF moved to db7_io_box; split O/I/T instead of inout.
	I2C_SDA_DRIVE_OUT : out std_logic;
	I2C_SDA_TRI_OUT   : out std_logic;
	I2C_SDA_READ_IN   : in  std_logic;
	I2C_SCL_DRIVE_OUT : out std_logic;
	I2C_SCL_TRI_OUT   : out std_logic;
	I2C_SCL_READ_IN   : in  std_logic;
    p_sda_debug_out : out std_logic;
	p_scl_debug_out : out std_logic
);
end db4_integrator;

architecture Behavioral of db4_integrator is

	signal clk        : std_logic;
	signal intg_data  : std_logic_vector(15 downto 0);
	signal ckja       : std_logic_vector(7 downto 0);
	signal cnvt       : std_logic;
	signal igbck      : std_logic;
	signal iaddr      : std_logic_vector(6 downto 0);
	signal irw        : std_logic;
	signal ird        : std_logic_vector(7 downto 0);
	signal ierr       : std_logic;
	signal ibusy      : std_logic;
	signal ireset_n   : std_logic;
	signal istrt      : std_logic;
	signal t0         : std_logic;
	signal t1         : std_logic;
	signal s_gbck_buffer, s_t0_buffer, s_t1_buffer : std_logic;
	
	type intg_state is (intg_idle,
	                    intg_s0,
	                    intg_s1,
	                    intg_s2,
	                    intg_s3,
	                    intg_s4);
	signal intg_current   : intg_state :=intg_idle; --a�adido defeault state
	signal intg_next      : intg_state :=intg_idle; --a�adido defeault state

begin

	clk <= CLK_IN;  -- ~10KHz clock rate for readout request rate

	igbck <= INTEG_DATA_IN(15);
	iaddr(6 downto 2) <= "01100";
	iaddr(1 downto 0) <= INTEG_DATA_IN(1 downto 0);
	
	INTEG_DATA_OUT <= intg_data;
	
	integ_proc : process(p_clknet_in.cfgbus_clk40,p_reset_in) --, t1, t0, istrt, intg_current)
	--variable v_gbck, v_t0, v_t1 : std_logic := '1';
	begin

--		if(rising_edge(clk)) then
--			ckja <= ckja +1;
--		end if;
        if p_reset_in = '1' then
		  ireset_n <= '0';
		elsif(rising_edge(p_clknet_in.cfgbus_clk40)) then
	
            s_gbck_buffer <= igbck;
            s_t0_buffer <= t0;
            s_t1_buffer <= t1;	
            if(istrt = '1') then
                cnvt <= '0';
            else
                --if(igbck'event and igbck = '1') then
                if (s_gbck_buffer = '0') and (igbck = '1') then           
                    cnvt <= '1';
                end if;
            end if;
            --		iaddr <= "0110000";
            irw <= '1';
            --		ireset_n <= '1';
            --		iaddr <= "0110000";
            --		irw <= '1';
            
            
            intg_current <= intg_next;
            
            
            
            --if(t1'event and t1 = '1') then
            if (s_t1_buffer = '0') and (t1 = '1') then
                 intg_data(7 downto 0) <= ird(7 downto 0);
            end if;
            --if(t0'event and t0 = '1') then
            if (s_t0_buffer = '0') and (t0 = '1') then
                intg_data(15 downto 8) <= ird(7 downto 0);
            end if;
            
            case intg_current is
                when intg_idle =>   -- wait for PC to send command
                    ireset_n <= '1';
                    istrt <= '0';
                    if(cnvt = '1') then
                        intg_next <= intg_s0;
                    else
                        intg_next <= intg_idle;
                    end if;
                when intg_s0 =>     -- reset I2C_master
                    istrt <= '0';
                    ireset_n <= '0';
                    intg_next <= intg_s1;
                
                when intg_s1 =>     -- start a transfer
                    istrt <= '0';
                    ireset_n <= '1';
                    intg_next <= intg_s2;
                 
                when intg_s2 =>     -- start a transfer
                    istrt <= '1';
                    ireset_n <= '1';
                    intg_next <= intg_s3;
            
            
                when intg_s3 =>      -- has the higher order byte xfer finished
                     ireset_n <= '1';
                     if(t0 = '1') then 
                            istrt <= '0';
                            intg_next <= intg_s4;
                     else
                                istrt <= '1';
                                intg_next <= intg_s3;
                     end if;
             
                when intg_s4 =>
                     istrt <= '0';
                     ireset_n <= '1';
                     if(t1 = '1') then       -- has the lower order byte xfer finished
                            intg_next <= intg_idle;
                     else
                            intg_next <= intg_s4;
                     end if;
                     
            end case;
            
            EndOfRead <= t1;
        end if;
	end process integ_proc;
	
	-->> I2C instantiation >>>>>>>>>>>>>>>>>>>>>>>>>>>>--
	gen_i2c_master : if g_i2c_master = 0 generate
--        i2c_master_1: entity work.i2c_master
--        port map (
--            clk   => clk_in, --156.25KHz MAX1169 specs say 400KHz max rate for scl
--            reset_n => ireset_n,
--            ena     => istrt,
--            addr    => iaddr,
--            rw      => irw,
--            data_wr => (others => '0'),
--            busy    => ibusy,
--            data_rd => ird(7 downto 0),
--            ack_error => ierr,
--            sda     => I2C_SDA,
--            scl     => I2C_SCL,
--            test0   => t0,
--            test1   => t1,
--            p_sda_debug_out => p_sda_debug_out,
--            p_scl_debug_out => p_scl_debug_out
            
--            );

    elsif g_i2c_master = 1 generate

        i2c_master_1: entity tilecal.db6_integrator_i2c_master
        port map (
            clk   => p_clknet_in.cfgbus_clk40, --156.25KHz MAX1169 specs say 400KHz max rate for scl
            p_clknet_in => p_clknet_in,
            divider => 	Integrator_config_reg(31 downto 16),
            reset_n => ireset_n,
            ena     => istrt,
            addr    => iaddr,
            rw      => irw,
            data_wr => (others => '0'),
            busy    => ibusy,
            data_rd => ird(7 downto 0),
            ack_error => ierr,
            sda_drive_out => I2C_SDA_DRIVE_OUT,
            sda_tri_out   => I2C_SDA_TRI_OUT,
            sda_read_in   => I2C_SDA_READ_IN,
            scl_drive_out => I2C_SCL_DRIVE_OUT,
            scl_tri_out   => I2C_SCL_TRI_OUT,
            scl_read_in   => I2C_SCL_READ_IN,
            test0   => t0,
            test1   => t1
            
            ); 

    p_scl_debug_out <= t0;
    p_sda_debug_out <= t1;
    end generate;

end Behavioral;

