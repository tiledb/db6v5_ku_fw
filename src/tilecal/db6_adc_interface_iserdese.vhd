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

entity db6_adc_interface_iserdese is
    generic (
            g_tmr_enabled      : std_logic := '0';       -- 0 = no no_tmr, 1 = tmr
            g_clocking_mode : integer := 0---- 0-> simple, 1-> divclkout, 2-> pll with clk40_ou
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
        --control
        p_adc_readout_control_in : in t_adc_readout_control;
--        p_adc_readout_control_out : out t_adc_readout_control;
        --output
        p_adc_readout_out       : out t_adc_readout;
        p_leds_out      : out std_logic_vector(3 downto 0)
				);	
end db6_adc_interface_iserdese;

architecture behavioral of db6_adc_interface_iserdese is

    signal s_adc_bitclk : std_logic_vector(5 downto 0);
    signal s_adc_bitclkdiv : std_logic_vector(5 downto 0);
    signal s_frame_missalignment : std_logic_vector(5 downto 0);
    signal s_adc_bitclk_locked : std_logic_vector(5 downto 0);
    signal s_ctrl_reset_from_sm : std_logic_vector(5 downto 0);
    signal s_adc_frameclk : t_byteslice_sr;
    signal s_adc_lg_data : t_byteslice_sr;
    signal s_adc_hg_data : t_byteslice_sr;
    
    signal s_adc_readout : t_adc_readout;
    signal s_adc_readout_tmr : t_adc_readout_tmr;

    signal s_lg_idelay_count, s_hg_idelay_count, s_fc_idelay_count : t_idelay_count;
--    signal s_adc_readout_control_out : t_adc_readout_control;
--    attribute keep_hierarchy : string;
--    attribute dont_touch : string;
--    attribute keep : string;
--    attribute dont_touch of s_adc_readout, s_adc_readout_tmr, s_adc_frameclk, s_adc_bitclk, s_adc_lg_data, s_adc_hg_data : signal is "true";
--    attribute keep of s_adc_readout, s_adc_readout_tmr, s_adc_frameclk, s_adc_bitclk, s_adc_lg_data, s_adc_hg_data : signal is "true";

--    attribute loc : string;
--    attribute loc of i_db6_adc_interface_decoder_iddr : label is "slice_*";
--    attribute loc of MOD1 : label is "slice_*";
--    attribute loc of MOD2 : label is "slice_*";

begin

--p_adc_readout_control_out <= s_adc_readout_control_out;
p_adc_readout_out.channel_clk280_locked<=s_adc_bitclk_locked;
i_db6_adc_interface_io_iserdese : entity tilecal.db6_adc_interface_io_iserdese
    port map ( 	
        p_master_reset_in   => p_master_reset_in,
        --clock
        p_clknet_in         => p_clknet_in,
        p_db_reg_rx_in      => p_db_reg_rx_in,
        --inputs
        p_adc_bitclk_in     => p_adc_bitclk_in,
        
        p_adc_frameclk_in   => p_adc_frameclk_in,
        p_adc_lg_data_in    => p_adc_lg_data_in,
        p_adc_hg_data_in    => p_adc_hg_data_in,
        
        --outputs
        p_adc_bitclk_out    => s_adc_bitclk,
        p_adc_bitclkdiv_out    => s_adc_bitclkdiv,
        p_frame_missalignment_in => s_frame_missalignment,
        p_ctrl_reset_from_sm_out => s_ctrl_reset_from_sm,
--        p_adc_bitclk_locked_out => s_adc_bitclk_locked,
        p_adc_frameclk_out  => s_adc_frameclk,
        p_adc_lg_data_out   => s_adc_lg_data,
        p_adc_hg_data_out   => s_adc_hg_data,
        
--        p_adc_readout_control_out => s_adc_readout_control_out,
--        p_lg_idelay_count_out   => s_lg_idelay_count,
--        p_hg_idelay_count_out   => s_hg_idelay_count,
--        p_fc_idelay_count_out   => s_fc_idelay_count,
        --control
        p_adc_readout_control_in => p_adc_readout_control_in,
        
        --debug
        p_leds_out          => open
		);


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
            p_adc_bitclk_in     => s_adc_bitclk,
            p_adc_bitclkdiv_in    => s_adc_bitclkdiv,
            p_frame_missalignment_out => s_frame_missalignment,
            p_ctrl_reset_from_sm_in => s_ctrl_reset_from_sm,
            p_adc_frameclk_in   => s_adc_frameclk,
            p_adc_lg_data_in    => s_adc_lg_data,
            p_adc_hg_data_in    => s_adc_hg_data,
            
            
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
                p_adc_bitclk_in     => s_adc_bitclk,
                p_adc_bitclkdiv_in  => s_adc_bitclkdiv,
                p_adc_frameclk_in   => s_adc_frameclk,
                p_frame_missalignment_out => s_frame_missalignment,
                p_ctrl_reset_from_sm_in => s_ctrl_reset_from_sm,
                p_adc_lg_data_in    => s_adc_lg_data,
                p_adc_hg_data_in    => s_adc_hg_data,
                
                
                --control
                p_adc_readout_control_in => p_adc_readout_control_in,
                
                --output
                p_adc_readout_out   => s_adc_readout_tmr(v_tmr),
                
                --debug
                p_leds_out          => open
                        );
    end generate;
    gen_adc_channel_voters: for v_adc in 0 to 5 generate

        i_entity_db6_tmr_voter_lg_data : entity tilecal.db6_tmr_voter_sync
        generic map(
            g_vector_width      => 14
        )
        Port map (
                p_clk_in                       => p_clknet_in.cfgbus_clk40,     
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).lg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).lg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).lg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_lg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.lg_data(v_adc)   
                );

        i_entity_db6_tmr_voter_hg_data : entity tilecal.db6_tmr_voter_sync
        generic map(
            g_vector_width      => 14
        )
        Port map (     
                p_clk_in                       => p_clknet_in.cfgbus_clk40,
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).hg_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).hg_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).hg_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_hg(v_adc),
                p_std_logic_vector_out         => s_adc_readout.hg_data(v_adc)   
                );

        i_entity_db6_tmr_voter_fc_data : entity tilecal.db6_tmr_voter_sync
        generic map(
            g_vector_width      => 14
        )
        Port map (     
                p_clk_in                       => p_clknet_in.cfgbus_clk40,
                p_std_logic_vector_0_in        => (s_adc_readout_tmr(0).fc_data(v_adc)),
                p_std_logic_vector_1_in        => (s_adc_readout_tmr(1).fc_data(v_adc)),
                p_std_logic_vector_2_in        => (s_adc_readout_tmr(2).fc_data(v_adc)),
                p_tmr_error_out                => s_adc_readout.tmr_error_fc(v_adc),
                p_std_logic_vector_out         => s_adc_readout.fc_data(v_adc)   
                );
        
        s_adc_readout.tmr_error(v_adc)<= s_adc_readout.tmr_error_lg(v_adc) or s_adc_readout.tmr_error_hg(v_adc) or s_adc_readout.tmr_error_fc(v_adc);
        
    end generate;
end generate;

end behavioral;