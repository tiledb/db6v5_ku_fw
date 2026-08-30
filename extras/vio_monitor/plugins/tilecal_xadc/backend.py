"""TileCal DB xADC plugin backend."""
from flask import Blueprint, jsonify, request

from plugins.common.sysmon import parse_sysmon, tcl_dump_sysmon
from plugins.common.vio_live import parse_live_xadc_probes, tcl_read_live_xadc_probes
from plugins.registry import register_tree_hook
from plugins.tilecal_xadc.conversion import (
    build_channels,
    merge_vio_scan,
    sysmon_to_raw_by_addr,
    _parse_raw,
)


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_xadc", __name__, url_prefix="/api/plugins/tilecal_xadc")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]

    @bp.route("/data")
    def api_tilecal_xadc_data():
        device = request.args.get("device", "").strip() or None
        readings = []
        sysmon_ok = True
        vio_ok = True
        live_addr = None
        live_raw = None

        with lock:
            sysmon_result = run(tcl_dump_sysmon(device), timeout_override=120)
        sysmon_ok = sysmon_result.success
        readings = parse_sysmon(sysmon_result.output, parse_rows)

        if device:
            with lock:
                vio_result = run(tcl_read_live_xadc_probes(device), timeout_override=15)
            vio_ok = vio_result.success
            addr_text, val_text = parse_live_xadc_probes(vio_result.output, parse_rows)
            live_addr = _parse_raw(addr_text)
            live_raw = _parse_raw(val_text)

        raw_by_addr, sources = sysmon_to_raw_by_addr(readings)
        live_scan = merge_vio_scan(
            raw_by_addr, sources, live_addr, live_raw, "vio_live",
        )
        channels = build_channels(raw_by_addr, sources)
        return jsonify({
            "success": sysmon_ok,
            "channels": channels,
            "live_scan": live_scan,
            "sysmon_ok": sysmon_ok,
            "vio_ok": vio_ok,
        })

    app.register_blueprint(bp)

    def _tree_node(device_node, device_name, _vio_nodes):
        device_node["children"].append({
            "type": "tilecal_xadc",
            "name": "TileCal DB xADC",
            "full": device_name,
            "plugin": "tilecal_xadc",
        })

    register_tree_hook("tilecal_xadc", _tree_node)
