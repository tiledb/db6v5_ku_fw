"""PPr pipeline HG/LG for both FPGAs of one mini-drawer.

The VIO plugin muxes 6 channels on the single FPGA attached to that JTAG
chain. The pipeline RAM has 12 ADCs per mini-drawer: 0–5 on side A and
6–11 on side B (``DBReg.FPGA`` 1/3 then 0/2). Samples are the 12-bit
pipeline words, not the 14-bit VIO debug mux, and there is no frame-clock tap.

``cfb_db_inject_pulse`` bit 0 enables the orbit RAM injection (ORed with the
VIO enable). ``stb_db_inject_ram_rdata`` bit 14 is the live active flag.

Pipeline capture needs the PPr L1A sequence: deadtime armed once at connect,
then each readout reads LAST_EVT_BCID/L1ID (releases busy) and
``send_L1A(bcr, 3)`` before ``get_data_HG`` / ``get_data_LG``.
"""

from flask import Blueprint, jsonify, request

from plugins.common.regs import reg
from plugins.registry import register_tree_hook

_SIDES = {"A": range(0, 6), "B": range(6, 12)}


def _sides(value: str) -> list[str]:
    side = (value or "both").strip().upper()
    if side == "BOTH":
        return ["A", "B"]
    if side in ("A", "B"):
        return [side]
    raise ValueError("side must be A, B, or both")


def _inject_status(session) -> dict:
    found = reg("tx", "stb_db_inject_ram_rdata")
    values = session.read_both(found["hw_addr"])
    out = {}
    for side_id, raw in values.items():
        word = int(raw) & 0xFFFFFFFF
        out[side_id] = {
            "raw_hex": f"0x{word:08X}",
            "active": bool(word & (1 << 14)),
            "ram_rdata": word & 0x3FFF,
            "word_active": (word >> 15) & 0x3FFF,
        }
    return out


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_data_readout", __name__, url_prefix="/api/plugins/tilecal_data_readout")
    session = ctx["session"]

    @bp.route("/inject", methods=["POST"])
    def inject():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        body = request.get_json(silent=True) or {}
        try:
            targets = _sides(str(body.get("side") or "both"))
        except ValueError as exc:
            return jsonify({"success": False, "error": str(exc)}), 400
        enable = 1 if body.get("enable") else 0
        try:
            found = reg("rx", "cfb_db_inject_pulse")
            with session.lock:
                for side_id in targets:
                    # Bit 0 only. Leaving ram_we at 0 avoids a write-toggle edge.
                    session.write_side(side_id, found["hw_addr"], enable)
                status = _inject_status(session)
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({"success": True, "enable": bool(enable), "sides": targets, "inject": status})

    @bp.route("/data")
    def data():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        try:
            samples = int(request.args.get("samples", "16"))
            bcr = int(request.args.get("bcr", "16"))
        except ValueError:
            return jsonify({"success": False, "error": "samples and bcr must be integers"}), 400
        samples = max(1, min(samples, 32))
        # Pipeline of N samples at L1A BCID maps onto window slots (BCR−N)…(BCR−1).
        if bcr < samples or bcr > 0xFFF:
            return jsonify({
                "success": False,
                "error": f"BCR must be {samples}..4095 (BCR ≥ sample count)",
            }), 400
        from db_ppr_ipbus import DBReg
        try:
            with session.lock:
                triggered = session.trigger_readout(bcr)
                sides = {}
                for side_id, adcs in _SIDES.items():
                    channels = []
                    for adc in adcs:
                        channels.append({
                            "adc": adc,
                            "fpga": DBReg.FPGA[adc],
                            "fpga_channel": DBReg.FPGA_CHANNEL[adc],
                            "hg": session.pipeline(adc, samples, "hg"),
                            "lg": session.pipeline(adc, samples, "lg"),
                        })
                    sides[side_id] = channels
                inject = _inject_status(session)
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({
            "success": True,
            "md": session.md,
            "samples": samples,
            "bcr": triggered,
            "sides": sides,
            "inject": inject,
        })

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "tilecal_data_readout",
            "name": "TileCal ADC Data Readout",
            "plugin": "tilecal_data_readout",
        })

    register_tree_hook("tilecal_data_readout", _tree)
