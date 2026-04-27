----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.10.2022 23:08:56
-- Design Name: 
-- Module Name: db6_cfgbus_interface_decoder - Behavioral
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

library tilecal;
use tilecal.db6_design_package.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_cfgbus_interface_decoder_iddr is
    generic (
        g_tmr_enabled      : natural := 0;        -- 0 = no_tmr, 1 = tmr
        g_ila_sync_enabled      : natural := 0;        -- 0 = no_ila_sync, 1 = enable ila
        g_vio_configbus_registers : natural :=0        -- 0 = no vio, 1 enable vio
    );
    Port (     
               p_master_reset_in        : in    std_logic;
               p_iddr_clk_in            : in    std_logic;
               p_clknet_in              : in    t_db_clknet;  
               p_cfgbus_bitslice_in  : in t_cfgbus_bitslice;
               
               p_db_reg_rx_out      : out t_db_reg_rx;
               p_reg_rx_strobe_out  : out std_logic_vector(31 downto 0);--integer range 0 to 15;
               p_bcr_out    : out t_bcr;
               
               p_leds_out : out std_logic_vector(3 downto 0)
    );
end db6_cfgbus_interface_decoder_iddr;

architecture Behavioral of db6_cfgbus_interface_decoder_iddr is

    signal s_db_cfgbus_datavalid_shift_register : std_logic_vector(4 downto 0);
    signal s_db_cfgbus_address_shift_register : std_logic_vector(15 downto 0);
    signal s_db_cfgbus_data_shift_register : std_logic_vector(31 downto 0);
    signal s_db_cfgbus_byte_shift_register : std_logic_vector(7 downto 0);
    
    signal s_strobe_bit_cfgbus : std_logic := '0';

    signal s_db_reg_rx : t_db_reg_rx := c_db_reg_rx;
    signal s_reg_rx_strobe : std_logic_vector(31 downto 0); -- integer range 0 to 15;
    
    signal s_strobe_reg : std_logic_vector(31 downto 0) := (others =>'0');
    signal s_strobe_reg_buffer : std_logic_vector(31 downto 0);
    signal s_lhc_bunch_counter : std_logic_vector(31 downto 0) := (others =>'0');
    signal s_counter : integer := 0;
    signal s_bcrlock : std_logic := '0';
    signal s_maxcount : integer := 0;
    signal s_bcr_watchdog : integer:= 0;
    
    signal s_bcr_locked : std_logic := '0';
    signal s_bcr : std_logic := '0';

-- debug components
    signal s_db_reg_rx_debug : t_db_reg_rx;
    COMPONENT ila_configbus_sync_test
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe6 : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT  ;
    
    COMPONENT vio_configbus_registers_debug
    PORT (
        clk : IN STD_LOGIC;
        probe_in0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in5 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in6 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in7 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in8 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in9 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in10 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in11 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in12 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in13 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in14 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in15 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in16 : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT;
    
begin

    -- Enter each new 8-bit cfgbus word to the input shift register:
    
        proc_config_bus_shift_in_data : process(p_iddr_clk_in, p_master_reset_in)
        
        --sync to orbit
        constant c_watchdog_tries : integer := 31;
        variable v_counter : integer := 0;
        variable v_bcrlock: std_logic := '0';
        variable v_maxcount : integer := 0;
        variable v_bcr_watchdog : integer:= 0;
        begin
            if p_master_reset_in = '1' then
                s_db_cfgbus_datavalid_shift_register <= (others=> '0');
                s_db_cfgbus_address_shift_register <= (others=> '0');
                s_db_cfgbus_data_shift_register <= (others=> '0');
                s_db_cfgbus_byte_shift_register <= (others=> '0');
            elsif rising_edge(p_iddr_clk_in) then


                --shift in data and orbit cross from the cfgbus
                s_db_cfgbus_datavalid_shift_register <= s_db_cfgbus_datavalid_shift_register(3 downto 0) & p_cfgbus_bitslice_in(6)(1);

                s_db_cfgbus_address_shift_register <=  
                    p_cfgbus_bitslice_in(5)(1)& p_cfgbus_bitslice_in(4)(1) &  p_cfgbus_bitslice_in(3)(1)& p_cfgbus_bitslice_in(2)(1)
                    & s_db_cfgbus_address_shift_register(15 downto 4);
                s_db_cfgbus_data_shift_register <= 
                    p_cfgbus_bitslice_in(7)(0)& p_cfgbus_bitslice_in(6)(0)& p_cfgbus_bitslice_in(5)(0)& p_cfgbus_bitslice_in(4)(0) &
                    p_cfgbus_bitslice_in(3)(0)& p_cfgbus_bitslice_in(2)(0)& p_cfgbus_bitslice_in(1)(0)& p_cfgbus_bitslice_in(0)(0) &
                    s_db_cfgbus_data_shift_register(31 downto 8);
                s_db_cfgbus_byte_shift_register <= p_cfgbus_bitslice_in(1)(1)& p_cfgbus_bitslice_in(0)(1) & s_db_cfgbus_byte_shift_register(7 downto 2);
                
            end if; -- clock edge
        
        end process;

        proc_register_data_configbus : process(p_iddr_clk_in, p_master_reset_in)
        --register data
        variable v_cfg_db_advanced_mode_address, v_cfg_db_advanced_mode_register_value : std_logic_vector(31 downto 0);
        
        --strobe manager        
        variable v_counter : integer := 0;
        type t_strobe_manager_sm is (st_idle, st_wait_for_strobe_bit, st_propagate_strobe);
        variable sm_strobe_manager : t_strobe_manager_sm := st_idle;
--        variable v_reg_buffer : std_logic_vector(31 downto 0);
--        variable v_strobe_lenght : integer := 0;
        variable v_clk_domain_cross_counter : integer :=0;
        constant c_clk_strobe_lenght : integer := 3;
--        constant c_domain_cross_ratio : integer := 40000000/100;
        
        begin
             if p_master_reset_in = '1' then
             
             elsif rising_edge(p_iddr_clk_in) then
                
    -- register data
        --check that all clocks are locked
             --if (p_clknet_in.locked_db = '1') then-- and (p_master_reset_in = '0') then
                    
                     if (s_db_cfgbus_datavalid_shift_register(3 downto 0) = "1110") and (s_db_cfgbus_byte_shift_register = "11100100") then
                        
                        --s_db_reg_rx(cfb_command_counter)<=std_logic_vector(to_unsigned(to_integer(unsigned(s_db_reg_rx(cfb_command_counter)))+1,32));
                        case  s_db_cfgbus_address_shift_register(11 downto 0) is
                            when c_db_reg_rx_lut(cfb_db_reg_mask)=>
                                s_strobe_bit_cfgbus<='0';
                                s_db_reg_rx(cfb_db_reg_mask)<= s_db_cfgbus_data_shift_register;
                            
                            when c_db_reg_rx_lut(cfb_mb_phase_config)=>
                                s_strobe_bit_cfgbus<='0';
                                s_db_reg_rx(cfb_mb_phase_config)<= (s_db_cfgbus_data_shift_register and s_db_reg_rx(cfb_db_reg_mask)) 
                                    or (s_db_reg_rx(cfb_mb_phase_config) and (not s_db_reg_rx(cfb_db_reg_mask)));
                                s_reg_rx_strobe(cfb_mb_phase_config) <= '1';
                                                                    
                            when c_db_reg_rx_lut(cfb_strobe_reg)=>
                                s_strobe_bit_cfgbus<='1';
                                s_db_reg_rx(cfb_strobe_reg)<=s_db_cfgbus_data_shift_register;
                                s_reg_rx_strobe(cfb_strobe_reg) <= '1';
--                            when c_db_reg_rx_lut(cfb_db_advanced_reg_address)=>
--                                s_strobe_bit_cfgbus<='0';
--                                s_db_reg_rx(cfb_db_advanced_reg_address)<=(s_db_cfgbus_data_shift_register);
----                                s_db_reg_rx(cfb_wr_strobe)(15 downto 0)<= s_db_cfgbus_address_shift_register;
                                                                    
--                            when c_db_reg_rx_lut(cfb_db_advanced_reg_value)=>
--                                s_strobe_bit_cfgbus<='0';
--                                s_db_reg_rx(cfb_db_advanced_reg_value)<=(s_db_cfgbus_data_shift_register);
--                                s_db_reg_rx(to_integer(unsigned(s_db_reg_rx(cfb_db_advanced_reg_address))))<=
--                                    (s_db_cfgbus_data_shift_register and s_db_reg_rx(cfb_db_reg_mask))
--                                    or (s_db_reg_rx(to_integer(unsigned(s_db_reg_rx(cfb_db_advanced_reg_address)))) and (not s_db_reg_rx(cfb_db_reg_mask)));
----                                s_db_reg_rx(cfb_wr_strobe)(15 downto 0)<= s_db_cfgbus_address_shift_register;
                                
                            when c_db_reg_rx_lut(cfb_cis_config) =>
                                s_strobe_bit_cfgbus<='0';
                                s_db_reg_rx(cfb_cis_config)<= (s_db_cfgbus_data_shift_register and s_db_reg_rx(cfb_db_reg_mask)) 
                                    or (s_db_reg_rx(cfb_cis_config) and (not s_db_reg_rx(cfb_db_reg_mask)));
                                s_reg_rx_strobe(cfb_cis_config) <= '1';
--                                s_db_reg_rx(cfb_wr_strobe)(15 downto 0)<= s_db_cfgbus_address_shift_register;
                                
--                            when c_db_reg_rx_lut(cfb_cs_command) =>
--                                s_strobe_bit_cfgbus<='0';
--                                s_db_reg_rx(cfb_cs_command)<= (s_db_cfgbus_data_shift_register and s_db_reg_rx(cfb_db_reg_mask)) 
--                                    or (s_db_reg_rx(cfb_cs_command) and (not s_db_reg_rx(cfb_db_reg_mask)));
----                                s_db_reg_rx(cfb_wr_strobe)(15 downto 0)<= s_db_cfgbus_address_shift_register;
                                
                            when c_db_reg_rx_lut(cfb_integrator_interval) =>
                                s_strobe_bit_cfgbus<='0';
                                s_db_reg_rx(cfb_integrator_interval)<= (s_db_cfgbus_data_shift_register and s_db_reg_rx(cfb_db_reg_mask)) 
                                    or (s_db_reg_rx(cfb_integrator_interval) and (not s_db_reg_rx(cfb_db_reg_mask)));
                                s_reg_rx_strobe(cfb_integrator_interval) <= '1';
--                                s_db_reg_rx(cfb_wr_strobe)(15 downto 0)<= s_db_cfgbus_address_shift_register;
--                            when c_db_reg_rx_lut(cfb_command_counter) =>
                                    
--                            when c_db_reg_rx_lut(cfb_wr_strobe) =>
                                s_strobe_bit_cfgbus<='0';
                                
                            when others=>
                                s_strobe_bit_cfgbus<='0';
                                s_db_reg_rx(to_integer(unsigned(s_db_cfgbus_address_shift_register(11 downto 0))))<= (s_db_cfgbus_data_shift_register and s_db_reg_rx(cfb_db_reg_mask)) 
                                    or (s_db_reg_rx(to_integer(unsigned(s_db_cfgbus_address_shift_register(11 downto 0)))) and (not s_db_reg_rx(cfb_db_reg_mask)));
                                s_reg_rx_strobe(to_integer(unsigned(s_db_cfgbus_address_shift_register(4 downto 0)))) <= '1';
--                                s_db_reg_rx(cfb_wr_strobe)(15 downto 0)<= s_db_cfgbus_address_shift_register;
                                
                        end case;
                        
                    else
                        s_strobe_bit_cfgbus<='0';
                        s_reg_rx_strobe <= x"00000000";             
                    end if;
                --end if;
     -- strobe manager
     
                     case sm_strobe_manager is
                        when st_idle=>
                            if s_strobe_bit_cfgbus = '1' then
                                v_counter := 0;
                                if s_db_reg_rx(cfb_db_debug)(c_db_debug_cfgbus_strobe_persist) = '1' then
                                    if (s_db_reg_rx(cfb_strobe_reg)=x"00000000") then
                                        s_strobe_reg_buffer<= s_db_reg_rx(cfb_strobe_reg);
                                    else
                                        s_strobe_reg<= s_db_reg_rx(cfb_strobe_reg);
                                    end if;
                                    sm_strobe_manager := st_idle;
                                else
                                    sm_strobe_manager := st_wait_for_strobe_bit;
                                    s_strobe_reg_buffer<= s_db_reg_rx(cfb_strobe_reg);
                                end if;
                                
                            else
                                s_strobe_reg <= (others=>'0');
                            end if;
                        when st_wait_for_strobe_bit =>
                            v_clk_domain_cross_counter:=0;
                            v_counter:=0;
                            if (s_strobe_bit_cfgbus='0') then
                                sm_strobe_manager:=st_propagate_strobe;
                            else
                                sm_strobe_manager := st_wait_for_strobe_bit;
                            end if;
                        when st_propagate_strobe =>
                            if v_counter < c_clk_strobe_lenght then
                                v_counter:=v_counter+1;
                                s_strobe_reg <= s_strobe_reg_buffer;
                            else
                                sm_strobe_manager := st_idle;
                                v_counter :=0;
                                s_strobe_reg <= (others=>'0');
                            end if;
                        when others=>
                            sm_strobe_manager := st_idle;
                    end case;
                --end if;
            end if;
        end process;

        proc_sync_to_orbit: process(p_iddr_clk_in, p_master_reset_in)
        constant c_watchdog_tries : integer := 31;
    
        begin
            if p_master_reset_in = '1' then
            
            elsif rising_edge(p_iddr_clk_in) then
                
                    s_lhc_bunch_counter <= std_logic_vector(to_unsigned(s_counter,32));
                    s_bcr_locked <=  s_bcrlock;
                    s_bcr <= p_cfgbus_bitslice_in(7)(1);
                
                    if p_cfgbus_bitslice_in(7)(1) = '1' then
                        s_maxcount <= s_counter;
                        if (s_maxcount = (c_lhc_bunches_between_bcr-1)) then
                            s_bcrlock <= '1';
                            
                         else
                            s_bcrlock <= '0';
        
                        end if;
                        s_counter <= 0;                
                    else
                        s_counter <= s_counter + 1;
                   
                    end if;
--                end if;
            end if; -- Clock edge
        
        end process; -- proc_sync_to_orbit

    p_bcr_out.bcr <= p_cfgbus_bitslice_in(7)(1) and (s_bcr_locked);
    p_bcr_out.bcr_locked<=(s_bcr_locked);
    p_bcr_out.count<= (s_lhc_bunch_counter);

    p_reg_rx_strobe_out <= s_reg_rx_strobe;
    gen_reg_output : for reg in 0 to cfb_strobe_reg-1 generate    
    begin
        p_db_reg_rx_out(reg) <= s_db_reg_rx(reg);
        s_db_reg_rx_debug(reg) <= s_db_reg_rx(reg);
    end generate gen_reg_output;
        p_db_reg_rx_out(cfb_strobe_reg) <= s_strobe_reg;
        s_db_reg_rx_debug(cfb_strobe_reg) <= s_strobe_reg;
    gen_advanced_reg_output : for reg in cfb_strobe_reg+1 to  c_number_of_cfgbus_regs-1 generate
    begin
        p_db_reg_rx_out(reg) <= s_db_reg_rx(reg);
        s_db_reg_rx_debug(reg) <= s_db_reg_rx(reg);
    end generate gen_advanced_reg_output;
    
    gen_ila_sync_enabled : if g_ila_sync_enabled = 1 generate
        i_ila_configbus_sync_test : ila_configbus_sync_test
        PORT MAP (
            clk => p_iddr_clk_in,
            probe0 => s_db_cfgbus_datavalid_shift_register, 
            probe1 => s_db_cfgbus_byte_shift_register, 
            probe2 => s_db_cfgbus_address_shift_register, 
            probe3 => s_db_cfgbus_data_shift_register, 
            probe4(0) => p_cfgbus_bitslice_in(7)(1), 
            probe5(0) => s_bcr,
            probe6 => s_lhc_bunch_counter
        );
    end generate;
    gen_vio_configbus_registers : if g_vio_configbus_registers = 1 generate
        i_vio_configbus_registers : vio_configbus_registers_debug
          PORT MAP (
            clk => p_clknet_in.osc_clk40,
            probe_in0 => s_db_reg_rx_debug(0),
            probe_in1 => s_db_reg_rx_debug(1),
            probe_in2 => s_db_reg_rx_debug(2),
            probe_in3 => s_db_reg_rx_debug(3),
            probe_in4 => s_db_reg_rx_debug(4),
            probe_in5 => s_db_reg_rx_debug(5),
            probe_in6 => s_db_reg_rx_debug(6),
            probe_in7 => s_db_reg_rx_debug(7),
            probe_in8 => s_db_reg_rx_debug(8),
            probe_in9 => s_db_reg_rx_debug(9),
            probe_in10 => s_db_reg_rx_debug(10),
            probe_in11 => s_db_reg_rx_debug(11),
            probe_in12 => s_db_reg_rx_debug(12),
            probe_in13 => s_db_reg_rx_debug(13),
            probe_in14 => s_db_reg_rx_debug(14),
            probe_in15 => s_db_reg_rx_debug(15),
            probe_in16 => s_db_reg_rx_debug(16)
          );
   end generate;
end Behavioral;
