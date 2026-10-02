"""SFF-8472 A2h decode. Each status word packs SFP+0 in 15:0 and SFP+1 in 31:16."""

from __future__ import annotations

import math

FIELDS = (
    {"id": "temperature", "label": "Temperature", "stb": "stb_sfp_ddm_temperature", "kind": "signed_temp", "unit": "°C", "spec": "16-bit signed, LSB = 1/256 °C"},
    {"id": "vcc", "label": "Supply voltage", "stb": "stb_sfp_ddm_vcc", "kind": "unsigned_scale", "scale": 100e-6, "unit": "V", "spec": "16-bit unsigned, LSB = 100 µV"},
    {"id": "tx_bias_current", "label": "TX bias current", "stb": "stb_sfp_ddm_tx_bias_current", "kind": "unsigned_scale", "scale": 2e-6, "unit": "A", "display_unit": "µA", "display_scale": 1e6, "spec": "16-bit unsigned, LSB = 2 µA"},
    {"id": "tx_power", "label": "TX output power", "stb": "stb_sfp_ddm_tx_power", "kind": "optical_power", "spec": "16-bit unsigned, LSB = 0.1 µW"},
    {"id": "rx_power", "label": "RX optical power", "stb": "stb_sfp_ddm_rx_power", "kind": "optical_power", "spec": "16-bit unsigned, LSB = 0.1 µW"},
    {"id": "laser_temperature", "label": "Laser temperature", "stb": "stb_sfp_ddm_laser_temperature", "kind": "signed_temp", "unit": "°C", "spec": "16-bit signed, LSB = 1/256 °C"},
    {"id": "tec_current", "label": "TEC current", "stb": "stb_sfp_ddm_tec_current", "kind": "signed_scale", "scale": 0.1, "unit": "mA", "spec": "16-bit signed, LSB = 0.1 mA"},
)


def _signed(raw: int) -> int:
    raw &= 0xFFFF
    return raw - 0x10000 if raw >= 0x8000 else raw


def decode_half(field: dict, raw: int) -> dict:
    kind = field["kind"]
    raw_hex = f"0x{raw & 0xFFFF:04X}"
    if kind == "signed_temp":
        value = _signed(raw) / 256.0
        text = f"{value:.2f} {field['unit']}"
    elif kind == "signed_scale":
        value = _signed(raw) * field["scale"]
        text = f"{value:.1f} {field['unit']}"
    elif kind == "unsigned_scale":
        value = raw * field["scale"]
        unit = field.get("display_unit", field["unit"])
        shown = value * field.get("display_scale", 1.0)
        if unit == "µA":
            text = f"{shown:.1f} {unit} ({value * 1e3:.3f} mA)"
        elif field["unit"] == "V":
            text = f"{value:.4f} V ({value * 1e3:.1f} mV)"
        else:
            text = f"{shown:.4g} {unit}"
    elif kind == "optical_power":
        value = raw * 0.1e-3
        dbm = 10.0 * math.log10(value) if value > 0 else None
        extra = f"{dbm:.2f} dBm" if dbm is not None else "— dBm"
        text = f"{value:.4f} mW ({extra})"
    else:
        value = raw
        text = str(raw)
    return {"raw": raw & 0xFFFF, "raw_hex": raw_hex, "value": value, "value_text": text}


def decode_word(field: dict, word: int) -> dict:
    return {
        "0": decode_half(field, word & 0xFFFF),
        "1": decode_half(field, (word >> 16) & 0xFFFF),
    }
