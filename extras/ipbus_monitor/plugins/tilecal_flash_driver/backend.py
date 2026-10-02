"""IS25LP256 access over cfb_flash_* / stb_flash_* for one or both FPGAs."""

from __future__ import annotations

import time

from flask import Blueprint, jsonify, request

from plugins.common.regs import reg
from plugins.registry import register_tree_hook

OP_WREN = 0x01
OP_RDSR = 0x03
OP_READ = 0x04
OP_FAST_READ = 0x05
OP_PAGE_PROGRAM = 0x06
OP_SECTOR_ERASE = 0x07
OP_BLOCK_ERASE = 0x08
OP_RDID = 0x0A
OP_NAMES = {
    OP_WREN: "WREN",
    OP_RDSR: "RDSR",
    OP_READ: "READ",
    OP_FAST_READ: "FAST_READ",
    OP_PAGE_PROGRAM: "PAGE_PROGRAM",
    OP_SECTOR_ERASE: "SECTOR_ERASE",
    OP_BLOCK_ERASE: "BLOCK_ERASE",
    OP_RDID: "RDID",
}
_MUTATING = {"write_byte", "erase_sector", "erase_block"}


def _parse_int(value, default=0) -> int:
    if value is None or value == "":
        return default
    if isinstance(value, int):
        return value
    text = str(value).strip().lower()
    return int(text, 16 if text.startswith("0x") else 10)


def _encode(opcode: int, *, start: bool, length_sel: int = 0, wdata: int = 0) -> int:
    cmd = ((opcode & 0x1F) << 24) | ((length_sel & 0x3) << 8) | (wdata & 0xFF)
    if start:
        cmd |= 1 << 31
    return cmd & 0xFFFFFFFF


def _decode_status(raw: int) -> dict:
    op = (raw >> 16) & 0x1F
    return {
        "raw_hex": f"0x{raw:08X}",
        "busy": bool(raw & 0x1),
        "done": bool(raw & 0x2),
        "write_blocked": bool(raw & 0x8000),
        "status_reg": (raw >> 2) & 0xFF,
        "op_name": OP_NAMES.get(op, f"0x{op:X}"),
    }


def _decode_rdata(raw: int, nbytes: int) -> dict:
    count = max(1, min(int(nbytes), 4))
    out = [(raw >> (8 * i)) & 0xFF for i in range(count - 1, -1, -1)]
    return {"raw_hex": f"0x{raw:08X}", "bytes_hex": " ".join(f"0x{b:02X}" for b in out)}


def _hex_dump(byte_map: dict[int, int], base: int, length: int) -> dict:
    rows = []
    for row_off in range(0, length, 16):
        addr = (base + row_off) & 0xFFFFFFFF
        hex_cells = []
        ascii_chars = []
        for col in range(16):
            off = row_off + col
            if off >= length:
                break
            val = byte_map.get((base + off) & 0xFFFFFFFF)
            if val is None:
                hex_cells.append("--")
                ascii_chars.append(" ")
            else:
                hex_cells.append(f"{val:02X}")
                ascii_chars.append(chr(val) if 32 <= val < 127 else ".")
        rows.append({
            "address_hex": f"0x{addr:08X}",
            "hex": " ".join(hex_cells),
            "ascii": "".join(ascii_chars),
        })
    return {
        "base_hex": f"0x{base & 0xFFFFFFFF:08X}",
        "length": length,
        "byte_count": len(byte_map),
        "rows": rows,
    }


class _Flash:
    def __init__(self, session):
        self.session = session
        self.addr = reg("rx", "cfb_flash_address")["hw_addr"]
        self.cmd = reg("rx", "cfb_flash_command")["hw_addr"]
        self.floor = reg("rx", "cfb_flash_write_floor")["hw_addr"]
        self.status = reg("tx", "stb_flash_status")["hw_addr"]
        self.rdata = reg("tx", "stb_flash_rdata")["hw_addr"]

    def _pulse(self, side: str, opcode: int, address: int | None, length_sel: int, wdata: int, timeout: float):
        if address is not None:
            self.session.write_side(side, self.addr, address & 0xFFFFFFFF)
        idle = _encode(opcode, start=False, length_sel=length_sel, wdata=wdata)
        run = _encode(opcode, start=True, length_sel=length_sel, wdata=wdata)
        self.session.write_side(side, self.cmd, idle)
        self.session.write_side(side, self.cmd, run)
        deadline = time.time() + timeout
        status = 0
        try:
            while time.time() < deadline:
                status = self.session.read_side(side, self.status)
                if status & 0x2:
                    break
            else:
                raise TimeoutError(f"side {side} flash opcode 0x{opcode:X} did not set done")
        finally:
            self.session.write_side(side, self.cmd, idle)
        return status, self.session.read_side(side, self.rdata)

    def snapshot(self, side: str) -> dict:
        return {
            "side": side,
            "status": _decode_status(self.session.read_side(side, self.status)),
            "rdata": _decode_rdata(self.session.read_side(side, self.rdata), 4),
            "errors": [],
            "hex_dump": None,
        }

    def run(self, side: str, operation: str, address: int, wdata: int, byte_count: int, floor) -> dict:
        errors = []
        if floor is not None:
            self.session.write_side(side, self.floor, floor & 0xFFFFFFFF)
        status = rdata = 0
        byte_map: dict[int, int] = {}
        try:
            if operation == "status":
                pass
            elif operation == "rdsr":
                status, rdata = self._pulse(side, OP_RDSR, None, 0, 0, 5)
            elif operation == "rdid":
                status, rdata = self._pulse(side, OP_RDID, address, 2, 0, 5)
            elif operation in ("read", "fast_read"):
                opcode = OP_READ if operation == "read" else OP_FAST_READ
                offset = 0
                while offset < byte_count:
                    remain = byte_count - offset
                    chunk = min(4, remain)
                    status, rdata = self._pulse(side, opcode, address + offset, chunk - 1, 0, 10)
                    for i in range(chunk):
                        byte_map[(address + offset + i) & 0xFFFFFFFF] = (rdata >> (8 * i)) & 0xFF
                    offset += chunk
            elif operation == "write_byte":
                self._pulse(side, OP_WREN, None, 0, 0, 5)
                status, rdata = self._pulse(side, OP_PAGE_PROGRAM, address, 0, wdata, 15)
            elif operation == "erase_sector":
                self._pulse(side, OP_WREN, None, 0, 0, 5)
                status, rdata = self._pulse(side, OP_SECTOR_ERASE, address, 0, 0, 120)
            elif operation == "erase_block":
                self._pulse(side, OP_WREN, None, 0, 0, 5)
                status, rdata = self._pulse(side, OP_BLOCK_ERASE, address, 0, 0, 180)
            else:
                errors.append(f"unknown operation {operation}")
        except Exception as exc:
            errors.append(str(exc))
            status = self.session.read_side(side, self.status)
            rdata = self.session.read_side(side, self.rdata)
        if operation == "status" and not errors:
            status = self.session.read_side(side, self.status)
            rdata = self.session.read_side(side, self.rdata)
        nbytes = 3 if operation == "rdid" else 1 if operation == "rdsr" else 4
        return {
            "side": side,
            "status": _decode_status(status),
            "rdata": _decode_rdata(rdata, nbytes),
            "errors": errors,
            "hex_dump": _hex_dump(byte_map, address, byte_count) if byte_map else None,
        }


def register(app, ctx, manifest):
    bp = Blueprint("plugin_tilecal_flash", __name__, url_prefix="/api/plugins/tilecal_flash_driver")
    session = ctx["session"]

    def _sides(body) -> list[str]:
        side = str(body.get("side") or "both").strip().upper()
        if side == "BOTH":
            return ["A", "B"]
        if side in ("A", "B"):
            return [side]
        raise ValueError("side must be A, B, or both")

    @bp.route("/status")
    def status():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        try:
            with session.lock:
                flash = _Flash(session)
                results = [flash.snapshot(side) for side in ("A", "B")]
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        return jsonify({"success": True, "operation": "status", "sides": results})

    @bp.route("/execute", methods=["POST"])
    def execute():
        blocked = ctx["require_connected"]()
        if blocked:
            return blocked
        body = request.get_json(silent=True) or {}
        operation = str(body.get("operation") or "").strip().lower()
        if not operation:
            return jsonify({"success": False, "error": "operation required"}), 400
        try:
            sides = _sides(body)
        except ValueError as exc:
            return jsonify({"success": False, "error": str(exc)}), 400
        if operation in _MUTATING and sides != ["A"] and sides != ["B"]:
            return jsonify({
                "success": False,
                "error": "Write and erase run on one FPGA. Choose side A or side B.",
            }), 400
        address = _parse_int(body.get("address"), 0)
        wdata = _parse_int(body.get("wdata"), 0) & 0xFF
        byte_count = max(1, min(_parse_int(body.get("byte_count"), 64), 4096))
        floor = _parse_int(body.get("floor"), 0) if body.get("floor_enable") else None
        try:
            with session.lock:
                flash = _Flash(session)
                if operation == "status":
                    results = [flash.snapshot(side) for side in sides]
                else:
                    results = [
                        flash.run(side, operation, address, wdata, byte_count, floor)
                        for side in sides
                    ]
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 500
        errors = [err for row in results for err in row["errors"]]
        return jsonify({
            "success": not errors,
            "operation": operation,
            "sides": results,
            "errors": errors,
        })

    app.register_blueprint(bp)

    def _tree(md_node):
        md_node["children"].append({
            "type": "tilecal_flash_driver",
            "name": "TileCal DB FLASH Driver",
            "plugin": "tilecal_flash_driver",
        })

    register_tree_hook("tilecal_flash_driver", _tree)
