----------------------------------------------------------------------------------
-- Module Name: db6_adc_interface_io_hss - Behavioral
--
-- ADC readout front end using the Xilinx SelectIO Interface Wizard
-- (high_speed_selectio_wiz v3.6) instead of hand-instantiated ISERDESE3/IDDR
-- primitives. 280MHz DDR (560Mbps) bit clock, SERIALIZATION_FACTOR=4,
-- PLL0_RX_EXTERNAL_CLK_TO_DATA=1 (CENTER_DDR: the ADC's bit clock is free
-- running, drives PLL0 directly, and is center-aligned with the data eye --
-- matches how this board's LVDS ADC actually forwards its clock).
--
-- One SEPARATE IP customization per ADC channel (hss_adc_ch0..hss_adc_ch4,
-- plus hss_adc for channel 5) rather than one shared IP instantiated 6 times.
-- This is required, not just tidier: the wizard's own auto-generated XDC
-- (hss_adc.xdc) bakes real PACKAGE_PIN LOCs for its internal shared-PLL/RIU
-- bitslices into the IP's out-of-context synthesis checkpoint, based on
-- whatever CONFIG.BANK the IP was customized for. Reusing one IP's netlist
-- across 6 different physical banks makes every instance's internal cells
-- fight over the identical baked-in site -- confirmed on hardware by a
-- BITSLICE_RX_TX site conflict at implementation ("bel is occupied ... by
-- ...gen_adc_channels[0]...RX_BS[32]..." when channel 1's instance tried to
-- place the same cell). Six separately-customized IPs, each targeting its
-- channel's real bank, avoids this: each gets correct, non-colliding LOCs.
--
-- hss_adc's own RX FIFO (fifo_rd_clk_*) is read at cfgbus_clk40 (40MHz,
-- matching the ADC frame rate) rather than at the ~140MHz PLL0 output --
-- this makes the FIFO itself the CDC bridge from the write-side (bitclk/4)
-- domain into the cfgbus_clk40 domain that db6_adc_interface_decoder_iserdese
-- / db6_gbt_encoder_sc run on, so p_adc_bitclkdiv_out (the decoder's clock)
-- is simply tied to cfgbus_clk40 -- no separate synchronizer needed.
--
-- Pin group: on this board, every channel's bitclk/frameclk/lg/hg pads
-- physically land in the T2 byte-group of their bank (confirmed via each
-- pin's PIN_FUNC, e.g. channel 0's lg pad G15 = IO_L15P_T2L_N4..._68) --
-- wizard byte-group numbers map to fixed physical T-groups (BYTE2=T2, not a
-- free relabeling), so each IP is configured with bitclk on BYTE2_PIN0 (the
-- wizard's dedicated PLL0 clock-in slot) and frameclk/lg/hg differential
-- pairs on BYTE2_PIN2/3, PIN4/5, PIN6/7.
--
-- Each channel's GBTx-forwarded 40MHz and 80MHz clocks (already wired to the
-- FPGA per-bank, at IO_L12P_T1U_N10_GC_XX / IO_L11P_T1U_N8_GC_XX and their
-- differential pairs -- these are BYTE1_PIN10/11 and BYTE1_PIN8/9 in this
-- same bank) are ALSO deserialized as data through the same per-channel
-- hss_adc instance, on BYTE1_PIN8/9 ("gbtx_clk80") and BYTE1_PIN10/11
-- ("gbtx_clk40"). This is the same T1 byte-group across every bank as the
-- pre-existing (dead) p_adc_gbtx_frameclk_in constraints from before this
-- port was rewired onto hss_adc -- confirmed pin-for-pin identical via
-- CONFIG.BYTE1_PIN8/10_LOC per bank, e.g. bank 68 channel 0's clk40 P leg is
-- E18, matching the old p_adc_gbtx_frameclk_in[0][p].
--
-- Each hss_adc-configured differential pin pair (e.g. adc_lg_30 / bg2_pin5_31)
-- exposes a data_to_fabric_* port on BOTH the P pin (custom-named, e.g.
-- adc_lg_30) and the N pin (default-named, e.g. bg2_pin5_31); per the IP's
-- own generated hss_adc.xdc, both P and N are separate top-level LVDS ports
-- with DIFF_TERM_ADV, and only the P side's data_to_fabric_* output is used
-- here (the N side's is left open) -- confirm bit ordering and P/N semantics
-- in simulation/hardware bring-up.
--
-- db6_adc_interface_decoder_iserdese only reads bits (3 downto 0) of each
-- t_byteslice_sr element, so the wizard's 4-bit data_to_fabric_* output is
-- packed directly into that nibble; bits (7 downto 4) are unused/tied to 0.
-- The same packing is used for the newly-deserialized gbtx_clk40/80 data,
-- exposed via p_gbtx_clk40_data_out / p_gbtx_clk80_data_out -- nothing
-- consumes these yet (no downstream use was specified), they're just made
-- available for future debug/monitoring use.
--
-- hss_adc's PLL0/RIU clock-distribution hardware is shared across the whole
-- I/O bank (CONFIG.PLL_SHARING=1, locked -- not a configurable choice for
-- this device's HP banks in Native+FIFO RX mode). With only BYTE2 populated
-- this needed 2 placeholder bitslices (bg3_pin0_nc/bg3_pin12_51); now that
-- BYTE1 also carries real data, the wizard additionally claims BYTE1's own
-- pin0 (bg1_pin0_nc) as a third placeholder. None of the three carry real
-- data but all are I/O-bound cells that must be placed on a real package
-- pin. p_adc_hss_aux0/1/2_in feed them (aux0=bg3_pin0_nc, aux1=bg3_pin12_51,
-- aux2=bg1_pin0_nc), one bit per channel; the actual pin per channel is
-- whatever that channel's own IP customization natively assigns (see
-- constraints/db6v5.xdc), read back via CONFIG.BYTE1_PIN0_LOC /
-- BYTE3_PIN0_LOC / BYTE3_PIN12_LOC on each per-channel IP.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library tilecal;
use tilecal.db6_design_package.all;

library UNISIM;
use UNISIM.VComponents.all;

entity db6_adc_interface_io_hss is
    port (
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;
        --inputs
        p_adc_bitclk_in   : in t_adc_clk_in;
        p_adc_frameclk_in : in t_adc_clk_in;
        p_adc_lg_data_in  : in t_adc_data_in;
        p_adc_hg_data_in  : in t_adc_data_in;
        -- hss_adc PLL/RIU sharing placeholder pins, one bit per channel (see header)
        p_adc_hss_aux0_in : in std_logic_vector(5 downto 0);
        p_adc_hss_aux1_in : in std_logic_vector(5 downto 0);
        p_adc_hss_aux2_in : in std_logic_vector(5 downto 0);

        -- GBTx-forwarded 40MHz/80MHz clocks, per bank, deserialized as data on the
        -- same per-channel hss_adc instance (see header)
        p_gbtx_clk40_b68_in : in t_diff_pair;
        p_gbtx_clk40_b67_in : in t_diff_pair;
        p_gbtx_clk40_b66_in : in t_diff_pair;
        p_gbtx_clk40_b47_in : in t_diff_pair;
        p_gbtx_clk40_b46_in : in t_diff_pair;
        p_gbtx_clk40_b44_in : in t_diff_pair;
        p_gbtx_clk80_b68_in : in t_diff_pair;
        p_gbtx_clk80_b67_in : in t_diff_pair;
        p_gbtx_clk80_b66_in : in t_diff_pair;
        p_gbtx_clk80_b47_in : in t_diff_pair;
        p_gbtx_clk80_b46_in : in t_diff_pair;
        p_gbtx_clk80_b44_in : in t_diff_pair;

        --outputs
        p_adc_bitclk_out          : out std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_out       : out std_logic_vector(5 downto 0);
        p_frame_missalignment_in  : in  std_logic_vector(5 downto 0);
        p_ctrl_reset_from_sm_out  : out std_logic_vector(5 downto 0);
        p_adc_frameclk_out        : out t_byteslice_sr;
        p_adc_lg_data_out         : out t_byteslice_sr;
        p_adc_hg_data_out         : out t_byteslice_sr;
        -- deserialized gbtx_clk40/80 data, one t_byteslice_sr element per channel
        -- (channel index matches p_adc_lg_data_out etc: 0=bank68 .. 5=bank44);
        -- not consumed anywhere yet, see header
        p_gbtx_clk40_data_out     : out t_byteslice_sr;
        p_gbtx_clk80_data_out     : out t_byteslice_sr;

        --control
        p_adc_readout_control_in : in t_adc_readout_control;

        --debug
        p_leds_out      : out std_logic_vector(3 downto 0);
        -- per-channel hss_adc internal status, for vio_clknet_status hardware debug:
        -- did this channel's PLL0 lock, and did its reset sequencer complete? (see
        -- header -- these are the two prerequisites for any real data to flow at all)
        p_pll0_locked_out      : out std_logic_vector(5 downto 0);
        p_rst_seq_done_out     : out std_logic_vector(5 downto 0);
        p_fifo_data_valid_out  : out std_logic_vector(5 downto 0)
    );
end db6_adc_interface_io_hss;

architecture Behavioral of db6_adc_interface_io_hss is

    -- identical port list for all 6 (per-channel IP customizations differ only in
    -- which bank/pins their internal LOCs point at -- see header)
    component hss_adc_ch0
      PORT (
        fifo_rd_data_valid : OUT STD_LOGIC;
        fifo_rd_clk_21 : IN STD_LOGIC;
        fifo_rd_clk_22 : IN STD_LOGIC;
        fifo_rd_clk_23 : IN STD_LOGIC;
        fifo_rd_clk_24 : IN STD_LOGIC;
        fifo_rd_clk_28 : IN STD_LOGIC;
        fifo_rd_clk_29 : IN STD_LOGIC;
        fifo_rd_clk_30 : IN STD_LOGIC;
        fifo_rd_clk_31 : IN STD_LOGIC;
        fifo_rd_clk_32 : IN STD_LOGIC;
        fifo_rd_clk_33 : IN STD_LOGIC;
        fifo_rd_clk_51 : IN STD_LOGIC;
        fifo_empty_21 : OUT STD_LOGIC;
        fifo_empty_22 : OUT STD_LOGIC;
        fifo_empty_23 : OUT STD_LOGIC;
        fifo_empty_24 : OUT STD_LOGIC;
        fifo_empty_28 : OUT STD_LOGIC;
        fifo_empty_29 : OUT STD_LOGIC;
        fifo_empty_30 : OUT STD_LOGIC;
        fifo_empty_31 : OUT STD_LOGIC;
        fifo_empty_32 : OUT STD_LOGIC;
        fifo_empty_33 : OUT STD_LOGIC;
        fifo_empty_51 : OUT STD_LOGIC;
        vtc_rdy_bsc2 : OUT STD_LOGIC;
        en_vtc_bsc2 : IN STD_LOGIC;
        vtc_rdy_bsc3 : OUT STD_LOGIC;
        en_vtc_bsc3 : IN STD_LOGIC;
        vtc_rdy_bsc4 : OUT STD_LOGIC;
        en_vtc_bsc4 : IN STD_LOGIC;
        vtc_rdy_bsc5 : OUT STD_LOGIC;
        en_vtc_bsc5 : IN STD_LOGIC;
        vtc_rdy_bsc6 : OUT STD_LOGIC;
        en_vtc_bsc6 : IN STD_LOGIC;
        vtc_rdy_bsc7 : OUT STD_LOGIC;
        en_vtc_bsc7 : IN STD_LOGIC;
        dly_rdy_bsc2 : OUT STD_LOGIC;
        dly_rdy_bsc3 : OUT STD_LOGIC;
        dly_rdy_bsc4 : OUT STD_LOGIC;
        dly_rdy_bsc5 : OUT STD_LOGIC;
        dly_rdy_bsc6 : OUT STD_LOGIC;
        dly_rdy_bsc7 : OUT STD_LOGIC;
        rst_seq_done : OUT STD_LOGIC;
        shared_pll0_clkoutphy_out : OUT STD_LOGIC;
        pll0_clkout0 : OUT STD_LOGIC;
        rst : IN STD_LOGIC;
        clk : IN STD_LOGIC;
        riu_clk : IN STD_LOGIC;
        pll0_locked : OUT STD_LOGIC;
        bg1_pin0_nc : IN STD_LOGIC;
        bg3_pin0_nc : IN STD_LOGIC;
        gbtx_clk80_21 : IN STD_LOGIC;
        data_to_fabric_gbtx_clk80_21 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin9_22 : IN STD_LOGIC;
        data_to_fabric_bg1_pin9_22 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        gbtx_clk40_23 : IN STD_LOGIC;
        data_to_fabric_gbtx_clk40_23 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin11_24 : IN STD_LOGIC;
        data_to_fabric_bg1_pin11_24 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_fc_28 : IN STD_LOGIC;
        data_to_fabric_adc_fc_28 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin3_29 : IN STD_LOGIC;
        data_to_fabric_bg2_pin3_29 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_lg_30 : IN STD_LOGIC;
        data_to_fabric_adc_lg_30 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin5_31 : IN STD_LOGIC;
        data_to_fabric_bg2_pin5_31 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_hg_32 : IN STD_LOGIC;
        data_to_fabric_adc_hg_32 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin7_33 : IN STD_LOGIC;
        data_to_fabric_bg2_pin7_33 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg3_pin12_51 : IN STD_LOGIC;
        data_to_fabric_bg3_pin12_51 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
    end component;

    component hss_adc_ch1 is port (
        fifo_rd_data_valid : OUT STD_LOGIC; fifo_rd_clk_21 : IN STD_LOGIC; fifo_rd_clk_22 : IN STD_LOGIC;
        fifo_rd_clk_23 : IN STD_LOGIC; fifo_rd_clk_24 : IN STD_LOGIC;
        fifo_rd_clk_28 : IN STD_LOGIC; fifo_rd_clk_29 : IN STD_LOGIC;
        fifo_rd_clk_30 : IN STD_LOGIC; fifo_rd_clk_31 : IN STD_LOGIC; fifo_rd_clk_32 : IN STD_LOGIC;
        fifo_rd_clk_33 : IN STD_LOGIC; fifo_rd_clk_51 : IN STD_LOGIC;
        fifo_empty_21 : OUT STD_LOGIC; fifo_empty_22 : OUT STD_LOGIC; fifo_empty_23 : OUT STD_LOGIC; fifo_empty_24 : OUT STD_LOGIC;
        fifo_empty_28 : OUT STD_LOGIC;
        fifo_empty_29 : OUT STD_LOGIC; fifo_empty_30 : OUT STD_LOGIC; fifo_empty_31 : OUT STD_LOGIC;
        fifo_empty_32 : OUT STD_LOGIC; fifo_empty_33 : OUT STD_LOGIC; fifo_empty_51 : OUT STD_LOGIC;
        vtc_rdy_bsc2 : OUT STD_LOGIC; en_vtc_bsc2 : IN STD_LOGIC; vtc_rdy_bsc3 : OUT STD_LOGIC; en_vtc_bsc3 : IN STD_LOGIC;
        vtc_rdy_bsc4 : OUT STD_LOGIC; en_vtc_bsc4 : IN STD_LOGIC; vtc_rdy_bsc5 : OUT STD_LOGIC;
        en_vtc_bsc5 : IN STD_LOGIC; vtc_rdy_bsc6 : OUT STD_LOGIC; en_vtc_bsc6 : IN STD_LOGIC;
        vtc_rdy_bsc7 : OUT STD_LOGIC; en_vtc_bsc7 : IN STD_LOGIC;
        dly_rdy_bsc2 : OUT STD_LOGIC; dly_rdy_bsc3 : OUT STD_LOGIC; dly_rdy_bsc4 : OUT STD_LOGIC;
        dly_rdy_bsc5 : OUT STD_LOGIC; dly_rdy_bsc6 : OUT STD_LOGIC; dly_rdy_bsc7 : OUT STD_LOGIC;
        rst_seq_done : OUT STD_LOGIC; shared_pll0_clkoutphy_out : OUT STD_LOGIC; pll0_clkout0 : OUT STD_LOGIC;
        rst : IN STD_LOGIC; clk : IN STD_LOGIC; riu_clk : IN STD_LOGIC; pll0_locked : OUT STD_LOGIC;
        bg1_pin0_nc : IN STD_LOGIC; bg3_pin0_nc : IN STD_LOGIC;
        gbtx_clk80_21 : IN STD_LOGIC; data_to_fabric_gbtx_clk80_21 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin9_22 : IN STD_LOGIC; data_to_fabric_bg1_pin9_22 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        gbtx_clk40_23 : IN STD_LOGIC; data_to_fabric_gbtx_clk40_23 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin11_24 : IN STD_LOGIC; data_to_fabric_bg1_pin11_24 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_fc_28 : IN STD_LOGIC; data_to_fabric_adc_fc_28 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin3_29 : IN STD_LOGIC; data_to_fabric_bg2_pin3_29 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_lg_30 : IN STD_LOGIC; data_to_fabric_adc_lg_30 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin5_31 : IN STD_LOGIC; data_to_fabric_bg2_pin5_31 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_hg_32 : IN STD_LOGIC; data_to_fabric_adc_hg_32 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin7_33 : IN STD_LOGIC; data_to_fabric_bg2_pin7_33 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg3_pin12_51 : IN STD_LOGIC; data_to_fabric_bg3_pin12_51 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
    end component;

    component hss_adc_ch2 is port (
        fifo_rd_data_valid : OUT STD_LOGIC; fifo_rd_clk_21 : IN STD_LOGIC; fifo_rd_clk_22 : IN STD_LOGIC;
        fifo_rd_clk_23 : IN STD_LOGIC; fifo_rd_clk_24 : IN STD_LOGIC;
        fifo_rd_clk_28 : IN STD_LOGIC; fifo_rd_clk_29 : IN STD_LOGIC;
        fifo_rd_clk_30 : IN STD_LOGIC; fifo_rd_clk_31 : IN STD_LOGIC; fifo_rd_clk_32 : IN STD_LOGIC;
        fifo_rd_clk_33 : IN STD_LOGIC; fifo_rd_clk_51 : IN STD_LOGIC;
        fifo_empty_21 : OUT STD_LOGIC; fifo_empty_22 : OUT STD_LOGIC; fifo_empty_23 : OUT STD_LOGIC; fifo_empty_24 : OUT STD_LOGIC;
        fifo_empty_28 : OUT STD_LOGIC;
        fifo_empty_29 : OUT STD_LOGIC; fifo_empty_30 : OUT STD_LOGIC; fifo_empty_31 : OUT STD_LOGIC;
        fifo_empty_32 : OUT STD_LOGIC; fifo_empty_33 : OUT STD_LOGIC; fifo_empty_51 : OUT STD_LOGIC;
        vtc_rdy_bsc2 : OUT STD_LOGIC; en_vtc_bsc2 : IN STD_LOGIC; vtc_rdy_bsc3 : OUT STD_LOGIC; en_vtc_bsc3 : IN STD_LOGIC;
        vtc_rdy_bsc4 : OUT STD_LOGIC; en_vtc_bsc4 : IN STD_LOGIC; vtc_rdy_bsc5 : OUT STD_LOGIC;
        en_vtc_bsc5 : IN STD_LOGIC; vtc_rdy_bsc6 : OUT STD_LOGIC; en_vtc_bsc6 : IN STD_LOGIC;
        vtc_rdy_bsc7 : OUT STD_LOGIC; en_vtc_bsc7 : IN STD_LOGIC;
        dly_rdy_bsc2 : OUT STD_LOGIC; dly_rdy_bsc3 : OUT STD_LOGIC; dly_rdy_bsc4 : OUT STD_LOGIC;
        dly_rdy_bsc5 : OUT STD_LOGIC; dly_rdy_bsc6 : OUT STD_LOGIC; dly_rdy_bsc7 : OUT STD_LOGIC;
        rst_seq_done : OUT STD_LOGIC; shared_pll0_clkoutphy_out : OUT STD_LOGIC; pll0_clkout0 : OUT STD_LOGIC;
        rst : IN STD_LOGIC; clk : IN STD_LOGIC; riu_clk : IN STD_LOGIC; pll0_locked : OUT STD_LOGIC;
        bg1_pin0_nc : IN STD_LOGIC; bg3_pin0_nc : IN STD_LOGIC;
        gbtx_clk80_21 : IN STD_LOGIC; data_to_fabric_gbtx_clk80_21 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin9_22 : IN STD_LOGIC; data_to_fabric_bg1_pin9_22 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        gbtx_clk40_23 : IN STD_LOGIC; data_to_fabric_gbtx_clk40_23 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin11_24 : IN STD_LOGIC; data_to_fabric_bg1_pin11_24 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_fc_28 : IN STD_LOGIC; data_to_fabric_adc_fc_28 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin3_29 : IN STD_LOGIC; data_to_fabric_bg2_pin3_29 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_lg_30 : IN STD_LOGIC; data_to_fabric_adc_lg_30 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin5_31 : IN STD_LOGIC; data_to_fabric_bg2_pin5_31 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_hg_32 : IN STD_LOGIC; data_to_fabric_adc_hg_32 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin7_33 : IN STD_LOGIC; data_to_fabric_bg2_pin7_33 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg3_pin12_51 : IN STD_LOGIC; data_to_fabric_bg3_pin12_51 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
    end component;

    component hss_adc_ch3 is port (
        fifo_rd_data_valid : OUT STD_LOGIC; fifo_rd_clk_21 : IN STD_LOGIC; fifo_rd_clk_22 : IN STD_LOGIC;
        fifo_rd_clk_23 : IN STD_LOGIC; fifo_rd_clk_24 : IN STD_LOGIC;
        fifo_rd_clk_28 : IN STD_LOGIC; fifo_rd_clk_29 : IN STD_LOGIC;
        fifo_rd_clk_30 : IN STD_LOGIC; fifo_rd_clk_31 : IN STD_LOGIC; fifo_rd_clk_32 : IN STD_LOGIC;
        fifo_rd_clk_33 : IN STD_LOGIC; fifo_rd_clk_51 : IN STD_LOGIC;
        fifo_empty_21 : OUT STD_LOGIC; fifo_empty_22 : OUT STD_LOGIC; fifo_empty_23 : OUT STD_LOGIC; fifo_empty_24 : OUT STD_LOGIC;
        fifo_empty_28 : OUT STD_LOGIC;
        fifo_empty_29 : OUT STD_LOGIC; fifo_empty_30 : OUT STD_LOGIC; fifo_empty_31 : OUT STD_LOGIC;
        fifo_empty_32 : OUT STD_LOGIC; fifo_empty_33 : OUT STD_LOGIC; fifo_empty_51 : OUT STD_LOGIC;
        vtc_rdy_bsc2 : OUT STD_LOGIC; en_vtc_bsc2 : IN STD_LOGIC; vtc_rdy_bsc3 : OUT STD_LOGIC; en_vtc_bsc3 : IN STD_LOGIC;
        vtc_rdy_bsc4 : OUT STD_LOGIC; en_vtc_bsc4 : IN STD_LOGIC; vtc_rdy_bsc5 : OUT STD_LOGIC;
        en_vtc_bsc5 : IN STD_LOGIC; vtc_rdy_bsc6 : OUT STD_LOGIC; en_vtc_bsc6 : IN STD_LOGIC;
        vtc_rdy_bsc7 : OUT STD_LOGIC; en_vtc_bsc7 : IN STD_LOGIC;
        dly_rdy_bsc2 : OUT STD_LOGIC; dly_rdy_bsc3 : OUT STD_LOGIC; dly_rdy_bsc4 : OUT STD_LOGIC;
        dly_rdy_bsc5 : OUT STD_LOGIC; dly_rdy_bsc6 : OUT STD_LOGIC; dly_rdy_bsc7 : OUT STD_LOGIC;
        rst_seq_done : OUT STD_LOGIC; shared_pll0_clkoutphy_out : OUT STD_LOGIC; pll0_clkout0 : OUT STD_LOGIC;
        rst : IN STD_LOGIC; clk : IN STD_LOGIC; riu_clk : IN STD_LOGIC; pll0_locked : OUT STD_LOGIC;
        bg1_pin0_nc : IN STD_LOGIC; bg3_pin0_nc : IN STD_LOGIC;
        gbtx_clk80_21 : IN STD_LOGIC; data_to_fabric_gbtx_clk80_21 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin9_22 : IN STD_LOGIC; data_to_fabric_bg1_pin9_22 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        gbtx_clk40_23 : IN STD_LOGIC; data_to_fabric_gbtx_clk40_23 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin11_24 : IN STD_LOGIC; data_to_fabric_bg1_pin11_24 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_fc_28 : IN STD_LOGIC; data_to_fabric_adc_fc_28 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin3_29 : IN STD_LOGIC; data_to_fabric_bg2_pin3_29 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_lg_30 : IN STD_LOGIC; data_to_fabric_adc_lg_30 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin5_31 : IN STD_LOGIC; data_to_fabric_bg2_pin5_31 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_hg_32 : IN STD_LOGIC; data_to_fabric_adc_hg_32 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin7_33 : IN STD_LOGIC; data_to_fabric_bg2_pin7_33 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg3_pin12_51 : IN STD_LOGIC; data_to_fabric_bg3_pin12_51 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
    end component;

    component hss_adc_ch4 is port (
        fifo_rd_data_valid : OUT STD_LOGIC; fifo_rd_clk_21 : IN STD_LOGIC; fifo_rd_clk_22 : IN STD_LOGIC;
        fifo_rd_clk_23 : IN STD_LOGIC; fifo_rd_clk_24 : IN STD_LOGIC;
        fifo_rd_clk_28 : IN STD_LOGIC; fifo_rd_clk_29 : IN STD_LOGIC;
        fifo_rd_clk_30 : IN STD_LOGIC; fifo_rd_clk_31 : IN STD_LOGIC; fifo_rd_clk_32 : IN STD_LOGIC;
        fifo_rd_clk_33 : IN STD_LOGIC; fifo_rd_clk_51 : IN STD_LOGIC;
        fifo_empty_21 : OUT STD_LOGIC; fifo_empty_22 : OUT STD_LOGIC; fifo_empty_23 : OUT STD_LOGIC; fifo_empty_24 : OUT STD_LOGIC;
        fifo_empty_28 : OUT STD_LOGIC;
        fifo_empty_29 : OUT STD_LOGIC; fifo_empty_30 : OUT STD_LOGIC; fifo_empty_31 : OUT STD_LOGIC;
        fifo_empty_32 : OUT STD_LOGIC; fifo_empty_33 : OUT STD_LOGIC; fifo_empty_51 : OUT STD_LOGIC;
        vtc_rdy_bsc2 : OUT STD_LOGIC; en_vtc_bsc2 : IN STD_LOGIC; vtc_rdy_bsc3 : OUT STD_LOGIC; en_vtc_bsc3 : IN STD_LOGIC;
        vtc_rdy_bsc4 : OUT STD_LOGIC; en_vtc_bsc4 : IN STD_LOGIC; vtc_rdy_bsc5 : OUT STD_LOGIC;
        en_vtc_bsc5 : IN STD_LOGIC; vtc_rdy_bsc6 : OUT STD_LOGIC; en_vtc_bsc6 : IN STD_LOGIC;
        vtc_rdy_bsc7 : OUT STD_LOGIC; en_vtc_bsc7 : IN STD_LOGIC;
        dly_rdy_bsc2 : OUT STD_LOGIC; dly_rdy_bsc3 : OUT STD_LOGIC; dly_rdy_bsc4 : OUT STD_LOGIC;
        dly_rdy_bsc5 : OUT STD_LOGIC; dly_rdy_bsc6 : OUT STD_LOGIC; dly_rdy_bsc7 : OUT STD_LOGIC;
        rst_seq_done : OUT STD_LOGIC; shared_pll0_clkoutphy_out : OUT STD_LOGIC; pll0_clkout0 : OUT STD_LOGIC;
        rst : IN STD_LOGIC; clk : IN STD_LOGIC; riu_clk : IN STD_LOGIC; pll0_locked : OUT STD_LOGIC;
        bg1_pin0_nc : IN STD_LOGIC; bg3_pin0_nc : IN STD_LOGIC;
        gbtx_clk80_21 : IN STD_LOGIC; data_to_fabric_gbtx_clk80_21 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin9_22 : IN STD_LOGIC; data_to_fabric_bg1_pin9_22 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        gbtx_clk40_23 : IN STD_LOGIC; data_to_fabric_gbtx_clk40_23 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin11_24 : IN STD_LOGIC; data_to_fabric_bg1_pin11_24 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_fc_28 : IN STD_LOGIC; data_to_fabric_adc_fc_28 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin3_29 : IN STD_LOGIC; data_to_fabric_bg2_pin3_29 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_lg_30 : IN STD_LOGIC; data_to_fabric_adc_lg_30 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin5_31 : IN STD_LOGIC; data_to_fabric_bg2_pin5_31 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_hg_32 : IN STD_LOGIC; data_to_fabric_adc_hg_32 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin7_33 : IN STD_LOGIC; data_to_fabric_bg2_pin7_33 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg3_pin12_51 : IN STD_LOGIC; data_to_fabric_bg3_pin12_51 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
    end component;

    -- channel 5 (bank 44): the original, first-configured IP, kept as plain "hss_adc"
    component hss_adc is port (
        fifo_rd_data_valid : OUT STD_LOGIC; fifo_rd_clk_21 : IN STD_LOGIC; fifo_rd_clk_22 : IN STD_LOGIC;
        fifo_rd_clk_23 : IN STD_LOGIC; fifo_rd_clk_24 : IN STD_LOGIC;
        fifo_rd_clk_28 : IN STD_LOGIC; fifo_rd_clk_29 : IN STD_LOGIC;
        fifo_rd_clk_30 : IN STD_LOGIC; fifo_rd_clk_31 : IN STD_LOGIC; fifo_rd_clk_32 : IN STD_LOGIC;
        fifo_rd_clk_33 : IN STD_LOGIC; fifo_rd_clk_51 : IN STD_LOGIC;
        fifo_empty_21 : OUT STD_LOGIC; fifo_empty_22 : OUT STD_LOGIC; fifo_empty_23 : OUT STD_LOGIC; fifo_empty_24 : OUT STD_LOGIC;
        fifo_empty_28 : OUT STD_LOGIC;
        fifo_empty_29 : OUT STD_LOGIC; fifo_empty_30 : OUT STD_LOGIC; fifo_empty_31 : OUT STD_LOGIC;
        fifo_empty_32 : OUT STD_LOGIC; fifo_empty_33 : OUT STD_LOGIC; fifo_empty_51 : OUT STD_LOGIC;
        vtc_rdy_bsc2 : OUT STD_LOGIC; en_vtc_bsc2 : IN STD_LOGIC; vtc_rdy_bsc3 : OUT STD_LOGIC; en_vtc_bsc3 : IN STD_LOGIC;
        vtc_rdy_bsc4 : OUT STD_LOGIC; en_vtc_bsc4 : IN STD_LOGIC; vtc_rdy_bsc5 : OUT STD_LOGIC;
        en_vtc_bsc5 : IN STD_LOGIC; vtc_rdy_bsc6 : OUT STD_LOGIC; en_vtc_bsc6 : IN STD_LOGIC;
        vtc_rdy_bsc7 : OUT STD_LOGIC; en_vtc_bsc7 : IN STD_LOGIC;
        dly_rdy_bsc2 : OUT STD_LOGIC; dly_rdy_bsc3 : OUT STD_LOGIC; dly_rdy_bsc4 : OUT STD_LOGIC;
        dly_rdy_bsc5 : OUT STD_LOGIC; dly_rdy_bsc6 : OUT STD_LOGIC; dly_rdy_bsc7 : OUT STD_LOGIC;
        rst_seq_done : OUT STD_LOGIC; shared_pll0_clkoutphy_out : OUT STD_LOGIC; pll0_clkout0 : OUT STD_LOGIC;
        rst : IN STD_LOGIC; clk : IN STD_LOGIC; riu_clk : IN STD_LOGIC; pll0_locked : OUT STD_LOGIC;
        bg1_pin0_nc : IN STD_LOGIC; bg3_pin0_nc : IN STD_LOGIC;
        gbtx_clk80_21 : IN STD_LOGIC; data_to_fabric_gbtx_clk80_21 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin9_22 : IN STD_LOGIC; data_to_fabric_bg1_pin9_22 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        gbtx_clk40_23 : IN STD_LOGIC; data_to_fabric_gbtx_clk40_23 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg1_pin11_24 : IN STD_LOGIC; data_to_fabric_bg1_pin11_24 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_fc_28 : IN STD_LOGIC; data_to_fabric_adc_fc_28 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin3_29 : IN STD_LOGIC; data_to_fabric_bg2_pin3_29 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_lg_30 : IN STD_LOGIC; data_to_fabric_adc_lg_30 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin5_31 : IN STD_LOGIC; data_to_fabric_bg2_pin5_31 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        adc_hg_32 : IN STD_LOGIC; data_to_fabric_adc_hg_32 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg2_pin7_33 : IN STD_LOGIC; data_to_fabric_bg2_pin7_33 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        bg3_pin12_51 : IN STD_LOGIC; data_to_fabric_bg3_pin12_51 : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
      );
    end component;

    type t_std_logic_array6 is array(0 to 5) of std_logic;

    signal s_bitclk_se    : t_std_logic_array6;
    signal s_rst          : t_std_logic_array6 := (others => '1');
    signal s_en_vtc       : t_std_logic_array6 := (others => '0');
    signal s_pll0_locked  : t_std_logic_array6;
    signal s_rst_seq_done : t_std_logic_array6;
    signal s_data_valid   : t_std_logic_array6;

    signal s_data_lg, s_data_hg, s_data_fc : t_byteslice_sr := (others => (others => '0'));
    signal s_data_gbtx_clk40, s_data_gbtx_clk80 : t_byteslice_sr := (others => (others => '0'));

begin

  gen_adc_channels : for i in 0 to 5 generate

    i_IBUFGDS_BITCLK : IBUFGDS -- ADC bit clock (280MHz, 560Mbps DDR)
      generic map (
        IOSTANDARD => "LVDS", DIFF_TERM => TRUE)
      port map (
        O  => s_bitclk_se(i),
        I  => p_adc_bitclk_in(i).p,
        IB => p_adc_bitclk_in(i).n
        );

    proc_reset_sync : process(p_clknet_in.cfgbus_clk40, p_master_reset_in)
    begin
        if p_master_reset_in = '1' then
            s_rst(i)    <= '1';
            s_en_vtc(i) <= '0';
        elsif rising_edge(p_clknet_in.cfgbus_clk40) then
            s_rst(i)    <= '0';
            s_en_vtc(i) <= '1';
        end if;
    end process;

      p_adc_bitclk_out(i)         <= s_bitclk_se(i);
      p_adc_bitclkdiv_out(i)      <= p_clknet_in.cfgbus_clk40;
      p_ctrl_reset_from_sm_out(i) <= '0'; -- RX_DELAY_TYPE=FIXED: no idelay resync needed

  end generate;

    i_hss_adc_ch0 : hss_adc_ch0
      port map (
        fifo_rd_data_valid => s_data_valid(0),
        fifo_rd_clk_21 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_22 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_23 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_24 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_28 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_29 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_30 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_31 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_32 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_33 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_51 => p_clknet_in.cfgbus_clk40,
        fifo_empty_21 => open, fifo_empty_22 => open, fifo_empty_23 => open, fifo_empty_24 => open,
        fifo_empty_28 => open, fifo_empty_29 => open, fifo_empty_30 => open, fifo_empty_31 => open,
        fifo_empty_32 => open, fifo_empty_33 => open, fifo_empty_51 => open,
        vtc_rdy_bsc2 => open, en_vtc_bsc2 => s_en_vtc(0), vtc_rdy_bsc3 => open, en_vtc_bsc3 => s_en_vtc(0),
        vtc_rdy_bsc4 => open, en_vtc_bsc4 => s_en_vtc(0), vtc_rdy_bsc5 => open, en_vtc_bsc5 => s_en_vtc(0),
        vtc_rdy_bsc6 => open, en_vtc_bsc6 => s_en_vtc(0), vtc_rdy_bsc7 => open, en_vtc_bsc7 => s_en_vtc(0),
        dly_rdy_bsc2 => open, dly_rdy_bsc3 => open, dly_rdy_bsc4 => open, dly_rdy_bsc5 => open,
        dly_rdy_bsc6 => open, dly_rdy_bsc7 => open,
        rst_seq_done => s_rst_seq_done(0), shared_pll0_clkoutphy_out => open, pll0_clkout0 => open,
        rst => s_rst(0), clk => s_bitclk_se(0), riu_clk => p_clknet_in.cfgbus_clk40, pll0_locked => s_pll0_locked(0),
        bg1_pin0_nc => p_adc_hss_aux2_in(0), bg3_pin0_nc => p_adc_hss_aux0_in(0),
        gbtx_clk80_21 => p_gbtx_clk80_b68_in.p, data_to_fabric_gbtx_clk80_21 => s_data_gbtx_clk80(0)(3 downto 0),
        bg1_pin9_22 => p_gbtx_clk80_b68_in.n, data_to_fabric_bg1_pin9_22 => open,
        gbtx_clk40_23 => p_gbtx_clk40_b68_in.p, data_to_fabric_gbtx_clk40_23 => s_data_gbtx_clk40(0)(3 downto 0),
        bg1_pin11_24 => p_gbtx_clk40_b68_in.n, data_to_fabric_bg1_pin11_24 => open,
        adc_fc_28 => p_adc_frameclk_in(0).p, data_to_fabric_adc_fc_28 => s_data_fc(0)(3 downto 0),
        bg2_pin3_29 => p_adc_frameclk_in(0).n, data_to_fabric_bg2_pin3_29 => open,
        adc_lg_30 => p_adc_lg_data_in(0).p, data_to_fabric_adc_lg_30 => s_data_lg(0)(3 downto 0),
        bg2_pin5_31 => p_adc_lg_data_in(0).n, data_to_fabric_bg2_pin5_31 => open,
        adc_hg_32 => p_adc_hg_data_in(0).p, data_to_fabric_adc_hg_32 => s_data_hg(0)(3 downto 0),
        bg2_pin7_33 => p_adc_hg_data_in(0).n, data_to_fabric_bg2_pin7_33 => open,
        bg3_pin12_51 => p_adc_hss_aux1_in(0), data_to_fabric_bg3_pin12_51 => open
      );

    i_hss_adc_ch1 : hss_adc_ch1
      port map (
        fifo_rd_data_valid => s_data_valid(1),
        fifo_rd_clk_21 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_22 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_23 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_24 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_28 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_29 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_30 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_31 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_32 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_33 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_51 => p_clknet_in.cfgbus_clk40,
        fifo_empty_21 => open, fifo_empty_22 => open, fifo_empty_23 => open, fifo_empty_24 => open,
        fifo_empty_28 => open, fifo_empty_29 => open, fifo_empty_30 => open, fifo_empty_31 => open,
        fifo_empty_32 => open, fifo_empty_33 => open, fifo_empty_51 => open,
        vtc_rdy_bsc2 => open, en_vtc_bsc2 => s_en_vtc(1), vtc_rdy_bsc3 => open, en_vtc_bsc3 => s_en_vtc(1),
        vtc_rdy_bsc4 => open, en_vtc_bsc4 => s_en_vtc(1), vtc_rdy_bsc5 => open, en_vtc_bsc5 => s_en_vtc(1),
        vtc_rdy_bsc6 => open, en_vtc_bsc6 => s_en_vtc(1), vtc_rdy_bsc7 => open, en_vtc_bsc7 => s_en_vtc(1),
        dly_rdy_bsc2 => open, dly_rdy_bsc3 => open, dly_rdy_bsc4 => open, dly_rdy_bsc5 => open,
        dly_rdy_bsc6 => open, dly_rdy_bsc7 => open,
        rst_seq_done => s_rst_seq_done(1), shared_pll0_clkoutphy_out => open, pll0_clkout0 => open,
        rst => s_rst(1), clk => s_bitclk_se(1), riu_clk => p_clknet_in.cfgbus_clk40, pll0_locked => s_pll0_locked(1),
        bg1_pin0_nc => p_adc_hss_aux2_in(1), bg3_pin0_nc => p_adc_hss_aux0_in(1),
        gbtx_clk80_21 => p_gbtx_clk80_b67_in.p, data_to_fabric_gbtx_clk80_21 => s_data_gbtx_clk80(1)(3 downto 0),
        bg1_pin9_22 => p_gbtx_clk80_b67_in.n, data_to_fabric_bg1_pin9_22 => open,
        gbtx_clk40_23 => p_gbtx_clk40_b67_in.p, data_to_fabric_gbtx_clk40_23 => s_data_gbtx_clk40(1)(3 downto 0),
        bg1_pin11_24 => p_gbtx_clk40_b67_in.n, data_to_fabric_bg1_pin11_24 => open,
        adc_fc_28 => p_adc_frameclk_in(1).p, data_to_fabric_adc_fc_28 => s_data_fc(1)(3 downto 0),
        bg2_pin3_29 => p_adc_frameclk_in(1).n, data_to_fabric_bg2_pin3_29 => open,
        adc_lg_30 => p_adc_lg_data_in(1).p, data_to_fabric_adc_lg_30 => s_data_lg(1)(3 downto 0),
        bg2_pin5_31 => p_adc_lg_data_in(1).n, data_to_fabric_bg2_pin5_31 => open,
        adc_hg_32 => p_adc_hg_data_in(1).p, data_to_fabric_adc_hg_32 => s_data_hg(1)(3 downto 0),
        bg2_pin7_33 => p_adc_hg_data_in(1).n, data_to_fabric_bg2_pin7_33 => open,
        bg3_pin12_51 => p_adc_hss_aux1_in(1), data_to_fabric_bg3_pin12_51 => open
      );

    i_hss_adc_ch2 : hss_adc_ch2
      port map (
        fifo_rd_data_valid => s_data_valid(2),
        fifo_rd_clk_21 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_22 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_23 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_24 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_28 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_29 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_30 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_31 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_32 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_33 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_51 => p_clknet_in.cfgbus_clk40,
        fifo_empty_21 => open, fifo_empty_22 => open, fifo_empty_23 => open, fifo_empty_24 => open,
        fifo_empty_28 => open, fifo_empty_29 => open, fifo_empty_30 => open, fifo_empty_31 => open,
        fifo_empty_32 => open, fifo_empty_33 => open, fifo_empty_51 => open,
        vtc_rdy_bsc2 => open, en_vtc_bsc2 => s_en_vtc(2), vtc_rdy_bsc3 => open, en_vtc_bsc3 => s_en_vtc(2),
        vtc_rdy_bsc4 => open, en_vtc_bsc4 => s_en_vtc(2), vtc_rdy_bsc5 => open, en_vtc_bsc5 => s_en_vtc(2),
        vtc_rdy_bsc6 => open, en_vtc_bsc6 => s_en_vtc(2), vtc_rdy_bsc7 => open, en_vtc_bsc7 => s_en_vtc(2),
        dly_rdy_bsc2 => open, dly_rdy_bsc3 => open, dly_rdy_bsc4 => open, dly_rdy_bsc5 => open,
        dly_rdy_bsc6 => open, dly_rdy_bsc7 => open,
        rst_seq_done => s_rst_seq_done(2), shared_pll0_clkoutphy_out => open, pll0_clkout0 => open,
        rst => s_rst(2), clk => s_bitclk_se(2), riu_clk => p_clknet_in.cfgbus_clk40, pll0_locked => s_pll0_locked(2),
        bg1_pin0_nc => p_adc_hss_aux2_in(2), bg3_pin0_nc => p_adc_hss_aux0_in(2),
        gbtx_clk80_21 => p_gbtx_clk80_b66_in.p, data_to_fabric_gbtx_clk80_21 => s_data_gbtx_clk80(2)(3 downto 0),
        bg1_pin9_22 => p_gbtx_clk80_b66_in.n, data_to_fabric_bg1_pin9_22 => open,
        gbtx_clk40_23 => p_gbtx_clk40_b66_in.p, data_to_fabric_gbtx_clk40_23 => s_data_gbtx_clk40(2)(3 downto 0),
        bg1_pin11_24 => p_gbtx_clk40_b66_in.n, data_to_fabric_bg1_pin11_24 => open,
        adc_fc_28 => p_adc_frameclk_in(2).p, data_to_fabric_adc_fc_28 => s_data_fc(2)(3 downto 0),
        bg2_pin3_29 => p_adc_frameclk_in(2).n, data_to_fabric_bg2_pin3_29 => open,
        adc_lg_30 => p_adc_lg_data_in(2).p, data_to_fabric_adc_lg_30 => s_data_lg(2)(3 downto 0),
        bg2_pin5_31 => p_adc_lg_data_in(2).n, data_to_fabric_bg2_pin5_31 => open,
        adc_hg_32 => p_adc_hg_data_in(2).p, data_to_fabric_adc_hg_32 => s_data_hg(2)(3 downto 0),
        bg2_pin7_33 => p_adc_hg_data_in(2).n, data_to_fabric_bg2_pin7_33 => open,
        bg3_pin12_51 => p_adc_hss_aux1_in(2), data_to_fabric_bg3_pin12_51 => open
      );

    i_hss_adc_ch3 : hss_adc_ch3
      port map (
        fifo_rd_data_valid => s_data_valid(3),
        fifo_rd_clk_21 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_22 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_23 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_24 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_28 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_29 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_30 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_31 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_32 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_33 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_51 => p_clknet_in.cfgbus_clk40,
        fifo_empty_21 => open, fifo_empty_22 => open, fifo_empty_23 => open, fifo_empty_24 => open,
        fifo_empty_28 => open, fifo_empty_29 => open, fifo_empty_30 => open, fifo_empty_31 => open,
        fifo_empty_32 => open, fifo_empty_33 => open, fifo_empty_51 => open,
        vtc_rdy_bsc2 => open, en_vtc_bsc2 => s_en_vtc(3), vtc_rdy_bsc3 => open, en_vtc_bsc3 => s_en_vtc(3),
        vtc_rdy_bsc4 => open, en_vtc_bsc4 => s_en_vtc(3), vtc_rdy_bsc5 => open, en_vtc_bsc5 => s_en_vtc(3),
        vtc_rdy_bsc6 => open, en_vtc_bsc6 => s_en_vtc(3), vtc_rdy_bsc7 => open, en_vtc_bsc7 => s_en_vtc(3),
        dly_rdy_bsc2 => open, dly_rdy_bsc3 => open, dly_rdy_bsc4 => open, dly_rdy_bsc5 => open,
        dly_rdy_bsc6 => open, dly_rdy_bsc7 => open,
        rst_seq_done => s_rst_seq_done(3), shared_pll0_clkoutphy_out => open, pll0_clkout0 => open,
        rst => s_rst(3), clk => s_bitclk_se(3), riu_clk => p_clknet_in.cfgbus_clk40, pll0_locked => s_pll0_locked(3),
        bg1_pin0_nc => p_adc_hss_aux2_in(3), bg3_pin0_nc => p_adc_hss_aux0_in(3),
        gbtx_clk80_21 => p_gbtx_clk80_b47_in.p, data_to_fabric_gbtx_clk80_21 => s_data_gbtx_clk80(3)(3 downto 0),
        bg1_pin9_22 => p_gbtx_clk80_b47_in.n, data_to_fabric_bg1_pin9_22 => open,
        gbtx_clk40_23 => p_gbtx_clk40_b47_in.p, data_to_fabric_gbtx_clk40_23 => s_data_gbtx_clk40(3)(3 downto 0),
        bg1_pin11_24 => p_gbtx_clk40_b47_in.n, data_to_fabric_bg1_pin11_24 => open,
        adc_fc_28 => p_adc_frameclk_in(3).p, data_to_fabric_adc_fc_28 => s_data_fc(3)(3 downto 0),
        bg2_pin3_29 => p_adc_frameclk_in(3).n, data_to_fabric_bg2_pin3_29 => open,
        adc_lg_30 => p_adc_lg_data_in(3).p, data_to_fabric_adc_lg_30 => s_data_lg(3)(3 downto 0),
        bg2_pin5_31 => p_adc_lg_data_in(3).n, data_to_fabric_bg2_pin5_31 => open,
        adc_hg_32 => p_adc_hg_data_in(3).p, data_to_fabric_adc_hg_32 => s_data_hg(3)(3 downto 0),
        bg2_pin7_33 => p_adc_hg_data_in(3).n, data_to_fabric_bg2_pin7_33 => open,
        bg3_pin12_51 => p_adc_hss_aux1_in(3), data_to_fabric_bg3_pin12_51 => open
      );

    i_hss_adc_ch4 : hss_adc_ch4
      port map (
        fifo_rd_data_valid => s_data_valid(4),
        fifo_rd_clk_21 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_22 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_23 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_24 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_28 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_29 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_30 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_31 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_32 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_33 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_51 => p_clknet_in.cfgbus_clk40,
        fifo_empty_21 => open, fifo_empty_22 => open, fifo_empty_23 => open, fifo_empty_24 => open,
        fifo_empty_28 => open, fifo_empty_29 => open, fifo_empty_30 => open, fifo_empty_31 => open,
        fifo_empty_32 => open, fifo_empty_33 => open, fifo_empty_51 => open,
        vtc_rdy_bsc2 => open, en_vtc_bsc2 => s_en_vtc(4), vtc_rdy_bsc3 => open, en_vtc_bsc3 => s_en_vtc(4),
        vtc_rdy_bsc4 => open, en_vtc_bsc4 => s_en_vtc(4), vtc_rdy_bsc5 => open, en_vtc_bsc5 => s_en_vtc(4),
        vtc_rdy_bsc6 => open, en_vtc_bsc6 => s_en_vtc(4), vtc_rdy_bsc7 => open, en_vtc_bsc7 => s_en_vtc(4),
        dly_rdy_bsc2 => open, dly_rdy_bsc3 => open, dly_rdy_bsc4 => open, dly_rdy_bsc5 => open,
        dly_rdy_bsc6 => open, dly_rdy_bsc7 => open,
        rst_seq_done => s_rst_seq_done(4), shared_pll0_clkoutphy_out => open, pll0_clkout0 => open,
        rst => s_rst(4), clk => s_bitclk_se(4), riu_clk => p_clknet_in.cfgbus_clk40, pll0_locked => s_pll0_locked(4),
        bg1_pin0_nc => p_adc_hss_aux2_in(4), bg3_pin0_nc => p_adc_hss_aux0_in(4),
        gbtx_clk80_21 => p_gbtx_clk80_b46_in.p, data_to_fabric_gbtx_clk80_21 => s_data_gbtx_clk80(4)(3 downto 0),
        bg1_pin9_22 => p_gbtx_clk80_b46_in.n, data_to_fabric_bg1_pin9_22 => open,
        gbtx_clk40_23 => p_gbtx_clk40_b46_in.p, data_to_fabric_gbtx_clk40_23 => s_data_gbtx_clk40(4)(3 downto 0),
        bg1_pin11_24 => p_gbtx_clk40_b46_in.n, data_to_fabric_bg1_pin11_24 => open,
        adc_fc_28 => p_adc_frameclk_in(4).p, data_to_fabric_adc_fc_28 => s_data_fc(4)(3 downto 0),
        bg2_pin3_29 => p_adc_frameclk_in(4).n, data_to_fabric_bg2_pin3_29 => open,
        adc_lg_30 => p_adc_lg_data_in(4).p, data_to_fabric_adc_lg_30 => s_data_lg(4)(3 downto 0),
        bg2_pin5_31 => p_adc_lg_data_in(4).n, data_to_fabric_bg2_pin5_31 => open,
        adc_hg_32 => p_adc_hg_data_in(4).p, data_to_fabric_adc_hg_32 => s_data_hg(4)(3 downto 0),
        bg2_pin7_33 => p_adc_hg_data_in(4).n, data_to_fabric_bg2_pin7_33 => open,
        bg3_pin12_51 => p_adc_hss_aux1_in(4), data_to_fabric_bg3_pin12_51 => open
      );

    i_hss_adc_ch5 : hss_adc
      port map (
        fifo_rd_data_valid => s_data_valid(5),
        fifo_rd_clk_21 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_22 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_23 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_24 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_28 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_29 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_30 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_31 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_32 => p_clknet_in.cfgbus_clk40, fifo_rd_clk_33 => p_clknet_in.cfgbus_clk40,
        fifo_rd_clk_51 => p_clknet_in.cfgbus_clk40,
        fifo_empty_21 => open, fifo_empty_22 => open, fifo_empty_23 => open, fifo_empty_24 => open,
        fifo_empty_28 => open, fifo_empty_29 => open, fifo_empty_30 => open, fifo_empty_31 => open,
        fifo_empty_32 => open, fifo_empty_33 => open, fifo_empty_51 => open,
        vtc_rdy_bsc2 => open, en_vtc_bsc2 => s_en_vtc(5), vtc_rdy_bsc3 => open, en_vtc_bsc3 => s_en_vtc(5),
        vtc_rdy_bsc4 => open, en_vtc_bsc4 => s_en_vtc(5), vtc_rdy_bsc5 => open, en_vtc_bsc5 => s_en_vtc(5),
        vtc_rdy_bsc6 => open, en_vtc_bsc6 => s_en_vtc(5), vtc_rdy_bsc7 => open, en_vtc_bsc7 => s_en_vtc(5),
        dly_rdy_bsc2 => open, dly_rdy_bsc3 => open, dly_rdy_bsc4 => open, dly_rdy_bsc5 => open,
        dly_rdy_bsc6 => open, dly_rdy_bsc7 => open,
        rst_seq_done => s_rst_seq_done(5), shared_pll0_clkoutphy_out => open, pll0_clkout0 => open,
        rst => s_rst(5), clk => s_bitclk_se(5), riu_clk => p_clknet_in.cfgbus_clk40, pll0_locked => s_pll0_locked(5),
        bg1_pin0_nc => p_adc_hss_aux2_in(5), bg3_pin0_nc => p_adc_hss_aux0_in(5),
        gbtx_clk80_21 => p_gbtx_clk80_b44_in.p, data_to_fabric_gbtx_clk80_21 => s_data_gbtx_clk80(5)(3 downto 0),
        bg1_pin9_22 => p_gbtx_clk80_b44_in.n, data_to_fabric_bg1_pin9_22 => open,
        gbtx_clk40_23 => p_gbtx_clk40_b44_in.p, data_to_fabric_gbtx_clk40_23 => s_data_gbtx_clk40(5)(3 downto 0),
        bg1_pin11_24 => p_gbtx_clk40_b44_in.n, data_to_fabric_bg1_pin11_24 => open,
        adc_fc_28 => p_adc_frameclk_in(5).p, data_to_fabric_adc_fc_28 => s_data_fc(5)(3 downto 0),
        bg2_pin3_29 => p_adc_frameclk_in(5).n, data_to_fabric_bg2_pin3_29 => open,
        adc_lg_30 => p_adc_lg_data_in(5).p, data_to_fabric_adc_lg_30 => s_data_lg(5)(3 downto 0),
        bg2_pin5_31 => p_adc_lg_data_in(5).n, data_to_fabric_bg2_pin5_31 => open,
        adc_hg_32 => p_adc_hg_data_in(5).p, data_to_fabric_adc_hg_32 => s_data_hg(5)(3 downto 0),
        bg2_pin7_33 => p_adc_hg_data_in(5).n, data_to_fabric_bg2_pin7_33 => open,
        bg3_pin12_51 => p_adc_hss_aux1_in(5), data_to_fabric_bg3_pin12_51 => open
      );

  p_adc_lg_data_out  <= s_data_lg;
  p_adc_hg_data_out  <= s_data_hg;
  p_adc_frameclk_out <= s_data_fc;
  p_gbtx_clk40_data_out <= s_data_gbtx_clk40;
  p_gbtx_clk80_data_out <= s_data_gbtx_clk80;

  gen_status_bits : for i in 0 to 5 generate
    p_pll0_locked_out(i)     <= s_pll0_locked(i);
    p_rst_seq_done_out(i)    <= s_rst_seq_done(i);
    p_fifo_data_valid_out(i) <= s_data_valid(i);
  end generate;

  p_leds_out <= (others => '0');

end Behavioral;
