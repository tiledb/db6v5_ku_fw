"""CIS pulse configure, L1A trigger, and HG/LG pipeline readout.

Follows ``tile_scripts/cis.py``: set pedestals, noise switches, CIS BCID
(charge/discharge + HG/LG capacitor), CIS DAC charge, then
``send_L1A`` / pipeline readout on the selected mini-drawer.
"""

from __future__ import annotations

import math
import time

from flask import Blueprint, jsonify, request

from plugins.registry import register_tree_hook

_SIDES = {"A": range(0, 6), "B": range(6, 12)}
_NCHAN = 12


def _dbside(value: str) -> int:
    side = (value or "both").strip().lower()
    if side in ("both", "0"):
        return 0
    if side in ("a", "1"):
        return 1
    if side in ("b", "2"):
        return 2
    raise ValueError("dbside must be both, A, or B")


def _capacitor_gain(value: str) -> int:
    """Firmware: gain=0 → LG (TPL), gain=1 → HG (TPH)."""
    text = (value or "hg").strip().lower()
    if text in ("lg", "low", "0"):
        return 0
    if text in ("hg", "high", "1"):
        return 1
    raise ValueError("capacitor must be hg or lg")


def analyze_pulse(samples, pedestal_samples=4, noise_sigma_threshold=5, threshold_fraction=0.5):
    if not samples or len(samples) < pedestal_samples + 2:
        return {
            "pedestal": 0.0, "peak": 0.0, "peak_index": 0,
            "center": 0.0, "fwhm": 0.0,
        }

    pedestal_region = samples[:pedestal_samples]
    pedestal = sum(pedestal_region) / pedestal_samples
    variance = sum((x - pedestal) ** 2 for x in pedestal_region) / pedestal_samples
    noise_sigma = math.sqrt(variance)
    signal = [x - pedestal for x in samples]
    peak_value = max(signal)
    peak_index = signal.index(peak_value)

    if peak_value <= 0:
        return {
            "pedestal": pedestal, "peak": 0.0, "peak_index": 0,
            "center": 0.0, "fwhm": 0.0,
        }
    # Flat pedestal → σ=0; still accept a clear pulse above pedestal.
    if noise_sigma > 0 and peak_value < noise_sigma_threshold * noise_sigma:
        return {
            "pedestal": pedestal, "peak": 0.0, "peak_index": 0,
            "center": 0.0, "fwhm": 0.0,
        }

    total = sum(signal)
    center = sum(i * v for i, v in enumerate(signal)) / total if total > 0 else 0.0
    half_max = peak_value * threshold_fraction
    above_half = [i for i, v in enumerate(signal) if v >= half_max]
    fwhm = float(above_half[-1] - above_half[0]) if len(above_half) >= 2 else 0.0
    return {
        "pedestal": pedestal,
        "peak": peak_value,
        "peak_index": peak_index,
        "center": center,
        "fwhm": fwhm,
    }


def _configure_cis(feb, md: int, dbside: int, *, dac_charge: int, capacitor: int,
                   adc_ped: int, bcid_charge: int, bcid_discharge: int) -> None:
    dac_p, dac_n = feb.convert_ped_ADC_to_DACs(adc_ped)
    for feb_id in range(_NCHAN):
        feb.set_ped_HG_pos(md, dbside, feb_id, dac_p)
        feb.set_ped_HG_neg(md, dbside, feb_id, dac_n)
        feb.set_ped_LG_pos(md, dbside, feb_id, dac_p)
        feb.set_ped_LG_neg(md, dbside, feb_id, dac_n)
        feb.load_ped_HG(md, dbside, feb_id)
        feb.load_ped_LG(md, dbside, feb_id)

    for adc in range(_NCHAN):
        feb.set_switches_noise(md, dbside, feb=adc)

    feb.set_CIS_BCID_settings(md, dbside, bcid_charge, bcid_discharge, capacitor)

    for feb_id in range(_NCHAN):
        feb.set_CIS_DAC(md, dbside, feb_id, dac_charge)
    time.sleep(0.05)


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_cis", __name__, url_prefix="/api/plugins/tilecal_cis")
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
            phase = int(src.get("phase", 0))
        except (TypeError, ValueError) as exc:
            return jsonify({"success": False, "error": str(exc)}), 400

        samples = max(1, min(samples, 32))
        dac_charge = max(0, min(dac_charge, 4095))
        adc_ped = max(0, min(adc_ped, 4095))
        bcid_charge = max(0, min(bcid_charge, 0xFFF))
        bcid_discharge = max(0, min(bcid_discharge, 0xFFF))
        ped_samples = max(1, min(ped_samples, samples - 2 if samples > 2 else 1))
        phase = max(0, min(phase, 31))
        # Match TileCal CIS Phase Scan: register pushes clock forward → reversed offset.
        phase_ns = (31 - phase) * (25.0 / 32.0)
        if bcr < samples or bcr > 0xFFF:
            return jsonify({
                "success": False,
                "error": f"BCR must be {samples}..4095 (BCR ≥ sample count)",
            }), 400

        from db_lib import cfb_mb_phase_config, lut_cfgbus_address
        from db_ppr_ipbus import DBReg, FEB

        phase_hw = int(lut_cfgbus_address[cfb_mb_phase_config]) & 0xFFFF
        phase_word = ((phase & 0x1F) << 23) | ((phase & 0x1F) << 7)

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

                # Always apply CIS HSS phase before L1A (Q0 + Q1 same step).
                session.write_side("A", phase_hw, phase_word)
                session.write_side("B", phase_hw, phase_word)
                time.sleep(0.02)

                triggered = session.trigger_readout(bcr)
                sides = {}
                channels_flat = []
                for side_id, adcs in _SIDES.items():
                    channels = []
                    for adc in adcs:
                        hg = session.pipeline(adc, samples, "hg")
                        lg = session.pipeline(adc, samples, "lg")
                        metrics = {
                            "hg": analyze_pulse(hg, pedestal_samples=ped_samples),
                            "lg": analyze_pulse(lg, pedestal_samples=ped_samples),
                        }
                        row = {
                            "adc": adc,
                            "fpga": DBReg.FPGA[adc],
                            "fpga_channel": DBReg.FPGA_CHANNEL[adc],
                            "hg": hg,
                            "lg": lg,
                            "metrics": metrics,
                        }
                        channels.append(row)
                        channels_flat.append(row)
                    sides[side_id] = channels
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500

        return jsonify({
            "success": True,
            "md": session.md,
            "samples": samples,
            "bcr": triggered,
            "configure": configure,
            "settings": {
                "dac_charge": dac_charge,
                "capacitor": "hg" if capacitor else "lg",
                "capacitor_bit": capacitor,
                "adc_pedestal": adc_ped,
                "bcid_charge": bcid_charge,
                "bcid_discharge": bcid_discharge,
                "dbside": dbside,
                "pedestal_samples": ped_samples,
                "phase": phase,
                "phase_ns": phase_ns,
                "phase_word": f"0x{phase_word:08X}",
            },
            "sides": sides,
            "channels": channels_flat,
        })

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "tilecal_cis",
            "name": "TileCal CIS",
            "plugin": "tilecal_cis",
        })

    register_tree_hook("tilecal_cis", _tree)
