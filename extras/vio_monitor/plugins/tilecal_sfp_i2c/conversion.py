"""Parse SFP+ I2C register scan results."""

from __future__ import annotations

import re
from typing import Any


def _parse_raw(value) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text in ("N/A", "—", "-"):
        return None
    try:
        if text.lower().startswith("0x"):
            return int(text, 16) & 0xFF
        if re.search(r"[a-fA-F]", text):
            return int(text, 16) & 0xFF
        if re.fullmatch(r"[0-9]+", text) and len(text) <= 2:
            return int(text, 16) & 0xFF
        return int(text, 10) & 0xFF
    except (TypeError, ValueError):
        return None


def _format_cell(raw: int | None) -> dict[str, Any]:
    if raw is None:
        return {"raw": None, "raw_hex": "—", "raw_bin": "—"}
    return {
        "raw": raw,
        "raw_hex": f"0x{raw:02X}",
        "raw_bin": f"{raw:08b}",
    }


def parse_scan_rows(output: str, parse_rows) -> tuple[list[dict], list[str]]:
    """Return (data rows, error messages)."""
    rows: list[dict] = []
    errors: list[str] = []
    for row in parse_rows(output, "SFPI2C", 4):
        side_text, addr_text, val_text = row
        try:
            side = int(side_text, 0)
            addr = int(addr_text, 0)
        except (TypeError, ValueError):
            continue
        rows.append({
            "side": side,
            "address": addr,
            "value_text": val_text,
            "raw": _parse_raw(val_text),
        })
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("SFPI2CERR|"):
            errors.append(line.split("|", 1)[1])
        elif line.startswith("SFPI2CPROBE|"):
            pass
    return rows, errors


def build_register_table(scan_rows: list[dict], max_addr: int) -> dict[str, Any]:
    """Build address × side table for 0..max_addr."""
    by_side: dict[int, dict[int, int | None]] = {0: {}, 1: {}}
    for row in scan_rows:
        side = row["side"]
        addr = row["address"]
        if side in by_side and 0 <= addr <= max_addr:
            by_side[side][addr] = row.get("raw")

    entries = []
    for addr in range(max_addr + 1):
        entries.append({
            "address": addr,
            "address_hex": f"0x{addr:02X}",
            "sides": {
                "0": _format_cell(by_side[0].get(addr)),
                "1": _format_cell(by_side[1].get(addr)),
            },
        })

    return {
        "max_addr": max_addr,
        "entries": entries,
        "read_count": len(scan_rows),
    }


def parse_probe_map(output: str, parse_rows) -> dict[str, Any]:
    """Extract discovered probe names from SFPI2CPROBE lines."""
    probes = {"addr": {}, "data": {}}
    for row in parse_rows(output, "SFPI2CPROBE", 4):
        role, side_text, name = row
        try:
            side = int(side_text, 0)
        except (TypeError, ValueError):
            continue
        if role in probes:
            probes[role][side] = name
    return probes
