"""List hw_probe objects on the current device (names for probe mapping UI)."""


def tcl_list_hw_probes(device: str) -> str:
    """Return Tcl that prints VIOPROBE|name|direction|vio_core lines."""
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        'current_hw_device $__dev ; '
        'foreach __vio [get_hw_vios -of_objects $__dev] { '
        'set __vname [get_property NAME $__vio] ; '
        'foreach __p [get_hw_probes -of_objects $__vio] { '
        'set __n [get_property NAME $__p] ; '
        'set __dir "IN" ; '
        'catch { if {[get_property PROBE_TYPE $__p] eq "OUTPUT"} { set __dir "OUT" } } ; '
        'puts "VIOPROBE|$__n|$__dir|$__vname" '
        '} }'
    )


def parse_vio_probe_list(output: str, parse_rows) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for row in parse_rows(output, "VIOPROBE", 4):
        name, direction, vio = row
        if name:
            rows.append({
                "name": name,
                "direction": direction or "IN",
                "vio": vio or "",
            })
    return rows
