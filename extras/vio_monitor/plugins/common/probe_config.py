"""Shared VIO probe name configuration for TileCal plugins."""

from __future__ import annotations

import fnmatch
import re
from typing import Any

from plugins.common.ltx_probes import activate_ltx, aliases_for_name
from plugins.common.db6_hw_map import (
    DDM_CLASSIFY_PATTERNS,
    DDM_FIELDS,
    DATA_READOUT_PROBES,
    FLASH_PROBES,
    XADC_LIVE_PROBES,
    data_readout_probe_names,
    ddm_all_names,
    ddm_ltx_name,
    flash_probe_names,
    probe_aliases,
    sfp_i2c_addr_names,
    sfp_i2c_data_names,
    xadc_live_names,
)
from plugins.tilecal_xadc.conversion import (
    ADDRESSES,
    LABELS,
    default_sysmon_property,
    tilecal_xadc_channel_probe_key,
)


_NUMERIC_SLICE_RE = re.compile(r"(?:\[\d+(?::\d+)?\])+$")
_TCL_RE_SPECIAL = frozenset(r"\.^$*+?()[]{}|")


def _tcl_glob(pattern: str) -> str:
    """Escape a glob for Tcl braced string match ([ ] are char-class syntax)."""
    out: list[str] = []
    for ch in pattern:
        if ch in "\\[]}":
            out.append("\\" + ch)
        else:
            out.append(ch)
    return "".join(out)


def _tcl_regexp_escape(text: str) -> str:
    return "".join("\\" + ch if ch in _TCL_RE_SPECIAL else ch for ch in text)


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
    """Match configured probe: exact VIO name, numeric bus suffix, or glob."""
    if not name:
        return "0"
    if "*" in name or "?" in name:
        return tcl_string_match(name, var)
    eq = tcl_probe_eq(name, var)
    # Live NAME is often net[15:0] / probe_in58[15:0] while config stores the bus.
    regexp = r"^" + _tcl_regexp_escape(name) + r"(\[[0-9]+(:[0-9]+)?\])*$"
    return f"({eq} || [regexp -- {{{regexp}}} {var}])"


def tcl_probe_match_any(names: list[str], var: str = "$__n") -> str:
    """OR of tcl_probe_match for LTX + legacy aliases."""
    parts = [tcl_probe_match(n, var) for n in names if n]
    if not parts:
        return "0"
    if len(parts) == 1:
        return parts[0]
    return "(" + " || ".join(parts) + ")"


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


def names_refer_to_same_probe(required: str, candidate: str) -> bool:
    """True if *candidate* is *required* or a numeric bus/bit suffix of it."""
    if not required or not candidate:
        return False
    if required == candidate:
        return True
    if candidate.startswith(required) and _NUMERIC_SLICE_RE.fullmatch(candidate[len(required):]):
        return True
    if required.startswith(candidate) and re.fullmatch(r"\[\d+:\d+\]", required[len(candidate):]):
        return True
    return normalize_probe_name(required) == normalize_probe_name(candidate)


def _expand_probe_aliases(required: str) -> list[str]:
    names: list[str] = []
    for alias in probe_aliases(required) or [required]:
        if alias and alias not in names:
            names.append(alias)
        for extra in aliases_for_name(alias):
            if extra and extra not in names:
                names.append(extra)
    return names


def _name_in_pool(required: str, names: set[str]) -> bool:
    if required in names:
        return True
    if "*" in required or "?" in required:
        return any(fnmatch.fnmatchcase(n, required) for n in names)
    for candidate in names:
        if names_refer_to_same_probe(required, candidate):
            return True
    return False


def probe_name_available(required: str, names: set[str]) -> bool:
    """True if required probe (or a known LTX/legacy/pin alias) matches the pool."""
    if not required or not names:
        return False
    for alias in _expand_probe_aliases(required):
        if _name_in_pool(alias, names):
            return True
    return False


def find_matching_probe_name(required: str, names) -> str | None:
    """Return the pool name that matches *required*, preferring bus-level names."""
    hits = find_matching_probe_names(required, names)
    return hits[0] if hits else None


def find_matching_probe_names(required: str, names) -> list[str]:
    """All pool names that match *required*, bus-level first, bit slices last."""
    if not required:
        return []
    pool = list(names)
    hits: list[str] = []
    for alias in _expand_probe_aliases(required):
        for candidate in pool:
            if names_refer_to_same_probe(alias, candidate) or (
                "*" in alias and fnmatch.fnmatchcase(candidate, alias)
            ):
                if candidate not in hits:
                    hits.append(candidate)
    if not hits:
        return []

    parents = _expand_probe_aliases(required)
    non_bit_children = [
        hit for hit in hits
        if not any(re.fullmatch(re.escape(parent) + r"\[\d+\]", hit) for parent in parents)
    ]
    if non_bit_children:
        hits = non_bit_children

    def _rank(name: str) -> tuple[int, int, str]:
        # Prefer exact / bus-range over single-bit slices.
        if name == required:
            return (0, 0, name)
        if re.search(r"\[\d+:\d+\]$", name):
            return (1, 0, name)
        if re.search(r"\[\d+\]$", name):
            return (3, 0, name)
        return (2, 0, name)

    hits.sort(key=_rank)
    return hits


def missing_probe_names(required: list[str], names: set[str]) -> list[str]:
    return [name for name in required if not probe_name_available(name, names)]


def _sfp_ddm_probe_defaults() -> tuple[dict[str, str], dict[str, str], dict[str, str], dict[str, str]]:
    """Per-side per-field DDM VIO probe keys (s_vio_dbg_ddm_* / stb_sfp_ddm_*)."""
    defaults: dict[str, str] = {
        "ddm_classify_pattern": DDM_CLASSIFY_PATTERNS[0],
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
        for field in DDM_FIELDS:
            key = f"ddm_{side}_{field['id']}"
            defaults[key] = ddm_ltx_name(field["id"], side)
            labels[key] = field["label"]
            hints[key] = (
                f"{field['spec']} · {field['stb']} @ 0x{field['stb_addr']:03X} "
                f"(aliases: {', '.join(ddm_all_names(field['id'], side)[1:])})"
            )
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
    pattern = DDM_CLASSIFY_PATTERNS[0]
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
            if key in XADC_LIVE_PROBES or key.endswith("_legacy"):
                kinds[key] = "vio_name_optional"

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
            "optional": kinds.get(key, "vio_name") in ("glob_pattern", "vio_name_optional")
            or bool((XADC_LIVE_PROBES.get(key) or {}).get("optional")),
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
    activate_ltx((cfg or {}).get("last_ltx"))
    return {f["key"]: f["value"] for f in probe_config_fields(manifest, cfg)}


def plugin_probe_match_names(key: str, configured: str) -> list[str]:
    """Configured name plus known LTX/legacy/pin aliases for Tcl matching."""
    names: list[str] = []
    for name in [configured, *probe_aliases(configured)]:
        if name and name not in names:
            names.append(name)
    extra: list[str] = []
    if key in FLASH_PROBES:
        extra = flash_probe_names(key)
    elif key in DATA_READOUT_PROBES:
        extra = data_readout_probe_names(key)
    elif key.startswith("addr_probe_"):
        extra = sfp_i2c_addr_names(int(key[-1]))
    elif key.startswith("data_probe_"):
        extra = sfp_i2c_data_names(int(key[-1]))
    elif key in XADC_LIVE_PROBES:
        extra = xadc_live_names(key)
    for name in extra:
        if name and name not in names:
            names.append(name)
    for name in list(names):
        for alias in aliases_for_name(name):
            if alias and alias not in names:
                names.append(alias)
    return names


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
