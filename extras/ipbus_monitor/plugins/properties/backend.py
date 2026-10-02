"""PPr link status plus daughterboard status registers, both FPGA sides."""

import time

from flask import Blueprint, jsonify, request

from plugins.common.regs import read_named, reg
from plugins.common.session import word
from plugins.registry import register_tree_hook

_STATUS = (
    "stb_db_fwversion",
    "stb_global_date",
    "stb_global_time",
    "stb_running_time_status",
    "stb_dna_2",
    "stb_dna_1",
    "stb_dna_0",
    "stb_db_status",
    "stb_pgood_reg",
    "stb_adc_readout_status",
    "stb_sfp0_reg",
    "stb_sfp1_reg",
)

# PPr GBT status: one 32-bit word per FPGA side, link 0 in 15:0 and link 1 in 31:16.
# The half-word split matches PPr.get_links_status_bits.
_OPTICAL = (
    {"md": 0, "status": {"A": 0x10, "B": 0x11}, "frames": (0x21, 0x22),
     "crc": {"A0": 0x23, "A1": 0x24, "B0": 0x25, "B1": 0x26}, "total": {"A": 0x27, "B": 0x28}},
    {"md": 1, "status": {"A": 0x12, "B": 0x13}, "frames": (0x29, 0x2A),
     "crc": {"A0": 0x2B, "A1": 0x2C, "B0": 0x2D, "B1": 0x2E}, "total": {"A": 0x2F, "B": 0x30}},
    {"md": 2, "status": {"A": 0x14, "B": 0x15}, "frames": (0x31, 0x32),
     "crc": {"A0": 0x33, "A1": 0x34, "B0": 0x35, "B1": 0x36}, "total": {"A": 0x37, "B": 0x38}},
    {"md": 3, "status": {"A": 0x16, "B": 0x17}, "frames": (0x39, 0x3A),
     "crc": {"A0": 0x3B, "A1": 0x3C, "B0": 0x3D, "B1": 0x3E}, "total": {"A": 0x3F, "B": 0x40}},
)


def _link_half(word: int, link: int) -> dict:
    half = ((word >> 16) if link else word) & 0xFFFF
    return {
        "b0": half & 1,
        "b1": (half >> 1) & 1,
        "b2": (half >> 2) & 1,
        "b3": (half >> 3) & 1,
        "bits_9_4": (half >> 4) & 0x3F,
        "b10": (half >> 10) & 1,
        "b11": (half >> 11) & 1,
        "b12": (half >> 12) & 1,
    }


def _optical(session) -> list:
    rows = []
    for spec in _OPTICAL:
        frames = (word(session.ppr_read(spec["frames"][1])) << 32) | word(session.ppr_read(spec["frames"][0]))
        crc = {name: word(session.ppr_read(addr)) for name, addr in spec["crc"].items()}
        total = {name: word(session.ppr_read(addr)) for name, addr in spec["total"].items()}
        links = []
        for side_id, addr in spec["status"].items():
            raw = word(session.ppr_read(addr))
            for link in (0, 1):
                key = f"{side_id}{link}"
                links.append({
                    "id": key,
                    "side": side_id,
                    "link": link,
                    "raw_hex": f"0x{raw:08X}",
                    "bits": _link_half(raw, link),
                    "crc": crc[key],
                    "crc_total": total[side_id],
                })
        rows.append({
            "md": spec["md"],
            "selected": spec["md"] == session.md,
            "frames": str(frames),
            "links": links,
        })
    return rows


def register(app, ctx, manifest):
    bp = Blueprint("plugin_properties", __name__, url_prefix="/api/plugins/properties")
    session = ctx["session"]

    @bp.route("/data")
    def data():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        try:
            with session.lock:
                firmware = word(session.ppr_read(0x1))
                optical = _optical(session)
                registers = [read_named(session, "tx", name) for name in _STATUS]
                strobe = reg("rx", "cfb_strobe_reg")
                resets = [
                    {"name": field["name"], "bit": field["lsb"]}
                    for field in strobe["fields"]
                    if field["msb"] == field["lsb"]
                ]
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({
            "success": True,
            "md": session.md,
            "ppr_ip": session.ppr_ip,
            "firmware": f"0x{firmware:08X}",
            "optical": optical,
            "registers": registers,
            "resets": resets,
        })

    @bp.route("/reset", methods=["POST"])
    def reset():
        """Pulse one ``cfb_strobe_reg`` bit, then clear the register."""
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        body = request.get_json(silent=True) or {}
        side = str(body.get("side") or "both").strip().upper()
        if side == "BOTH":
            targets = ["A", "B"]
        elif side in ("A", "B"):
            targets = [side]
        else:
            return jsonify({"success": False, "error": "side must be A, B, or both"}), 400
        try:
            bit = int(body.get("bit"))
        except (TypeError, ValueError):
            return jsonify({"success": False, "error": "bit required"}), 400
        try:
            strobe = reg("rx", "cfb_strobe_reg")
            known = {field["lsb"] for field in strobe["fields"] if field["msb"] == field["lsb"]}
            if bit not in known:
                return jsonify({"success": False, "error": "unknown reset bit"}), 400
            name = next(field["name"] for field in strobe["fields"] if field["lsb"] == bit)
            with session.lock:
                for target in targets:
                    session.write_side(target, strobe["hw_addr"], 1 << bit)
                time.sleep(0.05)
                for target in targets:
                    session.write_side(target, strobe["hw_addr"], 0)
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({"success": True, "name": name, "bit": bit, "sides": targets})

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "properties",
            "name": "Properties",
            "plugin": "properties",
        })

    register_tree_hook("properties", _tree)
