
--=================================================================================================--
--##################################   module information   #######################################--
--=================================================================================================--
--                                                                                         
-- company:               stockholm university                                                        
-- engineer:              eduardo valdes eduardo.valdes@cern.ch
-- engineer:              sam silverstein silver@fysik.su.se
--                                                                                                 
-- project name:          piro_gbtx_i2c_interface                                                                
-- module name:           gbt top                                        
--                                                                                                 
-- language:              vhdl'93                                                                  
--                                                                                                   
-- target device:         xilinx kintex 7                                                         
-- tool version:          ise 14.7                                                               
--                                                                                                   
-- version:               1.0                                                                      
--
-- description:            
--
-- versions history:      date         version   author            			description
--
--                        22/03/2018   1.0       eduardo valdes santurio   	firmware for the controlling the i2c configuration/monitoring of the gbtx / tilecal daughterboard
--
--
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library tilecal;
use tilecal.db6_design_package.all;

entity db6_gbtx_i2c_interface_testbeam is
  port (       
    p_clknet_in 		: in t_db_clknet;
--    p_master_reset_in  : in std_logic;
    p_db_reg_rx_in : in t_db_reg_rx;
    p_gbt_encoder_interface_in        : in t_gbt_encoder_interface;
    p_gbtx_control_in : in t_gbtx_control;
    p_gbtx_interface_out : out t_gbtx_interface;
    -- IOBUF moved to db7_io_box; split O/I/T instead of inout.
    p_sda_drive_out : out std_logic;
    p_sda_tri_out   : out std_logic;
    p_sda_read_in   : in  std_logic;
    p_scl_drive_out : out std_logic;
    p_scl_tri_out   : out std_logic;
    p_scl_read_in   : in  std_logic;

    p_leds_out : out std_logic_vector(3 downto 0)
				
				

    );
end db6_gbtx_i2c_interface_testbeam;

architecture behavioral of db6_gbtx_i2c_interface_testbeam is

--leds buffering for debug
signal s_leds_out : std_logic_vector(3 downto 0) := (others=>'0' ); 

-- trigger and config signals
signal s_trigger_i2c_operation, s_global_trigger, s_global_trigger_from_vio : std_logic := '0';
signal s_i2c_read_write_operation : std_logic;


--i2c signals
signal s_gbtx_reg_address_read : std_logic_vector(15 downto 0);
signal s_gbtx_reg_address_write : std_logic_vector(15 downto 0);
signal s_gbtx_reg_default_data : std_logic_vector(7 downto 0);
signal s_gbtx_reg_read_data : std_logic_vector(7 downto 0);
signal s_gbtx_reg_write_data : std_logic_vector(7 downto 0);
signal s_i2c_clk : std_logic;

signal s_i2c_divider : std_logic_vector(15 downto 0) := x"0000";
signal s_i2c_clk_stretch : std_logic := '0';

component db5_i2c_master_driver is
generic(
	input_clk : integer := 10000000;   --input clock speed from user logic in 10*khz
	bus_clk   : integer := 10000);   --speed the i2c bus (scl) will run at in 10*khz
port(
	clk       : in     std_logic;                    --system clock
    p_db_side : in     std_logic_vector(1 downto 0); -- db side
    p_verify_bus :in   std_logic; -- verify if the bus is being used
	reset_n   : in     std_logic;                    --active low reset
	ena       : in     std_logic;                    --latch in command
	addr      : in     std_logic_vector(6 downto 0); --address of target slave
	rw        : in     std_logic;                    --'0' is write, '1' is read
	data_wr   : in     std_logic_vector(7 downto 0); --data to write to slave
	busy      : out    std_logic;                    --indicates transaction in progress
	data_rd   : out    std_logic_vector(7 downto 0); --data read from slave
	ack_error : inout std_logic;                    --flag if improper acknowledge from slave
	sda       : inout  std_logic;                    --serial data output of i2c bus
	scl       : inout  std_logic;                   --serial clock output of i2c bus
	--test0     : out  std_logic;
	--test1     : out  std_logic;
	p_bus_busy : out std_logic;
	sda_mon   : out std_logic;
	scl_mon   : out std_logic
	
	 );	 
end component;


--signal s_scl_inout, s_sda_inout,s_scl_inout_b, s_sda_inout_b : std_logic :='1';
signal s_scl_test, s_sda_test : std_logic;
signal s_reset, s_reset_n : std_logic := '1';
signal s_ena, s_rw, s_busy, s_ack_error : std_logic;
signal s_addr: std_logic_vector (6 downto 0);
signal s_data_rd, s_data_wr: std_logic_vector(7 downto 0);
signal s_verify_bus : std_logic;
signal s_bus_busy : std_logic;

--i2c state machine control signals
type t_i2c_general_state is ( st_idle, st_busy, st_stop, st_wait_for_bus_free, st_set_reset, st_set_address_msb, st_set_address_lsb, st_trigger_register_operation, st_debounce_trigger);

--removed bypiro
signal s_start_register_address : std_logic_vector(15 downto 0) := x"0000";
--signal s_ending_register_address   : std_logic_vector(15 downto 0) := x"016d"; -- 365 decimal

signal sm_i2c : t_i2c_general_state  := st_idle;
signal s_i2c_busy_rising_edge, s_i2c_busy_falling_edge : std_logic := '0';
signal s_busy_buffer : std_logic:= '0';

signal s_wipe_gbtx_registers     :  std_logic := '0';
signal s_gbtx_default_configuration : std_logic:= '0';
signal s_gbtx_side : std_logic_vector (1 downto 0):="01";

    signal s_start_register, s_register_index, s_end_register : integer := 0;
    --signal s_db_debug_gbtx_deskew_clk_mux_reg : std_logic;


COMPONENT vio_db6_gbtx_interface
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);        
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out2 : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe_out3 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END COMPONENT;

COMPONENT blk_mem_gbtx_regs
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    clkb : IN STD_LOGIC;
    web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addrb : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    dinb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) 
  );
END COMPONENT;
signal s_blk_mem_gbtx_regs : t_blk_mem_gbtx_regs;
--    signal s_side_debug : std_logic_vector(0 downto 0);
--    signal s_address_debug : std_logic_vector(15 downto 0); 
--    signal s_data_debug : std_logic_vector(7 downto 0); 

signal s_wr_sm : integer:=0;
signal s_wr_sm_counter : integer :=0;
signal s_cfb_mb_phase_config : std_logic_vector(31 downto 0);

begin

p_gbtx_interface_out.blk_mem_gbtx_regs<=s_blk_mem_gbtx_regs;
p_gbtx_interface_out.gbtx_control <= p_gbtx_control_in;

p_leds_out<=s_leds_out;
--s_leds_out(3)<= s_i2c_read_write_operation;
p_leds_out(3)<= s_busy;
--p_bus_busy <= s_bus_busy;
s_gbtx_side <= "01";

i_blk_mem_gbtx_regs : blk_mem_gbtx_regs
  PORT MAP (
    clka => s_blk_mem_gbtx_regs.clka,
    wea => s_blk_mem_gbtx_regs.wea,
    addra => s_blk_mem_gbtx_regs.addra,
    dina => s_blk_mem_gbtx_regs.dina,
    douta => s_blk_mem_gbtx_regs.douta,
    clkb => s_blk_mem_gbtx_regs.clkb,
    web => s_blk_mem_gbtx_regs.web,
    addrb => s_blk_mem_gbtx_regs.addrb,
    dinb => s_blk_mem_gbtx_regs.dinb,
    doutb => s_blk_mem_gbtx_regs.doutb
  );

s_blk_mem_gbtx_regs.clka <= p_clknet_in.osc_clk200;
s_blk_mem_gbtx_regs.clkb <= p_clknet_in.osc_clk200;

s_blk_mem_gbtx_regs.wea <= "1";
s_blk_mem_gbtx_regs.web <= "0";
  

s_blk_mem_gbtx_regs.addra <= s_gbtx_reg_address_write(8 downto 0);
s_blk_mem_gbtx_regs.dina <= s_gbtx_reg_write_data;

--proc_ps_mux: process(p_clknet_in.osc_clk40)
--begin
--    if rising_edge(p_clknet_in.osc_clk40) then
--        s_cfb_mb_phase_config <= p_db_reg_rx_in(cfb_mb_phase_config);
--        case s_wr_sm is
--            when 0 =>
--                if p_db_reg_rx_in(cfb_mb_phase_config) = s_cfb_mb_phase_config then
                    s_gbtx_reg_address_write <= p_gbtx_control_in.gbtx_reg_address;
                    s_gbtx_reg_write_data <=  p_gbtx_control_in.gbtx_reg_value;
--                else
--                    if p_db_reg_rx_in(cfb_db_debug)(c_db_debug_gbtx_deskew_clk_mux) = '1' then
--                        s_wr_sm<=1;
--                    else
--                        s_wr_sm<=4;
--                    end if;                        
--                end if;
--            when 1=>
--                --coarse delay
--                s_gbtx_reg_address_write(8 downto 0) <= std_logic_vector(to_unsigned(8,9)); -- tp q0
--                s_gbtx_reg_write_data(4 downto 0) <= p_db_reg_rx_in(cfb_mb_phase_config)(11 downto 7); -- tp q0
--                s_wr_sm<=2;
--            when 2=>
--                --coarse delay
--                s_gbtx_reg_address_write(8 downto 0) <= std_logic_vector(to_unsigned(9,9)); -- tp q1
--                s_gbtx_reg_write_data(4 downto 0) <= p_db_reg_rx_in(cfb_mb_phase_config)(27 downto 23); -- tp q1
--                s_wr_sm<=2;
--            when 3=>
--                --fine delay
--                s_gbtx_reg_address_write(8 downto 0) <= std_logic_vector(to_unsigned(4,9)); -- tp q0, tp q1
--                s_gbtx_reg_write_data(3 downto 0)<=p_db_reg_rx_in(cfb_mb_phase_config)(6 downto 3); --tp q0
--                s_gbtx_reg_write_data(7 downto 4)<=p_db_reg_rx_in(cfb_mb_phase_config)(22 downto 19); --tp q1
--                s_wr_sm<=0;
--            when 4=>
--                --coarse delay
--                s_gbtx_reg_address_write(8 downto 0) <= std_logic_vector(to_unsigned(10,9)); -- adc q0
--                s_gbtx_reg_write_data(4 downto 0) <= p_db_reg_rx_in(cfb_mb_phase_config)(11 downto 7); -- adc q0
--                s_wr_sm<=2;
--            when 5=>
--                --coarse delay
--                s_gbtx_reg_address_write(8 downto 0) <= std_logic_vector(to_unsigned(11,9)); -- adc q1
--                s_gbtx_reg_write_data(4 downto 0) <= p_db_reg_rx_in(cfb_mb_phase_config)(27 downto 23); -- adc q1
--                s_wr_sm<=2;
--            when 6=>
--                --fine delay
--                s_gbtx_reg_address_write(8 downto 0) <= std_logic_vector(to_unsigned(5,9)); -- adc q0, adc q1
--                s_gbtx_reg_write_data(3 downto 0)<=p_db_reg_rx_in(cfb_mb_phase_config)(6 downto 3); --adc q0
--                s_gbtx_reg_write_data(7 downto 4)<=p_db_reg_rx_in(cfb_mb_phase_config)(22 downto 19); --adc q1
--                s_wr_sm<=0;
--            when others=>
--                s_wr_sm<=0;
            
--        end case;
--    end if;
--end process;
-----------------------------------------------------
-- state machine to configure local or remote gbtx --
-----------------------------------------------------

proc_i2c_transaction : process(p_clknet_in.osc_clk40)
    
    --variable v_start_register, v_register_index, v_end_register : integer := 0;
    --variable v_counter : integer:=0;
    --variable v_gbtx_lut_index : integer:=0;
    --variable v_previous_scl, v_previous_sda : std_logic :='0';
    --constant gbtx_i2c_arbitration_constant :integer :=50000000;
begin

    if rising_edge (p_clknet_in.osc_clk40) then
    
      s_blk_mem_gbtx_regs.addrb<= std_logic_vector(to_unsigned(s_register_index,9));
    
      s_busy_buffer <= s_busy;                       --capture the value of the previous i2c busy signal
      if (s_busy_buffer = '0' and s_busy = '1') then  --i2c busy just went high
        s_i2c_busy_rising_edge <= '1';                       -- ready to execute next operation
      else
        s_i2c_busy_rising_edge <= '0';                       --wait until operation is finished
      end if;
 
      if(s_busy_buffer = '1' and s_busy = '0') then  --i2c busy just went high
        s_i2c_busy_falling_edge <= '1';                       -- ready to execute next operation
      else
        s_i2c_busy_falling_edge  <= '0';                       --wait until operation is finished
      end if;
      
      

      case sm_i2c is
      -- i2c controller is idle.  release control of bus, and wait for init
        when st_idle =>
                
                p_gbtx_interface_out.busy <= '0';
                s_ena <= '0';
                s_reset_n <= '0';
                s_register_index <= 0;
                
                --set up propper address range, gbtx has only 365 writeable regs and 4xx readeable
                --if p_db_reg_rx_in(cfb_mb_phase_config)(12) = '0' and p_db_reg_rx_in(cfb_mb_phase_config)(13) = '0' then
                    --s_gbtx_default_configuration<= p_gbtx_control_in.gbtx_default_config;
                    if s_i2c_read_write_operation = '0' then
                        s_start_register <= 0;
                        --v_end_register := 15;
                        s_end_register <= 366;
                    else
                        s_start_register <= 0;
                        s_end_register <= 435;
                    end if;
                --else
--                    v_start_register:= to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(11 downto 0)));
--                    v_end_register:=to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(11 downto 0)));
                    --s_gbtx_default_configuration<= '0';
                --    s_start_register <= 0;
                --    s_end_register <= 15;
                --end if;
               
                s_start_register_address<= std_logic_vector(to_unsigned(s_start_register,16));
                
                --buffer in signals
                s_i2c_read_write_operation <= p_gbtx_control_in.gbtx_i2c_read_write_operation;
                s_wipe_gbtx_registers<= p_gbtx_control_in.wipe_gbtx_registers;
                
                --gbtx side signal multiplexer to avoid use of illegal addresses

                
                --gbtx address and data mod from configbus (cfb_gbtx_reg_config)
--                s_gbtx_register_configuration(to_integer(unsigned(p_user_address_in)))<=p_user_data_in;
--                p_user_data_out<=s_gbtx_register_readout_array(to_integer(unsigned(p_gbtx_db_side))-1)(to_integer(unsigned(p_user_address_in)));
                
                s_leds_out(2 downto 0)<="000";

                --trigger code
                if s_trigger_i2c_operation = '1' then
                  sm_i2c <= st_set_reset;
                else
                  sm_i2c <= st_idle;
                end if;
                
        when st_set_reset =>
                p_gbtx_interface_out.busy <= '1';
                s_reset_n <= '1';
                sm_i2c <= st_set_address_lsb;
                s_verify_bus <='1';-- and s_probe_out0(15); 
                
                s_leds_out(2 downto 0)<="010";
                              
        
        when st_set_address_lsb =>
              p_gbtx_interface_out.busy <= '1';
              s_verify_bus <='1';--  and s_probe_out0(15); 
              --p_busy_out <= '1';  
              s_reset_n <= '1';
              
              s_ena <= '1';                            
              s_addr <= "00000"&s_gbtx_side;                    
              s_rw <= '0';                           -- write operation  
              s_data_wr <= s_start_register_address(7 downto 0);    -- transmit lower 8 bits of starting register address
              if s_i2c_busy_rising_edge = '1' then 
                sm_i2c <= st_set_address_msb;
              end if;
              
              s_leds_out(2 downto 0)<="011";

        when st_set_address_msb =>
              p_gbtx_interface_out.busy <= '1';
              s_verify_bus <='1';-- and s_probe_out0(15); 
              --p_busy_out <= '1';
              s_reset_n <= '1';
              
              s_ena <= '1';                            
              s_addr <= "00000"&s_gbtx_side;                    
              s_rw <= '0';                             
              s_data_wr <= s_start_register_address(15 downto 8); -- transmit upper 8 bits of starting register address
                    
              if s_i2c_busy_rising_edge = '1' then
                s_register_index <= s_start_register+1;
                sm_i2c <= st_trigger_register_operation;
              end if;
              
              s_leds_out(2 downto 0)<="100";
              
        when st_trigger_register_operation =>
              p_gbtx_interface_out.busy <= '1';
              s_verify_bus <='1';-- and s_probe_out0(15); 
              --p_busy_out <= '1';
              s_reset_n <= '1';
              
              s_addr <= "00000"&s_gbtx_side; 
              s_rw <= s_i2c_read_write_operation; --'0';

              
              if s_i2c_read_write_operation = '0' then
                if s_wipe_gbtx_registers = '0' then
--                    if s_gbtx_default_configuration = '0' then
--                        s_data_wr <= s_gbtx_register_configuration(s_register_index); -- transmit 8 bits of register data
--                    else
--                        s_data_wr <= s_gbtx_register_default_configuration(s_register_index); -- transmit 8 bits of register data
--                    end if;
                    s_data_wr<= s_blk_mem_gbtx_regs.doutb;
                else
                    s_data_wr <= x"00";
                end if;
              else
                if s_i2c_busy_falling_edge = '1' then
--                    s_gbtx_register_readout(s_register_index-1) <=s_data_rd; --read register                
                end if;
              end if;
              
              if s_i2c_busy_rising_edge = '1' then
              
                  s_register_index <= s_register_index + 1;
                  if s_register_index > s_end_register+1 then -- writing the final word....
                    sm_i2c <= st_stop;  
                    s_ena <= '0';
                  else
--                    sm_i2c <= st_limbo ;
                    s_ena <= '1';
                  end if;                                            
                  
              end if;
              
              s_leds_out(2 downto 0)<="101";
        
        
        when st_stop => -- wait for i2c master to finish the last operation
              p_gbtx_interface_out.busy <= '1';
              s_verify_bus <='1';-- and s_probe_out0(15);               p_busy_out <= '1';
              s_reset_n <= '1';
              s_ena <= '0';
              if s_i2c_busy_falling_edge = '1' then
                sm_i2c <= st_idle;
              end if;
              s_leds_out(2 downto 0)<="110";
        when others =>
            p_gbtx_interface_out.busy <= '1';
            sm_i2c <= st_idle;
            
        end case; 
     end if; -- clock edge
end process; -- i2c_control



s_reset<=not s_reset_n;
i_db6_i2c_master : entity tilecal.db6_i2c_master
  port map(
        p_clk_in            => p_clknet_in.osc_clk40, -- system clk
        p_master_reset_in   => s_reset,
        p_divider_in        => s_i2c_divider,--x"0000", -- i2c_speed (period)
        p_enable_clk_stretch_in => s_i2c_clk_stretch, --'1',
        p_ena_in       => s_ena,
        p_addr_in      => s_addr,
        p_rw_in        => s_rw,
        p_data_in      => s_data_wr,
        p_busy_out     => s_busy,
        p_data_out     => s_data_rd,
        p_ack_error_buffer => s_ack_error,
        p_sda_drive_out => p_sda_drive_out,
        p_sda_tri_out   => p_sda_tri_out,
        p_sda_read_in   => p_sda_read_in,
        p_scl_drive_out => p_scl_drive_out,
        p_scl_tri_out   => p_scl_tri_out,
        p_scl_read_in   => p_scl_read_in,
        p_sda_test_out    => s_sda_test,
        p_scl_test_out => s_scl_test,
        p_read_state_out  => open,
        p_completed_transaction_out => open
    );
	

--s_trigger_i2c_operation <= p_trigger_i2c_operation_in; -- or s_debug_gbtx_i2c_trigger(0); --old not-debounced signal
s_global_trigger <= --p_db_reg_rx_in(cfb_mb_phase_config)(12) or 
                   -- p_db_reg_rx_in(cfb_mb_phase_config)(13) or 
                    p_gbtx_control_in.gbtx_trigger_i2c_operation or
                    s_global_trigger_from_vio; 

proc_trigger_monitor : process(p_clknet_in.osc_clk40, s_global_trigger)
type t_trigger_monitor_sm is (st_idle,st_debouncer);
variable v_trigger_monitor_sm : t_trigger_monitor_sm := st_idle;
begin
	if rising_edge(p_clknet_in.osc_clk40) then
		case v_trigger_monitor_sm is
			when st_idle =>
				s_trigger_i2c_operation<='0';
				if (s_global_trigger='1') then -- or (p_user_config_in(31)='1') then
					s_trigger_i2c_operation<='1';
					v_trigger_monitor_sm:=st_debouncer;
				end if;
			when st_debouncer=>
				s_trigger_i2c_operation<='0';
				if (s_global_trigger='0') then --and (p_user_config_in(31)='0')then
					v_trigger_monitor_sm:=st_idle;
				end if;
			when others=>
		end case;
	end if;
end process;
    

end behavioral;
