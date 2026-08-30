"""TileCal DB xADC analogue conversion LUTs and helpers."""

from __future__ import annotations

import re

# Resistor / shunt gain constants (from TileCal analysis scripts).
db_rg_2v5 = (1.0 / (((100000 / 124) + 1) * 0.002)) / (10000.0 / (20000 + 10000))
db_rg_3v3 = (1.0 / (((100000 / 124) + 1) * 0.002)) / (10000.0 / (20000 + 10000))
db_rg_0v95 = (1.0 / (((100000 / 200) + 1) * 0.002)) / (10000.0 / (10000 + 10000))
db_rg_1v2 = (1.0 / (1 + (100000 / 187))) * (1.0 / (10000.0 / (10000 + 10000))) * (1.0 / 0.002)
db_rg_1v8 = (1.0 / (((100000 / 124) + 1) * 0.002)) / (10000.0 / (20000 + 10000))
db_rg_1v5 = (1.0 / (1 + (100000 / 187))) * (1.0 / (10000.0 / (10000 + 10000))) * (1.0 / 0.002)
db_rg_1v0 = (1.0 / (1 + (100000 / 187))) * (1.0 / (10000.0 / (10000 + 10000))) * (1.0 / 0.002)

mb_rg_5v0n = 1.0 / (20 * 0.02)
mb_rg_5v0 = 1.0 / (20 * 0.02)
mb_rg_10v0 = 1.0 / 10
mb_rg_2v5 = 1.0 / (20 * 0.01)
mb_rg_1v8 = 1.0 / (20 * 0.02)
mb_rg_1v2 = 1.0 / (20 * 0.2)

LABELS = [
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
    "min_vram",
]

ADDRESSES = [
    0x00, 0x01, 0x02, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16,
    0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
    0x03, 0x04, 0x05, 0x06,
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
]

FA = [
    502.9098 / 65536,
    0.244 * 3 / 16,
    0.244 * 3 / 16,
    *([0.244 / 16] * 16),
    0.244 * 3 / 16,
    0.244 * 3 / 16,
    0.244 * 3 / 16,
    0.244 * 3 / 16,
    502.9098 / 65536,
    0.244 * 3 / 16,
    0.244 * 3 / 16,
    0.244 * 3 / 16,
    502.9098 / 65536,
    0.244 * 3 / 16,
    0.244 * 3 / 16,
    0.244 * 3 / 16,
]

FB = [
    -273.819,
    *([0.0] * 22),
    -273.819,
    0.0, 0.0, 0.0,
    -273.819,
    0.0, 0.0, 0.0,
]

FG = [
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
    1, 1, 1, 1,
    1, 1, 1, 1,
    1, 1, 1, 1,
]

DIMENSIONS = [
    "°C", "mV", "mV",
    *(["mV"] * 16),
    "mV", "mV", "mV", "mV",
    "°C", "mV", "mV", "mV",
    "°C", "mV", "mV", "mV",
]

FG_DIMENSIONS = [
    "°C", "mA", "mA",
    *(["mA"] * 16),
    "mV", "mV", "mV", "mV",
    "°C", "mV", "mV", "mV",
    "°C", "mV", "mV", "mV",
]

ADDR_TO_IDX = {addr: idx for idx, addr in enumerate(ADDRESSES)}


def is_xadc_addr_probe(name: str) -> bool:
    n = (name or "").lower()
    if "probe_in97" in n:
        return True
    return "xadc_channel" in n and "voltage" not in n


def is_xadc_val_probe(name: str) -> bool:
    n = (name or "").lower()
    if "probe_in98" in n:
        return True
    return "xadc_channel_voltage" in n

# Vivado hw_sysmon property names -> DRP address (lower 8 bits).
SYSMON_PROP_TO_ADDR: dict[str, int] = {
    "TEMPERATURE": 0x00,
    "VCCINT": 0x01,
    "VCCAUX": 0x02,
    "VP_VN": 0x03,
    "VCCBRAM": 0x06,
    "VBRAM": 0x06,
    "VRAM": 0x06,
    **{f"VAUX{i}": 0x10 + i for i in range(16)},
    **{f"VAUXP{i}_VAUXN{i}": 0x10 + i for i in range(16)},
    "MAX_TEMPERATURE": 0x20,
    "MAX_VCCAUX": 0x21,
    "MAX_VCCINT": 0x22,
    "MAX_VCCBRAM": 0x23,
    "MAX_VBRAM": 0x23,
    "MIN_TEMPERATURE": 0x24,
    "MIN_VCCAUX": 0x25,
    "MIN_VCCINT": 0x26,
    "MIN_VCCBRAM": 0x27,
    "MIN_VBRAM": 0x27,
}


def _parse_raw(value) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text in ("N/A", "—", "-"):
        return None
    try:
        if text.lower().startswith("0x"):
            return int(text, 16)
        if "." in text:
            return int(float(text))
        if re.search(r"[a-fA-F]", text):
            return int(text, 16)
        # Vivado VIO probe values are hex strings without a 0x prefix (≤4 digits).
        if re.fullmatch(r"[0-9]+", text) and len(text) <= 4:
            return int(text, 16)
        return int(text, 10)
    except (TypeError, ValueError):
        return None


def convert_channel(raw: int | None, idx: int) -> dict:
    """Apply TileCal LUT conversion for one channel index."""
    label = LABELS[idx]
    addr = ADDRESSES[idx]
    if raw is None:
        return {
            "index": idx,
            "label": label,
            "address": addr,
            "address_hex": f"0x{addr:02X}",
            "raw": None,
            "analog": None,
            "analog_unit": DIMENSIONS[idx].strip(),
            "current": None,
            "current_unit": FG_DIMENSIONS[idx].strip(),
            "has_current": FG[idx] != 1,
            "source": None,
        }

    data_eval = raw * FA[idx] + FB[idx]
    data_reeval = data_eval * FG[idx]
    has_current = FG[idx] != 1
    return {
        "index": idx,
        "label": label,
        "address": addr,
        "address_hex": f"0x{addr:02X}",
        "raw": raw,
        "analog": data_eval,
        "analog_unit": DIMENSIONS[idx].strip(),
        "current": data_reeval if has_current else None,
        "current_unit": FG_DIMENSIONS[idx].strip(),
        "has_current": has_current,
        "source": "unknown",
    }


def build_channels(raw_by_addr: dict[int, int], sources: dict[int, str] | None = None) -> list[dict]:
    """Build converted channel list in LUT order."""
    sources = sources or {}
    channels = []
    for idx, addr in enumerate(ADDRESSES):
        ch = convert_channel(raw_by_addr.get(addr), idx)
        ch["source"] = sources.get(addr)
        channels.append(ch)
    return channels


def _physical_to_raw(idx: int, value: float, prop: str) -> int:
    """Estimate 16-bit DRP code from a Vivado sysmon physical reading."""
    prop = prop.upper()
    if "TEMPERATURE" in prop:
        return int(round((value - FB[idx]) / FA[idx]))
    # Supply / aux channels: Vivado reports volts; LUT analog side is mV.
    data_eval_mV = value * 1000.0
    return int(round((data_eval_mV - FB[idx]) / FA[idx]))


def sysmon_to_raw_by_addr(readings: list[dict]) -> tuple[dict[int, int], dict[int, str]]:
    """Map hw_sysmon property rows to DRP addresses (16-bit raw codes)."""
    raw_by_addr: dict[int, int] = {}
    sources: dict[int, str] = {}
    for row in readings:
        prop = (row.get("property") or "").upper()
        if prop.endswith("_SCALE") or prop.endswith("_OFFSET"):
            continue
        addr = SYSMON_PROP_TO_ADDR.get(prop)
        if addr is None:
            continue
        idx = ADDR_TO_IDX.get(addr)
        if idx is None:
            continue
        text = str(row.get("value") or "").strip()
        if not text:
            continue
        try:
            if text.lower().startswith("0x"):
                raw = int(text, 16)
            elif "." in text:
                raw = _physical_to_raw(idx, float(text), prop)
            else:
                raw = int(text, 0)
        except (TypeError, ValueError):
            continue
        raw_by_addr[addr] = raw & 0xFFFF
        sources[addr] = f"sysmon:{prop}"
    return raw_by_addr, sources


def vio_xadc_snapshot(vios: dict) -> tuple[int | None, int | None, str | None]:
    """Extract live scan address + raw code from vio_clknet_status probe_in97/98."""
    addr_raw = None
    value_raw = None
    vio_name = None
    for _vio_key, probes in (vios or {}).items():
        addr_text = None
        val_text = None
        for probe in probes:
            name = (probe.get("probe") or "").lower()
            if is_xadc_addr_probe(name):
                addr_text = probe.get("value")
            elif is_xadc_val_probe(name):
                val_text = probe.get("value")
        if addr_text is not None or val_text is not None:
            vio_name = _vio_key
            addr_raw = _parse_raw(addr_text)
            value_raw = _parse_raw(val_text)
            break
    return addr_raw, value_raw, vio_name


def merge_vio_scan(raw_by_addr: dict[int, int], sources: dict[int, str],
                   addr: int | None, raw: int | None, vio_name: str | None) -> dict:
    """Overlay live VIO scan onto accumulated sysmon map."""
    if addr is None or raw is None:
        return {
            "address": addr,
            "address_hex": f"0x{addr:02X}" if addr is not None else None,
            "raw": raw,
            "vio": vio_name,
        }
    raw_by_addr[addr] = raw & 0xFFFF
    sources[addr] = f"vio:{vio_name or 'live'}"
    return {
        "address": addr,
        "address_hex": f"0x{addr:02X}",
        "raw": raw & 0xFFFF,
        "vio": vio_name,
    }
