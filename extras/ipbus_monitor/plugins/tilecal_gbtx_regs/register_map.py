"""GBTx register names/descriptions from the GBTX Manual (Ch. 17, Tables 153–154)."""

from __future__ import annotations

import json
import os
from functools import lru_cache
from typing import Any


@lru_cache(maxsize=1)
def _load() -> dict[str, dict[str, Any]]:
    path = os.path.join(os.path.dirname(__file__), "gbtx_register_map.json")
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def lookup(addr: int) -> dict[str, Any]:
    """Return name/block/access/description/bits for a GBTx register address."""
    entry = _load().get(str(int(addr)))
    if not entry:
        return {
            "name": "—",
            "block": "—",
            "access": "—",
            "description": "",
            "bits": {},
        }
    return entry


def annotate_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Attach manual metadata to each scan row."""
    out: list[dict[str, Any]] = []
    for row in rows:
        info = lookup(int(row["address"]))
        annotated = dict(row)
        annotated["name"] = info.get("name") or "—"
        annotated["block"] = info.get("block") or "—"
        annotated["access"] = info.get("access") or "—"
        annotated["description"] = info.get("description") or ""
        bits = info.get("bits") or {}
        # Compact bit tooltip: "b0 sig — fn; b1 ..."
        tips = []
        for b in range(8):
            bd = bits.get(str(b)) or {}
            sig = (bd.get("signal") or "").strip()
            fn = (bd.get("function") or "").strip()
            if not sig and not fn:
                continue
            if fn and fn.lower() == "unused" and not sig:
                tips.append(f"b{b}: unused")
            elif sig and fn:
                tips.append(f"b{b}: {sig} — {fn}")
            else:
                tips.append(f"b{b}: {sig or fn}")
        annotated["bit_tooltip"] = "; ".join(tips)
        out.append(annotated)
    return out
