library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity db6_proasic3_jtag_driver is
    generic (
        g_clk_div : positive := 25
    );
    port (
        p_clk_in        : in  std_logic;
        p_rst_in        : in  std_logic;

        p_start_in      : in  std_logic;
        p_ir_in         : in  std_logic_vector(7 downto 0);

        p_jtag_tck_out  : out std_logic;
        p_jtag_tms_out  : out std_logic;
        p_jtag_tdi_out  : out std_logic;
        p_jtag_tdo_in   : in  std_logic;
        p_jtag_trst_out : out std_logic;

        p_dr_out        : out std_logic_vector(31 downto 0);
        p_busy_out      : out std_logic;
        p_done_out      : out std_logic
    );
end entity;

architecture rtl of db6_proasic3_jtag_driver is

    -- Standard JTAG TAP Controller States
    type t_state is (
        st_idle,
        st_reset,
        st_select_dr_scan,
        st_select_ir_scan,
        st_capture_ir,
        st_shift_ir,
        st_exit1_ir,
        st_update_ir,
        st_capture_dr,
        st_shift_dr,
        st_exit1_dr,
        st_update_dr
    );

    signal s_state     : t_state := st_idle;
    
    -- Clock Divider Signals
    signal s_div_cnt   : natural range 0 to g_clk_div := 0;
    signal s_tck       : std_logic := '0';
    signal s_tck_pulse : std_logic := '0'; 

    -- Internal Shift Registers and Counters
    signal s_ir_reg    : std_logic_vector(7 downto 0) := (others => '0');
    signal s_dr_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_bit_cnt   : integer range 0 to 31 := 0;

    -- Global hardware edge tracking registers
    signal s_start_reg     : std_logic := '0';
    signal s_start_trig    : std_logic := '0';

begin

    -- Static Port Assignments
    p_jtag_tck_out  <= s_tck;
    p_jtag_trst_out <= not p_rst_in;
    p_dr_out        <= s_dr_reg;

    -- ============================================================
    -- TCK Clock Divider & Rising Edge Pulse Generator
    -- ============================================================
    process(p_clk_in)
    begin
        if rising_edge(p_clk_in) then
            if p_rst_in = '1' then
                s_div_cnt   <= 0;
                s_tck       <= '0';
                s_tck_pulse <= '0';
            else
                s_tck_pulse <= '0'; 
                
                if s_div_cnt = g_clk_div - 1 then
                    s_div_cnt <= 0;
                    s_tck     <= not s_tck;
                    
                    if s_tck = '0' then
                        s_tck_pulse <= '1';
                    end if;
                else
                    s_div_cnt <= s_div_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- ============================================================
    -- Synchronous State Machine & JTAG Sequencing
    -- ============================================================
    process(p_clk_in)
    begin
        if rising_edge(p_clk_in) then
            if p_rst_in = '1' then
                s_state         <= st_idle;
                p_busy_out      <= '0';
                p_done_out      <= '0';
                p_jtag_tms_out  <= '1';
                p_jtag_tdi_out  <= '0';
                s_bit_cnt       <= 0;
                s_ir_reg        <= (others => '0');
                s_dr_reg        <= (others => '0');
                s_start_reg     <= '0';
                s_start_trig    <= '0';
            else
                -- Pulsed outputs default low
                p_done_out <= '0';

                -- 1. CLOCK EDGE DETECTION FOR ASYNC VIO START
                -- Runs every clock cycle at 100MHz to catch the exact start moment
                s_start_reg <= p_start_in;
                if p_start_in = '1' and s_start_reg = '0' then
                    s_start_trig <= '1'; -- Latches high, acts as a temporary token
                end if;

                -- 2. STATE MACHINE LOGIC STEPPING
                if s_tck_pulse = '1' then
                    case s_state is

                        when st_idle =>
                            p_busy_out     <= '0';
                            p_jtag_tms_out <= '1'; 
                            p_jtag_tdi_out <= '0';
                            
                            -- Consume the start token only once, ignoring a latched high signal
                            if s_start_trig = '1' then
                                s_start_trig <= '0'; -- Clear the token immediately 
                                s_ir_reg     <= p_ir_in;
                                p_busy_out   <= '1';
                                s_bit_cnt    <= 0;
                                s_state      <= st_reset;
                            end if;

                        -- Run Test-Logic-Reset for 5 cycles to guarantee chip TAP clearing
                        when st_reset =>
                            p_jtag_tms_out <= '1';
                            if s_bit_cnt = 4 then 
                                p_jtag_tms_out <= '0'; 
                                s_state        <= st_select_dr_scan;
                            else
                                s_bit_cnt <= s_bit_cnt + 1;
                            end if;

                        when st_select_dr_scan =>
                            p_jtag_tms_out <= '1'; 
                            s_state        <= st_select_ir_scan;

                        when st_select_ir_scan =>
                            p_jtag_tms_out <= '1'; 
                            s_state        <= st_capture_ir;

                        when st_capture_ir =>
                            p_jtag_tms_out <= '0'; 
                            s_state        <= st_shift_ir;
                            s_bit_cnt      <= 0;
                            p_jtag_tdi_out <= s_ir_reg(0); 

                        when st_shift_ir =>
                            if s_bit_cnt = 7 then
                                p_jtag_tms_out <= '1'; 
                                s_state        <= st_exit1_ir;
                            else
                                p_jtag_tms_out <= '0'; 
                                p_jtag_tdi_out <= s_ir_reg(s_bit_cnt + 1);
                                s_bit_cnt      <= s_bit_cnt + 1;
                            end if;

                        when st_exit1_ir =>
                            p_jtag_tms_out <= '1'; 
                            s_state        <= st_update_ir;

                        when st_update_ir =>
                            p_jtag_tms_out <= '1'; 
                            s_state        <= st_capture_dr;

                        when st_capture_dr =>
                            p_jtag_tms_out <= '0'; 
                            s_state        <= st_shift_dr;
                            s_bit_cnt      <= 0;
                            p_jtag_tdi_out <= '0';

                        when st_shift_dr =>
                            s_dr_reg(s_bit_cnt) <= p_jtag_tdo_in;
                            
                            if s_bit_cnt = 31 then
                                p_jtag_tms_out <= '1'; 
                                s_state        <= st_exit1_dr;
                            else
                                p_jtag_tms_out <= '0'; 
                                s_bit_cnt      <= s_bit_cnt + 1;
                            end if;

                        when st_exit1_dr =>
                            p_jtag_tms_out <= '1'; 
                            s_state        <= st_update_dr;

                        when st_update_dr =>
                            p_jtag_tms_out <= '1';
                            p_done_out     <= '1';
                            p_busy_out     <= '0';
                            s_state        <= st_idle;

                        when others =>
                            s_state <= st_idle;
                    end case;
                end if;
            end if;
        end if;
    end process;

end architecture;
