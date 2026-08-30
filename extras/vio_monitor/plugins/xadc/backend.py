"""System Monitor (XADC) plugin backend."""
from flask import Blueprint, jsonify, request

from plugins.common.sysmon import parse_sysmon, tcl_dump_sysmon
from plugins.registry import register_tree_hook


def register(app, ctx, manifest):
    bp = Blueprint("plugin_xadc", __name__, url_prefix="/api/plugins/xadc")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]

    @bp.route("/data")
    def api_xadc_data():
        device = request.args.get("device", "").strip() or None
        with lock:
            result = run(tcl_dump_sysmon(device), timeout_override=120)
        return jsonify({
            "success": result.success,
            "output": result.output,
            "readings": parse_sysmon(result.output, parse_rows),
        })

    app.register_blueprint(bp)

    def _tree_sysmon_node(device_node, device_name, _vio_nodes):
        device_node["children"].append({
            "type": "sysmon",
            "name": "System Monitor (XADC)",
            "full": device_name,
            "plugin": "xadc",
        })

    register_tree_hook("xadc", _tree_sysmon_node)
