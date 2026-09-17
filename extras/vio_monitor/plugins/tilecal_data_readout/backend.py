"""TileCal ADC data-readout debug plugin (db6_data_readout_debug VIO)."""
from __future__ import annotations

from flask import Blueprint, jsonify, request

from plugins.common.db6_hw_map import (
    DATA_READOUT_BCR_DEFAULT,
    DATA_READOUT_CHANNEL_COUNT,
    DATA_READOUT_PROBES,
    DATA_READOUT_SAMPLE_COUNT,
    clamp_data_readout_bcr,
)
from plugins.common.probe_config import plugin_probes, plugin_probe_match_names, tcl_probe_match_any
from plugins.registry import plugin_bcr_offset, register_tree_hook
from plugins.tilecal_data_readout.conversion import parse_output


def _probe(probes: dict, key: str) -> str:
    return probes.get(key) or DATA_READOUT_PROBES[key]["ltx"]


def _tcl_discover(probes: dict) -> str:
    matches = {}
    for key in DATA_READOUT_PROBES:
        matches[key] = tcl_probe_match_any(plugin_probe_match_names(key, _probe(probes, key)))

    return (
        'set __trig_p "" ; set __samp_p "" ; set __ch_p "" ; set __bcr_p "" ; '
        'set __cap_p "" ; set __hg_p "" ; set __lg_p "" ; set __fc_p "" ; '
        'set __packed_p "" ; set __out_vio "" ; set __in_vio "" ; '
        'foreach __vio [get_hw_vios -of_objects $__dev] { '
        'foreach __p [get_hw_probes -of_objects $__vio] { '
        'set __n [get_property NAME $__p] ; '
        # Never bind inject nets (probe_out19 / probe_in89). data_readout is a
        # prefix of data_readout_inject; a whole-VIO commit also rewrites enable.
        'if {[string match {*data_readout_inject*} $__n] || '
        '[regexp {probe_out19(\[|$)} $__n] || [regexp {probe_in89(\[|$)} $__n]} { continue } ; '
        f'if {{{matches["trigger_probe"]}}} {{ set __trig_p $__p ; set __out_vio $__vio ; puts "ADCRDPROBE|trigger|$__n" }} ; '
        f'if {{{matches["sample_index_probe"]}}} {{ set __samp_p $__p ; set __out_vio $__vio ; puts "ADCRDPROBE|sample_index|$__n" }} ; '
        f'if {{{matches["channel_select_probe"]}}} {{ set __ch_p $__p ; set __out_vio $__vio ; puts "ADCRDPROBE|channel_select|$__n" }} ; '
        f'if {{{matches["bcr_number_probe"]}}} {{ set __bcr_p $__p ; set __out_vio $__vio ; puts "ADCRDPROBE|bcr_number|$__n" }} ; '
        f'if {{{matches["captured_probe"]}}} {{ set __cap_p $__p ; set __in_vio $__vio ; puts "ADCRDPROBE|captured|$__n" }} ; '
        f'if {{{matches["hg_data_probe"]}}} {{ set __hg_p $__p ; if {{$__in_vio eq ""}} {{ set __in_vio $__vio }} ; puts "ADCRDPROBE|hg_data|$__n" }} ; '
        f'if {{{matches["lg_data_probe"]}}} {{ set __lg_p $__p ; if {{$__in_vio eq ""}} {{ set __in_vio $__vio }} ; puts "ADCRDPROBE|lg_data|$__n" }} ; '
        f'if {{{matches["fc_data_probe"]}}} {{ set __fc_p $__p ; if {{$__in_vio eq ""}} {{ set __in_vio $__vio }} ; puts "ADCRDPROBE|fc_data|$__n" }} ; '
        f'if {{{matches["packed_control_probe"]}}} {{ '
        'if {![regexp {\\[[0-9]+(:[0-9]+)?\\]$} $__n] || [regexp {\\[(7:0|0:7)\\]$} $__n]} { '
        'if {$__packed_p eq ""} { set __packed_p $__p ; if {$__out_vio eq ""} { set __out_vio $__vio } ; puts "ADCRDPROBE|packed|$__n" } } } ; '
        '} } ; '
        'if {$__bcr_p eq ""} { puts "ADCRDERR|bcr_number probe not found" } ; '
        'if {$__cap_p eq ""} { puts "ADCRDERR|captured probe not found" } ; '
        'if {$__hg_p eq ""} { puts "ADCRDERR|hg_data probe not found" } ; '
        'if {$__lg_p eq ""} { puts "ADCRDERR|lg_data probe not found" } ; '
        'if {$__fc_p eq ""} { puts "ADCRDERR|fc_data probe not found" } ; '
        'if {$__trig_p eq "" || $__samp_p eq "" || $__ch_p eq ""} { '
        'if {$__packed_p eq ""} { puts "ADCRDERR|trigger/sample/channel probes not found (and no packed probe_out17)" } } ; '
        'if {$__out_vio eq "" || $__in_vio eq ""} { puts "ADCRDERR|VIO core not resolved" } ; '
    )


def _tcl_commit_probes(*probe_vars: str) -> str:
    """Commit only the named hw_probe objects, not the whole vio_db_debug core.

    Re-resolve via get_hw_probes -filter NAME == {…} so HDL names with [] are
    not passed as hw_vio identifiers (Labtoolstcl 44-186).
    """
    name_gets = " ".join(f"[get_property NAME ${name}]" for name in probe_vars)
    fmt = " || ".join(["NAME == {%s}"] * len(probe_vars))
    return (
        f'set __cf [format {{{fmt}}} {name_gets}] ; '
        'commit_hw_vio [get_hw_probes -of_objects $__out_vio -filter $__cf] ; '
    )


def _tcl_refresh_inputs() -> str:
    """Refresh the parent VIO core. refresh_hw_vio only accepts hw_vio objects."""
    return 'refresh_hw_vio $__in_vio ; '


def _tcl_apply_control(include_bcr: bool = False) -> str:
    """Write $__t/$__s/$__c (and optionally $__bcr) via split probes or packed probe_out17."""
    bcr = (
        'if {$__bcr_p ne ""} { '
        'set_property OUTPUT_VALUE [format %08x $__bcr] $__bcr_p '
        '} ; '
    ) if include_bcr else ''
    if include_bcr:
        commit_split = (
            'if {$__bcr_p ne ""} { '
            + _tcl_commit_probes("__trig_p", "__samp_p", "__ch_p", "__bcr_p")
            + '} else { '
            + _tcl_commit_probes("__trig_p", "__samp_p", "__ch_p")
            + '} '
        )
    else:
        commit_split = _tcl_commit_probes("__trig_p", "__samp_p", "__ch_p")
    return (
        bcr
        + 'if {$__trig_p ne "" && $__samp_p ne "" && $__ch_p ne ""} { '
        'set_property OUTPUT_VALUE [format %x $__t] $__trig_p ; '
        'set_property OUTPUT_VALUE [format %x $__s] $__samp_p ; '
        'set_property OUTPUT_VALUE [format %x $__c] $__ch_p ; '
        + commit_split
        + '} elseif {$__packed_p ne ""} { '
        'set __pv [expr {(($__c & 7) << 5) | (($__s & 15) << 1) | ($__t & 1)}] ; '
        'set_property OUTPUT_VALUE [format %02x $__pv] $__packed_p ; '
        + _tcl_commit_probes("__packed_p")
        + '} else { puts "ADCRDERR|data_readout control probes not found" } ; '
    )


def _tcl_apply_mux() -> str:
    """Update sample_index/channel_select without changing the trigger bit."""
    return (
        'if {$__samp_p ne "" && $__ch_p ne ""} { '
        'set_property OUTPUT_VALUE [format %x $__s] $__samp_p ; '
        'set_property OUTPUT_VALUE [format %x $__c] $__ch_p ; '
        + _tcl_commit_probes("__samp_p", "__ch_p")
        + '} elseif {$__packed_p ne ""} { '
        'set __cur 0 ; '
        'catch { scan [get_property OUTPUT_VALUE $__packed_p] %x __cur } ; '
        'set __tkeep [expr {$__cur & 1}] ; '
        'set __pv [expr {(($__c & 7) << 5) | (($__s & 15) << 1) | $__tkeep}] ; '
        'set_property OUTPUT_VALUE [format %02x $__pv] $__packed_p ; '
        + _tcl_commit_probes("__packed_p")
        + '} else { puts "ADCRDERR|sample/channel probes not found" } ; '
    )


def _tcl_read_captured() -> str:
    return (
        _tcl_refresh_inputs()
        + 'set __sr [get_property INPUT_VALUE $__cap_p] ; '
        'set __sv 0 ; '
        'if {[catch {scan $__sr %x __sv}]} { set __sv 0 } ; '
        'puts "ADCRDCAPTURED|[expr {($__sv & 1) != 0}]|$__sr" ; '
    )


def _tcl_wait_captured(timeout_ms: int) -> str:
    return (
        f'set __t0 [clock milliseconds] ; set __ok 0 ; set __sr 0 ; '
        f'while {{[expr {{[clock milliseconds] - $__t0 < {timeout_ms}}}]}} {{ '
        + _tcl_refresh_inputs()
        + 'set __sr [get_property INPUT_VALUE $__cap_p] ; '
        'if {![catch {scan $__sr %x __sv}]} { '
        'if {[expr {$__sv & 1}]} { set __ok 1 ; break } } ; '
        'after 10 '
        '} ; '
        'if {$__ok == 0} { puts "ADCRDERR|timeout waiting for captured (BCR match)" } ; '
        'puts "ADCRDCAPTURED|$__ok|$__sr" ; '
    )


def _tcl_sweep_readout() -> str:
    n_ch = DATA_READOUT_CHANNEL_COUNT
    n_samp = DATA_READOUT_SAMPLE_COUNT
    return (
        f'for {{set __c 0}} {{$__c < {n_ch}}} {{incr __c}} {{ '
        f'for {{set __s 0}} {{$__s < {n_samp}}} {{incr __s}} {{ '
        + _tcl_apply_mux()
        + _tcl_refresh_inputs()
        + 'set __hg [get_property INPUT_VALUE $__hg_p] ; '
        'set __lg [get_property INPUT_VALUE $__lg_p] ; '
        'set __fc [get_property INPUT_VALUE $__fc_p] ; '
        'puts "ADCRDSAMPLE|$__c|$__s|$__hg|$__lg|$__fc" '
        '} } ; '
    )


def _tcl_guard() -> str:
    return (
        'if {$__cap_p eq "" || $__hg_p eq "" || $__lg_p eq "" || $__fc_p eq "" || $__bcr_p eq "" || $__out_vio eq "" || $__in_vio eq ""} { '
        'puts "ADCRDCAPTURED|0|0" ; '
        '} elseif {$__trig_p eq "" && $__packed_p eq ""} { '
        'puts "ADCRDCAPTURED|0|0" ; '
        '} else { '
    )


def tcl_data_readout(
    device: str,
    operation: str,
    *,
    bcr_number: int = 0,
    timeout_ms: int = 15000,
    probes=None,
) -> str:
    probes = probes or {}
    op = (operation or "status").lower()
    bcr = bcr_number & 0xFFFFFFFF
    timeout_ms = max(100, min(int(timeout_ms), 120000))

    body = _tcl_discover(probes)
    body += _tcl_guard()

    if op == "status":
        body += _tcl_read_captured()
    elif op in ("trigger", "capture"):
        body += (
            f'set __bcr {bcr} ; set __t 0 ; set __s 0 ; set __c 0 ; '
            + _tcl_apply_control(include_bcr=True)
            + 'after 10 ; '
            'set __t 1 ; '
            + _tcl_apply_control(include_bcr=False)
            + _tcl_wait_captured(timeout_ms)
        )
    elif op == "readout":
        body += _tcl_read_captured()
        body += _tcl_sweep_readout()
    elif op in ("trigger_readout", "capture_readout"):
        body += (
            f'set __bcr {bcr} ; set __t 0 ; set __s 0 ; set __c 0 ; '
            + _tcl_apply_control(include_bcr=True)
            + 'after 10 ; '
            'set __t 1 ; '
            + _tcl_apply_control(include_bcr=False)
            + _tcl_wait_captured(timeout_ms)
            + 'if {$__ok} { '
            + _tcl_sweep_readout()
            + '} ; '
        )
    else:
        body += f'puts "ADCRDERR|unknown operation {operation}" ; '

    body += '}'
    return f'set __dev [get_hw_devices {{{device}}}] ; current_hw_device $__dev ; ' + body


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_data_readout", __name__, url_prefix="/api/plugins/tilecal_data_readout")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]
    require_open_target = ctx["require_open_target"]
    load_config = ctx["load_config"]

    def _parse_int(value, default=0):
        if value is None or value == "":
            return default
        if isinstance(value, int):
            return value
        text = str(value).strip().lower()
        return int(text, 16 if text.startswith("0x") else 10)

    def _json_result(result, operation, bcr_number=0, bcr_requested=0, bcr_offset=-16):
        parsed = parse_output(result.output, parse_rows)
        ok = result.success and not parsed["errors"]
        if operation in ("trigger", "capture", "trigger_readout", "capture_readout"):
            if parsed["captured"] is False:
                ok = False
        return jsonify({
            "success": ok,
            "operation": operation,
            "bcr_number": bcr_number,
            "bcr_requested": bcr_requested,
            "bcr_offset": bcr_offset,
            "captured": parsed["captured"],
            "captured_raw": parsed["captured_raw"],
            "tables": parsed["tables"],
            "samples": parsed["samples"],
            "csv": parsed["csv"],
            "sample_count": parsed["sample_count"],
            "channel_count": parsed["channel_count"],
            "sample_bits": parsed["sample_bits"],
            "adc_bits": parsed["adc_bits"],
            "probes": parsed["probes"],
            "errors": parsed["errors"],
            "output": result.output,
        })

    def _run_op(operation: str, data: dict):
        device = (data.get("device") or request.args.get("device") or "").strip()
        if not device:
            return jsonify({"success": False, "error": "device required"}), 400
        blocked = require_open_target()
        if blocked:
            return blocked
        bcr_requested = clamp_data_readout_bcr(
            _parse_int(data.get("bcr_number"), DATA_READOUT_BCR_DEFAULT)
        )
        cfg = load_config()
        default_offset = plugin_bcr_offset(cfg, manifest)
        if data.get("bcr_offset") in (None, ""):
            bcr_offset = default_offset
        else:
            bcr_offset = _parse_int(data.get("bcr_offset"), default_offset)
        if operation in ("trigger", "capture", "trigger_readout", "capture_readout"):
            bcr_number = (bcr_requested + bcr_offset) & 0xFFFFFFFF
        else:
            bcr_number = bcr_requested
        timeout_ms = _parse_int(data.get("timeout_ms"), 15000)
        timeout_ms = max(100, min(timeout_ms, 120000))
        probes = plugin_probes(manifest, load_config())
        http_timeout = 30
        if operation == "readout":
            http_timeout = 180
        elif operation in ("trigger_readout", "capture_readout"):
            http_timeout = 210
        elif operation in ("trigger", "capture"):
            http_timeout = max(30, (timeout_ms // 1000) + 15)
        with lock:
            result = run(
                tcl_data_readout(
                    device,
                    operation,
                    bcr_number=bcr_number,
                    timeout_ms=timeout_ms,
                    probes=probes,
                ),
                timeout_override=http_timeout,
            )
        return _json_result(
            result, operation,
            bcr_number=bcr_number,
            bcr_requested=bcr_requested,
            bcr_offset=bcr_offset,
        )

    @bp.route("/status")
    def api_data_readout_status():
        return _run_op("status", {"device": request.args.get("device", "")})

    @bp.route("/execute", methods=["POST"])
    def api_data_readout_execute():
        data = request.get_json(silent=True) or {}
        operation = (data.get("operation") or "").strip().lower()
        if not operation:
            return jsonify({"success": False, "error": "operation required"}), 400
        try:
            return _run_op(operation, data)
        except ValueError as exc:
            return jsonify({"success": False, "error": str(exc)}), 400

    app.register_blueprint(bp)

    def _tree_node(device_node, device_name, _vio_nodes):
        device_node["children"].append({
            "type": "tilecal_data_readout",
            "name": "TileCal ADC Data Readout",
            "full": device_name,
            "plugin": "tilecal_data_readout",
        })

    register_tree_hook("tilecal_data_readout", _tree_node)
