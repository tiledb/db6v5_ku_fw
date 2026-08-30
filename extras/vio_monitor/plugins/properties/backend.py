"""Device properties plugin backend."""
from flask import Blueprint, jsonify, request


def _tcl_device_properties(device):
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        'foreach __prop [lsort [list_property $__dev]] { '
        'if {[catch {set __val [get_property $__prop $__dev]} __err]} '
        '{ set __val "<error: $__err>" } ; '
        'puts "DEVPROP|$__prop|$__val" '
        '}'
    )


def register(app, ctx, manifest):
    bp = Blueprint("plugin_properties", __name__, url_prefix="/api/plugins/properties")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]
    require_open_target = ctx["require_open_target"]

    @bp.route("/data")
    def api_properties_data():
        device = request.args.get("device", "").strip()
        if not device:
            return jsonify({"success": False, "error": "device required"}), 400
        blocked = require_open_target()
        if blocked:
            return blocked
        with lock:
            result = run(_tcl_device_properties(device), timeout_override=60)
        properties = [
            {"name": row[0], "value": row[1]}
            for row in parse_rows(result.output, "DEVPROP", 3)
        ]
        return jsonify({
            "success": result.success,
            "device": device,
            "properties": properties,
            "output": result.output,
        })

    app.register_blueprint(bp)
