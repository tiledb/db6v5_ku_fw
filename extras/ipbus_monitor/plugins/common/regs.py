"""Register lookup helpers against ``extras/ipbus_monitor/lib/db_lib.py``."""

from __future__ import annotations

import os
import sys

_LIB = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "lib"))
if _LIB not in sys.path:
    sys.path.insert(0, _LIB)

from db_lib import decode_fields, decode_value, find_register  # noqa: E402


def reg(bus: str, name: str) -> dict:
    found = find_register(bus, name)
    if not found or found.get("name") == "(raw)":
        raise KeyError(f"{bus}:{name}")
    return found


def describe(found: dict, value: int) -> dict:
    value_i = int(value) & 0xFFFFFFFF
    return {
        "raw": value_i,
        "hex": f"0x{value_i:08X}",
        "fields": decode_fields(found, value_i),
        "extra": decode_value(found, value_i),
    }


def read_named(session, bus: str, name: str) -> dict:
    found = reg(bus, name)
    sides = {
        side_id: describe(found, value)
        for side_id, value in session.read_both(found["hw_addr"]).items()
    }
    return {
        "name": found["name"],
        "bus": bus,
        "addr": found["hw_addr"],
        "addr_hex": f"0x{found['hw_addr']:03X}",
        "note": found.get("note") or "",
        "writable": bool(found.get("writable")),
        "sides": sides,
    }
