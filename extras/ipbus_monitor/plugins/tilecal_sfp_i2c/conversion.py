"""SFF-8472 Rev 12.4 A2h register map and internal-calibration conversions.

Firmware stores the fixed 128-byte A2h diagnostic region (bytes 0-127) in BRAM.
Values are decoded as internally calibrated (the usual SFP+ case).
"""

from __future__ import annotations

import math
import struct
from typing import Any

# (start, end_inclusive, name, kind) — kind drives conversion of the 16-bit MSB/LSB pair
# or of a single status/flag byte.
_A2H_MAP: tuple[tuple[int, int, str, str], ...] = (
    (0, 1, "Temp High Alarm", "signed_temp"),
    (2, 3, "Temp Low Alarm", "signed_temp"),
    (4, 5, "Temp High Warning", "signed_temp"),
    (6, 7, "Temp Low Warning", "signed_temp"),
    (8, 9, "Voltage High Alarm", "vcc"),
    (10, 11, "Voltage Low Alarm", "vcc"),
    (12, 13, "Voltage High Warning", "vcc"),
    (14, 15, "Voltage Low Warning", "vcc"),
    (16, 17, "Bias High Alarm", "tx_bias"),
    (18, 19, "Bias Low Alarm", "tx_bias"),
    (20, 21, "Bias High Warning", "tx_bias"),
    (22, 23, "Bias Low Warning", "tx_bias"),
    (24, 25, "TX Power High Alarm", "optical_power"),
    (26, 27, "TX Power Low Alarm", "optical_power"),
    (28, 29, "TX Power High Warning", "optical_power"),
    (30, 31, "TX Power Low Warning", "optical_power"),
    (32, 33, "RX Power High Alarm", "optical_power"),
    (34, 35, "RX Power Low Alarm", "optical_power"),
    (36, 37, "RX Power High Warning", "optical_power"),
    (38, 39, "RX Power Low Warning", "optical_power"),
    (40, 41, "Laser Temp High Alarm", "signed_temp"),
    (42, 43, "Laser Temp Low Alarm", "signed_temp"),
    (44, 45, "Laser Temp High Warning", "signed_temp"),
    (46, 47, "Laser Temp Low Warning", "signed_temp"),
    (48, 49, "TEC Current High Alarm", "tec_current"),
    (50, 51, "TEC Current Low Alarm", "tec_current"),
    (52, 53, "TEC Current High Warning", "tec_current"),
    (54, 55, "TEC Current Low Warning", "tec_current"),
    (56, 59, "Rx_PWR(4) cal", "ieee754"),
    (60, 63, "Rx_PWR(3) cal", "ieee754"),
    (64, 67, "Rx_PWR(2) cal", "ieee754"),
    (68, 71, "Rx_PWR(1) cal", "ieee754"),
    (72, 75, "Rx_PWR(0) cal", "ieee754"),
    (76, 77, "Tx_I Slope", "fixed_slope"),
    (78, 79, "Tx_I Offset", "signed_raw"),
    (80, 81, "Tx_PWR Slope", "fixed_slope"),
    (82, 83, "Tx_PWR Offset", "signed_raw"),
    (84, 85, "T Slope", "fixed_slope"),
    (86, 87, "T Offset", "signed_raw"),
    (88, 89, "V Slope", "fixed_slope"),
    (90, 91, "V Offset", "signed_raw"),
    (92, 94, "Reserved", "bytes"),
    (95, 95, "CC_DMI checksum", "checksum"),
    (96, 97, "Temperature", "signed_temp"),
    (98, 99, "Vcc", "vcc"),
    (100, 101, "TX Bias", "tx_bias"),
    (102, 103, "TX Power", "optical_power"),
    (104, 105, "RX Power", "optical_power"),
    (106, 107, "Laser Temp / Wavelength", "signed_temp"),
    (108, 109, "TEC Current", "tec_current"),
    (110, 110, "Status/Control", "status_110"),
    (111, 111, "Reserved", "byte"),
    (112, 112, "Alarm Flags", "alarm_112"),
    (113, 113, "Alarm Flags", "alarm_113"),
    (114, 114, "Tx Input EQ control", "nibble_eq"),
    (115, 115, "Rx Out Emphasis control", "nibble_eq"),
    (116, 116, "Warning Flags", "warn_116"),
    (117, 117, "Warning Flags", "warn_117"),
    (118, 119, "Ext Status/Control", "bytes"),
    (120, 126, "Vendor Specific", "bytes"),
    (127, 127, "Table Select", "byte"),
)

_STATUS_110 = (
    (7, "TX Disable State"),
    (6, "Soft TX Disable"),
    (5, "RS(1) State"),
    (4, "Rate_Select / RS(0)"),
    (3, "Soft Rate_Select"),
    (2, "TX Fault State"),
    (1, "Rx_LOS State"),
    (0, "Data_Not_Ready"),
)

_ALARM_112 = (
    (7, "Temp High Alarm"),
    (6, "Temp Low Alarm"),
    (5, "Vcc High Alarm"),
    (4, "Vcc Low Alarm"),
    (3, "TX Bias High Alarm"),
    (2, "TX Bias Low Alarm"),
    (1, "TX Power High Alarm"),
    (0, "TX Power Low Alarm"),
)

_ALARM_113 = (
    (7, "RX Power High Alarm"),
    (6, "RX Power Low Alarm"),
    (5, "Laser Temp High Alarm"),
    (4, "Laser Temp Low Alarm"),
    (3, "TEC Current High Alarm"),
    (2, "TEC Current Low Alarm"),
    (1, "Reserved Alarm"),
    (0, "Reserved Alarm"),
)

_WARN_116 = (
    (7, "Temp High Warning"),
    (6, "Temp Low Warning"),
    (5, "Vcc High Warning"),
    (4, "Vcc Low Warning"),
    (3, "TX Bias High Warning"),
    (2, "TX Bias Low Warning"),
    (1, "TX Power High Warning"),
    (0, "TX Power Low Warning"),
)

_WARN_117 = (
    (7, "RX Power High Warning"),
    (6, "RX Power Low Warning"),
    (5, "Laser Temp High Warning"),
    (4, "Laser Temp Low Warning"),
    (3, "TEC Current High Warning"),
    (2, "TEC Current Low Warning"),
    (1, "Reserved Warning"),
    (0, "Reserved Warning"),
)


def _signed16(raw: int) -> int:
    raw &= 0xFFFF
    return raw - 0x10000 if raw >= 0x8000 else raw


def _u16(msb: int, lsb: int) -> int:
    return ((msb & 0xFF) << 8) | (lsb & 0xFF)


def _bits_set(raw: int, labels: tuple[tuple[int, str], ...]) -> str:
    active = [name for bit, name in labels if (raw >> bit) & 1]
    return ", ".join(active) if active else "none"


def _optical_text(raw: int) -> str:
    mw = (raw & 0xFFFF) * 0.1e-3  # 0.1 µW / LSB → mW
    if mw > 0:
        dbm = 10.0 * math.log10(mw)
        return f"{mw:.4f} mW ({dbm:.2f} dBm)"
    return "0 mW (— dBm)"


def _decode_kind(kind: str, bytes_: list[int]) -> str:
    if kind == "signed_temp":
        value = _signed16(_u16(bytes_[0], bytes_[1])) / 256.0
        return f"{value:.2f} °C"
    if kind == "vcc":
        value = _u16(bytes_[0], bytes_[1]) * 100e-6
        return f"{value:.4f} V ({value * 1e3:.1f} mV)"
    if kind == "tx_bias":
        ua = _u16(bytes_[0], bytes_[1]) * 2.0
        return f"{ua:.1f} µA ({ua * 1e-3:.3f} mA)"
    if kind == "optical_power":
        return _optical_text(_u16(bytes_[0], bytes_[1]))
    if kind == "tec_current":
        value = _signed16(_u16(bytes_[0], bytes_[1])) * 0.1
        return f"{value:.1f} mA"
    if kind == "fixed_slope":
        value = _u16(bytes_[0], bytes_[1]) / 256.0
        return f"{value:.4f}"
    if kind == "signed_raw":
        return str(_signed16(_u16(bytes_[0], bytes_[1])))
    if kind == "ieee754":
        if len(bytes_) < 4:
            return "—"
        # IEEE-754 binary32, MSB first as stored in A2h
        value = struct.unpack(">f", bytes(b & 0xFF for b in bytes_[:4]))[0]
        return f"{value:.6g}"
    if kind == "status_110":
        return _bits_set(bytes_[0], _STATUS_110)
    if kind == "alarm_112":
        return _bits_set(bytes_[0], _ALARM_112)
    if kind == "alarm_113":
        return _bits_set(bytes_[0], _ALARM_113)
    if kind == "warn_116":
        return _bits_set(bytes_[0], _WARN_116)
    if kind == "warn_117":
        return _bits_set(bytes_[0], _WARN_117)
    if kind == "nibble_eq":
        return f"HIGH nibble={((bytes_[0] >> 4) & 0xF)}, LOW nibble={(bytes_[0] & 0xF)}"
    if kind == "checksum":
        return f"0x{bytes_[0] & 0xFF:02X}"
    if kind in ("byte", "bytes"):
        return " ".join(f"0x{b & 0xFF:02X}" for b in bytes_)
    return "—"


def _field_for_addr(addr: int) -> tuple[int, int, str, str] | None:
    for start, end, name, kind in _A2H_MAP:
        if start <= addr <= end:
            return start, end, name, kind
    return None


def annotate_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Attach SFF-8472 names and converted values to a per-address scan of one side.

    Each row must already contain ``address``, ``sfp0.raw``, ``sfp1.raw``.
    Conversion for multi-byte fields is shown on the first (MSB) address only.
    """
    by_addr = {int(row["address"]): row for row in rows}
    out: list[dict[str, Any]] = []
    for row in rows:
        addr = int(row["address"])
        field = _field_for_addr(addr)
        annotated = dict(row)
        if field is None:
            annotated["name"] = "—"
            annotated["role"] = "unknown"
            for key in ("sfp0", "sfp1"):
                side = dict(row[key])
                side["value_text"] = ""
                annotated[key] = side
            out.append(annotated)
            continue

        start, end, name, kind = field
        width = end - start + 1
        if addr == start:
            role = "msb" if width > 1 else "byte"
            label = name
            for key in ("sfp0", "sfp1"):
                side = dict(row[key])
                chunk = []
                missing = False
                for off in range(width):
                    other = by_addr.get(start + off)
                    if other is None:
                        missing = True
                        break
                    chunk.append(int(other[key]["raw"]))
                side["value_text"] = "" if missing else _decode_kind(kind, chunk)
                annotated[key] = side
        else:
            role = "lsb"
            label = f"{name} LSB" if width == 2 else f"{name} [{addr - start}]"
            for key in ("sfp0", "sfp1"):
                side = dict(row[key])
                side["value_text"] = ""
                annotated[key] = side

        annotated["name"] = label
        annotated["role"] = role
        annotated["field_kind"] = kind
        out.append(annotated)
    return out
