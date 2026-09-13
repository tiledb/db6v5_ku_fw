"""TileCal DB SFP+ I2C register scan plugin."""
from flask import Blueprint, jsonify, request

from plugins.common.db6_hw_map import SFP_I2C, sfp_i2c_addr_names, sfp_i2c_data_names
from plugins.common.probe_config import plugin_probes, plugin_probe_match_names, tcl_probe_match, tcl_probe_match_any
from plugins.registry import register_tree_hook
from plugins.tilecal_sfp_i2c.conversion import (
    build_register_table,
    parse_probe_map,
    parse_scan_rows,
)


def _side_probe(probes: dict, key: str, legacy_key: str, default: str) -> str:
    return probes.get(key) or probes.get(legacy_key) or default


def _side_scan_tcl(side: str, addr_var: str, data_var: str, avio_var: str, dvio_var: str, max_addr: int) -> str:
    """Per-side register scan: set address output, commit, refresh, read input."""
    return (
        f'if {{${addr_var} ne "" && ${data_var} ne "" && ${avio_var} ne "" && ${dvio_var} ne ""}} {{ '
        f'for {{set __a 0}} {{$__a <= {max_addr}}} {{incr __a}} {{ '
        f'set_property OUTPUT_VALUE [format %02x $__a] ${addr_var} ; '
        f'if {{[catch {{commit_hw_vio ${avio_var}}} __err]}} {{ '
        f'puts "SFPI2CERR|SFP+{side} commit failed at addr $__a|$__err" ; continue }} ; '
        f'if {{[catch {{refresh_hw_vio ${dvio_var}}} __err]}} {{ '
        f'puts "SFPI2CERR|SFP+{side} refresh failed at addr $__a|$__err" ; continue }} ; '
        f'set __v [get_property INPUT_VALUE ${data_var}] ; '
        f'if {{$__v eq ""}} {{ set __v "N/A" }} ; '
        f'puts "SFPI2C|{side}|[format %02x $__a]|$__v" '
        f'}} ; '
        f'set_property OUTPUT_VALUE 00 ${addr_var} ; '
        f'catch {{ commit_hw_vio ${avio_var} }} '
        f'}}'
    )


def tcl_scan_sfp_i2c(device: str, max_addr: int = 127, probes=None) -> str:
    """Cycle s_vio_dbg_sfp_addr_out_q* outputs and read s_vio_dbg_sfp_shadow_q* inputs."""
    probes = probes or {}
    max_addr = max(0, min(int(max_addr), 127))

    addr0_pat = _side_probe(probes, "addr_probe_0", "addr_probe", SFP_I2C["addr_out"][0])
    addr1_pat = _side_probe(probes, "addr_probe_1", "addr_probe", SFP_I2C["addr_out"][1])
    data0_pat = _side_probe(probes, "data_probe_0", "data_probe", SFP_I2C["data_in"][0])
    data1_pat = _side_probe(probes, "data_probe_1", "data_probe", SFP_I2C["data_in"][1])
    exclude_pat = probes.get("exclude_probe", "")

    addr0_match = tcl_probe_match_any(plugin_probe_match_names("addr_probe_0", addr0_pat) or sfp_i2c_addr_names(0))
    addr1_match = tcl_probe_match_any(plugin_probe_match_names("addr_probe_1", addr1_pat) or sfp_i2c_addr_names(1))
    data0_match = tcl_probe_match_any(plugin_probe_match_names("data_probe_0", data0_pat) or sfp_i2c_data_names(0))
    data1_match = tcl_probe_match_any(plugin_probe_match_names("data_probe_1", data1_pat) or sfp_i2c_data_names(1))
    exclude_match = tcl_probe_match(exclude_pat) if exclude_pat else "0"

    exclude_line = f'if {{{exclude_match}}} {{ continue }} ; ' if exclude_pat else ''

    side0 = _side_scan_tcl("0", "__a0", "__d0", "__a0vio", "__d0vio", max_addr)
    side1 = _side_scan_tcl("1", "__a1", "__d1", "__a1vio", "__d1vio", max_addr)

    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        'current_hw_device $__dev ; '
        'set __a0 "" ; set __a1 "" ; set __d0 "" ; set __d1 "" ; '
        'set __a0vio "" ; set __a1vio "" ; set __d0vio "" ; set __d1vio "" ; '
        'foreach __vio [get_hw_vios -of_objects $__dev] { '
        'foreach __p [get_hw_probes -of_objects $__vio] { '
        'set __n [get_property NAME $__p] ; '
        + exclude_line +
        f'if {{{addr0_match}}} {{ set __a0 $__p ; set __a0vio $__vio ; puts "SFPI2CPROBE|addr|0|$__n" }} ; '
        f'if {{{addr1_match}}} {{ set __a1 $__p ; set __a1vio $__vio ; puts "SFPI2CPROBE|addr|1|$__n" }} ; '
        f'if {{{data0_match}}} {{ set __d0 $__p ; set __d0vio $__vio ; puts "SFPI2CPROBE|data|0|$__n" }} ; '
        f'if {{{data1_match}}} {{ set __d1 $__p ; set __d1vio $__vio ; puts "SFPI2CPROBE|data|1|$__n" }} ; '
        '} } ; '
        'if {$__a0 eq ""} { puts "SFPI2CERR|SFP+0 address probe not found (' + addr0_pat + ')" } ; '
        'if {$__a1 eq ""} { puts "SFPI2CERR|SFP+1 address probe not found (' + addr1_pat + ')" } ; '
        'if {$__d0 eq ""} { puts "SFPI2CERR|SFP+0 data probe not found (' + data0_pat + ')" } ; '
        'if {$__d1 eq ""} { puts "SFPI2CERR|SFP+1 data probe not found (' + data1_pat + ')" } ; '
        + side0 + ' ; '
        + side1
    )


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_sfp_i2c", __name__, url_prefix="/api/plugins/tilecal_sfp_i2c")
    run = ctx["run"]
    lock = ctx["lock"]
    parse_rows = ctx["parse_rows"]
    require_open_target = ctx["require_open_target"]
    load_config = ctx["load_config"]

    @bp.route("/data")
    def api_tilecal_sfp_i2c_data():
        device = request.args.get("device", "").strip()
        if not device:
            return jsonify({"success": False, "error": "device required"}), 400
        blocked = require_open_target()
        if blocked:
            return blocked

        try:
            max_addr = int(request.args.get("max_addr", "127"))
        except (TypeError, ValueError):
            max_addr = 127
        max_addr = max(0, min(max_addr, 127))

        probes = plugin_probes(manifest, load_config())
        with lock:
            result = run(tcl_scan_sfp_i2c(device, max_addr, probes), timeout_override=180)

        scan_rows, errors = parse_scan_rows(result.output, parse_rows)
        probe_map = parse_probe_map(result.output, parse_rows)
        table = build_register_table(scan_rows, max_addr)
        return jsonify({
            "success": result.success and not errors,
            "device": device,
            "table": table,
            "probes": probe_map,
            "probe_config": probes,
            "errors": errors,
            "output": result.output,
        })

    app.register_blueprint(bp)

    def _tree_node(device_node, device_name, _vio_nodes):
        device_node["children"].append({
            "type": "tilecal_sfp_i2c",
            "name": "TileCal DB SFP+ I2C",
            "full": device_name,
            "plugin": "tilecal_sfp_i2c",
        })

    register_tree_hook("tilecal_sfp_i2c", _tree_node)
