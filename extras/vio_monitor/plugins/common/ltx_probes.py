"""Extract VIO probe names and pin/net aliases from Vivado LTX (JSON) files.

Hardware Manager often reports ``probe_in58`` or ``s_vio_dbg_ddm_temp_q0[15:0]``
while plugin config uses the HDL net ``s_vio_dbg_ddm_temp_q0``.  Alias groups
from the selected LTX let both sides match.
"""

from __future__ import annotations

import json
import os
from typing import Any

_alias_cache: dict[str, tuple[float, dict[str, tuple[str, ...]]]] = {}
_active_aliases: dict[str, tuple[str, ...]] = {}


def _range_forms(base: str, left: int | None, right: int | None) -> list[str]:
    if left is None or right is None:
        return []
    if left == right:
        return [f"{base}[{left}]"]
    return [f"{base}[{left}:{right}]", f"{base}[{right}:{left}]"]


def _net_bus_name(net: dict[str, Any]) -> str:
    return str(net.get("name") or "")


def _iter_vio_pin_slices(data: dict[str, Any]):
    root = data.get("ltx_root", {})
    for item in root.get("ltx_data", []):
        for core in item.get("debug_cores", []):
            core_type = (core.get("type") or "").upper()
            if core_type != "VIO_V2":
                continue
            vio_name = core.get("name") or ""
            for pin in core.get("pins", []) or []:
                yield vio_name, pin


def _slice_alias_group(pin: dict[str, Any]) -> set[str]:
    """Names that all refer to one VIO pin slice (not individual bits)."""
    names: set[str] = set()
    pin_name = str(pin.get("name") or "")
    left = pin.get("leftIndex")
    right = pin.get("rightIndex")
    if pin_name:
        names.add(pin_name)
        names.update(_range_forms(pin_name, left, right))
    for net in pin.get("nets") or []:
        net_name = _net_bus_name(net)
        if not net_name:
            continue
        names.add(net_name)
    return {n for n in names if n}


def _build_alias_map(ltx_path: str) -> dict[str, tuple[str, ...]]:
    with open(ltx_path, encoding="utf-8", errors="replace") as f:
        data = json.load(f)

    groups: list[set[str]] = []
    pin_uses: dict[str, int] = {}
    for _vio, pin in _iter_vio_pin_slices(data):
        group = _slice_alias_group(pin)
        if not group:
            continue
        groups.append(group)
        pin_name = str(pin.get("name") or "")
        if pin_name:
            pin_uses[pin_name] = pin_uses.get(pin_name, 0) + 1

    # Concatenated ports (probe_out9 = flash address|command|floor) must not
    # alias the bare pin name — that would smash sibling slices.
    for group in groups:
        for pin_name, count in pin_uses.items():
            if count > 1 and pin_name in group:
                group.discard(pin_name)

    mapping: dict[str, tuple[str, ...]] = {}
    for group in groups:
        aliases = tuple(sorted(group))
        for name in aliases:
            existing = mapping.get(name)
            if existing is None:
                mapping[name] = aliases
                continue
            merged = tuple(sorted(set(existing) | group))
            mapping[name] = merged
    return mapping


def load_ltx_alias_map(ltx_path: str | None) -> dict[str, tuple[str, ...]]:
    """Return name -> alias-group for an LTX file (cached by path + mtime)."""
    global _active_aliases
    if not ltx_path or not os.path.isfile(ltx_path):
        _active_aliases = {}
        return {}
    path = os.path.abspath(ltx_path)
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        _active_aliases = {}
        return {}
    cached = _alias_cache.get(path)
    if cached and cached[0] == mtime:
        _active_aliases = cached[1]
        return cached[1]
    mapping = _build_alias_map(path)
    _alias_cache[path] = (mtime, mapping)
    _active_aliases = mapping
    return mapping


def activate_ltx(ltx_path: str | None) -> dict[str, tuple[str, ...]]:
    """Set the LTX used to expand probe aliases for matching / Tcl."""
    return load_ltx_alias_map(ltx_path)


def aliases_for_name(name: str) -> tuple[str, ...]:
    """LTX pin/net/range aliases for *name*, or ``(name,)`` if unknown."""
    if not name:
        return ()
    return _active_aliases.get(name, (name,))


def _pin_width(pin: dict[str, Any]) -> int:
    left = pin.get("leftIndex")
    right = pin.get("rightIndex")
    if left is None or right is None:
        return 1
    try:
        return abs(int(left) - int(right)) + 1
    except (TypeError, ValueError):
        return 1


def parse_ltx_pin_slices(ltx_path: str) -> list[dict[str, Any]]:
    """One record per VIO pin slice: pin, nets, aliases, width, direction."""
    with open(ltx_path, encoding="utf-8", errors="replace") as f:
        data = json.load(f)

    load_ltx_alias_map(ltx_path)

    slices = list(_iter_vio_pin_slices(data))
    pin_uses: dict[str, int] = {}
    for _vio_name, pin in slices:
        pin_name = str(pin.get("name") or "")
        if pin_name:
            pin_uses[pin_name] = pin_uses.get(pin_name, 0) + 1

    records: list[dict[str, Any]] = []
    for vio_name, pin in slices:
        direction = (pin.get("direction") or "IN").upper()
        if direction not in ("IN", "OUT"):
            direction = "IN"
        pin_name = str(pin.get("name") or "")
        left = pin.get("leftIndex")
        right = pin.get("rightIndex")
        aliases = _slice_alias_group(pin)
        if pin_name and pin_uses.get(pin_name, 0) > 1:
            aliases.discard(pin_name)
        nets = [n for n in (_net_bus_name(net) for net in pin.get("nets") or []) if n]
        records.append({
            "vio": vio_name,
            "pin": pin_name,
            "direction": direction,
            "left": left,
            "right": right,
            "width": _pin_width(pin),
            "nets": nets,
            "aliases": tuple(sorted(aliases)),
        })
    return records


def parse_ltx_probes(ltx_path: str) -> list[dict[str, str]]:
    """Return probe dicts {name, direction, vio} from a Vivado JSON LTX file.

    Includes HDL nets, VIO pin names, and bus-range forms.  Individual bit
    slices (``foo[3]``) are omitted so catalogs stay selectable.
    """
    with open(ltx_path, encoding="utf-8", errors="replace") as f:
        data = json.load(f)

    load_ltx_alias_map(ltx_path)

    slices = list(_iter_vio_pin_slices(data))
    pin_uses: dict[str, int] = {}
    for _vio_name, pin in slices:
        pin_name = str(pin.get("name") or "")
        if pin_name:
            pin_uses[pin_name] = pin_uses.get(pin_name, 0) + 1

    probes: list[dict[str, str]] = []
    seen: set[str] = set()
    for vio_name, pin in slices:
        direction = (pin.get("direction") or "IN").upper()
        if direction not in ("IN", "OUT"):
            direction = "IN"
        names = _slice_alias_group(pin)
        pin_name = str(pin.get("name") or "")
        if pin_name and pin_uses.get(pin_name, 0) > 1:
            names.discard(pin_name)
        for name in sorted(names):
            if name in seen:
                continue
            seen.add(name)
            probes.append({
                "name": name,
                "direction": direction,
                "vio": vio_name,
            })
    return probes
