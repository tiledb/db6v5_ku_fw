"""SFF-8472 A2h DDM decode helpers for s_vio_dbg_ddm_* / stb_sfp_ddm_* probes."""

from __future__ import annotations

import fnmatch
import math
import re
from typing import Any

from plugins.common.db6_hw_map import (
    DDM_BY_ID,
    DDM_BY_INDEX,
    DDM_CLASSIFY_PATTERNS,
    DDM_FIELDS,
    DDM_TOKEN_TO_ID,
    ddm_all_names,
)
from plugins.common.probe_config import find_matching_probe_name

# Field order matches c_sfp_* in db6_design_package.vhd
FIELD_DEFS: list[dict[str, Any]] = DDM_FIELDS
FIELD_BY_ID = DDM_BY_ID
FIELD_BY_INDEX = DDM_BY_INDEX


def _parse_raw(value) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text in ("N/A", "—", "-"):
        return None
    try:
        if text.lower().startswith("0x"):
            return int(text, 16) & 0xFFFF
        if re.search(r"[a-fA-F]", text):
            return int(text, 16) & 0xFFFF
        if re.fullmatch(r"[0-9]+", text) and len(text) <= 4:
            return int(text, 16) & 0xFFFF
        return int(text, 10) & 0xFFFF
    except (TypeError, ValueError):
        return None


def _to_signed16(raw: int) -> int:
    raw &= 0xFFFF
    return raw - 0x10000 if raw >= 0x8000 else raw


def _mw_to_dbm(mw: float | None) -> float | None:
    if mw is None or mw <= 0:
        return None
    return 10.0 * math.log10(mw)


def decode_ddm(field_id: str, raw: int | None) -> dict[str, Any]:
    """Convert a 16-bit DDM raw code to calibrated value(s)."""
    field = FIELD_BY_ID[field_id]
    if raw is None:
        return {
            "raw": None,
            "raw_hex": None,
            "value": None,
            "value_text": "—",
            "extra": None,
        }

    raw_hex = f"0x{raw:04X}"
    kind = field["kind"]

    if kind == "signed_temp":
        value = _to_signed16(raw) / 256.0
        return {
            "raw": raw,
            "raw_hex": raw_hex,
            "value": value,
            "value_text": f"{value:.2f} {field['unit']}",
            "extra": None,
        }

    if kind == "signed_scale":
        value = _to_signed16(raw) * field["scale"]
        return {
            "raw": raw,
            "raw_hex": raw_hex,
            "value": value,
            "value_text": f"{value:.1f} {field['unit']}",
            "extra": None,
        }

    if kind == "unsigned_scale":
        value = raw * field["scale"]
        disp_unit = field.get("display_unit", field["unit"])
        disp_scale = field.get("display_scale", 1.0)
        disp_val = value * disp_scale
        if disp_unit == "µA":
            text = f"{disp_val:.1f} {disp_unit} ({value * 1e3:.3f} mA)"
        elif field["unit"] == "V":
            text = f"{value:.4f} {field['unit']} ({value * 1e3:.1f} mV)"
        else:
            text = f"{disp_val:.4g} {disp_unit}"
        return {
            "raw": raw,
            "raw_hex": raw_hex,
            "value": value,
            "value_text": text,
            "extra": None,
        }

    if kind == "optical_power":
        mw = raw * 0.1e-3  # LSB = 0.1 µW -> mW
        dbm = _mw_to_dbm(mw)
        extra = f"{dbm:.2f} dBm" if dbm is not None else "— dBm"
        return {
            "raw": raw,
            "raw_hex": raw_hex,
            "value": mw,
            "value_text": f"{mw:.4f} mW ({extra})",
            "extra": dbm,
        }

    return {
        "raw": raw,
        "raw_hex": raw_hex,
        "value": raw,
        "value_text": str(raw),
        "extra": None,
    }


def classify_probe(name: str, ddm_pattern: str = DDM_CLASSIFY_PATTERNS[0]) -> tuple[int, str] | None:
    """Map a VIO probe name to (side, field_id)."""
    if not name:
        return None

    n = name.lower()
    # Bit slices of s_vio_dbg_ddm_*_qN are not the 16-bit bus.
    if re.search(r"s_vio_dbg_ddm_[a-z]+_q[01]\[\d+\]$", n):
        return None

    # LTX / legacy / pin-range names from db6_hw_map + current LTX
    for field in DDM_FIELDS:
        for side in (0, 1):
            for alias in ddm_all_names(field["id"], side):
                if find_matching_probe_name(alias, (name,)):
                    return side, field["id"]

    m = re.search(r"s_vio_dbg_ddm_([a-z]+)_q([01])", n)
    if m:
        field_id = DDM_TOKEN_TO_ID.get(m.group(1))
        if field_id:
            return int(m.group(2)), field_id

    patterns = [ddm_pattern, *DDM_CLASSIFY_PATTERNS] if ddm_pattern else list(DDM_CLASSIFY_PATTERNS)
    if not any(fnmatch.fnmatch(name, pat) for pat in patterns if pat):
        return None

    side = None
    field_id = None

    m = re.search(r"ddm\(([01])\)\(c_sfp_(\w+)\)", n)
    if m:
        side = int(m.group(1))
        field_id = m.group(2)
    else:
        m = re.search(r"\[ddm\]\[([01])\]\[c_sfp_(\w+)\]", n)
        if m:
            side = int(m.group(1))
            field_id = m.group(2)
        else:
            m = re.search(r"\[ddm\]\[([01])\]\[([0-6])\]", n)
            if m:
                side = int(m.group(1))
                field_id = FIELD_BY_INDEX[int(m.group(2))]["id"]
            else:
                m = re.search(r"ddm[\[\(_\.]*([01])", n)
                if m:
                    side = int(m.group(1))

                keyword_fields = [
                    "laser_temperature",
                    "tx_bias_current",
                    "tx_power",
                    "rx_power",
                    "tec_current",
                    "temperature",
                    "vcc",
                ]
                for fid in keyword_fields:
                    if fid in n or f"c_sfp_{fid}" in n:
                        field_id = fid
                        break
                    if fid == "temperature" and "temp" in n and "laser" not in n:
                        field_id = fid
                        break
                    if fid == "tx_bias_current" and "bias" in n:
                        field_id = fid
                        break
                    if fid == "tec_current" and "tec" in n:
                        field_id = fid
                        break

    if side is None or field_id is None or field_id not in FIELD_BY_ID:
        return None
    return side, field_id


def build_ddm_table(
    probe_rows: list[dict],
    ddm_pattern: str = DDM_CLASSIFY_PATTERNS[0],
    explicit_probes: dict[tuple[int, str], str] | None = None,
) -> dict[str, Any]:
    """Build side×field table from SFPDDM probe rows."""
    explicit_probes = explicit_probes or {}
    slots: dict[tuple[int, str], dict[str, Any]] = {}
    unmatched: list[dict[str, str]] = []
    row_by_name: dict[str, dict] = {}
    for row in probe_rows:
        name = row.get("probe", "")
        if name:
            row_by_name[name] = row

    for (side, field_id), probe_name in explicit_probes.items():
        if field_id not in FIELD_BY_ID:
            continue
        match_name = find_matching_probe_name(probe_name, row_by_name.keys())
        if match_name is None:
            for alias in ddm_all_names(field_id, side):
                match_name = find_matching_probe_name(alias, row_by_name.keys())
                if match_name is not None:
                    break
        row = row_by_name.get(match_name) if match_name else None
        if row is not None:
            probe_name = match_name
        if row is None:
            continue
        raw = _parse_raw(row.get("value"))
        decoded = decode_ddm(field_id, raw)
        slots[(side, field_id)] = {
            "side": side,
            "field_id": field_id,
            "probe": probe_name,
            "direction": row.get("direction"),
            **decoded,
        }

    for row in probe_rows:
        name = row.get("probe", "")
        classified = classify_probe(name, ddm_pattern)
        if classified is None:
            unmatched.append(row)
            continue
        side, field_id = classified
        key = (side, field_id)
        if key in slots:
            continue
        raw = _parse_raw(row.get("value"))
        decoded = decode_ddm(field_id, raw)
        slots[key] = {
            "side": side,
            "field_id": field_id,
            "probe": name,
            "direction": row.get("direction"),
            **decoded,
        }

    # Drop rows that were matched via explicit map or classify from unmatched
    matched_names = {cell.get("probe") for cell in slots.values() if cell.get("probe")}
    unmatched = [row for row in unmatched if row.get("probe") not in matched_names]

    rows = []
    for field in FIELD_DEFS:
        entry = {
            "field_id": field["id"],
            "label": field["label"],
            "spec": field["spec"],
            "stb": field.get("stb"),
            "stb_addr": field.get("stb_addr"),
            "sides": {},
        }
        for side in (0, 1):
            cell = slots.get((side, field["id"]))
            entry["sides"][str(side)] = cell or {
                "side": side,
                "field_id": field["id"],
                "probe": None,
                "raw": None,
                "raw_hex": None,
                "value": None,
                "value_text": "—",
                "extra": None,
            }
        rows.append(entry)

    found = sum(1 for _k in slots)
    expected = len(FIELD_DEFS) * 2
    return {
        "rows": rows,
        "found_probes": found,
        "expected_probes": expected,
        "complete": found >= expected,
        "unmatched_probes": unmatched,
    }
