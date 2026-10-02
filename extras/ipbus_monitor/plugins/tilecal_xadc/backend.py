"""xADC DRP scan over the slow-control address 0xA00|drp, both FPGAs."""

from flask import Blueprint, jsonify

from plugins.registry import register_tree_hook


def _channels(words_by_idx):
    from db_lib import (
        lut_xadc_address,
        lut_xadc_address_labels,
        lut_xadc_dimensions,
        lut_xadc_fa,
        lut_xadc_fb,
        lut_xadc_fg,
        lut_xadc_fg_dimensions,
    )

    channels = []
    for idx, addr in enumerate(lut_xadc_address):
        sides = {}
        for side_id, raw in words_by_idx[idx].items():
            code = None if raw is None else (int(raw) & 0xFFFF)
            if code is None:
                analog = current = None
            else:
                analog = code * float(lut_xadc_fa[idx]) + float(lut_xadc_fb[idx])
                current = analog * float(lut_xadc_fg[idx]) if float(lut_xadc_fg[idx]) != 1 else None
            sides[side_id] = {
                "raw": code,
                "raw_hex": "—" if code is None else f"0x{code:04X}",
                "analog": analog,
                "analog_unit": str(lut_xadc_dimensions[idx]).strip(),
                "current": current,
                "current_unit": str(lut_xadc_fg_dimensions[idx]).strip(),
                "has_current": float(lut_xadc_fg[idx]) != 1,
            }
        channels.append({
            "label": lut_xadc_address_labels[idx],
            "address_hex": f"0x{addr:02X}",
            "sides": sides,
        })
    return channels


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_xadc", __name__, url_prefix="/api/plugins/tilecal_xadc")
    session = ctx["session"]

    @bp.route("/data")
    def data():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        from db_lib import lut_xadc_address
        try:
            with session.lock:
                words = []
                for addr in lut_xadc_address:
                    words.append(session.read_both(0xA00 | int(addr)))
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({"success": True, "channels": _channels(words)})

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "tilecal_xadc",
            "name": "TileCal DB xADC",
            "plugin": "tilecal_xadc",
        })

    register_tree_hook("tilecal_xadc", _tree)
