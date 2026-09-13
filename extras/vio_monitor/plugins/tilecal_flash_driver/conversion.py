"""IS25LP256 flash driver command encoding and result parsing.

Encodes ``cfb_flash_command`` (bit31=start, bits28:24=opcode, bits9:8=length_sel,
bits7:0=wdata) and decodes ``stb_flash_status`` / ``stb_flash_rdata`` as defined
in ``db6_design_package.vhd`` / ``db7_is25lp256_driver.vhd``.
"""

from __future__ import annotations

from typing import Any

from plugins.common.db6_hw_map import (
    FLASH_CMD_LENGTH_MASK,
    FLASH_CMD_LENGTH_SHIFT,
    FLASH_CMD_OPCODE_MASK,
    FLASH_CMD_OPCODE_SHIFT,
    FLASH_CMD_START_BIT,
    FLASH_OP_BLOCK_ERASE,
    FLASH_OP_CHIP_ERASE,
    FLASH_OP_CLERP,
    FLASH_OP_FAST_READ,
    FLASH_OP_GBUN,
    FLASH_OP_NAMES,
    FLASH_OP_NOP,
    FLASH_OP_PAGE_PROGRAM,
    FLASH_OP_PAGE_READ,
    FLASH_OP_RDERP,
    FLASH_OP_RDID,
    FLASH_OP_RDSR,
    FLASH_OP_READ,
    FLASH_OP_RESET,
    FLASH_OP_RESET_ENABLE,
    FLASH_OP_SECTOR_ERASE,
    FLASH_OP_WRDI,
    FLASH_OP_WREN,
    FLASH_OP_WRSR,
    FLASH_STATUS_OP_MASK,
    FLASH_STATUS_OP_SHIFT,
    FLASH_STB,
)

# Re-export opcodes under the names backends already import.
OP_NOP = FLASH_OP_NOP
OP_WREN = FLASH_OP_WREN
OP_WRDI = FLASH_OP_WRDI
OP_RDSR = FLASH_OP_RDSR
OP_READ = FLASH_OP_READ
OP_FAST_READ = FLASH_OP_FAST_READ
OP_PAGE_PROGRAM = FLASH_OP_PAGE_PROGRAM
OP_SECTOR_ERASE = FLASH_OP_SECTOR_ERASE
OP_BLOCK_ERASE = FLASH_OP_BLOCK_ERASE
OP_CHIP_ERASE = FLASH_OP_CHIP_ERASE
OP_RDID = FLASH_OP_RDID
OP_RESET_ENABLE = FLASH_OP_RESET_ENABLE
OP_RESET = FLASH_OP_RESET
OP_PAGE_READ = FLASH_OP_PAGE_READ
OP_RDERP = FLASH_OP_RDERP
OP_CLERP = FLASH_OP_CLERP
OP_GBUN = FLASH_OP_GBUN
OP_WRSR = FLASH_OP_WRSR
OP_NAMES = FLASH_OP_NAMES


def encode_command(opcode: int, *, start: bool = False, length_sel: int = 0, wdata: int = 0) -> int:
    """Build 32-bit flash_manual_command / cfb_flash_command value."""
    cmd = (
        ((opcode & FLASH_CMD_OPCODE_MASK) << FLASH_CMD_OPCODE_SHIFT)
        | ((length_sel & FLASH_CMD_LENGTH_MASK) << FLASH_CMD_LENGTH_SHIFT)
        | (wdata & 0xFF)
    )
    if start:
        cmd |= 1 << FLASH_CMD_START_BIT
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
            "stb": FLASH_STB["status"]["name"],
            "stb_addr": FLASH_STB["status"]["addr"],
        }
    op_latched = (raw >> FLASH_STATUS_OP_SHIFT) & FLASH_STATUS_OP_MASK
    return {
        "raw": raw,
        "raw_hex": f"0x{raw:08X}",
        "busy": bool(raw & 0x1),
        "done": bool(raw & 0x2),
        "write_blocked": bool(raw & 0x8000),
        "status_reg": (raw >> 2) & 0xFF,
        "op_latched": op_latched,
        "op_name": OP_NAMES.get(op_latched, f"0x{op_latched:X}"),
        "stb": FLASH_STB["status"]["name"],
        "stb_addr": FLASH_STB["status"]["addr"],
    }


def decode_rdata(raw: int | None, byte_count: int = 4) -> dict[str, Any]:
    if raw is None:
        return {
            "raw": None,
            "raw_hex": "—",
            "bytes": [],
            "stb": FLASH_STB["rdata"]["name"],
            "stb_addr": FLASH_STB["rdata"]["addr"],
        }
    nbytes = max(1, min(int(byte_count), 4))
    out_bytes = []
    for i in range(nbytes - 1, -1, -1):
        out_bytes.append((raw >> (8 * i)) & 0xFF)
    return {
        "raw": raw,
        "raw_hex": f"0x{raw:08X}",
        "bytes": out_bytes,
        "bytes_hex": " ".join(f"0x{b:02X}" for b in out_bytes),
        "stb": FLASH_STB["rdata"]["name"],
        "stb_addr": FLASH_STB["rdata"]["addr"],
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
