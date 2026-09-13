"""Compare LTX VIO pin slices with live hw_probe objects on the JTAG chain."""
from __future__ import annotations

import json
import os

from flask import Blueprint, jsonify, request

from plugins.common.ltx_probes import activate_ltx, parse_ltx_pin_slices
from plugins.common.probe_config import (
    find_matching_probe_names,
    names_refer_to_same_probe,
    probe_config_fields,
)
from plugins.registry import discover_plugins, register_tree_hook


def tcl_dump_live_probes(device: str) -> str:
    """List VIO cores and hw_probe NAME/type/width/value without a full device refresh."""
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        'current_hw_device $__dev ; '
        'foreach __vio [get_hw_vios -of_objects $__dev] { '
        'set __vname [get_property NAME $__vio] ; '
        'puts "VIOCORE|$__vname" ; '
        'foreach __p [get_hw_probes -of_objects $__vio] { '
        'set __n [get_property NAME $__p] ; '
        'set __dir "IN" ; '
        'catch { if {[get_property PROBE_TYPE $__p] eq "OUTPUT"} { set __dir "OUT" } } ; '
        'set __w "" ; catch { set __w [get_property WIDTH $__p] } ; '
        'set __val "" ; '
        'if {$__dir eq "OUT"} { catch { set __val [get_property OUTPUT_VALUE $__p] } } '
        'else { catch { set __val [get_property INPUT_VALUE $__p] } ; '
        'if {$__val eq ""} { catch { set __val [get_property OUTPUT_VALUE $__p] } } } ; '
        'if {$__val eq ""} { set __val "-" } ; '
        'puts "VIOCMP|$__n|$__dir|$__vname|$__w|$__val" '
        '} }'
    )


def _plugin_probe_refs(cfg: dict) -> dict[str, list[str]]:
    """Map configured probe names to plugin.field labels."""
    refs: dict[str, list[str]] = {}
    for manifest in discover_plugins():
        pid = manifest.get("id") or ""
        for field in probe_config_fields(manifest, cfg):
            kind = field.get("kind") or "vio_name"
            if kind not in ("vio_name", "vio_name_optional", None, ""):
                continue
            value = (field.get("value") or "").strip()
            if not value:
                continue
            label = f"{pid}.{field.get('key')}"
            refs.setdefault(value, []).append(label)
    return refs


def _refs_for_aliases(aliases: list[str], refs: dict[str, list[str]]) -> list[str]:
    found: list[str] = []
    for configured, labels in refs.items():
        if any(names_refer_to_same_probe(configured, alias) for alias in aliases):
            for label in labels:
                if label not in found:
                    found.append(label)
    return found


def _match_live(aliases: list[str], live_names: list[str]) -> list[str]:
    hits: list[str] = []
    for alias in aliases:
        for name in find_matching_probe_names(alias, live_names):
            if name not in hits:
                hits.append(name)
    return hits


def register(app, ctx, manifest):
    bp = Blueprint("plugin_vio_match", __name__, url_prefix="/api/plugins/vio_match")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]
    load_config = ctx["load_config"]

    @bp.route("/data")
    def api_vio_match_data():
        cfg = load_config()
        ltx_path = (request.args.get("path") or request.args.get("ltx") or "").strip()
        if not ltx_path:
            ltx_path = (cfg.get("last_ltx") or "").strip()
        device = request.args.get("device", "").strip()

        ltx_error = ""
        slices: list[dict] = []
        if not ltx_path:
            ltx_error = "No LTX file selected"
        elif not os.path.isfile(ltx_path):
            ltx_error = f"LTX file not found: {ltx_path}"
        else:
            try:
                activate_ltx(ltx_path)
                slices = parse_ltx_pin_slices(ltx_path)
            except (OSError, ValueError, json.JSONDecodeError) as exc:
                ltx_error = str(exc)

        live: list[dict[str, str]] = []
        cores: list[str] = []
        live_error = ""
        live_output = ""
        if device:
            with lock:
                result = run(tcl_dump_live_probes(device), timeout_override=45)
            live_output = result.output
            if not result.success:
                live_error = (result.output or "failed to list hw_probes").strip().splitlines()
                live_error = live_error[-1] if live_error else "failed to list hw_probes"
            cores = [row[0] for row in parse_rows(result.output, "VIOCORE", 2)]
            for row in parse_rows(result.output, "VIOCMP", 6):
                name, direction, vio, width, value = row
                live.append({
                    "name": name,
                    "direction": direction or "IN",
                    "vio": vio or "",
                    "width": width or "",
                    "value": value or "-",
                })
        else:
            live_error = "No device selected"

        live_by_name = {row["name"]: row for row in live}
        live_names = list(live_by_name)
        refs = _plugin_probe_refs(cfg)
        matched_live: set[str] = set()
        rows = []
        matched = 0
        for sl in slices:
            aliases = list(sl.get("aliases") or [])
            if sl.get("pin") and sl["pin"] not in aliases:
                aliases.insert(0, sl["pin"])
            for net in sl.get("nets") or []:
                if net not in aliases:
                    aliases.append(net)
            hits = _match_live(aliases, live_names) if live_names else []
            for name in hits:
                matched_live.add(name)
            if hits:
                matched += 1
            rows.append({
                "vio": sl.get("vio") or "",
                "pin": sl.get("pin") or "",
                "direction": sl.get("direction") or "",
                "width": sl.get("width") or 1,
                "left": sl.get("left"),
                "right": sl.get("right"),
                "nets": sl.get("nets") or [],
                "aliases": aliases,
                "live": [live_by_name[n] for n in hits if n in live_by_name],
                "plugins": _refs_for_aliases(aliases, refs),
                "status": "matched" if hits else ("no_jtag" if not live else "unmatched"),
            })

        jtag_only = [row for row in live if row["name"] not in matched_live]
        summary = {
            "ltx_slices": len(rows),
            "jtag_probes": len(live),
            "jtag_cores": len(cores),
            "matched": matched,
            "ltx_only": sum(1 for r in rows if r["status"] == "unmatched"),
            "jtag_only": len(jtag_only),
            "no_jtag": sum(1 for r in rows if r["status"] == "no_jtag"),
        }
        return jsonify({
            "success": True,
            "ltx_path": ltx_path,
            "ltx_error": ltx_error,
            "device": device,
            "live_error": live_error,
            "cores": cores,
            "summary": summary,
            "rows": rows,
            "jtag_only": jtag_only,
            "output": live_output,
        })

    app.register_blueprint(bp)

    def _tree_node(device_node, device_name, _vio_nodes):
        device_node["children"].append({
            "type": "vio_match",
            "name": "LTX vs JTAG",
            "full": device_name,
            "plugin": "vio_match",
        })

    register_tree_hook("vio_match", _tree_node)
