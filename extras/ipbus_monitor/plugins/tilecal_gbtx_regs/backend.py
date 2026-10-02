"""Scan GBTx register RAMs on both daughterboard FPGAs.

Write ``cfb_gbtx_reg_readback_address`` bits 8:0, then read:
- ``stb_gbtx_reg_readback`` — bits 8:0 address echo, bits 16:9 actual I2C byte
- ``stb_gbtx_config_readback`` — same echo, bits 16:9 intended/shadow write byte

Walking the BRAM alone does **not** trigger an I2C transaction. Status /
read-only registers (366–435) are only refreshed after an I2C **read** sweep
via ``cfb_gbtx_reg_config`` (bit26=read, bit27=trigger pulse, bit29=control).
"""

from __future__ import annotations

import time

from flask import Blueprint, jsonify, request

from plugins.common.regs import reg
from plugins.registry import register_tree_hook
from plugins.tilecal_gbtx_regs.register_map import annotate_rows

# Firmware read sweep: start=0, end=435 when gbtx_i2c_rw=1
# Firmware write sweep: start=0, end=366 when gbtx_i2c_rw=0
READOUT_LAST = 435
CONFIG_LAST = 365
STATUS_FIRST = 366
BRAM_LAST = 511

# cfb_gbtx_reg_config control bits (see db6_design_package.vhd)
_BIT_I2C_RW = 26
_BIT_TRIGGER = 27
_BIT_CONTROL = 29

# Full 0..435 I2C sequential read is slow; allow override via query.
_DEFAULT_I2C_WAIT_S = 5.0


def _byte_field(word: int, lsb: int = 9) -> dict:
    raw = (int(word) >> lsb) & 0xFF
    return {"raw": raw, "raw_hex": f"0x{raw:02X}", "raw_bin": f"{raw:08b}"}


def _addr_echo(word: int) -> int:
    return int(word) & 0x1FF


def _trigger_i2c_read(session, cfg_addr: int, wait_s: float) -> None:
    """Pulse a GBTx I2C read sweep (0..435) on both FPGAs.

    Requires bit29 (gbtx_control) so configbus drives the I2C SM, bit26=1 for
    read, and a rising edge on bit27 (debounced in firmware).
    """
    base = (1 << _BIT_CONTROL) | (1 << _BIT_I2C_RW)
    armed = base | (1 << _BIT_TRIGGER)
    for side in ("A", "B"):
        session.write_side(side, cfg_addr, base)
    time.sleep(0.05)
    for side in ("A", "B"):
        session.write_side(side, cfg_addr, armed)
    time.sleep(0.05)
    for side in ("A", "B"):
        session.write_side(side, cfg_addr, base)
    time.sleep(max(0.5, float(wait_s)))


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_gbtx_regs", __name__, url_prefix="/api/plugins/tilecal_gbtx_regs")
    session = ctx["session"]

    @bp.route("/data")
    def data():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        try:
            min_addr = int(request.args.get("min_addr", "0"))
            max_addr = int(request.args.get("max_addr", str(READOUT_LAST)))
            trigger = request.args.get("trigger_i2c", "0") in ("1", "true", "yes")
            wait_s = float(request.args.get("i2c_wait_s", str(_DEFAULT_I2C_WAIT_S)))
        except ValueError:
            return jsonify({"success": False, "error": "min_addr/max_addr/i2c_wait_s must be numeric"}), 400
        min_addr = max(0, min(min_addr, BRAM_LAST))
        max_addr = max(min_addr, min(max_addr, BRAM_LAST))
        try:
            addr_reg = reg("rx", "cfb_gbtx_reg_readback_address")["hw_addr"]
            actual_reg = reg("tx", "stb_gbtx_reg_readback")["hw_addr"]
            config_reg = reg("tx", "stb_gbtx_config_readback")["hw_addr"]
            cfg_reg = reg("rx", "cfb_gbtx_reg_config")["hw_addr"]
            entries = {"A": [], "B": []}
            with session.lock:
                if trigger:
                    _trigger_i2c_read(session, cfg_reg, wait_s)
                for addr in range(min_addr, max_addr + 1):
                    session.write_side("A", addr_reg, addr & 0x1FF)
                    session.write_side("B", addr_reg, addr & 0x1FF)
                    time.sleep(0.01)
                    actuals = session.read_both(actual_reg)
                    configs = session.read_both(config_reg)
                    for side_id in ("A", "B"):
                        actual_w = actuals[side_id]
                        config_w = configs[side_id]
                        actual = _byte_field(actual_w)
                        config = _byte_field(config_w)
                        entries[side_id].append({
                            "address": addr,
                            "address_hex": f"0x{addr:03X}",
                            "address_label": f"0x{addr:03X} ({addr})",
                            "addr_echo_actual": _addr_echo(actual_w),
                            "addr_echo_config": _addr_echo(config_w),
                            "actual": actual,
                            "config": config,
                            "match": actual["raw"] == config["raw"],
                        })
            for side_id in entries:
                entries[side_id] = annotate_rows(entries[side_id])
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({
            "success": True,
            "min_addr": min_addr,
            "max_addr": max_addr,
            "trigger_i2c": trigger,
            "i2c_wait_s": wait_s if trigger else 0,
            "spec": (
                "GBTX Manual Ch.17. "
                + (
                    "Triggered I2C read sweep (0–435) before BRAM dump."
                    if trigger else
                    "BRAM dump only — no I2C trigger (shows last captured snapshot)."
                )
            ),
            "sides": entries,
        })

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "tilecal_gbtx_regs",
            "name": "TileCal DB GBTx Registers",
            "plugin": "tilecal_gbtx_regs",
        })

    register_tree_hook("tilecal_gbtx_regs", _tree)
