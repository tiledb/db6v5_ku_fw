"""Extract VIO probe net names from Vivado LTX (JSON) files."""

import json
from typing import Any


def _collect_net_names(net: dict[str, Any], out: list[str]) -> None:
    name = net.get("name")
    if not name:
        return
    if net.get("isBus") and net.get("subnets"):
        out.append(name)
        for sub in net.get("subnets", []):
            sn = sub.get("name")
            if sn:
                out.append(sn)
    else:
        out.append(name)


def parse_ltx_probes(ltx_path: str) -> list[dict[str, str]]:
    """Return probe dicts {name, direction, vio} from a Vivado JSON LTX file."""
    with open(ltx_path, encoding="utf-8", errors="replace") as f:
        data = json.load(f)

    probes: list[dict[str, str]] = []
    seen: set[str] = set()
    root = data.get("ltx_root", {})
    for item in root.get("ltx_data", []):
        for core in item.get("debug_cores", []):
            core_type = (core.get("type") or "").upper()
            if core_type != "VIO_V2":
                continue
            vio_name = core.get("name") or ""
            for pin in core.get("pins", []):
                direction = (pin.get("direction") or "IN").upper()
                if direction not in ("IN", "OUT"):
                    direction = "IN"
                names: list[str] = []
                for net in pin.get("nets", []):
                    _collect_net_names(net, names)
                for name in names:
                    if name in seen:
                        continue
                    seen.add(name)
                    probes.append({
                        "name": name,
                        "direction": direction,
                        "vio": vio_name,
                    })
    return probes
