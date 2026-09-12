"""Shared VIO probe name configuration for TileCal plugins."""

from __future__ import annotations

import fnmatch
from typing import Any

from plugins.tilecal_xadc.conversion import (
    ADDRESSES,
    LABELS,
    default_sysmon_property,
    tilecal_xadc_channel_probe_key,
)


def _tcl_glob(pattern: str) -> str:
    """Escape a glob for Tcl braced string match ([ ] are char-class syntax)."""
    out: list[str] = []
    for ch in pattern:
        if ch in "\\[]}":
            out.append("\\" + ch)
        else:
            out.append(ch)
    return "".join(out)


def tcl_string_match(pattern: str, var: str = "$__pname") -> str:
    """Return Tcl expression: string match {pattern} var (legacy glob patterns)."""
    return f'[string match {{{_tcl_glob(pattern)}}} {var}]'


def tcl_probe_eq(name: str, var: str = "$__n") -> str:
    """Exact hw_probe NAME comparison (safe for brackets in VIO names)."""
    if not name:
        return "0"
    escaped = name.replace("\\", "\\\\").replace("}", "\\}")
    # Must use [string equal ...] — NOT [$var eq {...}], which Tcl parses as a command named $var.
    return f'[string equal {var} {{{escaped}}}]'


def tcl_probe_match(name: str, var: str = "$__n") -> str:
    """Match configured probe: exact VIO name, or Tcl glob if * / ? present."""
    if not name:
        return "0"
    if "*" in name or "?" in name:
        return tcl_string_match(name, var)
    return tcl_probe_eq(name, var)


def probe_name_leaf(name: str) -> str:
    text = name.strip()
    if "[" in text:
        return text.rsplit("[", 1)[-1].rstrip("]")
    if "." in text:
        return text.rsplit(".", 1)[-1]
    if "/" in text:
        return text.rsplit("/", 1)[-1]
    return text


def normalize_probe_name(name: str) -> str:
    return name.replace("[", ".").replace("]", "").replace("/", ".").lower()


def probe_name_available(required: str, names: set[str]) -> bool:
    """True if required probe pattern matches any name in the pool."""
    if not required or not names:
        return False
    if required in names:
        return True
    if "*" in required or "?" in required:
        return any(fnmatch.fnmatchcase(n, required) for n in names)
    norm_req = normalize_probe_name(required)
    leaf = probe_name_leaf(required)
    parent = required.split("[", 1)[0] if "[" in required else (
        required.rsplit(".", 1)[0] if "." in required else ""
    )
    norm_parent = normalize_probe_name(parent) if parent else ""
    for candidate in names:
        if candidate == required:
            return True
        norm_candidate = normalize_probe_name(candidate)
        if norm_candidate == norm_req:
            return True
        if leaf and probe_name_leaf(candidate) == leaf:
            if not norm_parent or norm_parent in norm_candidate:
                return True
    return False


def missing_probe_names(required: list[str], names: set[str]) -> list[str]:
    return [name for name in required if not probe_name_available(name, names)]


def _sfp_ddm_probe_defaults() -> tuple[dict[str, str], dict[str, str], dict[str, str], dict[str, str]]:
    """Per-side per-field DDM VIO probe keys."""
    from plugins.sfp_ddm.conversion import FIELD_DEFS

    defaults: dict[str, str] = {
        "ddm_classify_pattern": "*s_sfp_interface*ddm*",
    }
    labels: dict[str, str] = {
        "ddm_classify_pattern": "Auto-classify fallback pattern",
    }
    hints: dict[str, str] = {
        "ddm_classify_pattern": "Tcl glob for unmatched probes (optional fallback)",
    }
    groups: dict[str, str] = {
        "ddm_classify_pattern": "Advanced",
    }
    for side in (0, 1):
        group = f"SFP+ {side}"
        for field in FIELD_DEFS:
            key = f"ddm_{side}_{field['id']}"
            defaults[key] = f"s_sfp_interface[ddm][{side}][{field['index']}]"
            labels[key] = field["label"]
            hints[key] = field["spec"]
            groups[key] = group
    return defaults, labels, hints, groups


def parse_ddm_probe_key(key: str) -> tuple[int, str] | None:
    """Parse ddm_0_temperature -> (0, 'temperature')."""
    if not key.startswith("ddm_") or key == "ddm_classify_pattern":
        return None
    parts = key.split("_", 2)
    if len(parts) != 3:
        return None
    try:
        side = int(parts[1])
    except ValueError:
        return None
    return side, parts[2]


def split_sfp_ddm_probes(probes: dict[str, str]) -> tuple[dict[tuple[int, str], str], str]:
    """Return explicit (side, field_id) -> probe name map and classify pattern."""
    explicit: dict[tuple[int, str], str] = {}
    pattern = "*s_sfp_interface*ddm*"
    for key, value in probes.items():
        if key == "ddm_classify_pattern":
            if value:
                pattern = value
            continue
        parsed = parse_ddm_probe_key(key)
        if parsed is not None:
            explicit[parsed] = value
    return explicit, pattern


def _tilecal_xadc_probe_defaults() -> tuple[dict[str, str], dict[str, str], dict[str, str], dict[str, str]]:
    """Per-channel sysmon property keys plus live VIO scan keys."""
    defaults: dict[str, str] = {}
    labels: dict[str, str] = {}
    hints: dict[str, str] = {}
    groups: dict[str, str] = {}
    for idx, addr in enumerate(ADDRESSES):
        key = tilecal_xadc_channel_probe_key(addr)
        prop = default_sysmon_property(addr)
        defaults[key] = prop
        labels[key] = LABELS[idx]
        hints[key] = f"hw_sysmon property · DRP 0x{addr:02X}"
        groups[key] = "Channel sysmon properties"
    return defaults, labels, hints, groups


def probe_config_fields(manifest: dict[str, Any], cfg: dict[str, Any]) -> list[dict[str, Any]]:
    """Merge manifest probe_defaults with saved cfg['plugins'][id]['probes']."""
    defaults: dict[str, str] = dict(manifest.get("probe_defaults") or {})
    labels: dict[str, str] = dict(manifest.get("probe_labels") or {})
    hints: dict[str, str] = dict(manifest.get("probe_hints") or {})
    groups: dict[str, str] = dict(manifest.get("probe_groups") or {})
    kinds: dict[str, str] = dict(manifest.get("probe_kinds") or {})

    if manifest.get("id") == "tilecal_xadc":
        ch_defaults, ch_labels, ch_hints, ch_groups = _tilecal_xadc_probe_defaults()
        defaults = {**ch_defaults, **defaults}
        labels = {**ch_labels, **labels}
        hints = {**ch_hints, **hints}
        groups = {**ch_groups, **groups}
        for key in ch_defaults:
            kinds.setdefault(key, "sysmon_prop")
        for key in (manifest.get("probe_defaults") or {}):
            kinds.setdefault(key, "vio_name")
            groups.setdefault(key, "Live VIO scan")

    if manifest.get("id") == "sfp_ddm":
        ddm_defaults, ddm_labels, ddm_hints, ddm_groups = _sfp_ddm_probe_defaults()
        defaults = {**ddm_defaults, **defaults}
        labels = {**ddm_labels, **labels}
        hints = {**ddm_hints, **hints}
        groups = {**ddm_groups, **groups}
        for key in ddm_defaults:
            kinds.setdefault(key, "glob_pattern" if key == "ddm_classify_pattern" else "vio_name")

    saved = (cfg.get("plugins") or {}).get(manifest["id"], {}).get("probes") or {}
    fields: list[dict[str, Any]] = []
    group_rank = {
        "Live VIO scan": 0,
        "Channel sysmon properties": 1,
        "SFP+ 0": 2,
        "SFP+ 1": 3,
        "Advanced": 4,
    }
    for key, default in defaults.items():
        value = saved.get(key, default)
        if not isinstance(value, str) or not value.strip():
            value = default
        fields.append({
            "key": key,
            "label": labels.get(key, key.replace("_", " ")),
            "hint": hints.get(key, ""),
            "value": value.strip(),
            "default": default,
            "kind": kinds.get(key, "vio_name"),
            "group": groups.get(key, ""),
        })
    fields.sort(key=lambda f: (group_rank.get(f.get("group") or "", 99), f["key"]))
    return fields


def channel_probe_addr(key: str) -> int | None:
    """Parse ch_10 -> 0x10 channel probe key."""
    if not key.startswith("ch_") or len(key) != 5:
        return None
    try:
        return int(key[3:], 16)
    except ValueError:
        return None


def split_plugin_probes(probes: dict[str, str]) -> tuple[dict[str, str], dict[int, str]]:
    """Separate VIO probe names from per-channel sysmon property overrides."""
    vio: dict[str, str] = {}
    channels: dict[int, str] = {}
    for key, value in probes.items():
        addr = channel_probe_addr(key)
        if addr is not None:
            channels[addr] = value
        else:
            vio[key] = value
    return vio, channels


def plugin_probes(manifest: dict[str, Any], cfg: dict[str, Any]) -> dict[str, str]:
    """Resolved probe name map for a plugin."""
    return {f["key"]: f["value"] for f in probe_config_fields(manifest, cfg)}


def sanitize_probe_updates(raw: dict | None) -> dict[str, str]:
    """Keep only non-empty string probe overrides from a config save."""
    if not isinstance(raw, dict):
        return {}
    out: dict[str, str] = {}
    for key, value in raw.items():
        if not isinstance(key, str):
            continue
        text = str(value).strip() if value is not None else ""
        if text:
            out[key] = text
    return out
