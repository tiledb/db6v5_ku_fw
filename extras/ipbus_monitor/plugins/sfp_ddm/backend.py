"""SFP+ DDM for both daughterboard FPGAs."""

from flask import Blueprint, jsonify

from plugins.common.regs import reg
from plugins.registry import register_tree_hook
from plugins.sfp_ddm.conversion import FIELDS, decode_word


def register(app, ctx, manifest):
    bp = Blueprint("plugin_sfp_ddm", __name__, url_prefix="/api/plugins/sfp_ddm")
    session = ctx["session"]

    @bp.route("/data")
    def data():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        try:
            with session.lock:
                sides = {"A": [], "B": []}
                for field in FIELDS:
                    found = reg("tx", field["stb"])
                    words = session.read_both(found["hw_addr"])
                    for side_id, word in words.items():
                        sides[side_id].append({
                            "field_id": field["id"],
                            "label": field["label"],
                            "spec": field["spec"],
                            "addr_hex": f"0x{found['hw_addr']:03X}",
                            "sfps": decode_word(field, word),
                        })
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({"success": True, "sides": sides})

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "sfp_ddm",
            "name": "TileCal DB SFP+ DDM",
            "plugin": "sfp_ddm",
        })

    register_tree_hook("sfp_ddm", _tree)
