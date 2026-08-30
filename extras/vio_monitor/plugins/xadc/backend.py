"""System Monitor (XADC) plugin backend."""
from flask import Blueprint, jsonify, request

from plugins.registry import register_tree_hook


def _tcl_dump_sysmon(device=None):
    dev_filter = (
        f'set __devs [list [get_hw_devices {{{device}}}]] ; '
        if device else
        'set __devs [get_hw_devices] ; '
    )
    return (
        dev_filter +
        'foreach __dev $__devs { '
        'current_hw_device $__dev ; '
        'set __sms [get_hw_sysmons -of_objects $__dev] ; '
        'if {[llength $__sms] > 0} { catch { refresh_hw_sysmon $__sms } } ; '
        'foreach __sm $__sms { '
        'set __sname [get_property NAME $__sm] ; '
        'foreach __prop [lsort [list_property $__sm]] { '
        'if {![catch {set __val [get_property $__prop $__sm]}]} { '
        'puts "SYSMONROW|$__dev|$__sname|$__prop|$__val" '
        '} } } }'
    )


def _parse_sysmon(output, parse_rows):
    rows = []
    for row in parse_rows(output, "SYSMONROW", 5):
        device, sysmon, prop, value = row
        rows.append({
            "device": device,
            "sysmon": sysmon,
            "property": prop,
            "value": value,
        })
    return rows


def register(app, ctx, manifest):
    bp = Blueprint("plugin_xadc", __name__, url_prefix="/api/plugins/xadc")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]

    @bp.route("/data")
    def api_xadc_data():
        device = request.args.get("device", "").strip() or None
        with lock:
            result = run(_tcl_dump_sysmon(device), timeout_override=120)
        return jsonify({
            "success": result.success,
            "output": result.output,
            "readings": _parse_sysmon(result.output, parse_rows),
        })

    app.register_blueprint(bp)

    def _tree_sysmon_node(device_node, device_name, _vio_nodes):
        device_node["children"].append({
            "type": "sysmon",
            "name": "System Monitor (XADC)",
            "full": device_name,
            "plugin": "xadc",
        })

    register_tree_hook(_tree_sysmon_node)
