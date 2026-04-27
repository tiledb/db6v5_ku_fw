----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.10.2022 22:49:01
-- Design Name: 
-- Module Name: db6_cfgbus_interface_io_iddr - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity db6_cfgbus_interface_io_iddr is
    Port (     
               p_master_reset_in        : in    std_logic;
               p_clknet_in              : in    t_db_clknet;
               p_iddr_clk_in              : in    std_logic;
               p_iddr_freerun_clk_in              : in    std_logic;
               p_cfgbus_data_in       : in t_cfgbus_data_in;
               p_cfgbus_bitslice_out  : out t_cfgbus_bitslice;
                           
               p_leds_out : out std_logic_vector(3 downto 0)
    );
end db6_cfgbus_interface_io_iddr;

architecture Behavioral of db6_cfgbus_interface_io_iddr is

    signal s_cfgbus_data_se, s_cfgbus_data_delayed : std_logic_vector(7 downto 0);
    type t_cfgbus_delay_control_array is array (0 to 7) of t_delay_control;
    signal s_cfgbus_delay_control : t_cfgbus_delay_control_array := (others => c_delay_control);


begin

    p_leds_out <= "0000";

    gen_cfgbus_io : for k in 0 to 7 generate
    begin
    i_ibufds_cfbl : ibufds
         generic map (
           diff_term => true,
           iostandard => "sub_lvds")
         port map (
           o  => s_cfgbus_data_se(k),             -- buffer diff_p output
           i  => p_cfgbus_data_in(k).p, -- diff_p buffer input (connect directly to top-level port)
           ib => p_cfgbus_data_in(k).n -- diff_n buffer input (connect directly to top-level port)
           );
    
--    i_bufgce_cfb1 : bufgce  
--        port map (
--        o  => s_cfgbus_clk40,
--        i  => p_iddr_clk_in,
--        ce => '1'
--        );     
           
    i_idelaye3_cfgbus_in : idelaye3
    generic map (
        SIM_DEVICE => "ULTRASCALE",
        cascade => "none", -- cascade setting (none, master, slave_end, slave_middle)
        delay_format => "count", -- units of the delay_value (time, count)
        delay_src => "idatain", -- delay input (idatain, datain)
        delay_type => "fixed", -- set the type of tap delay line (fixed, var_load, variable)
        delay_value => 0, -- input delay value setting
        is_clk_inverted => '0', -- optional inversion for clk
        is_rst_inverted => '0', -- optional inversion for rst
        refclk_frequency => 200.0, -- idelayctrl clock input frequency in mhz (values)
        update_mode => "async" -- determines when updates to the delay will take effect (async, manual, sync)
        )
        port map (
        casc_out => s_cfgbus_delay_control(k).casc_out, -- 1-bit output: cascade delay output to odelay input cascade
        cntvalueout => s_cfgbus_delay_control(k).cntvalueout, -- 9-bit output: counter value output
        dataout => s_cfgbus_data_delayed(k), -- 1-bit output: delayed data output
        casc_in => s_cfgbus_delay_control(k).casc_in, -- 1-bit input: cascade delay input from slave odelay cascade_out
        casc_return =>  s_cfgbus_delay_control(k).casc_return, -- 1-bit input: cascade delay returning from slave odelay dataout
        ce => s_cfgbus_delay_control(k).ce, -- 1-bit input: active high enable increment/decrement input
        clk => p_iddr_freerun_clk_in, -- 1-bit input: clock input
        cntvaluein => s_cfgbus_delay_control(k).cntvaluein, -- 9-bit input: counter value input
        datain => '0',--s_data_lg(i), -- 1-bit input: data input from the iobuf
        en_vtc => s_cfgbus_delay_control(k).en_vtc, -- 1-bit input: keep delay constant over vt
        idatain => s_cfgbus_data_se(k), -- 1-bit input: data input from the logic
        inc => s_cfgbus_delay_control(k).inc, -- 1-bit input: increment / decrement tap delay input
        load => s_cfgbus_delay_control(k).load, -- 1-bit input: load delay_value input
        rst => p_master_reset_in -- 1-bit input: asynchronous reset to the delay_value
);

    s_cfgbus_delay_control(k).casc_in <= '0';
    s_cfgbus_delay_control(k).casc_return <= '0';
    s_cfgbus_delay_control(k).ce <= '0';
    s_cfgbus_delay_control(k).cntvaluein <= (others => '0');
    s_cfgbus_delay_control(k).en_vtc <= '1';
    s_cfgbus_delay_control(k).inc <= '0';
    s_cfgbus_delay_control(k).load <= '0';
    s_cfgbus_delay_control(k).rst <= '0';



    i_iddre1_cfgbus_in : iddre1
    generic map (
        ddr_clk_edge => "SAME_EDGE_PIPELINED", -- iddre1 mode (opposite_edge, same_edge, same_edge_pipelined)
        is_c_inverted => '0', -- optional inversion for c
        is_cb_inverted => '1' -- optional inversion for c
    )
    port map (
        q1 => p_cfgbus_bitslice_out(k)(1), -- 1-bit output: registered parallel output 1
        q2 => p_cfgbus_bitslice_out(k)(0), -- 1-bit output: registered parallel output 2
        c => p_iddr_clk_in, -- 1-bit input: high-speed clock
        cb => p_iddr_clk_in, -- 1-bit input: inversion of high-speed clock c
        d => s_cfgbus_data_delayed(k), -- 1-bit input: serial data input
        r => p_master_reset_in -- 1-bit input: active high async reset
);


    
end generate gen_cfgbus_io;


end Behavioral;
