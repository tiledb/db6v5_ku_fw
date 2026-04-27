---------------------------------------------------------------------------------
-- Company: 
-- Engineer: Eduardo Valdes Santurio
--           Samuel Silverstein
--           Fernando Carrio
-- 
-- Create Date: 09/29/2018 04:51:03 PM
-- Design Name: 
-- Module Name: db5_mb_driver - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_mainboard_driver is
    generic (
    g_use_db5_code : natural := 0
    );
	port (
        --p_db_side_in     : in std_logic_vector(0 downto 0);
        p_master_reset_in : in std_logic;
        p_clknet_in       : in  t_db_clknet;
        p_mb_config_trigger_in : in std_logic;
        p_ssel_out         : out t_mb_diff_pair; --std_logic_vector (1 downto 0);
        p_sclk_out         : out t_mb_diff_pair; --std_logic_vector (1 downto 0);
        p_sdata_out     : out t_mb_diff_pair; --std_logic_vector (1 downto 0);
        p_sdata_in    : in  t_mb_diff_pair; --std_logic_vector (1 downto 0);
        p_mb_txword_in      : in  std_logic_vector (31 downto 0);
        p_mb_rxword_out       : out t_mb_rxword;
        p_mb_tx_collision_out : out t_mb_std_logic;
        p_rx_done_out       : out t_mb_std_logic;
        p_tx_done_out       : out t_mb_std_logic;
        p_idle_out       : out t_mb_std_logic;
        p_leds_out              : out std_logic_vector(3 downto 0)
);
end db6_mainboard_driver;

architecture Behavioral of db6_mainboard_driver is

    signal s_sclk_out_buf      : std_logic_vector(1 downto 0);

--    type t_data_buffer is array (0 to 7) of std_logic_vector(31 downto 0);
--    signal s_fe_data_buffer : t_data_buffer; 
	signal s_fe_data, s_fe_data_old, s_fe_data_older   		: std_logic_vector(31 downto 0);
	signal s_mb_config_trigger_buffer : std_logic;
	signal s_execute      			: std_logic_vector(1 downto 0);
	signal s_bk_ena       			: std_logic_vector(1 downto 0);
	type s_cycle_array is array (0 to 1) of std_logic_vector(11 downto 0);
	--signal s_cycle					: cycle_array :=(others=>(others=>'0'));


	type t_mb_state is ( -- What do all of these states do? (Sam)
    mb_idle,
    mb_s0a,
    mb_s0b,
    mb_s1a,
    mb_s1b,
    mb_s2a,
    mb_s2b,
    mb_s3a,
    mb_s3b,
    mb_s4a,
    mb_s4b,
    mb_s5a,
    mb_s5b,
    mb_s6a,
    mb_s6b,
    mb_s7a,
    mb_s7b,
    mb_s8a,
    mb_s8b,
    mb_s9a,
    mb_s9b,
    mb_s10a,
    mb_s10b,
    mb_s11a,
    mb_s11b,
    mb_s12a,
    mb_s12b,
    mb_s13a,
    mb_s13b,
    mb_s14a,
    mb_s14b,
    mb_s15a,
    mb_s15b,
    mb_s16a,
    mb_s16b,
    mb_s17a,
    mb_s17b,
    mb_s18a,
    mb_s18b,
    mb_s19a,
    mb_s19b,
    mb_s20a,
    mb_s20b,
    mb_s21a,
    mb_s21b,
    mb_s22a,
    mb_s22b,
    mb_s23a,
    mb_s23b,
    mb_exa,
    mb_exb,
    mb_exc,
    mb_b0a,
    mb_b0b,
    mb_b1a,
    mb_b1b,
    mb_b2a,
    mb_b2b,
    mb_b3a,
    mb_b3b,
    mb_b4a,
    mb_b4b,
    mb_b5a,
    mb_b5b,
    mb_b6a,
    mb_b6b,
    mb_b7a,
    mb_b7b,
    mb_b8a,
    mb_b8b,
    mb_b9a,
    mb_b9b,
    mb_b10a,
    mb_b10b,
    mb_b11a,
    mb_b11b,
    mb_b12a,
    mb_b12b,
    mb_b13a,
    mb_b13b,
    mb_b14a,
    mb_b14b,
    mb_b15a,
    mb_b15b,
    mb_b16a,
    mb_b16b,
    mb_b17a,
    mb_b17b);

type t_mb_state_pair is array (0 to 1) of t_mb_state;
signal s_mb_current : t_mb_state_pair;
signal s_mb_next    : t_mb_state_pair;
type t_std_logic_pair is array (0 to 1) of std_logic;-- := ('0','0');
signal s_mb_exe     : t_std_logic_pair;
signal s_mb_clk     : t_std_logic_pair;
signal s_mb_clr     : t_std_logic_pair;
signal s_bk_clr     : t_std_logic_pair;
signal s_mb_st      : t_std_logic_pair;
signal s_bk_st      : t_std_logic_pair;
signal s_lrtn_bit   : t_std_logic_pair;
signal s_idle_out   : t_std_logic_pair;
signal s_rtn_done, s_mb_strt, s_bk_strt, s_mb_execute, s_mb_clock, s_mb_data_out, s_mb_data_in, s_rtn_bit   : t_std_logic_pair;
type  t_command_pair is array (0 to 1) of std_logic_vector(23 downto 0);
signal s_command : t_command_pair;  -- command to be sent to mainboard
type t_rtn_wd_pair is array (0 to 1) of std_logic_vector(17 downto 0);
signal s_rtn_wd : t_rtn_wd_pair;

signal s_mb_tx_collision : t_mb_std_logic;


constant c_pipeline_depth : integer := c_global_pipeline_depth;
type t_db_reg_rx_pipeline is array (0 to c_pipeline_depth-1) of t_db_reg_rx;
type t_reg_r_strobe_pipeline is array (0 to c_pipeline_depth-1) of std_logic_vector(31 downto 0);
type t_bcr_pipeline is array(0 to c_pipeline_depth-1) of t_bcr;


COMPONENT ila_mb_driver

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(17 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(17 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe10 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe14 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe15 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe16 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe17 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe18 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe19 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
	probe20 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
	probe21 : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
	
);
END COMPONENT  ;

signal s_db5_side_in : std_logic_vector(1 downto 0);

begin

--signals to/from the top, numbered for easier debug implementation 


i_mb_q0_sdata_out_OBUFDS : OBUFDS
    port map (
    O => p_sdata_out.q0.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
    OB => p_sdata_out.q0.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
    I => s_mb_data_out(0) -- 1-bit input: Buffer input
    );

i_mb_q1_sdata_out_OBUFDS : OBUFDS
    port map (
    O => p_sdata_out.q1.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
    OB => p_sdata_out.q1.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
    I => s_mb_data_out(1) -- 1-bit input: Buffer input
    );

i_mb_q0_sdata_in_IBUFDS : IBUFDS
    port map (
    I => p_sdata_in.q0.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
    IB => p_sdata_in.q0.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
    O => s_mb_data_in(0) -- 1-bit input: Buffer input
    );

i_mb_q1_sdata_in_IBUFDS : IBUFDS
    port map (
    I => p_sdata_in.q1.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
    IB => p_sdata_in.q1.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
    O => s_mb_data_in(1) -- 1-bit input: Buffer input
    );


i_mb_q0_sclk_OBUFDS : OBUFDS
    port map (
    O => p_sclk_out.q0.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
    OB => p_sclk_out.q0.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
    I => s_sclk_out_buf(0) -- 1-bit input: Buffer input
    );

i_mb_q1_sclk_OBUFDS : OBUFDS
    port map (
    O => p_sclk_out.q1.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
    OB => p_sclk_out.q1.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
    I => s_sclk_out_buf(1) -- 1-bit input: Buffer input
    );

i_mb_q0_psel_OBUFDS : OBUFDS
    port map (
    O => p_ssel_out.q0.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
    OB => p_ssel_out.q0.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
    I => s_mb_exe(0) -- 1-bit input: Buffer input
    );

i_mb_q1_psel_OBUFDS : OBUFDS
    port map (
    O => p_ssel_out.q1.p, -- 1-bit output: Diff_p output (connect directly to top-level port)
    OB => p_ssel_out.q1.n, -- 1-bit output: Diff_n output (connect directly to top-level port)
    I => s_mb_exe(1) -- 1-bit input: Buffer input
    );


    --s_mb_clk(0)<=s_sclk_out_buf(0);  --s_mb_clk(1);
    --s_mb_clk(1)<=s_sclk_out_buf(1);  -- s_mb_clk(0);
    s_lrtn_bit(1) 	<= s_mb_data_in(1);
    s_lrtn_bit(0) 	<= s_mb_data_in(0);
    
    p_idle_out.q1 <= s_idle_out(1);
    p_idle_out.q0 <= s_idle_out(0);
    p_rx_done_out.q1 <= s_rtn_done(1);
    p_rx_done_out.q0 <= s_rtn_done(0);
    p_tx_done_out.q1 <= s_mb_exe(1);
    p_tx_done_out.q0 <= s_mb_exe(0) ;
    p_mb_rxword_out.q1 <= s_rtn_wd(1);
    p_mb_rxword_out.q0 <= s_rtn_wd(0);
--    s_command(1)<=p_mb_txword_in(23 downto 0); 
--    s_command(0)<=p_mb_txword_in(23 downto 0);
    p_mb_tx_collision_out <= s_mb_tx_collision;
    
    p_leds_out(3) <=  s_rtn_done(1);
    p_leds_out(2) <=  s_rtn_done(0);
    p_leds_out(1) <=  s_rtn_done(1);
    p_leds_out(0) <=  s_rtn_done(0);
    
    --s_mb_clock   	<= s_mb_clk;
    --s_lrtn_bit 	<= s_rtn_bit;
    
    s_sclk_out_buf(0) <= s_mb_clk(0); -- This works without delay, but we could add 1/4 clock delay here if we wanted
    s_sclk_out_buf(1) <= s_mb_clk(1);
    
    proc_mb_toggler : process (p_clknet_in.cfgbus_clk40, p_master_reset_in)
    begin
        if p_master_reset_in = '1' then
            --s_fe_data_buffer <= (others=> (others=>'0'));
            s_fe_data <= (others=>'0');
            s_fe_data_old <= (others=>'0');
            s_execute 	<= "00";
            s_bk_ena 	<= "00";
            s_mb_tx_collision.q0 <= '0';
            s_mb_tx_collision.q1 <= '0';
            
        elsif rising_edge(p_clknet_in.cfgbus_clk40) then
    --            if s_mb_current(0) = mb_idle or s_mb_current(1) = mb_idle then
                s_fe_data <= p_mb_txword_in;
    --            s_mb_config_trigger_buffer <= p_mb_config_trigger_in;			
    --                s_fe_data_old <= s_fe_data;
                    --s_fe_data_older <= s_fe_data_old;
    --            end if;	
    
                if (s_fe_data=p_mb_txword_in) and (p_mb_config_trigger_in='0') then
                    s_execute 	<= "00";
                    s_bk_ena 	<= "00";            
    --            elsif (s_mb_config_trigger_buffer = '1' and  p_mb_config_trigger_in= '1') 
    --                or (s_mb_config_trigger_buffer = '0' and  p_mb_config_trigger_in= '0')
    --                or (s_mb_config_trigger_buffer = '1' and  p_mb_config_trigger_in= '0')
    --                then
    --                s_execute 	<= "00";
    --                s_bk_ena 	<= "00";
                else
                    if (s_mb_current(0) = mb_idle) or (s_mb_current(1) = mb_idle) then
                    else
                        s_mb_tx_collision.q0 <= '1';
                        s_mb_tx_collision.q1 <= '1';
                    end if;                
                    s_command(1)<=p_mb_txword_in(23 downto 0);--p_mb_txword_in(23 downto 0); 
                    s_command(0)<=p_mb_txword_in(23 downto 0);--p_mb_txword_in(23 downto 0);
                    if (p_mb_txword_in(23 downto 21)="100" or p_mb_txword_in(23 downto 21)="010") then
                        case p_mb_txword_in(20 downto 18) is
                            when "010" =>
                                s_execute 	<= '0' & p_clknet_in.db_side(0);
                                s_bk_ena 	<= "00";
                            when "011" =>
                                s_execute 	<= p_clknet_in.db_side(0) & '0';
                                s_bk_ena 	<= "00";					
                            when "000" =>
                                s_execute 	<= '0' & not p_clknet_in.db_side(0);
                                s_bk_ena 	<= "00";					
                            when "001" =>
                                s_execute 	<= not p_clknet_in.db_side & '0';
                                s_bk_ena 	<= "00";										
                            when others=>
                                s_execute 	<= "11";
                                s_bk_ena 	<= "00";			
                        end case;
                    elsif(p_mb_txword_in(23 downto 21)="001" or p_mb_txword_in(23 downto 21)="101") then
                        case p_mb_txword_in(20 downto 18) is
                            when "010" =>
                                s_execute 	<= "00";
                                s_bk_ena 	<= '0' & p_clknet_in.db_side(0);
                            when "011" =>
                                s_execute 	<= "00";
                                s_bk_ena 	<= p_clknet_in.db_side(0) & '0';					
                            when "000" =>
                                s_execute 	<= "00";
                                s_bk_ena 	<= '0' & not p_clknet_in.db_side(0);					
                            when "001" =>
                                s_execute 	<= "00";
                                s_bk_ena 	<= not p_clknet_in.db_side(0) & '0';									
                            when others=>
                                s_execute 	<= "00";
                                s_bk_ena 	<= "11";
                        end case;
                    end if;
                    
                end if;
        
        end if; -- clock edge
    end process;  
    
-- Translate outputs of the above state machine to the one below: 
--    s_mb_strt(0) <= s_execute(0);
--    s_mb_strt(1) <= s_execute(1);
    
--    s_bk_strt(0) <= s_bk_ena(0);
--    s_bk_strt(1) <= s_bk_ena(1);
    
    
    -- Execute serial transmission to the MB
    
    gen_mb_quadrants : for i in 0 to 1 generate

    s_mb_strt(i) <= s_execute(i);
    s_bk_strt(i) <= s_bk_ena(i);
    
    proc_mb_to_db : process(p_clknet_in.cfgbus_clk40,p_master_reset_in)
    begin
        if (p_master_reset_in = '1') then
            s_mb_current(i) <= mb_idle;
        elsif (rising_edge(p_clknet_in.cfgbus_clk40)) then

                case s_mb_current(i) is
                    when mb_idle =>
                        s_mb_clk(i) <= '0';
                        s_mb_clr(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_bk_clr(i) <= '0';
                        s_rtn_done(i) <= '0';
                        if(s_mb_strt(i) = '1') then
                            s_mb_current(i) <= mb_s0a;
                            s_idle_out(i) <= '0';
                        elsif(s_bk_strt(i) = '1') then
                            s_mb_current(i) <= mb_b0a;
                            s_idle_out(i) <= '0';
                        else
                            s_idle_out(i) <= '1';
                            s_mb_current(i) <= mb_idle;
                        end if;
                        
                    when mb_s0a =>
                        s_mb_data_out(i) <= s_command(i)(0);
                        s_mb_exe(i)  <= '0';              -- clk 0 
                        s_mb_clr(i)  <= '1';              -- clk 0 
                        s_mb_current(i) <= mb_s0b;
                        
                    when mb_s0b =>
                        s_mb_data_out(i) <= s_command(i)(0);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s1a;
                
                    when mb_s1a =>
                        s_mb_data_out(i) <= s_command(i)(1);
                        s_mb_clk(i)  <= '0';              -- clk 1  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s1b;
                        
                    when mb_s1b =>
                        s_mb_data_out(i) <= s_command(i)(1);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s2a;
                
                    when mb_s2a =>
                        s_mb_data_out(i) <= s_command(i)(2);
                        s_mb_clk(i)  <= '0';              -- clk 2  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s2b;
                        
                    when mb_s2b =>
                        s_mb_data_out(i) <= s_command(i)(2);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s3a;
                
                    when mb_s3a =>
                        s_mb_data_out(i) <= s_command(i)(3);
                        s_mb_clk(i)  <= '0';              -- clk 3  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s3b;
                        
                    when mb_s3b =>
                        s_mb_data_out(i) <= s_command(i)(3);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s4a;
                
                    when mb_s4a =>
                        s_mb_data_out(i) <= s_command(i)(4);
                        s_mb_clk(i)  <= '0';              -- clk 4  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s4b;
                        
                    when mb_s4b =>
                        s_mb_data_out(i) <= s_command(i)(4);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s5a;
                
                    when mb_s5a =>
                        s_mb_data_out(i) <= s_command(i)(5);
                        s_mb_clk(i)  <= '0';              -- clk 5  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s5b;
                        
                    when mb_s5b =>
                        s_mb_data_out(i) <= s_command(i)(5);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s6a;
                
                    when mb_s6a =>
                        s_mb_data_out(i) <= s_command(i)(6);
                        s_mb_clk(i)  <= '0';              -- clk 6  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s6b;
                        
                    when mb_s6b =>
                        s_mb_data_out(i) <= s_command(i)(6);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s7a;
                
                    when mb_s7a =>
                        s_mb_data_out(i) <= s_command(i)(7);
                        s_mb_clk(i)  <= '0';              -- clk 7  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s7b;
                        
                    when mb_s7b =>
                        s_mb_data_out(i) <= s_command(i)(7);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s8a;
                
                    when mb_s8a =>
                        s_mb_data_out(i) <= s_command(i)(8);
                        s_mb_clk(i)  <= '0';              -- clk 8  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s8b;
                        
                    when mb_s8b =>
                        s_mb_data_out(i) <= s_command(i)(8);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s9a;
                
                    when mb_s9a =>
                        s_mb_data_out(i) <= s_command(i)(9);
                        s_mb_clk(i)  <= '0';              -- clk 9  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s9b;
                        
                    when mb_s9b =>
                        s_mb_data_out(i) <= s_command(i)(9);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s10a;
                
                    when mb_s10a =>
                        s_mb_data_out(i) <= s_command(i)(10);
                        s_mb_clk(i)  <= '0';              -- clk 10  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s10b;
                        
                    when mb_s10b =>
                        s_mb_data_out(i) <= s_command(i)(10);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s11a;
                
                    when mb_s11a =>
                        s_mb_data_out(i) <= s_command(i)(11);
                        s_mb_clk(i)  <= '0';              -- clk 11  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s11b;
                        
                    when mb_s11b =>
                        s_mb_data_out(i) <= s_command(i)(11);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s12a;
                
                    when mb_s12a =>
                        s_mb_data_out(i) <= s_command(i)(12);
                        s_mb_clk(i)  <= '0';              -- clk 12  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s12b;
                        
                    when mb_s12b =>
                        s_mb_data_out(i) <= s_command(i)(12);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s13a;
                
                    when mb_s13a =>
                        s_mb_data_out(i) <= s_command(i)(13);
                        s_mb_clk(i)  <= '0';              -- clk 13  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s13b;
                        
                    when mb_s13b =>
                        s_mb_data_out(i) <= s_command(i)(13);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s14a;
                
                    when mb_s14a =>
                        s_mb_data_out(i) <= s_command(i)(14);
                        s_mb_clk(i)  <= '0';              -- clk 14  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s14b;
                        
                    when mb_s14b =>
                        s_mb_data_out(i) <= s_command(i)(14);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s15a;
                
                    when mb_s15a =>
                        s_mb_data_out(i) <= s_command(i)(15);
                        s_mb_clk(i)  <= '0';              -- clk 15  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s15b;
                        
                    when mb_s15b =>
                        s_mb_data_out(i) <= s_command(i)(15);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s16a;
                
                    when mb_s16a =>
                        s_mb_data_out(i) <= s_command(i)(16);
                        s_mb_clk(i)  <= '0';              -- clk 16  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s16b;
                        
                    when mb_s16b =>
                        s_mb_data_out(i) <= s_command(i)(16);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s17a;
                          
                    when mb_s17a =>
                        s_mb_data_out(i) <= s_command(i)(17);
                        s_mb_clk(i)  <= '0';              -- clk 17  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s17b;
                        
                    when mb_s17b =>
                        s_mb_data_out(i) <= s_command(i)(17);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s18a;
                
                    when mb_s18a =>
                        s_mb_data_out(i) <= s_command(i)(18);
                        s_mb_clk(i)  <= '0';              -- clk 18  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s18b;
                        
                    when mb_s18b =>
                        s_mb_data_out(i) <= s_command(i)(18);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s19a;
                
                    when mb_s19a =>
                        s_mb_data_out(i) <= s_command(i)(19);
                        s_mb_clk(i)  <= '0';              -- clk 19  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s19b;
                        
                    when mb_s19b =>
                        s_mb_data_out(i) <= s_command(i)(19);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s20a;
                
                    when mb_s20a =>
                        s_mb_data_out(i) <= s_command(i)(20);
                        s_mb_clk(i)  <= '0';              -- clk 20  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s20b;
                        
                    when mb_s20b =>
                        s_mb_data_out(i) <= s_command(i)(20);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s21a;
                
                    when mb_s21a =>
                        s_mb_data_out(i) <= s_command(i)(21);
                        s_mb_clk(i)  <= '0';              -- clk 21  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s21b;
                        
                    when mb_s21b =>
                        s_mb_data_out(i) <= s_command(i)(21);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s22a;
                
                    when mb_s22a =>
                        s_mb_data_out(i) <= s_command(i)(22);
                        s_mb_clk(i)  <= '0';              -- clk 22  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s22b;
                        
                    when mb_s22b =>
                        s_mb_data_out(i) <= s_command(i)(22);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s23a;
                
                    when mb_s23a =>
                        s_mb_data_out(i) <= s_command(i)(23);
                        s_mb_clk(i)  <= '0';              -- clk 23  
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_s23b;
                        
                    when mb_s23b =>
                        s_mb_data_out(i) <= s_command(i)(23);
                        s_mb_clk(i)  <= '1';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_exa;
                
                    when mb_exa =>
                        s_mb_clk(i)  <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_exb;
                
                    when mb_exb =>
                        s_mb_clk(i)  <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i)  <= '1';
                        s_mb_current(i) <= mb_exc;
                          
                    when mb_exc =>
                        s_mb_clk(i)  <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i)  <= '1';
                        s_mb_current(i) <= mb_idle;
                          
                    when mb_b0a =>
                        s_rtn_wd(i)(0) <= s_lrtn_bit(i);    -- return 0
                        s_mb_clk(i) <= '1';
                        s_bk_clr(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b0b;
                
                    when mb_b0b =>
                --		rtn_wd(0) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b1a;
                          
                    when mb_b1a =>
                        s_rtn_wd(i)(1) <= s_lrtn_bit(i);    -- return 1
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b1b;
                
                    when mb_b1b =>
                --		rtn_wd(1) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b2a;
                          
                    when mb_b2a =>
                        s_rtn_wd(i)(2) <= s_lrtn_bit(i);    -- return 2
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b2b;
                
                    when mb_b2b =>
                --		rtn_wd(2) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b3a;
                          
                    when mb_b3a =>
                        s_rtn_wd(i)(3) <= s_lrtn_bit(i);    -- return 3
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b3b;
                
                    when mb_b3b =>
                --		rtn_wd(3) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b4a;
                          
                    when mb_b4a =>
                        s_rtn_wd(i)(4) <= s_lrtn_bit(i);    -- return 4
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b4b;
                
                    when mb_b4b =>
                --		rtn_wd(4) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b5a;
                          
                    when mb_b5a =>
                        s_rtn_wd(i)(5) <= s_lrtn_bit(i);    -- return 5
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b5b;
                
                    when mb_b5b =>
                --		rtn_wd(5) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b6a;
                          
                    when mb_b6a =>
                        s_rtn_wd(i)(6) <= s_lrtn_bit(i);    -- return 6
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b6b;
                
                    when mb_b6b =>
                --		rtn_wd(6) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b7a;
                          
                    when mb_b7a =>
                        s_rtn_wd(i)(7) <= s_lrtn_bit(i);    -- return 7
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b7b;
                
                    when mb_b7b =>
                --		rtn_wd(7) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b8a;
                          
                    when mb_b8a =>
                        s_rtn_wd(i)(8) <= s_lrtn_bit(i);    -- return 8
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b8b;
                
                    when mb_b8b =>
                --		rtn_wd(8) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b9a;
                          
                    when mb_b9a =>
                        s_rtn_wd(i)(9) <= s_lrtn_bit(i);    -- return 9
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b9b;
                
                    when mb_b9b =>
                --		rtn_wd(9) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b10a;
                          
                    when mb_b10a =>
                        s_rtn_wd(i)(10) <= s_lrtn_bit(i);    -- return 10
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b10b;
                
                    when mb_b10b =>
                --		rtn_wd(10) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b11a;
                 
                    when mb_b11a =>
                        s_rtn_wd(i)(11) <= s_lrtn_bit(i);    -- return 11
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b11b;
                
                    when mb_b11b =>
                --		rtn_wd(11) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b12a;
                          
                    when mb_b12a =>
                        s_rtn_wd(i)(12) <= s_lrtn_bit(i);    -- return 12
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b12b;
                
                    when mb_b12b =>
                --		rtn_wd(12) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b13a;
                          
                    when mb_b13a =>
                        s_rtn_wd(i)(13) <= s_lrtn_bit(i);    -- return 13
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b13b;
                
                    when mb_b13b =>
                --		rtn_wd(13) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b14a;
                          
                    when mb_b14a =>
                        s_rtn_wd(i)(14) <= s_lrtn_bit(i);    -- return 14
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b14b;
                
                    when mb_b14b =>
                --		rtn_wd(14) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b15a;
                          
                    when mb_b15a =>
                        s_rtn_wd(i)(15) <= s_lrtn_bit(i);    -- return 15
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b15b;
                
                    when mb_b15b =>
                --		rtn_wd(15) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b16a;
                          
                    when mb_b16a =>
                        s_rtn_wd(i)(16) <= s_lrtn_bit(i);    -- return 16
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b16b;
                
                    when mb_b16b =>
                --		rtn_wd(16) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_b17a;
                
                    when mb_b17a =>
                        s_rtn_wd(i)(17) <= s_lrtn_bit(i);    -- return 17
                        s_mb_clk(i) <= '1';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_rtn_done(i) <= '1';
                        s_mb_current(i) <= mb_b17b;
                
                    when mb_b17b =>
                --		rtn_wd(17) <= lrtn_bit;
                        s_mb_clk(i) <= '0';
                        s_mb_data_out(i) <= '0';
                        s_mb_exe(i) <= '0';
                        s_mb_current(i) <= mb_idle;
                          
                    when others => null;
            
                end case;
        end if;
    end process;
    
    end generate;
    


--i_ila_mb_driver : ila_mb_driver
--PORT MAP (
--	clk => p_clknet_in.osc_clk40,
--	probe0 => p_mb_txword_in, 
--	probe1 => s_rtn_wd(0), 
--	probe2 => s_rtn_wd(1), 
--	probe3 => s_execute, 
--	probe4 => s_bk_ena, 
--	probe5(0) => s_mb_clk(0), 
--	probe6(0) => s_mb_clk(1), 
--	probe7(0) => s_mb_data_out(0), 
--	probe8(0) => s_mb_data_out(1), 
--	probe9(0) => s_mb_exe(0), 
--	probe10(0) => s_mb_exe(1), 
--	probe11(0) => s_rtn_done(0), 
--	probe12(0) => s_rtn_done(1), 
--	probe13(0) => p_master_reset_in, 
--	probe14(0) => s_lrtn_bit(0),
--	probe15(0) => s_lrtn_bit(1),
--	probe16(0) => p_mb_config_trigger_in,
--	probe17(0) => s_idle_out(0),
--	probe18(0) => s_idle_out(1),
--	probe19(31 downto 24) => "00000000",
--	probe19(23 downto 0) => s_command(0),
--	probe20(31 downto 24) => "00000000",
--	probe20(23 downto 0) => s_command(1),
--	probe21 => s_fe_data
--);


end Behavioral;



