----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.01.2023 17:07:26
-- Design Name: 
-- Module Name: db6_gbt_encoder_sc - Behavioral
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

entity db6_gbt_encoder_sc is
  generic (
  -- hog
        GLOBAL_DATE : std_logic_vector(31 downto 0); -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_TIME : std_logic_vector(31 downto 0); -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
        GLOBAL_VER : std_logic_vector(31 downto 0); -- 32 bit Last version Tag when the project was modified. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        GLOBAL_SHA : std_logic_vector(31 downto 0); -- 32 bit Git hash (SHA) of the last commit when the project was modified.
        TOP_VER : std_logic_vector(31 downto 0); -- 32 bit Top directory version, containing the hog.conf file and other files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        TOP_SHA : std_logic_vector(31 downto 0); -- 32 bit Top directory version, containing the hog.conf file and other files.
        CON_VER : std_logic_vector(31 downto 0); -- 32 bit The version of the constraint files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        CON_SHA : std_logic_vector(31 downto 0); -- 32 bit The git commit hash (SHA) of the constraint files.
        HOG_VER : std_logic_vector(31 downto 0); -- 32 bit Hog submodule version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        HOG_SHA : std_logic_vector(31 downto 0) -- 32 bit Hog submodule git commit hash (SHA).
--        XML_VER : std_logic_vector(31 downto 0); -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        XML_SHA : std_logic_vector(31 downto 0) -- 32 bit (optional) IPbus xml git commit hash (SHA).
  );
  port (
        p_master_reset_in : std_logic;
		p_clknet_in : in t_db_clknet;
        p_db_reg_rx_in : in t_db_reg_rx;
		
		--interfaces
		p_mb_interface_in : in t_mb_interface;
		p_sem_interface_in : in t_sem_interface;
		p_system_management_interface_in : in t_system_management_interface;
		p_gbtx_interface_in : in t_gbtx_interface;
		p_serial_id_interface_in : in t_serial_id_interface;
		p_sfp_ku_mgt_in                     : in t_ku_mgt;
		p_db6_sem_interface_in : in t_db6_sem_interface;
		p_cfgbus_interface_in : in t_cfgbus_interface;
		p_sfp_interface_in : in t_sfp_interface;
--        p_sc_address_out     : out std_logic_vector(15 downto 0);
--        p_sc_data_out        : out std_logic_vector(31 downto 0);
        p_sc_switch_out      : out t_sc_switch;
        p_sc_tx_out          : out t_sc_tx
        
		);
end db6_gbt_encoder_sc;

architecture Behavioral of db6_gbt_encoder_sc is

--    constant c_pipeline_depth : integer := c_global_pipeline_depth;
--    type t_db_reg_tx_pipeline is array (0 to c_pipeline_depth-1) of t_db_reg_tx;
--    type t_db_reg_rx_pipeline is array (0 to c_pipeline_depth-1) of t_db_reg_rx;
--    signal s_db_reg_tx_pipeline : t_db_reg_tx_pipeline;
--    signal s_db_reg_rx_pipeline : t_db_reg_rx_pipeline;

    signal s_sc_address          	    : integer range 0 to c_number_of_cfgbus_regs + c_number_of_gbttx_regs; --std_logic_vector(15 downto 0):=(others=>'0');
    signal s_db_reg_tx_in      	: t_db_reg_tx;
    signal s_db_reg_rx_in      	: t_db_reg_rx;
    signal s_xadc_channel, s_xadc_channel_buffer : integer range 0 to 32 := 0;
    
    type t_sm_sync is (st_syncying,st_wait,st_synced);
    signal s_sm_data_sync, s_sm_tx_sync : t_sm_sync := st_syncying;
    
    type t_db_reg_trx is (st_db_reg_tx,st_db_reg_rx,st_db_xadc_tx);
    signal s_db_reg_trx : t_db_reg_trx :=st_db_reg_tx;
    
    type t_sm_write_state is (st_data,st_address);
    signal s_sm_write_state : t_sm_write_state := st_data;
    
    --signal s_gbt_encoder_interface : t_gbt_encoder_interface;
    signal s_bcr_buffer_clk80, s_bcr_buffer_clk40, s_bcr_locked_buffer, s_phase : std_logic :='0';
    
    signal s_sc_address_tx, s_sc_address_out         : std_logic_vector(15 downto 0);
    signal s_sc_data_tx, s_sc_data_out         : std_logic_vector(31 downto 0);
    signal s_sc_reg_tx_data_buffer         : std_logic_vector(31 downto 0);
    signal s_sc_switch_out       :  t_sc_switch;
    signal s_sc_tx_out           :t_sc_tx;
	signal s_sending : std_logic;
    signal s_tx_counter : integer range 0 to 4095;
    COMPONENT xadc_blk_mem
      PORT (
        clka : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--        douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        clkb : IN STD_LOGIC;
--        web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addrb : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
--        dinb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) 
          );
    END COMPONENT;
    signal s_blk_mem_gbt_sc : t_blk_mem_gbt_sc;
    
    signal s_xadc_channel_voltage : std_logic_vector(15 downto 0);
    signal s_xadc_channel_voltage_debug : std_logic_vector(15 downto 0);
    
    COMPONENT blk_mem_gbt_sc
      PORT (
        clka : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        clkb : IN STD_LOGIC;
        web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        dinb : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        doutb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0) 
      );
    END COMPONENT;
    --debug
    
    COMPONENT ila_xadc_encoder_sc

    PORT (
        clk : IN STD_LOGIC;
    
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe1 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
        probe2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe3 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
        probe5 : IN STD_LOGIC_VECTOR(4 DOWNTO 0); 
        probe6 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe7 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
        probe8 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe9 : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT  ;

COMPONENT ila_blk_mem_gbt_sc

PORT (
	clk : IN STD_LOGIC;



	probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0); 
	probe5 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe6 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe7 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe8 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe9 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe10 : IN STD_LOGIC_VECTOR(3 DOWNTO 0); 
	probe11 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe12 : IN STD_LOGIC_VECTOR(15 DOWNTO 0); 
	probe13 : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
	probe14 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
	probe15 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
);
END COMPONENT  ;


    signal s_adc_counter : integer range 0 to 5 :=0;
begin

--outputs
--p_sc_address_out <= s_sc_address_out;
--p_sc_data_out <= s_sc_data_out;
p_sc_switch_out <= s_sc_switch_out;
p_sc_tx_out <= s_sc_tx_out;

s_db_reg_rx_in <= p_db_reg_rx_in;

-- register connections
s_db_reg_tx_in(stb_mb) <= p_mb_interface_in.mb_driver.rxword_out.q1(15 downto 0) & p_mb_interface_in.mb_driver.rxword_out.q0(15 downto 0);
s_db_reg_tx_in(stb_mb_q0) <= "00" & p_mb_interface_in.mb_driver.txword_in(23 downto 12) & p_mb_interface_in.mb_driver.rxword_out.q0;
s_db_reg_tx_in(stb_mb_q1) <= "00" & p_mb_interface_in.mb_driver.txword_in(23 downto 12) & p_mb_interface_in.mb_driver.rxword_out.q1;
s_db_reg_tx_in(stb_mb_jtag_id_q0) <= p_mb_interface_in.mb_jtag_id.q0;
s_db_reg_tx_in(stb_mb_jtag_id_q1) <= p_mb_interface_in.mb_jtag_id.q1;
-- sfp+ reg block ram port b readback: echo the commanded address alongside the value
-- so the far end can confirm which byte it's looking at (see cfb_sfp_reg_address)
s_db_reg_tx_in(stb_sfp_reg_readback)(6 downto 0)   <= s_db_reg_rx_in(cfb_sfp_reg_address)(6 downto 0);
s_db_reg_tx_in(stb_sfp_reg_readback)(7)            <= '0';
s_db_reg_tx_in(stb_sfp_reg_readback)(14 downto 8)  <= s_db_reg_rx_in(cfb_sfp_reg_address)(14 downto 8);
s_db_reg_tx_in(stb_sfp_reg_readback)(15)           <= '0';
s_db_reg_tx_in(stb_sfp_reg_readback)(23 downto 16) <= p_sfp_ku_mgt_in.sfp_tx_register(0);
s_db_reg_tx_in(stb_sfp_reg_readback)(31 downto 24) <= p_sfp_ku_mgt_in.sfp_tx_register(1);
--s_db_reg_tx_in(stb_db_cfbstrobe) <= s_db_reg_rx_in(cfb_strobe_reg);
s_db_reg_tx_in(stb_db_debug) <= s_db_reg_rx_in(cfb_db_debug);
s_db_reg_tx_in(stb_db_fwversion) <= c_fw_version;-- x"EDEDEDED";
s_db_reg_tx_in(stb_pgood_reg)(c_number_of_pgood_channels downto 0) <= p_system_management_interface_in.p_good;
s_db_reg_tx_in(stb_pgood_reg)(31 downto 28) <= p_clknet_in.md_number;
s_db_reg_tx_in(stb_pgood_reg)(27) <= p_clknet_in.db_side(0);
s_db_reg_tx_in(stb_loopback) <= s_db_reg_rx_in(cfb_loopback);


s_db_reg_tx_in(stb_dna_2) <=p_system_management_interface_in.ku_dna(31+32+32 downto 32+32);
s_db_reg_tx_in(stb_dna_1) <=p_system_management_interface_in.ku_dna(31+32 downto 32);
s_db_reg_tx_in(stb_dna_0) <=p_system_management_interface_in.ku_dna(31 downto 0);


s_db_reg_tx_in(stb_sfp0_reg)(c_sfp_status_mod_los_bit) <= p_sfp_interface_in.mod_los(0);
s_db_reg_tx_in(stb_sfp1_reg)(c_sfp_status_mod_los_bit) <= p_sfp_interface_in.mod_los(1);
s_db_reg_tx_in(stb_sfp0_reg)(c_sfp_status_mod_abs_bit) <= p_sfp_interface_in.mod_abs(0);
s_db_reg_tx_in(stb_sfp1_reg)(c_sfp_status_mod_abs_bit) <= p_sfp_interface_in.mod_abs(1);
s_db_reg_tx_in(stb_sfp0_reg)(c_sfp_status_tx_fault_bit) <= p_sfp_interface_in.tx_fault(0);
s_db_reg_tx_in(stb_sfp1_reg)(c_sfp_status_tx_fault_bit) <= p_sfp_interface_in.tx_fault(1);


s_db_reg_tx_in(stb_db_status)(c_db_status_bcr_locked_bit) <= p_clknet_in.bcr.bcr_locked;

s_db_reg_tx_in(stb_adc_readout_status)(c_adc_config_done_bit) <= p_mb_interface_in.adc_readout_control.adc_config_done;
gen_adc_channels: for v_adc in 0 to 5 generate 
    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_status_adc_missalignment_bit(v_adc)) <= p_mb_interface_in.adc_readout.channel_frame_missalignemt(v_adc);
    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_status_adc_channel_missed_locked_bit(v_adc)) <= p_mb_interface_in.adc_readout.channel_missed_locked(v_adc);
    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_status_adc_channel_locked_bit(v_adc)) <= p_mb_interface_in.adc_readout.channel_locked(v_adc);
    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_channel_phase_offset_bit(v_adc)) <= p_mb_interface_in.adc_readout.channel_phase_offset(v_adc);
    
    
--    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_status_adc1_missalignment_bit) <= p_mb_interface_in.adc_readout.channel_frame_missalignemt(1);
--    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_status_adc2_missalignment_bit) <= p_mb_interface_in.adc_readout.channel_frame_missalignemt(2);
--    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_status_adc3_missalignment_bit) <= p_mb_interface_in.adc_readout.channel_frame_missalignemt(3);
--    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_status_adc4_missalignment_bit) <= p_mb_interface_in.adc_readout.channel_frame_missalignemt(4);
--    s_db_reg_tx_in(stb_adc_readout_status)(c_adc_readout_status_adc5_missalignment_bit) <= p_mb_interface_in.adc_readout.channel_frame_missalignemt(5);

    --s_db_reg_tx_in(stb_adc_readout_status)(31-(4*0) downto 31-3-(4*0)) <= p_mb_interface_in.adc_readout.channel_cdc_align_counter(5);
    --s_db_reg_tx_in(stb_adc_readout_status)(31-(4*1) downto 31-3-(4*1)) <= p_mb_interface_in.adc_readout.channel_cdc_align_counter(4);
    --s_db_reg_tx_in(stb_adc_readout_status)(31-(4*2) downto 31-3-(4*2)) <= p_mb_interface_in.adc_readout.channel_cdc_align_counter(3);
    --s_db_reg_tx_in(stb_adc_readout_status)(31-(4*3) downto 31-3-(4*3)) <= p_mb_interface_in.adc_readout.channel_cdc_align_counter(2);
    --s_db_reg_tx_in(stb_adc_readout_status)(31-(4*4) downto 31-3-(4*4)) <= p_mb_interface_in.adc_readout.channel_cdc_align_counter(1);
    --s_db_reg_tx_in(stb_adc_readout_status)(31-(4*5) downto 31-3-(4*5)) <= p_mb_interface_in.adc_readout.channel_cdc_align_counter(0);
end generate;

    s_db_reg_tx_in(stb_running_time_status)<=p_clknet_in.running_time;
    s_db_reg_tx_in(stb_db_status)(c_db_status_mb_tx_collission_q0_bit) <= p_mb_interface_in.mb_driver.mb_tx_collission_out.q0;
    s_db_reg_tx_in(stb_db_status)(c_db_status_mb_tx_collission_q1_bit) <= p_mb_interface_in.mb_driver.mb_tx_collission_out.q1;
    s_db_reg_tx_in(stb_db_status)(c_db_status_md_number_bit_msb downto c_db_status_md_number_bit_lsb) <= p_clknet_in.md_number;
    s_db_reg_tx_in(stb_db_status)(c_db_status_db_leds_bit_msb downto c_db_status_db_leds_bit_lsb) <= p_clknet_in.db_leds;
    s_db_reg_tx_in(stb_integrator_status)(c_db_status_mb_integrator_latency_bit_msb  downto c_db_status_mb_integrator_latency_bit_lsb) <= p_mb_interface_in.mb_integrator.bc_count_readout;
    
--s_db_reg_tx_in(stb_cis_config)    	<= s_db_reg_rx_in(cfb_cis_config); --(others=> '0'); --s_db_cis_config_reg;

--proc_sem_clock_domain_cross : process(p_clknet_in.refclk40)
--begin
--    if rising_edge(p_clknet_in.refclk40) then
        
    s_db_reg_tx_in(stb_sem)(c_sem_status_heartbeat_bit) <= p_db6_sem_interface_in.sem_interface.status_heartbeat;
    s_db_reg_tx_in(stb_sem)(c_sem_status_initialization_bit) <= p_db6_sem_interface_in.sem_interface.status_initialization;
    s_db_reg_tx_in(stb_sem)(c_sem_status_observation_bit) <= p_db6_sem_interface_in.sem_interface.status_observation;
    s_db_reg_tx_in(stb_sem)(c_sem_status_correction_bit) <= p_db6_sem_interface_in.sem_interface.status_correction;
    s_db_reg_tx_in(stb_sem)(c_sem_status_classification_bit) <= p_db6_sem_interface_in.sem_interface.status_classification;
    s_db_reg_tx_in(stb_sem)(c_sem_status_injection_bit) <= p_db6_sem_interface_in.sem_interface.status_injection;
    s_db_reg_tx_in(stb_sem)(c_sem_status_essential_bit) <= p_db6_sem_interface_in.sem_interface.status_essential;
    s_db_reg_tx_in(stb_sem)(c_sem_status_detect_only_bit) <= p_db6_sem_interface_in.sem_interface.status_detect_only;
    s_db_reg_tx_in(stb_sem)(c_sem_command_busy_bit) <= p_db6_sem_interface_in.sem_interface.command_busy;
    s_db_reg_tx_in(stb_sem)(c_sem_monitor_txfull_bit) <= p_db6_sem_interface_in.sem_interface.monitor_txfull;
    s_db_reg_tx_in(stb_sem)(c_sem_status_uncorrectable_bit) <= p_db6_sem_interface_in.sem_interface.status_uncorrectable;
    s_db_reg_tx_in(stb_sem)(c_sem_status_diagnostic_scan_bit) <= p_db6_sem_interface_in.sem_interface.status_diagnostic_scan;
    s_db_reg_tx_in(stb_sem)(c_sem_status_command_strobe_bit) <= p_db6_sem_interface_in.sem_interface.command_strobe;
    s_db_reg_tx_in(stb_sem)(c_sem_status_cap_gnt_bit) <= p_db6_sem_interface_in.sem_interface.cap_gnt;
    s_db_reg_tx_in(stb_sem)(c_sem_status_cap_rel_bit) <= p_db6_sem_interface_in.sem_interface.cap_rel;
    s_db_reg_tx_in(stb_sem)(c_sem_status_cap_req_bit) <= p_db6_sem_interface_in.sem_interface.cap_req;                

    s_db_reg_tx_in(stb_sem)(31 downto 16) <= p_db6_sem_interface_in.sem_interpreter.correctable_errors(15 downto 0);

    s_db_reg_tx_in(stb_tmr)(15 downto 0) <= p_cfgbus_interface_in.tmr_error_local(15 downto 0);
    s_db_reg_tx_in(stb_tmr)(21 downto 16) <= p_mb_interface_in.adc_readout.tmr_error;
    s_db_reg_tx_in(stb_tmr)(22) <= p_mb_interface_in.cis_interface.tmr_error_tpl.q0;
    s_db_reg_tx_in(stb_tmr)(23) <= p_mb_interface_in.cis_interface.tmr_error_tpl.q1;
    s_db_reg_tx_in(stb_tmr)(24) <= p_mb_interface_in.cis_interface.tmr_error_tph.q0;
    s_db_reg_tx_in(stb_tmr)(25) <= p_mb_interface_in.cis_interface.tmr_error_tph.q1;
    
    s_db_reg_tx_in(stb_tmr)(28) <= p_mb_interface_in.adc_readout.tmr_enabled;
    s_db_reg_tx_in(stb_tmr)(29) <= p_mb_interface_in.cis_interface.tmr_enabled;
    s_db_reg_tx_in(stb_tmr)(31) <= p_cfgbus_interface_in.tmr_enabled;    
--        s_db_reg_tx_in(stb_db_sem_icap) <= p_db6_sem_interface_in.sem_interface.icap_out;
        
--    end if;
--end process;

        -- hog
        s_db_reg_tx_in(stb_GLOBAL_DATE) <= GLOBAL_DATE; -- 32 bit Date of last commit when the project was modified. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
        s_db_reg_tx_in(stb_GLOBAL_TIME) <= GLOBAL_TIME; -- 32 bit Time of last commit when the project was modified. Format: 00HHMMSS (hex with decimal digits, no digit greater than 9 is used)
        s_db_reg_tx_in(stb_GLOBAL_VER) <= GLOBAL_VER;  -- 32 bit Last version Tag when the project was modified. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        s_db_reg_tx_in(stb_GLOBAL_SHA) <= GLOBAL_SHA;  -- 32 bit Git hash (SHA) of the last commit when the project was modified.
        s_db_reg_tx_in(stb_TOP_VER) <= TOP_VER; -- 32 bit Top directory version, containing the hog.conf file and other files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        s_db_reg_tx_in(stb_TOP_SHA) <= TOP_SHA; -- 32 bit Top directory version, containing the hog.conf file and other files.
        s_db_reg_tx_in(stb_CON_VER) <= CON_VER; -- 32 bit The version of the constraint files. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        s_db_reg_tx_in(stb_CON_SHA) <= CON_SHA; -- 32 bit The git commit hash (SHA) of the constraint files.
        s_db_reg_tx_in(stb_HOG_VER) <= HOG_VER; -- 32 bit Hog submodule version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
        s_db_reg_tx_in(stb_HOG_SHA) <= HOG_SHA; -- 32 bit Hog submodule git commit hash (SHA).
--        s_db_reg_tx_in(stb_XML_VER) <= XML_VER; -- 32 bit (optional) IPbus xml version. The version of the form m.M.p is encoded in hexadecimal as MMmmpppp
--        s_db_reg_tx_in(stb_XML_SHA) <= XML_SHA; -- 32 bit (optional) IPbus xml git commit hash (SHA).

    proc_sync : process(p_clknet_in.cfgbus_clk40)
    begin
        if rising_edge(p_clknet_in.cfgbus_clk40) then
            s_bcr_buffer_clk40<=p_clknet_in.bcr.bcr;
            --sending tx flag
            
            if (s_bcr_buffer_clk40 = '0') and (p_clknet_in.bcr.bcr = '1') and (p_clknet_in.bcr.bcr_locked = '1') then
                s_sending 	 <= '0';
            else
                s_sending <= not s_sending;
            end if;
        end if;
    end process;

    proc_control_sc_data : process(p_clknet_in.cfgbus_clk40,p_master_reset_in, p_clknet_in.locked_db, p_sfp_ku_mgt_in.gtwiz_reset_tx_done_out, s_db_reg_rx_in(cfb_strobe_reg)(c_gbt_encoder_reset_bit))--process(p_clknet_in.refclk40)
        variable v_mb0_tube          : std_logic_vector(1 downto 0);
        variable v_mb0_command       : std_logic_vector(3 downto 0);
        variable v_mb1_tube          : std_logic_vector(1 downto 0);
        variable v_mb1_command       : std_logic_vector(3 downto 0);
        constant c_mb0_fpga          : std_logic   := '0';
        constant c_mb1_fpga          : std_logic   := '1';
        variable v_pmtaddr           : std_logic_vector(3 downto 0);
        variable v_cis_t_cmd	     : std_logic;
        variable v_pmtaddr_to_integer : std_logic_vector(3 downto 0) := x"0";	
        
        --xadc
        --variable v_xadc_channel : integer range 0 to c_n_db_xadc_channels -1 := 0;
        
        --proc_sc_manager
        type t_sm_write_state is (st_writing,st_idle);
        variable v_sm_write_state : t_sm_write_state := st_idle;
        --variable v_bcr, v_bcr_buffer : std_logic :='0';
        begin
            if (p_master_reset_in = '1') or (p_clknet_in.locked_db = '0') or (p_sfp_ku_mgt_in.gtwiz_reset_tx_done_out = "0") or (s_db_reg_rx_in(cfb_strobe_reg)(c_gbt_encoder_reset_bit) = '1')then
                s_sc_address <= 0;
                --s_sending <= '0';
                s_sc_address_out <= (others=> '0');            
            elsif rising_edge(p_clknet_in.cfgbus_clk40) then--(p_clknet_in.refclk40) then
--                s_blk_mem_gbt_sc.addra<=s_sc_address_out;
--                s_blk_mem_gbt_sc.dina<=s_sc_data_out;
                --encode data
                if (s_sending = '1') then
                    
                    if p_mb_interface_in.mb_driver.rx_done_out.q0 = '1' then
--                        s_debug_tx_state <= "0001";
--                        v_cis_t_cmd			:= (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q0)(29));
--                        v_mb0_tube          	:= (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q0)(17 downto 16)); -- this register is shifted
--                        v_mb0_command       	:= (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q0)(15 downto 12));

                        v_cis_t_cmd			:= (s_db_reg_tx_in(stb_mb_q0)(29));
                        v_mb0_tube          	:= (s_db_reg_tx_in(stb_mb_q0)(17 downto 16)); -- this register is shifted
                        v_mb0_command       	:= (s_db_reg_tx_in(stb_mb_q0)(15 downto 12));
                        v_pmtaddr_to_integer := (p_clknet_in.db_side(0) & (c_mb0_fpga) & (v_mb0_tube));
                        v_pmtaddr            	:= c_mb_to_pmt_addr(to_integer(unsigned(v_pmtaddr_to_integer)));
                        s_sc_data_out <= 
                                                        x"000" & 
                                                        p_clknet_in.db_side(0) & 
                                                        c_mb0_fpga &  
                                                        --(s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q0)(17 downto 0));
                                                        (s_db_reg_tx_in(stb_mb_q0)(17 downto 0));
                        s_sc_address_out <= 
                                                        x"0" & 
                                                        "000" & 
                                                        v_cis_t_cmd & 
                                                        v_pmtaddr & 
                                                        c_mb_to_ppr(to_integer(unsigned((v_mb0_command))));
                    elsif p_mb_interface_in.mb_driver.rx_done_out.q1 = '1' then
--                        s_debug_tx_state <= "0010";
--                        v_cis_t_cmd			:= (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q1)(29));
--                        v_mb1_tube          	:= (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q1)(17 downto 16));
--                        v_mb1_command       	:= (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q1)(15 downto 12));

                        v_cis_t_cmd			:= (s_db_reg_tx_in(stb_mb_q1)(29));
                        v_mb1_tube          	:= (s_db_reg_tx_in(stb_mb_q1)(17 downto 16));
                        v_mb1_command       	:= (s_db_reg_tx_in(stb_mb_q1)(15 downto 12));
                        v_pmtaddr_to_integer    := ((p_clknet_in.db_side(0)) & (c_mb1_fpga) & (v_mb1_tube));
                        v_pmtaddr           	:= c_mb_to_pmt_addr(to_integer(unsigned(v_pmtaddr_to_integer)));
                        s_sc_data_out <= 
                                                        x"000" & 
                                                        p_clknet_in.db_side(0) & 
                                                        c_mb1_fpga & 
--                                                        (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q1)(17 downto 0));
                                                        (s_db_reg_tx_in(stb_mb_q1)(17 downto 0));
                                                        
                        s_sc_address_out <= 
                                                        x"0" & 
                                                        "000" & 
                                                        v_cis_t_cmd & 
                                                        v_pmtaddr & 
                                                        c_mb_to_ppr(to_integer(unsigned((v_mb1_command))));				
        
                    else
                 --###########################################--
                 --## continous write of register contents  ##--
                 --###########################################--

                        
                        case s_db_reg_trx is
                            when st_db_reg_tx =>

--                                    s_debug_tx_state <= "0100";
                                if s_sc_address < c_number_of_gbttx_regs then
                                    s_sc_address<=s_sc_address+1;
                                    s_sc_address_out          <= c_db_reg_tx_lut(s_sc_address);
                                    --s_xadc_channel <= s_xadc_channel_buffer;

                                    case s_sc_address_out is
                                        when c_db_reg_tx_lut(stb_mb) =>  							--x"001"
--                                            if (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb) /= x"00000000") then
--                                                s_sc_data_out <= s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb);
--                                            end if;
                                            if (s_db_reg_tx_in(stb_mb) /= x"00000000") then
                                                s_sc_data_out <= s_db_reg_tx_in(stb_mb);
                                            end if;

                                        when c_db_reg_tx_lut(stb_adc_readout_counter_status) =>
                                            s_sc_data_out<=p_mb_interface_in.adc_readout.channel_invalid_fc_frame_counter(s_adc_counter)(31 downto 0); --x"0000" & p_mb_interface_in.adc_readout.channel_invalid_fc_frame_counter(s_adc_counter);
                                            if s_adc_counter<5 then
                                                s_adc_counter<=s_adc_counter+1;
                                            else
                                                s_adc_counter<=0;
                                            end if;
                                        when c_db_reg_tx_lut(stb_db_xadc) =>
--                                                if s_xadc_channel_buffer < c_n_db_xadc_channels then
--                                                    s_xadc_channel_buffer <= s_xadc_channel_buffer+1;
--                                                else
--                                                    s_xadc_channel_buffer<=0;
--                                                end if;
--                                                s_sc_data_out <= "00000000" & c_db_drp_xadc_addresses(s_xadc_channel_buffer) & s_xadc_channel_voltage;
--                                                s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_db_xadc) <= "00000000" & c_db_drp_xadc_addresses(s_xadc_channel_buffer) & s_xadc_channel_voltage;

                                            s_sc_data_out <= "00000000" & p_system_management_interface_in.xadc_channel & p_system_management_interface_in.xadc_channel_voltage;
                                            s_db_reg_tx_in(stb_db_xadc) <= "00000000" & p_system_management_interface_in.xadc_channel & p_system_management_interface_in.xadc_channel_voltage;
                                        
                                        when c_db_reg_tx_lut(stb_mb_q0) =>							--x"00c"
--                                            if ((s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q0)(11 downto 0)) /= x"000") then
--                                                s_sc_data_out <= s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q0);						
--                                            end if;
                                            if ((s_db_reg_tx_in(stb_mb_q0)(11 downto 0)) /= x"000") then
                                                s_sc_data_out <= s_db_reg_tx_in(stb_mb_q0);						
                                            end if;

                                        when c_db_reg_tx_lut(stb_mb_q1) =>							--x"00d"
--                                            if ((s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q1)(11 downto 0)) /= x"000") then
--                                                s_sc_data_out <= s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb_q1);						
--                                            end if;
                                            if ((s_db_reg_tx_in(stb_mb_q1)(11 downto 0)) /= x"000") then
                                                s_sc_data_out <= s_db_reg_tx_in(stb_mb_q1);						
                                            end if;
--                                            when c_db_reg_tx_lut(stb_db_cfbstrobe) =>  							--x"001"
--                                                if (s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_db_cfbstrobe) /= x"00000000") then
--                                                    s_sc_data_out <= s_db_reg_tx_pipeline(c_pipeline_depth-1)(stb_mb);
--                                                end if;
                                        when others =>
--                                            s_sc_data_out 			<= s_db_reg_tx_pipeline(c_pipeline_depth-1)(s_sc_address);
                                            s_sc_data_out 			<= s_db_reg_tx_in(s_sc_address);
                                            
                                    end case;
                                else
                                    s_sc_address <= 0;
                                    --s_sc_address_out          <= c_db_reg_tx_lut(0);
                                    s_sc_address_out          <= x"0C" & c_db_reg_rx_lut(0)(7 downto 0);
--                                    s_sc_data_out 			<= s_db_reg_rx_pipeline(c_pipeline_depth-1)(0);
                                    s_sc_data_out 			<= s_db_reg_rx_in(0);
                                    s_db_reg_trx <= st_db_reg_rx;
                                    --s_xadc_channel <= 0;
                                end if;
                            
                             when st_db_reg_rx =>
--                                    s_debug_tx_state <= "0101";
                                
                                if s_sc_address < c_number_of_cfgbus_regs then
                                    s_sc_address<=s_sc_address+1;
                                    case s_sc_address is
                                        when cfb_tx_reg_address=>
                                            s_sc_address_out <=  x"0C06";-- & c_db_reg_rx_lut(s_sc_address)(7 downto 0);
                                            s_sc_data_out<=s_db_reg_tx_in(to_integer(unsigned(s_db_reg_rx_in(cfb_tx_reg_address))));
                                            --s_sc_data_out <= s_sc_reg_tx_data_buffer;-- s_db_reg_tx_pipeline(c_pipeline_depth-1)(to_integer(unsigned(s_db_reg_rx_pipeline(c_pipeline_depth-1)(cfb_tx_reg_address))));
                                        when others =>
--                                            s_sc_reg_tx_data_buffer <=  s_db_reg_tx_in(to_integer(unsigned(s_db_reg_rx_in(cfb_tx_reg_address))));
--                                            s_sc_reg_tx_data_buffer <=  s_db_reg_tx_pipeline(c_pipeline_depth-1)(to_integer(unsigned(s_db_reg_rx_pipeline(c_pipeline_depth-1)(cfb_tx_reg_address))));
                                            s_sc_address_out          <= x"0C" & c_db_reg_rx_lut(s_sc_address)(7 downto 0);
                                            s_sc_data_out 			<= s_db_reg_rx_in(s_sc_address);
--                                            s_sc_data_out 			<= s_db_reg_rx_pipeline(c_pipeline_depth-1)(s_sc_address);
                                        end case;
                                else
                                
                                     s_sc_address_out          <= x"0A" & p_system_management_interface_in.xadc_channel(7 downto 0);
                                     s_sc_data_out             <= x"0000" & p_system_management_interface_in.xadc_channel_voltage;
                                     s_sc_address <= 0;
                                     s_db_reg_trx <= st_db_reg_tx;
--                                        s_sc_address <= 0;
--                                        s_sc_address_out          <= x"0C" & c_db_reg_rx_lut(0)(7 downto 0);
--                                        s_sc_address_out          <= x"0A" & c_db_drp_xadc_addresses(0)(7 downto 0);
--                                        s_sc_data_out 			<= x"0000" & s_xadc_channel_voltage; --p_system_management_interface_in.xadc_voltages(s_sc_address);
                                    --s_db_reg_trx <= st_db_reg_tx;
--                                        s_db_reg_trx <= st_db_xadc_tx;
                                end if;     
                                
--                                 when st_db_xadc_tx =>
                             
----                                    s_debug_tx_state <= "0101";
--                                         s_sc_address_out          <= x"0A" & p_system_management_interface_in.xadc_channel(7 downto 0);
--                                         s_sc_data_out             <= x"0000" & p_system_management_interface_in.xadc_channel_voltage;
--                                         s_sc_address <= 0;
--                                         s_db_reg_trx <= st_db_reg_tx;
----                                    if s_xadc_channel < c_n_db_xadc_channels then
----                                        s_xadc_channel<=s_xadc_channel+1;
----                                        s_sc_address_out          <= x"0A" & c_db_drp_xadc_addresses(s_xadc_channel+1)(7 downto 0);
----                                        s_sc_data_out 			<= x"0000" & s_xadc_channel_voltage; --p_system_management_interface_in.xadc_voltages(s_sc_address);
----                                    else
----                                        s_xadc_channel <= 0;
------                                        s_sc_address_out          <= x"0A" & c_db_drp_xadc_addresses(0)(7 downto 0);
----                                        s_sc_address <= 0;
----                                        s_sc_address_out          <= c_db_reg_tx_lut(0);
----                                        s_sc_data_out 			<= s_db_reg_tx_pipeline(c_pipeline_depth-1)(0);
----                                        s_db_reg_trx <= st_db_reg_tx;
----                                    end if;                                  
                             
                             when others =>
                                s_db_reg_trx <= st_db_reg_tx;
                        end case;
                                 

                end if;
            end if;
        end if;
    end process;
    
    proc_sc_data_tx: process(p_clknet_in.cfgbus_clk40, p_master_reset_in, p_clknet_in.locked_db, p_sfp_ku_mgt_in.gtwiz_reset_tx_done_out, s_db_reg_rx_in(cfb_strobe_reg)(c_gbt_encoder_reset_bit))--process(p_clknet_in.refclk40)
        
        begin
            if (p_master_reset_in = '1') or (p_clknet_in.locked_db = '0') or (p_sfp_ku_mgt_in.gtwiz_reset_tx_done_out = "0") or (s_db_reg_rx_in(cfb_strobe_reg)(c_gbt_encoder_reset_bit) = '1')then
                s_sm_write_state <= st_data;

                s_sc_switch_out(0)   <= "00";
                s_sc_switch_out(1)   <= "00";
                s_sc_tx_out(0)       <= (others=>'0');
                s_sc_tx_out(1)       <= (others=>'0');
                	
            elsif rising_edge(p_clknet_in.cfgbus_clk40) then--(p_clknet_in.refclk40) then
                
                if s_sending = '0' then
                     
--                        s_sc_address_tx <= s_blk_mem_gbt_sc.addrb;
--                        s_sc_data_tx <= s_blk_mem_gbt_sc.doutb;
                        s_sc_data_tx<=s_sc_data_out; --*
                        s_sc_switch_out(0)   <= "00"; 
                        s_sc_switch_out(1)   <= "01";
                        s_sc_tx_out(0)       <= (others=>'0');--s_sc_address_out;
                        s_sc_tx_out(1)       <= s_sc_address_out;--s_sc_address_tx;--s_sc_data_out(31 downto 16);
                        --writestate <= "01";
                 
                else
                        s_sc_switch_out(0)   <= "10"; --"11";
                        s_sc_switch_out(1)   <= "11"; --"00";
                        s_sc_tx_out(0)       <= s_sc_data_tx(31 downto 16); --s_sc_data_out(31 downto 16); --s_sc_data_out(15 downto 0);
                        s_sc_tx_out(1)       <= s_sc_data_tx(15 downto 0); --s_sc_data_out(15 downto 0); --(others=>'0');
                        --writestate <= "00";
--                        s_sm_write_state <= st_address;
 
--                        s_blk_mem_gbt_sc.addrb<=std_logic_vector(to_unsigned(s_tx_counter,16));
--                        if s_tx_counter < 4095 then
--                            s_tx_counter<=s_tx_counter+1;
--                        else
--                            s_tx_counter<=0;
--                        end if;
               end if;                                  
        end if;
    end process;

end Behavioral;
