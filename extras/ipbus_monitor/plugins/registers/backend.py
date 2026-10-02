"""Read the DB status bus (and write the config bus) on both FPGA sides."""

from flask import Blueprint, jsonify, request

from plugins.common.regs import describe, reg
from plugins.registry import register_tree_hook


def _parse_int(value, default=0):
    if value is None or value == "":
        return default
    if isinstance(value, int):
        return value
    text = str(value).strip().lower()
    return int(text, 0)


def register(app, ctx, manifest):
    bp = Blueprint("plugin_registers", __name__, url_prefix="/api/plugins/registers")
    session = ctx["session"]

    @bp.route("/map")
    def reg_map():
        from db_lib import public_register_map
        return jsonify(public_register_map())

    def _row(bus: str, name: str) -> dict:
        found = reg(bus, name)
        error = ""
        sides = {}
        try:
            values = session.read_both(found["hw_addr"])
            if bus == "xadc":
                values = {side_id: int(value) & 0xFFFF for side_id, value in values.items()}
            sides = {side_id: describe(found, value) for side_id, value in values.items()}
        except Exception as exc:
            error = str(exc)
        return {
            "name": found["name"],
            "addr_hex": f"0x{found['hw_addr']:03X}",
            "note": found.get("note") or "",
            "writable": bool(found.get("writable")),
            "fields": found.get("fields") or [],
            "sides": sides,
            "error": error,
        }

    @bp.route("/scan")
    def scan():
        """Every tx and xADC register on side A and side B, plus the rx catalogue."""
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        from db_lib import public_register_map
        catalog = public_register_map()
        try:
            with session.lock:
                tx = [_row("tx", item["name"]) for item in catalog["tx"]]
                xadc = [_row("xadc", item["name"]) for item in catalog["xadc"]]
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({
            "success": True,
            "md": session.md,
            "rx": catalog["rx"],
            "tx": tx,
            "xadc": xadc,
        })

    @bp.route("/read")
    def read():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        bus = (request.args.get("bus") or "tx").strip().lower()
        name = (request.args.get("name") or "").strip()
        if bus not in ("tx", "rx", "xadc"):
            return jsonify({"success": False, "error": "bus must be tx, rx, or xadc"}), 400
        if not name:
            return jsonify({"success": False, "error": "name required"}), 400
        try:
            found = reg(bus, name)
            addr = found["hw_addr"]
            with session.lock:
                if bus == "xadc":
                    values = session.read_both(addr)
                elif bus == "tx":
                    values = session.read_both(addr)
                else:
                    return jsonify({
                        "success": False,
                        "error": "Configbus registers are write-only over IPBus. Read the matching status register.",
                    }), 400
                sides = {side_id: describe(found, value) for side_id, value in values.items()}
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({
            "success": True,
            "name": found["name"],
            "addr_hex": f"0x{found['hw_addr']:03X}",
            "note": found.get("note") or "",
            "sides": sides,
        })

    @bp.route("/write", methods=["POST"])
    def write():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        body = request.get_json(silent=True) or {}
        side = str(body.get("side") or "").strip().upper()
        if side not in ("A", "B", "BOTH"):
            return jsonify({"success": False, "error": "side must be A, B, or both"}), 400
        name = str(body.get("name") or "").strip()
        targets = ["A", "B"] if side == "BOTH" else [side]
        try:
            found = reg("rx", name)
            value = _parse_int(body.get("value"), 0) & 0xFFFFFFFF
            with session.lock:
                for target in targets:
                    session.write_side(target, found["hw_addr"], value)
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({
            "success": True,
            "side": side,
            "sides": targets,
            "name": found["name"],
            "addr_hex": f"0x{found['hw_addr']:03X}",
            "value": f"0x{value:08X}",
        })

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "registers",
            "name": "Registers",
            "plugin": "registers",
        })

    register_tree_hook("registers", _tree)
