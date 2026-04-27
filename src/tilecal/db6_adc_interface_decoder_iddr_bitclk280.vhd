---------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.10.2022 00:26:50
-- Design Name: 
-- Module Name: db6_adc_interface_decoder_iddr - Behavioral
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

library tilecal;
use tilecal.db6_design_package.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity db6_adc_interface_decoder_iddr_bitclk280 is
    generic (
        g_tmr_enabled : std_logic := '1'
    );
    port ( 	
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;
        
        --inputs
        p_adc_bitclk_in : in std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_in : in std_logic_vector(5 downto 0);
        p_adc_frameclk_in : in t_bitslice_sr;
--        p_frame_missalignment_in : in std_logic_vector(5 downto 0);
--        p_adc_gbtx_frameclk_in : in std_logic_vector(5 downto 0);
        p_adc_lg_data_in : in t_bitslice_sr;
        p_adc_hg_data_in : in t_bitslice_sr;
        
        
        --control
        p_adc_readout_control_in : in t_adc_readout_control;
        
        --output
        p_adc_readout_out       : out t_adc_readout;
        
        --debug
        p_leds_out      : out std_logic_vector(3 downto 0)
				);
end db6_adc_interface_decoder_iddr_bitclk280;

architecture Behavioral of db6_adc_interface_decoder_iddr_bitclk280 is

--    signal s_adc_channel_sr_fc, s_adc_channel_sr_lg, s_adc_channel_sr_hg : t_adc_channel_sr;
    signal s_adc_channel_fifo_fc, s_adc_channel_fifo_hg, s_adc_channel_fifo_lg : t_adc_channel_fifo; --t_adc_channel_fifo_cdc;--t_adc_channel_fifo;
    signal s_adc_input_fc_buffer, s_adc_input_fc_cdc_buffer, s_adc_input_lg_cdc_buffer, s_adc_input_lg_buffer, s_adc_input_hg_cdc_buffer, s_adc_input_hg_buffer : t_adc_data; --t_adc_oversample_data_type;--t_adc_data;
    signal s_channel_frame_missalignemt, s_channel_frame_missalignemt_reg, s_channel_frame_missalignemt_buffer_lg, s_channel_frame_missalignemt_buffer_hg , s_channel_frame_missalignemt_buffer_delayed, s_channel_frame_missalignemt_reset : std_logic_vector (5 downto 0) := (others => '1');
    signal s_channel_phase, s_channel_locked,s_channel_missed_locked, s_channel_missed_bit_count : std_logic_vector(5 downto 0);
    type t_cdc_transition is array (0 to 5) of std_logic;
    signal s_cdc_transition : t_cdc_transition := (others=> '0');
    type t_counter_array is array (0 to 5) of integer range 0 to 31;
--    signal s_counter_array_lg, s_counter_array_hg, s_counter_cdc_array_lg, s_counter_cdc_array_hg, s_counter_cdc_align_array, s_counter_cdc_align_array_reg : t_counter_array;
    type t_counter_std_logic_vector_array is array (0 to 5) of std_logic_vector(3 downto 0);
    signal s_counter_array_debug, s_counter_cdc_array_debug, s_counter_cdc_align_array_debug : t_counter_std_logic_vector_array;
    
    signal s_adc_lg_data_sr, s_adc_hg_data_sr, s_adc_fc_data_sr : t_bitslice_sr;
    
    signal s_adc_readout : t_adc_readout :=
        (
            lg_bitslip => (others => "0111"),
            hg_bitslip => (others => "0111"),
            lg_idelay_count => (others =>"000000000"),
            hg_idelay_count => (others =>"000000000"),
            fc_idelay_count => (others =>"000000000"),
            lg_data =>(others=>"00000000000000"),
            hg_data =>(others=>"00000000000000"),
            fc_data =>(others=>"00000000000000"),
            
            channel_cdc_align_counter => (others=> (others=>'0')),
            channel_phase_offset => (others=>'0'),
            channel_missed_bit_count=>(others=>'0'),
            channel_frame_missalignemt => (others=>'0'),
            channel_locked => (others=>'0'),
            channel_missed_locked => (others=>'0'),
            channel_clk280_locked => (others=>'0'),
            channel_clk280_stopped => (others=>'0'),
            channel_valid_fc_frame_counter => (others =>(others=>'0')),
            channel_invalid_fc_frame_counter => (others =>(others=>'0')),
            channel_valid_divclk_frame_counter => (others =>(others=>'0')),
            --channel_valid_lg_frame_counter => (others =>(others=>'0')),
            channel_invalid_lg_frame_counter => (others =>(others=>'0')),
            --channel_valid_hg_frame_counter => (others =>(others=>'0')),
            channel_invalid_hg_frame_counter => (others =>(others=>'0')),
        
            channel_enable_test_pattern => (others=> '0'),
            channel_lg_data_test_pattern => (others => (others=> '0')),
            channel_hg_data_test_pattern => (others => (others=> '0')),
            channel_pedestal_test_underflow_lg_counter => (others => (others=> '0')),
            channel_pedestal_test_overflow_lg_counter => (others => (others=> '0')),
            channel_pedestal_test_underflow_hg_counter => (others => (others=> '0')),
            channel_pedestal_test_overflow_hg_counter => (others => (others=> '0')),
            
            channel_pedestal_test_overflow => (others=> '0'),
            channel_pedestal_test_underflow => (others=> '0'),
        
            readout_initialized => '0',
            
            mb_adc_config_control => c_adc_register_init_config_14_bit,
            
            channel_fifo_block_ram_fc => s_adc_channel_fifo_fc,
            channel_fifo_block_ram_lg => s_adc_channel_fifo_lg,
            channel_fifo_block_ram_hg => s_adc_channel_fifo_hg,
                
            channel_leds => (others => "0000"),
            
            tmr_enabled => g_tmr_enabled,
            tmr_error_lg => (others => '0'),
            tmr_error_hg => (others => '0'),
            tmr_error_fc => (others => '0'),
            tmr_error => (others => '0')
        );
    
    type t_channel_counter_integer is array (0 to 5) of integer;
    signal s_channel_valid_fc_frame_counter, s_channel_invalid_fc_frame_counter, s_channel_initial_difference_counter, s_channel_difference_counter, s_channel_local_counter : t_channel_counter_integer;
    
    --signal s_channel_valid_fc_frame_counter, s_channel_valid_fc_frame_counter_pipelined, s_channel_valid_fc_frame_counter_reg, s_channel_invalid_fc_frame_counter, s_channel_invalid_fc_frame_counter_pipelined, s_channel_invalid_fc_frame_counter_reg, s_channel_valid_divclk_frame_counter, s_channel_initial_difference_counter, s_channel_difference_counter, s_channel_difference_counter_reg : t_channel_counter;
    signal s_invalid_frame_flag, s_first_frame_counted, s_first_count_aligned, s_first_state_achieved  : std_logic_vector(5 downto 0) := (others => '0' );
    
    type t_sync_bitclkdiv_state is array (0 to 5) of integer range 0 to 14;
    signal s_sync_bitclkdiv_state_lg, s_sync_bitclkdiv_state_hg: t_sync_bitclkdiv_state;
    type t_counter_sm is array (0 to 5) of integer range 0 to 14;
    signal s_counter_sm : t_counter_sm :=(others=>0);
    signal s_cdc_reset_in, s_cdc_reset_out : std_logic_vector(5 downto 0);
    signal s_calculated : std_logic_vector(5 downto 0);
    constant c_pipeline_depth : integer := 7;--c_global_pipeline_depth;
--    type t_adc_data_pipeline is array (0 to c_pipeline_depth-1) of t_adc_data;
--    signal s_adc_data_lg_pipeline, s_adc_data_hg_pipeline, s_adc_data_fc_pipeline : t_adc_data_pipeline;
    

    component pll_adc_channel
    port
     (-- Clock in ports
      -- Clock out ports
      p_clk280_out          : out    std_logic;
      -- Status and control signals
      p_locked_out            : out    std_logic;
      p_clk_in           : in     std_logic
     );
    end component;
    type t_pll_adc_channel is record
      clk280_out          : std_logic;
      locked_out            : std_logic;
      clk_in           : std_logic;
    end record;
    type t_pll_adc_channel_array is array (0 to 5) of t_pll_adc_channel;
    signal s_pll_adc_channel_array : t_pll_adc_channel_array;
    
    
--debug
COMPONENT vio_adc_readout_cdc
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
    probe_in6 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in10 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in11 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in12 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in13 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in14 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in15 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in16 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    probe_in17 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END COMPONENT;
    
begin

p_adc_readout_out <= s_adc_readout;

gen_adc_channels: for v_adc in 0 to 5 generate


    i_pll_adc_channel : pll_adc_channel
       port map ( 
      -- Clock out ports  
       p_clk280_out => s_pll_adc_channel_array(v_adc).clk280_out,
      -- Status and control signals                
       p_locked_out => s_pll_adc_channel_array(v_adc).locked_out,
       -- Clock in ports
       p_clk_in => s_pll_adc_channel_array(v_adc).clk_in
     );

    s_pll_adc_channel_array(v_adc).clk_in <= p_adc_bitclk_in(v_adc);
    s_adc_readout.channel_clk280_locked(v_adc) <= s_pll_adc_channel_array(v_adc).locked_out;

    
    
        proc_mon : process(p_clknet_in.cfgbus_clk40, s_cdc_reset_in(v_adc)) -- odd data bits clocked in on rising edge of adc clocks
        type t_mon_sm is (st_start, st_calculate, st_monitor);
        variable v_mon_st : t_mon_sm :=st_start;
        begin
        
            if s_cdc_reset_in(v_adc) = '1' then
                s_channel_valid_fc_frame_counter(v_adc)<= 0;
                s_channel_invalid_fc_frame_counter(v_adc)<= 0;
                s_channel_local_counter(v_adc)<=0;
                s_channel_locked(v_adc)<= '0';
                s_channel_missed_locked(v_adc)<= '0';
                s_channel_missed_bit_count(v_adc)<='0';
                v_mon_st:=st_start;
            elsif rising_edge(p_clknet_in.cfgbus_clk40) then
            
                if to_integer(unsigned(s_adc_readout.hg_data(v_adc)))>to_integer(unsigned(p_clknet_in.adc_readout_high_threshold)) then
                    s_adc_readout.channel_pedestal_test_overflow(v_adc)<='1';
                else
                    s_adc_readout.channel_pedestal_test_overflow(v_adc)<='0';
                end if;
                if to_integer(unsigned(s_adc_readout.hg_data(v_adc)))<to_integer(unsigned(p_clknet_in.adc_readout_low_threshold)) then
                    s_adc_readout.channel_pedestal_test_underflow(v_adc)<='1';
                else
                    s_adc_readout.channel_pedestal_test_underflow(v_adc)<='0';
                end if;

            
                case v_mon_st is
                    when st_start=>
                        if s_adc_input_fc_cdc_buffer(v_adc) = "11111110000000" then
                            s_channel_local_counter(v_adc)<=s_channel_local_counter(v_adc)+1;
                            s_channel_valid_fc_frame_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '1';
                            v_mon_st:=st_calculate;
                        else
                            s_channel_locked(v_adc)<= '0';
                            s_channel_valid_fc_frame_counter(v_adc)<= 0;
                            s_channel_invalid_fc_frame_counter(v_adc)<= 0;
                            s_channel_local_counter(v_adc)<=0;
                        end if;
    
                    when st_calculate=>
                        if s_calculated(v_adc) = '0' then
                            s_channel_initial_difference_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc) - s_channel_local_counter(v_adc);
                        end if;
                        s_channel_local_counter(v_adc)<=s_channel_local_counter(v_adc)+1;
                        if s_adc_input_fc_cdc_buffer(v_adc) = "11111110000000" then
                            s_channel_valid_fc_frame_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '1';
                            v_mon_st:=st_monitor;
                            s_calculated(v_adc) <= '1';
                        else
                            s_channel_invalid_fc_frame_counter(v_adc)<=s_channel_invalid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '0';
                        end if;
                        
                    when st_monitor=>
                        s_channel_difference_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc) - s_channel_local_counter(v_adc);
                        s_channel_local_counter(v_adc)<=s_channel_local_counter(v_adc)+1;
                        
                        if (s_channel_difference_counter(v_adc) = s_channel_initial_difference_counter(v_adc)) then
                        else
                            s_channel_missed_bit_count(v_adc)<='1';
                        end if;
                        
                        if s_adc_input_fc_cdc_buffer(v_adc) = "11111110000000" then
                            s_channel_valid_fc_frame_counter(v_adc)<=s_channel_valid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '1';
                        else
                            s_channel_invalid_fc_frame_counter(v_adc)<=s_channel_invalid_fc_frame_counter(v_adc)+1;
                            s_channel_locked(v_adc)<= '0';
                            s_channel_missed_locked(v_adc) <= '1';
                        end if;                
                    when others=>
                        v_mon_st:=st_start;
                end case;
            end if;
            
        end process;

        s_adc_readout.fc_data(v_adc) <= s_adc_input_fc_cdc_buffer(v_adc);
        s_adc_readout.lg_data(v_adc) <= s_adc_input_lg_cdc_buffer(v_adc);
        s_adc_readout.hg_data(v_adc) <= s_adc_input_hg_cdc_buffer(v_adc);

        s_cdc_reset_in(v_adc)<= (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_5_bit-v_adc)) or
                          (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)) or
                          (p_master_reset_in) or
                          (not p_clknet_in.mb_fpga_reset_low.q0) or
                          (not p_clknet_in.mb_fpga_reset_low.q1) or
                          (not p_adc_readout_control_in.adc_config_done);
                    

        s_adc_readout.channel_invalid_fc_frame_counter(v_adc) <= std_logic_vector(to_unsigned(s_channel_valid_fc_frame_counter(v_adc), c_adc_counters_depth));
        s_adc_readout.channel_valid_fc_frame_counter(v_adc) <= std_logic_vector(to_unsigned(s_channel_invalid_fc_frame_counter(v_adc), c_adc_counters_depth));
        
        s_adc_readout.channel_locked(v_adc)<=s_channel_locked(v_adc);
        s_adc_readout.channel_missed_locked(v_adc)<=s_channel_missed_locked(v_adc);
        s_adc_readout.channel_missed_bit_count(v_adc)<=s_channel_missed_bit_count(v_adc);
        
--        s_adc_readout.channel_frame_missalignemt(v_adc) <= s_channel_frame_missalignemt_reg(v_adc);


        i_adc_data_lg_pipeline : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_lg(v_adc).dout,
                       p_pipeline_out => s_adc_input_lg_cdc_buffer(v_adc));--s_adc_readout.lg_data(v_adc));
        i_adc_data_hg_pipeline : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_hg(v_adc).dout,
                       p_pipeline_out => s_adc_input_hg_cdc_buffer(v_adc));--s_adc_readout.hg_data(v_adc));
        i_adc_data_fc_pipeline : entity tilecal.db6_pipeline_propagator
            generic map(    g_pipeline_stages => c_pipeline_depth,
                            g_pipeline_item_lenght => c_adc_bit_number)
            Port map ( p_clk_in => p_adc_bitclk_in(v_adc),
                       p_pipeline_in => s_adc_channel_fifo_fc(v_adc).dout,
                       p_pipeline_out => s_adc_input_fc_cdc_buffer(v_adc));--s_adc_readout.fc_data(v_adc));


        s_adc_channel_fifo_fc(v_adc).dout <= s_adc_channel_fifo_fc(v_adc).din;
        s_adc_channel_fifo_lg(v_adc).dout <= s_adc_channel_fifo_lg(v_adc).din;
        s_adc_channel_fifo_hg(v_adc).dout <= s_adc_channel_fifo_hg(v_adc).din;


        proc_shift_lg_in : process(p_adc_bitclk_in(v_adc), s_cdc_reset_in(v_adc)) -- odd data bits clocked in on rising edge of adc clocks 
        begin
        
            if s_cdc_reset_in(v_adc) = '1' then
                s_sync_bitclkdiv_state_lg(v_adc) <= 0;
            elsif rising_edge(p_adc_bitclk_in(v_adc)) then
                case s_sync_bitclkdiv_state_lg(v_adc) is

                    when 0 =>
                            s_adc_channel_fifo_lg(v_adc).din<=(others=>'1');
                            s_adc_channel_fifo_hg(v_adc).din<=(others=>'1');
                            s_adc_channel_fifo_fc(v_adc).din<=(others=>'1');
                            
                        if ((p_adc_frameclk_in(v_adc)= "11")) then -- and (s_adc_fc_data_sr(v_adc)="00")) then
                            s_sync_bitclkdiv_state_lg(v_adc)<=2;
                            s_adc_input_lg_buffer(v_adc)(13 downto 12) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(13 downto 12) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(13 downto 12) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                            
                            
                        end if;

                    when 1 =>

                        s_adc_channel_fifo_lg(v_adc).din<=s_adc_input_lg_buffer(v_adc);
                        s_adc_channel_fifo_hg(v_adc).din<=s_adc_input_hg_buffer(v_adc);
                        s_adc_channel_fifo_fc(v_adc).din<=s_adc_input_fc_buffer(v_adc);

                        if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=2;
                            s_adc_input_lg_buffer(v_adc)(13 downto 12) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(13 downto 12) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(13 downto 12) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;

                    when 2 =>
                        s_first_state_achieved(v_adc)<='1';
                        if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=3;
                            s_adc_input_lg_buffer(v_adc)(11 downto 10) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(11 downto 10) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(11 downto 10) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;
                    when 3 =>
                        if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=4;
                            s_adc_input_lg_buffer(v_adc)(9 downto 8) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(9 downto 8) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(9 downto 8) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                         else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;                       
                    when 4 =>
                        if (p_adc_frameclk_in(v_adc)= "01") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=5;
                            s_adc_input_lg_buffer(v_adc)(7 downto 6) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(7 downto 6) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(7 downto 6) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;   
                    when 5 =>
                        if (p_adc_frameclk_in(v_adc)= "00") then
                            s_invalid_frame_flag(v_adc)<='0';
                            s_sync_bitclkdiv_state_lg(v_adc)<=6;
                            s_adc_input_lg_buffer(v_adc)(5 downto 4) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(5 downto 4) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(5 downto 4) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;       
                    when 6 =>
                        if ((p_adc_frameclk_in(v_adc)= "00")) then
                            s_sync_bitclkdiv_state_lg(v_adc)<=7;
                            s_adc_input_lg_buffer(v_adc)(3 downto 2) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(3 downto 2) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(3 downto 2) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if; 
                    when 7 =>
                        s_channel_phase(v_adc)<='0';
                        if ((p_adc_frameclk_in(v_adc)= "00")) then
                            s_sync_bitclkdiv_state_lg(v_adc)<=1;
                            s_adc_input_lg_buffer(v_adc)(1 downto 0) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(1 downto 0) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(1 downto 0) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if; 

--                    when 8 =>
--                        s_first_state_achieved(v_adc)<='0';
--                        if s_first_frame_counted(v_adc)='1' and s_first_state_achieved(v_adc)='1' then
--                            if s_invalid_frame_flag(v_adc)='0' then
--                                s_channel_valid_fc_frame_counter(v_adc)<=std_logic_vector(unsigned(s_channel_valid_fc_frame_counter(v_adc))+1);--s_channel_valid_fc_frame_counter(v_adc)<=-std_logic_vector(to_unsigned(to_integer(unsigned(s_channel_valid_fc_frame_counter(v_adc)))+1,48));
--                            else
--                                s_channel_invalid_fc_frame_counter(v_adc)<=std_logic_vector(unsigned(s_channel_invalid_fc_frame_counter(v_adc))+1); --s_channel_invalid_fc_frame_counter(v_adc)<=std_logic_vector(to_unsigned(to_integer(unsigned(s_channel_valid_fc_frame_counter(v_adc)))+1,48));
--                            end if;
--                        end if;
                        
--                        s_adc_channel_fifo_lg(v_adc).din(13 downto 2)<=s_adc_input_lg_buffer(v_adc)(13 downto 3)&p_adc_lg_data_in(v_adc)(0);
--                        s_adc_channel_fifo_hg(v_adc).din(13 downto 2)<=s_adc_input_hg_buffer(v_adc)(13 downto 3)&p_adc_hg_data_in(v_adc)(0);
--                        s_adc_channel_fifo_fc(v_adc).din(13 downto 2)<=s_adc_input_fc_buffer(v_adc)(13 downto 3)& p_adc_frameclk_in(v_adc)(0);
--                        s_adc_channel_fifo_fc(v_adc).dout <= s_adc_channel_fifo_fc(v_adc).din;
--                        s_adc_channel_fifo_lg(v_adc).dout <= s_adc_channel_fifo_lg(v_adc).din;
--                        s_adc_channel_fifo_hg(v_adc).dout <= s_adc_channel_fifo_hg(v_adc).din;
--                        if (p_adc_frameclk_in(v_adc)= "10") then
--                            s_invalid_frame_flag(v_adc)<='0';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=9;
--                            s_adc_input_lg_buffer(v_adc)(13) <= p_adc_lg_data_in(v_adc)(1);
--                            s_adc_input_hg_buffer(v_adc)(13) <= p_adc_hg_data_in(v_adc)(1);
--                            s_adc_input_fc_buffer(v_adc)(13) <= p_adc_frameclk_in(v_adc)(1);
--                            s_adc_input_lg_buffer(v_adc)(2) <= p_adc_lg_data_in(v_adc)(0);
--                            s_adc_input_hg_buffer(v_adc)(2) <= p_adc_hg_data_in(v_adc)(0);
--                            s_adc_input_fc_buffer(v_adc)(2) <= p_adc_frameclk_in(v_adc)(0);
--                        end if;

--                    when 9 =>
--                        s_first_state_achieved(v_adc)<='1';
--                        if (p_adc_frameclk_in(v_adc)= "11") then
--                            s_invalid_frame_flag(v_adc)<='0';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=10;
--                            s_adc_input_lg_buffer(v_adc)(12 downto 11) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
--                            s_adc_input_hg_buffer(v_adc)(12 downto 11) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
--                            s_adc_input_fc_buffer(v_adc)(12 downto 11) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
--                        else
--                            s_invalid_frame_flag(v_adc)<='1';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
--                        end if;
--                    when 10 =>
--                        if (p_adc_frameclk_in(v_adc)= "11") then
--                            s_invalid_frame_flag(v_adc)<='0';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=11;
--                            s_adc_input_lg_buffer(v_adc)(10 downto 9) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
--                            s_adc_input_hg_buffer(v_adc)(10 downto 9) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
--                            s_adc_input_fc_buffer(v_adc)(10 downto 9) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
--                         else
--                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
--                            s_invalid_frame_flag(v_adc)<='1';
--                        end if;                       
--                    when 11 =>
--                        s_channel_frame_missalignemt(v_adc) <= s_channel_frame_missalignemt_buffer_lg(v_adc);
--                        if (p_adc_frameclk_in(v_adc)= "11") then
--                            s_invalid_frame_flag(v_adc)<='0';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=12;
--                            s_adc_input_lg_buffer(v_adc)(8 downto 7) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
--                            s_adc_input_hg_buffer(v_adc)(8 downto 7) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
--                            s_adc_input_fc_buffer(v_adc)(8 downto 7) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
--                        else
--                            s_invalid_frame_flag(v_adc)<='1';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
--                        end if;   
--                    when 12 =>
--                        if (p_adc_frameclk_in(v_adc)= "00") then
--                            s_invalid_frame_flag(v_adc)<='0';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=13;
--                            s_adc_input_lg_buffer(v_adc)(6 downto 5) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
--                            s_adc_input_hg_buffer(v_adc)(6 downto 5) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
--                            s_adc_input_fc_buffer(v_adc)(6 downto 5) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
--                        else
--                            s_invalid_frame_flag(v_adc)<='1';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
--                        end if;       
--                    when 13 =>
--                        s_channel_phase(v_adc)<='1';
--                        if (p_adc_frameclk_in(v_adc)= "00") then
--                            s_invalid_frame_flag(v_adc)<='0';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=14;
--                            s_adc_input_lg_buffer(v_adc)(4 downto 3) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
--                            s_adc_input_hg_buffer(v_adc)(4 downto 3) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
--                            s_adc_input_fc_buffer(v_adc)(4 downto 3) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
--                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='0';
--                        else
--                            s_invalid_frame_flag(v_adc)<='1';
--                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
--                        end if;   
--                    when 14 =>
--                        s_channel_phase(v_adc)<='1';
--                        if (p_adc_frameclk_in(v_adc)= "00") then
--                            s_first_frame_counted(v_adc)<='1';
--                            s_invalid_frame_flag(v_adc)<='0';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=8;
--                            s_adc_input_lg_buffer(v_adc)(2 downto 1) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
--                            s_adc_input_hg_buffer(v_adc)(2 downto 1) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
--                            s_adc_input_fc_buffer(v_adc)(2 downto 1) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
--                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='0';
--                        else
--                            s_invalid_frame_flag(v_adc)<='1';
--                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
--                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
--                        end if;   



                    when others =>
                        s_sync_bitclkdiv_state_lg(v_adc)<=0;
                end case;
            end if;
        end process;



    
end generate;


--    i_vio_adc_readout_cdc : vio_adc_readout_cdc
--      PORT MAP (
--        clk => p_clknet_in.mmcm_refclk40,
--        probe_in0 => s_counter_cdc_array_debug(0),
--        probe_in1 => s_counter_cdc_array_debug(1),
--        probe_in2 => s_counter_cdc_array_debug(2),
--        probe_in3 => s_counter_cdc_array_debug(3),
--        probe_in4 => s_counter_cdc_array_debug(4),
--        probe_in5 => s_counter_cdc_array_debug(5),
--        probe_in6 => s_counter_array_debug(0),
--        probe_in7 => s_counter_array_debug(1),
--        probe_in8 => s_counter_array_debug(2),
--        probe_in9 => s_counter_array_debug(3),
--        probe_in10 => s_counter_array_debug(4),
--        probe_in11 => s_counter_array_debug(5),
--        probe_in12 => s_counter_cdc_align_array_debug(0),
--        probe_in13 => s_counter_cdc_align_array_debug(1),
--        probe_in14 => s_counter_cdc_align_array_debug(2),
--        probe_in15 => s_counter_cdc_align_array_debug(3),
--        probe_in16 => s_counter_cdc_align_array_debug(4),
--        probe_in17 => s_counter_cdc_align_array_debug(5)
--      );    
--gen_debug_chan : for v_adc in 0 to 5 generate
--    s_counter_cdc_array_debug(v_adc) <= std_logic_vector(to_unsigned(s_counter_cdc_array(v_adc),4));
--    s_counter_array_debug(v_adc) <= std_logic_vector(to_unsigned(s_counter_array(v_adc),4));
--    s_counter_cdc_align_array_debug(v_adc) <= std_logic_vector(to_unsigned(s_counter_cdc_array(v_adc)-s_counter_array(v_adc),4));
--end generate;
 
end behavioral;
