"""IS25LP256 flash driver command encoding and result parsing."""

from __future__ import annotations

from typing import Any

# Internal opcodes (cfb_flash_command bits 27:24) — db7_is25lp256_driver.vhd
OP_NOP = 0x0
OP_WREN = 0x1
OP_WRDI = 0x2
OP_RDSR = 0x3
OP_READ = 0x4
OP_FAST_READ = 0x5
OP_PAGE_PROGRAM = 0x6
OP_SECTOR_ERASE = 0x7
OP_BLOCK_ERASE = 0x8
OP_CHIP_ERASE = 0x9
OP_RDID = 0xA

OP_NAMES = {
    OP_WREN: "WREN",
    OP_WRDI: "WRDI",
    OP_RDSR: "RDSR",
    OP_READ: "READ",
    OP_FAST_READ: "FAST_READ",
    OP_PAGE_PROGRAM: "PAGE_PROGRAM",
    OP_SECTOR_ERASE: "SECTOR_ERASE",
    OP_BLOCK_ERASE: "BLOCK_ERASE",
    OP_CHIP_ERASE: "CHIP_ERASE",
    OP_RDID: "RDID",
}


def encode_command(opcode: int, *, start: bool = False, length_sel: int = 0, wdata: int = 0) -> int:
    """Build 32-bit flash_manual_command value."""
    cmd = ((opcode & 0xF) << 24) | ((length_sel & 0x3) << 8) | (wdata & 0xFF)
    if start:
        cmd |= 1 << 31
    return cmd & 0xFFFFFFFF


def parse_hex32(value) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text in ("N/A", "—", "-"):
        return None
    try:
        if text.lower().startswith("0x"):
            return int(text, 16) & 0xFFFFFFFF
        return int(text, 16) & 0xFFFFFFFF
    except (TypeError, ValueError):
        return None


def decode_status(raw: int | None) -> dict[str, Any]:
    if raw is None:
        return {
            "raw": None,
            "raw_hex": "—",
            "busy": None,
            "done": None,
            "write_blocked": None,
            "status_reg": None,
            "op_latched": None,
        }
    return {
        "raw": raw,
        "raw_hex": f"0x{raw:08X}",
        "busy": bool(raw & 0x1),
        "done": bool(raw & 0x2),
        "write_blocked": bool(raw & 0x8000),
        "status_reg": (raw >> 2) & 0xFF,
        "op_latched": (raw >> 16) & 0xF,
        "op_name": OP_NAMES.get((raw >> 16) & 0xF, f"0x{(raw >> 16) & 0xF:X}"),
    }


def decode_rdata(raw: int | None, byte_count: int = 4) -> dict[str, Any]:
    if raw is None:
        return {"raw": None, "raw_hex": "—", "bytes": []}
    nbytes = max(1, min(int(byte_count), 4))
    out_bytes = []
    for i in range(nbytes - 1, -1, -1):
        out_bytes.append((raw >> (8 * i)) & 0xFF)
    return {
        "raw": raw,
        "raw_hex": f"0x{raw:08X}",
        "bytes": out_bytes,
        "bytes_hex": " ".join(f"0x{b:02X}" for b in out_bytes),
    }


def parse_flash_bytes(output: str, parse_rows) -> dict[int, int]:
    """Parse FLASHBYTE|addr_hex|value_hex lines into address → byte map."""
    out: dict[int, int] = {}
    for row in parse_rows(output, "FLASHBYTE", 3):
        addr_text, val_text = row
        try:
            addr = int(addr_text, 16) & 0xFFFFFFFF
            val = int(val_text, 16) & 0xFF
        except (TypeError, ValueError):
            continue
        out[addr] = val
    return out


def build_hex_dump(
    byte_map: dict[int, int],
    base: int,
    length: int,
    *,
    cols: int = 16,
) -> dict[str, Any]:
    """Classic hex dump rows: address | 16 hex bytes | ASCII."""
    base = base & 0xFFFFFFFF
    length = max(0, min(int(length), 4096))
    rows: list[dict[str, str]] = []
    for row_off in range(0, length, cols):
        addr = (base + row_off) & 0xFFFFFFFF
        hex_cells: list[str] = []
        ascii_chars: list[str] = []
        for col in range(cols):
            off = row_off + col
            if off >= length:
                hex_cells.append("")
                ascii_chars.append(" ")
                continue
            val = byte_map.get((base + off) & 0xFFFFFFFF)
            if val is None:
                hex_cells.append("--")
                ascii_chars.append(" ")
            else:
                hex_cells.append(f"{val:02X}")
                ascii_chars.append(chr(val) if 32 <= val < 127 else ".")
        rows.append({
            "address_hex": f"0x{addr:08X}",
            "hex": " ".join(hex_cells).rstrip(),
            "ascii": "".join(ascii_chars).rstrip(),
        })
    return {
        "base": base,
        "base_hex": f"0x{base:08X}",
        "length": length,
        "cols": cols,
        "rows": rows,
        "byte_count": len(byte_map),
    }


def parse_flash_output(output: str, parse_rows) -> dict[str, Any]:
    errors: list[str] = []
    probes: dict[str, str] = {}
    status_raw = None
    rdata_raw = None
    for row in parse_rows(output, "FLASHPROBE", 3):
        role, name = row
        probes[role] = name
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("FLASHERR|"):
            errors.append(line.split("|", 1)[1])
        elif line.startswith("FLASHRESULT|"):
            parts = line.split("|")
            if len(parts) >= 3:
                status_raw = parse_hex32(parts[1])
                rdata_raw = parse_hex32(parts[2])
    return {
        "errors": errors,
        "probes": probes,
        "status_raw": status_raw,
        "rdata_raw": rdata_raw,
        "byte_map": parse_flash_bytes(output, parse_rows),
    }
