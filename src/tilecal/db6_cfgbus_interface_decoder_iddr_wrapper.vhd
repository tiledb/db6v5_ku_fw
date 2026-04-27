----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.10.2022 03:04:14
-- Design Name: 
-- Module Name: db6_cfgbus_interface_decoder_iddr_wrapper - Behavioral
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

library tilecal;
use tilecal.db6_design_package.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity db6_cfgbus_interface_decoder_iddr_wrapper is
    generic (
        g_tmr_enabled      : natural := 0;        -- 0 = no_tmr, 1 = tmr
        g_ila_sync_enabled      : natural := 0;        -- 0 = no_ila_sync, 1 = enable ila
        g_vio_configbus_registers : natural := 0        -- 0 = no vio, 1 enable vio
    );
    Port (     
               p_master_reset_in        : in    std_logic;
               p_iddr_clk_in            : in    std_logic;
               p_clknet_in              : in    t_db_clknet;  
               p_cfgbus_bitslice_in  : in t_cfgbus_bitslice;
               
               p_db_reg_rx_out      : out t_db_reg_rx;
               p_bcr_out    : out t_bcr;
               p_reg_rx_strobe_out  : out std_logic_vector(31 downto 0);--integer range 0 to 15;
               
               p_tmr_enabled_out : out std_logic;
               p_tmr_error_out : out std_logic_vector(c_number_of_cfgbus_regs-1 downto 0);
               
               p_leds_out : out std_logic_vector(3 downto 0)
    );
end db6_cfgbus_interface_decoder_iddr_wrapper;

architecture Behavioral of db6_cfgbus_interface_decoder_iddr_wrapper is

signal s_db_reg_rx : t_db_reg_rx := c_db_reg_rx;
signal s_bcr : t_bcr;
signal s_reg_rx_strobe  : std_logic_vector(31 downto 0);--: integer range 0 to 15;
--signal s_reg_rx_strobe_buffer : std_logic_vector(3 downto 0);

--tmr signals
signal s_db_reg_rx_tmr : t_db_reg_rx_tmr := (others=>c_db_reg_rx);
signal s_bcr_tmr : t_bcr_tmr;
type t_reg_rx_strobe_tmr is array (0 to 2) of std_logic_vector(31 downto 0); --integer range 0 to 15;
signal s_reg_rx_strobe_tmr : t_reg_rx_strobe_tmr;




--debug

    COMPONENT vio_configbus_registers_debug
    PORT (
        clk : IN STD_LOGIC;
        probe_in0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in1 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in5 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in6 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in7 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in8 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in9 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in10 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in11 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in12 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in13 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in14 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in15 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe_in16 : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT;

begin

gen_tmr_disabled : if g_tmr_enabled = 0 generate
    
--    proc_cdc : process(p_clknet_in.cfgbus_clk40)
--    begin
        
--        if rising_edge(p_clknet_in.cfgbus_clk40) then--(p_clknet_in.refclk40) then
            p_db_reg_rx_out<=s_db_reg_rx;
            p_bcr_out<=s_bcr;
            p_tmr_enabled_out <= '0';
            p_reg_rx_strobe_out <= s_reg_rx_strobe;
--        end if;
--    end process;
    
    i_db6_cfgbus_interface_decoder_iddr : entity tilecal.db6_cfgbus_interface_decoder_iddr
        generic map(
            g_tmr_enabled      => g_tmr_enabled,        -- 0 = no no_tmr, 1 = tmr
            g_ila_sync_enabled => g_ila_sync_enabled,
            g_vio_configbus_registers => 0
        )
        Port map (     
                   p_master_reset_in        => p_master_reset_in,
                   p_clknet_in              => p_clknet_in,
                   p_iddr_clk_in            => p_iddr_clk_in,
                   p_cfgbus_bitslice_in     => p_cfgbus_bitslice_in,
                   
                   p_db_reg_rx_out          => s_db_reg_rx,
                   p_bcr_out                => s_bcr,
                   p_reg_rx_strobe_out      => s_reg_rx_strobe,
                   
                   
                   p_leds_out               => open
        );

end generate;
    
gen_tmr_enabled: if g_tmr_enabled = 1 generate
    
    p_db_reg_rx_out<=s_db_reg_rx;
    p_bcr_out<=s_bcr;
    p_tmr_enabled_out <= '1';
    p_reg_rx_strobe_out <= s_reg_rx_strobe;
    gen_tmr_voter: for v_reg in 0 to c_number_of_cfgbus_regs-1 generate 
--        s_db_reg_rx(v_reg)<=(s_db_reg_rx_tmr(0)(v_reg) and s_db_reg_rx_tmr(1)(v_reg)) or (s_db_reg_rx_tmr(1)(v_reg) and s_db_reg_rx_tmr(2)(v_reg)) or (s_db_reg_rx_tmr(2)(v_reg) and s_db_reg_rx_tmr(0)(v_reg));
    i_entity_db6_tmr_voter_db_reg_rx : entity tilecal.db6_tmr_voter --_sync_cdc
        generic map(
            g_vector_width      => 32
        )
        Port map (
--                p_clk_in                       => p_clknet_in.mmcm_refclk240,
--                p_cdc_in                       => p_clknet_in.gbt_cdc_counter,
--                p_cdc_phase_in                 => p_clknet_in.gbt_cdc_phase,
                p_std_logic_vector_0_in        => (s_db_reg_rx_tmr(0)(v_reg)),
                p_std_logic_vector_1_in        => (s_db_reg_rx_tmr(1)(v_reg)),
                p_std_logic_vector_2_in        => (s_db_reg_rx_tmr(2)(v_reg)),
                p_tmr_error_out                => p_tmr_error_out(v_reg),
                p_std_logic_vector_out         => s_db_reg_rx(v_reg)   
                );
    end generate;
    
    i_entity_db6_tmr_voter_bcr : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 1
        )
        Port map (
                --p_clk_in                          => p_clknet_in.cfgbus_clk40,
                p_std_logic_vector_0_in(0)        => s_bcr_tmr(0).bcr,
                p_std_logic_vector_1_in(0)        => s_bcr_tmr(1).bcr,
                p_std_logic_vector_2_in(0)        => s_bcr_tmr(2).bcr,
                p_tmr_error_out                   => s_bcr.bcr_tmr_error,
                p_std_logic_vector_out(0)         => s_bcr.bcr 
                );

    i_entity_db6_tmr_voter_bcr_locked : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 1
        )
        Port map (
                --p_clk_in                          => p_clknet_in.cfgbus_clk40,
                p_std_logic_vector_0_in(0)        => s_bcr_tmr(0).bcr_locked,
                p_std_logic_vector_1_in(0)        => s_bcr_tmr(1).bcr_locked,
                p_std_logic_vector_2_in(0)        => s_bcr_tmr(2).bcr_locked,
                p_tmr_error_out                   => s_bcr.bcr_locked_tmr_error,
                p_std_logic_vector_out(0)         => s_bcr.bcr_locked 
                );
    i_entity_db6_tmr_voter_bcr_count : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 32
        )
        Port map (
                --p_clk_in                       => p_clknet_in.cfgbus_clk40,
                p_std_logic_vector_0_in        => s_bcr_tmr(0).count,
                p_std_logic_vector_1_in        => s_bcr_tmr(1).count,
                p_std_logic_vector_2_in        => s_bcr_tmr(2).count,
                p_tmr_error_out                => s_bcr.count_tmr_error,
                p_std_logic_vector_out      => s_bcr.count 
                );

    
    i_entity_db6_tmr_voter_reg_rx_strobe_buffer : entity tilecal.db6_tmr_voter
        generic map(
            g_vector_width      => 32
        )
        Port map (
                --p_clk_in                       => p_clknet_in.cfgbus_clk40,
                p_std_logic_vector_0_in        => s_reg_rx_strobe_tmr(0),
                p_std_logic_vector_1_in        => s_reg_rx_strobe_tmr(1),
                p_std_logic_vector_2_in        => s_reg_rx_strobe_tmr(2),
                p_tmr_error_out                => open,
                p_std_logic_vector_out      => s_reg_rx_strobe 
                );



--    s_bcr.bcr<=(s_bcr_tmr(0).bcr and s_bcr_tmr(1).bcr) or (s_bcr_tmr(1).bcr and s_bcr_tmr(2).bcr) or (s_bcr_tmr(2).bcr and s_bcr_tmr(0).bcr); 
--    s_bcr.bcr_locked<=(s_bcr_tmr(0).bcr_locked and s_bcr_tmr(1).bcr_locked) or (s_bcr_tmr(1).bcr_locked and s_bcr_tmr(2).bcr_locked) or (s_bcr_tmr(2).bcr_locked and s_bcr_tmr(0).bcr_locked);
--    s_bcr.count<=(s_bcr_tmr(0).count and s_bcr_tmr(1).count) or (s_bcr_tmr(1).count and s_bcr_tmr(2).count) or (s_bcr_tmr(2).count and s_bcr_tmr(0).count);
    
    gen_tmr: for v_tmr in 0 to 2 generate
        i_db6_cfgbus_interface_decoder_iddr : entity tilecal.db6_cfgbus_interface_decoder_iddr
            generic map(
                g_tmr_enabled      => 0,        -- 0 = no no_tmr, 1 = tmr
                g_ila_sync_enabled => 0,
                g_vio_configbus_registers => 0
            )
            Port map (     
                       p_master_reset_in        => p_master_reset_in,
                       p_clknet_in              => p_clknet_in,
                       p_iddr_clk_in            => p_iddr_clk_in,
                       p_cfgbus_bitslice_in     => p_cfgbus_bitslice_in,
                       
                       p_db_reg_rx_out          => s_db_reg_rx_tmr(v_tmr),
                       p_bcr_out                => s_bcr_tmr(v_tmr),
                       p_reg_rx_strobe_out      => s_reg_rx_strobe_tmr(v_tmr),
                       
                       p_leds_out               => open
            );
    end generate;
    
end generate;
    
    
gen_vio_configbus_registers : if g_vio_configbus_registers = 1 generate
    i_vio_configbus_registers : vio_configbus_registers_debug
      PORT MAP (
        clk => p_clknet_in.osc_clk40,
        probe_in0 => s_db_reg_rx(0),
        probe_in1 => s_db_reg_rx(1),
        probe_in2 => s_db_reg_rx(2),
        probe_in3 => s_db_reg_rx(3),
        probe_in4 => s_db_reg_rx(4),
        probe_in5 => s_db_reg_rx(5),
        probe_in6 => s_db_reg_rx(6),
        probe_in7 => s_db_reg_rx(7),
        probe_in8 => s_db_reg_rx(8),
        probe_in9 => s_db_reg_rx(9),
        probe_in10 => s_db_reg_rx(10),
        probe_in11 => s_db_reg_rx(11),
        probe_in12 => s_db_reg_rx(12),
        probe_in13 => s_db_reg_rx(13),
        probe_in14 => s_db_reg_rx(14),
        probe_in15 => s_db_reg_rx(15),
        probe_in16 => s_db_reg_rx(16)
      );
end generate;  
    
end Behavioral;
