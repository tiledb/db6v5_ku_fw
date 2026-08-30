"""VIO probes plugin backend."""
from flask import Blueprint, jsonify, request

from plugins.registry import register_tree_hook

_VIO_PROBE_READ_LOOP = (
    'foreach __p [get_hw_probes -of_objects $__vio] { '
    'catch { refresh_hw_probe $__p } ; '
    'set __pname [get_property NAME $__p] ; '
    'set __dir "IN" ; '
    'set __val "" ; '
    'set __act "" ; '
    'if {![catch {set __ptype [get_property PROBE_TYPE $__p]}] && $__ptype eq "OUTPUT"} { '
    'set __dir "OUT" ; catch {set __val [get_property OUTPUT_VALUE $__p]} '
    '} else { catch {set __val [get_property INPUT_VALUE $__p]} ; '
    'catch {set __act [get_property ACTIVITY_VALUE $__p]} ; '
    'if {$__val eq ""} { set __dir "OUT" ; catch {set __val [get_property OUTPUT_VALUE $__p]} } } ; '
    'if {$__val eq ""} { set __val "N/A" ; set __dir "UNKNOWN" } ; '
    'if {$__act eq ""} { set __act "-" } ; '
    'puts "VIOROW|$__dev|$__vname|$__pname|$__dir|$__val|$__act" '
    '} '
)

_DUMP_VIOS_TCL = (
    'foreach __dev [get_hw_devices] { '
    'current_hw_device $__dev ; '
    'refresh_hw_device -update_hw_probes true $__dev ; '
    'set __vios [get_hw_vios -of_objects $__dev] ; '
    'if {[llength $__vios] > 0} { refresh_hw_vio $__vios } ; '
    'foreach __vio $__vios { '
    'set __vname [get_property NAME $__vio] ; '
    + _VIO_PROBE_READ_LOOP +
    '} }'
)


def _tcl_dump_vios(device=None):
    if not device:
        return _DUMP_VIOS_TCL
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        'current_hw_device $__dev ; '
        'refresh_hw_device -update_hw_probes true $__dev ; '
        'set __vios [get_hw_vios -of_objects $__dev] ; '
        'if {[llength $__vios] > 0} { refresh_hw_vio $__vios } ; '
        'foreach __vio $__vios { '
        'set __vname [get_property NAME $__vio] ; '
        + _VIO_PROBE_READ_LOOP +
        '}'
    )


def _parse_vios(output, parse_rows):
    vios = {}
    for row in parse_rows(output, "VIOROW", 7):
        device, vio, probe, direction, value, activity = row
        key = f"{device} / {vio}"
        vios.setdefault(key, []).append(
            {
                "probe": probe,
                "direction": direction,
                "value": value,
                "activity": activity,
            }
        )
    return vios


def register(app, ctx, manifest):
    bp = Blueprint("plugin_vio", __name__, url_prefix="/api/plugins/vio")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]

    @bp.route("/data")
    def api_vio_data():
        device = request.args.get("device", "").strip() or None
        with lock:
            result = run(_tcl_dump_vios(device), timeout_override=60)
        return jsonify({
            "success": result.success,
            "output": result.output,
            "vios": _parse_vios(result.output, parse_rows),
        })

    app.register_blueprint(bp)

    def _tree_vio_nodes(device_node, device_name, vio_nodes):
        vios_by_device = {}
        for row in vio_nodes:
            dev, vio_name = row
            vios_by_device.setdefault(dev, []).append(vio_name)
        for vio in vios_by_device.get(device_name, []):
            device_node["children"].append({
                "type": "vio",
                "name": vio,
                "full": f"{device_name}/{vio}",
                "plugin": "vio",
            })

    register_tree_hook(_tree_vio_nodes)
