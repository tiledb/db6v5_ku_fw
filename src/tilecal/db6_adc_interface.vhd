--=================================================================================================--
--##################################   module information   #######################################--
--=================================================================================================--
--                                                                                         
-- company:               stockholm university                                                        
-- engineer:              samuel silverstein    silver@fysik.su.se
--                        eduardo valdes santurio
--                                                                                                 
-- project name:          adc deserializer for ltc2264-12                                                                
-- module name:           adc_top                                        
--                                                                                                 
-- language:              vhdl                                                                 
--                                                                                                   --
--
--=================================================================================================--
--#################################################################################################--
--=================================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_adc_interface is
    generic (
            g_tmr_enabled      : std_logic := '0';       -- 0 = no no_tmr, 1 = tmr
            g_adc_clocking_scheme : t_adc_clocking_scheme := iddr280;
            g_bitclk        : integer := 280
        );
    port (
        p_master_reset_in : in std_logic;
        --clock
        p_clknet_in                        : in t_db_clknet;
        p_db_reg_rx_in                     : in t_db_reg_rx;
        --inputs (plain logic; IBUFDS/IBUFGDS now in db6_adc_interface_io_iddr_bitclk280/240.vhd, instantiated from db7_io_box)
        p_adc_bitclk_in : in std_logic_vector(5 downto 0);
        p_adc_bitclkdiv_in : in std_logic_vector(5 downto 0);
        p_frame_missalignment_in : in std_logic_vector(5 downto 0); -- iddr only
        p_adc_frameclk_in : in t_bitslice_sr; -- iddr only
        p_adc_lg_data_in : in t_bitslice_sr;  -- iddr only
        p_adc_hg_data_in : in t_bitslice_sr;  -- iddr only

        -- iserdese only: parallel, wider ports (see db7_io_box.vhd's port list for why),
        -- plus the closed-loop resync pair with db6_adc_interface_io_iserdese
        p_adc_frameclk_iserdese_in   : in  t_byteslice_sr;
        p_adc_lg_data_iserdese_in    : in  t_byteslice_sr;
        p_adc_hg_data_iserdese_in    : in  t_byteslice_sr;
        p_adc_pll0_locked_in         : in  std_logic_vector(5 downto 0) := (others => '0'); -- iserdese/hss only
        p_adc_frame_missalignment_out : out std_logic_vector(5 downto 0);
        p_adc_ctrl_reset_from_sm_in   : in  std_logic_vector(5 downto 0);
        --control
        p_adc_readout_control_in : in t_adc_readout_control;
        --output
        p_adc_readout_out       : out t_adc_readout;
        -- iddr/iddr280_clkdiv, g_bitclk=280 only: db6_adc_idelay_calibration's chosen
        -- IDELAYE3 tap/load/en_vtc, to be threaded up to db7_io_box's IDELAYE3
        -- primitives (see db6_adc_idelay_calibration.vhd's header for why this lives
        -- here, outside any TMR replication, rather than inside the decoder). Only the
        -- fc/lg/hg idelay_count/load/en_vtc fields of this record are meaningful; every
        -- other field is left undriven and must be ignored by whatever consumes this.
        p_adc_idelay_ctrl_out    : out t_adc_readout_control;
        p_leds_out      : out std_logic_vector(3 downto 0)
				);
end db6_adc_interface;

architecture behavioral of db6_adc_interface is

    signal s_adc_gbtx_frameclk : std_logic_vector(5 downto 0);
    signal s_adc_bitclk_locked : std_logic_vector(5 downto 0); -- never driven (io wrapper's locked output was already unconnected pre-refactor)

    signal s_adc_readout : t_adc_readout;
    signal s_adc_readout_tmr : t_adc_readout_tmr;

    signal s_lg_idelay_count, s_hg_idelay_count, s_fc_idelay_count : t_idelay_count;

    -- 2026-09-12: db6_adc_idelay_calibration relocated here from
    -- db6_mainboard_interface.vhd (see that entity's header) -- single shared instance,
    -- outside gen_tmr_disabled/gen_tmr_enabled, driving p_adc_idelay_ctrl_out above and
    -- the new p_calibration_tap_in/done_in/failed_in inputs on every TMR copy of
    -- db6_adc_interface_decoder_iddr_bitclk280 identically.
    signal s_adc_idelay_fc_count, s_adc_idelay_lg_count, s_adc_idelay_hg_count, s_adc_idelay_calibration_tap : t_idelay_count;
    signal s_adc_idelay_fc_load, s_adc_idelay_lg_load, s_adc_idelay_hg_load : std_logic_vector(5 downto 0);
    signal s_adc_idelay_fc_en_vtc, s_adc_idelay_lg_en_vtc, s_adc_idelay_hg_en_vtc : std_logic_vector(5 downto 0);
    signal s_adc_idelay_calibration_done, s_adc_idelay_calibration_failed : std_logic_vector(5 downto 0);
    -- calibration's channel_locked feedback: tmr copy 0 when tripled, to avoid fan-in
    -- from all three onto one signal (same reasoning as the iserdese frame_missalignment
    -- feedback further below in this file).
    signal s_adc_channel_locked_for_calibration : std_logic_vector(5 downto 0);

    -- iserdese + tmr only: each tmr copy's own frame_missalignment_out, tmr copy 0 feeds
    -- the shared io feedback (see gen_db6_adc_interface_iserdese below)
    type t_frame_missalignment_tmr is array (0 to 2) of std_logic_vector(5 downto 0);
    signal s_adc_frame_missalignment_tmr : t_frame_missalignment_tmr;

begin

p_adc_readout_out.channel_clk280_locked<=s_adc_bitclk_locked;

-- IO primitives (IBUFDS/IBUFGDS/IDELAYE3/IDDRE1) for both bitclk variants moved to
-- db6_adc_interface_io_iddr_bitclk280.vhd / _bitclk240.vhd, instantiated from db7_io_box.
-- This entity now takes their plain-logic outputs directly as its own inputs.

-- ADC readout front end select: iddr (this branch, unchanged) or hss (below), by
-- g_adc_clocking_scheme. Only one is ever elaborated.
gen_db6_adc_interface_iddr : if g_adc_clocking_scheme /= hss_wizard generate

p_adc_frame_missalignment_out <= (others => '0');

gen_calibration_locked_tmr_disabled : if g_tmr_enabled = '0' generate
    s_adc_channel_locked_for_calibration <= s_adc_readout.channel_locked;
end generate;
gen_calibration_locked_tmr_enabled : if g_tmr_enabled = '1' generate
    s_adc_channel_locked_for_calibration <= s_adc_readout_tmr(0).channel_locked;
end generate;

gen_idelay_calibration_bitclk280 : if g_bitclk = 280 generate
    i_db6_adc_idelay_calibration : entity tilecal.db6_adc_idelay_calibration
        port map (
            p_master_reset_in   => p_master_reset_in,
            p_clknet_in         => p_clknet_in,
            p_adc_bitclk_in     => p_adc_bitclk_in,
            p_start_in          => p_adc_readout_control_in.adc_config_done,
            p_channel_locked_in => s_adc_channel_locked_for_calibration,
            p_fc_idelay_count_out  => s_adc_idelay_fc_count,
            p_fc_idelay_load_out   => s_adc_idelay_fc_load,
            p_fc_idelay_en_vtc_out => s_adc_idelay_fc_en_vtc,
            p_lg_idelay_count_out  => s_adc_idelay_lg_count,
            p_lg_idelay_load_out   => s_adc_idelay_lg_load,
            p_lg_idelay_en_vtc_out => s_adc_idelay_lg_en_vtc,
            p_hg_idelay_count_out  => s_adc_idelay_hg_count,
            p_hg_idelay_load_out   => s_adc_idelay_hg_load,
            p_hg_idelay_en_vtc_out => s_adc_idelay_hg_en_vtc,
            p_calibration_done_out   => s_adc_idelay_calibration_done,
            p_calibration_failed_out => s_adc_idelay_calibration_failed,
            p_calibration_tap_out    => s_adc_idelay_calibration_tap
        );

    p_adc_idelay_ctrl_out.fc_idelay_count  <= s_adc_idelay_fc_count;
    p_adc_idelay_ctrl_out.fc_idelay_load   <= s_adc_idelay_fc_load;
    p_adc_idelay_ctrl_out.fc_idelay_en_vtc <= s_adc_idelay_fc_en_vtc;
    p_adc_idelay_ctrl_out.lg_idelay_count  <= s_adc_idelay_lg_count;
    p_adc_idelay_ctrl_out.lg_idelay_load   <= s_adc_idelay_lg_load;
    p_adc_idelay_ctrl_out.lg_idelay_en_vtc <= s_adc_idelay_lg_en_vtc;
    p_adc_idelay_ctrl_out.hg_idelay_count  <= s_adc_idelay_hg_count;
    p_adc_idelay_ctrl_out.hg_idelay_load   <= s_adc_idelay_hg_load;
    p_adc_idelay_ctrl_out.hg_idelay_en_vtc <= s_adc_idelay_hg_en_vtc;
end generate;

gen_tmr_disabled: if g_tmr_enabled = '0' generate
    p_adc_readout_out<=s_adc_readout;
    g_bitclk240 : if g_bitclk = 240 generate
        i_db6_adc_interface_decoder_iddr : entity tilecal.db6_adc_interface_decoder_iddr_bitclk240
            generic map(
                g_adc_clocking_scheme =>  g_adc_clocking_scheme,
                g_tmr_enabled => g_tmr_enabled
                )
            port map (
                p_master_reset_in   => p_master_reset_in,
                --clock
                p_clknet_in         => p_clknet_in,
                p_db_reg_rx_in      => p_db_reg_rx_in,
                --inputs
                p_adc_bitclk_in     => p_adc_bitclk_in,
                p_adc_bitclkdiv_in    => p_adc_bitclkdiv_in,
                p_frame_missalignment_in => p_frame_missalignment_in,
                p_adc_frameclk_in   => p_adc_frameclk_in,
                p_adc_lg_data_in    => p_adc_lg_data_in,
                p_adc_hg_data_in    => p_adc_hg_data_in,


                --control
                p_adc_readout_control_in => p_adc_readout_control_in,

                --output
                p_adc_readout_out   => s_adc_readout,

                --debug
                p_leds_out          => open
                        );
    end generate;

    g_bitclk280 : if g_bitclk = 280 generate
        i_db6_adc_interface_decoder_iddr : entity tilecal.db6_adc_interface_decoder_iddr_bitclk280
            generic map(
                g_tmr_enabled => g_tmr_enabled,
                g_adc_clocking_scheme => g_adc_clocking_scheme
                )
            port map ( 	
                p_master_reset_in   => p_master_reset_in,
                --clock
                p_clknet_in         => p_clknet_in,
                p_db_reg_rx_in      => p_db_reg_rx_in,
                --inputs
                p_adc_bitclk_in     => p_adc_bitclk_in,
                p_adc_bitclkdiv_in    => p_adc_bitclkdiv_in,
                p_adc_frameclk_in   => p_adc_frameclk_in,
                p_adc_lg_data_in    => p_adc_lg_data_in,
                p_adc_hg_data_in    => p_adc_hg_data_in,
                p_adc_pll0_locked_in => p_adc_pll0_locked_in,
                p_calibration_tap_in    => s_adc_idelay_calibration_tap,
                p_calibration_done_in   => s_adc_idelay_calibration_done,
                p_calibration_failed_in => s_adc_idelay_calibration_failed,

                --control
                p_adc_readout_control_in => p_adc_readout_control_in,

                --output
                p_adc_readout_out   => s_adc_readout,

                --debug
                p_leds_out          => open
                        );
    end generate;

end generate;

gen_tmr_enabled: if g_tmr_enabled = '1' generate
    p_adc_readout_out<=s_adc_readout;
    
    gen_tmr : for v_tmr in 0 to 2 generate
        g_bitclk240 : if g_bitclk = 240 generate
            i_db6_adc_interface_decoder_iddr : entity tilecal.db6_adc_interface_decoder_iddr_bitclk240
                generic map(
                    g_adc_clocking_scheme => g_adc_clocking_scheme,
                    g_tmr_enabled => g_tmr_enabled
                    )
                port map ( 	
                    p_master_reset_in   => '0',
                    --clock
                    p_clknet_in         => p_clknet_in,
                    p_db_reg_rx_in      => p_db_reg_rx_in,
                    --inputs
                    p_adc_bitclk_in     => p_adc_bitclk_in,
                    p_adc_bitclkdiv_in  => p_adc_bitclkdiv_in,
                    p_adc_frameclk_in   => p_adc_frameclk_in,
                    p_frame_missalignment_in => p_frame_missalignment_in,
                    p_adc_lg_data_in    => p_adc_lg_data_in,
                    p_adc_hg_data_in    => p_adc_hg_data_in,
                    
                    
                    --control
                    p_adc_readout_control_in => p_adc_readout_control_in,
                    
                    --output
                    p_adc_readout_out   => s_adc_readout_tmr(v_tmr),
                    
                    --debug
                    p_leds_out          => open
                            );
        end generate;
        g_bitclk280 : if g_bitclk = 280 generate
            i_db6_adc_interface_decoder_iddr : entity tilecal.db6_adc_interface_decoder_iddr_bitclk280
                generic map(
                    g_tmr_enabled => g_tmr_enabled,
                    g_adc_clocking_scheme => g_adc_clocking_scheme
                    )
                port map ( 	
                    p_master_reset_in   => '0',
                    --clock
                    p_clknet_in         => p_clknet_in,
                    p_db_reg_rx_in      => p_db_reg_rx_in,
                    --inputs
                    p_adc_bitclk_in     => p_adc_bitclk_in,
                    p_adc_bitclkdiv_in  => p_adc_bitclkdiv_in,
                    p_adc_frameclk_in   => p_adc_frameclk_in,
                    p_adc_lg_data_in    => p_adc_lg_data_in,
                    p_adc_hg_data_in    => p_adc_hg_data_in,
                    p_adc_pll0_locked_in => p_adc_pll0_locked_in,
                    p_calibration_tap_in    => s_adc_idelay_calibration_tap,
                    p_calibration_done_in   => s_adc_idelay_calibration_done,
                    p_calibration_failed_in => s_adc_idelay_calibration_failed,

                    --control
                    p_adc_readout_control_in => p_adc_readout_control_in,

                    --output
                    p_adc_readout_out   => s_adc_readout_tmr(v_tmr),

                    --debug
                    p_leds_out          => open
                            );
        end generate;
    end generate;
    gen_adc_channel_voters: for v_adc in 0 to 5 generate

        i_entity_db6_tmr_voter_lg_data : entity tilecal.db6_tmr_voter --tilecal.db6_tmr_voter_sync_cdc
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).lg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).lg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).lg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_lg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.lg_data(v_adc)   
                );

        i_entity_db6_tmr_voter_hg_data : entity tilecal.db6_tmr_voter --tilecal.db6_tmr_voter_sync_cdc
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).hg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).hg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).hg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_hg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.hg_data(v_adc)   
                );

        i_entity_db6_tmr_voter_fc_data : entity tilecal.db6_tmr_voter --tilecal.db6_tmr_voter_sync_cdc
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).fc_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).fc_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).fc_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_fc(v_adc),
                p_std_logic_vector_out         => s_adc_readout.fc_data(v_adc)   
                );
        
        s_adc_readout.tmr_error(v_adc)<= s_adc_readout.tmr_error_lg(v_adc) or s_adc_readout.tmr_error_hg(v_adc) or s_adc_readout.tmr_error_fc(v_adc);

    end generate;
end generate;

end generate; -- gen_db6_adc_interface_iddr

-- SelectIO Interface Wizard front end (hss_adc, registered on the divided clkdiv --
-- see db6_adc_interface_io_hss.vhd -- instead of IDDRE1's raw undivided-bitclk output,
-- which needed an SRL pipeline stage tight enough to violate timing at 280 Mbps).
gen_db6_adc_interface_iserdese : if g_adc_clocking_scheme = hss_wizard generate

gen_tmr_disabled: if g_tmr_enabled = '0' generate
    p_adc_readout_out<=s_adc_readout;
    i_db6_adc_interface_decoder_iserdese : entity tilecal.db6_adc_interface_decoder_iserdese
            generic map(
                g_tmr_enabled => g_tmr_enabled
                )
        port map (
            p_master_reset_in   => p_master_reset_in,
            --clock
            p_clknet_in         => p_clknet_in,
            p_db_reg_rx_in      => p_db_reg_rx_in,
            --inputs
            p_adc_bitclk_in     => p_adc_bitclk_in,
            p_adc_bitclkdiv_in    => p_adc_bitclkdiv_in,
            p_frame_missalignment_out => p_adc_frame_missalignment_out,
            p_ctrl_reset_from_sm_in => p_adc_ctrl_reset_from_sm_in,
            p_adc_frameclk_in   => p_adc_frameclk_iserdese_in,
            p_adc_lg_data_in    => p_adc_lg_data_iserdese_in,
            p_adc_hg_data_in    => p_adc_hg_data_iserdese_in,
            p_adc_pll0_locked_in => p_adc_pll0_locked_in,

            --control
            p_adc_readout_control_in => p_adc_readout_control_in,

            --output
            p_adc_readout_out   => s_adc_readout,

            --debug
            p_leds_out          => open
                    );

end generate;

gen_tmr_enabled: if g_tmr_enabled = '1' generate
    p_adc_readout_out<=s_adc_readout;

    gen_tmr : for v_tmr in 0 to 2 generate
        i_db6_adc_interface_decoder_iserdese : entity tilecal.db6_adc_interface_decoder_iserdese
            generic map(
                g_tmr_enabled => g_tmr_enabled
                )
            port map (
                p_master_reset_in   => '0',
                --clock
                p_clknet_in         => p_clknet_in,
                p_db_reg_rx_in      => p_db_reg_rx_in,
                --inputs
                p_adc_bitclk_in     => p_adc_bitclk_in,
                p_adc_bitclkdiv_in  => p_adc_bitclkdiv_in,
                -- all three copies see the same inputs and run the same state machine,
                -- so they agree; only tmr copy 0's is used for the shared io feedback,
                -- avoiding fan-in from all three onto one signal.
                p_frame_missalignment_out => s_adc_frame_missalignment_tmr(v_tmr),
                p_ctrl_reset_from_sm_in => p_adc_ctrl_reset_from_sm_in,
                p_adc_frameclk_in   => p_adc_frameclk_iserdese_in,
                p_adc_lg_data_in    => p_adc_lg_data_iserdese_in,
                p_adc_hg_data_in    => p_adc_hg_data_iserdese_in,

                --control
                p_adc_readout_control_in => p_adc_readout_control_in,

                --output
                p_adc_readout_out   => s_adc_readout_tmr(v_tmr),

                --debug
                p_leds_out          => open
                        );
    end generate;

    p_adc_frame_missalignment_out <= s_adc_frame_missalignment_tmr(0);

    gen_adc_channel_voters: for v_adc in 0 to 5 generate

        i_entity_db6_tmr_voter_lg_data : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).lg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).lg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).lg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_lg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.lg_data(v_adc)
                );

        i_entity_db6_tmr_voter_hg_data : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).hg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).hg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).hg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_hg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.hg_data(v_adc)
                );

        i_entity_db6_tmr_voter_fc_data : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).fc_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).fc_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).fc_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_fc(v_adc),
                p_std_logic_vector_out         => s_adc_readout.fc_data(v_adc)
                );

        s_adc_readout.tmr_error(v_adc)<= s_adc_readout.tmr_error_lg(v_adc) or s_adc_readout.tmr_error_hg(v_adc) or s_adc_readout.tmr_error_fc(v_adc);

    end generate;
end generate;

end generate; -- gen_db6_adc_interface_iserdese

end behavioral;