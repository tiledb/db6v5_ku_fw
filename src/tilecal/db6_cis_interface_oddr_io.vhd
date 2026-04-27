----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/23/2023 01:16:46 AM
-- Design Name: 
-- Module Name: db6_cis_driver_iddr - Behavioral
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
library UNISIM;
use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_cis_interface_oddr_io is
  Port (
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx; 
        p_master_reset_in       : in  std_logic;
        p_tph_out               : out t_mb_diff_pair;
        p_tpl_out               : out t_mb_diff_pair;
        p_tph_in               : in t_mb_std_logic;
        p_tpl_in               : in t_mb_std_logic
);
end db6_cis_interface_oddr_io;



architecture Behavioral of db6_cis_interface_oddr_io is


signal s_tph_q0_delay_control, s_tph_q1_delay_control, s_tpl_q0_delay_control, s_tpl_q1_delay_control: t_delay_control;
--signal s_clk640 : std_logic;
signal s_tph_q0_data_shape, s_tph_q1_data_shape, s_tpl_q0_data_shape, s_tpl_q1_data_shape : std_logic_vector(1 downto 0);
type t_data_shape_fifo is array (0 to 6) of std_logic_vector(1 downto 0);
signal s_tph_q0_data_shape_fifo, s_tph_q1_data_shape_fifo, s_tpl_q0_data_shape_fifo, s_tpl_q1_data_shape_fifo : t_data_shape_fifo;   


signal s_tph_q0_shape, s_tph_q1_shape, s_tpl_q0_shape, s_tpl_q1_shape : std_logic_vector(15 downto 0);


constant c_start_shape : std_logic_vector(31 downto 0) :=  x"0000FFFF";
constant c_end_shape : std_logic_vector(31 downto 0) :=  x"FFFF0000";

signal s_q0_start_shape, s_q0_end_shape, s_q1_start_shape, s_q1_end_shape : std_logic_vector(15 downto 0);
signal s_q0_phase_config, s_q1_phase_config : integer range 0 to 15;--integer range 0 to 15;
--signal s_cis_cdc_counter : integer range 0 to 15;
signal s_cis_cdc_counter_debug : std_logic_vector(3 downto 0);--std_logic_vector(3 downto 0);

signal s_tph_reg, s_tpl_reg : t_mb_std_logic;
signal s_tph_q0_mon, s_tph_q1_mon, s_tpl_q0_mon, s_tpl_q1_mon : std_logic_vector(1 downto 0);

constant c_pipeline_depth : integer := c_global_pipeline_depth;
type t_data_shape_pipeline is array (0 to c_pipeline_depth-1) of std_logic_vector(1 downto 0);
signal s_tph_q0_data_shape_pipeline, s_tph_q1_data_shape_pipeline, s_tpl_q0_data_shape_pipeline, s_tpl_q1_data_shape_pipeline: t_data_shape_pipeline;
--signal s_cis_phase : integer range 0 to 7 :=0;
--signal s_reset_cdc : std_logic;
    --debug
    COMPONENT ila_cis_iddr

        PORT (
            clk : IN STD_LOGIC;
        
        
        
            probe0 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
            probe1 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
            probe2 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
            probe3 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
            probe4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
            probe5 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
            probe6 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
            probe7 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
            probe8 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
            probe9 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
            probe10 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
            probe11 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
            probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
            probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
            probe14 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
            probe15 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            probe16 : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
        );
        END COMPONENT  ;

begin



    i_tph_q0_OBUFDS : OBUFDS
    --generic map (IOSTANDARD => "DIFF_HSTL_I_18")
        port map (
        O => p_tph_out.q0.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB =>p_tph_out.q0.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => s_tph_q0_delay_control.dataout -- 1-bit input: Buffer input
        );

    i_tph_q1_OBUFDS : OBUFDS
    --generic map (IOSTANDARD => "DIFF_HSTL_I_18")
        port map (
        O => p_tph_out.q1.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB =>p_tph_out.q1.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => s_tph_q1_delay_control.dataout -- 1-bit input: Buffer input
        );


    i_tpl_q0_OBUFDS : OBUFDS
    --generic map (IOSTANDARD => "DIFF_HSTL_I_18")
        port map (
        O => p_tpl_out.q0.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB => p_tpl_out.q0.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => s_tpl_q0_delay_control.dataout -- 1-bit input: Buffer input
        );


    i_tpl_q1_OBUFDS : OBUFDS
    --generic map (IOSTANDARD => "DIFF_HSTL_I_18")
        port map (
        O => p_tpl_out.q1.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB => p_tpl_out.q1.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
        I => s_tpl_q1_delay_control.dataout -- 1-bit input: Buffer input
        );

    i_odelaye3_tph_q0 : odelaye3
    generic map (
        SIM_DEVICE => "ULTRASCALE",
        cascade => "none", -- cascade setting (none, master, slave_end, slave_middle)
        delay_format => "count", -- (time, count)
        delay_type => "fixed", -- set the type of tap delay line (fixed, var_load, variable)
        delay_value => 0, -- output delay tap setting
        is_clk_inverted => '0', -- optional inversion for clk
        is_rst_inverted => '0', -- optional inversion for rst
        refclk_frequency => 320.0, -- idelayctrl clock input frequency in mhz (values).
        update_mode => "async" -- determines when updates to the delay will take effect (async, manual, sync)
    )
    port map (
        casc_out => s_tph_q0_delay_control.casc_out, -- 1-bit output: cascade delay output to idelay input cascade
        cntvalueout => s_tph_q0_delay_control.cntvalueout, -- 9-bit output: counter value output
        dataout => s_tph_q0_delay_control.dataout, -- 1-bit output: delayed data from odatain input port
        casc_in => s_tph_q0_delay_control.casc_in , -- 1-bit input: cascade delay input from slave idelay cascade_out
        casc_return => s_tph_q0_delay_control.casc_return, -- 1-bit input: cascade delay returning from slave idelay dataout
        ce => s_tph_q0_delay_control.ce , -- 1-bit input: active high enable increment/decrement input
        clk => p_clknet_in.mmcm_refclk320,--s_clk640,--p_clknet_in.osc_clk200, -- 1-bit input: clock input
        cntvaluein => s_tph_q0_delay_control.cntvaluein, -- 9-bit input: counter value input
        en_vtc => s_tph_q0_delay_control.en_vtc, -- 1-bit input: keep delay constant over vt
        inc => s_tph_q0_delay_control.inc, -- 1-bit input: increment / decrement tap delay input
        load => s_tph_q0_delay_control.load, -- 1-bit input: load delay_value input
        odatain => s_tph_q0_delay_control.odatain, -- 1-bit input: data input
        rst => s_tph_q0_delay_control.rst -- 1-bit input: asynchronous reset to the delay_value
    );
    
        s_tph_q0_delay_control.casc_in <= '0';
        s_tph_q0_delay_control.casc_return <= '0';
        s_tph_q0_delay_control.ce <= '0';
        s_tph_q0_delay_control.cntvaluein <= (others => '0');
        s_tph_q0_delay_control.en_vtc <= '1';
        s_tph_q0_delay_control.inc <= '0';
        s_tph_q0_delay_control.load <= '0';
        s_tph_q0_delay_control.rst <= '0';


    i_odelaye3_tph_q1 : odelaye3
    generic map (
        SIM_DEVICE => "ULTRASCALE",
        cascade => "none", -- cascade setting (none, master, slave_end, slave_middle)
        delay_format => "count", -- (time, count)
        delay_type => "fixed", -- set the type of tap delay line (fixed, var_load, variable)
        delay_value => 0, -- output delay tap setting
        is_clk_inverted => '0', -- optional inversion for clk
        is_rst_inverted => '0', -- optional inversion for rst
        refclk_frequency => 320.0, -- idelayctrl clock input frequency in mhz (values).
        update_mode => "async" -- determines when updates to the delay will take effect (async, manual, sync)
    )
    port map (
        casc_out => s_tph_q1_delay_control.casc_out, -- 1-bit output: cascade delay output to idelay input cascade
        cntvalueout => s_tph_q1_delay_control.cntvalueout, -- 9-bit output: counter value output
        dataout => s_tph_q1_delay_control.dataout, -- 1-bit output: delayed data from odatain input port
        casc_in => s_tph_q1_delay_control.casc_in , -- 1-bit input: cascade delay input from slave idelay cascade_out
        casc_return => s_tph_q1_delay_control.casc_return, -- 1-bit input: cascade delay returning from slave idelay dataout
        ce => s_tph_q1_delay_control.ce , -- 1-bit input: active high enable increment/decrement input
        clk => p_clknet_in.mmcm_refclk320,--s_clk640,--p_clknet_in.osc_clk200, -- 1-bit input: clock input
        cntvaluein => s_tph_q1_delay_control.cntvaluein, -- 9-bit input: counter value input
        en_vtc => s_tph_q1_delay_control.en_vtc, -- 1-bit input: keep delay constant over vt
        inc => s_tph_q1_delay_control.inc, -- 1-bit input: increment / decrement tap delay input
        load => s_tph_q1_delay_control.load, -- 1-bit input: load delay_value input
        odatain => s_tph_q1_delay_control.odatain, -- 1-bit input: data input
        rst => s_tph_q1_delay_control.rst -- 1-bit input: asynchronous reset to the delay_value
    );
    
        s_tph_q1_delay_control.casc_in <= '0';
        s_tph_q1_delay_control.casc_return <= '0';
        s_tph_q1_delay_control.ce <= '0';
        s_tph_q1_delay_control.cntvaluein <= (others => '0');
        s_tph_q1_delay_control.en_vtc <= '1';
        s_tph_q1_delay_control.inc <= '0';
        s_tph_q1_delay_control.load <= '0';
        s_tph_q1_delay_control.rst <= '0';
        
    i_odelaye3_tpl_q0 : odelaye3
    generic map (
        SIM_DEVICE => "ULTRASCALE",
        cascade => "none", -- cascade setting (none, master, slave_end, slave_middle)
        delay_format => "count", -- (time, count)
        delay_type => "fixed", -- set the type of tap delay line (fixed, var_load, variable)
        delay_value => 0, -- output delay tap setting
        is_clk_inverted => '0', -- optional inversion for clk
        is_rst_inverted => '0', -- optional inversion for rst
        refclk_frequency => 640.0, -- idelayctrl clock input frequency in mhz (values).
        update_mode => "async" -- determines when updates to the delay will take effect (async, manual, sync)
    )
    port map (
        casc_out => s_tpl_q0_delay_control.casc_out, -- 1-bit output: cascade delay output to idelay input cascade
        cntvalueout => s_tpl_q0_delay_control.cntvalueout, -- 9-bit output: counter value output
        dataout => s_tpl_q0_delay_control.dataout, -- 1-bit output: delayed data from odatain input port
        casc_in => s_tpl_q0_delay_control.casc_in , -- 1-bit input: cascade delay input from slave idelay cascade_out
        casc_return => s_tpl_q0_delay_control.casc_return, -- 1-bit input: cascade delay returning from slave idelay dataout
        ce => s_tpl_q0_delay_control.ce , -- 1-bit input: active high enable increment/decrement input
        clk => p_clknet_in.mmcm_refclk320, --s_clk640,--p_clknet_in.osc_clk200, -- 1-bit input: clock input
        cntvaluein => s_tpl_q0_delay_control.cntvaluein, -- 9-bit input: counter value input
        en_vtc => s_tpl_q0_delay_control.en_vtc, -- 1-bit input: keep delay constant over vt
        inc => s_tpl_q0_delay_control.inc, -- 1-bit input: increment / decrement tap delay input
        load => s_tpl_q0_delay_control.load, -- 1-bit input: load delay_value input
        odatain => s_tpl_q0_delay_control.odatain, -- 1-bit input: data input
        rst => s_tpl_q0_delay_control.rst -- 1-bit input: asynchronous reset to the delay_value
    );
    
        s_tpl_q0_delay_control.casc_in <= '0';
        s_tpl_q0_delay_control.casc_return <= '0';
        s_tpl_q0_delay_control.ce <= '0';
        s_tpl_q0_delay_control.cntvaluein <= (others => '0');
        s_tpl_q0_delay_control.en_vtc <= '1';
        s_tpl_q0_delay_control.inc <= '0';
        s_tpl_q0_delay_control.load <= '0';
        s_tpl_q0_delay_control.rst <= '0';
        
        
    i_odelaye3_tpl_q1 : odelaye3
    generic map (
        SIM_DEVICE => "ULTRASCALE",
        cascade => "none", -- cascade setting (none, master, slave_end, slave_middle)
        delay_format => "count", -- (time, count)
        delay_type => "fixed", -- set the type of tap delay line (fixed, var_load, variable)
        delay_value => 0, -- output delay tap setting
        is_clk_inverted => '0', -- optional inversion for clk
        is_rst_inverted => '0', -- optional inversion for rst
        refclk_frequency => 640.0, -- idelayctrl clock input frequency in mhz (values).
        update_mode => "async" -- determines when updates to the delay will take effect (async, manual, sync)
    )
    port map (
        casc_out => s_tpl_q1_delay_control.casc_out, -- 1-bit output: cascade delay output to idelay input cascade
        cntvalueout => s_tpl_q1_delay_control.cntvalueout, -- 9-bit output: counter value output
        dataout => s_tpl_q1_delay_control.dataout, -- 1-bit output: delayed data from odatain input port
        casc_in => s_tpl_q1_delay_control.casc_in , -- 1-bit input: cascade delay input from slave idelay cascade_out
        casc_return => s_tpl_q1_delay_control.casc_return, -- 1-bit input: cascade delay returning from slave idelay dataout
        ce => s_tpl_q1_delay_control.ce , -- 1-bit input: active high enable increment/decrement input
        clk => p_clknet_in.mmcm_refclk320,--s_clk640,--p_clknet_in.osc_clk200, -- 1-bit input: clock input
        cntvaluein => s_tpl_q1_delay_control.cntvaluein, -- 9-bit input: counter value input
        en_vtc => s_tpl_q1_delay_control.en_vtc, -- 1-bit input: keep delay constant over vt
        inc => s_tpl_q1_delay_control.inc, -- 1-bit input: increment / decrement tap delay input
        load => s_tpl_q1_delay_control.load, -- 1-bit input: load delay_value input
        odatain => s_tpl_q1_delay_control.odatain, -- 1-bit input: data input
        rst => s_tpl_q1_delay_control.rst -- 1-bit input: asynchronous reset to the delay_value
    );
    
        s_tpl_q1_delay_control.casc_in <= '0';
        s_tpl_q1_delay_control.casc_return <= '0';
        s_tpl_q1_delay_control.ce <= '0';
        s_tpl_q1_delay_control.cntvaluein <= (others => '0');
        s_tpl_q1_delay_control.en_vtc <= '1';
        s_tpl_q1_delay_control.inc <= '0';
        s_tpl_q1_delay_control.load <= '0';
        s_tpl_q1_delay_control.rst <= '0';



    i_oddre1_tph_q0 : oddre1
    generic map (
        is_c_inverted => '1', -- optional inversion for c
        is_d1_inverted => '0', -- optional inversion for d1
        is_d2_inverted => '0', -- optional inversion for d2
        srval => '0' -- initializes the oddre1 flip-flops to the specified value (1'b0, 1'b1)
    )
        port map (
        q => s_tph_q0_delay_control.odatain, -- 1-bit output: data output to iob
        c => p_clknet_in.mmcm_refclk320,--s_clk640, -- 1-bit input: high-speed clock input
        d1 => s_tph_q0_data_shape_fifo(c_pipeline_depth-1)(1),--s_tph_q0_data_shape(1), -- 1-bit input: parallel data input 1
        d2 => s_tph_q0_data_shape_fifo(c_pipeline_depth-1)(0),--s_tph_q0_data_shape(0), -- 1-bit input: parallel data input 2
        sr =>  '0' -- 1-bit input: active high async reset
    );

    i_oddre1_tph_q1 : oddre1
    generic map (
        is_c_inverted => '1', -- optional inversion for c
        is_d1_inverted => '0', -- optional inversion for d1
        is_d2_inverted => '0', -- optional inversion for d2
        srval => '0' -- initializes the oddre1 flip-flops to the specified value (1'b0, 1'b1)
    )
        port map (
        q => s_tph_q1_delay_control.odatain, -- 1-bit output: data output to iob
        c => p_clknet_in.mmcm_refclk320,--s_clk640, -- 1-bit input: high-speed clock input
        d1 => s_tph_q1_data_shape_fifo(c_pipeline_depth-1)(1),--s_tph_q1_data_shape(1), -- 1-bit input: parallel data input 1
        d2 => s_tph_q1_data_shape_fifo(c_pipeline_depth-1)(0),--s_tph_q1_data_shape(0), -- 1-bit input: parallel data input 2
        sr =>  '0' -- 1-bit input: active high async reset
    );
    
    i_oddre1_tpl_q0 : oddre1
    generic map (
        is_c_inverted => '1', -- optional inversion for c
        is_d1_inverted => '0', -- optional inversion for d1
        is_d2_inverted => '0', -- optional inversion for d2
        srval => '0' -- initializes the oddre1 flip-flops to the specified value (1'b0, 1'b1)
    )
        port map (
        q => s_tpl_q0_delay_control.odatain, -- 1-bit output: data output to iob
        c => p_clknet_in.mmcm_refclk320,--s_clk640, -- 1-bit input: high-speed clock input
        d1 => s_tpl_q0_data_shape_fifo(c_pipeline_depth-1)(1), --s_tpl_q0_data_shape(1), -- 1-bit input: parallel data input 1
        d2 => s_tpl_q0_data_shape_fifo(c_pipeline_depth-1)(0), --s_tpl_q0_data_shape(0), -- 1-bit input: parallel data input 2
        sr =>  '0' -- 1-bit input: active high async reset
    );
    
    i_oddre1_tpl_q1 : oddre1
    generic map (
        is_c_inverted => '1', -- optional inversion for c
        is_d1_inverted => '0', -- optional inversion for d1
        is_d2_inverted => '0', -- optional inversion for d2
        srval => '0' -- initializes the oddre1 flip-flops to the specified value (1'b0, 1'b1)
    )
        port map (
        q => s_tpl_q1_delay_control.odatain, -- 1-bit output: data output to iob
        c => p_clknet_in.mmcm_refclk320,--s_clk640, -- 1-bit input: high-speed clock input
        d1 => s_tpl_q1_data_shape_fifo(c_pipeline_depth-1)(1), --s_tpl_q1_data_shape(1), -- 1-bit input: parallel data input 1
        d2 => s_tpl_q1_data_shape_fifo(c_pipeline_depth-1)(0), ----s_tpl_q1_data_shape(0), -- 1-bit input: parallel data input 2
        sr =>  '0' -- 1-bit input: active high async reset
    );
    

s_tpl_q1_data_shape_fifo(c_pipeline_depth-1)<=s_tpl_q0_data_shape;
s_tpl_q0_data_shape_fifo(c_pipeline_depth-1)<=s_tpl_q1_data_shape;
s_tph_q1_data_shape_fifo(c_pipeline_depth-1)<=s_tph_q0_data_shape;
s_tph_q0_data_shape_fifo(c_pipeline_depth-1)<=s_tph_q1_data_shape;
    
--    proc_cdc_pipeline: process(p_clknet_in.mmcm_refclk320)
--    begin
--        if rising_edge(p_clknet_in.mmcm_refclk320) then
--            for p in 0 to (c_pipeline_depth-1-1) loop
--                s_tph_q0_data_shape_fifo(p+1)<=s_tph_q0_data_shape_fifo(p);
--                s_tph_q1_data_shape_fifo(p+1)<=s_tph_q1_data_shape_fifo(p);
--                s_tpl_q0_data_shape_fifo(p+1)<=s_tpl_q0_data_shape_fifo(p);
--                s_tpl_q1_data_shape_fifo(p+1)<=s_tpl_q1_data_shape_fifo(p);
--            end loop;            
--            s_tph_q0_data_shape_fifo(0)<=s_tph_q0_data_shape;
--            s_tph_q1_data_shape_fifo(0)<=s_tph_q1_data_shape;
--            s_tpl_q0_data_shape_fifo(0)<=s_tpl_q0_data_shape;
--            s_tpl_q1_data_shape_fifo(0)<=s_tpl_q1_data_shape;
    
        
--        end if;
        
    
--    end process;
    
    
    
    proc_shift_iddr_data: process(p_clknet_in.mmcm_refclk320)
    type t_sm_iddr_data_sync is (st_wait, st_sync);
    variable v_tph_q0_mon, v_tph_q1_mon, v_tpl_q0_mon, v_tpl_q1_mon : std_logic_vector(1 downto 0);
    begin
            
        if rising_edge(p_clknet_in.mmcm_refclk320) then
--            s_cis_cdc_counter_debug<=std_logic_vector(to_unsigned(p_clknet_in.cis_cdc_counter, 4));
            s_tph_q0_data_shape<=s_tph_q0_shape(15-(2*p_clknet_in.cis_cdc_counter) downto 15-(2*p_clknet_in.cis_cdc_counter+1));
            s_tph_q1_data_shape<=s_tph_q1_shape(15-(2*p_clknet_in.cis_cdc_counter) downto 15-(2*p_clknet_in.cis_cdc_counter+1));
            s_tpl_q0_data_shape<=s_tpl_q0_shape(15-(2*p_clknet_in.cis_cdc_counter) downto 15-(2*p_clknet_in.cis_cdc_counter+1));
            s_tpl_q1_data_shape<=s_tpl_q1_shape(15-(2*p_clknet_in.cis_cdc_counter) downto 15-(2*p_clknet_in.cis_cdc_counter+1));
            
            if p_clknet_in.cis_cdc_counter=0 then
                s_tph_reg <= p_tph_in;
                s_tpl_reg <= p_tpl_in;
                
                v_tph_q0_mon:= s_tph_reg.q0 & p_tph_in.q0;
                v_tph_q1_mon:= s_tph_reg.q1 & p_tph_in.q1;
                v_tpl_q0_mon:= s_tpl_reg.q0 & p_tpl_in.q0;
                v_tpl_q1_mon:= s_tpl_reg.q1 & p_tpl_in.q1;

                s_tph_q0_mon <= v_tph_q0_mon;
                s_tph_q1_mon <= v_tph_q1_mon;
                s_tpl_q0_mon <= v_tpl_q0_mon;
                s_tpl_q1_mon <= v_tpl_q1_mon;
               
                case v_tph_q0_mon is
                    when "00" =>
                        s_tph_q0_shape<=(others=>'0');
                    when "01" =>
                        s_tph_q0_shape<=s_q0_start_shape;
                    when "11" =>
                        s_tph_q0_shape<=(others=>'1');
                    when "10" =>
                        s_tph_q0_shape<=s_q0_end_shape;
                    when others=>
                end case;

                case v_tph_q1_mon is
                    when "00" =>
                        s_tph_q1_shape<=(others=>'0');
                    when "01" =>
                        s_tph_q1_shape<=s_q1_start_shape;
                    when "11" =>
                        s_tph_q1_shape<=(others=>'1');
                    when "10" =>
                        s_tph_q1_shape<=s_q1_end_shape;
                    when others=>
                end case;                             

                case v_tpl_q0_mon is
                    when "00" =>
                        s_tpl_q0_shape<=(others=>'0');
                    when "01" =>
                        s_tpl_q0_shape<=s_q0_start_shape;
                    when "11" =>
                        s_tpl_q0_shape<=(others=>'1');
                    when "10" =>
                        s_tpl_q0_shape<=s_q0_end_shape;
                    when others=>
                end case;

                case v_tpl_q1_mon is
                    when "00" =>
                        s_tpl_q1_shape<=(others=>'0');
                    when "01" =>
                        s_tpl_q1_shape<=s_q1_start_shape;
                    when "11" =>
                        s_tpl_q1_shape<=(others=>'1');
                    when "10" =>
                        s_tpl_q1_shape<=s_q1_end_shape;
                    when others=>
                end case;
                                                                
            end if;
        end if;
    end process;
    
    
    s_q0_phase_config<=to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(11 downto 8)));--(11 downto 6)));--to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(11 downto 7)));
    s_q0_start_shape<= c_start_shape(15 + s_q0_phase_config downto 0 + s_q0_phase_config);--c_start_shape(31 + 2*s_q0_phase_config downto 0 + 2*s_q0_phase_config);
    s_q0_end_shape<= c_end_shape(15 + s_q0_phase_config downto 0 + s_q0_phase_config);--c_end_shape(31 + 2*s_q0_phase_config downto 0 + 2*s_q0_phase_config);

    s_q1_phase_config<=to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(27 downto 24)));--(27 downto 22)));--to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(27 downto 23)));
    s_q1_start_shape<= c_start_shape(15 + s_q1_phase_config downto 0 + s_q1_phase_config);--c_start_shape(31 + 2*s_q1_phase_config downto 0 + 2*s_q1_phase_config);
    s_q1_end_shape<= c_end_shape(15 + s_q1_phase_config downto 0 + s_q1_phase_config);--c_end_shape(31 + 2*s_q1_phase_config downto 0 + 2*s_q1_phase_config);

    
    --debug
--    i_ila_cis_iddr : ila_cis_iddr
--        PORT MAP (
--            clk => s_clk640,
        
        
        
--            probe0 => s_tph_q0_data_shape, 
--            probe1 => s_tph_q1_data_shape, 
--            probe2 => s_tpl_q0_data_shape, 
--            probe3 => s_tpl_q1_data_shape, 
--            probe4 => s_tph_q0_shape, 
--            probe5 => s_tph_q1_shape, 
--            probe6 => s_tpl_q0_shape, 
--            probe7 => s_tpl_q1_shape, 
--            probe8 => s_tph_q0_mon, 
--            probe9 => s_tph_q1_mon, 
--            probe10 => s_tpl_q0_mon, 
--            probe11 => s_tpl_q1_mon, 
--            probe12(0) => p_tph_in.q0,
--            probe13(0) => p_tph_in.q1, 
--            probe14(0) => p_tpl_in.q0, 
--            probe15(0) => p_tpl_in.q1,
--            probe16 => s_cis_cdc_counter_debug
--        );
        
    
end Behavioral;
