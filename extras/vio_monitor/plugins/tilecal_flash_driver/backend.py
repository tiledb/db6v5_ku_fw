"""TileCal DB IS25LP256 flash driver plugin (VIO manual override)."""
from __future__ import annotations

from flask import Blueprint, jsonify, request

from plugins.common.probe_config import plugin_probes, tcl_probe_match
from plugins.registry import register_tree_hook
from plugins.tilecal_flash_driver.conversion import (
    OP_BLOCK_ERASE,
    OP_FAST_READ,
    OP_PAGE_PROGRAM,
    OP_RDID,
    OP_RDSR,
    OP_READ,
    OP_SECTOR_ERASE,
    OP_WREN,
    build_hex_dump,
    decode_rdata,
    decode_status,
    encode_command,
    parse_flash_output,
)


def _probe(probes: dict, key: str, default: str) -> str:
    return probes.get(key) or default


def _tcl_set_out(probe_var: str, vio_var: str, hex_val: str) -> str:
    return (
        f'set_property OUTPUT_VALUE {hex_val} ${probe_var} ; '
        f'commit_hw_vio ${vio_var} ; '
    )


def _tcl_pulse(opcode: int, *, wdata: int = 0, length_sel: int = 0, timeout_ms: int = 5000) -> str:
    """Pulse start on flash_manual_command and wait for status bit1 (done)."""
    cmd_idle = encode_command(opcode, start=False, length_sel=length_sel, wdata=wdata)
    cmd_run = encode_command(opcode, start=True, length_sel=length_sel, wdata=wdata)
    return (
        f'set __cmd0 [format %08x {cmd_idle}] ; '
        f'set __cmd1 [format %08x {cmd_run}] ; '
        + _tcl_set_out("__cmd_p", "__out_vio", "$__cmd0")
        + 'set_property OUTPUT_VALUE $__cmd1 $__cmd_p ; '
        + 'commit_hw_vio $__out_vio ; '
        + f'set __t0 [clock milliseconds] ; set __ok 0 ; '
        + f'while {{[expr {{[clock milliseconds] - $__t0 < {timeout_ms}}}]}} {{ '
        + 'refresh_hw_vio $__in_vio ; '
        + 'set __sr [get_property INPUT_VALUE $__status_p] ; '
        + 'if {![catch {scan $__sr %x __sv}]} { '
        + 'if {[expr {$__sv & 2}]} { set __ok 1 ; break } } ; '
        + 'after 10 '
        + '} ; '
        + 'if {$__ok == 0} { puts "FLASHERR|timeout waiting for done (opcode '
        + f'{opcode:#x}' + ')" } ; '
        + _tcl_set_out("__cmd_p", "__out_vio", "$__cmd0")
        + 'refresh_hw_vio $__in_vio ; '
    )


def _tcl_discover(probes: dict) -> str:
    addr_m = tcl_probe_match(_probe(probes, "address_probe", "s_clknet_debug_control[flash_manual_address]"))
    cmd_m = tcl_probe_match(_probe(probes, "command_probe", "s_clknet_debug_control[flash_manual_command]"))
    fl_en_m = tcl_probe_match(
        _probe(probes, "floor_enable_probe", "s_clknet_debug_control[flash_manual_write_floor_enable]")
    )
    floor_m = tcl_probe_match(
        _probe(probes, "floor_probe", "s_clknet_debug_control[flash_manual_write_floor]")
    )
    status_m = tcl_probe_match(_probe(probes, "status_probe", "s_system_management_interface[flash_status]"))
    rdata_m = tcl_probe_match(_probe(probes, "rdata_probe", "s_system_management_interface[flash_rdata]"))

    return (
        'set __addr_p "" ; set __cmd_p "" ; set __floor_en_p "" ; set __floor_p "" ; '
        'set __status_p "" ; set __rdata_p "" ; set __out_vio "" ; set __in_vio "" ; '
        'foreach __vio [get_hw_vios -of_objects $__dev] { '
        'foreach __p [get_hw_probes -of_objects $__vio] { '
        'set __n [get_property NAME $__p] ; '
        f'if {{{addr_m}}} {{ set __addr_p $__p ; set __out_vio $__vio ; puts "FLASHPROBE|address|$__n" }} ; '
        f'if {{{cmd_m}}} {{ set __cmd_p $__p ; set __out_vio $__vio ; puts "FLASHPROBE|command|$__n" }} ; '
        f'if {{{fl_en_m}}} {{ set __floor_en_p $__p ; set __out_vio $__vio ; puts "FLASHPROBE|floor_enable|$__n" }} ; '
        f'if {{{floor_m}}} {{ set __floor_p $__p ; set __out_vio $__vio ; puts "FLASHPROBE|floor|$__n" }} ; '
        f'if {{{status_m}}} {{ set __status_p $__p ; set __in_vio $__vio ; puts "FLASHPROBE|status|$__n" }} ; '
        f'if {{{rdata_m}}} {{ set __rdata_p $__p ; if {{$__in_vio eq ""}} {{ set __in_vio $__vio }} ; puts "FLASHPROBE|rdata|$__n" }} ; '
        '} } ; '
        'if {$__addr_p eq ""} { puts "FLASHERR|address probe not found" } ; '
        'if {$__cmd_p eq ""} { puts "FLASHERR|command probe not found" } ; '
        'if {$__status_p eq ""} { puts "FLASHERR|status probe not found" } ; '
        'if {$__rdata_p eq ""} { puts "FLASHERR|rdata probe not found" } ; '
        'if {$__out_vio eq "" || $__in_vio eq ""} { puts "FLASHERR|VIO core not resolved" } ; '
    )


def _tcl_read_result() -> str:
    return (
        'set __st [get_property INPUT_VALUE $__status_p] ; '
        'set __rd [get_property INPUT_VALUE $__rdata_p] ; '
        'puts "FLASHRESULT|$__st|$__rd" ; '
    )


def _tcl_emit_rdata_bytes_var() -> str:
    """Emit FLASHBYTE lines for $__lsel+1 bytes at $__addr after read."""
    return (
        'set __rd [get_property INPUT_VALUE $__rdata_p] ; '
        'if {![catch {scan $__rd %x __rv}]} { '
        'for {set __bi 0} {$__bi <= $__lsel} {incr __bi} { '
        'set __ba [expr {$__addr + $__bi}] ; '
        'set __bv [expr {($__rv >> (8 * $__bi)) & 0xff}] ; '
        'puts "FLASHBYTE|[format %08x $__ba]|[format %02x $__bv]" '
        '} } ; '
    )


def _tcl_pulse_var(opcode: int, timeout_ms: int = 10000) -> str:
    """Pulse read command; uses Tcl vars $__lsel for length_sel."""
    op = (opcode & 0xF) << 24
    return (
        f'set __cmd0 [format %08x [expr {{{op} | ($__lsel << 8)}}]] ; '
        f'set __cmd1 [format %08x [expr {{{op} | ($__lsel << 8) | 0x80000000}}]] ; '
        + _tcl_set_out("__cmd_p", "__out_vio", "$__cmd0")
        + 'set_property OUTPUT_VALUE $__cmd1 $__cmd_p ; '
        + 'commit_hw_vio $__out_vio ; '
        + f'set __t0 [clock milliseconds] ; set __ok 0 ; '
        + f'while {{[expr {{[clock milliseconds] - $__t0 < {timeout_ms}}}]}} {{ '
        + 'refresh_hw_vio $__in_vio ; '
        + 'set __sr [get_property INPUT_VALUE $__status_p] ; '
        + 'if {![catch {scan $__sr %x __sv}]} { '
        + 'if {[expr {$__sv & 2}]} { set __ok 1 ; break } } ; '
        + 'after 10 '
        + '} ; '
        + 'if {$__ok == 0} { puts "FLASHERR|timeout read at [format %08x $__addr]" } ; '
        + _tcl_set_out("__cmd_p", "__out_vio", "$__cmd0")
        + 'refresh_hw_vio $__in_vio ; '
    )


def _tcl_read_bulk(opcode: int, base: int, count: int, timeout_ms: int = 10000) -> str:
    """Read count bytes (1..4096) in up-to-4-byte chunks."""
    count = max(1, min(int(count), 4096))
    return (
        f'set __base {base & 0xFFFFFFFF} ; '
        f'set __total {count} ; '
        'for {set __off 0} {$__off < $__total} {incr __off 4} { '
        'set __addr [expr {$__base + $__off}] ; '
        'set __rem [expr {$__total - $__off}] ; '
        'set __lsel 3 ; '
        'if {$__rem == 1} { set __lsel 0 } '
        'elseif {$__rem == 2} { set __lsel 1 } '
        'elseif {$__rem == 3} { set __lsel 2 } ; '
        'set_property OUTPUT_VALUE [format %08x $__addr] $__addr_p ; '
        'commit_hw_vio $__out_vio ; '
        + _tcl_pulse_var(opcode, timeout_ms=timeout_ms)
        + _tcl_emit_rdata_bytes_var()
        + '} ; '
    )


def _tcl_single_read(opcode: int, length_sel: int, timeout_ms: int = 10000) -> str:
    return (
        f'set __lsel {length_sel} ; '
        + _tcl_pulse_var(opcode, timeout_ms=timeout_ms)
        + _tcl_emit_rdata_bytes_var()
    )


def tcl_flash_operation(
    device: str,
    operation: str,
    *,
    address: int = 0,
    wdata: int = 0,
    length_sel: int = 0,
    byte_count: int = 4,
    floor_enable: bool | None = None,
    floor: int | None = None,
    probes=None,
) -> str:
    probes = probes or {}
    op = (operation or "status").lower()
    addr = address & 0xFFFFFFFF
    wdata = wdata & 0xFF
    length_sel = max(0, min(length_sel, 3))
    byte_count = max(1, min(int(byte_count), 4096))

    body = _tcl_discover(probes)
    body += (
        'if {$__addr_p eq "" || $__cmd_p eq "" || $__status_p eq "" || $__rdata_p eq ""} { '
        'puts "FLASHRESULT|0|0" ; '
        '} else { '
    )

    if floor_enable is not None and floor is not None:
        body += (
            'if {$__floor_en_p ne ""} { '
            + _tcl_set_out("__floor_en_p", "__out_vio", ("1" if floor_enable else "0"))
            + '} ; '
            'if {$__floor_p ne ""} { '
            f'set_property OUTPUT_VALUE [format %08x {floor & 0xFFFFFFFF}] $__floor_p ; '
            'commit_hw_vio $__out_vio ; '
            '} ; '
        )

    read_ops = ("read", "fast_read")
    if op in read_ops:
        body += f'set __addr {addr} ; '
    elif op != "status" and op not in ("rdsr", "rdid"):
        body += (
            f'set_property OUTPUT_VALUE [format %08x {addr}] $__addr_p ; '
            'commit_hw_vio $__out_vio ; '
        )

    if op == "status":
        body += 'refresh_hw_vio $__in_vio ; '
    elif op == "wren":
        body += _tcl_pulse(OP_WREN, timeout_ms=5000)
    elif op == "rdsr":
        body += _tcl_pulse(OP_RDSR, timeout_ms=5000)
    elif op == "rdid":
        body += _tcl_pulse(OP_RDID, timeout_ms=5000)
    elif op == "read":
        if byte_count > 4:
            body += _tcl_read_bulk(OP_READ, addr, byte_count, timeout_ms=10000)
        else:
            body += (
                f'set_property OUTPUT_VALUE [format %08x {addr}] $__addr_p ; '
                'commit_hw_vio $__out_vio ; '
                + _tcl_single_read(OP_READ, max(0, byte_count - 1))
            )
    elif op == "fast_read":
        if byte_count > 4:
            body += _tcl_read_bulk(OP_FAST_READ, addr, byte_count, timeout_ms=10000)
        else:
            body += (
                f'set_property OUTPUT_VALUE [format %08x {addr}] $__addr_p ; '
                'commit_hw_vio $__out_vio ; '
                + _tcl_single_read(OP_FAST_READ, max(0, byte_count - 1))
            )
    elif op == "write_byte":
        body += _tcl_pulse(OP_WREN, timeout_ms=5000)
        body += _tcl_pulse(OP_PAGE_PROGRAM, wdata=wdata, timeout_ms=15000)
    elif op == "erase_sector":
        body += _tcl_pulse(OP_WREN, timeout_ms=5000)
        body += _tcl_pulse(OP_SECTOR_ERASE, timeout_ms=120000)
    elif op == "erase_block":
        body += _tcl_pulse(OP_WREN, timeout_ms=5000)
        body += _tcl_pulse(OP_BLOCK_ERASE, timeout_ms=180000)
    else:
        body += f'puts "FLASHERR|unknown operation {operation}" ; '

    body += _tcl_read_result()
    body += '}'

    return f'set __dev [get_hw_devices {{{device}}}] ; current_hw_device $__dev ; ' + body


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_flash_driver", __name__, url_prefix="/api/plugins/tilecal_flash_driver")
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

    @bp.route("/status")
    def api_flash_status():
        device = request.args.get("device", "").strip()
        if not device:
            return jsonify({"success": False, "error": "device required"}), 400
        blocked = require_open_target()
        if blocked:
            return blocked
        probes = plugin_probes(manifest, load_config())
        with lock:
            result = run(tcl_flash_operation(device, "status", probes=probes), timeout_override=30)
        return _json_result(result, parse_rows, length_sel=0, byte_count=0, address=0)

    @bp.route("/execute", methods=["POST"])
    def api_flash_execute():
        data = request.get_json(silent=True) or {}
        device = (data.get("device") or request.args.get("device") or "").strip()
        if not device:
            return jsonify({"success": False, "error": "device required"}), 400
        blocked = require_open_target()
        if blocked:
            return blocked

        operation = (data.get("operation") or "").strip().lower()
        if not operation:
            return jsonify({"success": False, "error": "operation required"}), 400

        address = _parse_int(data.get("address"), 0)
        wdata = _parse_int(data.get("wdata"), 0) & 0xFF
        length_sel = _parse_int(data.get("length_sel"), 0)
        length_sel = max(0, min(length_sel, 3))
        byte_count = _parse_int(data.get("byte_count"), length_sel + 1)
        byte_count = max(1, min(byte_count, 4096))

        floor_enable = data.get("floor_enable")
        floor = data.get("floor")
        floor_enable_val = None
        floor_val = None
        if floor_enable is not None:
            floor_enable_val = bool(floor_enable)
            floor_val = _parse_int(floor, 0)

        probes = plugin_probes(manifest, load_config())
        timeout = 30
        if operation in ("erase_sector",):
            timeout = 150
        elif operation in ("erase_block",):
            timeout = 240
        elif operation in ("write_byte",):
            timeout = 60
        elif operation in ("read", "fast_read"):
            timeout = max(60, min(600, 30 + byte_count // 4))

        with lock:
            result = run(
                tcl_flash_operation(
                    device,
                    operation,
                    address=address,
                    wdata=wdata,
                    length_sel=length_sel,
                    byte_count=byte_count,
                    floor_enable=floor_enable_val,
                    floor=floor_val,
                    probes=probes,
                ),
                timeout_override=timeout,
            )
        return _json_result(
            result, parse_rows,
            length_sel=length_sel,
            byte_count=byte_count,
            address=address,
            operation=operation,
        )

    def _json_result(result, parse_rows, length_sel=0, byte_count=4, address=0, operation=None):
        parsed = parse_flash_output(result.output, parse_rows)
        byte_count = max(1, min(int(byte_count), 4096))
        if operation == "rdid":
            display_count = 3
        elif operation == "rdsr":
            display_count = 1
        elif operation in ("read", "fast_read"):
            display_count = byte_count
        else:
            display_count = length_sel + 1
        status = decode_status(parsed["status_raw"])
        rdata = decode_rdata(parsed["rdata_raw"], min(4, display_count))
        hex_dump = None
        if operation in ("read", "fast_read") and parsed["byte_map"]:
            hex_dump = build_hex_dump(parsed["byte_map"], address, byte_count)
        ok = result.success and not parsed["errors"]
        return jsonify({
            "success": ok,
            "operation": operation,
            "status": status,
            "rdata": rdata,
            "hex_dump": hex_dump,
            "probes": parsed["probes"],
            "errors": parsed["errors"],
            "output": result.output,
        })

    app.register_blueprint(bp)

    def _tree_node(device_node, device_name, _vio_nodes):
        device_node["children"].append({
            "type": "tilecal_flash_driver",
            "name": "TileCal DB FLASH Driver",
            "full": device_name,
            "plugin": "tilecal_flash_driver",
        })

    register_tree_hook("tilecal_flash_driver", _tree_node)
