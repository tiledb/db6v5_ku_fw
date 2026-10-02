"""Scan the SFP+ A2h block RAM on both FPGAs.

``cfb_sfp_reg_address`` carries SFP+0 in bits 6:0 and SFP+1 in bits 14:8.
``stb_sfp_reg_readback`` returns the bytes in bits 23:16 and 31:24.
"""

import time

from flask import Blueprint, jsonify, request

from plugins.common.regs import reg
from plugins.registry import register_tree_hook


def _byte(word: int, shift: int) -> dict:
    raw = (int(word) >> shift) & 0xFF
    return {"raw": raw, "raw_hex": f"0x{raw:02X}", "raw_bin": f"{raw:08b}"}


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_sfp_i2c", __name__, url_prefix="/api/plugins/tilecal_sfp_i2c")
    session = ctx["session"]

    @bp.route("/data")
    def data():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        try:
            max_addr = int(request.args.get("max_addr", "31"))
        except ValueError:
            return jsonify({"success": False, "error": "max_addr must be an integer"}), 400
        max_addr = max(0, min(max_addr, 127))
        try:
            addr_reg = reg("rx", "cfb_sfp_reg_address")["hw_addr"]
            data_reg = reg("tx", "stb_sfp_reg_readback")["hw_addr"]
            entries = {"A": [], "B": []}
            with session.lock:
                for addr in range(max_addr + 1):
                    packed = (addr & 0x7F) | ((addr & 0x7F) << 8)
                    session.write_side("A", addr_reg, packed)
                    session.write_side("B", addr_reg, packed)
                    time.sleep(0.01)
                    words = session.read_both(data_reg)
                    for side_id, word in words.items():
                        entries[side_id].append({
                            "address": addr,
                            "address_hex": f"0x{addr:02X}",
                            "sfp0": _byte(word, 16),
                            "sfp1": _byte(word, 24),
                        })
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({"success": True, "max_addr": max_addr, "sides": entries})

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "tilecal_sfp_i2c",
            "name": "TileCal DB SFP+ I2C",
            "plugin": "tilecal_sfp_i2c",
        })

    register_tree_hook("tilecal_sfp_i2c", _tree)
