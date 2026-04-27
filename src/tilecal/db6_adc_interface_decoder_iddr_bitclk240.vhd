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

entity db6_adc_interface_decoder_iddr_bitclk240 is
    generic (
        g_clocking_mode : integer :=0;
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
        p_frame_missalignment_in : in std_logic_vector(5 downto 0);
        p_adc_lg_data_in : in t_bitslice_sr;
        p_adc_hg_data_in : in t_bitslice_sr;
        
        
        --control
        p_adc_readout_control_in : in t_adc_readout_control;
        
        --output
        p_adc_readout_out       : out t_adc_readout;
        
        --debug
        p_leds_out      : out std_logic_vector(3 downto 0)
				);
end db6_adc_interface_decoder_iddr_bitclk240;

architecture Behavioral of db6_adc_interface_decoder_iddr_bitclk240 is

--    signal s_adc_channel_sr_fc, s_adc_channel_sr_lg, s_adc_channel_sr_hg : t_adc_channel_sr;
    signal s_adc_channel_fifo_fc, s_adc_channel_fifo_hg, s_adc_channel_fifo_lg, s_adc_channel_fifo_fc_bitclk, s_adc_channel_fifo_hg_bitclk, s_adc_channel_fifo_lg_bitclk : t_adc_channel_fifo; --t_adc_channel_fifo_cdc;--t_adc_channel_fifo;
    signal s_adc_input_fc_buffer, s_adc_input_lg_buffer, s_adc_input_hg_buffer : t_adc_data; --t_adc_oversample_data_type;--t_adc_data;
    signal s_channel_frame_missalignemt, s_channel_frame_missalignemt_buffer_lg, s_channel_frame_missalignemt_buffer_hg , s_channel_frame_missalignemt_buffer_delayed, s_channel_frame_missalignemt_reset : std_logic_vector (5 downto 0) := (others => '1');
    signal s_channel_phase : std_logic_vector(5 downto 0);
    type t_cdc_transition is array (0 to 5) of std_logic;
    signal s_cdc_transition : t_cdc_transition := (others=> '0');
    type t_counter_array is array (0 to 5) of integer range 0 to 31;
--    signal s_counter_array_lg, s_counter_array_hg, s_counter_cdc_array_lg, s_counter_cdc_array_hg, s_counter_cdc_align_array, s_counter_cdc_align_array_reg : t_counter_array;
    type t_counter_std_logic_vector_array is array (0 to 5) of std_logic_vector(3 downto 0);
    signal s_counter_array_debug, s_counter_cdc_array_debug, s_counter_cdc_align_array_debug : t_counter_std_logic_vector_array;
    
    signal s_adc_lg_data_sr, s_adc_hg_data_sr, s_adc_fc_data_sr : t_bitslice_sr;
    type t_bitslice_fifo is array (0 to 3) of t_bitslice_sr;
    signal s_lg_bitslice_fifo, s_hg_bitslice_fifo, s_fc_bitslice_fifo : t_bitslice_fifo; 
    
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
            
            mb_adc_config_control => c_adc_register_init_config_12_bit,
            
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

    type t_sync_bitclkdiv_state is array (0 to 5) of integer range 0 to 7;
    signal s_sync_bitclkdiv_state_lg, s_sync_bitclkdiv_state_hg: t_sync_bitclkdiv_state;
    signal s_cdc_reset_in, s_cdc_reset_out : std_logic_vector(5 downto 0);


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

--proc_register_data_out : process(p_clknet_in.refclk40)
--begin
--    if rising_edge(p_clknet_in.refclk40) then
        p_adc_readout_out <= s_adc_readout;
--    end if;
--end process;

gen_adc_channels: for v_adc in 0 to 5 generate
    s_cdc_reset_in(v_adc)<= (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_5_bit-v_adc)) or
                          (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)) or
                          (p_master_reset_in) or
                          (not p_clknet_in.mb_fpga_reset_low.q0) or
                          (not p_clknet_in.mb_fpga_reset_low.q1) or
                          (not p_adc_readout_control_in.adc_config_done);
                    

        proc_cdc_fifos : process(p_adc_bitclk_in(v_adc)) -- odd data bits clocked in on rising edge of adc clocks 
        begin
            if rising_edge(p_adc_bitclk_in(v_adc)) then
                s_lg_bitslice_fifo(0)(v_adc) <= s_lg_bitslice_fifo(1)(v_adc); 
                s_lg_bitslice_fifo(1)(v_adc) <= s_lg_bitslice_fifo(2)(v_adc);
                s_lg_bitslice_fifo(2)(v_adc) <= s_lg_bitslice_fifo(3)(v_adc);
                s_lg_bitslice_fifo(3)(v_adc)(1 downto 0) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);

                s_hg_bitslice_fifo(0)(v_adc) <= s_hg_bitslice_fifo(1)(v_adc); 
                s_hg_bitslice_fifo(1)(v_adc) <= s_hg_bitslice_fifo(2)(v_adc);
                s_hg_bitslice_fifo(2)(v_adc) <= s_hg_bitslice_fifo(3)(v_adc);
                s_hg_bitslice_fifo(3)(v_adc)(1 downto 0) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);

                s_fc_bitslice_fifo(0)(v_adc) <= s_fc_bitslice_fifo(1)(v_adc); 
                s_fc_bitslice_fifo(1)(v_adc) <= s_fc_bitslice_fifo(2)(v_adc);
                s_fc_bitslice_fifo(2)(v_adc) <= s_fc_bitslice_fifo(3)(v_adc);
                s_fc_bitslice_fifo(3)(v_adc)(1 downto 0) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
            end if;
        end process;
        


        proc_fifos : process(p_clknet_in.mmcm_refclk240)
        begin
            if rising_edge(p_clknet_in.mmcm_refclk240) then
--                if s_sync_bitclkdiv_state_lg(v_adc) = 4 then
                if (p_clknet_in.gbt_cdc_counter = 0) and (p_clknet_in.gbt_cdc_phase = '1') then
                    s_adc_channel_fifo_fc(v_adc).din <= s_adc_channel_fifo_fc_bitclk(v_adc).dout;
                    s_adc_channel_fifo_lg(v_adc).din <= s_adc_channel_fifo_lg_bitclk(v_adc).dout;
                    s_adc_channel_fifo_hg(v_adc).din <= s_adc_channel_fifo_hg_bitclk(v_adc).dout;
                elsif (p_clknet_in.gbt_cdc_counter = 1) and (p_clknet_in.gbt_cdc_phase = '1') then
                    s_adc_channel_fifo_fc(v_adc).dout <= s_adc_channel_fifo_fc(v_adc).din;
                    s_adc_channel_fifo_lg(v_adc).dout <= s_adc_channel_fifo_lg(v_adc).din;
                    s_adc_channel_fifo_hg(v_adc).dout <= s_adc_channel_fifo_hg(v_adc).din;
                    s_channel_frame_missalignemt(v_adc)<=s_channel_frame_missalignemt_buffer_delayed(v_adc);
--                end if;
                elsif (p_clknet_in.gbt_cdc_counter = 2) and (p_clknet_in.gbt_cdc_phase = '1') then
                    s_adc_readout.channel_frame_missalignemt(v_adc) <= s_channel_frame_missalignemt(5-v_adc);
                    s_adc_readout.hg_data(v_adc)<= s_adc_channel_fifo_hg(5-v_adc).dout; --s_hg_adc_output_word;
                    s_adc_readout.lg_data(v_adc)<= s_adc_channel_fifo_lg(5-v_adc).dout; --s_lg_adc_output_word;
--                    s_adc_readout.channel_cdc_align_counter(v_adc)<=std_logic_vector(to_unsigned(s_counter_cdc_align_array(5-v_adc),4));
                    s_adc_readout.fc_data(v_adc)<= s_adc_channel_fifo_fc(5-v_adc).dout;--s_adc_channel_fifo_fc(v_adc).dout; --s_fc_output_word;
                    s_adc_readout.channel_phase_offset(v_adc) <= s_channel_phase(5-v_adc);
                end if;
            end if;
        end process;
    

        proc_shift_lg_in : process(p_adc_bitclk_in(v_adc), s_cdc_reset_in(v_adc)) -- odd data bits clocked in on rising edge of adc clocks 
        variable v_phase: integer range 0 to 7 :=0;
        begin
        
            if s_cdc_reset_in(v_adc) = '1' then
            --        s_adc_input_fc_temp(v_adc) <= (others => '1');
            --        s_adc_input_lg_temp(v_adc) <= (others => '1');
            --        s_adc_input_hg_temp(v_adc) <= (others => '1');
--                        v_state:=0;
--                        s_counter_array_lg(v_adc)<=0;
--                        s_counter_cdc_array_lg(v_adc)<=0;
                        s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
                        s_sync_bitclkdiv_state_lg(v_adc) <= 0;
                        s_channel_phase(v_adc)<='0';

                        
            elsif rising_edge(p_adc_bitclk_in(v_adc)) then
--                if s_counter_cdc_array_lg(v_adc) = 6 then
--                    s_counter_cdc_array_lg(v_adc)<=0;
--                else
--                    s_counter_cdc_array_lg(v_adc) <= s_counter_cdc_array_lg(v_adc) +1;
--                end if;
                
                --s_adc_input_lg_buffer(v_adc)((c_adc_bit_number)-1 downto 0) <= s_adc_input_lg_buffer(v_adc)((c_adc_bit_number)-3 downto 0) & p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                if (p_clknet_in.gbt_cdc_phase = '0') and (s_sync_bitclkdiv_state_lg(v_adc) = 5) then
                    s_adc_channel_fifo_lg_bitclk(v_adc).dout <= s_adc_channel_fifo_lg_bitclk(v_adc).din;
                    s_adc_channel_fifo_hg_bitclk(v_adc).dout <= s_adc_channel_fifo_hg_bitclk(v_adc).din;
                    s_adc_channel_fifo_fc_bitclk(v_adc).dout <= s_adc_channel_fifo_fc_bitclk(v_adc).din;
                    s_channel_frame_missalignemt_buffer_delayed(v_adc)<=s_channel_frame_missalignemt_buffer_lg(v_adc);
                end if;
                
                case s_sync_bitclkdiv_state_lg(v_adc) is
                    when 0 =>
                        if (s_fc_bitslice_fifo(0)(v_adc)) = "11" then --if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=1;
                            s_adc_input_lg_buffer(v_adc)(13 downto 12) <= s_lg_bitslice_fifo(0)(v_adc);--p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(13 downto 12) <= s_hg_bitslice_fifo(0)(v_adc);--p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(13 downto 12) <= "11"; --s_fc_bitslice_fifo(v_adc)(3);--p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
                        end if;

                    when 1 =>
                        if (s_fc_bitslice_fifo(0)(v_adc)) = "11" then --if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=2;
                            s_adc_input_lg_buffer(v_adc)(11 downto 10) <= s_lg_bitslice_fifo(0)(v_adc); --p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(11 downto 10) <= s_hg_bitslice_fifo(0)(v_adc); --p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(11 downto 10) <= "11"; --s_fc_bitslice_fifo(v_adc)(3); --p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;
                    when 2 =>
                        if (s_fc_bitslice_fifo(0)(v_adc)) = "11" then --if (p_adc_frameclk_in(v_adc)= "11") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=3;
                            s_adc_input_lg_buffer(v_adc)(9 downto 8) <= s_lg_bitslice_fifo(0)(v_adc);--p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(9 downto 8) <= s_hg_bitslice_fifo(0)(v_adc);--p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(9 downto 8) <= "11"; --s_lg_bitslice_fifo(v_adc)(3); --p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                         else
                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;                       
                    when 3 =>
                        if (s_fc_bitslice_fifo(0)(v_adc)) = "00" then --if (p_adc_frameclk_in(v_adc)= "00") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=4;
                            s_adc_input_lg_buffer(v_adc)(7 downto 6) <= s_lg_bitslice_fifo(0)(v_adc); --p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(7 downto 6) <= s_hg_bitslice_fifo(0)(v_adc); --p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(7 downto 6) <= "00"; -- s_fc_bitslice_fifo(v_adc)(3); --p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;   
                    when 4 =>
                        if (s_fc_bitslice_fifo(0)(v_adc)) = "00" then --if (p_adc_frameclk_in(v_adc)= "00") then
                            s_sync_bitclkdiv_state_lg(v_adc)<=5;
                            s_adc_input_lg_buffer(v_adc)(5 downto 4) <= s_lg_bitslice_fifo(0)(v_adc); --p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
                            s_adc_input_hg_buffer(v_adc)(5 downto 4) <= s_hg_bitslice_fifo(0)(v_adc); --p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
                            s_adc_input_fc_buffer(v_adc)(5 downto 4) <= "00"; --s_fc_bitslice_fifo(0)(v_adc); --p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                        else
                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if;       
                    when 5 =>
                        s_channel_phase(v_adc)<='0';
                        if (s_fc_bitslice_fifo(0)(v_adc)) = "00" then --if ((p_adc_frameclk_in(v_adc)= "00")) then
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
--                            s_adc_input_lg_buffer(v_adc)(3 downto 2) <= p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);
--                            s_adc_input_hg_buffer(v_adc)(3 downto 2) <= p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);
--                            s_adc_input_fc_buffer(v_adc)(3 downto 2) <= p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);
                            s_adc_channel_fifo_lg_bitclk(v_adc).din(13 downto 2)<=s_adc_input_lg_buffer(v_adc)(13 downto 4) & s_lg_bitslice_fifo(0)(v_adc); --p_adc_lg_data_in(v_adc)(0) & p_adc_lg_data_in(v_adc)(1);-- & "00";
                            s_adc_channel_fifo_hg_bitclk(v_adc).din(13 downto 2)<=s_adc_input_hg_buffer(v_adc)(13 downto 4) & s_hg_bitslice_fifo(0)(v_adc); --p_adc_hg_data_in(v_adc)(0) & p_adc_hg_data_in(v_adc)(1);-- & "00";
                            s_adc_channel_fifo_fc_bitclk(v_adc).din(13 downto 2)<=s_adc_input_fc_buffer(v_adc)(13 downto 4) & "00"; --s_fc_bitslice_fifo(0)(v_adc); --p_adc_frameclk_in(v_adc)(0) & p_adc_frameclk_in(v_adc)(1);-- & "00";
                                                        
                            
                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='0';
                        else
                            s_channel_frame_missalignemt_buffer_lg(v_adc)<='1';
                            s_sync_bitclkdiv_state_lg(v_adc)<=0;
                        end if; 



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
