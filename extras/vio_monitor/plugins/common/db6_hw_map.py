"""TileCal DB6 configbus registers + vio_db_debug probe names.

Mirrors ``db6_design_package.vhd`` (``c_sfp_*``, ``cfb_*``, ``stb_*``,
``t_debug_control.flash``) and the 2026-09-12 staging nets in
``db6v5_top.vhd`` / ``bin/*/db6v5_top.ltx`` (``s_vio_dbg_*`` and
``s_clknet_debug_control[flash][...]``).

Legacy hierarchical names (``s_sfp_interface[ddm]...``, flat
``flash_manual_*``) are kept as aliases so older LTX files still match.
"""

from __future__ import annotations

from typing import Any

# ---------------------------------------------------------------------------
# SFF-8472 A2h DDM  (c_sfp_* / t_sfp_regs / stb_sfp_ddm_*)
# Each stb register packs side 0 in bits 15:0 and side 1 in bits 31:16.
# ---------------------------------------------------------------------------

C_SFP = {
    "temperature": 0,
    "vcc": 1,
    "tx_bias_current": 2,
    "tx_power": 3,
    "rx_power": 4,
    "laser_temperature": 5,
    "tec_current": 6,
}

# LTX leaf token used in s_vio_dbg_ddm_<token>_q<side>
_DDM_LTX_TOKEN = {
    "temperature": "temp",
    "vcc": "vcc",
    "tx_bias_current": "txbias",
    "tx_power": "txpower",
    "rx_power": "rxpower",
    "laser_temperature": "lasertemp",
    "tec_current": "teccurrent",
}

DDM_FIELDS: list[dict[str, Any]] = [
    {
        "id": "temperature",
        "label": "Temperature",
        "index": 0,
        "stb": "stb_sfp_ddm_temperature",
        "stb_index": 26,
        "stb_addr": 0x342,
        "kind": "signed_temp",
        "unit": "°C",
        "spec": "16-bit signed, LSB = 1/256 °C",
    },
    {
        "id": "vcc",
        "label": "Supply voltage",
        "index": 1,
        "stb": "stb_sfp_ddm_vcc",
        "stb_index": 27,
        "stb_addr": 0x343,
        "kind": "unsigned_scale",
        "scale": 100e-6,
        "unit": "V",
        "spec": "16-bit unsigned, LSB = 100 µV",
    },
    {
        "id": "tx_bias_current",
        "label": "TX bias current",
        "index": 2,
        "stb": "stb_sfp_ddm_tx_bias_current",
        "stb_index": 28,
        "stb_addr": 0x344,
        "kind": "unsigned_scale",
        "scale": 2e-6,
        "unit": "A",
        "display_unit": "µA",
        "display_scale": 1e6,
        "spec": "16-bit unsigned, LSB = 2 µA",
    },
    {
        "id": "tx_power",
        "label": "TX output power",
        "index": 3,
        "stb": "stb_sfp_ddm_tx_power",
        "stb_index": 29,
        "stb_addr": 0x345,
        "kind": "optical_power",
        "scale": 0.1e-6,
        "unit": "mW",
        "spec": "16-bit unsigned, LSB = 0.1 µW",
    },
    {
        "id": "rx_power",
        "label": "RX optical power",
        "index": 4,
        "stb": "stb_sfp_ddm_rx_power",
        "stb_index": 30,
        "stb_addr": 0x346,
        "kind": "optical_power",
        "scale": 0.1e-6,
        "unit": "mW",
        "spec": "16-bit unsigned, LSB = 0.1 µW",
    },
    {
        "id": "laser_temperature",
        "label": "Laser temperature",
        "index": 5,
        "stb": "stb_sfp_ddm_laser_temperature",
        "stb_index": 31,
        "stb_addr": 0x347,
        "kind": "signed_temp",
        "unit": "°C",
        "spec": "16-bit signed, LSB = 1/256 °C (DWDM optional)",
    },
    {
        "id": "tec_current",
        "label": "TEC current",
        "index": 6,
        "stb": "stb_sfp_ddm_tec_current",
        "stb_index": 32,
        "stb_addr": 0x348,
        "kind": "signed_scale",
        "scale": 0.1,
        "unit": "mA",
        "spec": "16-bit signed, LSB = 0.1 mA (+ = cooling)",
    },
]

DDM_BY_ID = {f["id"]: f for f in DDM_FIELDS}
DDM_BY_INDEX = {f["index"]: f for f in DDM_FIELDS}
DDM_TOKEN_TO_ID = {token: fid for fid, token in _DDM_LTX_TOKEN.items()}


def ddm_ltx_name(field_id: str, side: int) -> str:
    token = _DDM_LTX_TOKEN[field_id]
    return f"s_vio_dbg_ddm_{token}_q{side}"


def ddm_legacy_names(field_id: str, side: int) -> list[str]:
    idx = C_SFP[field_id]
    return [
        f"s_sfp_interface[ddm][{side}][{idx}]",
        f"s_sfp_interface[ddm][{side}][c_sfp_{field_id}]",
        f"s_sfp_interface.ddm({side})(c_sfp_{field_id})",
    ]


def ddm_all_names(field_id: str, side: int) -> list[str]:
    return [ddm_ltx_name(field_id, side), *ddm_legacy_names(field_id, side)]


DDM_CLASSIFY_PATTERNS = (
    "*s_vio_dbg_ddm*",
    "*s_sfp_interface*ddm*",
)

# ---------------------------------------------------------------------------
# SFP+ I2C block-RAM  (cfb_sfp_reg_address / stb_sfp_reg_readback)
# ---------------------------------------------------------------------------

SFP_I2C = {
    "cfb": "cfb_sfp_reg_address",
    "cfb_index": 4,
    "cfb_addr": 0x004,
    "stb": "stb_sfp_reg_readback",
    "stb_index": 25,
    "stb_addr": 0x01A,
    "addr_out": {
        0: "s_vio_dbg_sfp_addr_out_q0",
        1: "s_vio_dbg_sfp_addr_out_q1",
    },
    "addr_echo": {
        0: "s_vio_dbg_sfp_addr_echo0",
        1: "s_vio_dbg_sfp_addr_echo1",
    },
    "data_in": {
        0: "s_vio_dbg_sfp_shadow_q0",
        1: "s_vio_dbg_sfp_shadow_q1",
    },
    "legacy_addr": {
        0: "s_sfp_reg_address_vio[0]",
        1: "s_sfp_reg_address_vio[1]",
    },
    "legacy_data": {
        0: "s_sfp_ku_mgt[sfp_tx_register][0]",
        1: "s_sfp_ku_mgt[sfp_tx_register][1]",
    },
}


def sfp_i2c_addr_names(side: int) -> list[str]:
    return [SFP_I2C["addr_out"][side], SFP_I2C["legacy_addr"][side]]


def sfp_i2c_data_names(side: int) -> list[str]:
    return [SFP_I2C["data_in"][side], SFP_I2C["legacy_data"][side]]


# ---------------------------------------------------------------------------
# IS25LP256 flash  (cfb_flash_* / stb_flash_* / t_debug_control.flash)
# Command: bit31=start, bits28:24=opcode (5 bits), bits9:8=length_sel, bits7:0=wdata
# Status:  bit0=busy, bit1=done, bits9:2=RDSR, bit15=write_blocked, bits20:16=opcode
# ---------------------------------------------------------------------------

FLASH_CFB = {
    "address": {"name": "cfb_flash_address", "index": 18, "addr": 0x012},
    "command": {"name": "cfb_flash_command", "index": 19, "addr": 0x013},
    "write_floor": {"name": "cfb_flash_write_floor", "index": 20, "addr": 0x014},
    "page_ram_address": {"name": "cfb_flash_page_ram_address", "index": 21, "addr": 0x015},
    "fifo_addr": {"name": "cfb_flash_fifo_addr", "index": 22, "addr": 0x016},
    "fifo_push": {"name": "cfb_flash_fifo_push", "index": 23, "addr": 0x017},
}

FLASH_STB = {
    "status": {"name": "stb_flash_status", "index": 37, "addr": 0x34D},
    "rdata": {"name": "stb_flash_rdata", "index": 38, "addr": 0x34E},
    "page_ram_readback": {"name": "stb_flash_page_ram_readback", "index": 39, "addr": 0x34F},
    "fifo_status": {"name": "stb_flash_fifo_status", "index": 40, "addr": 0x350},
}

FLASH_PROBES: dict[str, dict[str, Any]] = {
    "address_probe": {
        "ltx": "s_clknet_debug_control[flash][manual_address]",
        "legacy": ["s_clknet_debug_control[flash_manual_address]"],
        "cfb": FLASH_CFB["address"],
    },
    "command_probe": {
        "ltx": "s_clknet_debug_control[flash][manual_command]",
        "legacy": ["s_clknet_debug_control[flash_manual_command]"],
        "cfb": FLASH_CFB["command"],
    },
    "floor_enable_probe": {
        "ltx": "s_clknet_debug_control[flash][manual_write_floor_enable]",
        "legacy": ["s_clknet_debug_control[flash_manual_write_floor_enable]"],
    },
    "floor_probe": {
        "ltx": "s_clknet_debug_control[flash][manual_write_floor]",
        "legacy": ["s_clknet_debug_control[flash_manual_write_floor]"],
        "cfb": FLASH_CFB["write_floor"],
    },
    "status_probe": {
        "ltx": "s_vio_dbg_flash_status",
        "legacy": ["s_system_management_interface[flash_status]"],
        "stb": FLASH_STB["status"],
    },
    "rdata_probe": {
        "ltx": "s_vio_dbg_flash_rdata",
        "legacy": ["s_system_management_interface[flash_rdata]"],
        "stb": FLASH_STB["rdata"],
    },
}

# Internal opcodes (cfb_flash_command bits 28:24) — db7_is25lp256_driver.vhd
FLASH_OP_NOP = 0x00
FLASH_OP_WREN = 0x01
FLASH_OP_WRDI = 0x02
FLASH_OP_RDSR = 0x03
FLASH_OP_READ = 0x04
FLASH_OP_FAST_READ = 0x05
FLASH_OP_PAGE_PROGRAM = 0x06
FLASH_OP_SECTOR_ERASE = 0x07
FLASH_OP_BLOCK_ERASE = 0x08
FLASH_OP_CHIP_ERASE = 0x09
FLASH_OP_RDID = 0x0A
FLASH_OP_RESET_ENABLE = 0x0B
FLASH_OP_RESET = 0x0C
FLASH_OP_PAGE_READ = 0x0D
FLASH_OP_RDERP = 0x0E
FLASH_OP_CLERP = 0x0F
FLASH_OP_GBUN = 0x10
FLASH_OP_WRSR = 0x11

FLASH_OP_NAMES = {
    FLASH_OP_WREN: "WREN",
    FLASH_OP_WRDI: "WRDI",
    FLASH_OP_RDSR: "RDSR",
    FLASH_OP_READ: "READ",
    FLASH_OP_FAST_READ: "FAST_READ",
    FLASH_OP_PAGE_PROGRAM: "PAGE_PROGRAM",
    FLASH_OP_SECTOR_ERASE: "SECTOR_ERASE",
    FLASH_OP_BLOCK_ERASE: "BLOCK_ERASE",
    FLASH_OP_CHIP_ERASE: "CHIP_ERASE",
    FLASH_OP_RDID: "RDID",
    FLASH_OP_RESET_ENABLE: "RESET_ENABLE",
    FLASH_OP_RESET: "RESET",
    FLASH_OP_PAGE_READ: "PAGE_READ",
    FLASH_OP_RDERP: "RDERP",
    FLASH_OP_CLERP: "CLERP",
    FLASH_OP_GBUN: "GBUN",
    FLASH_OP_WRSR: "WRSR",
}

FLASH_CMD_START_BIT = 31
FLASH_CMD_OPCODE_SHIFT = 24
FLASH_CMD_OPCODE_MASK = 0x1F
FLASH_CMD_LENGTH_SHIFT = 8
FLASH_CMD_LENGTH_MASK = 0x3
FLASH_STATUS_OP_SHIFT = 16
FLASH_STATUS_OP_MASK = 0x1F


def flash_probe_names(key: str) -> list[str]:
    spec = FLASH_PROBES[key]
    return [spec["ltx"], *spec.get("legacy", [])]


# ---------------------------------------------------------------------------
# Live xADC VIO scan (optional — dropped from vio_db_debug; hw_sysmon remains)
# ---------------------------------------------------------------------------

XADC_LIVE_PROBES = {
    "xadc_channel_voltage": {
        "ltx": "s_system_management_interface[xadc_channel_voltage]",
        "legacy": ["*xadc_channel_voltage*", "probe_in98", "*probe_in98*"],
        "optional": True,
    },
    "xadc_channel": {
        "ltx": "s_system_management_interface[xadc_channel]",
        "legacy": ["*xadc_channel*", "probe_in97", "*probe_in97*"],
        "optional": True,
    },
}


def xadc_live_names(key: str) -> list[str]:
    spec = XADC_LIVE_PROBES[key]
    return [spec["ltx"], *spec.get("legacy", [])]


# ---------------------------------------------------------------------------
# ADC data readout debug (t_debug_control.data_readout / t_data_readout_debug_status)
# probe_out17: trigger(0) | sample_index(4:1) | channel_select(7:5)
# probe_out18: bcr_number
# probe_in74: captured ; probe_in75/76/77: hg/lg/fc muxed 14-bit sample
# ---------------------------------------------------------------------------

DATA_READOUT_SAMPLE_COUNT = 16
DATA_READOUT_CHANNEL_COUNT = 6
DATA_READOUT_ADC_BITS = 14
DATA_READOUT_SAMPLE_BITS = 12

DATA_READOUT_PROBES: dict[str, dict[str, Any]] = {
    "trigger_probe": {
        "ltx": "s_clknet_debug_control[data_readout][trigger]",
        "legacy": ["probe_out17[0]"],
    },
    "sample_index_probe": {
        "ltx": "s_clknet_debug_control[data_readout][sample_index]",
        "legacy": ["probe_out17[4:1]", "probe_out17[1:4]"],
    },
    "channel_select_probe": {
        "ltx": "s_clknet_debug_control[data_readout][channel_select]",
        "legacy": ["probe_out17[7:5]", "probe_out17[5:7]"],
    },
    "bcr_number_probe": {
        "ltx": "s_clknet_debug_control[data_readout][bcr_number]",
        "legacy": ["probe_out18"],
    },
    "captured_probe": {
        "ltx": "s_data_readout_debug_status[captured]",
        "legacy": ["probe_in74[0]", "probe_in74"],
    },
    "hg_data_probe": {
        "ltx": "s_data_readout_debug_status[hg_data]",
        "legacy": ["probe_in75"],
    },
    "lg_data_probe": {
        "ltx": "s_data_readout_debug_status[lg_data]",
        "legacy": ["probe_in76"],
    },
    "fc_data_probe": {
        "ltx": "s_data_readout_debug_status[fc_data]",
        "legacy": ["probe_in77"],
    },
    "packed_control_probe": {
        "ltx": "probe_out17",
        "legacy": [],
        "optional": True,
    },
}


def data_readout_probe_names(key: str) -> list[str]:
    spec = DATA_READOUT_PROBES[key]
    return [spec["ltx"], *spec.get("legacy", [])]


# ---------------------------------------------------------------------------
# Alias expansion
# ---------------------------------------------------------------------------

def _alias_table() -> dict[str, list[str]]:
    table: dict[str, list[str]] = {}

    def _add(names: list[str]) -> None:
        uniq = [n for n in names if n]
        for name in uniq:
            table.setdefault(name, [])
            for other in uniq:
                if other not in table[name]:
                    table[name].append(other)

    for field in DDM_FIELDS:
        for side in (0, 1):
            _add(ddm_all_names(field["id"], side))
    for side in (0, 1):
        _add(sfp_i2c_addr_names(side))
        _add(sfp_i2c_data_names(side))
    for key in FLASH_PROBES:
        _add(flash_probe_names(key))
    for key in DATA_READOUT_PROBES:
        if key == "packed_control_probe":
            continue
        _add(data_readout_probe_names(key))
    for key in XADC_LIVE_PROBES:
        _add(xadc_live_names(key))
    return table


_ALIASES = _alias_table()


def probe_aliases(name: str) -> list[str]:
    """Known LTX/legacy names for the same net, including *name* itself."""
    if not name:
        return []
    return list(_ALIASES.get(name, [name]))
