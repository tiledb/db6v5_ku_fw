"""SFP+ DDM plugin backend."""
from flask import Blueprint, jsonify, request

from plugins.common.probe_config import plugin_probes, split_sfp_ddm_probes
from plugins.registry import register_tree_hook
from plugins.sfp_ddm.conversion import build_ddm_table


def tcl_read_sfp_ddm_probes(device, probes=None):
    """Read all VIO input probes; DDM fields classified in Python."""
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        'current_hw_device $__dev ; '
        'foreach __vio [get_hw_vios -of_objects $__dev] { '
        'foreach __p [get_hw_probes -of_objects $__vio] { '
        'set __pname [get_property NAME $__p] ; '
        'set __dir "IN" ; '
        'set __val "" ; '
        'if {![catch {set __ptype [get_property PROBE_TYPE $__p]}] && $__ptype eq "OUTPUT"} { '
        'set __dir "OUT" ; catch {set __val [get_property OUTPUT_VALUE $__p]} '
        '} else { catch { refresh_hw_probe $__p } ; '
        'catch {set __val [get_property INPUT_VALUE $__p]} ; '
        'if {$__val eq ""} { set __dir "OUT" ; catch {set __val [get_property OUTPUT_VALUE $__p]} } } ; '
        'if {$__val eq ""} { set __val "N/A" } ; '
        'puts "SFPDDM|$__pname|$__dir|$__val" '
        '} }'
    )


def _parse_sfp_ddm(output, parse_rows):
    rows = []
    for row in parse_rows(output, "SFPDDM", 4):
        probe, direction, value = row
        rows.append({
            "probe": probe,
            "direction": direction,
            "value": value,
        })
    return rows


def register(app, ctx, manifest):
    bp = Blueprint("plugin_sfp_ddm", __name__, url_prefix="/api/plugins/sfp_ddm")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]
    require_open_target = ctx["require_open_target"]
    load_config = ctx["load_config"]

    @bp.route("/data")
    def api_sfp_ddm_data():
        device = request.args.get("device", "").strip()
        if not device:
            return jsonify({"success": False, "error": "device required"}), 400
        blocked = require_open_target()
        if blocked:
            return blocked

        all_probes = plugin_probes(manifest, load_config())
        explicit, ddm_pattern = split_sfp_ddm_probes(all_probes)

        with lock:
            result = run(tcl_read_sfp_ddm_probes(device), timeout_override=60)

        probe_rows = _parse_sfp_ddm(result.output, parse_rows)
        table = build_ddm_table(
            probe_rows,
            ddm_pattern=ddm_pattern,
            explicit_probes=explicit,
        )
        return jsonify({
            "success": result.success,
            "device": device,
            "table": table,
            "output": result.output,
        })

    app.register_blueprint(bp)

    def _tree_node(device_node, device_name, _vio_nodes):
        device_node["children"].append({
            "type": "sfp_ddm",
            "name": "TileCal DB SFP+ DDM",
            "full": device_name,
            "plugin": "sfp_ddm",
        })

    register_tree_hook("sfp_ddm", _tree_node)
