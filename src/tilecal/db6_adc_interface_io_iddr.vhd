----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.10.2022 00:26:50
-- Design Name: 
-- Module Name: db6_adc_interface_io_iddr - Behavioral
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

Library xpm;
use xpm.vcomponents.all;

entity db6_adc_interface_io_iddr is
    generic (
        g_clocking_mode : integer := 0;  -- 0-> simple, 1-> divclkout, 2-> pll with clk40_out 
        g_common_delay_value : integer :=0
    );
    port ( 	
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;
        --inputs
        p_adc_bitclk_in : in t_adc_clk_in;
        p_adc_frameclk_in : in t_adc_clk_in;
        p_adc_lg_data_in : in t_adc_data_in;
        p_adc_hg_data_in : in t_adc_data_in;
        
        --outputs
        p_adc_bitclk_out : out std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_out : out std_logic_vector(5 downto 0);
        p_frame_missalignment_out : out std_logic_vector(5 downto 0);
        p_adc_frameclk_out : out t_bitslice_sr;
        p_adc_lg_data_out : out t_bitslice_sr;
        p_adc_hg_data_out : out t_bitslice_sr;
        
        
        --control
        p_adc_readout_control_in : in t_adc_readout_control;
        
        --debug
        p_leds_out      : out std_logic_vector(3 downto 0)
				);
end db6_adc_interface_io_iddr;

architecture Behavioral of db6_adc_interface_io_iddr is


    signal s_fc_bitslips_from_sm, s_hg_bitslips_from_sm, s_lg_bitslips_from_sm, s_hg_bitslips_from_hw, s_lg_bitslips_from_hw : t_bitslips_integer_array;

    signal s_data_lg, s_data_hg, s_data_lg_delayed, s_data_hg_delayed , s_bitclk_in, s_bitclk_se, s_frameclk, s_frameclk_to_bufg ,s_frameclk_delayed: std_logic_vector (5 downto 0) := (others => '0');
    signal s_bitslice_lg_sr, s_bitslice_hg_sr, s_bitslice_fc_sr : t_bitslice_sr;
    signal s_fc_idelay_count_in, s_fc_idelay_count_out, s_fc_idelay_count_in_from_sm : t_idelay_count := (others => (others => '0'));
    
    signal s_lg_idelay_count_in_from_hw, s_hg_idelay_count_in_from_hw, s_hg_idelay_count_in_from_sm, s_lg_idelay_count_in_from_sm : t_idelay_integer_array;
    signal s_lg_idelay_count_in, s_lg_idelay_count_out : t_idelay_count := (others => (others => '0'));
    signal s_hg_idelay_count_in, s_hg_idelay_count_out : t_idelay_count := (others => (others => '0'));

    signal s_lg_delay_control_array, s_hg_delay_control_array, s_fc_delay_control_array : t_adc_readout_delay_control_array := (others => c_delay_control);
    signal s_lg_idelay_ctrl_reset, s_lg_idelay_ctrl_reset_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_hg_idelay_ctrl_reset, s_hg_idelay_ctrl_reset_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_fc_idelay_ctrl_reset, s_fc_idelay_ctrl_reset_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_lg_idelay_ctrl_load, s_lg_idelay_ctrl_load_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_hg_idelay_ctrl_load, s_hg_idelay_ctrl_load_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_fc_idelay_ctrl_load, s_fc_idelay_ctrl_load_from_sm : std_logic_vector (5 downto 0) := (others => '0');  
    signal s_lg_idelay_ctrl_en_vtc, s_lg_idelay_ctrl_en_vtc_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_hg_idelay_ctrl_en_vtc, s_hg_idelay_ctrl_en_vtc_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_fc_idelay_ctrl_en_vtc, s_fc_idelay_ctrl_en_vtc_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_lg_iserdes_ctrl_reset : std_logic_vector (5 downto 0) := (others => '0');
    signal s_hg_iserdes_ctrl_reset : std_logic_vector (5 downto 0) := (others => '0');
    signal s_fc_iserdes_ctrl_reset : std_logic_vector (5 downto 0) := (others => '0');

    signal s_bitclk_div, s_bufgce_div_ctrl_reset_sync, s_bufgce_div_ctrl_reset_async : std_logic_vector (5 downto 0) := (others => '0');

    signal s_adc_channel_sr_fc : t_adc_channel_sr;
    signal s_adc_channel_fifo_fc : t_adc_channel_fifo;
    signal s_adc_input_fc_buffer : t_adc_data;
    type t_sync_bitclkdiv_state is array (0 to 5) of integer range 0 to 3;
    signal s_sync_bitclkdiv_state: t_sync_bitclkdiv_state;
    type t_counter_bitclkdiv_state is array (0 to 5) of integer range 0 to 16;
    signal s_counter_array : t_counter_bitclkdiv_state;

    --debug    
--    COMPONENT ila_adc_interface_iddr_io_channel
--    PORT (
--        clk : IN STD_LOGIC;
    
--        probe0 : IN STD_LOGIC_VECTOR(13 DOWNTO 0); 
--        probe1 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
--        probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
--        probe3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
--    );
--    END COMPONENT  ;
    
begin

p_adc_bitclk_out <= s_bitclk_se;
p_adc_frameclk_out <= s_bitslice_fc_sr;
p_adc_lg_data_out <= s_bitslice_lg_sr;
p_adc_hg_data_out <= s_bitslice_hg_sr;

-- differential to single-ended conversion of adc inputs from fmc
gen_adc_data_diff_to_se : for i in 0 to 5 generate

    i_IBUFDS_DATA0 : IBUFDS  -- ADC output Low gain
      generic map (
        IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_lg_delay_control_array(i).idatain,             -- Buffer diff_p output
        I  => p_adc_lg_data_in(i).p,  -- Diff_p buffer input (connect directly to top-level port)
        IB => p_adc_lg_data_in(i).n  -- Diff_n buffer input (connect directly to top-level port)
        );

    i_IBUFDS_DATA1 : IBUFDS -- ADC output High gain
      generic map (
        IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_hg_delay_control_array(i).idatain,             -- Buffer diff_p output
        I  => p_adc_hg_data_in(i).p,  -- Diff_p buffer input (connect directly to top-level port)
        IB => p_adc_hg_data_in(i).n  -- Diff_n buffer input (connect directly to top-level port)
        );

    i_IBUFDS_FRMCLK : IBUFDS -- ADC frame clock 
      generic map (
        IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_fc_delay_control_array(i).idatain,             -- Buffer diff_p output
        I  => p_adc_frameclk_in(i).p,  -- Diff_p buffer input (connect directly to top-level port)
        IB => p_adc_frameclk_in(i).n  -- Diff_n buffer input (connect directly to top-level port)
        );

    i_IBUFGDS_BITCLK : IBUFGDS -- ADC bit clock 
      generic map (
        IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_bitclk_se(i),             -- Buffer diff_p output
        I  => p_adc_bitclk_in(i).p,  -- Diff_p buffer input (connect directly to top-level port)
        IB => p_adc_bitclk_in(i).n  -- Diff_n buffer input (connect directly to top-level port)
        );

    gen_enable_bitclkdiv: if g_clocking_mode = 1 generate 
    
        bufgce_div_inst : bufgce_div
        generic map (
            bufgce_divide => 7, -- 1-8
            -- programmable inversion attributes: specifies built-in programmable inversion on specific pins
            is_ce_inverted => '0', -- optional inversion for ce
            is_clr_inverted => '0', -- optional inversion for clr
            is_i_inverted => '0' -- optional inversion for i
            )
            port map (
            o => p_adc_bitclkdiv_out(i), --s_bitclk_div(i), -- 1-bit output: buffer
            ce => '1', -- 1-bit input: buffer enable
            clr => s_bufgce_div_ctrl_reset_sync(i), -- 1-bit input: asynchronous clear
            i => s_bitclk_se(i) -- 1-bit input: buffer
        );
    end generate;
-- p_adc_bitclkdiv_out(i) <= '0';

end generate;
-- generate adc data input registers and output word mapping,
-- the output bits from each adc is stored in four shift registers (two even and two odd).


proc_load_hw_bitslips: process(p_clknet_in.db_side)

--PMT0 450 +/-2    3.015ns
--PMT1 394 +/-2    2.718ns
--PMT2 338 +/-2    2.265ns
--PMT3 284 +/-2     1.903ns
--PMT4 230 +/-2     1.541ns
--PMT5 178 +/-2     1.193ns
--PMT6109 +/-2     0.730ns
--PMT7 66+/-2      0.442ns
--PMT8 86+/-2       0.576ns
--PMT9 47 +/-2     0.315ns
--PMT10 41+/-2    0.274ns
--PMT11 103+/-2   0.690ns

begin
    if p_clknet_in.db_side = "0" then

        s_lg_bitslips_from_hw <= (14,14,14,14,14,14);
        s_hg_bitslips_from_hw <= (14,14,14,14,14,14);

        s_lg_idelay_count_in_from_hw <= (0,0,0,0,0,0);--(60,0,0,0,0,0);
        s_hg_idelay_count_in_from_hw <= (0,0,0,0,0,0);--(60,0,0,0,0,0);
    
    elsif p_clknet_in.db_side = "1" then
        
        s_lg_bitslips_from_hw <= (14,14,14,14,14,14);--(14-1,14,14,14,14,14);
        s_hg_bitslips_from_hw <= (14,14,14,14,14,14);--(14,14,14,14,14,14-1);
        
        s_lg_idelay_count_in_from_hw <= (0,0,0,0,0,0); --(0,100,0,100,0,0);--(60,0,0,0,0,60);
        s_hg_idelay_count_in_from_hw <= (0,0,0,0,0,0); --(0,100,0,0,100,0);--(0,0,0,0,0,200);

    else

    end if;

end process;



gen_adc_channels: for v_adc in 0 to 5 generate
        
        i_idelaye3_data_lg : idelaye3
            generic map (
                SIM_DEVICE => "ULTRASCALE",
                cascade => "none", -- cascade setting (none, master, slave_end, slave_middle)
                delay_format => "count", -- units of the delay_value (time, count)
                delay_src => "idatain", -- delay input (idatain, datain)
                delay_type => "fixed", -- set the type of tap delay line (fixed, var_load, variable)
                delay_value => g_common_delay_value, -- input delay value setting
                is_clk_inverted => '0', -- optional inversion for clk
                is_rst_inverted => '0', -- optional inversion for rst
                refclk_frequency => 200.00, -- idelayctrl clock input frequency in mhz (values)
                update_mode => "async" -- determines when updates to the delay will take effect (async, manual, sync)
                )
                port map (
                casc_out => s_lg_delay_control_array(v_adc).casc_out, -- 1-bit output: cascade delay output to odelay input cascade
                cntvalueout => s_lg_delay_control_array(v_adc).cntvalueout,--s_lg_idelay_count_out(v_adc), -- 9-bit output: counter value output
                dataout => s_lg_delay_control_array(v_adc).dataout,--s_adc_lg_data_delayed(v_adc), -- 1-bit output: delayed data output
                casc_in => s_lg_delay_control_array(v_adc).casc_in,--'0', -- 1-bit input: cascade delay input from slave odelay cascade_out
                casc_return =>  s_lg_delay_control_array(v_adc).casc_return,--'0', -- 1-bit input: cascade delay returning from slave odelay dataout
                ce => s_lg_delay_control_array(v_adc).ce, --'0', -- 1-bit input: active high enable increment/decrement input
                clk => s_lg_delay_control_array(v_adc).clk,--s_bitclk(v_adc), -- 1-bit input: clock input
                cntvaluein => s_lg_delay_control_array(v_adc).cntvaluein, --s_lg_idelay_count_in(v_adc), -- 9-bit input: counter value input
                datain => s_lg_delay_control_array(v_adc).datain, --'0',--s_data_lg(i), -- 1-bit input: data input from the iobuf
                en_vtc => s_lg_delay_control_array(v_adc).en_vtc, --s_lg_idelay_ctrl_en_vtc(v_adc), -- 1-bit input: keep delay constant over vt
                idatain => s_lg_delay_control_array(v_adc).idatain, --s_adc_lg_data_se(v_adc), -- 1-bit input: data input from the logic
                inc => s_lg_delay_control_array(v_adc).inc, --'0', -- 1-bit input: increment / decrement tap delay input
                load => s_lg_delay_control_array(v_adc).load, --s_lg_idelay_ctrl_load(v_adc), -- 1-bit input: load delay_value input
                rst => s_lg_delay_control_array(v_adc).rst --s_lg_idelay_ctrl_reset(v_adc) -- 1-bit input: asynchronous reset to the delay_value
        );
        s_lg_delay_control_array(v_adc).clk<= p_clknet_in.osc_clk200; -- s_bitclk_se(v_adc);
        s_lg_delay_control_array(v_adc).rst <= s_lg_idelay_ctrl_reset_from_sm(v_adc) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)); -- or p_adc_readout_control_in.lg_idelay_ctrl_reset(v_adc); 
        s_lg_delay_control_array(v_adc).load <= s_lg_idelay_ctrl_load_from_sm(v_adc); --p_adc_readout_control_in.lg_idelay_load(v_adc);
        s_lg_delay_control_array(v_adc).en_vtc <= s_lg_idelay_ctrl_en_vtc_from_sm(v_adc); --p_adc_readout_control_in.lg_idelay_en_vtc(v_adc);
        s_lg_delay_control_array(v_adc).cntvaluein <= std_logic_vector(to_unsigned(s_lg_idelay_count_in_from_sm(v_adc) + s_lg_idelay_count_in_from_hw(v_adc),9));-- p_adc_readout_control_in.lg_idelay_count(v_adc);
        --s_adc_readout.lg_idelay_count(v_adc) <= s_lg_delay_control_array(v_adc).cntvalueout;
        
        i_idelaye3_data_hg : idelaye3
            generic map (
                SIM_DEVICE => "ULTRASCALE",
                cascade => "none", -- cascade setting (none, master, slave_end, slave_middle)
                delay_format => "count", -- units of the delay_value (time, count)
                delay_src => "idatain", -- delay input (idatain, datain)
                delay_type => "fixed", -- set the type of tap delay line (fixed, var_load, variable)
                delay_value => g_common_delay_value, -- input delay value setting
                is_clk_inverted => '0', -- optional inversion for clk
                is_rst_inverted => '0', -- optional inversion for rst
                refclk_frequency => 200.00, -- idelayctrl clock input frequency in mhz (values)
                update_mode => "async" -- determines when updates to the delay will take effect (async, manual, sync)
                )
                port map (
                casc_out => s_hg_delay_control_array(v_adc).casc_out, -- 1-bit output: cascade delay output to odelay input cascade
                cntvalueout => s_hg_delay_control_array(v_adc).cntvalueout,--s_hg_idelay_count_out(v_adc), -- 9-bit output: counter value output
                dataout => s_hg_delay_control_array(v_adc).dataout,--s_adc_hg_data_delayed(v_adc), -- 1-bit output: delayed data output
                casc_in => s_hg_delay_control_array(v_adc).casc_in,--'0', -- 1-bit input: cascade delay input from slave odelay cascade_out
                casc_return =>  s_hg_delay_control_array(v_adc).casc_return,--'0', -- 1-bit input: cascade delay returning from slave odelay dataout
                ce => s_hg_delay_control_array(v_adc).ce, --'0', -- 1-bit input: active high enable increment/decrement input
                clk => s_hg_delay_control_array(v_adc).clk,--s_bitclk(v_adc), -- 1-bit input: clock input
                cntvaluein => s_hg_delay_control_array(v_adc).cntvaluein, --s_hg_idelay_count_in(v_adc), -- 9-bit input: counter value input
                datain => s_hg_delay_control_array(v_adc).datain, --'0',--s_data_hg(i), -- 1-bit input: data input from the iobuf
                en_vtc => s_hg_delay_control_array(v_adc).en_vtc, --s_hg_idelay_ctrl_en_vtc(v_adc), -- 1-bit input: keep delay constant over vt
                idatain => s_hg_delay_control_array(v_adc).idatain, --s_adc_hg_data_se(v_adc), -- 1-bit input: data input from the logic
                inc => s_hg_delay_control_array(v_adc).inc, --'0', -- 1-bit input: increment / decrement tap delay input
                load => s_hg_delay_control_array(v_adc).load, --s_hg_idelay_ctrl_load(v_adc), -- 1-bit input: load delay_value input
                rst => s_hg_delay_control_array(v_adc).rst --s_hg_idelay_ctrl_reset(v_adc) -- 1-bit input: asynchronous reset to the delay_value
        );
        
        s_hg_delay_control_array(v_adc).clk <= p_clknet_in.osc_clk200; --s_bitclk_se(v_adc);
        s_hg_delay_control_array(v_adc).rst <= s_hg_idelay_ctrl_reset_from_sm(v_adc) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)); -- or p_adc_readout_control_in.hg_idelay_ctrl_reset(v_adc); 
        s_hg_delay_control_array(v_adc).load <= s_hg_idelay_ctrl_load_from_sm(v_adc); --p_adc_readout_control_in.hg_idelay_load(v_adc);
        s_hg_delay_control_array(v_adc).en_vtc <= s_hg_idelay_ctrl_en_vtc_from_sm(v_adc); --p_adc_readout_control_in.hg_idelay_en_vtc(v_adc);
        s_hg_delay_control_array(v_adc).cntvaluein <= std_logic_vector(to_unsigned(s_hg_idelay_count_in_from_sm(v_adc) + s_hg_idelay_count_in_from_hw(v_adc),9));-- p_adc_readout_control_in.hg_idelay_count(v_adc);
        --s_adc_readout.hg_idelay_count(v_adc) <= s_hg_delay_control_array(v_adc).cntvalueout;
        
        i_idelaye3_data_fc : idelaye3
            generic map (
                SIM_DEVICE => "ULTRASCALE",
                cascade => "none", -- cascade setting (none, master, slave_end, slave_middle)
                delay_format => "count", -- units of the delay_value (time, count)
                delay_src => "idatain", -- delay input (idatain, datain)
                delay_type => "fixed", -- set the type of tap delay line (fixed, var_load, variable)
                delay_value => g_common_delay_value, -- input delay value setting
                is_clk_inverted => '0', -- optional inversion for clk
                is_rst_inverted => '0', -- optional inversion for rst
                refclk_frequency => 200.00, -- idelayctrl clock input frequency in mhz (values)
                update_mode => "async" -- determines when updates to the delay will take effect (async, manual, sync)
                )
                port map (
                casc_out => s_fc_delay_control_array(v_adc).casc_out, -- 1-bit output: cascade delay output to odelay input cascade
                cntvalueout => s_fc_delay_control_array(v_adc).cntvalueout,--s_fc_idelay_count_out(v_adc), -- 9-bit output: counter value output
                dataout => s_fc_delay_control_array(v_adc).dataout,--s_adc_fc_data_delayed(v_adc), -- 1-bit output: delayed data output
                casc_in => s_fc_delay_control_array(v_adc).casc_in,--'0', -- 1-bit input: cascade delay input from slave odelay cascade_out
                casc_return =>  s_fc_delay_control_array(v_adc).casc_return,--'0', -- 1-bit input: cascade delay returning from slave odelay dataout
                ce => s_fc_delay_control_array(v_adc).ce, --'0', -- 1-bit input: active high enable increment/decrement input
                clk => s_fc_delay_control_array(v_adc).clk,--s_bitclk(v_adc), -- 1-bit input: clock input
                cntvaluein => s_fc_delay_control_array(v_adc).cntvaluein, --s_fc_idelay_count_in(v_adc), -- 9-bit input: counter value input
                datain => s_fc_delay_control_array(v_adc).datain, --'0',--s_data_fc(i), -- 1-bit input: data input from the iobuf
                en_vtc => s_fc_delay_control_array(v_adc).en_vtc, --s_fc_idelay_ctrl_en_vtc(v_adc), -- 1-bit input: keep delay constant over vt
                idatain => s_fc_delay_control_array(v_adc).idatain, --s_adc_fc_data_se(v_adc), -- 1-bit input: data input from the logic
                inc => s_fc_delay_control_array(v_adc).inc, --'0', -- 1-bit input: increment / decrement tap delay input
                load => s_fc_delay_control_array(v_adc).load, --s_fc_idelay_ctrl_load(v_adc), -- 1-bit input: load delay_value input
                rst => s_fc_delay_control_array(v_adc).rst --s_fc_idelay_ctrl_reset(v_adc) -- 1-bit input: asynchronous reset to the delay_value
        );
        
        s_fc_delay_control_array(v_adc).clk <= p_clknet_in.osc_clk200; --s_bitclk_se(v_adc);
        s_fc_delay_control_array(v_adc).rst <= s_fc_idelay_ctrl_reset_from_sm(v_adc) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)); --p_adc_readout_control_in.fc_idelay_ctrl_reset(v_adc) or s_fc_idelay_ctrl_reset_from_sm(v_adc);
        s_fc_delay_control_array(v_adc).load <= s_fc_idelay_ctrl_load_from_sm(v_adc);--p_adc_readout_control_in.fc_idelay_load(v_adc);
        s_fc_delay_control_array(v_adc).en_vtc <= s_fc_idelay_ctrl_en_vtc_from_sm(v_adc);-- p_adc_readout_control_in.fc_idelay_en_vtc(v_adc);
        s_fc_delay_control_array(v_adc).cntvaluein <= s_fc_idelay_count_in_from_sm(v_adc); --p_adc_readout_control_in.fc_idelay_count(v_adc);
        --s_adc_readout.fc_idelay_count(v_adc) <= s_fc_delay_control_array(v_adc).cntvalueout;
        
        i_iddre1_lg : iddre1
        generic map (
            ddr_clk_edge => "SAME_EDGE_PIPELINED", -- iddre1 mode (opposite_edge, same_edge, same_edge_pipelined)
            is_c_inverted => '1', -- optional inversion for c
            is_cb_inverted => '0' -- optional inversion for c
        )
        port map (
            q1 => s_bitslice_lg_sr(v_adc)(0), -- 1-bit output: registered parallel output 1
            q2 => s_bitslice_lg_sr(v_adc)(1), -- 1-bit output: registered parallel output 2
            c => s_bitclk_se(v_adc), -- 1-bit input: high-speed clock
            cb => s_bitclk_se(v_adc), -- 1-bit input: inversion of high-speed clock c
            d => s_lg_delay_control_array(v_adc).dataout, -- 1-bit input: serial data input
            r => s_lg_iserdes_ctrl_reset(v_adc) -- 1-bit input: active high async reset
        );
        
        i_iddre1_hg : iddre1
        generic map (
            ddr_clk_edge => "SAME_EDGE_PIPELINED", -- iddre1 mode (opposite_edge, same_edge, same_edge_pipelined)
            is_c_inverted => '1', -- optional inversion for c
            is_cb_inverted => '0' -- optional inversion for c
        )
        port map (
            q1 => s_bitslice_hg_sr(v_adc)(0), -- 1-bit output: registered parallel output 1
            q2 => s_bitslice_hg_sr(v_adc)(1), -- 1-bit output: registered parallel output 2
            c => s_bitclk_se(v_adc), -- 1-bit input: high-speed clock
            cb => s_bitclk_se(v_adc), -- 1-bit input: inversion of high-speed clock c
            d => s_hg_delay_control_array(v_adc).dataout, -- 1-bit input: serial data input
            r => s_hg_iserdes_ctrl_reset(v_adc) -- 1-bit input: active high async reset
        );
        
        i_iddre1_fc : iddre1
        generic map (
            ddr_clk_edge => "SAME_EDGE_PIPELINED", -- iddre1 mode (opposite_edge, same_edge, same_edge_pipelined)
            is_c_inverted => '1', -- optional inversion for c
            is_cb_inverted => '0' -- optional inversion for c
        )
        port map (
            q1 => s_bitslice_fc_sr(v_adc)(0), -- 1-bit output: registered parallel output 1
            q2 => s_bitslice_fc_sr(v_adc)(1), -- 1-bit output: registered parallel output 2
            c => s_bitclk_se(v_adc), -- 1-bit input: high-speed clock
            cb => s_bitclk_se(v_adc), -- 1-bit input: inversion of high-speed clock c
            d => s_fc_delay_control_array(v_adc).dataout, -- 1-bit input: serial data input
            r => s_fc_iserdes_ctrl_reset(v_adc) -- 1-bit input: active high async reset
        );
        

    s_fc_iserdes_ctrl_reset(v_adc) <= '0' or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit));
    s_lg_iserdes_ctrl_reset(v_adc) <= '0' or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit));
    s_hg_iserdes_ctrl_reset(v_adc) <= '0' or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit));
    
    s_fc_idelay_ctrl_reset_from_sm(v_adc) <= '0';
    s_lg_idelay_ctrl_reset_from_sm(v_adc) <= '0';
    s_hg_idelay_ctrl_reset_from_sm(v_adc) <= '0';
    
    s_fc_idelay_ctrl_load_from_sm(v_adc) <= '0'; --p_adc_readout_control_in.fc_idelay_load(v_adc);
    s_fc_idelay_ctrl_en_vtc_from_sm(v_adc) <= '1'; --p_adc_readout_control_in.fc_idelay_en_vtc(v_adc);
    s_fc_idelay_count_in_from_sm(v_adc) <= (others => '0'); --p_adc_readout_control_in.fc_idelay_count(v_adc);
    
    s_hg_idelay_ctrl_load_from_sm(v_adc) <= '0'; --p_adc_readout_control_in.hg_idelay_load(v_adc);
    s_hg_idelay_ctrl_en_vtc_from_sm(v_adc) <= '1'; --p_adc_readout_control_in.hg_idelay_en_vtc(v_adc);
    
    s_lg_idelay_ctrl_load_from_sm(v_adc) <= '0'; --p_adc_readout_control_in.hg_idelay_load(v_adc);
    s_lg_idelay_ctrl_en_vtc_from_sm(v_adc) <= '1'; -- p_adc_readout_control_in.hg_idelay_en_vtc(v_adc);
    
    s_lg_idelay_count_in_from_sm(v_adc) <= 0; --to_integer(unsigned(p_adc_readout_control_in.lg_idelay_count(v_adc)));
    s_hg_idelay_count_in_from_sm(v_adc) <= 0; -- to_integer(unsigned(p_adc_readout_control_in.hg_idelay_count(v_adc)));


    s_bufgce_div_ctrl_reset_async(v_adc)<=p_master_reset_in or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_0_bit+v_adc));

    gen_enable_bitclkdiv : if g_clocking_mode = 1 generate 
--        i_db6_reset_synchronizer : entity tilecal.db6_reset_synchronizer
--        --    generic(
--        --           g_clk_divider : integer :=1    
--        --    );
--            Port map ( 
--                   p_clk_in => s_bitclk_se(v_adc), 
--                   p_reset_in => s_bufgce_div_ctrl_reset_async(v_adc),
--                   p_reset_out => s_bufgce_div_ctrl_reset_sync(v_adc)
--                   );
                   
        proc_shift_in : process(s_bitclk_se(v_adc), p_master_reset_in, p_db_reg_rx_in(c_adc_readout_reset_channel_5_bit-v_adc) , p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit),p_clknet_in.mb_fpga_reset_low.q0, p_clknet_in.mb_fpga_reset_low.q1, p_adc_readout_control_in.adc_config_done) -- odd data bits clocked in on rising edge of adc clocks 
        variable v_counter : integer range 0 to 65536;
        begin
            
            if ((p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_5_bit-v_adc)) = '1') or 
                (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit) = '1') or
                (p_master_reset_in = '1') or 
                (p_clknet_in.mb_fpga_reset_low.q0 = '0') or 
                (p_clknet_in.mb_fpga_reset_low.q1 = '0') or
                (p_adc_readout_control_in.adc_config_done = '0')
                then
        --        s_adc_input_fc_temp(v_adc) <= (others => '1');
        --        s_adc_input_lg_temp(v_adc) <= (others => '1');
        --        s_adc_input_hg_temp(v_adc) <= (others => '1');
                    s_sync_bitclkdiv_state(v_adc)<=0;
                    s_bufgce_div_ctrl_reset_sync(v_adc)<='1';
                    s_counter_array(v_adc)<=0;
                    
                    v_counter := 0;
            elsif rising_edge(s_bitclk_se(v_adc)) then
                s_adc_input_fc_buffer(v_adc) <= s_adc_input_fc_buffer(v_adc)(11 downto 0) & s_bitslice_fc_sr(v_adc)(0) & s_bitslice_fc_sr(v_adc)(1);
                case s_sync_bitclkdiv_state(v_adc) is
                    when 0=>
                        p_frame_missalignment_out(v_adc)<='1';
                        if v_counter<(4096*2-1) then
                            v_counter := v_counter+1;
                        else
                            if s_adc_input_fc_buffer(v_adc)(13 downto 0) = "00111111100000" then

                                s_bufgce_div_ctrl_reset_sync(v_adc)<='0';
                                s_sync_bitclkdiv_state(v_adc)<= 1;
                                s_counter_array(v_adc)<=0;
                            elsif s_adc_input_fc_buffer(v_adc)(13 downto 0) = "000111111110000" then
                                s_bufgce_div_ctrl_reset_sync(v_adc)<='0';
                                s_sync_bitclkdiv_state(v_adc)<= 2;
                                s_counter_array(v_adc)<=0;
                            else
                                s_counter_array(v_adc)<=0;
                                s_bufgce_div_ctrl_reset_sync(v_adc) <= '1';
                            end if;
                        end if;
                    when 1 =>
                        v_counter := 0;
                        p_frame_missalignment_out(v_adc)<='0';
                        if s_counter_array(v_adc)<15 then
                            if (s_counter_array(v_adc)=7) and (s_adc_input_fc_buffer(v_adc)(13 downto 0) = "11111110000000") then
                                s_counter_array(v_adc) <=1;
                            else
                                s_counter_array(v_adc)<=s_counter_array(v_adc)+1;
                            end if;
                        else
                            s_sync_bitclkdiv_state(v_adc)<= 3;
                        end if;
                    when 2 =>
                        v_counter := 0;
                        p_frame_missalignment_out(v_adc)<='0';
                        if s_counter_array(v_adc)<15 then
                            if (s_counter_array(v_adc)=7) and (s_adc_input_fc_buffer(v_adc)(13 downto 0) = "01111111000000") then
                                s_counter_array(v_adc) <=1;
                            else
                                s_counter_array(v_adc)<=s_counter_array(v_adc)+1;
                            end if;
                        else
                            s_sync_bitclkdiv_state(v_adc)<= 3;
                        end if;
                    when 3 =>
                        v_counter := 0;
                        p_frame_missalignment_out(v_adc)<='1';
                    when others =>
                        v_counter := 0;
                        s_sync_bitclkdiv_state(v_adc)<= 0;
                end case;
                    
                        
            end if;
        end process;
            
--        i_ila_adc_interface_iddr_io_channel : ila_adc_interface_iddr_io_channel
--        PORT MAP (
--            clk => s_bitclk_se(v_adc),
        
--            probe0 => s_adc_input_fc_buffer(v_adc), 
--            probe1(0) => s_bitslice_fc_sr(v_adc)(0),
--            probe1(1) => s_bitslice_fc_sr(v_adc)(1), 
--            probe2 => std_logic_vector(to_unsigned(s_counter_array(v_adc),8)),
--            probe3 => x"00"
--        );
        
            
    end generate;

end generate;


end Behavioral;


