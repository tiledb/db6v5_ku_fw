-------------------------------------------------------
--! @file
--! @author Julian Mendez <julian.mendez@cern.ch> (CERN - EP-ESE-BE)
--! @version 6.0
--! @brief GBT-FPGA IP - Device specific transceiver
-------------------------------------------------------

--! IEEE VHDL standard library:
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Xilinx devices library:
library unisim;
use unisim.vcomponents.all;

--! Custom libraries and packages:
library gbt;
use gbt.gbt_bank_package.all;
use gbt.vendor_specific_gbt_bank_package.all;

library tilecal;
use tilecal.db6_design_package.all;

--! @brief MGT - Transceiver
--! @details 
--! The MGT module provides the interface to the transceivers to send the GBT-links via
--! high speed links (@4.8Gbps)
entity db6_mgt is
   generic (
      NUM_LINKS                                      : integer := 1
   );                                                
   port (
        --========--
        -- db6  --
        --========--
        p_clknet_in             : in t_db_clknet;   
        p_ku_mgt_out            : out t_ku_mgt;
        p_db_reg_rx_in          : in t_db_reg_rx;
   
       --=============--
       -- Clocks      --
       --=============--
       MGT_REFCLK_i                 : in  std_logic_vector(1 to c_number_of_gth_refclks);
       
       MGT_RXUSRCLK_o               : out std_logic_vector(1 to NUM_LINKS);
       MGT_TXUSRCLK_o               : out std_logic_vector(1 to NUM_LINKS);
       
       --=============--
       -- Resets      --
       --=============--
       MGT_TXRESET_i                : in  std_logic_vector(1 to NUM_LINKS);
       MGT_RXRESET_i                : in  std_logic_vector(1 to NUM_LINKS);
       
       --=============--
       -- Status      --
       --=============--
       MGT_TXREADY_o                : out std_logic_vector(1 to NUM_LINKS);
       MGT_RXREADY_o                : out std_logic_vector(1 to NUM_LINKS);

       RX_HEADERLOCKED_o            : out std_logic_vector(1 to NUM_LINKS);
       RX_HEADERFLAG_o              : out std_logic_vector(1 to NUM_LINKS);
         MGT_RSTCNT_o                 : out gbt_reg8_A(1 to NUM_LINKS);
       
         --==============--
         -- Control      --
         --==============--
         MGT_AUTORSTEn_i              : in  std_logic_vector(1 to NUM_LINKS);
       MGT_AUTORSTONEVEN_i          : in  std_logic_vector(1 to NUM_LINKS);
         
       --==============--
       -- Data         --
       --==============--
       MGT_USRWORD_i                : in  word_mxnbit_A(1 to NUM_LINKS);
       MGT_USRWORD_o                : out word_mxnbit_A(1 to NUM_LINKS);
       
       --=============================--
       -- Device specific connections --
       --=============================--
       MGT_DEVSPEC_i                : in  mgtDeviceSpecific_i_R;
       MGT_DEVSPEC_o                : out mgtDeviceSpecific_o_R
   
   );
end db6_mgt;

--! @brief MGT - Transceiver
--! @details The MGT module implements all the logic required to send the GBT frame on high speed
--! links: resets modules for the transceiver, Tx PLL and alignement logic to align the received word with the 
--! GBT frame header.
architecture structural of db6_mgt is
   --================================ Signal Declarations ================================--

   --==============================--
   -- RX phase alignment (bitslip) --
   --==============================--
   
   
       signal rx_wordclk_sig                         : std_logic_vector(1 to NUM_LINKS);
       signal tx_wordclk240_sig, tx_wordclk480_sig, tx_wordclk_sig_muxed   : std_logic_vector(1 to NUM_LINKS);
       signal tx_frameclk_sig                        : std_logic_vector(1 to NUM_LINKS);
       signal tx_frameclk40_sig                        : std_logic_vector(1 to NUM_LINKS);
       
       signal rxoutclk_sig                           : std_logic_vector(1 to NUM_LINKS);
       signal txoutclk_sig                           : std_logic_vector(1 to NUM_LINKS);
       
       signal rx_reset_done                          : std_logic_vector(1 to NUM_LINKS);
       signal tx_reset_done                          : std_logic_vector(1 to NUM_LINKS);
       
       signal rxResetDone_r3                         : std_logic_vector         (1 to NUM_LINKS);
       signal txResetDone_r2                         : std_logic_vector         (1 to NUM_LINKS);
       signal rxResetDone_r2                         : std_logic_vector         (1 to NUM_LINKS);
       signal txResetDone_r                          : std_logic_vector         (1 to NUM_LINKS);   
       signal rxResetDone_r                          : std_logic_vector         (1 to NUM_LINKS);    
       
       signal rxfsm_reset_done                       : std_logic_vector(1 to NUM_LINKS);
       signal txfsm_reset_done                       : std_logic_vector(1 to NUM_LINKS);
       
       signal txuserclkRdy                           : std_logic_vector(1 to NUM_LINKS);
       signal rxuserclkRdy                           : std_logic_vector(1 to NUM_LINKS);
       
       signal gtwiz_buffbypass_tx_reset_in_s         : std_logic_vector(1 to NUM_LINKS);
       signal gtwiz_buffbypass_rx_reset_in_s         : std_logic_vector(1 to NUM_LINKS);
       
       signal rxpmaresetdone                         : std_logic_vector(1 to NUM_LINKS);
       signal txpmaresetdone                         : std_logic_vector(1 to NUM_LINKS);
          
       signal run_to_rxBitSlipControl                : std_logic_vector         (1 to NUM_LINKS);
       signal rxBitSlip_from_rxBitSlipControl        : std_logic_vector         (1 to NUM_LINKS);
       signal rxBitSlip_to_gtx                       : std_logic_vector         (1 to NUM_LINKS);   
       signal done_from_rxBitSlipControl             : std_logic_vector         (1 to NUM_LINKS);
                 
       type rstBitSlip_FSM_t                 is (idle, reset_tx, reset_rx);
       type rstBitSlip_FSM_t_A              is array (natural range <>) of rstBitSlip_FSM_t; 
       signal rstBitSlip_FSM                : rstBitSlip_FSM_t_A(1 to NUM_LINKS);
            
       signal mgtRst_from_bitslipCtrl       : std_logic_vector(1 to NUM_LINKS);
       signal rx_reset_sig                                  : std_logic_vector(1 to NUM_LINKS);
       signal tx_reset_sig                                  : std_logic_vector(1 to NUM_LINKS);
       
       signal resetGtxRx_from_rxBitSlipControl            : std_logic_vector         (1 to NUM_LINKS);   
       signal resetGtxTx_from_rxBitSlipControl            : std_logic_vector         (1 to NUM_LINKS);  
       
       signal txprgdivresetdone_int      : std_logic_vector(1 to NUM_LINKS);
       signal gtwiz_userclk_tx_reset_int : std_logic_vector(1 to NUM_LINKS);
       signal gtwiz_userclk_tx_reset_int_bufg_gt_sync_clr, gtwiz_userclk_tx_reset_int_bufg_gt_sync_ce : std_logic_vector(1 to NUM_LINKS);
       
       signal gtwiz_userclk_rx_reset_int : std_logic_vector(1 to NUM_LINKS);
       signal gtwiz_userclk_tx_active_int: std_logic_vector(1 to NUM_LINKS);
       signal gtwiz_userclk_rx_active_int: std_logic_vector(1 to NUM_LINKS);
       signal rxBuffBypassRst            : std_logic_vector(1 to NUM_LINKS);
       signal resetAllMgt                : std_logic_vector(1 to NUM_LINKS);
       
       signal MGT_USRWORD_s              : gbt_reg40_A(1 to NUM_LINKS);
       signal bitSlipCmd_to_bitSlipCtrller : std_logic_vector(1 to NUM_LINKS);
       signal ready_from_bitSlipCtrller    : std_logic_vector(1 to NUM_LINKS);
 
       signal rx_headerlocked_s            : std_logic_vector(1 to NUM_LINKS);
       signal rx_bitslipIsEven_s           : std_logic_vector(1 to NUM_LINKS);

COMPONENT xlx_ku_mgt_ip_gtg_testbeam
  PORT (
    gtwiz_userclk_tx_active_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userclk_rx_active_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_start_user_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_tx_error_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_reset_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_start_user_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_buffbypass_rx_error_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_clk_freerun_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_all_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_pll_and_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_datapath_in : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_cdr_stable_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_tx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_reset_rx_done_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    gtwiz_userdata_tx_in : IN STD_LOGIC_VECTOR(79 DOWNTO 0);
    gtwiz_userdata_rx_out : OUT STD_LOGIC_VECTOR(79 DOWNTO 0);
    gtgrefclk0_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    gtgrefclk1_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    gtrefclk01_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    gtrefclk11_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    qpll1refclksel_in : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    qpll1lock_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    qpll1outclk_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    qpll1outrefclk_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    cpllrefclksel_in : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    gtgrefclk_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    gthrxn_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    gthrxp_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    gtrefclk1_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxoutclksel_in : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    rxpllclksel_in : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    rxsysclksel_in : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    rxusrclk_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxusrclk2_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    txoutclksel_in : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    txpllclksel_in : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    txsysclksel_in : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    txusrclk_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    txusrclk2_in : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    cplllock_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    gthtxn_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    gthtxp_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    gtpowergood_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxoutclk_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    rxpmaresetdone_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    txoutclk_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    txpmaresetdone_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    txprgdivresetdone_out : OUT STD_LOGIC_VECTOR(1 DOWNTO 0) 
  );
  end component;

    type t_gbt_cdc_counter_array is array (1 to NUM_LINKS) of integer range 0 to 3;
    signal s_gbt_cdc_counter_array : t_gbt_cdc_counter_array := (others => 0);


signal s_ku_mgt, s_ku_mgt_from_vio : t_ku_mgt;

--=================================================================================================--
begin                 --========####   Architecture Body   ####========-- 
--=================================================================================================--
    p_ku_mgt_out <= s_ku_mgt;

          xlx_ku_mgt_std_i: xlx_ku_mgt_ip_gtg_testbeam
             PORT MAP (          
                 rxusrclk_in => s_ku_mgt.rxusrclk_in, --rx_wordclk_sig(i),
                 rxusrclk2_in => s_ku_mgt.rxusrclk2_in, --rx_wordclk_sig(i),
                 txusrclk_in => s_ku_mgt.txusrclk_in,--tx_wordclk_sig(i),
                 txusrclk2_in => s_ku_mgt.txusrclk2_in,--tx_wordclk_sig(i),
                 rxoutclk_out => s_ku_mgt.rxoutclk_out,--rxoutclk_sig(i),
                 txoutclk_out => s_ku_mgt.txoutclk_out,--txoutclk_sig(i),
                 
                 gtwiz_userclk_tx_active_in(0)          => s_ku_mgt.gtwiz_userclk_tx_active_in(0),
                 gtwiz_userclk_rx_active_in(0)          => s_ku_mgt.gtwiz_userclk_rx_active_in(0),                 
                 
                 gtwiz_buffbypass_tx_reset_in(0)        => s_ku_mgt.gtwiz_buffbypass_tx_reset_in(0),
                 gtwiz_buffbypass_tx_start_user_in(0)   => s_ku_mgt.gtwiz_buffbypass_tx_start_user_in(0),
                 gtwiz_buffbypass_tx_done_out(0)        => s_ku_mgt.gtwiz_buffbypass_tx_done_out(0),
                 gtwiz_buffbypass_tx_error_out          => s_ku_mgt.gtwiz_buffbypass_tx_error_out,
                 
                 gtwiz_buffbypass_rx_reset_in(0)        => s_ku_mgt.gtwiz_buffbypass_rx_reset_in(0),
                 gtwiz_buffbypass_rx_start_user_in(0)   => s_ku_mgt.gtwiz_buffbypass_rx_start_user_in(0),
                 gtwiz_buffbypass_rx_done_out(0)        => s_ku_mgt.gtwiz_buffbypass_rx_done_out(0),
                 gtwiz_buffbypass_rx_error_out          => s_ku_mgt.gtwiz_buffbypass_rx_error_out,
                 
                 gtwiz_reset_clk_freerun_in(0)          => s_ku_mgt.gtwiz_reset_clk_freerun_in(0),
                 
                 gtwiz_reset_all_in(0)                  => s_ku_mgt.gtwiz_reset_all_in(0),
                 
                 gtwiz_reset_tx_pll_and_datapath_in(0)  => s_ku_mgt.gtwiz_reset_tx_pll_and_datapath_in(0),
                 gtwiz_reset_tx_datapath_in(0)          => s_ku_mgt.gtwiz_reset_tx_datapath_in(0),
                 
                 gtwiz_reset_rx_pll_and_datapath_in(0)  => s_ku_mgt.gtwiz_reset_rx_pll_and_datapath_in(0), -- Same PLL is used for TX and RX !
                 gtwiz_reset_rx_datapath_in(0)          => s_ku_mgt.gtwiz_reset_rx_datapath_in(0),
                 gtwiz_reset_rx_cdr_stable_out          => open,
                 
                 gtwiz_reset_tx_done_out(0)             => s_ku_mgt.gtwiz_reset_tx_done_out(0),
                 gtwiz_reset_rx_done_out(0)             => s_ku_mgt.gtwiz_reset_rx_done_out(0),
                 
                 gtwiz_userdata_tx_in                   => s_ku_mgt.gtwiz_userdata_tx_in,
                 gtwiz_userdata_rx_out                  => s_ku_mgt.gtwiz_userdata_rx_out,

                 gthrxn_in                              => s_ku_mgt.gthrxn_in,
                 gthrxp_in                              => s_ku_mgt.gthrxp_in,
                 gthtxn_out                             => s_ku_mgt.gthtxn_out,
                 gthtxp_out                             => s_ku_mgt.gthtxp_out,

                 gtrefclk1_in                           => s_ku_mgt.gtrefclk1_in,

                 cplllock_out                           => s_ku_mgt.cplllock_out,
                 qpll1lock_out                          => s_ku_mgt.qpll1lock_out,
                 
                 
                 rxpmaresetdone_out                     => s_ku_mgt.rxpmaresetdone_out,
                 txpmaresetdone_out                     => s_ku_mgt.txpmaresetdone_out,
                 
                 gtrefclk01_in                          => s_ku_mgt.gtrefclk01_in,
                 gtrefclk11_in                          => s_ku_mgt.gtrefclk11_in,
                 
                 gtgrefclk0_in                          => s_ku_mgt.gtgrefclk0_in,
                 gtgrefclk1_in                          => s_ku_mgt.gtgrefclk1_in,
                 gtgrefclk_in                           => s_ku_mgt.gtgrefclk_in,
                 qpll1refclksel_in                      => s_ku_mgt.qpll1refclksel_in,
                 cpllrefclksel_in                       => s_ku_mgt.cpllrefclksel_in,
                 
                 rxoutclksel_in                         => s_ku_mgt.rxoutclksel_in,
                 rxpllclksel_in                         => s_ku_mgt.rxpllclksel_in,
                 rxsysclksel_in                         => s_ku_mgt.rxsysclksel_in,
                 txoutclksel_in                         => s_ku_mgt.txoutclksel_in,
                 txpllclksel_in                         => s_ku_mgt.txpllclksel_in,
                 txsysclksel_in                         => s_ku_mgt.txsysclksel_in                
                
             );     


         s_ku_mgt.gtgrefclk0_in(0) <= '0'; --p_clknet_in.mmcm_refclk80; --p_clknet_in.mmcm_refclk240;--p_clknet_in.mmcm_refclk160;--p_clknet_in.mmcm_refclk80;--p_clknet_in.refclk240;--p_clknet_in.refclk80;
         s_ku_mgt.gtgrefclk1_in(0) <= '0'; --p_clknet_in.mmcm_refclk80; --p_clknet_in.mmcm_refclk240;--p_clknet_in.mmcm_refclk80;--p_clknet_in.refclk240; --p_clknet_in.refclk80;
         s_ku_mgt.gtgrefclk0_in(1) <= '0'; --p_clknet_in.mmcm_refclk80; --p_clknet_in.mmcm_refclk240;--p_clknet_in.mmcm_refclk160;--p_clknet_in.mmcm_refclk80;--p_clknet_in.refclk240;--p_clknet_in.refclk80;
         s_ku_mgt.gtgrefclk1_in(1) <= '0'; --p_clknet_in.mmcm_refclk80; --p_clknet_in.mmcm_refclk240;--p_clknet_in.mmcm_refclk80;--p_clknet_in.refclk240; --p_clknet_in.refclk80;

         s_ku_mgt.qpll1refclksel_in <= p_clknet_in.qpllclksel & p_clknet_in.qpllclksel;

         
        s_ku_mgt.gtwiz_userclk_tx_active_in(0)          <= gtwiz_userclk_tx_active_int(1) or gtwiz_userclk_tx_active_int(2); --channel 0 with priviledge
        s_ku_mgt.gtwiz_userclk_rx_active_in(0)          <= gtwiz_userclk_rx_active_int(1) or gtwiz_userclk_rx_active_int(2); --channel 0 with priviledge              
        
        s_ku_mgt.gtwiz_buffbypass_tx_reset_in(0)        <= (gtwiz_buffbypass_tx_reset_in_s(1) or gtwiz_buffbypass_tx_reset_in_s(2)) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_buffbypass_tx_reset_bit); --channel 0 with priviledge
        s_ku_mgt.gtwiz_buffbypass_tx_start_user_in(0)   <= '0' or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_buffbypass_tx_start_use_bit);
        s_ku_mgt.gtwiz_buffbypass_tx_done_out(0)        <= txfsm_reset_done(1); --channel 0 with priviledge
        
        s_ku_mgt.gtwiz_buffbypass_rx_reset_in(0)        <= gtwiz_buffbypass_rx_reset_in_s(1) and gtwiz_buffbypass_rx_reset_in_s(2); --channel 0 with priviledge
        s_ku_mgt.gtwiz_buffbypass_rx_start_user_in(0)   <= '0';
        s_ku_mgt.gtwiz_buffbypass_rx_done_out(0)        <= rxfsm_reset_done(1); --channel 0 with priviledge
                
        s_ku_mgt.gtwiz_reset_clk_freerun_in(0)          <= MGT_DEVSPEC_i.reset_freeRunningClock(1);
        
        s_ku_mgt.gtwiz_reset_all_in(0)                  <= '0';
        
        s_ku_mgt.gtwiz_reset_tx_pll_and_datapath_in(0)  <= (tx_reset_sig(1) and tx_reset_sig(2)) or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_reset_tx_datapath_bit);
        s_ku_mgt.gtwiz_reset_tx_datapath_in(0)          <= '0'or p_db_reg_rx_in(cfb_strobe_reg)(c_gth_reset_tx_pll_and_datapath_bit);

        s_ku_mgt.gtwiz_reset_rx_pll_and_datapath_in(0)  <= '0'; -- Same PLL is used for TX and RX !
        s_ku_mgt.gtwiz_reset_rx_datapath_in(0)          <= rx_reset_sig(1); --channel 0 with priviledge
        s_ku_mgt.gtrefclk11_in(0)                          <= MGT_REFCLK_i(1);
        s_ku_mgt.gtrefclk11_in(1)                          <= MGT_REFCLK_i(2);
  
   --==================================== User Logic =====================================--
   gtxLatOpt_gen: for i in 1 to NUM_LINKS generate

            s_ku_mgt.gtwiz_userdata_tx_in((i)*40-1 downto (i-1)*40)                   <= MGT_USRWORD_i(i);


         s_ku_mgt.rxoutclksel_in((i*3-1) downto (3*(i-1))) <= p_clknet_in.rxoutclksel;
         s_ku_mgt.rxpllclksel_in((i*2-1) downto (2*(i-1))) <= p_clknet_in.rxpllclksel;
         s_ku_mgt.rxsysclksel_in((i*2-1) downto (2*(i-1))) <= p_clknet_in.rxsysclksel;
         s_ku_mgt.txoutclksel_in((i*3-1) downto (3*(i-1))) <= p_clknet_in.txoutclksel;
         s_ku_mgt.txpllclksel_in((i*2-1) downto (2*(i-1))) <= p_clknet_in.txpllclksel;
         s_ku_mgt.txsysclksel_in((i*2-1) downto (2*(i-1))) <= p_clknet_in.txsysclksel;

        s_ku_mgt.gtgrefclk_in(i-1) <= '0';
        s_ku_mgt.cpllrefclksel_in((i)*3-1 downto (i-1)*3) <= p_clknet_in.cpllclksel;

        tx_wordclk_sig_muxed(i)<= tx_wordclk240_sig(i);--p_clknet_in.mmcm_refclk240; --tx_wordclk480_sig(i); --p_clknet_in.mmcm_refclk240; --tx_wordclk_sig(1); --tx_wordclk_sig(i); --p_clknet_in.mmcm_refclk240;
        
        
        s_ku_mgt.rxusrclk_in(i-1) <= rx_wordclk_sig(i);
        s_ku_mgt.rxusrclk2_in(i-1) <= rx_wordclk_sig(i);
        s_ku_mgt.txusrclk_in(i-1) <= tx_wordclk_sig_muxed(i);--tx_wordclk_sig(i);--p_clknet_in.refclk240;--tx_wordclk_sig(i);
        s_ku_mgt.txusrclk2_in(i-1) <= tx_wordclk_sig_muxed(i);--tx_wordclk_sig(i);--p_clknet_in.refclk240;-- tx_wordclk_sig(i);

        s_ku_mgt.tx_wordclk(i-1) <= tx_wordclk_sig_muxed(i);--tx_wordclk_sig(i);--p_clknet_in.refclk240;--tx_wordclk_sig(i);
        s_ku_mgt.tx_frameclk(i-1) <= tx_wordclk_sig_muxed(i);--tx_wordclk_sig(i); --p_clknet_in.mmcm_refclk240; --p_clknet_in.mmcm_refclk80;--tx_frameclk_sig(i);
        s_ku_mgt.tx_frameclk40(i-1) <= p_clknet_in.mmcm_refclk40;-- p_clknet_in.refclk40;--tx_frameclk40_sig(i);

        rxoutclk_sig(i) <= s_ku_mgt.rxoutclk_out(i-1);
        txoutclk_sig(i) <= s_ku_mgt.txoutclk_out(i-1);
        
        tx_reset_done(i) <= s_ku_mgt.gtwiz_reset_tx_done_out(0);
        rx_reset_done(i) <= s_ku_mgt.gtwiz_reset_rx_done_out(0);

        MGT_USRWORD_s(i)                                                          <= s_ku_mgt.gtwiz_userdata_rx_out((i)*40-1 downto (i-1)*40);

        s_ku_mgt.drpaddr_in((i)*9-1 downto (i-1)*9)                             <= MGT_DEVSPEC_i.drp_addr(i);
        s_ku_mgt.drpclk_in(i-1)                                                 <= MGT_DEVSPEC_i.drp_clk(i);
        s_ku_mgt.drpdi_in((i)*16-1 downto (i-1)*16)                               <= MGT_DEVSPEC_i.drp_di(i);
        s_ku_mgt.drpen_in(i-1)                            <= MGT_DEVSPEC_i.drp_en(i);
        s_ku_mgt.drpwe_in(i-1)                            <= MGT_DEVSPEC_i.drp_we(i);
        MGT_DEVSPEC_o.drp_do(i)                                                 <=s_ku_mgt.drpdo_out((i)*16-1 downto (i-1)*16);
        MGT_DEVSPEC_o.drp_rdy(i)                          <= s_ku_mgt.drprdy_out(i-1);
        
        s_ku_mgt.gthrxn_in(i-1)                           <= MGT_DEVSPEC_i.rx_n(i);
        s_ku_mgt.gthrxp_in(i-1)                           <= MGT_DEVSPEC_i.rx_p(i);
        MGT_DEVSPEC_o.tx_n(i)                             <= s_ku_mgt.gthtxn_out(i-1);
        MGT_DEVSPEC_o.tx_p(i)                             <= s_ku_mgt.gthtxp_out(i-1);
        
        --s_ku_mgt.gtrefclk0_in(i-1)                        <= MGT_REFCLK_i;
        s_ku_mgt.gtrefclk1_in(i-1)                        <= MGT_REFCLK_i(i);

        s_ku_mgt.loopback_in((i)*3-1 downto (i-1)*3)                            <= MGT_DEVSPEC_i.loopBack(i);  
        s_ku_mgt.rxpolarity_in(i-1)                       <= MGT_DEVSPEC_i.conf_rxPol(i);
        s_ku_mgt.txpolarity_in(i-1)                       <= MGT_DEVSPEC_i.conf_txPol(i);

        s_ku_mgt.rxslide_in(i-1)                          <= rxBitSlip_to_gtx(i);
        
        s_ku_mgt.txdiffctrl_in((i)*4-1 downto (i-1)*4)                          <= MGT_DEVSPEC_i.conf_diffCtrl(i);
        s_ku_mgt.txpostcursor_in((i)*5-1 downto (i-1)*5)                        <= MGT_DEVSPEC_i.conf_postCursor(i);
        s_ku_mgt.txprecursor_in((i)*5-1 downto (i-1)*5)                         <= MGT_DEVSPEC_i.conf_preCursor(i);
        
        rxpmaresetdone(i)                                 <= s_ku_mgt.rxpmaresetdone_out(i-1);
        txpmaresetdone(i)                                 <= s_ku_mgt.txpmaresetdone_out(i-1);
        
      --=============--
      -- Assignments --
      --=============--              
         MGT_TXREADY_o(i)          <= tx_reset_done(i) and txfsm_reset_done(i);
         MGT_RXREADY_o(i)          <= rx_reset_done(i) and rxfsm_reset_done(i) and done_from_rxBitSlipControl(i);
           
         MGT_RXUSRCLK_o(i)         <= rx_wordclk_sig(i);   
         MGT_TXUSRCLK_o(i)         <= tx_wordclk_sig_muxed(i); --tx_wordclk_sig(i);--tx_wordclk_sig(i); --p_clknet_in.mmcm_refclk240;--tx_wordclk_sig(i);
          
         MGT_USRWORD_o(i)    <= MGT_USRWORD_s(i);
      
         rx_reset_sig(i)                  <= MGT_RXRESET_i(i) or resetGtxRx_from_rxBitSlipControl(i);
         tx_reset_sig(i)                  <= MGT_TXRESET_i(i) or resetGtxTx_from_rxBitSlipControl(i);

          gtwiz_userclk_tx_active_int(i) <= txpmaresetdone(i);
          activetxUsrClk_proc: process(txpmaresetdone(i),tx_wordclk240_sig(i), p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_ch0_reset_bit+i-1))--tx_wordclk_sig(i))-- p_clknet_in.mmcm_refclk240) --p_clknet_in.mmcm_refclk40)--  tx_wordclk_sig(i))
          begin
            if (txpmaresetdone(i) = '0') or (p_db_reg_rx_in(cfb_strobe_reg)(c_gbt_ch0_reset_bit+i-1)= '1') then
                gtwiz_buffbypass_tx_reset_in_s(i) <= '1';
            elsif rising_edge(tx_wordclk240_sig(i)) then --(p_clknet_in.mmcm_refclk240) then--tx_wordclk_sig(i)) then
                if (p_clknet_in.gbt_cdc_counter_array(i-1) = 2) then -- and (s_gbt_cdc_counter_array(i) = 1) then
                    gtwiz_buffbypass_tx_reset_in_s(i) <= not gtwiz_userclk_tx_active_int(i);
                end if;
            end if;
            
          end process;

            txWordClk240Buf_inst: bufg_gt
              port map (
                 O                                        => tx_wordclk240_sig(i), 
                 I                                        => txoutclk_sig(i),
                 CE                                       => gtwiz_userclk_tx_reset_int_bufg_gt_sync_ce(i),
                 DIV                                      => "000",
                 CLR                                      => gtwiz_userclk_tx_reset_int_bufg_gt_sync_clr(i),
                 CLRMASK                                  => '0',
                 CEMASK                                   => '0'
              ); 

            
            BUFG_GT_SYNC_inst : BUFG_GT_SYNC
            port map (
               CESYNC => gtwiz_userclk_tx_reset_int_bufg_gt_sync_ce(i),   -- 1-bit output: Synchronized CE
               CLRSYNC => gtwiz_userclk_tx_reset_int_bufg_gt_sync_clr(i), -- 1-bit output: Synchronized CLR
               CE => gtwiz_userclk_tx_active_int(i),--not gtwiz_userclk_tx_reset_int(i),--gtwiz_userclk_tx_active_int(i),           -- 1-bit input: Asynchronous enable
               CLK => txoutclk_sig(i),         -- 1-bit input: Clock
               CLR => '0'          -- 1-bit input: Asynchronous clear
            );

    end generate;
    
   
end structural;
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--