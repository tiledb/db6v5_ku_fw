----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Eduardo Valdes Santurio
--           Samuel Silverstein
--           Fernando Carrio
--           Steffen Muschter
--           Henrik Askedek
-- 
-- Create Date: 08/28/2018 03:04:12 PM
-- Design Name: 
-- Module Name: db6_design_package - Behavioral
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library gbt;
use gbt.vendor_specific_gbt_bank_package.all;
use gbt.gbt_bank_package.all;

package db6_design_package is



    constant c_cht8305c_temperature : integer :=0;
    constant c_cht8305c_humidity : integer :=1;
    constant c_cht8305c_config : integer :=2;
    constant c_cht8305c_alert : integer :=3;
    constant c_cht8305c_manufacturer : integer :=4;
    constant c_cht8305c_id : integer :=5;
    
    type t_cht8305c_regs is array (0 to 5) of std_logic_vector(15 downto 0);
--    signal s_cht8305c_regs : t_cht8305c_regs;


    -- sff-8472 A2h digital diagnostics monitoring (ddm) fields, decoded from the raw
    -- byte page db6_sfp_i2c_interface.vhd already reads into its block ram (offsets
    -- 96-109); tec_current is optional per spec (dwdm-tunable transceivers only).
    constant c_sfp_temperature : integer :=0;
    constant c_sfp_vcc : integer :=1;
    constant c_sfp_tx_bias_current : integer :=2;
    constant c_sfp_tx_power : integer :=3;
    constant c_sfp_rx_power : integer :=4;
    constant c_sfp_laser_temperature : integer :=5;
    constant c_sfp_tec_current : integer :=6;

    type t_sfp_regs is array (0 to 6) of std_logic_vector(15 downto 0);
    type t_sfp_regs_array is array (0 to 1) of t_sfp_regs; -- one per sfp side



    
    --general constants
    constant c_priority_side : std_logic_vector(1 downto 0) := "01";
    constant c_fw_version : std_logic_vector(31 downto 0) := x"20230306"; 
    constant c_global_pipeline_depth : integer:=3;
    --general types
    --type t_diff_pair is array (0 to 1) of std_logic;
    type t_diff_pair is record
        n : std_logic;
        p : std_logic;
    end record;

    type t_i2c_bus is record
        sda : std_logic;
        scl : std_logic;
    end record;

    type t_i2c is record
        reset        : std_logic;
        ena_in       : std_logic;                    --latch in command
        addr_in      : std_logic_vector(6 downto 0); --address of target slave
        rw_in        : std_logic;                    --'0' is write, '1' is read
        data_in   : std_logic_vector(7 downto 0); --data to write to slave
        busy_out      : std_logic;                    --indicates transaction in progress
        data_out   : std_logic_vector(7 downto 0); --data read from slave
        ack_error : std_logic;                    --flag if improper acknowledge from slave
    end record;

    type t_blk_mem_gbtx_regs is record
        clka : STD_LOGIC;
        wea : STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : STD_LOGIC_VECTOR(8 DOWNTO 0);
        dina : STD_LOGIC_VECTOR(7 DOWNTO 0);
        douta : STD_LOGIC_VECTOR(7 DOWNTO 0);
        clkb : STD_LOGIC;
        enb : STD_LOGIC;
        web : STD_LOGIC_VECTOR(0 DOWNTO 0);
        addrb : STD_LOGIC_VECTOR(8 DOWNTO 0);
        dinb : STD_LOGIC_VECTOR(7 DOWNTO 0);
        doutb : STD_LOGIC_VECTOR(7 DOWNTO 0);
    end record;
    
    type t_blk_mem_gbt_sc is record
        clka : STD_LOGIC;
        wea : STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : STD_LOGIC_VECTOR(15 DOWNTO 0);
        dina : STD_LOGIC_VECTOR(31 DOWNTO 0);
        douta : STD_LOGIC_VECTOR(31 DOWNTO 0);
        clkb : STD_LOGIC;
        web : STD_LOGIC_VECTOR(0 DOWNTO 0);
        addrb : STD_LOGIC_VECTOR(15 DOWNTO 0);
        dinb : STD_LOGIC_VECTOR(31 DOWNTO 0);
        doutb : STD_LOGIC_VECTOR(31 DOWNTO 0);
    end record;
    
    type t_blk_mem_sfp is record
        clka : STD_LOGIC;
        wea : STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : STD_LOGIC_VECTOR(6 DOWNTO 0);
        dina : STD_LOGIC_VECTOR(7 DOWNTO 0);
        douta : STD_LOGIC_VECTOR(7 DOWNTO 0);
        clkb : STD_LOGIC;
        web : STD_LOGIC_VECTOR(0 DOWNTO 0);
        addrb : STD_LOGIC_VECTOR(6 DOWNTO 0);
        dinb : STD_LOGIC_VECTOR(7 DOWNTO 0);
        doutb : STD_LOGIC_VECTOR(7 DOWNTO 0); 
    end record;
    
    type t_blk_mem_sfp_array is array (0 to 1) of t_blk_mem_sfp;

    -- port b debug readback of the sfp reg block ram: rx_register addresses a byte
    -- (0-127) of the A2h diagnostic region, tx_register carries that byte back out.
    type t_sfp_reg_addr_array is array (0 to 1) of std_logic_vector(6 downto 0);
    type t_sfp_reg_data_array is array (0 to 1) of std_logic_vector(7 downto 0);
    --t_sfp_i2c_interface_out is record

    type t_sfp_interface is record
        tx_fault : std_logic_vector(1 downto 0);
        tx_disable : std_logic_vector(1 downto 0);
        mod_abs :  std_logic_vector(1 downto 0);
        mod_los :  std_logic_vector(1 downto 0);
        
--        gbtx_rxready : std_logic_vector(1 downto 0);
        --i2c : t_i2c;
        --busy : std_logic;
        i2c_interface : t_blk_mem_sfp_array;
        ddm : t_sfp_regs_array; -- decoded a2h ddm fields, per side (see c_sfp_* above)
        --tmr_error : std_logic;
    end record;

    --mgt        
    constant c_gbt_bank_number_of_links : integer := 2; --2;--3; --2;--3;
    constant c_number_of_gth_refclks : integer :=2;-- 1;
    type t_gbt_cdc_counter_array is array (0 to c_gbt_bank_number_of_links-1) of integer range 0 to 3;
    type t_gbt_cdc_phase_array  is array (0 to c_gbt_bank_number_of_links-1) of std_logic;
    type t_db6_gbt_bank is record
        --========--
        -- resets --
        --========--
        mgt_txreset_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        mgt_rxreset_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_txreset_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_rxreset_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        --========--
        -- clocks --     
        --========--
        mgt_clk_i : std_logic_vector(c_number_of_gth_refclks-1 downto 0); --std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_txframeclk_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_txclken_i  : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
		gbt_rxframeclk_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_rxclken_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
		mgt_txwordclk_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        mgt_rxwordclk_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        --================--
        -- gbt tx control --
        --================--
        tx_encoding_sel_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_isdataflag_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        --=================--
        -- gbt tx status   --
        --=================--
        tx_phcomputed_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
		tx_phaligned_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        --================--
        -- gbt rx control --
        --================--
        rx_encoding_sel_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        --=================--
        -- gbt rx status   --
        --=================--
        gbt_rxready_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_isdataflag_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_errordetected_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gbt_errorflag_o : gbt_reg84_A(c_gbt_bank_number_of_links-1 downto 0);
        --================--
        -- mgt control    --
        --================--
        mgt_devspecific_i : mgtdevicespecific_i_r;
        mgt_rstonbitslipen_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        mgt_rstoneven_i : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        --=================--
        -- mgt status      --
        --=================--
        mgt_txready_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        mgt_rxready_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        mgt_devspecific_o : mgtdevicespecific_o_r;               --! device specific record connected to the transceiver, defined into the device specific package
        mgt_headerflag_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        mgt_headerlocked_o : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        mgt_rstcnt_o : gbt_reg8_a(1 to c_gbt_bank_number_of_links);          --! number of resets because of a wrong bitslip parity
        --========--
        -- data   --
        --========--
        gbt_txdata_lg_i : gbt_reg84_a(1 to c_gbt_bank_number_of_links);         --! gbt data to be encoded and transmit
        gbt_txdata_hg_i : gbt_reg84_a(1 to c_gbt_bank_number_of_links);         --! gbt data to be encoded and transmit
        gbt_txdata_i : gbt_reg84_a(1 to c_gbt_bank_number_of_links);         --! gbt data to be encoded and transmit
        gbt_rxdata_o: gbt_reg84_a(1 to c_gbt_bank_number_of_links);         --! gbt data received and decoded
        wb_txdata_lg_i : gbt_reg32_a(1 to c_gbt_bank_number_of_links);         --! (tx) extra data (32bit) to replace the fec when the widebus encoding scheme is selected
        wb_txdata_hg_i : gbt_reg32_a(1 to c_gbt_bank_number_of_links);         --! (tx) extra data (32bit) to replace the fec when the widebus encoding scheme is selected
        wb_txdata_i : gbt_reg32_a(1 to c_gbt_bank_number_of_links);         --! (tx) extra data (32bit) to replace the fec when the widebus encoding scheme is selected
        wb_rxdata_o : gbt_reg32_a(1 to c_gbt_bank_number_of_links);          --! (rx) extra data (32bit) replacing the fec when the widebus encoding scheme is selected
        gbt_cdc_counter_array_i : t_gbt_cdc_counter_array;
        tx_phase_i : std_logic_vector(c_gbt_bank_number_of_links -1 downto 0);
        wordtx_phase_missalignment : std_logic_vector(c_gbt_bank_number_of_links -1 downto 0);
        gbt_bank_sync : std_logic_vector(2 downto 0);
    end record;
    
    type t_mgt_diff_pair is array (c_gbt_bank_number_of_links-1 downto 0) of t_diff_pair;
    type t_diff_pair_vector is array (natural range <>) of t_diff_pair;
    
    type t_ku_mgt_channel is record
    gtwiz_userclk_tx_active_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_reset_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_start_user_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_done_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_error_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_reset_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_start_user_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_done_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_error_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in : STD_LOGIC_VECTOR(79 DOWNTO 0);
    gtwiz_userdata_rx_out : STD_LOGIC_VECTOR(79 DOWNTO 0);
    gtrefclk01_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1refclksel_in : STD_LOGIC_VECTOR(2 DOWNTO 0);
    qpll1fbclklost_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1lock_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1outclk_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1outrefclk_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    qpll1refclklost_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    cpllrefclksel_in : STD_LOGIC_VECTOR(5 DOWNTO 0);
    drpaddr_in : STD_LOGIC_VECTOR(17 DOWNTO 0);
    drpclk_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    drpdi_in : STD_LOGIC_VECTOR(31 DOWNTO 0);
    drpen_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    drpwe_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    gtgrefclk_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    gthrxn_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    gthrxp_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    gtrefclk0_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    loopback_in : STD_LOGIC_VECTOR(5 DOWNTO 0);
    rxpolarity_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxslide_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxsysclksel_in : STD_LOGIC_VECTOR(3 DOWNTO 0);
    rxusrclk_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxusrclk2_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    txdiffctrl_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
    txmaincursor_in : STD_LOGIC_VECTOR(13 DOWNTO 0);
    txpolarity_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    txpostcursor_in : STD_LOGIC_VECTOR(9 DOWNTO 0);
    txprecursor_in : STD_LOGIC_VECTOR(9 DOWNTO 0);
    txsysclksel_in : STD_LOGIC_VECTOR(3 DOWNTO 0);
    txusrclk_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    txusrclk2_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
    cplllock_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    drpdo_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
    drprdy_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    gthtxn_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    gthtxp_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    gtpowergood_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxoutclk_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxpmaresetdone_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    txoutclk_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    txpmaresetdone_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
    txprgdivresetdone_out : STD_LOGIC_VECTOR(1 DOWNTO 0);
end record;

--type t_ku_mgt is array (c_gbt_bank_number_of_links-1 downto 0) of t_ku_mgt_channel;

    type t_ku_mgt is record
        gtwiz_userclk_tx_reset_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_rx_reset_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_tx_srcclk_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_tx_usrclk_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_tx_usrclk2_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_tx_active_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_rx_srcclk_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_rx_usrclk_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_rx_usrclk2_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_rx_active_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
    
        gtwiz_userclk_tx_active_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userclk_rx_active_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_buffbypass_tx_reset_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gttxreset_in : STD_LOGIC_VECTOR(2 DOWNTO 0);
        gtwiz_buffbypass_tx_start_user_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_buffbypass_tx_done_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_buffbypass_tx_error_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_buffbypass_rx_reset_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_buffbypass_rx_start_user_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_buffbypass_rx_done_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_buffbypass_rx_error_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_clk_freerun_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_all_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_tx_pll_and_datapath_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_tx_datapath_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_rx_pll_and_datapath_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_rx_datapath_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_rx_cdr_stable_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_tx_done_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_reset_rx_done_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtwiz_userdata_tx_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*40-1) DOWNTO 0);
        gtwiz_userdata_rx_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*40-1) DOWNTO 0);
        drpaddr_common_in : STD_LOGIC_VECTOR(8 DOWNTO 0);
        drpclk_common_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        drpdi_common_in : STD_LOGIC_VECTOR(15 DOWNTO 0);
        drpen_common_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        drpwe_common_in : STD_LOGIC_VECTOR(0 DOWNTO 0);
        gtgrefclk0_in : STD_LOGIC_VECTOR(c_number_of_gth_refclks*1-1 DOWNTO 0);
        gtgrefclk1_in : STD_LOGIC_VECTOR(c_number_of_gth_refclks*1-1 DOWNTO 0);
        gtrefclk01_in : STD_LOGIC_VECTOR(c_number_of_gth_refclks*1-1 DOWNTO 0);
        gtrefclk11_in : STD_LOGIC_VECTOR(c_number_of_gth_refclks*1-1 DOWNTO 0);
        qpll1refclksel_in : STD_LOGIC_VECTOR(c_number_of_gth_refclks*3-1 DOWNTO 0);
        qpll0refclksel_in : STD_LOGIC_VECTOR(c_number_of_gth_refclks*3 DOWNTO 0);
        drpdo_common_out : STD_LOGIC_VECTOR(15 DOWNTO 0);
        drprdy_common_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        qpll1fbclklost_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        qpll1lock_out : STD_LOGIC_VECTOR(c_number_of_gth_refclks*1-1 DOWNTO 0);
        qpll1outclk_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        qpll1outrefclk_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        qpll1refclklost_out : STD_LOGIC_VECTOR(0 DOWNTO 0);
        cpllrefclksel_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*3-1) DOWNTO 0);
        drpaddr_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*9-1) DOWNTO 0);
        drpclk_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        drpdi_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*16-1) DOWNTO 0);
        drpen_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        drpwe_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        gtgrefclk_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        gthrxn_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        gthrxp_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        gtrefclk0_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        gtrefclk1_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        loopback_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*3-1) DOWNTO 0);
        rxoutclksel_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*3-1) DOWNTO 0);
        rxpllclksel_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*2-1) DOWNTO 0);
        rxpolarity_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        rxslide_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        rxsysclksel_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*2-1) DOWNTO 0);
        rxusrclk_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        rxusrclk2_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        txdiffctrl_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*4-1) DOWNTO 0);
        txmaincursor_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*7-1) DOWNTO 0);
        txoutclksel_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*3-1) DOWNTO 0);
        txpllclksel_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*2-1) DOWNTO 0);
        txpolarity_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        txpostcursor_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*5-1) DOWNTO 0);
        txprecursor_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*5-1) DOWNTO 0);
        txsysclksel_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*2-1) DOWNTO 0);
        txusrclk_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        txusrclk2_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        cplllock_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        drpdo_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*16-1) DOWNTO 0);
        drprdy_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        gthtxn_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        gthtxp_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        gtpowergood_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        rxoutclk_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        rxoutclkfabric_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        rxpmaresetdone_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        txoutclkfabric_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        txoutclk_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        txpmaresetdone_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        txprgdivresetdone_out : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        
        eyescanreset_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        rxlpmen_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        rxrate_in : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*3-1) DOWNTO 0);
        
        leds_out : std_logic_vector (3 downto 0);
        
        tx_wordclk : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        tx_frameclk : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
        tx_frameclk40 : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);

        -- sfp+ reg block ram port b readback value, per side (see cfb_sfp_reg_address /
        -- stb_sfp_reg_readback); rides along with the rest of the sfp/gth status bundle
        -- so it's visible everywhere p_sfp_ku_mgt_in already is (db6_gbt_encoder_sc etc.)
        sfp_tx_register : t_sfp_reg_data_array;

    end record;


type t_xlx_ku_system_ibert_ip is record

    drpclk_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    gth_drpen_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    gth_drpwe_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    gth_drpaddr_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*9-1) DOWNTO 0);
    gth_drpdi_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*16-1) DOWNTO 0);
    gth_drprdy_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    gth_drpdo_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*16-1) DOWNTO 0);

    eyescanreset_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    rxrate_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*3-1) DOWNTO 0);
    txdiffctrl_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*4-1) DOWNTO 0);
    txprecursor_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*5-1) DOWNTO 0);
    txpostcursor_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*5-1) DOWNTO 0);
    rxlpmen_o : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    rxrate_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*3-1) DOWNTO 0);
    txdiffctrl_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*4-1) DOWNTO 0);
    txprecursor_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*5-1) DOWNTO 0);
    txpostcursor_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*5-1) DOWNTO 0);
    rxlpmen_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    drpclk_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    rxoutclk_i : STD_LOGIC_VECTOR((c_gbt_bank_number_of_links*1-1) DOWNTO 0);
    clk : STD_LOGIC;
    
end record;

    --xadc declarations
    constant c_n_db_xadc_channels : integer range 0 to 32 := 31;
--    constant c_n_mb_xadc_mux_channels : integer range 0 to 32 := 6;    
    --type t_db_xadc_values is array (natural range <>) of std_logic_vector(15 downto 0);
    type t_db_xadc_drp_addresses is array (natural range 0 to c_n_db_xadc_channels-1) of std_logic_vector(7 downto 0);
    --type t_db_xadc_sequencer_addresses is array (natural range <>) of std_logic_vector(5 downto 0);
    type t_xadc_voltages is array (natural range 0 to c_n_db_xadc_channels-1) of std_logic_vector(15 downto 0);
    --xadc values
    --signal s_db_xadc_values : t_db_xadc_values(c_n_db_xadc_channels-1 downto 0):= (others=>(others=>'0'));
    -- xadc ram addresses
    constant c_db_drp_xadc_addresses : t_db_xadc_drp_addresses :=
        (
            "0000" & x"0",   -- temperature
            "0000" & x"1",   -- vccint
            "0000" & x"2",   -- vccaux
            "0000" & x"3",  --vp_vn
            "0000" & x"4",  --vp_ref
            "0000" & x"5",  --vn_ref
            "0000" & x"6",  --v_ram
            "0001" & x"0", -- db_mon_1.8v(vaux0)
            "0001" & x"1", -- db_mon_2.5v(vaux1)
            "0001" & x"2", -- mb_mon_+5v(vaux2)
            "0001" & x"3", -- db_sense_3(vaux3)
            "0001" & x"4", -- mb_mon_-5v(vaux04)
            "0001" & x"5", -- db_mon_1.0v(vaux5)
            "0001" & x"6", -- mb_mon_1.8v(vaux6)
            "0001" & x"7", -- mb_mon_1.2v(vaux7)
            "0001" & x"8", -- db_mon_1,5v(vaux8)
            "0001" & x"9", -- db_mon_0.95v(vaux9)
            "0001" & x"a", -- db_mon_3.3v(vaux10)
            "0001" & x"b", -- db_mon_1.2v(vaux11)
            "0001" & x"c", -- db_sense_1(vaux12)
            "0001" & x"d", -- db_sense_2(vaux13)
            "0001" & x"e", -- mb_mon_10v(vaux14)
            "0001" & x"f", -- mb_mon_2.5v(vaux15)
            "0010" & x"0", --max_temp            
            "0010" & x"1", --max_vccint
            "0010" & x"2", --max_vccaux
            "0010" & x"3", --max_vccram
            "0010" & x"4", --min_temp           
            "0010" & x"5", --min_vccint  
            "0010" & x"6", --min_vccaux            
            "0010" & x"7"  --min_vccram 
    );
    
    

    type t_commbus is record
        heartbeat : std_logic;
        side : std_logic;
        tx_busy : std_logic;
        main_sm :std_logic_vector(3 downto 0);
        gbt_clk_sel : std_logic;
        qpll1refclksel :std_logic_vector(2 downto 0);
        leds : std_logic_vector(3 downto 0);
        i2c_busy : std_logic;
        master_reset : std_logic;
        gth_reset : std_logic;
        clknet_reset : std_logic;
        write_flag : std_logic;
        read_flag : std_logic;
        gbtx_select : std_logic_vector(1 downto 0);
        address : std_logic_vector(7 downto 0);
        value : std_logic_vector(31 downto 0);
    end record;

    
    type t_xadc_data is record
        temperature : std_logic_vector(15 downto 0);
        vccint : std_logic_vector(15 downto 0);
        vccaux : std_logic_vector(15 downto 0);
        mb_10v_voltage : std_logic_vector(15 downto 0);
        mb_1v2_voltage : std_logic_vector(15 downto 0);
        mb_2v5_voltage : std_logic_vector(15 downto 0);
        mb_1v8_voltage : std_logic_vector(15 downto 0);
        mb_5v_voltage : std_logic_vector(15 downto 0);
        mb_5vn_voltage : std_logic_vector(15 downto 0);
        db_3v3_current : std_logic_vector(15 downto 0);
        db_2v5_current : std_logic_vector(15 downto 0);
        db_1v8_current : std_logic_vector(15 downto 0);
        db_1v5_current : std_logic_vector(15 downto 0);
        db_1v2_current : std_logic_vector(15 downto 0);
        db_0v9_current : std_logic_vector(15 downto 0);
        db_0v85_current : std_logic_vector(15 downto 0);
        db_sense_1 : std_logic_vector(15 downto 0);
        db_sense_2 : std_logic_vector(15 downto 0);
        db_sense_3 : std_logic_vector(15 downto 0);
        
        db_pgood_1 : std_logic;
        db_pgood_2 : std_logic;
        db_pgood_3 : std_logic;
        db_pgood_4 : std_logic;
        
    end record;

type t_xadc_analog_in is record

    v : t_diff_pair;
    vaux0 : t_diff_pair;
    vaux1 : t_diff_pair;
    vaux2 : t_diff_pair;
    vaux3 : t_diff_pair;
    vaux4 : t_diff_pair;
    vaux5 : t_diff_pair;
    vaux6 : t_diff_pair;
    vaux7 : t_diff_pair;
    vaux8 : t_diff_pair;
    vaux9 : t_diff_pair;
    vaux10 : t_diff_pair;
    vaux11 : t_diff_pair;
    vaux12 : t_diff_pair;
    vaux13 : t_diff_pair;
    vaux14 : t_diff_pair;
    vaux15 : t_diff_pair;

end record;

        constant c_number_of_pgood_channels : integer := 15-1;
        constant c_pgood_db_1v2_bit : integer := 0;        
        constant c_pgood_db_5v0_bit : integer := 1;
        constant c_pgood_db_1v5_bit : integer := 2;
        constant c_pgood_db_3v3_bit : integer := 3;
        constant c_pgood_db_0v95_bit : integer := 4;
        constant c_pgood_db_1v0_bit : integer := 5;
        constant c_pgood_db_1v8_bit : integer := 6;
        constant c_pgood_db_2v5_bit : integer := 7;
        constant c_pgood_mb_3v3_bit : integer := 8;
        constant c_pgood_mb_5v0_n_bit : integer := 9;
        constant c_pgood_mb_5v0_bit : integer := 10;
        constant c_pgood_mb_1v8_bit : integer := 11;
        constant c_pgood_mb_1v2_bit : integer := 12;
        constant c_pgood_mb_2v5_bit : integer := 13;
        constant c_pgood_mb_10v0_bit : integer := 14; 


type t_pgood is record
    db_5v0 : std_logic;
    db_3v3 : std_logic;
    db_2v5 : std_logic;
    db_1v8 : std_logic;
    db_1v5 : std_logic;
    db_1v0 : std_logic;
    db_1v2 : std_logic;
    db_0v95 : std_logic;
    
    mb_10v0 : std_logic;    
    mb_5v0 : std_logic;
    mb_5v0_n : std_logic;
    mb_3v3 : std_logic;
    mb_2v5 : std_logic;
    mb_1v8 : std_logic;
    mb_1v2 : std_logic;

end record;



type t_p_pgood_in is record
    db_1v2_5v0 : std_logic;
--    db_3v3 : std_logic;
--    db_2v5 : std_logic;
    db_1v8_2v5 : std_logic;
    db_1v5_3v3 : std_logic;
    db_1v0_0v95 : std_logic;
--    db_0v9 : std_logic;
    
    mb_10v0 : std_logic;    
    mb_5v0_1v8 : std_logic;
    mb_5v0_n_3v3 : std_logic;
--    mb_3v3 : std_logic;
    mb_2v5_1v2 : std_logic;
--    mb_1v8 : std_logic;
--    mb_1v2 : std_logic;

end record;



    constant c_lhc_bunches_between_bcr : integer := 3564;

	type countbit_type is array (0 to 11) of std_logic_vector(4 downto 0);
	type eye_type is array (0 to 11) of std_logic_vector(31 downto 0);

--	constant g_bus_input_enable : std_logic_vector(11 downto 0) := (others=>'1');
--	constant h_bus_input_enable : std_logic_vector(11 downto 0) := (others=>'1');
--	constant j_bus_input_enable : std_logic_vector(11 downto 0) := (others=>'1');
--	constant k_bus_input_enable : std_logic_vector(11 downto 0) := (others=>'1');

	type fmc_array is array (11 downto 0) of std_logic_vector(15 downto 0);
	type serial_array is array (11 downto 0) of std_logic_vector(0 downto 0);
	type loopback_type is array (3 downto 0) of std_logic_vector(2 downto 0);
	type gtx_data_type is array (3 downto 0) of std_logic_vector(39 downto 0);
	type slow_data_array is array (3 downto 0) of std_logic_vector(239 downto 0);
	type shift_reg_array is array (3 downto 0) of std_logic_vector(4 downto 0);

    constant c_adc_bit_number : integer := 14;
    constant c_oversamples : integer := 2;
	type t_adc_data_type is array (0 to 11) of std_logic_vector(c_adc_bit_number-1 downto 0);  -- 14 bit adc output words
	type t_adc_data is array (5 downto 0) of std_logic_vector(c_adc_bit_number-1 downto 0);
	
	type t_adc_oversample_data_type is array (5 downto 0) of std_logic_vector((c_oversamples*c_adc_bit_number)-1 downto 0);  -- 14 bit adc output words
	type t_bitslip is array (5 downto 0) of  std_logic_vector(3 downto 0);
    type t_adc_sr is array(5 downto 0) of std_logic_vector(26 downto 0);
    type t_bitslice_sr is array(5 downto 0) of std_logic_vector(1 downto 0);
    type t_byteslice_sr is array(5 downto 0) of std_logic_vector(7 downto 0);		
	type fmc_bus_diff_out is array (1 downto 0) of std_logic_vector(11 downto 0);
    type t_idelay_count is array (5 downto 0) of  std_logic_vector(8 downto 0);
    type t_channel_integer_count is array (5 downto 0) of  std_logic_vector(31 downto 0);
	
	type t_bitslips_integer_array is array (5 downto 0) of integer;
	type t_idelay_integer_array is array (5 downto 0) of integer;

    type t_iserdese3 is record
       fifo_empty : std_logic; -- 1-bit output: fifo empty flag
       internal_divclk : std_logic; -- 1-bit output: internally divided down clock used when fifo is
       q : std_logic_vector(7 downto 0); -- 8-bit registered output
       clk : std_logic; -- 1-bit input: high-speed clock
       clkdiv : std_logic; -- 1-bit input: divided clock
       clk_b : std_logic; -- 1-bit input: inversion of high-speed clock clk
       d : std_logic; -- 1-bit input: serial data input
       fifo_rd_clk : std_logic; -- 1-bit input: fifo read clock
       fifo_rd_en : std_logic; -- 1-bit input: enables reading the fifo when asserted
       rst : std_logic; -- 1-bit input: asynchronous reset
    end record;    
    type t_iserdese3_array is array (0 to 5) of t_iserdese3;
	
	type t_adc_registers is array (0 to 4) of std_logic_vector(7 downto 0);

    type t_bufgce_div is record
        o : std_logic; --s_bitclk_div(i), -- 1-bit output: buffer
        ce : std_logic; -- 1-bit input: buffer enable
        clr : std_logic; -- 1-bit input: asynchronous clear
        i  : std_logic; -- 1-bit input: buffer
    end record;
    type t_bufgce_div_array is array (0 to 5) of t_bufgce_div;
    
    type t_counter_binary_8bit is record
        CLK : STD_LOGIC;
        CE : STD_LOGIC;
        SCLR : STD_LOGIC;
        LOAD : STD_LOGIC;
        L : STD_LOGIC_VECTOR(7 DOWNTO 0);
        Q : STD_LOGIC_VECTOR(7 DOWNTO 0);
    END record;
 
    type t_counter_binary_32bit is record
        CLK : STD_LOGIC;
        CE : STD_LOGIC;
        SCLR : STD_LOGIC;
        LOAD : STD_LOGIC;
        L : STD_LOGIC_VECTOR(31 DOWNTO 0);
        Q : STD_LOGIC_VECTOR(31 DOWNTO 0);
    END record;

    type t_counter_binary_48bit is record
        CLK : STD_LOGIC;
        CE : STD_LOGIC;
        SCLR : STD_LOGIC;
        LOAD : STD_LOGIC;
        L : STD_LOGIC_VECTOR(47 DOWNTO 0);
        Q : STD_LOGIC_VECTOR(47 DOWNTO 0);
    END record;


    type t_adc_channel_counter_binary_48bit is array (5 downto 0) of t_counter_binary_48bit;
    type t_adc_channel_counter_binary_8bit is array (5 downto 0) of t_counter_binary_8bit;    
    
	type t_adc_register_config is record
	   mode                    : std_logic;
	   trigger_mb_adc_config : std_logic; 
	   mb_fpga_select : std_logic_vector(2 downto 0);
	   mb_pmt_select : std_logic_vector(1 downto 0);
	   adc_registers : t_adc_registers;
	   	
	end record;
	
	constant c_adc_registers_init_14_bit : t_adc_registers :=  (x"10", x"00", x"b5", x"00", x"00");
	constant c_adc_registers_init_12_bit : t_adc_registers :=  (x"00", x"00", x"b6", x"00", x"00");
    constant c_adc_register_init_config_14_bit : t_adc_register_config := ( '0', '0', "100", "11", c_adc_registers_init_14_bit);
    constant c_adc_register_init_config_12_bit : t_adc_register_config := ( '0', '0', "100", "11", c_adc_registers_init_12_bit);
    
    type t_fifo_cdc is record
        srst : STD_LOGIC;
        rst : STD_LOGIC;
        wr_clk : STD_LOGIC;
        rd_clk : STD_LOGIC;
        din : STD_LOGIC_VECTOR((c_adc_bit_number*c_oversamples)-1 DOWNTO 0);
        wr_en : STD_LOGIC;
        rd_en : STD_LOGIC;
        injectdbiterr : STD_LOGIC;
        injectsbiterr : STD_LOGIC;
        --sleep : STD_LOGIC;
        dout : STD_LOGIC_VECTOR(13 DOWNTO 0);
        full : STD_LOGIC;
        almost_full : STD_LOGIC;
        wr_ack : STD_LOGIC;
        overflow : STD_LOGIC;
        empty : STD_LOGIC;
        almost_empty : STD_LOGIC;
        valid : STD_LOGIC;
        underflow : STD_LOGIC;
        rd_data_count : STD_LOGIC_VECTOR(4 DOWNTO 0);
        wr_data_count : STD_LOGIC_VECTOR(4 DOWNTO 0);
        sbiterr : STD_LOGIC;
        dbiterr : STD_LOGIC;
        wr_rst_busy : STD_LOGIC;
        rd_rst_busy : STD_LOGIC;
        prog_full : STD_LOGIC;
        prog_empty : STD_LOGIC;
        
    end record;    

    type t_fifo is record
        srst : STD_LOGIC;
        rst : STD_LOGIC;
        wr_clk : STD_LOGIC;
        rd_clk : STD_LOGIC;
        din : STD_LOGIC_VECTOR(13 DOWNTO 0);
        wr_en : STD_LOGIC;
        rd_en : STD_LOGIC;
        injectdbiterr : STD_LOGIC;
        injectsbiterr : STD_LOGIC;
        --sleep : STD_LOGIC;
        dout : STD_LOGIC_VECTOR(13 DOWNTO 0);
        full : STD_LOGIC;
        almost_full : STD_LOGIC;
        wr_ack : STD_LOGIC;
        overflow : STD_LOGIC;
        empty : STD_LOGIC;
        almost_empty : STD_LOGIC;
        valid : STD_LOGIC;
        underflow : STD_LOGIC;
        rd_data_count : STD_LOGIC_VECTOR(4 DOWNTO 0);
        wr_data_count : STD_LOGIC_VECTOR(4 DOWNTO 0);
        sbiterr : STD_LOGIC;
        dbiterr : STD_LOGIC;
        wr_rst_busy : STD_LOGIC;
        rd_rst_busy : STD_LOGIC;
        prog_full : STD_LOGIC;
        prog_empty : STD_LOGIC;
        
    end record; 



    type t_adc_channel_fifo is array (5 downto 0) of t_fifo;
    type t_adc_channel_fifo_cdc is array (5 downto 0) of t_fifo_cdc;
    
    constant c_adc_counters_depth : integer :=48;
    type t_channel_phase_offset is array (5 downto 0) of std_logic;--of std_logic_vector(1 downto 0);
    type t_channel_counter is array (5 downto 0) of std_logic_vector(c_adc_counters_depth-1 downto 0);
    type t_channel_cdc_align_counter is array (5 downto 0) of std_logic_vector(3 downto 0);
    type t_channel_leds is array (5 downto 0) of std_logic_vector(3 downto 0);
	type t_adc_readout is record
	
		lg_data        : t_adc_data;
		lg_bitslip     : t_bitslip;
		lg_idelay_count      : t_idelay_count;
		hg_data        : t_adc_data;
		hg_bitslip     : t_bitslip;
		hg_idelay_count      : t_idelay_count;
		fc_data              : t_adc_data;
		fc_idelay_count      : t_idelay_count;
		
		channel_cdc_align_counter     : t_channel_cdc_align_counter;
		channel_missed_bit_count      : std_logic_vector(5 downto 0);
	    channel_phase_offset : t_channel_phase_offset;
	    channel_frame_missalignemt : std_logic_vector(5 downto 0);
	    channel_locked : std_logic_vector(5 downto 0);
        channel_missed_locked : std_logic_vector(5 downto 0);
        channel_clk280_stopped :  std_logic_vector(5 downto 0);
        channel_clk280_locked :  std_logic_vector(5 downto 0);
        channel_valid_fc_frame_counter : t_channel_counter;
        channel_invalid_fc_frame_counter : t_channel_counter;
        channel_valid_divclk_frame_counter : t_channel_counter;
--        channel_valid_lg_frame_counter : t_channel_counter;
        channel_invalid_lg_frame_counter : t_channel_counter;
--        channel_valid_hg_frame_counter : t_channel_counter;
        channel_invalid_hg_frame_counter : t_channel_counter;
        
        channel_pedestal_test_underflow : std_logic_vector(5 downto 0);
        channel_pedestal_test_overflow : std_logic_vector(5 downto 0);
        
        channel_pedestal_test_underflow_lg_counter : t_channel_counter;
        channel_pedestal_test_overflow_lg_counter : t_channel_counter;
        channel_pedestal_test_underflow_hg_counter : t_channel_counter;
        channel_pedestal_test_overflow_hg_counter : t_channel_counter;
        
        channel_enable_test_pattern : std_logic_vector (5 downto 0);
        channel_lg_data_test_pattern            : t_adc_data;
        channel_hg_data_test_pattern            : t_adc_data;
    
	    readout_initialized : std_logic;
	        
	    mb_adc_config_control : t_adc_register_config;
	    
        channel_fifo_block_ram_fc                       : t_adc_channel_fifo; --t_adc_channel_fifo_cdc;--t_adc_channel_fifo;
        channel_fifo_block_ram_lg                       : t_adc_channel_fifo; --t_adc_channel_fifo_cdc;--t_adc_channel_fifo;
        channel_fifo_block_ram_hg                       : t_adc_channel_fifo; --t_adc_channel_fifo_cdc;--t_adc_channel_fifo;
    
	    channel_leds : t_channel_leds;
	    
	    tmr_enabled : std_logic;
	    tmr_error_lg : std_logic_vector(5 downto 0);
	    tmr_error_hg : std_logic_vector(5 downto 0);
	    tmr_error_fc : std_logic_vector(5 downto 0);
	    tmr_error : std_logic_vector(5 downto 0);
	    
	end record;	
type t_adc_readout_tmr is array (0 to 2) of t_adc_readout;

type t_addsub is record
    clk : std_logic;
    A : STD_LOGIC_VECTOR(14 DOWNTO 0);
    B : STD_LOGIC_VECTOR(14 DOWNTO 0);
    S : STD_LOGIC_VECTOR(14 DOWNTO 0);
    
end record;

type t_adc_addsub is array (0 to 5) of t_addsub;


    type t_fifo_gbt_encoder is record
        clk : std_logic;
        rst : STD_LOGIC;
        wr_clk : STD_LOGIC;
        rd_clk : STD_LOGIC;
        din : STD_LOGIC_VECTOR(115 DOWNTO 0);
        wr_en : STD_LOGIC;
        rd_en : STD_LOGIC;
        sleep : std_logic;
        injectdbiterr : STD_LOGIC;
        injectsbiterr : STD_LOGIC;
        dout : STD_LOGIC_VECTOR(115 DOWNTO 0);
        full : STD_LOGIC;
        almost_full : STD_LOGIC;
        wr_ack : STD_LOGIC;
        overflow : STD_LOGIC;
        empty : STD_LOGIC;
        almost_empty : STD_LOGIC;
        valid : STD_LOGIC;
        underflow : STD_LOGIC;
        rd_data_count : STD_LOGIC_VECTOR(3 DOWNTO 0);
        wr_data_count : STD_LOGIC_VECTOR(3 DOWNTO 0);
        sbiterr : STD_LOGIC;
        dbiterr : STD_LOGIC;
        wr_rst_busy : STD_LOGIC;
        rd_rst_busy : STD_LOGIC;
    end record;

    type t_fifo_gbt_encoder_array is array (1 to c_gbt_bank_number_of_links) of t_fifo_gbt_encoder;

    type t_fifo_commbus_encoder is record
        clk : std_logic;
        rst : STD_LOGIC;
        wr_clk : STD_LOGIC;
        rd_clk : STD_LOGIC;
        din : STD_LOGIC_VECTOR(119 DOWNTO 0);
        wr_en : STD_LOGIC;
        rd_en : STD_LOGIC;
        sleep : std_logic;
        injectdbiterr : STD_LOGIC;
        injectsbiterr : STD_LOGIC;
        dout : STD_LOGIC_VECTOR(119 DOWNTO 0);
        full : STD_LOGIC;
        almost_full : STD_LOGIC;
        wr_ack : STD_LOGIC;
        overflow : STD_LOGIC;
        empty : STD_LOGIC;
        almost_empty : STD_LOGIC;
        valid : STD_LOGIC;
        underflow : STD_LOGIC;
        rd_data_count : STD_LOGIC_VECTOR(3 DOWNTO 0);
        wr_data_count : STD_LOGIC_VECTOR(3 DOWNTO 0);
        sbiterr : STD_LOGIC;
        dbiterr : STD_LOGIC;
        wr_rst_busy : STD_LOGIC;
        rd_rst_busy : STD_LOGIC;
    end record;

    
    type t_sr is record
        D : STD_LOGIC_VECTOR(1 DOWNTO 0);
        CLK : STD_LOGIC;
        CE : STD_LOGIC;
        SCLR : STD_LOGIC;
        SSET : STD_LOGIC;
        Q : STD_LOGIC_VECTOR(1 DOWNTO 0);
    END record;

    type t_sr_readout is record
        D : STD_LOGIC_VECTOR(13 DOWNTO 0);
        CLK : STD_LOGIC;
        CE : STD_LOGIC;
        SCLR : STD_LOGIC;
        SSET : STD_LOGIC;
        Q : STD_LOGIC_VECTOR(13 DOWNTO 0);
    END record;

    type t_adc_channel_sr is array(5 downto 0) of t_sr;
    type t_adc_channel_sr_readout is array(5 downto 0) of t_sr_readout;
                
        type t_adc_readout_control is record	
    --        adc_mode	: std_logic;
            db_side              : std_logic_vector(0 downto 0);
            channel_reset        : std_logic_vector(5 downto 0);
            fc_idelay_ctrl_reset : std_logic_vector(5 downto 0);
            fc_idelay_load  : std_logic_vector(5 downto 0);
            fc_idelay_en_vtc  : std_logic_vector(5 downto 0);
            fc_idelay_count      : t_idelay_count;
    
            lg_idelay_ctrl_reset : std_logic_vector (5 downto 0);
            lg_idelay_load  : std_logic_vector(5 downto 0);
            lg_idelay_en_vtc : std_logic_vector(5 downto 0);
            lg_idelay_count      : t_idelay_count;
            lg_bitslip     : t_bitslip;
            
            hg_idelay_ctrl_reset : std_logic_vector(5 downto 0);
            hg_idelay_load  : std_logic_vector(5 downto 0);
            hg_idelay_en_vtc : std_logic_vector(5 downto 0);
            hg_bitslip     : t_bitslip;
            hg_idelay_count      : t_idelay_count;
            
            channel_enable_test_pattern : std_logic_vector (5 downto 0);
            channel_reset_test_pattern : std_logic_vector (5 downto 0);
            channel_lg_data_test_pattern            : t_adc_data;
            channel_hg_data_test_pattern            : t_adc_data;
            channel_lg_pedestal_test_lower                : t_adc_data;
            channel_lg_pedestal_test_higher                : t_adc_data;
            channel_hg_pedestal_test_lower                : t_adc_data;
            channel_hg_pedestal_test_higher                : t_adc_data;

            adc_config_done     : std_logic;
        end record;    
        type t_delay_control is record
            casc_out : std_logic; -- 1-bit output: cascade delay output to idelay input cascade
            cntvalueout : std_logic_vector(8 downto 0); -- 9-bit output: counter value output
            dataout : std_logic; -- 1-bit output: delayed data from odatain input port
            casc_in : std_logic; -- 1-bit input: cascade delay input from slave idelay cascade_out
            casc_return : std_logic; -- 1-bit input: cascade delay returning from slave idelay dataout
            ce : std_logic; -- 1-bit input: active high enable increment/decrement input
            clk : std_logic; -- 1-bit input: clock input
            cntvaluein : std_logic_vector(8 downto 0); -- 9-bit input: counter value input
            datain : std_logic;  -- 1-bit input: data input from the iobuf
            en_vtc : std_logic; -- 1-bit input: keep delay constant over vt
            idatain : std_logic;  -- 1-bit input: data input from the logic
            inc : std_logic; -- 1-bit input: increment / decrement tap delay input
            load : std_logic; -- 1-bit input: load delay_value input
            odatain : std_logic; -- 1-bit input: data input
            rst : std_logic; -- 1-bit input: asynchronous reset to the delay_value
        
        end record;
        type t_idelayctrl is record
           rdy : std_logic;       -- 1-bit output: ready output
           refclk : std_logic; -- 1-bit input: reference clock input
           rst : std_logic;   -- 1-bit input: active high reset input
        end record;
        type t_idelayctrl_array is array (0 to 5) of t_idelayctrl;
    
    constant c_delay_control : t_delay_control :=
    (
        casc_out => '0', -- 1-bit output: cascade delay output to idelay input cascade
        cntvalueout => (others=>'0'), -- 9-bit output: counter value output
        dataout => '0', -- 1-bit output: delayed data from odatain input port
        casc_in => '0', -- 1-bit input: cascade delay input from slave idelay cascade_out
        casc_return => '0', -- 1-bit input: cascade delay returning from slave idelay dataout
        ce => '0', -- 1-bit input: active high enable increment/decrement input
        clk => '0', -- 1-bit input: clock input
        cntvaluein  => (others=>'0'), -- 9-bit input: counter value input
        datain => '0',  -- 1-bit input: data input from the iobuf
        en_vtc => '1', -- 1-bit input: keep delay constant over vt
        idatain => '0',  -- 1-bit input: data input from the logic
        inc => '0', -- 1-bit input: increment / decrement tap delay input
        load => '0', -- 1-bit input: load delay_value input
        odatain => '0', -- 1-bit input: data input
        rst => '0' -- 1-bit input: asynchronous reset to the delay_value            
    );

    type t_adc_readout_delay_control_array is array (0 to 5) of t_delay_control;
    
    type t_bcr is record
        bcr : std_logic;
        bcr_tmr_error : std_logic;
        count : std_logic_vector(31 downto 0);
        count_tmr_error : std_logic;
        bcr_locked : std_logic;
        bcr_locked_tmr_error : std_logic;
        bcr_local : std_logic;
        count_local : std_logic_vector(31 downto 0);
        bcr_remote : std_logic;
        count_remote : std_logic_vector(31 downto 0);
        bcr_locked_local : std_logic;
        bcr_locked_remote : std_logic;
    end record;
    type t_bcr_tmr is array (integer range 0 to 2) of t_bcr;
--	type gbt_rxbus is record
--		data        : std_logic_vector(83 downto 0);
--		data_dv     : std_logic;
--		aligned     : std_logic;
--		gbt_ready   : std_logic; --fcarrio 02/09/2015
--		frame       : std_logic_vector(119 downto 0);
--		header      : std_logic_vector(3 downto 0);
--		errordetect : std_logic;
--	end record;
	
	
type t_mb_diff_pair is record
    q0 : t_diff_pair;
    q1 : t_diff_pair;
end record;

type t_mb_std_logic is record
    q0 : std_logic;
    q1 : std_logic;
end record;


type t_mb_std_logic_vector_32 is record
    q0 : std_logic_vector(31 downto 0);
    q1 : std_logic_vector(31 downto 0);
end record;

type t_mb_std_logic_vector_64 is record
    q0 : std_logic_vector(63 downto 0);
    q1 : std_logic_vector(63 downto 0);
end record;

type t_mb_hss_cis_std_logic_vector_8 is record
    q0 : std_logic_vector(7 downto 0);
    q1 : std_logic_vector(7 downto 0);
end record;

type t_mb_std_logic_tmr is array (integer range 0 to 2) of t_mb_std_logic;

type t_mb_rxword is record
    q0 : std_logic_vector(17 downto 0);
    q1 : std_logic_vector(17 downto 0);
end record;




type t_serial_id_interface is record
    busy : std_logic;
    family_code : std_logic_vector(7 downto 0);
    serial_number : std_logic_vector(6*8-1 downto 0);
    crc_read : std_logic_vector(7 downto 0);
    crc_calculated : std_logic_vector(7 downto 0);
    crc_ok : std_logic;
    tmr_error : std_logic;
end record;

--type t_mb_txword is std_logic_vector(31 downto 0);
	
	type t_gbt_reg_type is array (natural range <>) of std_logic_vector(31 downto 0);
	type t_gbt_reg_addr_type is array (natural range <>) of integer;

--gbttx registers
    constant c_number_of_gbttx_regs : integer := 42+1;--14+1;-- 21 + 1;
    type t_db_reg_tx is array (integer range 0 to c_number_of_gbttx_regs-1) of std_logic_vector(31 downto 0);
    type t_db_reg_tx_lut is array (integer range 0 to c_number_of_gbttx_regs-1) of std_logic_vector(15 downto 0);
    
    constant stb_mb          : integer := 0;
    constant stb_db_fwversion          : integer := 1;
    constant stb_mb_q0          : integer := 2;
    constant stb_mb_q1          : integer := 3;
    constant stb_db_debug          : integer := 4;
    constant stb_db_xadc          : integer := 5;
    constant stb_sem          : integer := 6;
--    constant stb_db_sem_icap          : integer := 7;
--    constant stb_db_xadc_control               :  integer := 8;
--    constant stb_cis_config          : integer := 9;
    constant stb_loopback          : integer := 7;--10;
--    constant stb_cs_s          : integer := 11;
--    constant stb_cs_c          : integer := 12;
--    constant stb_db_serial_id_lsb          : integer := 13;
--    constant stb_db_serial_id_msb          : integer := 14;
--    constant stb_gbt_encoder          : integer := 15;
    constant stb_gbtxa_reg          : integer := 8;--16;
--    constant stb_gbtxb_reg          : integer := 17;
--    constant stb_db_serial_id_status          : integer := 18;
    constant stb_sfp0_reg          : integer := 9; --19;
    constant stb_sfp1_reg          : integer := 10; --20;
    constant stb_pgood_reg         : integer := 11; --21;
    constant stb_tmr               : integer := 12; --22
    constant stb_db_status        : integer := 13;
    constant stb_adc_readout_status        : integer := 14;
    constant stb_adc_readout_counter_status        : integer := 15;

    constant stb_global_date  : integer := 15+1;-- 32 bit date of last commit when the project was modified. format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
    constant stb_global_time : integer := 16+1; -- 32 bit time of last commit when the project was modified. format: 00hhmmss (hex with decimal digits, no digit greater than 9 is used)
    constant stb_global_ver : integer := 17+1; -- 32 bit last version tag when the project was modified. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    constant stb_global_sha : integer := 18+1; -- 32 bit git hash (sha) of the last commit when the project was modified.
    constant stb_top_ver : integer := 19+1; -- 32 bit top directory version, containing the hog.conf file and other files. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    constant stb_top_sha : integer := 20+1; -- 32 bit top directory version, containing the hog.conf file and other files.
    constant stb_con_ver : integer := 21+1; -- 32 bit the version of the constraint files. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    constant stb_con_sha : integer := 22+1; -- 32 bit the git commit hash (sha) of the constraint files.
    constant stb_hog_ver : integer := 23+1; -- 32 bit hog submodule version. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    constant stb_hog_sha : integer := 24+1; -- 32 bit hog submodule git commit hash (sha).
    constant stb_xml_ver : integer := 25+1; -- 32 bit (optional) ipbus xml version. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    constant stb_xml_sha : integer := 26+1; -- 32 bit (optional) ipbus xml git commit hash (sha).
    constant stb_dna_2 : integer := 27+1;
    constant stb_dna_1 : integer := 28+1;
    constant stb_dna_0 : integer := 29+1;
    constant stb_running_time_status : integer := 30+1;
    constant stb_integrator_status : integer := 31+1;
    constant stb_mb_jtag_id_q0 : integer := 32+1;
    constant stb_mb_jtag_id_q1 : integer := 33+1;
    -- sfp+ reg block ram port b readback (see cfb_sfp_reg_address): bits 6:0/14:8 echo the
    -- commanded per-side address, bits 23:16/31:24 carry the resulting read value
    constant stb_sfp_reg_readback : integer := 34+1;

    -- sff-8472 A2h ddm fields (see t_sfp_regs / c_sfp_* above): each register packs both
    -- sfp sides into one 32-bit word, side 0 in bits 15:0, side 1 in bits 31:16.
    constant stb_sfp_ddm_temperature       : integer := 35+1;
    constant stb_sfp_ddm_vcc               : integer := 36+1;
    constant stb_sfp_ddm_tx_bias_current   : integer := 37+1;
    constant stb_sfp_ddm_tx_power          : integer := 38+1;
    constant stb_sfp_ddm_rx_power          : integer := 39+1;
    constant stb_sfp_ddm_laser_temperature : integer := 40+1;
    constant stb_sfp_ddm_tec_current       : integer := 41+1;

constant c_db_reg_tx_lut : t_db_reg_tx_lut := (
    x"0" & x"001", --stb_mb,
    x"0" & x"F0F", --stb_db_fwversion,
    x"0" & x"012", --stb_mb_q0,
    x"0" & x"013", --stb_mb_q1,
    x"0" & x"D0D", --stb_db_debug,
    x"0" & x"015", --stb_db_xadc,
    x"0" & x"016", --stb_sem,
--    x"0" & x"310", --stb_db_sem_icap,
--    x"0" & x"320", --stb_db_xadc_control,
--    x"0" & x"121", --stb_cis_config_w,
    x"0" & x"FFF", --stb_loopback,
--    x"0" & x"0e1", --stb_cs_s_w,
--    x"0" & x"0e2", --stb_cs_c_w,
--    x"0" & x"200", --db_serial_id_lsb,
--    x"0" & x"201", --db_serial_id_msb,
--    x"0" & x"300", --gbt_encoder,
    x"0" & x"330", --stb_gbtxa_reg,
--    x"0" & x"331", --stb_gbtxb_reg,
--    x"0" & x"202", --stb_db_serial_id_status,
    x"0" & x"340", --stb_sfp0_reg,
    x"0" & x"341", --stb_sfp1_reg,
    x"0" & x"AFF", --stb_pgood_reg,
    x"0" & x"00C", -- stb_tmr,
    x"0" & x"00D", --stb_db_status
    x"0" & x"00E", --stb_adc_readout_status
    x"0" & x"00F", --stb_adc_readout_counter_status
    
    x"0" & x"100", -- stb_global_date  : integer := 15;-- 32 bit date of last commit when the project was modified. format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)
    x"0" & x"101", -- stb_global_time : integer := 16; -- 32 bit time of last commit when the project was modified. format: 00hhmmss (hex with decimal digits, no digit greater than 9 is used)
    x"0" & x"102", -- stb_global_ver : integer := 17; -- 32 bit last version tag when the project was modified. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    x"0" & x"103", -- stb_global_sha : integer := 18; -- 32 bit git hash (sha) of the last commit when the project was modified.
    x"0" & x"104", -- stb_top_ver : integer := 19; -- 32 bit top directory version, containing the hog.conf file and other files. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    x"0" & x"105", -- stb_top_sha : integer := 20; -- 32 bit top directory version, containing the hog.conf file and other files.
    x"0" & x"106", -- stb_con_ver : integer := 21; -- 32 bit the version of the constraint files. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    x"0" & x"107", -- stb_con_sha : integer := 22; -- 32 bit the git commit hash (sha) of the constraint files.
    x"0" & x"108", -- stb_hog_ver : integer := 23; -- 32 bit hog submodule version. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    x"0" & x"109", -- stb_hog_sha : integer := 24; -- 32 bit hog submodule git commit hash (sha).
    x"0" & x"10A", -- stb_xml_ver : integer := 25; -- 32 bit (optional) ipbus xml version. the version of the form m.m.p is encoded in hexadecimal as mmmmpppp
    x"0" & x"10B", -- stb_xml_sha : integer := 26; -- 32 bit (optional) ipbus xml git commit hash (sha).
    x"0" & x"10C", --stb_dna_2
    x"0" & x"10D", --stb_dna_1
    x"0" & x"10E", --stb_dna_0
    x"0" & x"10F", --stb_running_time_status
    x"0" & x"00A", --stb_integrator_status
    x"0" & x"018", --stb_mb_jtag_id_q0
    x"0" & x"019", --stb_mb_jtag_id_q1
    x"0" & x"01A", --stb_sfp_reg_readback
    x"0" & x"342", --stb_sfp_ddm_temperature
    x"0" & x"343", --stb_sfp_ddm_vcc
    x"0" & x"344", --stb_sfp_ddm_tx_bias_current
    x"0" & x"345", --stb_sfp_ddm_tx_power
    x"0" & x"346", --stb_sfp_ddm_rx_power
    x"0" & x"347", --stb_sfp_ddm_laser_temperature
    x"0" & x"348"  --stb_sfp_ddm_tec_current
    );




-- new code for configbus register arrays
    constant c_number_of_cfgbus_regs : integer := 15+1; --75 + 1;
    type t_db_reg_rx is array (integer range 0 to c_number_of_cfgbus_regs-1) of std_logic_vector(31 downto 0);
    type t_db_reg_rx_tmr is array (integer range 0 to 2) of t_db_reg_rx;
    type t_db_reg_rx_lut is array (integer range 0 to c_number_of_cfgbus_regs-1) of std_logic_vector(11 downto 0);

    type t_cfgbus_bitslice is array (7 downto 0) of std_logic_vector(1 downto 0);

    -- names of configbus registers
    
        constant cfb_register_zero          : integer := 0;
        constant cfb_mb_adc_config          : integer := 1;
        constant cfb_mb_phase_config        : integer := 2;
        constant cfb_cis_config             : integer := 3;
        constant cfb_sfp_reg_address         : integer := 4; -- sfp+ reg block ram port b address, per side: bits 6:0 = side 0, bits 14:8 = side 1
        constant cfb_integrator_interval    : integer := 5;
        constant cfb_tx_reg_address          : integer := 6;
        constant cfb_sem_control            : integer := 7;
        constant cfb_tx_control             : integer := 8;   
        constant cfb_gbtx_reg_config        : integer := 9;
        constant cfb_strobe_lenght             : integer := 10;
        constant cfb_loopback               : integer := 11;
        constant cfb_db_fw_version             : integer := 12;
        constant cfb_db_debug               : integer := 13;
        constant cfb_db_reg_mask       : integer := 14;
        constant cfb_strobe_reg             : integer := 15;
        constant bc_number                  : integer := 4;--16; -- bunch crossing number counter
--        constant cfb_adc_readout       : integer := 16;
--        constant cfb_wr_strobe              : integer := 17; -- strobe indicating write to a cfb register 
     
     --advanced configbus registers
--        constant adv_cfg_gty_txdiffctrl     : integer := 18;
--        constant adv_cfg_gty_txpostcursor   : integer := 19;
--        constant adv_cfg_gty_txprecursor    : integer := 20;
--        constant adv_cfg_gty_txmaincursor   : integer := 21;
--        constant adv_cfg_txrawtestword      : integer := 22;
--        constant adv_cfg_commbus_address      : integer := 23;
--        constant adv_cfg_commbus_value      : integer := 24;
--        constant adv_cfg_commbus_header_crc      : integer := 35; --***
--        constant adc_config_module      : integer := 25;
--        constant adc_register_config      : integer := 26;
--        constant adc_readout_idelay3_lg_0      : integer := 27;
--        constant adc_readout_idelay3_lg_1      : integer := 28;
--        constant adc_readout_idelay3_lg_2      : integer := 29;
--        constant adc_readout_idelay3_lg_3      : integer := 30;
--        constant adc_readout_idelay3_lg_4      : integer := 31;
--        constant adc_readout_idelay3_lg_5      : integer := 32;
--        constant adc_readout_idelay3_hg_0      : integer := 33;
--        constant adc_readout_idelay3_hg_1      : integer := 34;
--        constant adc_readout_idelay3_hg_2      : integer := 35;
--        constant adc_readout_idelay3_hg_3      : integer := 36;
--        constant adc_readout_idelay3_hg_4      : integer := 37;
--        constant adc_readout_idelay3_hg_5      : integer := 38;
--        constant adc_readout_idelay3_fc_0      : integer := 39;
--        constant adc_readout_idelay3_fc_1      : integer := 40;
--        constant adc_readout_idelay3_fc_2      : integer := 41;
--        constant adc_readout_idelay3_fc_3      : integer := 42;
--        constant adc_readout_idelay3_fc_4      : integer := 43;
--        constant adc_readout_idelay3_fc_5      : integer := 44;

--        constant adc_readout_pedestal_stability_test_lg_0      : integer := 45;
--        constant adc_readout_pedestal_stability_test_lg_1      : integer := 46;
--        constant adc_readout_pedestal_stability_test_lg_2      : integer := 47;
--        constant adc_readout_pedestal_stability_test_lg_3      : integer := 48;
--        constant adc_readout_pedestal_stability_test_lg_4      : integer := 49;
--        constant adc_readout_pedestal_stability_test_lg_5      : integer := 50;
        
--        constant adc_readout_pedestal_stability_test_hg_0      : integer := 51;
--        constant adc_readout_pedestal_stability_test_hg_1      : integer := 52;
--        constant adc_readout_pedestal_stability_test_hg_2      : integer := 53;
--        constant adc_readout_pedestal_stability_test_hg_3      : integer := 54;
--        constant adc_readout_pedestal_stability_test_hg_4      : integer := 55;
--        constant adc_readout_pedestal_stability_test_hg_5      : integer := 56;

--        constant adc_readout_test_pattern_lg_0                 :  integer := 57;
--        constant adc_readout_test_pattern_lg_1                 :  integer := 58;
--        constant adc_readout_test_pattern_lg_2                 :  integer := 59;
--        constant adc_readout_test_pattern_lg_3                 :  integer := 60;
--        constant adc_readout_test_pattern_lg_4                 :  integer := 61;
--        constant adc_readout_test_pattern_lg_5                 :  integer := 62;

--        constant adc_readout_test_pattern_hg_0                 :  integer := 63;
--        constant adc_readout_test_pattern_hg_1                 :  integer := 64;
--        constant adc_readout_test_pattern_hg_2                 :  integer := 65;
--        constant adc_readout_test_pattern_hg_3                 :  integer := 66;
--        constant adc_readout_test_pattern_hg_4                 :  integer := 67;
--        constant adc_readout_test_pattern_hg_5                 :  integer := 68;
        
        
--        constant adc_mb_jtag              : integer := 69;
--        constant cfb_command_counter              : integer := 70;
--        constant cfb_gbt_sc_address              : integer := 71;
--        constant cfb_led0_clock_gear              : integer := 72;
--        constant cfb_led1_clock_gear              : integer := 73;
--        constant cfb_led2_clock_gear              : integer := 74;
--        constant cfb_led3_clock_gear              : integer := 75;
        constant c_dbmaster_reset_bit : integer := 0;
        constant c_mb1_reset_bit : integer := 1;
        constant c_mb0_reset_bit : integer := 2;
        constant c_master_reset_bit : integer := 3;
        constant c_clknet_reset_bit : integer := 4;
        constant c_commbus_reset_bit : integer := 5;
        constant c_cfgbus_reset_bit : integer := 6;
        constant c_adc_readout_reset_bit : integer := 7;
        constant c_sem_reset_bit : integer := 8;
        constant c_adc_config_reset_bit : integer := 9;  
        constant c_cis_reset_bit  : integer := 10;  
        constant c_integrator_reset_bit : integer := 11;
        constant c_gbt_reset_bit : integer := 12; 
        constant c_gth_reset_bit : integer := 13;
        constant c_adc_channel_reset_bit : integer := 14;
        constant c_gth_reset_tx_pll_and_datapath_bit : integer := 15;
        constant c_gth_reset_tx_datapath_bit : integer := 16;
        constant c_gth_buffbypass_tx_reset_bit : integer := 17;
        constant c_gth_buffbypass_tx_start_use_bit : integer := 18;
        constant c_adc_readout_reset_channel_0_bit : integer := 19;
        constant c_adc_readout_reset_channel_1_bit : integer := 20;
        constant c_adc_readout_reset_channel_2_bit : integer := 21;
        constant c_adc_readout_reset_channel_3_bit : integer := 22;
        constant c_adc_readout_reset_channel_4_bit : integer := 23;
        constant c_adc_readout_reset_channel_5_bit : integer := 24;
        
        constant c_gbt_ch0_reset_bit : integer := 25; 
        constant c_gbt_ch1_reset_bit : integer := 26;
        constant c_gth_ch0_reset_bit : integer := 27; 
        constant c_gth_ch1_reset_bit : integer := 28;
        constant c_gbt_encoder_reset_bit : integer := 29;
        
        constant c_fpga_hard_reset_bit : integer := 31;
        
        constant c_gbtxb_configsel_bit : integer := 31;
        constant c_gbtxa_configsel_bit : integer := 30;
        constant c_gbtx_control_bit : integer := 29;
        constant c_gbtx_default_config_bit : integer := 28;
        constant c_gbtx_trigger_i2c_operation_bit : integer := 27;
        constant c_gbtx_i2c_read_write_operation_bit : integer := 26;
        
        
        --cfb_db_debug
        -- 23 downto 16 gbtx i2c speed
        -- 15 downto 14 related to gbt bank phase status
        constant c_db_debug_gbt_cdc_phase_array : integer :=15;
        constant c_db_debug_cis_tp_clk_mux : integer := 9;
        constant c_db_debug_adc_clk_mux : integer := 10;
        constant c_db_debug_gbtx_deskew_clk_mux : integer := 8;
        constant c_db_debug_mb_adc_config_mode : integer := 11;
        constant c_db_debug_mb_adc_config_trigger : integer := 12;
        constant c_db_debug_gbt_txword_phase : integer := 13;
        constant c_db_debug_cfgbus_strobe_persist : integer := 14;
        constant c_db_debug_skip_main_sm : integer :=24;
        constant c_db_debug_mb_jtag_read_enable_q0 : integer := 25;
        constant c_db_debug_mb_jtag_read_enable_q1 : integer := 26;
        
        --cfb_tx_control
        constant c_gbt_encoder_tx_fc_lg_bit : integer := 0;
        constant c_gbt_encoder_tx_fc_hg_bit : integer := 1;
        
        constant c_sem_20bit_word_mux_bit : integer := 31;
        constant c_sem_command_strobe_bit : integer := 30;
        constant c_sem_cap_gnt_bit : integer := 29;
        constant c_sem_cap_rel_bit : integer := 28;        

        constant c_sem_status_heartbeat_bit : integer :=0;
        constant c_sem_status_initialization_bit : integer :=1;
        constant c_sem_status_observation_bit : integer :=2;
        constant c_sem_status_correction_bit : integer :=3;
        constant c_sem_status_classification_bit : integer :=4;
        constant c_sem_status_injection_bit : integer :=5;
        constant c_sem_status_essential_bit : integer :=6;
        constant c_sem_status_detect_only_bit : integer :=7;
        constant c_sem_command_busy_bit : integer :=8;
        constant c_sem_monitor_txfull_bit : integer :=9;
        constant c_sem_status_uncorrectable_bit : integer :=10;
        constant c_sem_status_diagnostic_scan_bit : integer :=11;
        constant c_sem_status_command_strobe_bit : integer := 12;
        constant c_sem_status_cap_gnt_bit : integer := 13;
        constant c_sem_status_cap_rel_bit : integer := 14;  
        constant c_sem_status_cap_req_bit : integer := 15;  

        constant c_db_status_bcr_locked_bit : integer :=0;
        
        
        constant c_adc_config_done_bit : integer :=0;
        type t_adc_integer_bit_lut is array (0 to 5) of integer;
        constant c_adc_readout_status_adc_missalignment_bit : t_adc_integer_bit_lut := (1,2,3,4,5,6);
        constant c_adc_readout_status_adc_channel_missed_locked_bit : t_adc_integer_bit_lut := (7,8,9,10,11,12);
        constant c_adc_readout_status_adc_channel_locked_bit : t_adc_integer_bit_lut := (13,14,15,16,17,18);
        constant c_adc_readout_channel_phase_offset_bit : t_adc_integer_bit_lut :=(19, 20, 21, 22, 23, 24);
--        constant c_adc_readout_status_adc0_missalignment_bit : integer :=1;
--        constant c_adc_readout_status_adc1_missalignment_bit : integer :=2;
--        constant c_adc_readout_status_adc2_missalignment_bit : integer :=3;
--        constant c_adc_readout_status_adc3_missalignment_bit : integer :=4;
--        constant c_adc_readout_status_adc4_missalignment_bit : integer :=5;
--        constant c_adc_readout_status_adc5_missalignment_bit : integer :=6;



        constant c_db_status_mb_tx_collission_q0_bit : integer :=1;
        constant c_db_status_mb_tx_collission_q1_bit : integer :=2;

        constant c_db_status_db_leds_bit_lsb : integer :=16;
        constant c_db_status_db_leds_bit_msb : integer :=19;
        constant c_db_status_md_number_bit_lsb : integer :=20;
        constant c_db_status_md_number_bit_msb : integer :=23;
        constant c_db_status_mb_integrator_latency_bit_lsb : integer :=0;
        constant c_db_status_mb_integrator_latency_bit_msb : integer :=15;
        
        constant c_sfp_status_mod_los_bit : integer :=0;
        constant c_sfp_status_mod_abs_bit : integer :=1;
        constant c_sfp_status_tx_fault_bit : integer :=2;
        
        
    constant c_db_reg_rx_lut : t_db_reg_rx_lut := (
        x"000", --cfg_register_zero,
        x"001", --cfb_mb_adc_config,
        x"002", --cfb_mb_phase_config,
        x"121", --cfb_cis_config,
        x"004", --cfb_sfp_reg_address,
        x"115", --cfb_integrator_interval,
        x"006", --cfb_tx_reg_address,
        x"007", --cfb_sem_control,
        x"008", --cfb_tx_control,
        x"009", --cfb_gbtx_reg_config,
        x"00a", --cfb_strobe_lenght,
        x"fff", --cfb_loopback,
        x"00c", --cfb_db_cfg_fw_version,
        x"00d", --cfb_db_debug,
        x"00e", --cfb_db_reg_mask,
        x"00f" --cfb_strobe_reg,
--        x"010" --cfb_adc_readout,
--        x"011", --cfb_wr_strobe,
--     --advanced configbus registers
--        x"012", --adv_cfg_gty_txdiffctrl,
--        x"013", --adv_cfg_gty_txpostcursor,
--        x"014", --adv_cfg_gty_txprecursor,
--        x"015", --adv_cfg_gty_txmaincursor,
--        x"016", --adv_cfg_txrawtestword,
--        x"017", --adv_cfg_commbus_address,
--        x"018", --adv_cfg_commbus_value,
--        x"019", --adc_config_module,
--        x"01a", --adc_lg_register_config,
--        x"a00", --adc_lg_readout_idelay3_0,
--        x"a01", --adc_lg_readout_idelay3_1,
--        x"a02", --adc_lg_readout_idelay3_2,
--        x"a03", --adc_lg_readout_idelay3_3,
--        x"a04", --adc_lg_readout_idelay3_4,
--        x"a05", --adc_lg_readout_idelay3_5
--        x"a10", --adc_hg_readout_idelay3_0,
--        x"a11", --adc_hg_readout_idelay3_1,
--        x"a12", --adc_hg_readout_idelay3_2,
--        x"a13", --adc_hg_readout_idelay3_3,
--        x"a14", --adc_hg_readout_idelay3_4,
--        x"a15", --adc_hg_readout_idelay3_5
--        x"af0", --adc_fc_readout_idelay3_0,
--        x"af1", --adc_fc_readout_idelay3_1,
--        x"af2", --adc_fc_readout_idelay3_2,
--        x"af3", --adc_fc_readout_idelay3_3,
--        x"af4", --adc_fc_readout_idelay3_4,
--        x"af5", --adc_fc_readout_idelay3_5
--        x"ac0", --adc_readout_pedestal_stability_test_lg_0
--        x"ac1", --adc_readout_pedestal_stability_test_lg_1
--        x"ac2", --adc_readout_pedestal_stability_test_lg_2
--        x"ac3", --adc_readout_pedestal_stability_test_lg_3
--        x"ac4", --adc_readout_pedestal_stability_test_lg_4
--        x"ac5", --adc_readout_pedestal_stability_test_lg_5
--        x"ad0", --adc_readout_pedestal_stability_test_lg_0
--        x"ad1", --adc_readout_pedestal_stability_test_lg_1
--        x"ad2", --adc_readout_pedestal_stability_test_lg_2
--        x"ad3", --adc_readout_pedestal_stability_test_lg_3
--        x"ad4", --adc_readout_pedestal_stability_test_lg_4
--        x"ad5", --adc_readout_pedestal_stability_test_lg_5
        
--        x"aa0", --adc_readout_test_pattern_lg_0
--        x"aa1", --adc_readout_test_pattern_lg_1
--        x"aa2", --adc_readout_test_pattern_lg_2
--        x"aa3", --adc_readout_test_pattern_lg_3
--        x"aa4", --adc_readout_test_pattern_lg_4
--        x"aa5", --adc_readout_test_pattern_lg_5
--        x"ab0", --adc_readout_test_pattern_hg_0
--        x"ab1", --adc_readout_test_pattern_hg_1
--        x"ab2", --adc_readout_test_pattern_hg_2
--        x"ab3", --adc_readout_test_pattern_hg_3
--        x"ab4", --adc_readout_test_pattern_hg_4
--        x"ab5", --adc_readout_test_pattern_hg_5

--        x"666", --adc_mb_jtag
--        x"300", --cfb_command_counter
--        x"023", --cfb_gbt_sc_address
--        x"111", --cfb_led0_clock_gear
--        x"222", --cfb_led1_clock_gear
--        x"333", --cfb_led2_clock_gear
--        x"444" --cfb_led3_clock_gear
        --x"024", --cfb_gbt_sc_address
        );        


    constant c_db_reg_rx : t_db_reg_rx:= (
        cfb_integrator_interval => x"0000000a",
        cfb_tx_control => "00000000000000000000000000001010",
        cfb_gbtx_reg_config => "00000000000000000000000000000000",
        cfb_strobe_lenght => "00000000000000000000000100000000",
        cfb_db_fw_version => c_fw_version,
        cfb_tx_reg_address => std_logic_vector(to_unsigned(stb_db_fwversion,32)),
        cfb_sem_control => "00100000000000000000000100000000", --"00100000000000000000000100000000", --cfb_sem_control => "00000000000000000000000100000000",
        cfb_db_debug => "00000000000000000000001000000000",
        
        cfb_db_reg_mask => (others=>'1'),
--        adv_cfg_gty_txdiffctrl =>"00000000000000000000000010001000",
--        adv_cfg_gty_txpostcursor =>"00000000000000000000001000010000",
--        adv_cfg_gty_txprecursor =>"00000000000000000000001000010000",
--        adv_cfg_gty_txmaincursor =>"00000000000000000010000001000000",
--        adc_config_module => "00000000000000000000000000011100",
--        adc_readout_idelay3_lg_0 => "00000100000000000000010000000000",
--        adc_readout_idelay3_lg_1 => "00000100000000000000010000000000",
--        adc_readout_idelay3_lg_2 => "00000100000000000000010000000000",
--        adc_readout_idelay3_lg_3 => "00000100000000000000010000000000",
--        adc_readout_idelay3_lg_4 => "00000100000000000000010000000000",
--        adc_readout_idelay3_lg_5 => "00000100000000000000010000000000",
--        adc_readout_idelay3_hg_0 => "00000100000000000000010000000000",
--        adc_readout_idelay3_hg_1 => "00000100000000000000010000000000",
--        adc_readout_idelay3_hg_2 => "00000100000000000000010000000000",
--        adc_readout_idelay3_hg_3 => "00000100000000000000010000000000",
--        adc_readout_idelay3_hg_4 => "00000100000000000000010000000000",
--        adc_readout_idelay3_hg_5 => "00000100000000000000010000000000",
        
--        cfb_led0_clock_gear => "00000000000011101000010010000000",
--        cfb_led1_clock_gear => "00000000000111010000100100000000",
--        cfb_led2_clock_gear => "00000000001110100001001000000000",
--        cfb_led3_clock_gear => "00000000011101000010010000000000",
    
        others=>(others=>'0')
    );

type t_dsp48_signed_substract is record
    clk : std_logic;
    A : STD_LOGIC_VECTOR(14 DOWNTO 0);
    B : STD_LOGIC_VECTOR(14 DOWNTO 0);
    S : STD_LOGIC_VECTOR(14 DOWNTO 0);
    
end record;

type t_adc_dsp48_signed_substract is array (0 to 5) of t_dsp48_signed_substract ;
type t_mb_driver is record
        txword_in       : std_logic_vector(31 downto 0);
        rxword_out       : t_mb_rxword;
        rx_done_out       : t_mb_std_logic;
        tx_done_out       : t_mb_std_logic;
        mb_tx_collission_out : t_mb_std_logic;
        leds_out              : std_logic_vector(3 downto 0);
end record;

type t_integrator_data is record
    q0 : std_logic_vector(15 downto 0);
    q1 : std_logic_vector(15 downto 0);
end record;

--type t_integrator_data is array (0 to 1) of  std_logic_vector(15 downto 0);
type t_integrator_adc_data is array (0 to 5) of std_logic_vector(15 downto 0); 

type t_mb_integrator is record
    integrator_data : t_integrator_data; 
    end_of_read_quadrant : t_mb_std_logic;
    end_of_read : std_logic;
    integrator_adc_data : t_integrator_adc_data;
    bc_count_readout : std_logic_vector(15 downto 0);
    --gbt       : std_logic_vector(4 downto 0);
    orbit_counter : std_logic_VECTOR (7 DOWNTO 0);
    tmr_error : std_logic;
end record;


type t_cis_interface is record
   tmr_enabled : std_logic;
   tmr_error_tpl : t_mb_std_logic; --std_logic;
   tmr_error_tph : t_mb_std_logic;
end record;

type t_mb_interface is record
    mb_reset : t_mb_std_logic;
    mb_driver : t_mb_driver;
    adc_readout : t_adc_readout;
    adc_readout_control : t_adc_readout_control;
    mb_integrator : t_mb_integrator;
    cis_interface : t_cis_interface;
    mb_jtag_id : t_mb_std_logic_vector_32;
    mb_jtag_done : t_mb_std_logic;
end record;



-- lookup table for mb register addresses
	
	type t_mb_addr_lut is array (integer range 0 to 15) of std_logic_vector(3 downto 0);
	constant c_mb_to_ppr : t_mb_addr_lut := (
		x"f", x"f", x"0", x"1",
		x"4", x"f", x"f", x"f",
		x"4", x"5", x"2", x"3",
		x"6", x"f", x"f", x"f");
	
--  lookup table to convert between 3in1 card return word to srod 3in1 address

	constant c_mb_to_pmt_addr : t_mb_addr_lut := (
		x"c", x"a", x"8", x"f",  --side a, fpga 0, tube 0-2
		x"6", x"4", x"2", x"f",  --side a, fpga 1, tube 0-2
		x"d", x"b", x"9", x"f",  --side b, fpga 0, tube 0-2
		x"7", x"5", x"3", x"f"); --side b, fpga 1, tube 0-2

	type gbt_status is record
		mmcm_lock   : std_logic;
		qpll_lock   : std_logic;
		cpll_lock   : std_logic;
		eyes_error  : std_logic;
		error_count : std_logic_vector(15 downto 0);
		error_count2 : std_logic_vector(15 downto 0);
		error_timer : std_logic_vector(19 downto 0);
		error_timer2 : std_logic_vector(19 downto 0);
	end record;



--mmcm clock register control
type t_mmcm_clk_control is record
 phase_mux : std_logic_vector(2 downto 0);
 delay_time : std_logic_vector(5 downto 0);
end record;

type t_mmcm_clk_control_array is array (0 to 1) of t_mmcm_clk_control;



-- gth signal control 
    type t_gth_tx_control is record
      txdiffctrl : STD_LOGIC_VECTOR(9 DOWNTO 0); -- Driver swing control (10110 = 809 mV)
      txpostcursor : STD_LOGIC_VECTOR(9 DOWNTO 0); -- Post-cursor TX pre-emphasis (10000 = 4.44 dB)
      txprecursor : STD_LOGIC_VECTOR(9 DOWNTO 0); -- Pre-cursor TX pre-emphasis (1000 = 4.44 dB)
      txmaincursor : STD_LOGIC_VECTOR(13 DOWNTO 0); -- main cursos for signal swing control
      txrawtestword : STD_LOGIC_VECTOR(119 DOWNTO 0); -- main cursos for signal swing control
    end record;
    
    --****************************************************************************************************
    --****************************************************************************************************
    
    
    --****************************************************************************************************
    --****************************************************************************************************


    constant c_number_of_led_regs : integer := 16 - 1;
        type t_led_regs is array (integer range 0 to c_number_of_led_regs) of std_logic_vector(3 downto 0);

        -- names of configbus registers
        
        constant leds_main_sm          : integer := 0;
        constant leds_clk_interface          : integer := 1;
        constant leds_cfgbus_interface        : integer := 2;
        constant leds_gbtx_i2c             : integer := 3;
        constant leds_mb0_mmcm             : integer := 4;
        constant leds_mb1_mmcm    : integer := 5;
        constant leds_serial_id          : integer := 6;
        constant leds_system            : integer := 7;
        constant leds_commbus             : integer := 8;   
        constant leds_gbtx_reg_config        : integer := 9;
        constant leds_system_management        : integer := 10;
        constant leds_mb_interface        : integer := 11;
        constant leds_sfp_interface        : integer := 12;
        
        constant leds_user        : integer := 15;



    type t_adc_data_in is array (0 to 5) of t_diff_pair;
    type t_adc_clk_in is array (0 to 5) of t_diff_pair;
    type t_adc_data_pipeline is array (1 downto 0) of t_adc_data;
    
    type t_cfgbus_data_in is array (0 to 7) of t_diff_pair;

    type t_db_gth_clock_inputs is record
        gth_refclk_loc, gth_refclk_rem, gth_gtgrefclk : std_logic_vector(0 downto 0);
    end record;

    type t_db_gth_clock_outputs is record
        gth_gtgrefclk, gth_gtgrefclk_fabric, gth_gtgrefclk_fabric_div, bufgce_div_ctrl_reset : std_logic_vector(1 downto 0);
    end record;

    type t_BUFG_GT_SYNC is record
        CESYNC : std_logic; -- 1-bit output: Synchronized CE
        CLRSYNC : std_logic; -- 1-bit output: Synchronized CLR
        CE : std_logic; -- 1-bit input: Asynchronous enable
        CLK : std_logic; -- 1-bit input: Clock
        CLR : std_logic; -- 1-bit input: Asynchronous clear
    end record;

    type t_mmcm_control is record
        daddr_in : std_logic_vector(6 downto 0);
        den_in :std_logic;
        din_in   : std_logic_vector(15 downto 0);
        dout_out : std_logic_vector(15 downto 0);
        drdy_out :std_logic;
        dwe_in :std_logic;
        --Dynamic phase shift ports
        psclk_in :std_logic;
        psen_in :std_logic;
        psincdec_in :std_logic;
        psdone_out :std_logic;
       -- Status and control signals                
        reset_in :std_logic;
        locked_out :std_logic;
        input_clk_stopped_out :std_logic;
        clkfb_stopped_out :std_logic;
        cddcdone_out :std_logic;
        cddcreq_in :std_logic;
    end record;

    type t_db_clknet is record
        --debug
        gbt_cdc_gearbox_phase : std_logic_vector(1 downto 0);
        skip_main_sm : std_logic;
        running_time : std_logic_vector(31 downto 0);
        reset_main_sm : std_logic;
        force_gtx_i2c_config : std_logic;
        reset_gbtx_i2c_interface : std_logic;
        adc_readout_high_threshold : std_logic_vector(11 downto 0);
        adc_readout_low_threshold : std_logic_vector(11 downto 0);
        adc_readout_threshold_select_channel : std_logic_vector(2 downto 0);
        cis_enable          : std_logic;
        cis_gain 				: std_logic; 
        cis_bcid_charge 		: std_logic_vector(11 downto 0);  
        cis_bcid_discharge 	    : std_logic_vector(11 downto 0);

        --configuration
        db_side : std_logic_vector(0 downto 0);
        md_number : std_logic_vector(3 downto 0);
        db_leds : std_logic_vector(3 downto 0);
        gbtx_rxready : std_logic_vector(1 downto 0);
        gbtx_datavalid : std_logic_vector(1 downto 0);
        clksel : std_logic;                    -- signal to select clock source (which gbtx)
        gth_wordclk_sel : std_logic;                    -- signal to select word clock source
        cpllclksel : std_logic_vector(2 downto 0);                    -- signal to select cpll clock source
        qpllclksel : std_logic_vector(2 downto 0);                    -- signal to select qpll clock source
        txsysclksel : std_logic_vector(1 downto 0);
        rxsysclksel : std_logic_vector(1 downto 0);
        rxoutclksel : std_logic_vector(2 downto 0);
        txoutclksel : std_logic_vector(2 downto 0);
        txpllclksel : std_logic_vector(1 downto 0);
        rxpllclksel : std_logic_vector(1 downto 0);

        
        bcr : t_bcr;
        bcr_count : std_logic_vector(31 downto 0);
        reg_rx_strobe : std_logic_vector(31 downto 0);--integer range 0 to 15;
        
        --status
        locked_osc : std_logic;
        locked_db : std_logic;
        locked_cfgbus : std_logic;
        locked_mb_q0 : std_logic;
        locked_mb_q1 : std_logic;
        locked_tp_q0 : std_logic;
        locked_tp_q1 : std_logic;
        
        --general clocks
        --freerun_clk40 : std_logic;
        clk40    : std_logic;
        --clk100    : std_logic;
        clk80    : std_logic;
        clk120    : std_logic;
        clk160    : std_logic;
        clk240    : std_logic;
        clk640    : std_logic;
--        clk280    : std_logic;
        --clk40_phase_90    : std_logic;
        --clk40_phase_180    : std_logic;
        --clk40_phase_270    : std_logic;       
        
        --cis hss clk
        cis_hss_clk80 : t_diff_pair; 
        
        --slow clocks
        clk_1hz : std_logic;
        clk_10hz : std_logic;
        clk_100hz : std_logic;
        clk_1khz : std_logic;
        clk_100khz : std_logic;
        
        --oscillator clocks
        osc_clk40    : std_logic;
        osc_clk100    : std_logic;
        osc_clk80    : std_logic;
        osc_clk200   : std_logic;
        osc_clk400   : std_logic;
--        osc_clk160    : std_logic;
--        osc_clk280    : std_logic;
--        osc_clk40_phase_90    : std_logic;
--        osc_clk40_phase_180    : std_logic;
--        osc_clk40_phase_270    : std_logic;
       
        --db clks
--        db_clk40     : std_logic;                  -- 40/80/120/160 clocks to fpga logic fabric
--        db_clk80     : std_logic;
--        db_clk160     : std_logic;
--        db_clk280     : std_logic;
--        db_clk40_phase_90    : std_logic;
--        db_clk40_phase_180    : std_logic;
--        db_clk40_phase_270    : std_logic;

        --commbus clks
        --commbus_bitclk_tx : std_logic;
        --commbus_bitclk_rx : std_logic;
        
        
        --cfgbus clks
        cfgbus_clk40_local : std_logic;
        cfgbus_clk40_remote : std_logic;
        cfgbus_clk40    : std_logic;
        cfgbus_clk40_phase_90    : std_logic;
        cfgbus_clk40_phase_180   : std_logic;
        cfgbus_clk40_phase_270   : std_logic;
        cfgbus_clk80   : std_logic;
        cfgbus_clk160   : std_logic;
        cfgbus_clk280   : std_logic;
--        cfgbus_reset_local : std_logic;
--        cfgbus_reset_remote : std_logic;        
--        cfgbus_clk320   : std_logic;
        

        --mb clks
        mmcm_gbt40_mb_q0    : t_mmcm_control;
        mmcm_gbt40_mb_q1    : t_mmcm_control;
        
        mb_fpga_reset_low         :  t_mb_std_logic;
        
        mb_clk40_q0_dp    : t_diff_pair;
        mb_clk40_q1_dp    : t_diff_pair;
        mb_clk40_q0_local : std_logic;
        mb_clk40_q0_remote : std_logic;
        mb_clk40_q1_local : std_logic;
        mb_clk40_q1_remote : std_logic;
        mb_clk40_q0 : std_logic;
        mb_clk40_q1 : std_logic;


        mb_clk40    : t_mb_std_logic;--std_logic_vector(1 downto 0);
        mb_clk40_phase_90    : t_mb_std_logic;--std_logic_vector(1 downto 0);
        mb_clk40_phase_180   : t_mb_std_logic;--std_logic_vector(1 downto 0);
        mb_clk40_phase_270   : t_mb_std_logic;--std_logic_vector(1 downto 0);
        mb_clk80   : t_mb_std_logic;--std_logic_vector(1 downto 0);
        mb_clk280   : t_mb_std_logic;--std_logic_vector(1 downto 0);
        mb_clk560   : t_mb_std_logic;--std_logic_vector(1 downto 0);
        
        --tp clks
        --tp_clk40_q0_dp    : t_diff_pair;
        --tp_clk40_q1_dp    : t_diff_pair;        
        tp_clk40    : t_mb_std_logic;--std_logic_vector(1 downto 0);
        
        --mgt clks
        gbt_cdc_counter : integer range 0 to 3;
        gbt_cdc_counter_array : t_gbt_cdc_counter_array;
        gbt_cdc_phase :  std_logic;
        gbt_cdc_phase_array : t_gbt_cdc_phase_array;
        cis_cdc_counter : integer range 0 to 15;
        cis_cdc_phase :  std_logic;
        mmcm_refclk40 : std_logic;
        mmcm_refclk80 : std_logic;
        mmcm_refclk160 : std_logic;
        mmcm_refclk240 : std_logic;
        mmcm_refclk320 : std_logic;
        mmcm_refclk640 : std_logic;
        refclk40 : std_logic;
--        refclk80 : std_logic;
--        refclk240 : std_logic;
        gth_tx_wordclk:  std_logic_vector((c_gbt_bank_number_of_links-1) downto 0);
        gth_tx_frameclk:  std_logic_vector((c_gbt_bank_number_of_links-1) downto 0);
        gth_tx_frameclk40:  std_logic_vector((c_gbt_bank_number_of_links-1) downto 0);
        gth_refclk_local : std_logic_vector((c_number_of_gth_refclks-1) downto 0);
        gth_refclk_remote : std_logic_vector((c_number_of_gth_refclks-1) downto 0);
        gth_refclkdiv2_local : std_logic_vector((c_number_of_gth_refclks-1) downto 0);
        gth_refclkdiv2_remote : std_logic_vector((c_number_of_gth_refclks-1) downto 0);
        gth_refclk80 : std_logic_vector((c_number_of_gth_refclks-1) downto 0);
        gth_refclk40 : std_logic_vector((c_number_of_gth_refclks-1) downto 0);        
        gth_txwordclk80_out : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gth_txwordclk40_out : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gth_rxwordclk40_out : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gth_txoutclkfabric_out : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gth_rxoutclkfabric_out : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
    end record;

    -- vio_clknet_status lives in db6v5_top (see db6_clock_interface.vhd header); these two
    -- records carry exactly what it needs across the db6_clock_interface boundary: status
    -- signals with no other home in t_db_clknet/t_db_clkin, and the handful of debug knobs
    -- the vio used to drive directly as internal signals when it lived inside the module.
    type t_clknet_debug_status is record
        mmcm_gbt40_db6_locked : std_logic;
        wordclk_locked        : std_logic_vector(1 downto 0);
        cdc_reset_array       : std_logic_vector(1 downto 0);
    end record;

    type t_clknet_debug_control is record
        reset_mb                             : t_mb_std_logic;
        reset_clknet                         : std_logic;
        skip_main_sm                         : std_logic;
        force_gtx_i2c_config                 : std_logic;
        gbt_cdc_gearbox_phase                : std_logic_vector(1 downto 0);
        adc_readout_high_threshold           : std_logic_vector(11 downto 0);
        adc_readout_low_threshold            : std_logic_vector(11 downto 0);
        adc_readout_threshold_select_channel : std_logic_vector(2 downto 0);
        cis_enable                           : std_logic;
        cis_gain                             : std_logic;
        cis_bcid_charge                      : std_logic_vector(11 downto 0);
        cis_bcid_discharge                   : std_logic_vector(11 downto 0);
    end record;



    type t_xadc_control is record
        di_in : STD_LOGIC_VECTOR(15 DOWNTO 0);
        daddr_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
        den_in : STD_LOGIC;
        dwe_in : STD_LOGIC;
        drdy_out : STD_LOGIC;
        do_out : STD_LOGIC_VECTOR(15 DOWNTO 0);
        dclk_in : STD_LOGIC;
        
--        i2c_sda :std_logic;
--        i2c_sclk :std_logic;
        
        reset_in :std_logic;


        user_temp_alarm_out : STD_LOGIC;
        vccint_alarm_out : STD_LOGIC;
        vccaux_alarm_out : STD_LOGIC;
        user_supply0_alarm_out : STD_LOGIC;
        user_supply1_alarm_out : STD_LOGIC;
        user_supply2_alarm_out : STD_LOGIC;
        --user_supply3_alarm_out : STD_LOGIC;
        ot_out : STD_LOGIC;
        channel_out : STD_LOGIC_VECTOR(5 DOWNTO 0);
        muxaddr_out : STD_LOGIC_VECTOR(4 DOWNTO 0);
        eoc_out : STD_LOGIC;
        vbram_alarm_out : STD_LOGIC;
        alarm_out : STD_LOGIC;
        eos_out : STD_LOGIC;
        busy_out : STD_LOGIC;
        jtaglocked_out : STD_LOGIC;
        jtagmodified_out : STD_LOGIC;
        jtagbusy_out : STD_LOGIC;
    end record;

    type t_system_management_interface is record
    
        p_good : std_logic_vector(c_number_of_pgood_channels downto 0);--t_pgood;
        xadc_control : t_xadc_control;
        xadc_channel_voltage : std_logic_vector(15 downto 0);
        xadc_channel : std_logic_vector(7 downto 0);
--        xadc_selected_channel : integer range 0 to 31;
        xadc_new_conversion : std_logic;
--        xadc_data : t_xadc_data;
--        xadc_voltages : t_xadc_voltages;
        tmr_error : std_logic;
        ku_dna : std_logic_vector(95 downto 0);
        ku_dna_done : std_logic;
    end record;


    type t_mb_jtag is record
    
        tck :  std_logic;
        tms :  std_logic;
        tdi : std_logic;
        --tdo : std_logic;
        --enable : std_logic;
        
    end record;


--    type t_uart is record
--        tx : std_logic;
--        rx : std_logic;
--    end record;



    type t_gbtx_dprom is record
        clka : STD_LOGIC;
        addra : STD_LOGIC_VECTOR(8 DOWNTO 0);
        douta : STD_LOGIC_VECTOR(7 DOWNTO 0);
    end record;
    type t_gbtx_dprom_tmr is array (2 downto 0) of t_gbtx_dprom;

    type t_gbtx_control is record
--        gbtx_side : std_logic_vector(1 downto 0);
        gbtx_cfgsel     : std_logic;
        gbtx_reset      :  std_logic;
        gbtx_default_config      :  std_logic;
        gbtx_i2c_read_write_operation : std_logic;
        gbtx_trigger_i2c_operation : std_logic;
        wipe_gbtx_registers : std_logic;
        gbtx_reg_address : std_logic_vector(15 downto 0);
        gbtx_reg_value : std_logic_vector(7 downto 0);
        gbtx_i2c_speed : std_logic_vector(15 downto 0);
--        gbtx_rw_mode : std_logic;

--        gbtx_read_in : std_logic;
--        gbtx_write_in: std_logic;
    end record;

    type t_gbtx_interface is record
        gbtx_side : std_logic_vector(1 downto 0);
        i2c : t_i2c;
        gbtx_control : t_gbtx_control;
        blk_mem_gbtx_regs : t_blk_mem_gbtx_regs;
        busy : std_logic;
        tmr_error : std_logic;
    end record;







    type t_sfp_control is record

        sfp_trigger_i2c_operation : std_logic;
        
    end record;


--    type t_sfp_interface is record
--        gbtx_side : std_logic_vector(1 downto 0);
----        gbtx_datavalid : std_logic_vector(1 downto 0);
----        gbtx_rxready : std_logic_vector(1 downto 0);
--        i2c : t_i2c;
--        busy : std_logic;
--        gbtx_dpram : t_sfp_dpram;
--    end record;

    type t_sc_switch is array (1 downto 0) of std_logic_vector(1 downto 0);
    type t_sc_tx is array (1 downto 0) of std_logic_vector(15 downto 0);
    
    type t_gbt_tx_data is record
        lg : std_logic_vector(115 downto 0);
        hg : std_logic_vector(115 downto 0);
        sync : std_logic_vector(115 downto 0);
	end record;
    type t_gbt_encoder_interface is record
        --gbt encoded words
        gbt_tx_data_out       : t_gbt_tx_data;--std_logic_vector(115 downto 0);
        
        --sc channel
        sc_sending        : std_logic;
--        sc_datavalid         : std_logic;
        sc_address         : std_logic_vector(15 downto 0);
        sc_data         : std_logic_vector(31 downto 0);
        sc_switch       :  t_sc_switch;
        sc_tx           :t_sc_tx;
        
        data_phase  : std_logic_vector(1 downto 0);
        data_phase_sync : std_logic_vector(1 downto 0);
        gbt_cdc_counter : integer range 0 to 3;
        gbt_cdc_counter_array : t_gbt_cdc_counter_array;
        
        tx_fc_lg    : std_logic;
        tx_fc_hg    : std_logic;
        tmr_enabled : std_logic;
        tmr_error : std_logic;
        
        --========--
        -- resets --
        --========--
        mgt_txreset_i : std_logic;
        gbt_txreset_i : std_logic;
        --========--
        -- clocks --     
        --========--
        gbt_txframeclk_i : std_logic;
        gbt_txclken_i  : std_logic;
		mgt_txwordclk_o : std_logic;
        mgt_rxwordclk_o : std_logic;
        --================--
        -- gbt tx control --
        --================--
        tx_encoding_sel_i : std_logic;
        gbt_isdataflag_i : std_logic;
        --=================--
        -- gbt tx status   --
        --=================--
        tx_phcomputed_o : std_logic;
		tx_phaligned_o : std_logic;
        --========--
        -- data   --
        --========--
        gbt_txencdata : std_logic_vector(119 downto 0);
        mgt_txword : std_logic_vector(39 downto 0);
        gbt_cdc_counter_i : integer range 0 to 3;
        tx_phase_i : std_logic_vector(1 downto 0);
        gbt_bank_sync : std_logic_vector(2 downto 0);
        
        
        
        
        --gearbox_tmr_error : std_logic_vector(1 downto 0);
    end record;
    type t_gbt_encoder_interface_tmr is array (natural range 0 to 2) of t_gbt_encoder_interface;
    
    type t_sr_gbt_encoder is record
    D :  STD_LOGIC_VECTOR(115 DOWNTO 0);
    CLK :  STD_LOGIC;
    Q :  STD_LOGIC_VECTOR(115 DOWNTO 0);
  end record;

    type t_gbt_encoder_interface_array is array (1 to c_gbt_bank_number_of_links) of t_gbt_encoder_interface;

    type t_sem_interface is record
        -- Status interface
        status_heartbeat : std_logic;
        status_initialization : std_logic;
        status_observation : std_logic;
        status_correction : std_logic;
        status_classification : std_logic;
        status_injection : std_logic;
        status_diagnostic_scan : std_logic;
        status_detect_only : std_logic;  
        status_essential : std_logic;
        status_uncorrectable : std_logic;
        
        -- UART interface
        --uart : t_uart;
        uart_tx : std_logic;
        uart_rx : std_logic;
        monitor_txdata : std_logic_vector(7 downto 0);
        monitor_txwrite : std_logic;
        monitor_txfull : std_logic;
                        
        -- Command interface
        command_strobe : std_logic;
        command_busy : std_logic;
        command_code : std_logic_vector(39 downto 0);
        
        --icap
        icap_out    :   std_logic_vector(31 downto 0);
        -- Routed system clock 
        icap_clk_out : std_logic;
        
        -- ICAP arbitration interface
        cap_rel : std_logic;
        cap_gnt : std_logic;
        cap_req : std_logic;
        
        -- Auxiliary interface
        aux_error_cr_ne : std_logic;
        aux_error_cr_es : std_logic;
        aux_error_uc : std_logic;
        
        
        end record;

    type t_sem_interpreter is record
        total_errors : std_logic_vector(31 downto 0);
        correctable_errors : std_logic_vector(31 downto 0);
        uncorrectable_errors : std_logic_vector(31 downto 0);
        sem_fatal_error : std_logic;
        injected_errors : std_logic_vector(31 downto 0);
    end record;


    type t_db6_sem_interface is record
        sem_interpreter : t_sem_interpreter;
        sem_interface : t_sem_interface;
    end record;

        type t_tmr_manager_db6 is record
            TMR_Disable : STD_LOGIC;
            Debug_Disable : STD_LOGIC;
            Clk : STD_LOGIC;
            Rst : STD_LOGIC;
            Recover : STD_LOGIC;
            LockStep_Break : STD_LOGIC;
            Fatal : STD_LOGIC;
            Reset : STD_LOGIC;
            Status : STD_LOGIC_VECTOR(31 DOWNTO 0);
            LMB_ABus : STD_LOGIC_VECTOR(0 TO 31);
            LMB_WriteDBus : STD_LOGIC_VECTOR(0 TO 31);
            LMB_AddrStrobe : STD_LOGIC;
            LMB_ReadStrobe : STD_LOGIC;
            LMB_WriteStrobe : STD_LOGIC;
            LMB_BE : STD_LOGIC_VECTOR(0 TO 3);
            Sl_DBus : STD_LOGIC_VECTOR(0 TO 31);
            Sl_Ready : STD_LOGIC;
            Sl_Wait : STD_LOGIC;
            Sl_UE : STD_LOGIC;
            Sl_CE : STD_LOGIC;
            Compare_0 : STD_LOGIC_VECTOR(3 DOWNTO 0);
            UE_LMB : STD_LOGIC_VECTOR(2 DOWNTO 0);
            SEM_heartbeat : STD_LOGIC;
            SEM_initialization : STD_LOGIC;
            SEM_observation : STD_LOGIC;
            SEM_correction : STD_LOGIC;
            SEM_classification : STD_LOGIC;
            SEM_injection : STD_LOGIC;
            SEM_essential : STD_LOGIC;
            SEM_uncorrectable : STD_LOGIC;
            SEM_diagnostic_scan : STD_LOGIC;
            SEM_detect_only : STD_LOGIC;
            SEM_heartbeat_expired : STD_LOGIC;
            SEM_status_irq : STD_LOGIC;
            To_TMR_Managers : STD_LOGIC_VECTOR(89 DOWNTO 0);
            From_TMR_Manager_1 : STD_LOGIC_VECTOR(89 DOWNTO 0);
            From_TMR_Manager_2 : STD_LOGIC_VECTOR(89 DOWNTO 0);
            From_TMR_Manager_3 : STD_LOGIC_VECTOR(89 DOWNTO 0);
        end record;

        
        type t_commbus_encoder_interface is record
            commbus_tx_data_out : std_logic_vector(119 downto 0);
        end record;
    
        type t_commbus_decoder_interface is record
            crc_counter : std_logic_vector(31 downto 0);
            loopback_counter : std_logic_vector(31 downto 0);
            loopback_counter_locked : std_logic;
            reset_locked : std_logic;
        end record;
    
        type t_commbus_ddr is record
        
            bitclk_rx : std_logic;
            bitclk_tx : std_logic;
            frameclk_rx : std_logic;
            frameclk_tx : std_logic;
            bitcnt_rx : integer range 0 to 120;
            bitcnt_tx : integer range 0 to 120;
                    
            refclk_tx : std_logic;
            refclk_rx : std_logic;
            
            commbus_tx_data_out : std_logic_vector(119 downto 0);
            commbus_rx_data_in : std_logic_vector(119 downto 0);
            
            locked : std_logic;
            locked_counter : integer range 0 to 15;
            datavalid : std_logic;
            dataloopback : std_logic;
            datareset : std_logic;
            
        end record;
        
        type t_cfgbus_interface is record
            db_reg_rx : t_db_reg_rx;
            reg_rx_strobe : std_logic_vector(31 downto 0);--: integer range 0 to 15;
            tmr_enabled : std_logic;
            tmr_error_local : std_logic_vector(c_number_of_cfgbus_regs-1 downto 0);
            tmr_error_remote :  std_logic_vector(c_number_of_cfgbus_regs-1 downto 0);
        end record;
        
        type t_commbus_ddr_interface is record
            commbus_decoder_interface : t_commbus_decoder_interface;
            commbus_encoder_interface : t_commbus_encoder_interface;
            clknet : t_db_clknet;
            db_reg_rx : t_db_reg_rx;
            db_reg_tx : t_db_reg_tx;
            mb_interface : t_mb_interface;
            sem_interface :t_sem_interface;
            tdo_remote : std_logic;
            system_management_interface : t_system_management_interface;
            gbtx_interface : t_gbtx_interface;
            serial_id_interface : t_serial_id_interface;
        end record;
        
        type msg_array is array (natural range <>) of std_logic_vector(7 downto 0);
	
	type array32bits 			is array (natural range <>) of std_logic_vector (31 downto 0);  

-- functions and procedures to be declared in package body

	procedure toggle(
		signal clk : in  std_logic;
		    input  : in  std_logic;
		    output : out std_logic);

	function to_bcd ( bin : std_logic_vector(7 downto 0) ) return std_logic_vector;
	
	function tile_link_crc_compute( data_in :  std_logic_vector(99 downto 0)) return std_logic_vector ; --std_logic_vector(15 downto 0);
	
	procedure tmr_voter (
        signal din0 : in  std_logic_vector;
        signal din1 : in  std_logic_vector;
        signal din2 : in  std_logic_vector; 
        signal dout : out std_logic_vector;
        signal nerr : out integer range 0 to 255);	
	
    -- serial id chip
    type t_serial_id_array is array (0 to 8) of std_logic_vector(7 downto 0);
	
	--gbtx registers
	--gbtx configuration registers config file to write on gbtx
    type t_gbtx_register_configuration is array (0 to 365) of std_logic_vector(7 downto 0);
    type t_gbtx_register_configuration_array is array (0 to 1) of t_gbtx_register_configuration;
    
    --gbtx configuration and status registers config file to read from gbtx
    type t_gbtx_register_readout is array (0 to 435) of std_logic_vector(7 downto 0);
    type t_gbtx_register_readout_array is array (0 to 1) of t_gbtx_register_readout;
	
	--mmcm drp
	type t_mmcm_clk_register_configuration is array (0 to 1) of std_logic_vector(15 downto 0);
	type t_mmcm_clk_register_address is array (0 to 1) of std_logic_vector(6 downto 0);



-- clocking!
    type t_db_clkin is record

        db_side : std_logic_vector(0 downto 0);
        md_number : std_logic_vector(3 downto 0);
        gbtx_rxready : std_logic_vector(1 downto 0);
        gbtx_datavalid : std_logic_vector(1 downto 0);
            
        clksel : std_logic;                    -- signal to select clock source (which gbtx)
        gth_wordclk_sel : std_logic;
        cpllclksel : std_logic_vector(2 downto 0);                    -- signal to select cpll clock source
        qpllclksel : std_logic_vector(2 downto 0);                    -- signal to select qpll clock source
        txsysclksel : std_logic_vector(1 downto 0);
        rxsysclksel : std_logic_vector(1 downto 0);
        rxoutclksel : std_logic_vector(2 downto 0);
        txoutclksel : std_logic_vector(2 downto 0);
        txpllclksel : std_logic_vector(1 downto 0);
        rxpllclksel : std_logic_vector(1 downto 0);
        
        sfp_ku_mgt                     : t_ku_mgt;
        db6_gbt_bank                        : t_db6_gbt_bank;
        gbt_encoder_interface                        : t_gbt_encoder_interface;
        mb_interface                    :t_mb_interface;
        db6_sem_interface                   : t_db6_sem_interface;
        gbtx_interface : t_gbtx_interface;
        sfp_interface : t_sfp_interface;
--        db_clkin_local, db_clkin_remote : t_diff_pair;
        bcr : t_bcr;
        
        cfgbus_clkin_local, cfgbus_clkin_remote : t_diff_pair;
        cis_hss_clkin_local : t_diff_pair;
        mb_q0_clkin_local, mb_q1_clkin_local : t_diff_pair;
        mb_q0_clkin_remote, mb_q1_clkin_remote : t_diff_pair;
        tp_q0_clkin_local, tp_q1_clkin_local : t_diff_pair;
        tp_q0_clkin_remote, tp_q1_clkin_remote : t_diff_pair;

        osc_clkin : t_diff_pair;
        gth_refclk_gbtx_local, gth_refclk_gbtx_remote : t_diff_pair_vector((c_number_of_gth_refclks-1) downto 0);
        gth_txwordclk80_in : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gth_txwordclk40_in : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gth_rxwordclk40_in : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gth_txoutclkfabric_out : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);
        gth_rxoutclkfabric_out : std_logic_vector(c_gbt_bank_number_of_links-1 downto 0);

        db_leds : std_logic_vector(3 downto 0); 
        --commbus clk
        --commbus_bitclk_tx : std_logic;
        --commbus_bitclk_rx : std_logic;
        
        --db_cfgbus_clkin_local, db_cfgbus_clkin_remote : t_diff_pair;
        --gth_refclk_loc, gth_refclk_rem : t_diff_pair;
    end record;



    -----------------------------------------------------------------
	--      DEBUGGING DECLARATIONS                                 --
	-----------------------------------------------------------------
	
	type t_db6_ibert_ultrascale_gth is record 
        txn_o : STD_LOGIC_VECTOR(7 DOWNTO 0);
        txp_o : STD_LOGIC_VECTOR(7 DOWNTO 0);
        rxoutclk_o : STD_LOGIC_VECTOR(7 DOWNTO 0);
        rxn_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
        rxp_i : STD_LOGIC_VECTOR(7 DOWNTO 0);
        gtrefclk0_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtrefclk1_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtnorthrefclk0_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtnorthrefclk1_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtsouthrefclk0_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtsouthrefclk1_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtrefclk00_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtrefclk10_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtrefclk01_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtrefclk11_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtnorthrefclk00_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtnorthrefclk10_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtnorthrefclk01_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtnorthrefclk11_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtsouthrefclk00_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtsouthrefclk10_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtsouthrefclk01_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        gtsouthrefclk11_i : STD_LOGIC_VECTOR(1 DOWNTO 0);
        clk : STD_LOGIC;    
    end record;    


end db6_design_package;

------------------
-- package body --
------------------

package body db6_design_package is	
	
	procedure toggle(
		signal clk : in  std_logic;
		    input  : in  std_logic;
		    output : out std_logic) is
	variable state : std_logic := '0';
	begin
		if(rising_edge(clk)) then
			case state is
				when '1' =>
					output := '0';
					if(input = '0') then
						state := '0';
					end if;
				when others =>
					output := '0';
					if(input = '1') then
						state := '1';
						output := '1';
					end if;
			end case;
		end if;
	end toggle;
	
	
	function to_bcd ( bin : std_logic_vector(7 downto 0) ) return std_logic_vector is
		variable i : integer:=0;
		variable bcd : std_logic_vector(11 downto 0) := (others => '0');
		variable bint : std_logic_vector(7 downto 0) := bin;

		begin
			for i in 0 to 7 loop  -- repeating 8 times.
				bcd(11 downto 1) := bcd(10 downto 0);  --shifting the bits.
				bcd(0) := bint(7);
				bint(7 downto 1) := bint(6 downto 0);
				bint(0) :='0';


				if(i < 7 and bcd(3 downto 0) > "0100") then --add 3 if bcd digit is greater than 4.
					bcd(3 downto 0) := bcd(3 downto 0) + "0011";
				end if;

				if(i < 7 and bcd(7 downto 4) > "0100") then --add 3 if bcd digit is greater than 4.
					bcd(7 downto 4) := bcd(7 downto 4) + "0011";
				end if;

				if(i < 7 and bcd(11 downto 8) > "0100") then  --add 3 if bcd digit is greater than 4.
					bcd(11 downto 8) := bcd(11 downto 8) + "0011";
				end if;
			end loop;
		return bcd;
	end to_bcd;


	procedure tmr_voter (
		signal din0 : in  std_logic_vector;
		signal din1 : in  std_logic_vector;
		signal din2 : in  std_logic_vector; 
		signal dout : out std_logic_vector;
		signal nerr : out integer range 0 to 255) is
		variable nerr_tmp : integer range 0 to 255 := 0;
	begin
			nerr_tmp := 0;
			for i in din0'range loop
				dout(i) <= (din0(i) and din1(i)) or
				           (din1(i) and din2(i)) or
				           (din2(i) and din0(i));
				if ((din0(i) /= din1(i)) or (din1(i) /= din2(i))) then
					nerr_tmp := nerr_tmp + 1;
				end if;
			end loop;
			nerr <= nerr_tmp;
	end tmr_voter;
	

	function tile_link_crc_compute( data_in :  std_logic_vector(99 downto 0)) return std_logic_vector is
--	variable result : std_logic_vector(15 downto 0);
	variable lfsr_c : std_logic_vector(15 downto 0);
	variable lfsr_q : std_logic_vector(15 downto 0):=X"FFFF";
	begin

		lfsr_c(0) := lfsr_q(1) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(8) xor lfsr_q(9) xor lfsr_q(10) xor lfsr_q(14) xor data_in(0) xor data_in(4) xor data_in(8) xor data_in(9) xor data_in(14) xor data_in(15) xor data_in(17) xor data_in(18) xor data_in(23) xor data_in(24) xor data_in(25) xor data_in(27) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(39) xor data_in(46) xor data_in(48) xor data_in(49) xor data_in(51) xor data_in(55) xor data_in(57) xor data_in(59) xor data_in(60) xor data_in(61) xor data_in(65) xor data_in(68) xor data_in(71) xor data_in(72) xor data_in(73) xor data_in(74) xor data_in(76) xor data_in(78) xor data_in(79) xor data_in(82) xor data_in(85) xor data_in(88) xor data_in(89) xor data_in(90) xor data_in(91) xor data_in(92) xor data_in(93) xor data_in(94) xor data_in(98);
		lfsr_c(1) := lfsr_q(1) xor lfsr_q(2) xor lfsr_q(4) xor lfsr_q(11) xor lfsr_q(14) xor lfsr_q(15) xor data_in(0) xor data_in(1) xor data_in(4) xor data_in(5) xor data_in(8) xor data_in(10) xor data_in(14) xor data_in(16) xor data_in(17) xor data_in(19) xor data_in(23) xor data_in(26) xor data_in(27) xor data_in(28) xor data_in(30) xor data_in(35) xor data_in(36) xor data_in(40) xor data_in(46) xor data_in(47) xor data_in(48) xor data_in(50) xor data_in(51) xor data_in(52) xor data_in(55) xor data_in(56) xor data_in(57) xor data_in(58) xor data_in(59) xor data_in(62) xor data_in(65) xor data_in(66) xor data_in(68) xor data_in(69) xor data_in(71) xor data_in(75) xor data_in(76) xor data_in(77) xor data_in(78) xor data_in(80) xor data_in(82) xor data_in(83) xor data_in(85) xor data_in(86) xor data_in(88) xor data_in(95) xor data_in(98) xor data_in(99);
		lfsr_c(2) := lfsr_q(0) xor lfsr_q(1) xor lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(8) xor lfsr_q(9) xor lfsr_q(10) xor lfsr_q(12) xor lfsr_q(14) xor lfsr_q(15) xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(8) xor data_in(11) xor data_in(14) xor data_in(20) xor data_in(23) xor data_in(25) xor data_in(28) xor data_in(29) xor data_in(30) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(38) xor data_in(39) xor data_in(41) xor data_in(46) xor data_in(47) xor data_in(52) xor data_in(53) xor data_in(55) xor data_in(56) xor data_in(58) xor data_in(61) xor data_in(63) xor data_in(65) xor data_in(66) xor data_in(67) xor data_in(68) xor data_in(69) xor data_in(70) xor data_in(71) xor data_in(73) xor data_in(74) xor data_in(77) xor data_in(81) xor data_in(82) xor data_in(83) xor data_in(84) xor data_in(85) xor data_in(86) xor data_in(87) xor data_in(88) xor data_in(90) xor data_in(91) xor data_in(92) xor data_in(93) xor data_in(94) xor data_in(96) xor data_in(98) xor data_in(99);
		lfsr_c(3) := lfsr_q(0) xor lfsr_q(1) xor lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(7) xor lfsr_q(8) xor lfsr_q(9) xor lfsr_q(10) xor lfsr_q(11) xor lfsr_q(13) xor lfsr_q(15) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(6) xor data_in(7) xor data_in(9) xor data_in(12) xor data_in(15) xor data_in(21) xor data_in(24) xor data_in(26) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(39) xor data_in(40) xor data_in(42) xor data_in(47) xor data_in(48) xor data_in(53) xor data_in(54) xor data_in(56) xor data_in(57) xor data_in(59) xor data_in(62) xor data_in(64) xor data_in(66) xor data_in(67) xor data_in(68) xor data_in(69) xor data_in(70) xor data_in(71) xor data_in(72) xor data_in(74) xor data_in(75) xor data_in(78) xor data_in(82) xor data_in(83) xor data_in(84) xor data_in(85) xor data_in(86) xor data_in(87) xor data_in(88) xor data_in(89) xor data_in(91) xor data_in(92) xor data_in(93) xor data_in(94) xor data_in(95) xor data_in(97) xor data_in(99);
		lfsr_c(4) := lfsr_q(0) xor lfsr_q(2) xor lfsr_q(3) xor lfsr_q(7) xor lfsr_q(11) xor lfsr_q(12) xor data_in(0) xor data_in(2) xor data_in(3) xor data_in(6) xor data_in(7) xor data_in(9) xor data_in(10) xor data_in(13) xor data_in(14) xor data_in(15) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(22) xor data_in(23) xor data_in(24) xor data_in(33) xor data_in(35) xor data_in(37) xor data_in(38) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(43) xor data_in(46) xor data_in(51) xor data_in(54) xor data_in(58) xor data_in(59) xor data_in(61) xor data_in(63) xor data_in(67) xor data_in(69) xor data_in(70) xor data_in(74) xor data_in(75) xor data_in(78) xor data_in(82) xor data_in(83) xor data_in(84) xor data_in(86) xor data_in(87) xor data_in(91) xor data_in(95) xor data_in(96);
		lfsr_c(5) := lfsr_q(0) xor lfsr_q(1) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(8) xor lfsr_q(12) xor lfsr_q(13) xor data_in(1) xor data_in(3) xor data_in(4) xor data_in(7) xor data_in(8) xor data_in(10) xor data_in(11) xor data_in(14) xor data_in(15) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(19) xor data_in(23) xor data_in(24) xor data_in(25) xor data_in(34) xor data_in(36) xor data_in(38) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(42) xor data_in(44) xor data_in(47) xor data_in(52) xor data_in(55) xor data_in(59) xor data_in(60) xor data_in(62) xor data_in(64) xor data_in(68) xor data_in(70) xor data_in(71) xor data_in(75) xor data_in(76) xor data_in(79) xor data_in(83) xor data_in(84) xor data_in(85) xor data_in(87) xor data_in(88) xor data_in(92) xor data_in(96) xor data_in(97);
		lfsr_c(6) := lfsr_q(0) xor lfsr_q(1) xor lfsr_q(2) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(9) xor lfsr_q(13) xor lfsr_q(14) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(8) xor data_in(9) xor data_in(11) xor data_in(12) xor data_in(15) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(19) xor data_in(20) xor data_in(24) xor data_in(25) xor data_in(26) xor data_in(35) xor data_in(37) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(42) xor data_in(43) xor data_in(45) xor data_in(48) xor data_in(53) xor data_in(56) xor data_in(60) xor data_in(61) xor data_in(63) xor data_in(65) xor data_in(69) xor data_in(71) xor data_in(72) xor data_in(76) xor data_in(77) xor data_in(80) xor data_in(84) xor data_in(85) xor data_in(86) xor data_in(88) xor data_in(89) xor data_in(93) xor data_in(97) xor data_in(98);
		lfsr_c(7) := lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(7) xor lfsr_q(8) xor lfsr_q(9) xor lfsr_q(15) xor data_in(0) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(8) xor data_in(10) xor data_in(12) xor data_in(13) xor data_in(14) xor data_in(15) xor data_in(16) xor data_in(19) xor data_in(20) xor data_in(21) xor data_in(23) xor data_in(24) xor data_in(26) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(37) xor data_in(39) xor data_in(40) xor data_in(41) xor data_in(42) xor data_in(43) xor data_in(44) xor data_in(48) xor data_in(51) xor data_in(54) xor data_in(55) xor data_in(59) xor data_in(60) xor data_in(62) xor data_in(64) xor data_in(65) xor data_in(66) xor data_in(68) xor data_in(70) xor data_in(71) xor data_in(74) xor data_in(76) xor data_in(77) xor data_in(79) xor data_in(81) xor data_in(82) xor data_in(86) xor data_in(87) xor data_in(88) xor data_in(91) xor data_in(92) xor data_in(93) xor data_in(99);
		lfsr_c(8) := lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(8) xor lfsr_q(9) xor lfsr_q(10) xor data_in(1) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(7) xor data_in(9) xor data_in(11) xor data_in(13) xor data_in(14) xor data_in(15) xor data_in(16) xor data_in(17) xor data_in(20) xor data_in(21) xor data_in(22) xor data_in(24) xor data_in(25) xor data_in(27) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(38) xor data_in(40) xor data_in(41) xor data_in(42) xor data_in(43) xor data_in(44) xor data_in(45) xor data_in(49) xor data_in(52) xor data_in(55) xor data_in(56) xor data_in(60) xor data_in(61) xor data_in(63) xor data_in(65) xor data_in(66) xor data_in(67) xor data_in(69) xor data_in(71) xor data_in(72) xor data_in(75) xor data_in(77) xor data_in(78) xor data_in(80) xor data_in(82) xor data_in(83) xor data_in(87) xor data_in(88) xor data_in(89) xor data_in(92) xor data_in(93) xor data_in(94);
		lfsr_c(9) := lfsr_q(0) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(9) xor lfsr_q(10) xor lfsr_q(11) xor data_in(2) xor data_in(5) xor data_in(6) xor data_in(7) xor data_in(8) xor data_in(10) xor data_in(12) xor data_in(14) xor data_in(15) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(21) xor data_in(22) xor data_in(23) xor data_in(25) xor data_in(26) xor data_in(28) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(39) xor data_in(41) xor data_in(42) xor data_in(43) xor data_in(44) xor data_in(45) xor data_in(46) xor data_in(50) xor data_in(53) xor data_in(56) xor data_in(57) xor data_in(61) xor data_in(62) xor data_in(64) xor data_in(66) xor data_in(67) xor data_in(68) xor data_in(70) xor data_in(72) xor data_in(73) xor data_in(76) xor data_in(78) xor data_in(79) xor data_in(81) xor data_in(83) xor data_in(84) xor data_in(88) xor data_in(89) xor data_in(90) xor data_in(93) xor data_in(94) xor data_in(95);
		lfsr_c(10) := lfsr_q(0) xor lfsr_q(1) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(10) xor lfsr_q(11) xor lfsr_q(12) xor data_in(3) xor data_in(6) xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(11) xor data_in(13) xor data_in(15) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(19) xor data_in(22) xor data_in(23) xor data_in(24) xor data_in(26) xor data_in(27) xor data_in(29) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(40) xor data_in(42) xor data_in(43) xor data_in(44) xor data_in(45) xor data_in(46) xor data_in(47) xor data_in(51) xor data_in(54) xor data_in(57) xor data_in(58) xor data_in(62) xor data_in(63) xor data_in(65) xor data_in(67) xor data_in(68) xor data_in(69) xor data_in(71) xor data_in(73) xor data_in(74) xor data_in(77) xor data_in(79) xor data_in(80) xor data_in(82) xor data_in(84) xor data_in(85) xor data_in(89) xor data_in(90) xor data_in(91) xor data_in(94) xor data_in(95) xor data_in(96);
		lfsr_c(11) := lfsr_q(1) xor lfsr_q(2) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(8) xor lfsr_q(11) xor lfsr_q(12) xor lfsr_q(13) xor data_in(4) xor data_in(7) xor data_in(8) xor data_in(9) xor data_in(10) xor data_in(12) xor data_in(14) xor data_in(16) xor data_in(17) xor data_in(18) xor data_in(19) xor data_in(20) xor data_in(23) xor data_in(24) xor data_in(25) xor data_in(27) xor data_in(28) xor data_in(30) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(41) xor data_in(43) xor data_in(44) xor data_in(45) xor data_in(46) xor data_in(47) xor data_in(48) xor data_in(52) xor data_in(55) xor data_in(58) xor data_in(59) xor data_in(63) xor data_in(64) xor data_in(66) xor data_in(68) xor data_in(69) xor data_in(70) xor data_in(72) xor data_in(74) xor data_in(75) xor data_in(78) xor data_in(80) xor data_in(81) xor data_in(83) xor data_in(85) xor data_in(86) xor data_in(90) xor data_in(91) xor data_in(92) xor data_in(95) xor data_in(96) xor data_in(97);
		lfsr_c(12) := lfsr_q(0) xor lfsr_q(1) xor lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(10) xor lfsr_q(12) xor lfsr_q(13) xor data_in(0) xor data_in(4) xor data_in(5) xor data_in(10) xor data_in(11) xor data_in(13) xor data_in(14) xor data_in(19) xor data_in(20) xor data_in(21) xor data_in(23) xor data_in(26) xor data_in(27) xor data_in(28) xor data_in(29) xor data_in(30) xor data_in(32) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(42) xor data_in(44) xor data_in(45) xor data_in(47) xor data_in(51) xor data_in(53) xor data_in(55) xor data_in(56) xor data_in(57) xor data_in(61) xor data_in(64) xor data_in(67) xor data_in(68) xor data_in(69) xor data_in(70) xor data_in(72) xor data_in(74) xor data_in(75) xor data_in(78) xor data_in(81) xor data_in(84) xor data_in(85) xor data_in(86) xor data_in(87) xor data_in(88) xor data_in(89) xor data_in(90) xor data_in(94) xor data_in(96) xor data_in(97);
		lfsr_c(13) := lfsr_q(1) xor lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(11) xor lfsr_q(13) xor lfsr_q(14) xor data_in(1) xor data_in(5) xor data_in(6) xor data_in(11) xor data_in(12) xor data_in(14) xor data_in(15) xor data_in(20) xor data_in(21) xor data_in(22) xor data_in(24) xor data_in(27) xor data_in(28) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(33) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(43) xor data_in(45) xor data_in(46) xor data_in(48) xor data_in(52) xor data_in(54) xor data_in(56) xor data_in(57) xor data_in(58) xor data_in(62) xor data_in(65) xor data_in(68) xor data_in(69) xor data_in(70) xor data_in(71) xor data_in(73) xor data_in(75) xor data_in(76) xor data_in(79) xor data_in(82) xor data_in(85) xor data_in(86) xor data_in(87) xor data_in(88) xor data_in(89) xor data_in(90) xor data_in(91) xor data_in(95) xor data_in(97) xor data_in(98);
		lfsr_c(14) := lfsr_q(2) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(8) xor lfsr_q(12) xor lfsr_q(14) xor lfsr_q(15) xor data_in(2) xor data_in(6) xor data_in(7) xor data_in(12) xor data_in(13) xor data_in(15) xor data_in(16) xor data_in(21) xor data_in(22) xor data_in(23) xor data_in(25) xor data_in(28) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(34) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(44) xor data_in(46) xor data_in(47) xor data_in(49) xor data_in(53) xor data_in(55) xor data_in(57) xor data_in(58) xor data_in(59) xor data_in(63) xor data_in(66) xor data_in(69) xor data_in(70) xor data_in(71) xor data_in(72) xor data_in(74) xor data_in(76) xor data_in(77) xor data_in(80) xor data_in(83) xor data_in(86) xor data_in(87) xor data_in(88) xor data_in(89) xor data_in(90) xor data_in(91) xor data_in(92) xor data_in(96) xor data_in(98) xor data_in(99);
		lfsr_c(15) := lfsr_q(0) xor lfsr_q(3) xor lfsr_q(4) xor lfsr_q(5) xor lfsr_q(6) xor lfsr_q(7) xor lfsr_q(8) xor lfsr_q(9) xor lfsr_q(13) xor lfsr_q(15) xor data_in(3) xor data_in(7) xor data_in(8) xor data_in(13) xor data_in(14) xor data_in(16) xor data_in(17) xor data_in(22) xor data_in(23) xor data_in(24) xor data_in(26) xor data_in(29) xor data_in(30) xor data_in(31) xor data_in(32) xor data_in(33) xor data_in(35) xor data_in(36) xor data_in(37) xor data_in(38) xor data_in(45) xor data_in(47) xor data_in(48) xor data_in(50) xor data_in(54) xor data_in(56) xor data_in(58) xor data_in(59) xor data_in(60) xor data_in(64) xor data_in(67) xor data_in(70) xor data_in(71) xor data_in(72) xor data_in(73) xor data_in(75) xor data_in(77) xor data_in(78) xor data_in(81) xor data_in(84) xor data_in(87) xor data_in(88) xor data_in(89) xor data_in(90) xor data_in(91) xor data_in(92) xor data_in(93) xor data_in(97) xor data_in(99);
		return lfsr_c;
	end tile_link_crc_compute;


	
end db6_design_package;

