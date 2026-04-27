----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/02/2024 03:02:34 PM
-- Design Name: 
-- Module Name: db6_cis_interface_hss_io - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library tilecal;
use tilecal.db6_design_package.all;


entity db6_cis_interface_hss_io is
  Port (
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx; 
        p_master_reset_in       : in  std_logic;
--        p_cis_wordclk_out           : out std_logic;
        p_tph_out               : out t_mb_diff_pair;
        p_tpl_out               : out t_mb_diff_pair;
        p_tph_in               : in t_mb_std_logic;
        p_tpl_in               : in t_mb_std_logic
);
end db6_cis_interface_hss_io;

architecture Behavioral of db6_cis_interface_hss_io is

COMPONENT hss_cis
  PORT (
    vtc_rdy_bsc0 : OUT STD_LOGIC;
    en_vtc_bsc0 : IN STD_LOGIC;
    vtc_rdy_bsc1 : OUT STD_LOGIC;
    en_vtc_bsc1 : IN STD_LOGIC;
    dly_rdy_bsc0 : OUT STD_LOGIC;
    dly_rdy_bsc1 : OUT STD_LOGIC;
    rst_seq_done : OUT STD_LOGIC;
    shared_pll0_clkoutphy_out : OUT STD_LOGIC;
    pll0_clkout0 : OUT STD_LOGIC;
    rst : IN STD_LOGIC;
    clk_p : IN STD_LOGIC;
    clk_n : IN STD_LOGIC;
    riu_clk : IN STD_LOGIC;
    pll0_locked : OUT STD_LOGIC;
    bg0_pin0_0 : OUT STD_LOGIC;
    data_from_fabric_bg0_pin0_0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    bg0_pin1_1 : OUT STD_LOGIC;
    bg0_pin2_2 : OUT STD_LOGIC;
    data_from_fabric_bg0_pin2_2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    bg0_pin3_3 : OUT STD_LOGIC;
    bg0_pin4_4 : OUT STD_LOGIC;
    data_from_fabric_bg0_pin4_4 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    bg0_pin5_5 : OUT STD_LOGIC;
    bg0_pin6_6 : OUT STD_LOGIC;
    data_from_fabric_bg0_pin6_6 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    bg0_pin7_7 : OUT STD_LOGIC 
  );
END COMPONENT;

type t_hss_cis is record
    vtc_rdy_bsc0 : STD_LOGIC;
    en_vtc_bsc0 : STD_LOGIC;
    vtc_rdy_bsc1 : STD_LOGIC;
    en_vtc_bsc1 : STD_LOGIC;
    dly_rdy_bsc0 : STD_LOGIC;
    dly_rdy_bsc1 : STD_LOGIC;
    rst_seq_done : STD_LOGIC;
    shared_pll0_clkoutphy_out : STD_LOGIC;
    pll0_clkout0 : STD_LOGIC; --160mhz @ 1280mbps
    --pll0_clkout1 : STD_LOGIC;
    rst : STD_LOGIC;
    clk_p : STD_LOGIC;
    clk_n : STD_LOGIC;
    riu_clk : STD_LOGIC;
    pll0_locked : STD_LOGIC;
    bg0_pin0_0 : STD_LOGIC; --an14 tpl_q0
    data_from_fabric_bg0_pin0_0 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    bg0_pin1_1 : STD_LOGIC;
    bg0_pin2_2 : STD_LOGIC; --an19 tph_q0
    data_from_fabric_bg0_pin2_2 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    bg0_pin3_3 : STD_LOGIC;
    bg0_pin4_4 : STD_LOGIC; --am17 tpl_q1
    data_from_fabric_bg0_pin4_4 : STD_LOGIC_VECTOR(7 DOWNTO 0);
    bg0_pin5_5 : STD_LOGIC;
    bg0_pin6_6 : STD_LOGIC; --an18 tph_q1
    data_from_fabric_bg0_pin6_6 : STD_LOGIC_VECTOR(7 DOWNTO 0); 
    bg0_pin7_7 : STD_LOGIC;
end record;

signal s_hss_cis : t_hss_cis;
signal s_data_mux : std_logic;

signal s_mb_hss_cis_std_logic_vector_8_tph, s_mb_hss_cis_std_logic_vector_8_tpl : t_mb_hss_cis_std_logic_vector_8;
signal s_mb_hss_cis_std_logic_vector_8_tph_inv, s_mb_hss_cis_std_logic_vector_8_tpl_inv : t_mb_hss_cis_std_logic_vector_8;

constant c_range : integer :=32;
constant c_range_1 : std_logic_vector(c_range-1 downto 0) := (others=>'1');
constant c_range_0 : std_logic_vector(c_range-1 downto 0) := (others=>'0');


signal s_q0_start_shape, s_q0_end_shape, s_q1_start_shape, s_q1_end_shape : std_logic_vector(c_range-1 downto 0);
signal s_q0_phase_config, s_q1_phase_config : integer range 0 to c_range-1;
signal s_tph_q0_shape, s_tph_q1_shape, s_tpl_q0_shape, s_tpl_q1_shape : std_logic_vector(c_range-1 downto 0);

signal s_tph_reg, s_tpl_reg : t_mb_std_logic;



constant c_start_shape : std_logic_vector(2*c_range-1 downto 0) :=  c_range_0 & c_range_1;
constant c_end_shape : std_logic_vector(2*c_range-1 downto 0) :=  c_range_1 & c_range_0;

signal s_cdc_counter : integer range 0 to 3; 
signal s_cdc_phase : std_logic; 
signal s_bcr_cis, s_bcr_buffer_cis : std_logic;
type t_sm_sync is (st_syncying,st_wait,st_synced);
signal s_sm_cis_sync : t_sm_sync := st_syncying;

COMPONENT ila_cis_interface_hs_io

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(7 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(1 DOWNTO 0); 
	probe8 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe9 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe10 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe11 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe14 : IN STD_LOGIC_VECTOR(1 DOWNTO 0)
);
END COMPONENT  ;


COMPONENT vio_cis_interface_hss_io
  PORT (
    clk : IN STD_LOGIC;
    probe_in0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_in9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0) 
  );
END COMPONENT;

--signal s_vio_mux, s_vio_reset : std_logic;

begin

i_hss_cis : hss_cis
  PORT MAP (
    vtc_rdy_bsc0 => s_hss_cis.vtc_rdy_bsc0,
    en_vtc_bsc0 => s_hss_cis.en_vtc_bsc0,
    vtc_rdy_bsc1 => s_hss_cis.vtc_rdy_bsc1,
    en_vtc_bsc1 => s_hss_cis.en_vtc_bsc1,
    dly_rdy_bsc0 => s_hss_cis.dly_rdy_bsc0,
    dly_rdy_bsc1 => s_hss_cis.dly_rdy_bsc1,
    rst_seq_done => s_hss_cis.rst_seq_done,
    shared_pll0_clkoutphy_out => s_hss_cis.shared_pll0_clkoutphy_out,
    pll0_clkout0 => s_hss_cis.pll0_clkout0,
    --pll0_clkout1 => s_hss_cis.pll0_clkout1,
    rst => s_hss_cis.rst,
    clk_p => s_hss_cis.clk_p,
    clk_n => s_hss_cis.clk_n,
    riu_clk => s_hss_cis.riu_clk,
    pll0_locked => s_hss_cis.pll0_locked,
    bg0_pin0_0 => s_hss_cis.bg0_pin0_0,
    data_from_fabric_bg0_pin0_0 => s_hss_cis.data_from_fabric_bg0_pin0_0,
    bg0_pin1_1 => s_hss_cis.bg0_pin1_1,
    bg0_pin2_2 => s_hss_cis.bg0_pin2_2,
    data_from_fabric_bg0_pin2_2 => s_hss_cis.data_from_fabric_bg0_pin2_2,
    bg0_pin3_3 => s_hss_cis.bg0_pin3_3,
    bg0_pin4_4 => s_hss_cis.bg0_pin4_4,
    data_from_fabric_bg0_pin4_4 => s_hss_cis.data_from_fabric_bg0_pin4_4,
    bg0_pin5_5 => s_hss_cis.bg0_pin5_5,
    bg0_pin6_6 => s_hss_cis.bg0_pin6_6,
    data_from_fabric_bg0_pin6_6 => s_hss_cis.data_from_fabric_bg0_pin6_6,
    bg0_pin7_7 => s_hss_cis.bg0_pin7_7
  );
  
  s_hss_cis.clk_p <= p_clknet_in.cis_hss_clk80.p;
  s_hss_cis.clk_n <= p_clknet_in.cis_hss_clk80.n;
  
  s_hss_cis.riu_clk <= p_clknet_in.cfgbus_clk40;
  
--  p_cis_wordclk_out <= s_hss_cis.pll0_clkout0;
  
--  s_hss_cis.data_from_fabric_bg0_pin0_0 <= p_tpl_in.q0;
--  s_hss_cis.data_from_fabric_bg0_pin2_2 <= p_tph_in.q0;
--  s_hss_cis.data_from_fabric_bg0_pin4_4 <= p_tpl_in.q1;
--  s_hss_cis.data_from_fabric_bg0_pin6_6 <= p_tph_in.q1;
  
  
  p_tpl_out.q0.p <= s_hss_cis.bg0_pin0_0;
  p_tpl_out.q0.n <= s_hss_cis.bg0_pin1_1;

  p_tph_out.q0.p <= s_hss_cis.bg0_pin2_2;
  p_tph_out.q0.n <= s_hss_cis.bg0_pin3_3;

  p_tpl_out.q1.p <= s_hss_cis.bg0_pin4_4;
  p_tpl_out.q1.n <= s_hss_cis.bg0_pin5_5;
  
  p_tph_out.q1.p <= s_hss_cis.bg0_pin6_6;
  p_tph_out.q1.n <= s_hss_cis.bg0_pin7_7;
  
  proc_mux : process(s_data_mux) --, s_vio_mux)
  begin
    if s_data_mux = '0' then
      s_hss_cis.data_from_fabric_bg0_pin0_0 <= (others=> '0');
      s_hss_cis.data_from_fabric_bg0_pin2_2 <= (others=> '0');
      s_hss_cis.data_from_fabric_bg0_pin4_4 <= (others=> '0');
      s_hss_cis.data_from_fabric_bg0_pin6_6 <= (others=> '0');
    else
--        if s_vio_mux = '0' then 
          s_hss_cis.data_from_fabric_bg0_pin0_0 <= s_mb_hss_cis_std_logic_vector_8_tpl_inv.q0;
          s_hss_cis.data_from_fabric_bg0_pin2_2 <= s_mb_hss_cis_std_logic_vector_8_tph_inv.q0;
          s_hss_cis.data_from_fabric_bg0_pin4_4 <= s_mb_hss_cis_std_logic_vector_8_tpl_inv.q1;
          s_hss_cis.data_from_fabric_bg0_pin6_6 <= s_mb_hss_cis_std_logic_vector_8_tph_inv.q1;
--        else
--          s_hss_cis.data_from_fabric_bg0_pin0_0 <= s_mb_hss_cis_std_logic_vector_8_tpl.q0;
--          s_hss_cis.data_from_fabric_bg0_pin2_2 <= s_mb_hss_cis_std_logic_vector_8_tph.q0;
--          s_hss_cis.data_from_fabric_bg0_pin4_4 <= s_mb_hss_cis_std_logic_vector_8_tpl.q1;
--          s_hss_cis.data_from_fabric_bg0_pin6_6 <= s_mb_hss_cis_std_logic_vector_8_tph.q1;        
--        end if;
    end if;
  end process;
  
  
  gen_inv : for i in 0 to 7 generate
    s_mb_hss_cis_std_logic_vector_8_tpl_inv.q0(i)<=s_mb_hss_cis_std_logic_vector_8_tpl.q0(7-i);
    s_mb_hss_cis_std_logic_vector_8_tpl_inv.q1(i)<=s_mb_hss_cis_std_logic_vector_8_tpl.q1(7-i);
    s_mb_hss_cis_std_logic_vector_8_tph_inv.q0(i)<=s_mb_hss_cis_std_logic_vector_8_tph.q0(7-i);
    s_mb_hss_cis_std_logic_vector_8_tph_inv.q1(i)<=s_mb_hss_cis_std_logic_vector_8_tph.q1(7-i);
  end generate;
  
  proc_resec : process(p_clknet_in.cfgbus_clk40, p_master_reset_in)
  begin
    if (p_master_reset_in = '1') then
        s_hss_cis.rst<='1';
        s_data_mux <='0';
    elsif rising_edge(p_clknet_in.cfgbus_clk40) then
        s_hss_cis.rst<='0';-- or s_vio_reset;
        s_hss_cis.en_vtc_bsc0<='1';
        s_hss_cis.en_vtc_bsc1<='1';
        s_data_mux <= s_hss_cis.pll0_locked and s_hss_cis.rst_seq_done;
    end if;
  end process;
  
 proc_cis_cdc_gen : process(s_hss_cis.pll0_clkout0, p_master_reset_in)
begin
    if (p_master_reset_in = '1') then
        s_cdc_counter <= 0;
        s_cdc_phase <= '0';
        s_sm_cis_sync <= st_syncying;
    elsif rising_edge(s_hss_cis.pll0_clkout0) then
            
            case s_sm_cis_sync is
                when st_syncying =>
                    if (p_clknet_in.bcr.bcr_locked = '1') then
                        s_cdc_counter <= 0;
                        s_cdc_phase <= '0';
                        s_sm_cis_sync <= st_wait;
                    end if;
                when st_wait =>
                    s_bcr_cis<=p_clknet_in.bcr.bcr;
                    if (p_clknet_in.bcr.bcr = '1') and (s_bcr_cis ='0') then
                        s_sm_cis_sync <= st_synced;
                        s_cdc_counter <= 3;
                    end if;
                when st_synced =>
                    if (p_clknet_in.bcr.bcr_locked = '1') then
                        case s_cdc_counter is
                            when 0 =>
                                s_cdc_counter <= 1;
                                s_cdc_phase <= '1';
                            when 1 =>
                                s_cdc_counter <= 2;
                                s_cdc_phase <= '1';
                            when 2 =>
                                s_cdc_counter <= 3;
                                s_cdc_phase <= '0';
                            when 3 =>
                                s_cdc_counter <= 0;
                                s_cdc_phase <= '0';
                            when others =>
                                null;
                        end case;
                    else
                        s_sm_cis_sync <= st_syncying;
                    end if;

                when others =>
                    s_sm_cis_sync <= st_syncying;
            end case;
    end if;
end process;

 
 proc_shift_iddr_data: process(s_hss_cis.pll0_clkout0)
    type t_sm_iddr_data_sync is (st_wait, st_sync);
    variable v_tph_q0_mon, v_tph_q1_mon, v_tpl_q0_mon, v_tpl_q1_mon : std_logic_vector(1 downto 0);
    begin
            
        if rising_edge(s_hss_cis.pll0_clkout0) then
--            s_cis_cdc_counter_debug<=std_logic_vector(to_unsigned(p_clknet_in.cis_cdc_counter, 4));
            s_mb_hss_cis_std_logic_vector_8_tph.q0<=s_tph_q0_shape(c_range-1-(8*s_cdc_counter) downto c_range-1-(8*s_cdc_counter+7));
            s_mb_hss_cis_std_logic_vector_8_tph.q1<=s_tph_q1_shape(c_range-1-(8*s_cdc_counter) downto c_range-1-(8*s_cdc_counter+7));
            s_mb_hss_cis_std_logic_vector_8_tpl.q0<=s_tpl_q0_shape(c_range-1-(8*s_cdc_counter) downto c_range-1-(8*s_cdc_counter+7));
            s_mb_hss_cis_std_logic_vector_8_tpl.q1<=s_tpl_q1_shape(c_range-1-(8*s_cdc_counter) downto c_range-1-(8*s_cdc_counter+7));
            
            if s_cdc_counter=3 then
                s_tph_reg <= p_tph_in;
                s_tpl_reg <= p_tpl_in;
                
                v_tph_q0_mon:= s_tph_reg.q0 & p_tph_in.q0;
                v_tph_q1_mon:= s_tph_reg.q1 & p_tph_in.q1;
                v_tpl_q0_mon:= s_tpl_reg.q0 & p_tpl_in.q0;
                v_tpl_q1_mon:= s_tpl_reg.q1 & p_tpl_in.q1;

--                s_tph_q0_mon <= v_tph_q0_mon;
--                s_tph_q1_mon <= v_tph_q1_mon;
--                s_tpl_q0_mon <= v_tpl_q0_mon;
--                s_tpl_q1_mon <= v_tpl_q1_mon;
               
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
                        null;
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
                        null;
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
                        null;
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
                        null;
                end case;
                                                                
            end if;
        end if;
    end process;
    
    
    s_q0_phase_config<=to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(11 downto 7)));--(11 downto 6)));--to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(11 downto 7)));
    s_q0_start_shape<= c_start_shape(c_range-1 + s_q0_phase_config downto 0 + s_q0_phase_config);--c_start_shape(31 + 2*s_q0_phase_config downto 0 + 2*s_q0_phase_config);
    s_q0_end_shape<= c_end_shape(c_range-1 + s_q0_phase_config downto 0 + s_q0_phase_config);--c_end_shape(31 + 2*s_q0_phase_config downto 0 + 2*s_q0_phase_config);

    s_q1_phase_config<=to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(27 downto 23)));--(27 downto 22)));--to_integer(unsigned(p_db_reg_rx_in(cfb_mb_phase_config)(27 downto 23)));
    s_q1_start_shape<= c_start_shape(c_range-1 + s_q1_phase_config downto 0 + s_q1_phase_config);--c_start_shape(31 + 2*s_q1_phase_config downto 0 + 2*s_q1_phase_config);
    s_q1_end_shape<= c_end_shape(c_range-1 + s_q1_phase_config downto 0 + s_q1_phase_config);--c_end_shape(31 + 2*s_q1_phase_config downto 0 + 2*s_q1_phase_config);


--    i_ila_cis_interface_hs_io : ila_cis_interface_hs_io
--    PORT MAP (
--        clk => s_hss_cis.pll0_clkout0,
    
--        probe0 => s_mb_hss_cis_std_logic_vector_8_tph.q0, 
--        probe1 => s_mb_hss_cis_std_logic_vector_8_tph.q0, 
--        probe2 => s_mb_hss_cis_std_logic_vector_8_tpl.q1, 
--        probe3 => s_mb_hss_cis_std_logic_vector_8_tpl.q1, 
--        probe4 => s_tph_reg.q0 & p_tph_in.q0, 
--        probe5 => s_tph_reg.q0 & p_tph_in.q0,
--        probe6 => s_tpl_reg.q1 & p_tpl_in.q1, 
--        probe7 => s_tpl_reg.q1 & p_tpl_in.q1,
--        probe8 => s_q0_start_shape, 
--        probe9 => s_q0_end_shape, 
--        probe10 => s_q1_start_shape, 
--        probe11 => s_q1_end_shape, 
--        probe12(0) => s_cdc_phase,
--        probe13(0) => p_clknet_in.bcr.bcr,
--        probe14 => std_logic_vector(to_unsigned(s_cdc_counter,2))
--    );
    
--  i_vio_cis_interface_hss_io : vio_cis_interface_hss_io
--  PORT MAP (
--    clk => p_clknet_in.cfgbus_clk40,
--    probe_in0(0) => s_hss_cis.vtc_rdy_bsc0,
--    probe_in1(0) => s_hss_cis.en_vtc_bsc0,
--    probe_in2(0) => s_hss_cis.vtc_rdy_bsc1,
--    probe_in3(0) => s_hss_cis.en_vtc_bsc1,
--    probe_in4(0) => s_hss_cis.dly_rdy_bsc0,
--    probe_in5(0) => s_hss_cis.dly_rdy_bsc1,
--    probe_in6(0) => s_hss_cis.rst_seq_done,
--    probe_in7(0) => s_hss_cis.rst,
--    probe_in8(0) => s_hss_cis.pll0_locked,
--    probe_in9(0) => s_vio_mux,
--    probe_out0(0) => s_vio_mux,
--    probe_out1(0) => s_vio_reset
--  );
  

  
end Behavioral;
