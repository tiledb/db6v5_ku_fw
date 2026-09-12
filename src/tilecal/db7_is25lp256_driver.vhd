----------------------------------------------------------------------------------
-- Module Name: db7_is25lp256_driver - rtl
-- Additional Comments:
--   Single-bit (not quad) SPI, mode 0, MSB-first, bit-banged driver for the
--   ISSI IS25LP256 (256Mbit/32MB) configuration flash. Talks to the flash
--   through the FPGA's dedicated STARTUPE3 primitive -- on UltraScale devices
--   the configuration-bank pins the flash is wired to (CS#/SCK/IO0-IO3) are
--   not accessible as plain top-level I/O once the bitstream has loaded, so
--   db7_io_box instantiates STARTUPE3 and this module talks to it through
--   t_is25lp256_control (p_flash_control_out/p_flash_control_in), never
--   touching a pad directly.
--
--   Since the device is 32MB (exceeds the 16MB reach of 3-byte addressing),
--   every addressed command uses the IS25LP256's native 4-byte-address opcode
--   variant (no EN4B/EX4B mode switch needed). Opcode values below are the
--   ISSI-documented ones as of this writing -- re-check against the current
--   IS25LP256 datasheet during hardware bring-up if a command doesn't behave
--   as expected (same spirit as the boundary-scan cell-numbering caveat in
--   db6_altera_jtag_driver.vhd).
--
--   Command interface (see db6_design_package.vhd cfb_flash_address/command,
--   stb_flash_status/stb_flash_rdata): software writes cfb_flash_address (raw
--   32-bit byte address) and cfb_flash_command (opcode/length_sel/wdata),
--   then sets cfb_flash_command bit31 (start) and holds it high until
--   stb_flash_status bit1 (done) reads back high, then drops start -- same
--   level-held handshake as db6_altera_jtag_driver's p_start_in/p_done_out.
--
--   The driver owns the SPI bus permanently (FCSBTS/USRCCLKTS tied '0'
--   always) rather than tri-stating between transactions: CS# idles high
--   (deselected) and SCK idles low, WP#/HOLD# are driven high (inactive) at
--   all times so the flash never sees an accidental hold/write-protect
--   condition, and only CS#/SCK actually toggle during a transaction.
--
--   Write-protect floor (cfb_flash_write_floor): PAGE_PROGRAM only runs if
--   cfb_flash_address is strictly greater than this byte address. SECTOR_ERASE/
--   BLOCK_ERASE are floor-checked against their erase-aligned block start (4KB/64KB),
--   not the raw commanded address, since an erase always wipes its whole aligned
--   block. Either way a blocked command no-ops (no bus activity) and
--   stb_flash_status bit15 (write_blocked) is set. Defaults to half the device
--   (0x01000000), so the low half stays read-only until firmware raises it.
--   CHIP_ERASE has no address to align/check, so it's gated all-or-nothing instead:
--   permitted only when the effective floor is exactly 0.
--
--   The effective floor is cfb_flash_write_floor, unless
--   vio_clknet_status probe_out15 bit32 (flash_manual_write_floor_enable) is set, in
--   which case the vio-supplied value (bits31:0 of that same probe) is used instead
--   -- a mux, not an OR, so hw_manager can actually lower/disable the floor for
--   debugging without needing to touch cfb_flash_write_floor itself.
--
--   RESET_ENABLE(0x66)/RESET(0x99): added during hardware bring-up after RDID/READ/
--   RDSR all came back as all-ones over the actual SPI link. Non-destructive
--   (touches no flash content) -- issue RESET_ENABLE then RESET (WREN not
--   required) before retrying a read if the chip appears unresponsive. Turned out
--   not to be the fix (see below), but kept: it's a reasonable thing to have.
--
--   Root cause of the all-ones symptom, found via hardware bring-up: MOSI/CS#
--   changes and their corresponding SCK edge were landing on the exact same
--   internal clock cycle (zero setup time from the chip's point of view), on
--   every bit of every transaction -- not a wiring/STARTUPE3-usage problem, and
--   not fixable in software alone (confirmed independently: Vivado's own indirect
--   flash programming, same physical STARTUPE3 link, read this exact chip's JEDEC
--   ID and content correctly). Fixed by driving the physical clock pin from
--   s_sck_out, a one-tick-delayed shadow of the internal FSM clock s_sck -- see
--   that signal's declaration comment below for the detail.
--
--   PAGE_READ (cfb_flash_command opcode c_op_page_read) and the write fifo
--   (cfb_flash_fifo_addr/cfb_flash_fifo_push) were added after the above was
--   verified working, to move whole 256-byte pages at a time instead of 1-4
--   bytes per db_reg_rx/VIO round-trip:
--     - PAGE_READ runs a dedicated 256-iteration FAST_READ burst (own state,
--       ST_PAGE_READ_BURST -- deliberately not reusing ST_SHIFT_RDATA, to avoid
--       touching the already hardware-verified small-read path) that streams
--       each byte into port a of a new 256x8 block ram (blk_mem_flash_page);
--       software then walks the page out one byte at a time via
--       cfb_flash_page_ram_address/stb_flash_page_ram_readback (port b, same
--       commanded-address readback idiom used elsewhere in this design, e.g.
--       cfb_gbtx_reg_readback_address).
--     - The write fifo lets software queue up to 32 {address,data} entries
--       (cfb_flash_fifo_addr staged, then cfb_flash_fifo_push bit31 toggled to
--       push -- see stb_flash_fifo_status for fill/full/empty). Since the push
--       bit crosses from the cfgbus clock domain, it's synchronized with a
--       plain 2-flop synchronizer + edge-detect (safe for a toggle/level bit,
--       unlike a single-cycle strobe). Whenever the driver is idle and the fifo
--       is non-empty, it auto-dispatches a PAGE_PROGRAM burst sourced from the
--       fifo (s_burst_mode) and keeps CS low across contiguous, same-page
--       entries, falling back to ST_DEASSERT_CS the moment the next queued
--       address isn't exactly +1 or would cross the 256-byte page boundary
--       (the flash's internal column pointer wraps within the page instead of
--       advancing, so a burst must never be allowed to cross one). The
--       write-protect floor is checked once, against the burst's starting
--       address only; a floor-blocked burst is dropped (popped without being
--       sent) rather than retried forever. Manual single-byte PAGE_PROGRAM
--       (s_burst_mode='0', the already-verified path) is completely unchanged
--       -- s_wdata_mux just selects s_cmd_wdata in that case, byte-for-byte
--       identical to before.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tilecal;
use tilecal.db6_design_package.all;

entity db7_is25lp256_driver is
    generic (
        g_clk_div : positive := 4 -- p_clk_in/(2*g_clk_div) SCK rate (osc_clk40/8 = 5 MHz by default)
    );
    port (
        p_clknet_in        : in  t_db_clknet; -- clock (osc_clk40) + flash_manual_address/command/write_floor*
        p_master_reset_in  : in  std_logic;

        p_db_reg_rx_in      : in  t_db_reg_rx; -- cfb_flash_address / cfb_flash_command / cfb_flash_write_floor

        p_flash_control_out : out t_is25lp256_control; -- do/dts/fcsbo/fcsbts/usrcclko/usrcclkts
        p_flash_control_in  : in  t_is25lp256_control; -- di (readback) only

        p_status_out : out std_logic_vector(31 downto 0); -- -> stb_flash_status
        p_rdata_out  : out std_logic_vector(31 downto 0); -- -> stb_flash_rdata

        p_page_ram_readback_out : out std_logic_vector(15 downto 0); -- -> stb_flash_page_ram_readback
        p_fifo_status_out       : out std_logic_vector(7 downto 0)   -- -> stb_flash_fifo_status
    );
end entity;

architecture rtl of db7_is25lp256_driver is

    -- 256x8 True Dual Port RAM (see t_blk_mem_flash_page in db6_design_package.vhd):
    -- port a written by the PAGE_READ burst below, port b read-only, addressed by
    -- cfb_flash_page_ram_address (same shape/idiom as blk_mem_gbtx_regs, just 8-bit
    -- deep instead of 9-bit -- see db6_gbtx_i2c_interface_testbeam.vhd for the
    -- reference pattern this mirrors)
    component blk_mem_flash_page
        port (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(7 downto 0);
            dina  : in  std_logic_vector(7 downto 0);
            douta : out std_logic_vector(7 downto 0);
            clkb  : in  std_logic;
            web   : in  std_logic_vector(0 downto 0);
            addrb : in  std_logic_vector(7 downto 0);
            dinb  : in  std_logic_vector(7 downto 0);
            doutb : out std_logic_vector(7 downto 0)
        );
    end component;

    ----------------------------------------------------------------
    -- internal opcode encoding (cfb_flash_command bits 28:24 -- widened from
    -- 4 to 5 bits when RDERP/CLERP/GBUN were added, see below)
    ----------------------------------------------------------------
    constant c_op_nop         : std_logic_vector(4 downto 0) := "00000";
    constant c_op_wren        : std_logic_vector(4 downto 0) := "00001";
    constant c_op_wrdi        : std_logic_vector(4 downto 0) := "00010";
    constant c_op_rdsr        : std_logic_vector(4 downto 0) := "00011";
    constant c_op_read        : std_logic_vector(4 downto 0) := "00100";
    constant c_op_fast_read   : std_logic_vector(4 downto 0) := "00101";
    constant c_op_page_program: std_logic_vector(4 downto 0) := "00110";
    constant c_op_sector_erase: std_logic_vector(4 downto 0) := "00111";
    constant c_op_block_erase : std_logic_vector(4 downto 0) := "01000";
    constant c_op_chip_erase  : std_logic_vector(4 downto 0) := "01001";
    constant c_op_rdid        : std_logic_vector(4 downto 0) := "01010";
    constant c_op_reset_enable: std_logic_vector(4 downto 0) := "01011";
    constant c_op_reset       : std_logic_vector(4 downto 0) := "01100";
    -- 256-byte page burst read into blk_mem_flash_page (see ST_PAGE_READ_BURST
    -- below); always issues 4FASTREAD (0x0C) internally, same as c_op_fast_read
    constant c_op_page_read   : std_logic_vector(4 downto 0) := "01101";
    -- added while debugging a PAGE_PROGRAM byte silently not landing on real
    -- hardware (WREN/WEL confirmed working, floor/BP not blocking it, yet
    -- readback still showed the erased 0xFF) -- IS25LP256D datasheet section
    -- 6.3.2/Table 6.15: PP/4PP sets PROT_E/P_ERR in the Extended Read Register
    -- if the program hit a protected sector/block via ASP (DYB/PPB), which is
    -- invisible in the plain Status Register's BP0-3 bits. RDERP reads that
    -- register (RDSR-shaped: opcode-only, 1 byte out, bit1=PROT_E, see
    -- ST_IDLE's c_op_rdsr branch, reused for this opcode too); CLERP clears
    -- PROT_E/P_ERR/E_ERR (sticky until cleared) so a retest starts clean;
    -- GBUN (Gang Block Unlock) clears all DYB bits in one shot, the likely
    -- fix if RDERP does show PROT_E set (see header comment update once this
    -- is confirmed on hardware).
    constant c_op_rderp       : std_logic_vector(4 downto 0) := "01110";
    constant c_op_clerp       : std_logic_vector(4 downto 0) := "01111";
    constant c_op_gbun        : std_logic_vector(4 downto 0) := "10000";
    -- added while further debugging PAGE_PROGRAM/SECTOR_ERASE both silently
    -- not taking effect (WEL never auto-clears afterward, confirmed via tight
    -- RDSR polling -- the flash never recognizes either command as executed,
    -- even though RDID/RDSR/WREN/RDERP/READ/FAST_READ, including
    -- address-phase reads at several addresses with real varying data, all
    -- verified working correctly). RDSR showed QE=1 (Quad Enable) on this
    -- chip; per the datasheet, with QE=1 the WP#/HOLD# pins become IO2/IO3,
    -- and this driver ties them to constant '1' from the FPGA side always --
    -- a plausible bus-contention source specific to any operation where the
    -- flash's internal engine does something with those pins post-CS, which
    -- would explain why plain reads (SO/SI only) are unaffected while
    -- PP/SER are. WRSR (opcode + 1 write-data byte, no address -- a
    -- combination never exercised before: PP has has_address=1 too, so this
    -- is the first has_address=0/is_write=1 test) both clears QE (candidate
    -- fix) and isolates whether the bug is in the write-data phase itself
    -- or specifically the address->write-data transition.
    constant c_op_wrsr        : std_logic_vector(4 downto 0) := "10001";

    -- SPI instruction bytes (4-byte-address variants where applicable)
    constant c_spi_wren        : std_logic_vector(7 downto 0) := x"06";
    constant c_spi_wrdi        : std_logic_vector(7 downto 0) := x"04";
    constant c_spi_rdsr        : std_logic_vector(7 downto 0) := x"05";
    constant c_spi_4read       : std_logic_vector(7 downto 0) := x"13";
    constant c_spi_4fastread   : std_logic_vector(7 downto 0) := x"0C";
    constant c_spi_4pp         : std_logic_vector(7 downto 0) := x"12";
    constant c_spi_4se         : std_logic_vector(7 downto 0) := x"21";
    constant c_spi_reset_enable: std_logic_vector(7 downto 0) := x"66";
    constant c_spi_reset       : std_logic_vector(7 downto 0) := x"99";
    constant c_spi_4be         : std_logic_vector(7 downto 0) := x"DC";
    constant c_spi_chip_erase  : std_logic_vector(7 downto 0) := x"C7";
    constant c_spi_rdid        : std_logic_vector(7 downto 0) := x"9F";
    constant c_spi_rderp       : std_logic_vector(7 downto 0) := x"81";
    constant c_spi_clerp       : std_logic_vector(7 downto 0) := x"82";
    constant c_spi_gbun        : std_logic_vector(7 downto 0) := x"98";
    constant c_spi_wrsr        : std_logic_vector(7 downto 0) := x"01";

    ----------------------------------------------------------------
    -- command register decode
    ----------------------------------------------------------------
    signal s_cmd_command    : std_logic_vector(31 downto 0);
    signal s_cmd_start      : std_logic;
    signal s_cmd_opcode     : std_logic_vector(4 downto 0);
    signal s_cmd_length_sel : std_logic_vector(1 downto 0);
    signal s_cmd_wdata      : std_logic_vector(7 downto 0);
    signal s_cmd_address    : std_logic_vector(31 downto 0);
    signal s_write_floor    : std_logic_vector(31 downto 0); -- cfb_flash_write_floor
    -- erase-aligned block start for s_cmd_address, per opcode (4KB for sector erase,
    -- 64KB for block erase) -- an erase always wipes the whole aligned block regardless
    -- of which byte address within it was commanded, so this is what must be floor-checked,
    -- not s_cmd_address itself
    signal s_erase_block_start : std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- clock divider (same style as db6_altera_jtag_driver.vhd)
    ----------------------------------------------------------------
    signal s_div_cnt : integer range 0 to g_clk_div-1 := 0;
    signal s_tick     : std_logic := '0';

    ----------------------------------------------------------------
    -- FSM
    ----------------------------------------------------------------
    type t_state is (
        ST_IDLE,
        ST_ASSERT_CS,
        ST_SHIFT_OPCODE,
        ST_SHIFT_ADDRESS,
        ST_SHIFT_DUMMY,
        ST_SHIFT_WDATA,
        ST_SHIFT_RDATA,
        ST_PAGE_READ_BURST,
        ST_DEASSERT_CS,
        ST_DONE
    );
    signal s_state : t_state := ST_IDLE;

    signal s_sck        : std_logic := '0'; -- internal FSM-timing clock (idle low)
    -- one-tick-delayed shadow of s_sck, driven onto the physical pin (USRCCLKO)
    -- instead of s_sck directly -- see the header comment and the process below for
    -- why: without this, every bit change (MOSI) and its corresponding real clock
    -- edge would land on the exact same internal clock cycle (zero setup time),
    -- which real SPI flash does not tolerate.
    signal s_sck_out     : std_logic := '0';
    signal s_cs_n        : std_logic := '1'; -- idle deselected

    signal s_op_latched      : std_logic_vector(4 downto 0) := (others => '0');
    signal s_has_address     : std_logic := '0';
    signal s_has_dummy       : std_logic := '0';
    signal s_is_write        : std_logic := '0';
    signal s_rdata_bytes     : integer range 1 to 4 := 1;

    signal s_shift_out  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_shift_addr : std_logic_vector(31 downto 0) := (others => '0');
    signal s_bit_cnt     : integer range 0 to 31 := 0;
    signal s_byte_cnt    : integer range 0 to 3 := 0;

    signal s_si_out : std_logic := '0'; -- shifted onto DO(0) / STARTUPE3 lane 0 (SI/IO0)

    signal s_status_reg  : std_logic_vector(7 downto 0) := (others => '0'); -- last RDSR byte
    signal s_rdata_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_done         : std_logic := '0';
    signal s_busy         : std_logic := '0';
    signal s_write_blocked : std_logic := '0'; -- last command rejected by the write floor

    -- selects the byte actually shifted out during a write phase: s_cmd_wdata for
    -- the original manual single-byte path (s_burst_mode='0', unchanged from before),
    -- s_burst_wdata when auto-draining the write fifo (s_burst_mode='1')
    signal s_burst_mode  : std_logic := '0';
    signal s_burst_wdata : std_logic_vector(7 downto 0) := (others => '0');
    signal s_wdata_mux   : std_logic_vector(7 downto 0);
    -- last byte address actually written this burst (valid once s_burst_mode='1');
    -- used to check the next fifo entry is exactly +1 and still in the same page
    signal s_burst_addr  : std_logic_vector(31 downto 0) := (others => '0');

    ----------------------------------------------------------------
    -- page-read burst (ST_PAGE_READ_BURST): completion/state-advance tracking
    -- (same tick phase as s_bit_cnt above) is independent of the RAM-write
    -- tracking below (same tick phase as the DI-sample block) -- see the two
    -- counters' respective comments and the header comment for why this is safe.
    ----------------------------------------------------------------
    signal s_page_byte_cnt : integer range 0 to 255 := 0; -- state-advance side: counts completed bytes (0-255)

    signal s_page_sample_bit_cnt : integer range 0 to 7 := 0; -- di-sample side: bit position within the current byte
    signal s_page_byte_reg       : std_logic_vector(7 downto 0) := (others => '0'); -- di-sample side: current byte being shifted in
    signal s_page_ram_wea        : std_logic := '0'; -- one-tick pulse: write the completed byte into blk_mem_flash_page
    signal s_page_ram_wr_addr    : std_logic_vector(7 downto 0) := (others => '0'); -- address that byte lands at
    signal s_page_ram_dina       : std_logic_vector(7 downto 0) := (others => '0'); -- the completed byte itself
    signal s_page_ram_addr_cnt   : unsigned(7 downto 0) := (others => '0'); -- running write address, 0..255

    signal s_blk_mem_flash_page : t_blk_mem_flash_page;

    ----------------------------------------------------------------
    -- write fifo: 32 entries x 40 bits ({address(31:0), data(7:0)}), hand-rolled
    -- circular buffer (see header comment). Owned entirely by the dedicated
    -- process below -- the main fsm process only reads s_fifo_head_*/s_fifo_next_*/
    -- s_fifo_empty and requests a pop via the one-tick pulse s_fifo_pop_req, so
    -- there is exactly one process driving s_fifo_mem/pointers/count (no
    -- multi-driver conflict).
    ----------------------------------------------------------------
    type t_fifo_array is array (0 to 31) of std_logic_vector(39 downto 0);
    signal s_fifo_mem    : t_fifo_array := (others => (others => '0'));
    signal s_fifo_wr_ptr : integer range 0 to 31 := 0;
    signal s_fifo_rd_ptr : integer range 0 to 31 := 0;
    signal s_fifo_rd_ptr_next : integer range 0 to 31;
    signal s_fifo_count  : integer range 0 to 32 := 0;
    signal s_fifo_empty  : std_logic;
    signal s_fifo_full   : std_logic;
    signal s_fifo_has_next : std_logic; -- '1' if a second (post-head) entry exists

    signal s_fifo_head_addr : std_logic_vector(31 downto 0);
    signal s_fifo_head_data : std_logic_vector(7 downto 0);
    signal s_fifo_next_addr : std_logic_vector(31 downto 0);
    signal s_fifo_next_data : std_logic_vector(7 downto 0);

    -- fifo push toggle-bit cdc (cfb_flash_fifo_push bit31 crosses from the cfgbus
    -- clock domain -- see header comment): plain 2-flop synchronizer, safe for a
    -- level/toggle bit (unlike a single-cycle strobe)
    signal s_push_toggle_sync1 : std_logic := '0';
    signal s_push_toggle_sync2 : std_logic := '0';
    signal s_push_toggle_last  : std_logic := '0';

    -- one-tick pulse (main fsm process) requesting the fifo process pop its head
    -- entry; the fifo process edge-detects this (s_fifo_pop_req_last) since the
    -- main fsm only re-evaluates every g_clk_div ticks and so may hold this
    -- level high for several raw clock cycles
    signal s_fifo_pop_req      : std_logic := '0';
    signal s_fifo_pop_req_last : std_logic := '0';

begin

    ----------------------------------------------------------------
    -- command register decode (direct db_reg_rx indexing, same pattern
    -- as db6_sfp_interface.vhd's cfb_sfp_reg_address usage)
    ----------------------------------------------------------------
    -- ORed with the vio_clknet_status manual override (see t_db_clknet.flash_manual_*):
    -- don't drive both non-zero at once, same convention as e.g. cfb_gbtx_reg_readback_address.
    s_cmd_address    <= p_db_reg_rx_in(cfb_flash_address) or p_clknet_in.flash_manual_address;
    s_cmd_command    <= p_db_reg_rx_in(cfb_flash_command) or p_clknet_in.flash_manual_command;
    s_cmd_start      <= s_cmd_command(31);
    s_cmd_opcode     <= s_cmd_command(28 downto 24);
    s_cmd_length_sel <= s_cmd_command(9 downto 8);
    s_cmd_wdata      <= s_cmd_command(7 downto 0);
    -- muxed rather than ORed with the vio override (an OR could only ever raise the
    -- floor, never lower/disable it) -- see t_db_clknet.flash_manual_write_floor*
    s_write_floor    <= p_clknet_in.flash_manual_write_floor when p_clknet_in.flash_manual_write_floor_enable = '1'
                         else p_db_reg_rx_in(cfb_flash_write_floor);

    s_erase_block_start <= s_cmd_address(31 downto 12) & x"000" when s_cmd_opcode = c_op_sector_erase else
                            s_cmd_address(31 downto 16) & x"0000" when s_cmd_opcode = c_op_block_erase else
                            s_cmd_address;

    -- selects the byte shifted out during a write phase (see signal comment above)
    s_wdata_mux <= s_burst_wdata when s_burst_mode = '1' else s_cmd_wdata;

    ----------------------------------------------------------------
    -- write fifo: combinational helper signals (see signal declarations above)
    ----------------------------------------------------------------
    s_fifo_rd_ptr_next <= 0 when s_fifo_rd_ptr = 31 else s_fifo_rd_ptr + 1;
    s_fifo_empty    <= '1' when s_fifo_count = 0 else '0';
    s_fifo_full     <= '1' when s_fifo_count = 32 else '0';
    s_fifo_has_next <= '1' when s_fifo_count > 1 else '0';
    s_fifo_head_addr <= s_fifo_mem(s_fifo_rd_ptr)(39 downto 8);
    s_fifo_head_data <= s_fifo_mem(s_fifo_rd_ptr)(7 downto 0);
    s_fifo_next_addr <= s_fifo_mem(s_fifo_rd_ptr_next)(39 downto 8);
    s_fifo_next_data <= s_fifo_mem(s_fifo_rd_ptr_next)(7 downto 0);

    ----------------------------------------------------------------
    -- 256x8 page-read buffer ram: port a written by ST_PAGE_READ_BURST, port b
    -- read-only, addressed by cfb_flash_page_ram_address
    ----------------------------------------------------------------
    i_blk_mem_flash_page : blk_mem_flash_page
        port map (
            clka  => s_blk_mem_flash_page.clka,
            wea   => s_blk_mem_flash_page.wea,
            addra => s_blk_mem_flash_page.addra,
            dina  => s_blk_mem_flash_page.dina,
            douta => s_blk_mem_flash_page.douta,
            clkb  => s_blk_mem_flash_page.clkb,
            web   => s_blk_mem_flash_page.web,
            addrb => s_blk_mem_flash_page.addrb,
            dinb  => s_blk_mem_flash_page.dinb,
            doutb => s_blk_mem_flash_page.doutb
        );

    s_blk_mem_flash_page.clka   <= p_clknet_in.osc_clk40;
    s_blk_mem_flash_page.clkb   <= p_clknet_in.osc_clk40;
    s_blk_mem_flash_page.wea(0) <= s_page_ram_wea;
    s_blk_mem_flash_page.addra  <= s_page_ram_wr_addr;
    s_blk_mem_flash_page.dina   <= s_page_ram_dina;
    s_blk_mem_flash_page.web(0) <= '0'; -- port b is read-only
    s_blk_mem_flash_page.addrb  <= p_db_reg_rx_in(cfb_flash_page_ram_address)(7 downto 0);
    s_blk_mem_flash_page.dinb   <= (others => '0');

    -- bits15:8=byte value, bits7:0=echoed address (1-cycle ram read latency vs
    -- the echoed address is invisible to VIO-paced polling -- same convention
    -- as stb_gbtx_reg_readback)
    p_page_ram_readback_out <= s_blk_mem_flash_page.doutb & p_db_reg_rx_in(cfb_flash_page_ram_address)(7 downto 0);
    -- bits5:0=fill count, bit6=full, bit7=empty
    p_fifo_status_out <= s_fifo_empty & s_fifo_full & std_logic_vector(to_unsigned(s_fifo_count, 6));

    ----------------------------------------------------------------
    -- outputs
    ----------------------------------------------------------------
    p_flash_control_out.do(0) <= s_si_out;
    p_flash_control_out.do(1) <= '0'; -- SO/IO1 is always input, value irrelevant
    p_flash_control_out.do(2) <= '1'; -- WP#/IO2 held inactive (high) at all times
    p_flash_control_out.do(3) <= '1'; -- HOLD#/RESET#/IO3 held inactive (high) at all times
    p_flash_control_out.dts   <= "0010"; -- IO3/IO2/IO0 driven, IO1(SO) input
    p_flash_control_out.fcsbo     <= s_cs_n;
    p_flash_control_out.fcsbts    <= '0'; -- always drive CS#
    p_flash_control_out.usrcclko  <= s_sck_out;
    p_flash_control_out.usrcclkts <= '0'; -- always drive SCK
    p_flash_control_out.di        <= (others => '0'); -- unused on this direction (io_box populates its own di)

    p_status_out <= (31 downto 21 => '0')
                     & s_op_latched                 -- bits 20:16 (widened from 19:16 for the 5-bit opcode)
                     & s_write_blocked              -- bit 15
                     & (14 downto 10 => '0')
                     & s_status_reg                 -- bits 9:2
                     & s_done & s_busy;             -- bit1, bit0
    p_rdata_out  <= s_rdata_reg;

    ----------------------------------------------------------------
    -- clock divider
    ----------------------------------------------------------------
    process(p_clknet_in.osc_clk40)
    begin
        if rising_edge(p_clknet_in.osc_clk40) then
            s_tick <= '0';
            if s_div_cnt = g_clk_div - 1 then
                s_div_cnt <= 0;
                s_tick    <= '1';
            else
                s_div_cnt <= s_div_cnt + 1;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- write fifo: push (via cdc'd toggle-bit edge) and pop (via s_fifo_pop_req,
    -- edge-detected -- see that signal's comment) both handled here, the only
    -- process driving s_fifo_mem/pointers/count. Runs every raw osc_clk40 cycle
    -- (not tick-gated) so a push is captured promptly regardless of the SPI
    -- clock divider.
    ----------------------------------------------------------------
    process(p_clknet_in.osc_clk40)
        variable v_push : std_logic;
        variable v_pop  : std_logic;
    begin
        if rising_edge(p_clknet_in.osc_clk40) then
            if p_master_reset_in = '1' then
                s_fifo_wr_ptr <= 0;
                s_fifo_rd_ptr <= 0;
                s_fifo_count  <= 0;
                s_push_toggle_sync1 <= '0';
                s_push_toggle_sync2 <= '0';
                s_push_toggle_last  <= '0';
                s_fifo_pop_req_last <= '0';
            else
                s_push_toggle_sync1 <= p_db_reg_rx_in(cfb_flash_fifo_push)(31);
                s_push_toggle_sync2 <= s_push_toggle_sync1;

                v_push := '0';
                if s_push_toggle_sync2 /= s_push_toggle_last then
                    s_push_toggle_last <= s_push_toggle_sync2;
                    if s_fifo_count < 32 then -- silently dropped if full; software
                        v_push := '1';        -- backs off using stb_flash_fifo_status
                    end if;
                end if;

                v_pop := '0';
                if s_fifo_pop_req = '1' and s_fifo_pop_req_last = '0' and s_fifo_count > 0 then
                    v_pop := '1';
                end if;
                s_fifo_pop_req_last <= s_fifo_pop_req;

                if v_push = '1' then
                    s_fifo_mem(s_fifo_wr_ptr) <= p_db_reg_rx_in(cfb_flash_fifo_addr) & p_db_reg_rx_in(cfb_flash_fifo_push)(7 downto 0);
                    if s_fifo_wr_ptr = 31 then
                        s_fifo_wr_ptr <= 0;
                    else
                        s_fifo_wr_ptr <= s_fifo_wr_ptr + 1;
                    end if;
                end if;

                if v_pop = '1' then
                    if s_fifo_rd_ptr = 31 then
                        s_fifo_rd_ptr <= 0;
                    else
                        s_fifo_rd_ptr <= s_fifo_rd_ptr + 1;
                    end if;
                end if;

                if v_push = '1' and v_pop = '1' then
                    s_fifo_count <= s_fifo_count; -- net unchanged
                elsif v_push = '1' then
                    s_fifo_count <= s_fifo_count + 1;
                elsif v_pop = '1' then
                    s_fifo_count <= s_fifo_count - 1;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- main FSM: internal s_sck toggles every tick and drives all FSM/MOSI
    -- timing (bit transitions/drive happen while s_sck is low, about to
    -- rise) -- same structure as db6_altera_jtag_driver.vhd's TCK/TDI/TDO
    -- handling. The *physical* clock pin runs one tick behind this (see
    -- s_sck_out above), which is what actually gives the flash real setup
    -- time on every bit, CS# included.
    ----------------------------------------------------------------
    process(p_clknet_in.osc_clk40)
        variable v_op_byte : std_logic_vector(7 downto 0);
    begin
        if rising_edge(p_clknet_in.osc_clk40) then

            if p_master_reset_in = '1' then
                s_state  <= ST_IDLE;
                s_sck    <= '0';
                s_sck_out <= '0';
                s_cs_n    <= '1';
                s_busy   <= '0';
                s_done   <= '0';
                s_burst_mode <= '0';
                s_fifo_pop_req <= '0';
                s_page_ram_wea <= '0';
                s_page_byte_cnt <= 0;
                s_page_sample_bit_cnt <= 0;
                s_page_ram_addr_cnt <= (others => '0');

            elsif s_tick = '1' then

                -- defaults, overridden below where needed -- both are one-tick
                -- pulses (see their declaration comments)
                s_fifo_pop_req <= '0';
                s_page_ram_wea <= '0';

                -- s_sck_out is a one-tick-delayed shadow of s_sck (see the signal's
                -- own comment above), read out to the physical pin instead of s_sck.
                -- Every MOSI bit (s_si_out) and FSM state change is driven by s_sck's
                -- *internal* phase, unchanged below -- s_sck_out lags it by exactly
                -- one tick, so by the time a real edge appears on USRCCLKO, the bit
                -- it's meant to sample has already been stable for a full tick, and
                -- CS# (asserted immediately, undelayed, in ST_ASSERT_CS) has already
                -- had a full tick of lead time before that first real edge too.
                -- DI (MISO) sampling below is gated on s_sck_out for the same reason:
                -- the flash only reacts after it sees the real (delayed) edge, so
                -- reading DI a further tick behind that edge (not the internal one)
                -- gives it time to respond.
                s_sck_out <= s_sck;
                s_sck     <= not s_sck;

                if s_sck = '0' then -- about to rise: this is where the fsm advances

                    case s_state is

                        when ST_IDLE =>
                            s_done <= '0';
                            s_busy <= '0';
                            s_cs_n  <= '1';
                            if s_cmd_start = '1' then
                                s_busy        <= '1';
                                s_op_latched  <= s_cmd_opcode;
                                s_shift_addr  <= s_cmd_address;
                                s_rdata_reg    <= (others => '0');
                                s_write_blocked <= '0';
                                s_burst_mode  <= '0'; -- manual command: never coalesced, unchanged one-shot behavior

                                case s_cmd_opcode is
                                    when c_op_read | c_op_fast_read | c_op_page_read =>
                                        s_has_address <= '1';
                                        if s_cmd_opcode = c_op_read then
                                            s_has_dummy <= '0';
                                        else
                                            s_has_dummy <= '1'; -- fast_read and page_read both take a dummy byte
                                        end if;
                                        s_is_write    <= '0';
                                        s_rdata_bytes <= to_integer(unsigned(s_cmd_length_sel)) + 1;
                                    when c_op_page_program =>
                                        s_has_address <= '1';
                                        s_has_dummy   <= '0';
                                        s_is_write    <= '1';
                                    when c_op_wrsr =>
                                        s_has_address <= '0';
                                        s_has_dummy   <= '0';
                                        s_is_write    <= '1';
                                    when c_op_sector_erase | c_op_block_erase =>
                                        s_has_address <= '1';
                                        s_has_dummy   <= '0';
                                        s_is_write    <= '0';
                                    when c_op_rdsr | c_op_rderp =>
                                        s_has_address <= '0';
                                        s_has_dummy   <= '0';
                                        s_is_write    <= '0';
                                        s_rdata_bytes <= 1;
                                    when c_op_rdid =>
                                        s_has_address <= '0';
                                        s_has_dummy   <= '0';
                                        s_is_write    <= '0';
                                        s_rdata_bytes <= 3;
                                    when others => -- wren/wrdi/chip_erase/reset_enable/reset/nop
                                        s_has_address <= '0';
                                        s_has_dummy   <= '0';
                                        s_is_write    <= '0';
                                end case;

                                -- write-protect floor: PAGE_PROGRAM below/at cfb_flash_write_floor is
                                -- rejected outright, and so is a SECTOR_ERASE/BLOCK_ERASE whose erase-
                                -- aligned block (s_erase_block_start) starts below/at the floor -- an
                                -- erase always wipes its whole aligned block, so checking the raw
                                -- commanded address alone would miss a block that starts at/below the
                                -- floor but was addressed with a byte above it. CHIP_ERASE has no
                                -- address to align/check, so it's all-or-nothing instead: permitted
                                -- only when the floor itself is 0 (i.e. firmware has explicitly
                                -- disabled write protection), rejected otherwise.
                                if s_cmd_opcode = c_op_nop then
                                    s_state <= ST_DONE;
                                elsif s_cmd_opcode = c_op_page_program and unsigned(s_cmd_address) <= unsigned(s_write_floor) then
                                    s_write_blocked <= '1';
                                    s_state <= ST_DONE;
                                elsif (s_cmd_opcode = c_op_sector_erase or s_cmd_opcode = c_op_block_erase)
                                      and unsigned(s_erase_block_start) <= unsigned(s_write_floor) then
                                    s_write_blocked <= '1';
                                    s_state <= ST_DONE;
                                elsif s_cmd_opcode = c_op_chip_erase and unsigned(s_write_floor) /= 0 then
                                    s_write_blocked <= '1';
                                    s_state <= ST_DONE;
                                else
                                    s_state <= ST_ASSERT_CS;
                                end if;

                            elsif s_fifo_empty = '0' then
                                -- auto-drain: no manual command pending and the write fifo
                                -- has entries -- dispatch a PAGE_PROGRAM burst sourced from
                                -- the fifo head instead of s_cmd_address/s_cmd_wdata (see
                                -- s_wdata_mux / s_burst_mode and ST_SHIFT_WDATA's coalescing
                                -- continuation below)
                                s_busy         <= '1';
                                s_op_latched   <= c_op_page_program;
                                s_shift_addr   <= s_fifo_head_addr;
                                s_burst_addr   <= s_fifo_head_addr;
                                s_burst_wdata  <= s_fifo_head_data;
                                s_burst_mode   <= '1';
                                s_write_blocked <= '0';
                                s_has_address  <= '1';
                                s_has_dummy    <= '0';
                                s_is_write     <= '1';
                                if unsigned(s_fifo_head_addr) <= unsigned(s_write_floor) then
                                    -- below/at the floor: drop this entry rather than retry it
                                    -- forever (it can never become writable without raising the
                                    -- floor), report write_blocked, and stay in ST_IDLE next tick
                                    s_write_blocked <= '1';
                                    s_fifo_pop_req  <= '1';
                                    s_state <= ST_DONE;
                                else
                                    s_state <= ST_ASSERT_CS;
                                end if;
                            end if;

                        when ST_ASSERT_CS =>
                            s_cs_n <= '0';
                            -- computed via a variable (not s_shift_out itself) so
                            -- s_si_out reflects the *new* opcode's msb immediately --
                            -- reading s_shift_out here would still see its stale
                            -- pre-assignment value this same cycle.
                            case s_op_latched is
                                when c_op_wren         => v_op_byte := c_spi_wren;
                                when c_op_wrdi         => v_op_byte := c_spi_wrdi;
                                when c_op_rdsr         => v_op_byte := c_spi_rdsr;
                                when c_op_read         => v_op_byte := c_spi_4read;
                                when c_op_fast_read    => v_op_byte := c_spi_4fastread;
                                when c_op_page_read    => v_op_byte := c_spi_4fastread;
                                when c_op_page_program => v_op_byte := c_spi_4pp;
                                when c_op_sector_erase => v_op_byte := c_spi_4se;
                                when c_op_block_erase  => v_op_byte := c_spi_4be;
                                when c_op_chip_erase   => v_op_byte := c_spi_chip_erase;
                                when c_op_rdid         => v_op_byte := c_spi_rdid;
                                when c_op_reset_enable  => v_op_byte := c_spi_reset_enable;
                                when c_op_reset         => v_op_byte := c_spi_reset;
                                when c_op_rderp         => v_op_byte := c_spi_rderp;
                                when c_op_clerp         => v_op_byte := c_spi_clerp;
                                when c_op_gbun          => v_op_byte := c_spi_gbun;
                                when c_op_wrsr           => v_op_byte := c_spi_wrsr;
                                when others            => v_op_byte := x"00";
                            end case;
                            s_shift_out <= v_op_byte;
                            s_bit_cnt   <= 0;
                            s_si_out    <= v_op_byte(7);
                            s_state     <= ST_SHIFT_OPCODE;

                        when ST_SHIFT_OPCODE =>
                            if s_bit_cnt = 7 then
                                if s_has_address = '1' then
                                    s_bit_cnt <= 0;
                                    s_si_out  <= s_shift_addr(31);
                                    s_state   <= ST_SHIFT_ADDRESS;
                                elsif s_is_write = '1' then
                                    s_bit_cnt <= 0;
                                    s_si_out  <= s_wdata_mux(7);
                                    s_state   <= ST_SHIFT_WDATA;
                                elsif s_op_latched = c_op_rdsr or s_op_latched = c_op_rdid or s_op_latched = c_op_rderp then
                                    s_byte_cnt <= 0;
                                    s_bit_cnt  <= 0;
                                    s_si_out   <= '0';
                                    s_state    <= ST_SHIFT_RDATA;
                                else
                                    s_state <= ST_DEASSERT_CS;
                                end if;
                            else
                                s_bit_cnt   <= s_bit_cnt + 1;
                                s_shift_out <= s_shift_out(6 downto 0) & '0';
                                s_si_out    <= s_shift_out(6);
                            end if;

                        when ST_SHIFT_ADDRESS =>
                            if s_bit_cnt = 31 then
                                if s_has_dummy = '1' then
                                    s_bit_cnt <= 0;
                                    s_si_out  <= '0';
                                    s_state   <= ST_SHIFT_DUMMY;
                                elsif s_is_write = '1' then
                                    s_bit_cnt <= 0;
                                    s_si_out  <= s_wdata_mux(7);
                                    s_state   <= ST_SHIFT_WDATA;
                                elsif s_op_latched = c_op_read or s_op_latched = c_op_fast_read then
                                    s_byte_cnt <= 0;
                                    s_bit_cnt  <= 0;
                                    s_si_out   <= '0';
                                    s_state    <= ST_SHIFT_RDATA;
                                else -- sector/block erase: no data phase
                                    s_state <= ST_DEASSERT_CS;
                                end if;
                            else
                                s_bit_cnt    <= s_bit_cnt + 1;
                                s_shift_addr <= s_shift_addr(30 downto 0) & '0';
                                s_si_out     <= s_shift_addr(30);
                            end if;

                        when ST_SHIFT_DUMMY =>
                            if s_bit_cnt = 7 then
                                s_byte_cnt <= 0;
                                s_bit_cnt  <= 0;
                                s_si_out   <= '0';
                                if s_op_latched = c_op_page_read then
                                    -- page_read breaks off into its own dedicated burst state
                                    -- instead of ST_SHIFT_RDATA (see header comment) -- the
                                    -- already-verified 1-4 byte fast_read path below is untouched
                                    s_page_byte_cnt <= 0;
                                    s_page_sample_bit_cnt <= 0;
                                    s_page_ram_addr_cnt <= (others => '0');
                                    s_state <= ST_PAGE_READ_BURST;
                                else
                                    s_state <= ST_SHIFT_RDATA;
                                end if;
                            else
                                s_bit_cnt <= s_bit_cnt + 1;
                            end if;

                        when ST_SHIFT_WDATA =>
                            if s_bit_cnt = 7 then
                                if s_burst_mode = '1' then
                                    -- coalescing continuation: pop the entry just written and,
                                    -- if the next queued entry is exactly +1 and still within
                                    -- the same 256-byte page, keep cs low and shift it straight
                                    -- out instead of deasserting -- see header comment
                                    s_fifo_pop_req <= '1';
                                    s_burst_addr <= std_logic_vector(unsigned(s_burst_addr) + 1);
                                    if s_fifo_has_next = '1'
                                       and s_fifo_next_addr = std_logic_vector(unsigned(s_burst_addr) + 1)
                                       and s_fifo_next_addr(31 downto 8) = s_burst_addr(31 downto 8) then
                                        s_burst_wdata <= s_fifo_next_data;
                                        s_bit_cnt <= 0;
                                        s_si_out  <= s_fifo_next_data(7);
                                    else
                                        s_state <= ST_DEASSERT_CS;
                                    end if;
                                else
                                    s_state <= ST_DEASSERT_CS;
                                end if;
                            else
                                s_bit_cnt <= s_bit_cnt + 1;
                                s_si_out  <= s_wdata_mux(6 - s_bit_cnt);
                            end if;

                        when ST_SHIFT_RDATA =>
                            -- readback is captured combinationally in the DI-sampling
                            -- process below and folded into s_rdata_reg there; this
                            -- state only walks the bit/byte counters.
                            if s_bit_cnt = 7 then
                                if s_byte_cnt = s_rdata_bytes - 1 then
                                    s_state <= ST_DEASSERT_CS;
                                else
                                    s_byte_cnt <= s_byte_cnt + 1;
                                    s_bit_cnt  <= 0;
                                end if;
                            else
                                s_bit_cnt <= s_bit_cnt + 1;
                            end if;

                        when ST_PAGE_READ_BURST =>
                            -- state-advance/completion tracking only -- the actual byte
                            -- capture and ram write happen in the di-sample block below,
                            -- on the same tick phase (see s_page_sample_bit_cnt and the
                            -- header comment for why these two counters stay in lockstep)
                            if s_bit_cnt = 7 then
                                if s_page_byte_cnt = 255 then
                                    s_state <= ST_DEASSERT_CS;
                                else
                                    s_page_byte_cnt <= s_page_byte_cnt + 1;
                                    s_bit_cnt <= 0;
                                end if;
                            else
                                s_bit_cnt <= s_bit_cnt + 1;
                            end if;

                        when ST_DEASSERT_CS =>
                            s_cs_n <= '1';
                            if s_op_latched = c_op_rdsr then
                                s_status_reg <= s_rdata_reg(7 downto 0);
                            end if;
                            s_state <= ST_DONE;

                        when ST_DONE =>
                            s_done <= '1';
                            s_busy <= '0';
                            if s_cmd_start = '0' then
                                s_done  <= '0';
                                s_state <= ST_IDLE;
                            end if;

                        when others =>
                            s_state <= ST_IDLE;

                    end case;

                end if;

                -- DI (MISO) sampling: gated on s_sck_out (the delayed, physically-
                -- driven clock), not the internal s_sck used for FSM/MOSI timing
                -- above -- see s_sck_out's declaration comment. s_sck_out='1' is
                -- true starting the tick right after a real rising edge appears on
                -- USRCCLKO, which is exactly when the flash's response to that edge
                -- is expected to be valid on DI.
                if s_sck_out = '1' and s_state = ST_SHIFT_RDATA then
                    s_rdata_reg <= s_rdata_reg(30 downto 0) & p_flash_control_in.di(1);
                end if;

                -- page-read burst: same di-sample phase as above, own byte-wide shift
                -- register and its own bit counter (independent of s_bit_cnt in the
                -- state-advance block above -- see header comment). Every 8th sample
                -- pulses s_page_ram_wea for one tick to commit the completed byte into
                -- blk_mem_flash_page at the running write address, then advances it.
                if s_sck_out = '1' and s_state = ST_PAGE_READ_BURST then
                    s_page_byte_reg <= s_page_byte_reg(6 downto 0) & p_flash_control_in.di(1);
                    if s_page_sample_bit_cnt = 7 then
                        s_page_sample_bit_cnt <= 0;
                        s_page_ram_wea     <= '1';
                        s_page_ram_wr_addr <= std_logic_vector(s_page_ram_addr_cnt);
                        s_page_ram_dina    <= s_page_byte_reg(6 downto 0) & p_flash_control_in.di(1);
                        s_page_ram_addr_cnt <= s_page_ram_addr_cnt + 1;
                    else
                        s_page_sample_bit_cnt <= s_page_sample_bit_cnt + 1;
                    end if;
                end if;

            end if;

        end if;
    end process;

end architecture;
