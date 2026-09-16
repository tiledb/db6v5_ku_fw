"""Parse db6_data_readout_debug VIO capture results."""

from __future__ import annotations

from typing import Any

from plugins.common.db6_hw_map import (
    DATA_READOUT_ADC_BITS,
    DATA_READOUT_CHANNEL_COUNT,
    DATA_READOUT_SAMPLE_BITS,
    DATA_READOUT_SAMPLE_COUNT,
)

ADC_MASK = (1 << DATA_READOUT_ADC_BITS) - 1
SAMPLE_MASK = (1 << DATA_READOUT_SAMPLE_BITS) - 1
GAINS = ("hg", "lg", "fc")


def parse_hex(value, width_bits: int = DATA_READOUT_ADC_BITS) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text in ("N/A", "—", "-"):
        return None
    mask = (1 << width_bits) - 1 if width_bits > 0 else 0xFFFFFFFF
    try:
        if text.lower().startswith("0x"):
            return int(text, 16) & mask
        return int(text, 16) & mask
    except (TypeError, ValueError):
        try:
            return int(text, 10) & mask
        except (TypeError, ValueError):
            return None


def decode_sample(raw: int | None) -> dict[str, Any]:
    if raw is None:
        return {
            "raw": None,
            "raw_hex": "—",
            "adc12": None,
            "adc12_hex": "—",
            "adc14": None,
            "adc14_hex": "—",
        }
    adc14 = raw & ADC_MASK
    adc12 = (raw >> (DATA_READOUT_ADC_BITS - DATA_READOUT_SAMPLE_BITS)) & SAMPLE_MASK
    return {
        "raw": raw,
        "raw_hex": f"0x{raw:04X}",
        "adc12": adc12,
        "adc12_hex": f"0x{adc12:03X}",
        "adc14": adc14,
        "adc14_hex": f"0x{adc14:04X}",
    }


def parse_probe_map(output: str, parse_rows) -> dict[str, str]:
    probes: dict[str, str] = {}
    for row in parse_rows(output, "ADCRDPROBE", 3):
        role, name = row
        if role and name:
            probes[role] = name
    return probes


def parse_errors(output: str) -> list[str]:
    errors: list[str] = []
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("ADCRDERR|"):
            errors.append(line.split("|", 1)[1])
    return errors


def parse_captured(output: str, parse_rows) -> dict[str, Any]:
    captured = None
    raw = None
    for row in parse_rows(output, "ADCRDCAPTURED", 3):
        ok_text, cap_text = row
        raw = parse_hex(cap_text, 8)
        if raw is None:
            captured = ok_text.strip() in ("1", "true", "True")
        else:
            captured = bool(raw & 1) or ok_text.strip() in ("1", "true", "True")
    return {"captured": captured, "captured_raw": raw}


def parse_samples(output: str, parse_rows) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for row in parse_rows(output, "ADCRDSAMPLE", 6):
        ch_text, samp_text, hg_text, lg_text, fc_text = row
        try:
            channel = int(ch_text, 0)
            sample = int(samp_text, 0)
        except (TypeError, ValueError):
            continue
        samples.append({
            "channel": channel,
            "sample": sample,
            "hg": decode_sample(parse_hex(hg_text)),
            "lg": decode_sample(parse_hex(lg_text)),
            "fc": decode_sample(parse_hex(fc_text)),
        })
    return samples


def build_tables(samples: list[dict[str, Any]]) -> dict[str, Any]:
    grid: dict[str, list[list[dict[str, Any] | None]]] = {
        gain: [
            [None] * DATA_READOUT_CHANNEL_COUNT
            for _ in range(DATA_READOUT_SAMPLE_COUNT)
        ]
        for gain in GAINS
    }
    for row in samples:
        ch = row["channel"]
        samp = row["sample"]
        if not (0 <= ch < DATA_READOUT_CHANNEL_COUNT):
            continue
        if not (0 <= samp < DATA_READOUT_SAMPLE_COUNT):
            continue
        for gain in GAINS:
            grid[gain][samp][ch] = row[gain]

    tables: dict[str, Any] = {}
    for gain in GAINS:
        entries = []
        for samp in range(DATA_READOUT_SAMPLE_COUNT):
            entries.append({
                "sample": samp,
                "channels": [
                    grid[gain][samp][ch] or decode_sample(None)
                    for ch in range(DATA_READOUT_CHANNEL_COUNT)
                ],
            })
        tables[gain] = {
            "label": gain.upper(),
            "entries": entries,
        }
    return tables


def build_csv(tables: dict[str, Any]) -> str:
    lines = ["sample,channel,hg_raw,hg12,hg14,lg_raw,lg12,lg14,fc_raw,fc12,fc14"]
    for samp in range(DATA_READOUT_SAMPLE_COUNT):
        for ch in range(DATA_READOUT_CHANNEL_COUNT):
            cols: list[str] = [str(samp), str(ch)]
            for gain in GAINS:
                entries = (tables.get(gain) or {}).get("entries") or []
                row = entries[samp] if samp < len(entries) else None
                cell = (row.get("channels") or [None] * DATA_READOUT_CHANNEL_COUNT)[ch] if row else None
                raw = (cell or {}).get("raw")
                adc12 = (cell or {}).get("adc12")
                adc14 = (cell or {}).get("adc14")
                cols.extend([
                    "" if raw is None else str(raw),
                    "" if adc12 is None else str(adc12),
                    "" if adc14 is None else str(adc14),
                ])
            lines.append(",".join(cols))
    return "\n".join(lines) + "\n"


def parse_output(output: str, parse_rows) -> dict[str, Any]:
    samples = parse_samples(output, parse_rows)
    tables = build_tables(samples)
    cap = parse_captured(output, parse_rows)
    return {
        "probes": parse_probe_map(output, parse_rows),
        "errors": parse_errors(output),
        "captured": cap["captured"],
        "captured_raw": cap["captured_raw"],
        "samples": samples,
        "tables": tables,
        "csv": build_csv(tables),
        "sample_count": DATA_READOUT_SAMPLE_COUNT,
        "channel_count": DATA_READOUT_CHANNEL_COUNT,
        "sample_bits": DATA_READOUT_SAMPLE_BITS,
        "adc_bits": DATA_READOUT_ADC_BITS,
    }
