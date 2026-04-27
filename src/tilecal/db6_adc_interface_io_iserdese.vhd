----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.03.2023 15:36:10
-- Design Name: 
-- Module Name: db6_adc_interface_io_iserdese - Behavioral
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

entity db6_adc_interface_io_iserdese is
    generic (
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
        p_frame_missalignment_in : in std_logic_vector(5 downto 0);
        p_ctrl_reset_from_sm_out : out std_logic_vector(5 downto 0);
        p_adc_frameclk_out : out t_byteslice_sr;
        p_adc_lg_data_out : out t_byteslice_sr;
        p_adc_hg_data_out : out t_byteslice_sr;
        
        
        --control
        p_adc_readout_control_in : in t_adc_readout_control;
        
        --debug
        p_leds_out      : out std_logic_vector(3 downto 0)
				);
end db6_adc_interface_io_iserdese;

architecture Behavioral of db6_adc_interface_io_iserdese is

    signal s_data_lg, s_data_hg, s_data_lg_delayed, s_data_hg_delayed, s_divbitclk, s_bitclk_in, s_bitclk_se, s_bitclk_ibufds_se, s_frameclk, s_frameclk_to_bufg ,s_frameclk_delayed: std_logic_vector (5 downto 0) := (others => '0');
    signal s_lg_delay_control_array, s_hg_delay_control_array, s_fc_delay_control_array : t_adc_readout_delay_control_array := (others => c_delay_control);
    
    signal s_bufgce_div_array : t_bufgce_div_array;
    
    signal s_lg_idelay_count_in_from_hw, s_hg_idelay_count_in_from_hw, s_hg_idelay_count_in_from_sm, s_lg_idelay_count_in_from_sm : t_idelay_integer_array;    
    signal s_fc_idelay_count_in, s_fc_idelay_count_out, s_fc_idelay_count_in_from_sm : t_idelay_count := (others => (others => '0'));

    signal s_lg_idelay_ctrl_reset, s_lg_idelay_ctrl_reset_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_hg_idelay_ctrl_reset, s_hg_idelay_ctrl_reset_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_fc_idelay_ctrl_reset, s_fc_idelay_ctrl_reset_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_lg_idelay_ctrl_load, s_lg_idelay_ctrl_load_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_hg_idelay_ctrl_load, s_hg_idelay_ctrl_load_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_fc_idelay_ctrl_load, s_fc_idelay_ctrl_load_from_sm : std_logic_vector (5 downto 0) := (others => '0');  
    signal s_lg_idelay_ctrl_en_vtc, s_lg_idelay_ctrl_en_vtc_from_sm : std_logic_vector (5 downto 0) := (others => '1');
    signal s_hg_idelay_ctrl_en_vtc, s_hg_idelay_ctrl_en_vtc_from_sm : std_logic_vector (5 downto 0) := (others => '1');
    signal s_fc_idelay_ctrl_en_vtc, s_fc_idelay_ctrl_en_vtc_from_sm : std_logic_vector (5 downto 0) := (others => '1');
    signal s_lg_iserdes_ctrl_reset : std_logic_vector (5 downto 0) := (others => '0');
    signal s_hg_iserdes_ctrl_reset : std_logic_vector (5 downto 0) := (others => '0');

    signal s_ctrl_reset_from_sm : std_logic_vector (5 downto 0) := (others => '0');
    signal s_frame_missalignment : std_logic_vector (5 downto 0) := (others => '0');

    signal s_lg_iserdese3_array, s_hg_iserdese3_array, s_fc_iserdese3_array : t_iserdese3_array;

begin

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
        O  => s_bitclk_ibufds_se(i),             -- Buffer diff_p output
        I  => p_adc_bitclk_in(i).p,  -- Diff_p buffer input (connect directly to top-level port)
        IB => p_adc_bitclk_in(i).n  -- Diff_n buffer input (connect directly to top-level port)
        );
        
    i_BUFGCE_BITCLK : BUFGCE -- ADC bit clock 
      port map (
        O  => s_bitclk_se(i),
        I  => s_bitclk_ibufds_se(i),
        CE => '1'
        );        

    i_bufgce_div : bufgce_div
        generic map (
            bufgce_divide => 2, -- 1-8
            -- programmable inversion attributes: specifies built-in programmable inversion on specific pins
            is_ce_inverted => '0', -- optional inversion for ce
            is_clr_inverted => '0', -- optional inversion for clr
            is_i_inverted => '0', -- optional inversion for i
            sim_device => "ultrascale"
            )
            port map (
            o => s_divbitclk(i), --s_bitclk_div(i), -- 1-bit output: buffer
            ce => s_bufgce_div_array(i).ce, --'1', -- 1-bit input: buffer enable
            clr => s_bufgce_div_array(i).clr, --'0', -- 1-bit input: asynchronous clear
            i => s_bitclk_se(i) -- 1-bit input: buffer
        );
     s_bufgce_div_array(i).clr <= '0';
     
     p_adc_bitclkdiv_out(i) <= s_divbitclk(i);
     
end generate;

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
                refclk_frequency => 280.00, -- idelayctrl clock input frequency in mhz (values)
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
        s_lg_delay_control_array(v_adc).clk<= s_divbitclk(v_adc);--s_bitclk_se(v_adc);--p_clknet_in.osc_clk200; -- s_bitclk_se(v_adc);
--        s_lg_delay_control_array(v_adc).rst <= s_lg_idelay_ctrl_reset_from_sm(v_adc) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)); -- or p_adc_readout_control_in.lg_idelay_ctrl_reset(v_adc); 
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
                refclk_frequency => 280.00, -- idelayctrl clock input frequency in mhz (values)
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
        
        s_hg_delay_control_array(v_adc).clk <= s_divbitclk(v_adc);--s_bitclk_se(v_adc); -- p_clknet_in.osc_clk200; --s_bitclk_se(v_adc);
        --s_hg_delay_control_array(v_adc).rst <= s_hg_idelay_ctrl_reset_from_sm(v_adc) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)); -- or p_adc_readout_control_in.hg_idelay_ctrl_reset(v_adc); 
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
                refclk_frequency => 280.00, -- idelayctrl clock input frequency in mhz (values)
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
        
        s_fc_delay_control_array(v_adc).clk <= s_divbitclk(v_adc);--s_bitclk_se(v_adc); --p_clknet_in.osc_clk200; --s_bitclk_se(v_adc);
--        s_fc_delay_control_array(v_adc).rst <= s_fc_idelay_ctrl_reset_from_sm(v_adc) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)); --p_adc_readout_control_in.fc_idelay_ctrl_reset(v_adc) or s_fc_idelay_ctrl_reset_from_sm(v_adc);
        s_fc_delay_control_array(v_adc).load <= s_fc_idelay_ctrl_load_from_sm(v_adc);--p_adc_readout_control_in.fc_idelay_load(v_adc);
        s_fc_delay_control_array(v_adc).en_vtc <= s_fc_idelay_ctrl_en_vtc_from_sm(v_adc);-- p_adc_readout_control_in.fc_idelay_en_vtc(v_adc);
        s_fc_delay_control_array(v_adc).cntvaluein <= s_fc_idelay_count_in_from_sm(v_adc); --p_adc_readout_control_in.fc_idelay_count(v_adc);
        --s_adc_readout.fc_idelay_count(v_adc) <= s_fc_delay_control_array(v_adc).cntvalueout;


   i_iserdese3_hg : iserdese3
   generic map (
      data_width => 4,          
      fifo_enable => "false",   
      fifo_sync_mode => "false",
      is_clk_b_inverted => '1', 
      is_clk_inverted => '0',   
      is_rst_inverted => '0',   
      sim_device => "ultrascale"
   )
   port map (
      fifo_empty => open,     
      internal_divclk => open,
      q             => s_hg_iserdese3_array(v_adc).q, -- adc_h_bte,
      clk           => s_bitclk_se(v_adc),
      clkdiv        => s_divbitclk(v_adc),
      clk_b         => s_bitclk_se(v_adc),
      d             => s_hg_delay_control_array(v_adc).dataout, --adc_h,      
      fifo_rd_clk   => '0',
      fifo_rd_en    => '0',
      rst           => s_hg_iserdese3_array(v_adc).rst --(adc_rst or adc_rst_global) 
   );
    p_adc_hg_data_out(v_adc)<=s_hg_iserdese3_array(v_adc).q;
    
    s_hg_delay_control_array(v_adc).rst <= p_master_reset_in or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_0_bit+v_adc));
    s_hg_iserdese3_array(v_adc).rst <= s_hg_delay_control_array(v_adc).rst;
    
   i_iserdese3_lg : iserdese3
   generic map (
      data_width => 4,          
      fifo_enable => "false",   
      fifo_sync_mode => "false",
      is_clk_b_inverted => '1', 
      is_clk_inverted => '0',   
      is_rst_inverted => '0',   
      sim_device => "ultrascale"
   )
   port map (
      fifo_empty => open,     
      internal_divclk => open,
      q             => s_lg_iserdese3_array(v_adc).q, --adc_l_bte,
      clk           => s_bitclk_se(v_adc),
      clkdiv        => s_divbitclk(v_adc),
      clk_b         => s_bitclk_se(v_adc),
      d             => s_lg_delay_control_array(v_adc).dataout, --adc_l,      
      fifo_rd_clk   => '0',
      fifo_rd_en    => '0',
      rst           => s_lg_iserdese3_array(v_adc).rst
   );
    p_adc_lg_data_out(v_adc)<=s_lg_iserdese3_array(v_adc).q;
    
    s_lg_delay_control_array(v_adc).rst <= p_master_reset_in or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_0_bit+v_adc));
    s_lg_iserdese3_array(v_adc).rst <= s_lg_delay_control_array(v_adc).rst;
    
   i_iserdese3_fc : iserdese3
   generic map (
      data_width => 4,
      fifo_enable => "false",
      fifo_sync_mode => "false",
      is_clk_b_inverted => '1',
      is_clk_inverted => '0',
      is_rst_inverted => '0',
      sim_device => "ultrascale"
   )
   port map (
      fifo_empty        => open,
      internal_divclk   => open,
      q             => s_fc_iserdese3_array(v_adc).q, --adc_dfr_bte,
      clk           => s_bitclk_se(v_adc),
      clkdiv        => s_divbitclk(v_adc),
      clk_b         => s_bitclk_se(v_adc),     
      d             => s_fc_delay_control_array(v_adc).dataout,  
      fifo_rd_clk   => '0',
      fifo_rd_en    => '0',
      rst           => s_fc_iserdese3_array(v_adc).rst
   );
    p_adc_frameclk_out(v_adc)<=s_fc_iserdese3_array(v_adc).q;

    s_fc_delay_control_array(v_adc).rst <= p_master_reset_in or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_bit)) or (p_db_reg_rx_in(cfb_strobe_reg)(c_adc_readout_reset_channel_0_bit+v_adc));
    s_fc_iserdese3_array(v_adc).rst <= s_fc_delay_control_array(v_adc).rst;
    
    p_ctrl_reset_from_sm_out(v_adc)<=s_ctrl_reset_from_sm(v_adc);
    
    s_frame_missalignment(v_adc)<=p_frame_missalignment_in(v_adc);
    
    proc_rst_manager : process(s_bitclk_se(v_adc))
    variable v_counter : natural := 0;
    begin
        if rising_edge(s_bitclk_se(v_adc)) then
            if (s_frame_missalignment(v_adc) = '1') or (v_counter >= 4095) then
                v_counter := 0;
            else
                v_counter := v_counter + 1;
            end if;
            if v_counter < 1023 then
                s_ctrl_reset_from_sm(v_adc)         <= '0';
                s_bufgce_div_array(v_adc).ce  <= '1';
            elsif v_counter < 1047 then
                s_ctrl_reset_from_sm(v_adc)         <= '0';
                s_bufgce_div_array(v_adc).ce  <= '0';
            elsif v_counter < 1060 then
                s_ctrl_reset_from_sm(v_adc)         <= '0';
                s_bufgce_div_array(v_adc).ce  <= '0';           
            elsif v_counter < 2060 then
                s_ctrl_reset_from_sm(v_adc)         <= '1';
                s_bufgce_div_array(v_adc).ce  <= '1';   
            else
                s_ctrl_reset_from_sm(v_adc)         <= '0';
                s_bufgce_div_array(v_adc).ce  <= '1';            
            end if;
        end if;
    end process;
    
    
end generate;


end Behavioral;
