# Copied from dataloggers/python3v7/db_lib.py and aligned with
# vhdl/db6_design_package.vhd (relative to the Flask app) for the db7_flask UI.
# Old names are kept as aliases where the index is unchanged.

# daughterboard configuration registers (c_db_reg_rx / cfb_*)
cfg_register_zero = 0
cfb_register_zero = 0
cfb_mb_adc_config = 1
cfb_mb_phase_config = 2
cfb_cis_config = 3
cfb_sfp_reg_address = 4
cfb_cs_command = 4  # old name
cfb_integrator_interval = 5
cfb_tx_reg_address = 6
cfb_bc_num_offset = 6  # old name
cfb_sem_control = 7
cfb_tx_control = 8
cfb_gbtx_reg_config = 9
cfb_strobe_lenght = 10
cfb_db_control = 10  # old name
cfb_loopback = 11
cfb_db_fw_version = 12
cfb_db_cfg_fw_version = 12
cfb_db_advanced_reg_value = 12  # old name
cfb_db_debug = 13
cfb_db_reg_mask = 14
cfb_strobe_reg = 15
cfb_mb_boundary_scan_reg_address = 16
cfb_gbtx_reg_readback_address = 17
cfb_flash_address = 18
cfb_flash_command = 19
cfb_flash_write_floor = 20
cfb_flash_page_ram_address = 21
cfb_flash_fifo_addr = 22
cfb_flash_fifo_push = 23
bc_number = 4
cfb_wr_strobe = 17  # unused in current VHDL LUT

# leftover advanced / ADC names (not in current c_db_reg_rx_lut)
adv_cfg_gty_txdiffctrl = 18
adv_cfg_gty_txpostcursor = 19
adv_cfg_gty_txprecursor = 20
adv_cfg_gty_txmaincursor = 21
adc_register_config = 26
adc_readout_idelay3_0 = 27
adc_readout_idelay3_1 = 28
adc_readout_idelay3_2 = 29
adc_readout_idelay3_3 = 30
adc_readout_idelay3_4 = 31
adc_readout_idelay3_5 = 32

#configbus and dataformat offsets
fpga_side_offset=12
md_offset=28

lut_xadc_address_labels = [
"db_temperature", 
"db_vccint(0.9v)",
"db_vccaux(1.8v)",
"db_mon_0.95v(vaux0)",
"db_mon_2.5v(vaux1)",
"db_sense_3(vaux2)",
"db_mon_1.5v(vaux3)",
"db_sense_2(vaux04)",
"db_mon_1.0v(vaux5)",
"db_sense_1(vaux6)",
"mb_mon_-5v(vaux7)",
"db_mon_1.8v(vaux8)",
"db_mon_1.2v(vaux9)",
"mb_mon_+5v(vaux10)",
"db_mon_3.3v(vaux11)",
"mb_mon_1.8v(vaux12)",
"mb_mon_10v(vaux13)",
"mb_mon_1.2v(vaux14)",
"mb_mon_2.5v(vaux15)",
"vp_vn",
"vp_ref",
"vn_ref",
"vram",
"max_temp",
"max_vccout",
"max_vccint",
"max_vram",
"min_temp",
"min_vccout",
"min_vccint",
"min_vram"
]


lut_xadc_address = [
0x00,
0x01,
0x02,
0x10,
0x11,
0x12,
0x13,
0x14,
0x15,
0x16,
0x17,
0x18,
0x19,
0x1a,
0x1b,
0x1c,
0x1d,
0x1e,
0x1f,
0x03,
0x04,
0x05,
0x06,
0x20,
0x21,
0x22,
0x23,
0x24,
0x25,
0x26,
0x27]

lut_xadc_fa=[
502.9098/65536,
0.244*3/16,
0.244*3/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244/16,
0.244*3/16,
0.244*3/16,
0.244*3/16,
0.244*3/16,
502.9098/65536,
0.244*3/16,
0.244*3/16,
0.244*3/16,
502.9098/65536,
0.244*3/16,
0.244*3/16,
0.244*3/16
]

lut_xadc_fb=[-273.819,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
-273.819,
0,
0,
0,
-273.819,
0,
0,
0]


#db_rg_2v5=(1./((100000/(200))+1)*0.002)
db_rg_2v5=(1./(((100000/(124))+1)*0.002)) / (10000./(20000+10000))
#db_rg_3v3=(1./((100000/(560))+1)*0.002)
db_rg_3v3=(1./(((100000/(124))+1)*0.002)) / (10000./(20000+10000))
#db_rg_0v95=(1./((100000/(750))+1)*0.002)
db_rg_0v95=(1./(((100000/(200))+1)*0.002)) / (10000./(10000+10000))
#db_rg_1v2=(1./((100000/(750))+1)*0.002)
db_rg_1v2= (1./(1+(100000/187))) * (1./(10000./(10000+10000))) * (1./0.002)
#db_rg_1v8=(1./((100000/(560))+1)*0.002)
db_rg_1v8=(1./(((100000/(124))+1)*0.002)) / (10000./(20000+10000))
#db_rg_1v5=(1./((100000/(560))+1)*0.002)
db_rg_1v5= (1./(1+(100000/187))) * (1./(10000./(10000+10000))) * (1./0.002)
#db_rg_1v0=(1./((100000/(560))+1)*0.002)
db_rg_1v0= (1./(1+(100000/187))) * (1./(10000./(10000+10000))) * (1./0.002)


mb_rg_5v0n=1./(20*0.02)
mb_rg_5v0=1./(20*0.02)
mb_rg_10v0=1./10
mb_rg_2v5=1./(20*0.01)
mb_rg_1v8=1./(20*0.02)
mb_rg_1v2=1./(20*0.2)


lut_xadc_fg=[
1,
1,
1,
db_rg_0v95,
db_rg_2v5,
1,
db_rg_1v5,
1,
db_rg_1v0,
1,
mb_rg_5v0n,
db_rg_1v8,
db_rg_1v2,
mb_rg_5v0,
db_rg_3v3,
mb_rg_1v8,
mb_rg_10v0,
mb_rg_1v2,
mb_rg_2v5,
1,
1,
1,
1,
1,
1,
1,
1,
1,
1,
1,
1
]

lut_xadc_dimensions= [
" C",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" mV",
" C",
" mV",
" mV",
" mV",
" C",
" mV",
" mV",
" mV"
]

lut_xadc_fg_dimensions= [
" C",
" mV",
" mV",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mA",
" mV",
" mV",
" mV",
" mV",
" C",
" mV",
" mV",
" mV",
" C",
" mV",
" mV",
" mV"
]


# c_db_reg_rx_lut
lut_cfgbus_address = [
    0x000,  # cfb_register_zero
    0x001,  # cfb_mb_adc_config
    0x002,  # cfb_mb_phase_config
    0x121,  # cfb_cis_config
    0x004,  # cfb_sfp_reg_address
    0x115,  # cfb_integrator_interval
    0x006,  # cfb_tx_reg_address
    0x007,  # cfb_sem_control
    0x008,  # cfb_tx_control
    0x009,  # cfb_gbtx_reg_config
    0x00A,  # cfb_strobe_lenght
    0xFFF,  # cfb_loopback
    0x00C,  # cfb_db_fw_version
    0x00D,  # cfb_db_debug
    0x00E,  # cfb_db_reg_mask
    0x00F,  # cfb_strobe_reg
    0x010,  # cfb_mb_boundary_scan_reg_address
    0x011,  # cfb_gbtx_reg_readback_address
    0x012,  # cfb_flash_address
    0x013,  # cfb_flash_command
    0x014,  # cfb_flash_write_floor
    0x015,  # cfb_flash_page_ram_address
    0x016,  # cfb_flash_fifo_addr
    0x017,  # cfb_flash_fifo_push
    0x018,  # cfb_db_inject_pulse
]

lut_cfgbus_address_labels = [
    "cfb_register_zero",
    "cfb_mb_adc_config",
    "cfb_mb_phase_config",
    "cfb_cis_config",
    "cfb_sfp_reg_address",
    "cfb_integrator_interval",
    "cfb_tx_reg_address",
    "cfb_sem_control",
    "cfb_tx_control",
    "cfb_gbtx_reg_config",
    "cfb_strobe_lenght",
    "cfb_loopback",
    "cfb_db_fw_version",
    "cfb_db_debug",
    "cfb_db_reg_mask",
    "cfb_strobe_reg",
    "cfb_mb_boundary_scan_reg_address",
    "cfb_gbtx_reg_readback_address",
    "cfb_flash_address",
    "cfb_flash_command",
    "cfb_flash_write_floor",
    "cfb_flash_page_ram_address",
    "cfb_flash_fifo_addr",
    "cfb_flash_fifo_push",
    "cfb_db_inject_pulse",
]


c_stb_mb = 0
c_stb_db_fwversion = 1
c_stb_mb_q0 = 2
c_stb_mb_q1 = 3
c_stb_db_debug = 4
c_stb_db_xadc = 5
c_stb_sem = 6
c_stb_loopback = 7
c_stb_gbtxa_reg = 8
c_stb_sfp0_reg = 9
c_stb_sfp1_reg = 10
c_stb_pgood_reg = 11
c_stb_tmr = 12
c_stb_db_status = 13
c_stb_adc_readout_status = 14
c_stb_adc_readout_counter_status = 15
c_stb_global_date = 16
c_stb_global_time = 17
# 2026-09-12 VHDL: Hog/XML ver/sha registers removed; DNA onward shifted down by 10.
c_stb_dna_2 = 18
c_stb_dna_1 = 19
c_stb_dna_0 = 20
c_stb_running_time_status = 21
c_stb_integrator_status = 22
c_stb_mb_jtag_id_q0 = 23
c_stb_mb_jtag_id_q1 = 24
c_stb_sfp_reg_readback = 25
c_stb_sfp_ddm_temperature = 26
c_stb_sfp_ddm_vcc = 27
c_stb_sfp_ddm_tx_bias_current = 28
c_stb_sfp_ddm_tx_power = 29
c_stb_sfp_ddm_rx_power = 30
c_stb_sfp_ddm_laser_temperature = 31
c_stb_sfp_ddm_tec_current = 32
c_stb_mb_boundary_scan_status = 33
c_stb_mb_boundary_scan_reg_readback = 34
c_stb_gbtx_reg_readback = 35
c_stb_gbtx_config_readback = 36
c_stb_flash_status = 37
c_stb_flash_rdata = 38
c_stb_flash_page_ram_readback = 39
c_stb_flash_fifo_status = 40
c_stb_sem_error_counters = 41
c_stb_sem_injected_errors = 42

# c_db_reg_tx_lut (surviving registers keep their original hex bus addresses)
lut_tx_address = [
    0x001, 0xF0F, 0x012, 0x013, 0xD0D, 0x015, 0x016, 0xFFF,
    0x330, 0x340, 0x341, 0xAFF, 0x00C, 0x00D, 0x00E, 0x00F,
    0x100, 0x101,
    0x10C, 0x10D, 0x10E, 0x10F, 0x00A, 0x018, 0x019, 0x01A,
    0x342, 0x343, 0x344, 0x345, 0x346, 0x347, 0x348, 0x349,
    0x34A, 0x34B, 0x34C, 0x34D, 0x34E, 0x34F, 0x350,
    0x102, 0x103, 0x351,
]

lut_tx_address_labels = [
    "stb_mb",
    "stb_db_fwversion",
    "stb_mb_q0",
    "stb_mb_q1",
    "stb_db_debug",
    "stb_db_xadc",
    "stb_sem",
    "stb_loopback",
    "stb_gbtxa_reg",
    "stb_sfp0_reg",
    "stb_sfp1_reg",
    "stb_pgood_reg",
    "stb_tmr",
    "stb_db_status",
    "stb_adc_readout_status",
    "stb_adc_readout_counter_status",
    "stb_global_date",
    "stb_global_time",
    "stb_dna_2",
    "stb_dna_1",
    "stb_dna_0",
    "stb_running_time_status",
    "stb_integrator_status",
    "stb_mb_jtag_id_q0",
    "stb_mb_jtag_id_q1",
    "stb_sfp_reg_readback",
    "stb_sfp_ddm_temperature",
    "stb_sfp_ddm_vcc",
    "stb_sfp_ddm_tx_bias_current",
    "stb_sfp_ddm_tx_power",
    "stb_sfp_ddm_rx_power",
    "stb_sfp_ddm_laser_temperature",
    "stb_sfp_ddm_tec_current",
    "stb_mb_boundary_scan_status",
    "stb_mb_boundary_scan_reg_readback",
    "stb_gbtx_reg_readback",
    "stb_gbtx_config_readback",
    "stb_flash_status",
    "stb_flash_rdata",
    "stb_flash_page_ram_readback",
    "stb_flash_fifo_status",
    "stb_sem_error_counters",
    "stb_sem_injected_errors",
    "stb_db_inject_ram_rdata",
]


#configuration constants
c_db_sm_reset_bit = 0;
c_mb1_reset_bit = 1;
c_mb0_reset_bit = 2;
c_master_reset_bit = 3;
c_clknet_reset_bit = 4;
c_commbus_reset_bit = 5;
c_cfgbus_reset_bit = 6;
c_adc_readout_reset_bit = 7;
c_sem_reset_bit = 8;
c_adc_config_reset_bit = 9;  
c_cis_reset_bit  = 10;  
c_integrator_reset_bit = 11;
c_gbt_reset_bit = 12; 
c_gth_reset_bit = 13;
c_adc_channel_reset_bit = 14;
c_gth_reset_tx_pll_and_datapath_bit = 15;
c_gth_reset_tx_datapath_bit = 16;
c_gth_buffbypass_tx_reset_bit = 17;
c_gth_buffbypass_tx_start_use_bit = 18;
c_adc_readout_reset_channel_0_bit= 19;
c_adc_readout_reset_channel_1_bit= 20;
c_adc_readout_reset_channel_2_bit= 21;
c_adc_readout_reset_channel_3_bit= 22;
c_adc_readout_reset_channel_4_bit= 23;
c_adc_readout_reset_channel_5_bit= 24;
c_gbt_ch0_reset_bit= 25; 
c_gbt_ch1_reset_bit= 26;
c_gth_ch0_reset_bit= 27; 
c_gth_ch1_reset_bit= 28;
c_gbt_encoder_reset_bit= 29;

c_db_debug_cis_tp_clk_mux = 9;
c_db_debug_adc_clk_mux = 10;
c_db_debug_gbtx_deskew_clk_mux = 8;
c_db_debug_mb_adc_config_mode = 11;
c_db_debug_mb_adc_config_trigger = 12;


#status constants
c_db_status_bcr_locked_bit =0;

c_adc_readout_status_adc0_missalignment_bit =1;
c_adc_readout_status_adc1_missalignment_bit =2;
c_adc_readout_status_adc2_missalignment_bit =3;
c_adc_readout_status_adc3_missalignment_bit =4;
c_adc_readout_status_adc4_missalignment_bit =5;
c_adc_readout_status_adc5_missalignment_bit =6;
c_db_status_mb_tx_collission_q0_bit =1;
c_db_status_mb_tx_collission_q1_bit =2;

#pgood
c_pgood_db_1v2_bit = 0;        
c_pgood_db_5v0_bit = 1;
c_pgood_db_1v5_bit = 2;
c_pgood_db_3v3_bit = 3;
c_pgood_db_0v95_bit = 4;
c_pgood_db_1v0_bit = 5;
c_pgood_db_1v8_bit = 6;
c_pgood_db_2v5_bit = 7;
c_pgood_mb_3v3_bit = 8;
c_pgood_mb_5v0_n_bit = 9;
c_pgood_mb_5v0_bit = 10;
c_pgood_mb_1v8_bit = 11;
c_pgood_mb_1v2_bit = 12;
c_pgood_mb_2v5_bit = 13;
c_pgood_mb_10v0_bit = 14; 


lut_pgood_labels = [
"pgood_db_1v2",
"pgood_db_5v0",
"pgood_db_1v5",
"pgood_db_3v3",
"pgood_db_0v95",
"pgood_db_1v0",
"pgood_db_1v8",
"pgood_db_2v5",
"pgood_mb_3v3",
"pgood_mb_5v0_n",
"pgood_mb_5v0",
"pgood_mb_1v8",
"pgood_mb_1v2",
"pgood_mb_2v5",
"pgood_mb_10v0"
]


#useful stuff

char_line_up = '\033[1A'
char_line_clear = '\x1b[2K'

def format_number(number):
    """Parse decimal / 0x hex / 0b binary the way db7_modregval.py does."""
    if isinstance(number, int):
        return int(number)
    number_str = str(number).strip().lower()
    if number_str.startswith("0b"):
        return int(number_str, 2)
    if number_str.startswith("0x"):
        return int(number_str, 16)
    return int(number_str, 10)


def _field(name, lsb, msb=None, note=""):
    # Allow _field("foo", 3, "comment") as a single-bit field with a note.
    if isinstance(msb, str) and not note:
        note = msb
        msb = None
    if msb is None:
        msb = lsb
    return {"name": name, "lsb": int(lsb), "msb": int(msb), "note": note}


# ---------------------------------------------------------------------------
# Configbus (RX) -- structured map for the Flask UI (c_db_reg_rx_lut)
# ---------------------------------------------------------------------------

CFB_FIELDS = {
    "cfb_sfp_reg_address": [
        _field("side0_addr", 0, 6, "SFP+ A2h BRAM port-b address, side 0"),
        _field("side1_addr", 8, 14, "SFP+ A2h BRAM port-b address, side 1"),
    ],
    "cfb_sem_control": [
        _field("sem_cap_rel", 28),
        _field("sem_cap_gnt", 29),
        _field("sem_command_strobe", 30),
        _field("sem_20bit_word_mux", 31),
    ],
    "cfb_tx_control": [
        _field("gbt_encoder_tx_fc_lg", 0),
        _field("gbt_encoder_tx_fc_hg", 1),
    ],
    "cfb_gbtx_reg_config": [
        _field("gbtx_i2c_rw", 26, note="'0' write, '1' read"),
        _field("gbtx_trigger_i2c", 27),
        _field("gbtx_default_config", 28),
        _field("gbtx_control", 29),
        _field("gbtxa_configsel", 30),
        _field("gbtxb_configsel", 31),
    ],
    "cfb_db_debug": [
        _field("gbtx_deskew_clk_mux", 8),
        _field("cis_tp_clk_mux", 9),
        _field("adc_clk_mux", 10),
        _field("mb_adc_config_mode", 11),
        _field("mb_adc_config_trigger", 12),
        _field("gbt_txword_phase", 13),
        _field("cfgbus_strobe_persist", 14),
        _field("gbt_cdc_phase_array", 14, 15, "GBT bank CDC phase"),
        _field("gbtx_i2c_speed", 16, 23),
        _field("skip_main_sm", 24),
        _field("mb_jtag_read_enable_q0", 25),
        _field("mb_jtag_read_enable_q1", 26),
        _field("mb_boundary_scan_enable_q0", 27),
        _field("mb_boundary_scan_enable_q1", 28),
        _field("mb_boundary_scan_ir_only_q0", 29),
        _field("mb_boundary_scan_ir_only_q1", 30),
    ],
    "cfb_strobe_reg": [
        _field("dbmaster_reset", 0),
        _field("mb1_reset", 1),
        _field("mb0_reset", 2),
        _field("master_reset", 3),
        _field("clknet_reset", 4),
        _field("commbus_reset", 5),
        _field("cfgbus_reset", 6),
        _field("adc_readout_reset", 7),
        _field("sem_reset", 8),
        _field("adc_config_reset", 9),
        _field("cis_reset", 10),
        _field("integrator_reset", 11),
        _field("gbt_reset", 12),
        _field("gth_reset", 13),
        _field("adc_channel_reset", 14),
        _field("gth_reset_tx_pll_and_datapath", 15),
        _field("gth_reset_tx_datapath", 16),
        _field("gth_buffbypass_tx_reset", 17),
        _field("gth_buffbypass_tx_start_use", 18),
        _field("adc_readout_reset_ch0", 19),
        _field("adc_readout_reset_ch1", 20),
        _field("adc_readout_reset_ch2", 21),
        _field("adc_readout_reset_ch3", 22),
        _field("adc_readout_reset_ch4", 23),
        _field("adc_readout_reset_ch5", 24),
        _field("gbt_ch0_reset", 25),
        _field("gbt_ch1_reset", 26),
        _field("gth_ch0_reset", 27),
        _field("gth_ch1_reset", 28),
        _field("gbt_encoder_reset", 29),
        _field("fpga_hard_reset", 31),
    ],
    "cfb_mb_boundary_scan_reg_address": [
        _field("side0_addr", 0, 6, "companion FPGA Q0 BRAM port-b address"),
        _field("side1_addr", 8, 14, "companion FPGA Q1 BRAM port-b address"),
    ],
    "cfb_gbtx_reg_readback_address": [
        _field("gbtx_addr", 0, 8),
    ],
    "cfb_flash_command": [
        _field("wdata", 0, 7, "page-program byte"),
        _field("length_sel", 8, 9, "1-4 bytes"),
        _field("opcode", 24, 28),
        _field("start", 31, note="level-held handshake"),
    ],
    "cfb_flash_page_ram_address": [
        _field("page_ram_addr", 0, 7),
    ],
    "cfb_flash_fifo_addr": [
        _field("fifo_target_addr", 0, 31, "staged before cfb_flash_fifo_push"),
    ],
    "cfb_flash_fifo_push": [
        _field("data_byte", 0, 7),
        _field("push_toggle", 31, note="flip to push {fifo_addr, data}"),
    ],
    "cfb_db_inject_pulse": [
        _field("enable", 0, note="ORed with the VIO inject enable"),
        _field("ram_we", 1, note="flip to write ram_wdata at ram_addr"),
        _field("ram_wdata", 2, 15, "signed pedestal-relative sample"),
        _field("ram_addr", 16, 27, "bunch address 0..3563"),
    ],
}

CFB_REGS = []
for _i, (_addr, _label) in enumerate(zip(lut_cfgbus_address, lut_cfgbus_address_labels)):
    CFB_REGS.append({
        "index": _i,
        "name": _label,
        "hw_addr": _addr,
        "bus": "rx",
        "writable": True,
        "note": "",
        "fields": CFB_FIELDS.get(_label, []),
    })

_CFB_NOTES = {
    "cfb_register_zero": "Zero / unused",
    "cfb_mb_adc_config": "Mainboard ADC configuration",
    "cfb_mb_phase_config": "Mainboard deskew / phase config",
    "cfb_cis_config": "CIS configuration",
    "cfb_sfp_reg_address": "SFP+ A2h BRAM port-b address: bits 6:0 side 0, bits 14:8 side 1",
    "cfb_integrator_interval": "Integrator interval (default 0xA)",
    "cfb_tx_reg_address": "Selects which TX/status register is presented",
    "cfb_sem_control": "SEM IP control (strobe / CAP / word mux)",
    "cfb_tx_control": "GBT encoder TX FC HG/LG bits",
    "cfb_gbtx_reg_config": "GBTx I2C / config-select control",
    "cfb_strobe_lenght": "Configbus strobe length",
    "cfb_loopback": "Loopback test register",
    "cfb_db_fw_version": "Daughterboard firmware version (c_fw_version)",
    "cfb_db_debug": "Debug muxes, GBTx I2C speed, JTAG / boundary-scan enables",
    "cfb_db_reg_mask": "Write mask applied by DB_Write_Val before the data write",
    "cfb_strobe_reg": "Per-block resets (pulse the corresponding bit)",
    "cfb_mb_boundary_scan_reg_address": "Companion FPGA boundary-scan RAM address, per side",
    "cfb_gbtx_reg_readback_address": "GBTx register readback RAM port-b address (bits 8:0)",
    "cfb_flash_address": "IS25LP256 32-bit byte address",
    "cfb_flash_command": "Flash opcode / length / wdata / start handshake",
    "cfb_flash_write_floor": "Write-protect floor (default 0x01000000 = half of 32 MB)",
    "cfb_flash_page_ram_address": "256-byte page-read buffer port-b address",
    "cfb_flash_fifo_addr": "Write-FIFO target address staged before push",
    "cfb_flash_fifo_push": "Write-FIFO push: bit31 toggle, bits7:0 data byte",
    "cfb_db_inject_pulse": "ADC inject enable (bit0), RAM write toggle, wdata and address",
}
for _reg in CFB_REGS:
    _reg["note"] = _CFB_NOTES.get(_reg["name"], "")


# ---------------------------------------------------------------------------
# TX / status -- structured map for the Flask UI (c_db_reg_tx_lut)
# ---------------------------------------------------------------------------

TX_FIELDS = {
    "stb_sem": [
        _field("heartbeat", 0),
        _field("initialization", 1),
        _field("observation", 2),
        _field("correction", 3),
        _field("classification", 4),
        _field("injection", 5),
        _field("essential", 6),
        _field("detect_only", 7),
        _field("command_busy", 8),
        _field("monitor_txfull", 9),
        _field("uncorrectable", 10),
        _field("diagnostic_scan", 11),
        _field("command_strobe", 12),
        _field("cap_gnt", 13),
        _field("cap_rel", 14),
        _field("cap_req", 15),
        _field("correctable_errors", 16, 31, "truncated 16-bit count"),
    ],
    "stb_db_status": [
        _field("bcr_locked", 0),
        _field("mb_tx_collision_q0", 1),
        _field("mb_tx_collision_q1", 2),
        _field("db_leds", 16, 19),
        _field("md_number", 20, 23),
    ],
    "stb_adc_readout_status": [
        _field("adc_config_done", 0),
        _field("adc0_missalign", 1),
        _field("adc1_missalign", 2),
        _field("adc2_missalign", 3),
        _field("adc3_missalign", 4),
        _field("adc4_missalign", 5),
        _field("adc5_missalign", 6),
        _field("adc0_missed_lock", 7),
        _field("adc1_missed_lock", 8),
        _field("adc2_missed_lock", 9),
        _field("adc3_missed_lock", 10),
        _field("adc4_missed_lock", 11),
        _field("adc5_missed_lock", 12),
        _field("adc0_locked", 13),
        _field("adc1_locked", 14),
        _field("adc2_locked", 15),
        _field("adc3_locked", 16),
        _field("adc4_locked", 17),
        _field("adc5_locked", 18),
        _field("adc0_phase_offset", 19),
        _field("adc1_phase_offset", 20),
        _field("adc2_phase_offset", 21),
        _field("adc3_phase_offset", 22),
        _field("adc4_phase_offset", 23),
        _field("adc5_phase_offset", 24),
    ],
    "stb_sfp0_reg": [
        _field("mod_los", 0),
        _field("mod_abs", 1),
        _field("tx_fault", 2),
    ],
    "stb_sfp1_reg": [
        _field("mod_los", 0),
        _field("mod_abs", 1),
        _field("tx_fault", 2),
    ],
    "stb_pgood_reg": [
        _field(name, i) for i, name in enumerate(lut_pgood_labels)
    ] + [
        _field("side", 27),
        _field("switches", 28, 31),
    ],
    "stb_integrator_status": [
        _field("mb_integrator_latency", 0, 15),
    ],
    "stb_sfp_reg_readback": [
        _field("side0_addr_echo", 0, 6),
        _field("side1_addr_echo", 8, 14),
        _field("side0_data", 16, 23),
        _field("side1_data", 24, 31),
    ],
    "stb_sfp_ddm_temperature": [
        _field("side0", 0, 15, "SFF-8472, signed / 256 degC"),
        _field("side1", 16, 31),
    ],
    "stb_sfp_ddm_vcc": [
        _field("side0", 0, 15, "SFF-8472, 100 uV / LSB"),
        _field("side1", 16, 31),
    ],
    "stb_sfp_ddm_tx_bias_current": [
        _field("side0", 0, 15, "SFF-8472, 2 uA / LSB"),
        _field("side1", 16, 31),
    ],
    "stb_sfp_ddm_tx_power": [
        _field("side0", 0, 15, "SFF-8472, 0.1 uW / LSB"),
        _field("side1", 16, 31),
    ],
    "stb_sfp_ddm_rx_power": [
        _field("side0", 0, 15, "SFF-8472, 0.1 uW / LSB"),
        _field("side1", 16, 31),
    ],
    "stb_sfp_ddm_laser_temperature": [
        _field("side0", 0, 15),
        _field("side1", 16, 31),
    ],
    "stb_sfp_ddm_tec_current": [
        _field("side0", 0, 15),
        _field("side1", 16, 31),
    ],
    "stb_mb_boundary_scan_status": [
        _field("msel_q0", 0, 2),
        _field("msel_q1", 3, 5),
        _field("clk_present_q0", 6, 12),
        _field("clk_present_q1", 13, 19),
        _field("done_q0", 20),
        _field("done_q1", 21),
    ],
    "stb_mb_boundary_scan_reg_readback": [
        _field("side0_addr_echo", 0, 6),
        _field("side1_addr_echo", 8, 14),
        _field("side0_data", 16, 23),
        _field("side1_data", 24, 31),
    ],
    "stb_gbtx_reg_readback": [
        _field("addr_echo", 0, 8),
        _field("read_byte", 9, 16, "actual I2C readback"),
    ],
    "stb_gbtx_config_readback": [
        _field("addr_echo", 0, 8),
        _field("write_byte", 9, 16, "intended / shadow write value"),
    ],
    "stb_flash_status": [
        _field("busy", 0),
        _field("done", 1),
        _field("rdsr", 2, 9, "last RDSR status byte"),
        _field("write_blocked", 15, note="see cfb_flash_write_floor"),
        _field("opcode_echo", 16, 19),
    ],
    "stb_flash_page_ram_readback": [
        _field("addr_echo", 0, 7),
        _field("data_byte", 8, 15),
    ],
    "stb_flash_fifo_status": [
        _field("fill_count", 0, 5, "0-32"),
        _field("full", 6),
        _field("empty", 7),
    ],
    "stb_sem_error_counters": [
        _field("total_errors", 0, 15, "truncated 16-bit count"),
        _field("uncorrectable_errors", 16, 31, "truncated 16-bit count"),
    ],
    "stb_sem_injected_errors": [
        _field("injected_errors", 0, 30, "truncated 31-bit count"),
        _field("sem_fatal_error", 31),
    ],
    "stb_db_inject_ram_rdata": [
        _field("ram_rdata", 0, 13, "port-b word at the commanded address"),
        _field("active", 14, note="injection is overriding HG/LG"),
        _field("word_active", 15, 28, "live injected word this cycle"),
    ],
}

_TX_NOTES = {
    "stb_mb": "Mainboard word",
    "stb_db_fwversion": "DB firmware version",
    "stb_mb_q0": "Mainboard Q0",
    "stb_mb_q1": "Mainboard Q1",
    "stb_db_debug": "Debug snapshot",
    "stb_db_xadc": "XADC muxed sample",
    "stb_sem": "SEM status + truncated correctable_errors[15:0]",
    "stb_loopback": "Loopback readback",
    "stb_gbtxa_reg": "GBTx A register",
    "stb_sfp0_reg": "SFP0 pin status (LOS/ABS/FAULT)",
    "stb_sfp1_reg": "SFP1 pin status (LOS/ABS/FAULT)",
    "stb_pgood_reg": "Power-good + side/switches",
    "stb_tmr": "TMR flags",
    "stb_db_status": "BCR lock, collisions, LEDs, MD number",
    "stb_adc_readout_status": "ADC lock / missalignment / phase",
    "stb_adc_readout_counter_status": "ADC readout counters",
    "stb_global_date": "Hog date ddmmyyyy (hex decimal digits)",
    "stb_global_time": "Hog time 00hhmmss",
    "stb_dna_2": "Device DNA [95:64]",
    "stb_dna_1": "Device DNA [63:32]",
    "stb_dna_0": "Device DNA [31:0]",
    "stb_running_time_status": "Uptime in seconds (hexadecimal count)",
    "stb_integrator_status": "Integrator latency / status",
    "stb_mb_jtag_id_q0": "Companion FPGA JTAG ID Q0",
    "stb_mb_jtag_id_q1": "Companion FPGA JTAG ID Q1",
    "stb_sfp_reg_readback": "SFP BRAM readback (addr echo + byte)",
    "stb_sfp_ddm_temperature": "SFP DDM temperature, both sides",
    "stb_sfp_ddm_vcc": "SFP DDM VCC, both sides",
    "stb_sfp_ddm_tx_bias_current": "SFP DDM TX bias, both sides",
    "stb_sfp_ddm_tx_power": "SFP DDM TX power, both sides",
    "stb_sfp_ddm_rx_power": "SFP DDM RX power, both sides",
    "stb_sfp_ddm_laser_temperature": "SFP DDM laser temperature, both sides",
    "stb_sfp_ddm_tec_current": "SFP DDM TEC current (DWDM only)",
    "stb_mb_boundary_scan_status": "Companion FPGA MSEL / clk / DONE",
    "stb_mb_boundary_scan_reg_readback": "Boundary-scan RAM readback (addr echo + byte)",
    "stb_gbtx_reg_readback": "GBTx I2C actual readback",
    "stb_gbtx_config_readback": "GBTx intended/shadow write value",
    "stb_flash_status": "IS25LP256 busy/done/RDSR/blocked",
    "stb_flash_rdata": "Last flash READ/RDID data",
    "stb_flash_page_ram_readback": "Page-buffer RAM readback",
    "stb_flash_fifo_status": "Flash write FIFO fill/full/empty",
    "stb_sem_error_counters": "SEM total_errors[15:0] + uncorrectable_errors[15:0] (truncated)",
    "stb_sem_injected_errors": "SEM injected_errors[30:0] + sem_fatal_error",
    "stb_db_inject_ram_rdata": "Inject RAM readback, active flag, live injected word",
}

TX_REGS = []
for _i, (_addr, _label) in enumerate(zip(lut_tx_address, lut_tx_address_labels)):
    TX_REGS.append({
        "index": _i,
        "name": _label,
        "hw_addr": _addr,
        "bus": "tx",
        "writable": False,
        "note": _TX_NOTES.get(_label, ""),
        "fields": TX_FIELDS.get(_label, []),
    })


# ---------------------------------------------------------------------------
# XADC -- db7_modregval.py --list xadc  (DRP addresses, read as 0xA00 | addr)
# ---------------------------------------------------------------------------

XADC_REGS = []
for _i, (_addr, _label) in enumerate(zip(lut_xadc_address, lut_xadc_address_labels)):
    XADC_REGS.append({
        "index": _i,
        "name": _label,
        "hw_addr": 0xA00 | _addr,
        "drp_addr": _addr,
        "bus": "xadc",
        "writable": False,
        "note": "XADC DRP 0x{:02X}, read as 0x{:03X}".format(_addr, 0xA00 | _addr),
        "fields": [],
        "unit": lut_xadc_dimensions[_i] if _i < len(lut_xadc_dimensions) else "",
        "fa": lut_xadc_fa[_i] if _i < len(lut_xadc_fa) else 1.0,
        "fb": lut_xadc_fb[_i] if _i < len(lut_xadc_fb) else 0.0,
        "fg": lut_xadc_fg[_i] if _i < len(lut_xadc_fg) else 1.0,
        "fg_unit": lut_xadc_fg_dimensions[_i] if _i < len(lut_xadc_fg_dimensions) else "",
    })


REGS_BY_BUS = {"rx": CFB_REGS, "tx": TX_REGS, "xadc": XADC_REGS}


def find_register(bus, spec):
    """Resolve a register by index, name, or hardware address."""
    regs = REGS_BY_BUS.get(bus) or []
    if spec is None or spec == "":
        return None

    if isinstance(spec, int):
        for reg in regs:
            if reg["index"] == spec:
                return dict(reg)
        for reg in regs:
            if reg["hw_addr"] == spec:
                return dict(reg)
        return {
            "index": spec,
            "name": "(raw)",
            "hw_addr": spec,
            "bus": bus,
            "writable": bus == "rx",
            "note": "Not in db6_design_package LUT",
            "fields": [],
        }

    spec_str = str(spec).strip()
    lowered = spec_str.lower()
    for reg in regs:
        if reg["name"].lower() == lowered:
            return dict(reg)

    try:
        if spec_str.lower().startswith("0x") or spec_str.lower().startswith("0b"):
            number = int(spec_str, 0)
        else:
            number = int(spec_str, 10)
    except (TypeError, ValueError):
        return None

    return find_register(bus, number)


def decode_fields(reg, value):
    decoded = []
    if not reg:
        return decoded
    value = int(value) & 0xFFFFFFFF
    for field in reg.get("fields") or []:
        lsb = int(field["lsb"])
        msb = int(field["msb"])
        width = msb - lsb + 1
        mask = (1 << width) - 1
        raw = (value >> lsb) & mask
        decoded.append({
            "name": field["name"],
            "lsb": field["lsb"],
            "msb": field["msb"],
            "value": raw,
            "hex": "0x{:X}".format(raw),
            "note": field.get("note") or "",
        })
    return decoded


def _s16(word):
    word = int(word) & 0xFFFF
    if word >= 0x8000:
        word -= 0x10000
    return word


def decode_value(reg, value):
    """Human-readable extras (SFP DDM, XADC)."""
    extras = {}
    if not reg:
        return extras
    name = reg.get("name") or ""
    value = int(value) & 0xFFFFFFFF
    lo = value & 0xFFFF
    hi = (value >> 16) & 0xFFFF

    if name == "stb_running_time_status":
        extras["seconds"] = "{} s".format(value)
        days = value // 86400
        hours = (value % 86400) // 3600
        minutes = (value % 3600) // 60
        secs = value % 60
        extras["elapsed"] = "{}d {:02d}:{:02d}:{:02d}".format(days, hours, minutes, secs)
    elif name == "stb_sem":
        extras["correctable_errors"] = str(hi)
    elif name == "stb_sem_error_counters":
        extras["total_errors"] = str(lo)
        extras["uncorrectable_errors"] = str(hi)
    elif name == "stb_sem_injected_errors":
        extras["injected_errors"] = str(value & 0x7FFFFFFF)
        extras["sem_fatal_error"] = str((value >> 31) & 1)
    elif name == "stb_sfp_ddm_temperature" or name == "stb_sfp_ddm_laser_temperature":
        extras["side0"] = "{:.2f} C".format(_s16(lo) / 256.0)
        extras["side1"] = "{:.2f} C".format(_s16(hi) / 256.0)
    elif name == "stb_sfp_ddm_vcc":
        extras["side0"] = "{:.3f} V".format(lo * 100e-6)
        extras["side1"] = "{:.3f} V".format(hi * 100e-6)
    elif name == "stb_sfp_ddm_tx_bias_current":
        extras["side0"] = "{:.3f} mA".format(lo * 2e-3)
        extras["side1"] = "{:.3f} mA".format(hi * 2e-3)
    elif name in ("stb_sfp_ddm_tx_power", "stb_sfp_ddm_rx_power"):
        extras["side0"] = "{:.3f} uW".format(lo * 0.1)
        extras["side1"] = "{:.3f} uW".format(hi * 0.1)
    elif name == "stb_sfp_ddm_tec_current":
        extras["side0"] = "{:.2f} mA".format(_s16(lo) * 0.1)
        extras["side1"] = "{:.2f} mA".format(_s16(hi) * 0.1)
    elif reg.get("bus") == "xadc":
        raw = value
        phys = raw * float(reg.get("fa") or 1.0) + float(reg.get("fb") or 0.0)
        scaled = phys * float(reg.get("fg") or 1.0)
        extras["physical"] = "{:.2f}{}".format(phys, reg.get("unit") or "")
        extras["scaled"] = "{:.2f}{}".format(scaled, reg.get("fg_unit") or "")
    return extras


def public_register_map():
    """JSON-serialisable register catalogue for the UI."""
    def slim(reg):
        item = {
            "index": reg["index"],
            "name": reg["name"],
            "hw_addr": reg["hw_addr"],
            "hw_addr_hex": "0x{:03X}".format(reg["hw_addr"]),
            "bus": reg["bus"],
            "writable": bool(reg.get("writable")),
            "note": reg.get("note") or "",
            "fields": reg.get("fields") or [],
        }
        if "unit" in reg:
            item["unit"] = reg["unit"]
        return item

    return {
        "source": "vhdl/db6_design_package.vhd",
        "rx": [slim(r) for r in CFB_REGS],
        "tx": [slim(r) for r in TX_REGS],
        "xadc": [slim(r) for r in XADC_REGS],
    }


