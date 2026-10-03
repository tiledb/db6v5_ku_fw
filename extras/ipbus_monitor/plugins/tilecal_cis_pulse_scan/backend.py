"""TileCal CIS Phase Scan via ``cfb_mb_phase_config``.

Firmware (``db6_cis_interface_hss_io.vhd``):
  - ``c_range = 32`` steps cover one 25 ns BC period (step = 25/32 ns).
  - Q0 phase = bits [11:7], Q1 phase = bits [27:23].
  - Increasing the register phase pushes the CIS clock/edge forward, so the
    reconstructed time axis uses the reversed offset
    ``(31 - phase) * 25/32`` ns.

For each phase step the panel configures CIS (once), writes the phase word,
fires L1A, and reads HG/LG pipelines. Samples are returned both per-phase and
merged onto ``t_ns = sample_index * 25 + (31 - phase) * 25/32``.
"""

from __future__ import annotations

import time

from flask import Blueprint, jsonify, request

from plugins.registry import register_tree_hook
from plugins.tilecal_cis.backend import (
    _capacitor_gain,
    _configure_cis,
    _dbside,
    analyze_pulse,
)

_SIDES = {"A": range(0, 6), "B": range(6, 12)}
_NCHAN = 12
_PHASE_STEPS = 32
_BC_NS = 25.0
_PHASE_STEP_NS = _BC_NS / _PHASE_STEPS


def _phase_word(phase: int) -> int:
    """Pack identical Q0/Q1 CIS HSS phase into ``cfb_mb_phase_config``."""
    p = int(phase) & 0x1F
    return (p << 23) | (p << 7)


def _phase_offset_ns(phase: int) -> float:
    """Time offset for a register phase (reversed: higher phase → earlier)."""
    return (_PHASE_STEPS - 1 - (int(phase) & 0x1F)) * _PHASE_STEP_NS


def _phase_list(start: int, stop: int, step: int) -> list[int]:
    start = max(0, min(int(start), _PHASE_STEPS - 1))
    stop = max(0, min(int(stop), _PHASE_STEPS - 1))
    step = max(1, min(int(step), _PHASE_STEPS - 1))
    if stop < start:
        start, stop = stop, start
    return list(range(start, stop + 1, step))


def _merge_channel(adc: int, fpga: int, fpga_channel: int, phase_rows: list[dict],
                   ped_samples: int) -> dict:
    """Interleave per-phase HG/LG samples onto a common time axis."""
    hg_pts = []
    lg_pts = []
    for row in phase_rows:
        phase = int(row["phase"])
        offset_ns = _phase_offset_ns(phase)
        for i, v in enumerate(row.get("hg") or []):
            hg_pts.append({
                "t_ns": i * _BC_NS + offset_ns,
                "v": v,
                "sample": i,
                "phase": phase,
                "phase_ns": offset_ns,
            })
        for i, v in enumerate(row.get("lg") or []):
            lg_pts.append({
                "t_ns": i * _BC_NS + offset_ns,
                "v": v,
                "sample": i,
                "phase": phase,
                "phase_ns": offset_ns,
            })
    hg_pts.sort(key=lambda p: (p["t_ns"], p["phase"], p["sample"]))
    lg_pts.sort(key=lambda p: (p["t_ns"], p["phase"], p["sample"]))
    return {
        "adc": adc,
        "fpga": fpga,
        "fpga_channel": fpga_channel,
        "hg": hg_pts,
        "lg": lg_pts,
        "metrics": {
            "hg": analyze_pulse([p["v"] for p in hg_pts], pedestal_samples=ped_samples),
            "lg": analyze_pulse([p["v"] for p in lg_pts], pedestal_samples=ped_samples),
        },
    }


def register(app, ctx, manifest):
    bp = Blueprint(
        "plugin_tilecal_cis_pulse_scan",
        __name__,
        url_prefix="/api/plugins/tilecal_cis_pulse_scan",
    )
    session = ctx["session"]

    @bp.route("/data", methods=["GET", "POST"])
    def data():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked

        body = request.get_json(silent=True) or {}
        src = body if request.method == "POST" else request.args

        try:
            samples = int(src.get("samples", 16))
            bcr = int(src.get("bcr", 2256))
            dac_charge = int(src.get("dac_charge", src.get("pulse_height", 2000)))
            adc_ped = int(src.get("adc_pedestal", src.get("adc_ped", 100)))
            bcid_charge = int(src.get("bcid_charge", 500))
            bcid_discharge = int(src.get("bcid_discharge", 2200))
            capacitor = _capacitor_gain(str(src.get("capacitor", src.get("gain", "hg"))))
            dbside = _dbside(str(src.get("dbside", "both")))
            configure = str(src.get("configure", "1")).lower() not in ("0", "false", "no")
            ped_samples = int(src.get("pedestal_samples", 4))
            phase_start = int(src.get("phase_start", 0))
            phase_stop = int(src.get("phase_stop", _PHASE_STEPS - 1))
            phase_step = int(src.get("phase_step", 1))
        except (TypeError, ValueError) as exc:
            return jsonify({"success": False, "error": str(exc)}), 400

        samples = max(1, min(samples, 32))
        dac_charge = max(0, min(dac_charge, 4095))
        adc_ped = max(0, min(adc_ped, 4095))
        bcid_charge = max(0, min(bcid_charge, 0xFFF))
        bcid_discharge = max(0, min(bcid_discharge, 0xFFF))
        ped_samples = max(1, min(ped_samples, samples - 2 if samples > 2 else 1))
        phases = _phase_list(phase_start, phase_stop, phase_step)
        if not phases:
            return jsonify({"success": False, "error": "empty phase list"}), 400
        if bcr < samples or bcr > 0xFFF:
            return jsonify({
                "success": False,
                "error": f"BCR must be {samples}..4095 (BCR ≥ sample count)",
            }), 400

        from db_lib import cfb_mb_phase_config, lut_cfgbus_address
        from db_ppr_ipbus import DBReg, FEB

        phase_hw = int(lut_cfgbus_address[cfb_mb_phase_config]) & 0xFFFF

        try:
            with session.lock:
                if session.ppr is None:
                    raise RuntimeError("IPBus is not connected")
                feb = FEB(session.ppr)
                md = int(session.md)

                if configure:
                    session.ppr.set_global_TTC_internal()
                    _configure_cis(
                        feb, md, dbside,
                        dac_charge=dac_charge,
                        capacitor=capacitor,
                        adc_ped=adc_ped,
                        bcid_charge=bcid_charge,
                        bcid_discharge=bcid_discharge,
                    )

                per_adc: dict[int, list[dict]] = {adc: [] for adc in range(_NCHAN)}
                phase_summaries = []

                for phase in phases:
                    word = _phase_word(phase)
                    session.write_side("A", phase_hw, word)
                    session.write_side("B", phase_hw, word)
                    time.sleep(0.02)

                    triggered = session.trigger_readout(bcr)
                    offset_ns = _phase_offset_ns(phase)
                    phase_sides = {}
                    for side_id, adcs in _SIDES.items():
                        channels = []
                        for adc in adcs:
                            hg = session.pipeline(adc, samples, "hg")
                            lg = session.pipeline(adc, samples, "lg")
                            row = {
                                "adc": adc,
                                "fpga": DBReg.FPGA[adc],
                                "fpga_channel": DBReg.FPGA_CHANNEL[adc],
                                "phase": phase,
                                "phase_ns": offset_ns,
                                "hg": hg,
                                "lg": lg,
                            }
                            channels.append(row)
                            per_adc[adc].append(row)
                        phase_sides[side_id] = channels
                    phase_summaries.append({
                        "phase": phase,
                        "phase_ns": offset_ns,
                        "bcr": triggered,
                        "sides": phase_sides,
                    })

                sides = {}
                channels_flat = []
                for side_id, adcs in _SIDES.items():
                    channels = []
                    for adc in adcs:
                        first = per_adc[adc][0]
                        merged = _merge_channel(
                            adc,
                            first["fpga"],
                            first["fpga_channel"],
                            per_adc[adc],
                            ped_samples,
                        )
                        channels.append(merged)
                        channels_flat.append(merged)
                    sides[side_id] = channels
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500

        return jsonify({
            "success": True,
            "md": session.md,
            "samples": samples,
            "bcr": bcr,
            "configure": configure,
            "phase_steps": _PHASE_STEPS,
            "bc_ns": _BC_NS,
            "phase_step_ns": _PHASE_STEP_NS,
            "phase_reversed": True,
            "phases": [p["phase"] for p in phase_summaries],
            "settings": {
                "dac_charge": dac_charge,
                "capacitor": "hg" if capacitor else "lg",
                "capacitor_bit": capacitor,
                "adc_pedestal": adc_ped,
                "bcid_charge": bcid_charge,
                "bcid_discharge": bcid_discharge,
                "dbside": dbside,
                "pedestal_samples": ped_samples,
                "phase_start": phases[0],
                "phase_stop": phases[-1],
                "phase_step": phase_step,
                "n_phases": len(phases),
            },
            "sides": sides,
            "channels": channels_flat,
        })

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "tilecal_cis_pulse_scan",
            "name": "TileCal CIS Phase Scan",
            "plugin": "tilecal_cis_pulse_scan",
        })

    register_tree_hook("tilecal_cis_pulse_scan", _tree)
