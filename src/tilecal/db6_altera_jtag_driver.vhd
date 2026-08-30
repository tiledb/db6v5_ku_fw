library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db6_altera_jtag_driver is
    generic (
        g_clk_div : positive := 25
    );
    port (
        ----------------------------------------------------------------
        -- System clock
        ----------------------------------------------------------------
        p_clk_in        : in  std_logic; -- 100 MHz

        ----------------------------------------------------------------
        -- Start pulses (mutually exclusive: hold exactly one high at a
        -- time, drop it once done_out asserts to return the fsm to idle)
        ----------------------------------------------------------------
        p_start_in                 : in  std_logic; -- idcode read (unchanged, legacy behaviour)
        p_start_boundary_scan_in   : in  std_logic; -- sample + full boundary-register capture

        ----------------------------------------------------------------
        -- JTAG
        ----------------------------------------------------------------
        p_jtag_tck_out  : out std_logic;
        p_jtag_tms_out  : out std_logic;
        p_jtag_tdi_out  : out std_logic;
        p_jtag_tdo_in   : in  std_logic;

        ----------------------------------------------------------------
        -- IDCODE result (unchanged)
        ----------------------------------------------------------------
        p_id_out        : out std_logic_vector(31 downto 0);
        p_done_out      : out std_logic;

        ----------------------------------------------------------------
        -- Boundary-scan (SAMPLE) result: the ep4ce10f17 bsdl's only
        -- boundary_register cells with a self-evident meaning without a
        -- schematic (see t_mb_boundary_scan), plus the full 603-bit raw
        -- capture byte-packed into a block ram (76 bytes; reuses the
        -- existing blk_mem_sfp ip -- 128x8 is more than wide enough) for
        -- detailed debug readback via port b (p_bs_rx/tx_register).
        ----------------------------------------------------------------
        p_msel_out              : out std_logic_vector(2 downto 0);
        p_clk_present_out       : out std_logic_vector(6 downto 0);
        p_boundary_scan_mem_out : out t_blk_mem_sfp;
        p_bs_rx_register_in     : in  std_logic_vector(6 downto 0);
        p_bs_tx_register_out    : out std_logic_vector(7 downto 0);
        p_boundary_scan_done_out : out std_logic
    );
end entity;

architecture rtl of db6_altera_jtag_driver is

    --------------------------------------------------------------------
    -- JTAG TAP controller states
    --------------------------------------------------------------------
    type t_state is (
        ST_IDLE,

        -- Reset sequence (shared by both scan types)
        ST_RESET_0,
        ST_RESET_1,
        ST_RESET_2,
        ST_RESET_3,
        ST_RESET_4,
        ST_RESET_5,

        -- IDCODE path (unchanged): relies on IDCODE being the default
        -- instruction after Test-Logic-Reset, so it never visits Shift-IR.
        ST_GOTO_DRSELECT,
        ST_GOTO_DRCAPTURE,
        ST_GOTO_DRSHIFT,
        ST_SHIFT,
        ST_EXIT1,
        ST_UPDATE,

        -- Boundary-scan path: shift SAMPLE into IR first, then walk to
        -- Shift-DR and capture all 603 boundary_register bits.
        ST_BS_GOTO_DRSCAN1,
        ST_BS_GOTO_IRSCAN,
        ST_BS_GOTO_IRCAPTURE,
        ST_BS_GOTO_IRSHIFT,
        ST_BS_SHIFT_IR,
        ST_BS_EXIT1_IR,
        ST_BS_UPDATE_IR,
        ST_BS_GOTO_DRSCAN2,
        ST_BS_GOTO_DRCAPTURE,
        ST_BS_GOTO_DRSHIFT,
        ST_BS_SHIFT_DR,
        ST_BS_EXIT1_DR,
        ST_BS_UPDATE_DR,

        ST_DONE
    );

    signal s_state          : t_state := ST_IDLE;
    signal s_boundary_scan_mode : std_logic := '0'; -- latched in ST_IDLE, selects the ST_RESET_5 branch

    --------------------------------------------------------------------
    -- JTAG outputs
    --------------------------------------------------------------------
    signal s_tck            : std_logic := '0';
    signal s_tms            : std_logic := '1';
    signal s_tdi            : std_logic := '0';

    --------------------------------------------------------------------
    -- Clock divider
    -- 100 MHz / 50 = 2 MHz JTAG clock
    --------------------------------------------------------------------
    signal s_div_cnt : integer range 0 to g_clk_div-1 := 0;

    signal s_tick           : std_logic := '0';

    --------------------------------------------------------------------
    -- IDCODE shift register (unchanged)
    --------------------------------------------------------------------
    signal s_shift_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_bit_cnt        : integer range 0 to 31 := 0;

    signal s_done           : std_logic := '0';

    --------------------------------------------------------------------
    -- Boundary-scan (SAMPLE) shift state
    --------------------------------------------------------------------
    -- SAMPLE opcode per the ep4ce10f17 bsdl (INSTRUCTION_OPCODE "0000000101"):
    -- bsdl instruction/opcode strings are written msb-first with the lsb (the
    -- first bit shifted into tdi) as the rightmost character, so indexing this
    -- vector with an ascending counter shifts it out lsb-first, as required.
    constant c_sample_opcode : std_logic_vector(9 downto 0) := "0000000101";
    signal s_ir_bit_cnt      : integer range 0 to 9 := 0;

    -- boundary_register cell numbers (per the ep4ce10f17 bsdl BOUNDARY_REGISTER
    -- attribute) for the only cells with a self-evident meaning without a board
    -- schematic: the configuration-mode strap pins and the external clock
    -- inputs. Assumes bsdl cell 0 is the first bit shifted out of tdo (i.e. the
    -- cell nearest tdo) per the standard bsdl numbering convention -- if a
    -- readback doesn't match known strapping/clocking on hardware, this
    -- direction is the first thing to flip (cell N <-> 602-N).
    constant c_bs_msel2 : integer := 216;
    constant c_bs_msel1 : integer := 219;
    constant c_bs_msel0 : integer := 222;
    constant c_bs_clk4  : integer := 228;
    constant c_bs_clk5  : integer := 231;
    constant c_bs_clk6  : integer := 234;
    constant c_bs_clk7  : integer := 237;
    constant c_bs_clk3  : integer := 534;
    constant c_bs_clk2  : integer := 537;
    constant c_bs_clk1  : integer := 540;
    constant c_bs_last_cell : integer := 602; -- boundary_length 603, 0-indexed

    signal s_bs_bit_cnt   : integer range 0 to c_bs_last_cell := 0;
    signal s_bs_byte_acc  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_msel         : std_logic_vector(2 downto 0) := (others => '0');
    signal s_clk_present  : std_logic_vector(6 downto 0) := (others => '0');
    signal s_boundary_scan_done : std_logic := '0';

    signal s_blk_mem_bs : t_blk_mem_sfp;

    COMPONENT blk_mem_sfp
      PORT (
        clka : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        clkb : IN STD_LOGIC;
        web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addrb : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
        dinb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
      );
    END COMPONENT;

begin

    --------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------
    p_jtag_tck_out <= s_tck;
    p_jtag_tms_out <= s_tms;
    p_jtag_tdi_out <= s_tdi;

    p_id_out       <= s_shift_reg;
    p_done_out     <= s_done;

    p_msel_out               <= s_msel;
    p_clk_present_out        <= s_clk_present;
    p_boundary_scan_done_out <= s_boundary_scan_done;

    --------------------------------------------------------------------
    -- Boundary-scan capture block ram: port a is written during the
    -- SAMPLE shift below; port b is a plain debug readback, addressed
    -- externally (mirrors db6_sfp_i2c_interface.vhd's port b).
    --------------------------------------------------------------------
    i_blk_mem_sfp : blk_mem_sfp
      PORT MAP (
        clka  => s_blk_mem_bs.clka,
        wea   => s_blk_mem_bs.wea,
        addra => s_blk_mem_bs.addra,
        dina  => s_blk_mem_bs.dina,
        douta => s_blk_mem_bs.douta,
        clkb  => s_blk_mem_bs.clkb,
        web   => s_blk_mem_bs.web,
        addrb => s_blk_mem_bs.addrb,
        dinb  => s_blk_mem_bs.dinb,
        doutb => s_blk_mem_bs.doutb
      );

    s_blk_mem_bs.clka <= p_clk_in;
    s_blk_mem_bs.clkb <= p_clk_in;
    s_blk_mem_bs.web(0) <= '0';

    s_blk_mem_bs.addrb <= p_bs_rx_register_in;
    s_blk_mem_bs.dinb  <= (others => '0');
    p_bs_tx_register_out <= s_blk_mem_bs.doutb;

    p_boundary_scan_mem_out <= s_blk_mem_bs;

    --------------------------------------------------------------------
    -- Clock divider
    --------------------------------------------------------------------
    process(p_clk_in)
    begin
        if rising_edge(p_clk_in) then

            s_tick <= '0';

            if s_div_cnt = g_clk_div - 1 then
                s_div_cnt <= 0;
                s_tick    <= '1';
            else
                s_div_cnt <= s_div_cnt + 1;
            end if;

        end if;
    end process;

    --------------------------------------------------------------------
    -- Main JTAG FSM
    --------------------------------------------------------------------
    process(p_clk_in)
    begin
        if rising_edge(p_clk_in) then

            if s_tick = '1' then

                ----------------------------------------------------------------
                -- Generate TCK
                ----------------------------------------------------------------
                s_tck <= not s_tck;

                ----------------------------------------------------------------
                -- Execute FSM on TCK low->high transition
                ----------------------------------------------------------------
                if s_tck = '0' then

                    -- default: port a write disabled unless a boundary-scan
                    -- byte flush below says otherwise
                    s_blk_mem_bs.wea(0) <= '0';

                    case s_state is

                        ----------------------------------------------------------------
                        -- Idle
                        ----------------------------------------------------------------
                        when ST_IDLE =>

                            s_done <= '0';
                            s_boundary_scan_done <= '0';
                            s_tms  <= '1';
                            s_tdi  <= '0';

                            if p_start_in = '1' then
                                s_boundary_scan_mode <= '0';
                                s_state <= ST_RESET_0;
                            elsif p_start_boundary_scan_in = '1' then
                                s_boundary_scan_mode <= '1';
                                s_state <= ST_RESET_0;
                            end if;

                        ----------------------------------------------------------------
                        -- Force TAP reset
                        -- TMS held high for 5+ clocks
                        ----------------------------------------------------------------
                        when ST_RESET_0 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_1;

                        when ST_RESET_1 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_2;

                        when ST_RESET_2 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_3;

                        when ST_RESET_3 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_4;

                        when ST_RESET_4 =>
                            s_tms   <= '1';
                            s_state <= ST_RESET_5;

                        when ST_RESET_5 =>
                            s_tms   <= '0';
                            if s_boundary_scan_mode = '1' then
                                s_state <= ST_BS_GOTO_DRSCAN1; -- via Shift-IR first (SAMPLE)
                            else
                                s_state <= ST_GOTO_DRSELECT;   -- idcode: default instruction, straight to Shift-DR
                            end if;

                        ----------------------------------------------------------------
                        -- IDCODE path: go to Shift-DR (unchanged)
                        ----------------------------------------------------------------
                        when ST_GOTO_DRSELECT =>
                            -- Select-DR-Scan
                            s_tms   <= '1';
                            s_state <= ST_GOTO_DRCAPTURE;

                        when ST_GOTO_DRCAPTURE =>
                            -- Capture-DR
                            s_tms   <= '0';
                            s_state <= ST_GOTO_DRSHIFT;

                        when ST_GOTO_DRSHIFT =>
                            -- Shift-DR
                            s_tms      <= '0';
                            s_bit_cnt  <= 0;
                            s_shift_reg <= (others => '0');
                            s_state    <= ST_SHIFT;

                        ----------------------------------------------------------------
                        -- Shift 32-bit IDCODE (unchanged)
                        ----------------------------------------------------------------
                        when ST_SHIFT =>

                            -- IDCODE instruction is default after reset
                            -- Shift zeros into TDI
                            s_tdi <= '0';

                            -- Shift in TDO LSB first
                            s_shift_reg <= p_jtag_tdo_in &
                                           s_shift_reg(31 downto 1);

                            if s_bit_cnt = 31 then
                                s_tms   <= '1'; -- Exit Shift-DR
                                s_state <= ST_EXIT1;
                            else
                                s_tms      <= '0';
                                s_bit_cnt  <= s_bit_cnt + 1;
                            end if;

                        ----------------------------------------------------------------
                        -- Exit1-DR
                        ----------------------------------------------------------------
                        when ST_EXIT1 =>
                            s_tms   <= '1';
                            s_state <= ST_UPDATE;

                        ----------------------------------------------------------------
                        -- Update-DR -> Run-Test/Idle
                        ----------------------------------------------------------------
                        when ST_UPDATE =>
                            s_tms   <= '0';
                            s_done  <= '1';
                            s_state <= ST_DONE;

                        ----------------------------------------------------------------
                        -- Boundary-scan path: Run-Test/Idle -> Select-DR-Scan ->
                        -- Select-IR-Scan -> Capture-IR -> Shift-IR (SAMPLE, 10 bits)
                        ----------------------------------------------------------------
                        when ST_BS_GOTO_DRSCAN1 =>
                            -- Select-DR-Scan
                            s_tms   <= '1';
                            s_state <= ST_BS_GOTO_IRSCAN;

                        when ST_BS_GOTO_IRSCAN =>
                            -- Select-IR-Scan
                            s_tms   <= '1';
                            s_state <= ST_BS_GOTO_IRCAPTURE;

                        when ST_BS_GOTO_IRCAPTURE =>
                            -- Capture-IR
                            s_tms   <= '0';
                            s_state <= ST_BS_GOTO_IRSHIFT;

                        when ST_BS_GOTO_IRSHIFT =>
                            -- Shift-IR
                            s_tms       <= '0';
                            s_ir_bit_cnt <= 0;
                            s_state     <= ST_BS_SHIFT_IR;

                        when ST_BS_SHIFT_IR =>
                            s_tdi <= c_sample_opcode(s_ir_bit_cnt);

                            if s_ir_bit_cnt = 9 then
                                s_tms   <= '1'; -- Exit Shift-IR
                                s_state <= ST_BS_EXIT1_IR;
                            else
                                s_tms        <= '0';
                                s_ir_bit_cnt <= s_ir_bit_cnt + 1;
                            end if;

                        when ST_BS_EXIT1_IR =>
                            s_tms   <= '1';
                            s_state <= ST_BS_UPDATE_IR;

                        when ST_BS_UPDATE_IR =>
                            -- Update-IR -> Run-Test/Idle
                            s_tms   <= '0';
                            s_state <= ST_BS_GOTO_DRSCAN2;

                        ----------------------------------------------------------------
                        -- Boundary-scan path: Run-Test/Idle -> Select-DR-Scan ->
                        -- Capture-DR -> Shift-DR (SAMPLE result, 603 bits)
                        ----------------------------------------------------------------
                        when ST_BS_GOTO_DRSCAN2 =>
                            -- Select-DR-Scan
                            s_tms   <= '1';
                            s_state <= ST_BS_GOTO_DRCAPTURE;

                        when ST_BS_GOTO_DRCAPTURE =>
                            -- Capture-DR
                            s_tms   <= '0';
                            s_state <= ST_BS_GOTO_DRSHIFT;

                        when ST_BS_GOTO_DRSHIFT =>
                            -- Shift-DR
                            s_tms         <= '0';
                            s_bs_bit_cnt  <= 0;
                            s_bs_byte_acc <= (others => '0');
                            s_state       <= ST_BS_SHIFT_DR;

                        when ST_BS_SHIFT_DR =>
                            s_tdi <= '0'; -- sample is non-intrusive: tdi value is irrelevant

                            -- flush the byte accumulated over the previous 8 bits,
                            -- right as we start shifting a new byte (avoids a
                            -- same-cycle read-after-write on the accumulator)
                            if s_bs_bit_cnt > 0 and s_bs_bit_cnt mod 8 = 0 then
                                s_blk_mem_bs.wea(0) <= '1';
                                s_blk_mem_bs.addra   <= std_logic_vector(to_unsigned((s_bs_bit_cnt/8)-1, 7));
                                s_blk_mem_bs.dina    <= s_bs_byte_acc;
                            end if;

                            -- shift the new bit in, lsb-first (same convention as the idcode path)
                            s_bs_byte_acc <= p_jtag_tdo_in & s_bs_byte_acc(7 downto 1);

                            -- tap the cells with a self-evident meaning as they pass by
                            case s_bs_bit_cnt is
                                when c_bs_msel2 => s_msel(2) <= p_jtag_tdo_in;
                                when c_bs_msel1 => s_msel(1) <= p_jtag_tdo_in;
                                when c_bs_msel0 => s_msel(0) <= p_jtag_tdo_in;
                                when c_bs_clk1  => s_clk_present(0) <= p_jtag_tdo_in;
                                when c_bs_clk2  => s_clk_present(1) <= p_jtag_tdo_in;
                                when c_bs_clk3  => s_clk_present(2) <= p_jtag_tdo_in;
                                when c_bs_clk4  => s_clk_present(3) <= p_jtag_tdo_in;
                                when c_bs_clk5  => s_clk_present(4) <= p_jtag_tdo_in;
                                when c_bs_clk6  => s_clk_present(5) <= p_jtag_tdo_in;
                                when c_bs_clk7  => s_clk_present(6) <= p_jtag_tdo_in;
                                when others => null;
                            end case;

                            if s_bs_bit_cnt = c_bs_last_cell then
                                s_tms   <= '1'; -- Exit Shift-DR
                                s_state <= ST_BS_EXIT1_DR;
                            else
                                s_tms        <= '0';
                                s_bs_bit_cnt <= s_bs_bit_cnt + 1;
                            end if;

                        when ST_BS_EXIT1_DR =>
                            -- flush the final (partial) byte 75: cells 600-602 in bits
                            -- 2:0, bits 7:3 are leftover shift residue from cells 597-599
                            s_blk_mem_bs.wea(0) <= '1';
                            s_blk_mem_bs.addra   <= std_logic_vector(to_unsigned((c_bs_last_cell/8), 7));
                            s_blk_mem_bs.dina    <= s_bs_byte_acc;

                            s_tms   <= '1';
                            s_state <= ST_BS_UPDATE_DR;

                        when ST_BS_UPDATE_DR =>
                            -- Update-DR -> Run-Test/Idle
                            s_tms   <= '0';
                            s_boundary_scan_done <= '1';
                            s_state <= ST_DONE;

                        ----------------------------------------------------------------
                        -- Done
                        ----------------------------------------------------------------
                        when ST_DONE =>

                            s_tms <= '0';
                            s_tdi <= '0';

                            if p_start_in = '0' and p_start_boundary_scan_in = '0' then
                                s_done  <= '0';
                                s_boundary_scan_done <= '0';
                                s_state <= ST_IDLE;
                            end if;

                        when others =>
                            s_state <= ST_IDLE;

                    end case;

                end if;

            end if;

        end if;
    end process;

end architecture;
