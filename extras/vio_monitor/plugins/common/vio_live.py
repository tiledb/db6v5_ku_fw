"""Minimal VIO probe read — does not refresh_hw_device or refresh_hw_vio."""

from plugins.common.db6_hw_map import XADC_LIVE_PROBES
from plugins.common.probe_config import plugin_probe_match_names, tcl_probe_match, tcl_probe_match_any


def tcl_read_live_xadc_probes(device, probes=None):
    """Read live xadc channel address + raw code from VIO (no full VIO refresh)."""
    probes = probes or {}
    vol_names = plugin_probe_match_names(
        "xadc_channel_voltage",
        probes.get("xadc_channel_voltage") or XADC_LIVE_PROBES["xadc_channel_voltage"]["ltx"],
    )
    ch_names = plugin_probe_match_names(
        "xadc_channel",
        probes.get("xadc_channel") or XADC_LIVE_PROBES["xadc_channel"]["ltx"],
    )
    vol_legacy = probes.get("xadc_voltage_legacy") or ""
    ch_legacy = probes.get("xadc_channel_legacy") or ""
    vol_match = tcl_probe_match_any(vol_names)
    ch_match = tcl_probe_match_any(ch_names)
    vol_legacy_match = tcl_probe_match(vol_legacy)
    ch_legacy_match = tcl_probe_match(ch_legacy)
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        'current_hw_device $__dev ; '
        'set __addr "" ; set __val "" ; '
        'foreach __vio [get_hw_vios -of_objects $__dev] { '
        'foreach __p [get_hw_probes -of_objects $__vio] { '
        'set __pname [get_property NAME $__p] ; '
        f'if {{{vol_match}}} {{ '
        'catch { refresh_hw_probe $__p } ; '
        'catch {set __val [get_property INPUT_VALUE $__p]} ; '
        'if {$__val eq ""} { catch {set __val [get_property OUTPUT_VALUE $__p]} } ; '
        f'}} elseif {{{vol_legacy_match}}} {{ '
        'catch { refresh_hw_probe $__p } ; '
        'catch {set __val [get_property INPUT_VALUE $__p]} ; '
        'if {$__val eq ""} { catch {set __val [get_property OUTPUT_VALUE $__p]} } ; '
        f'}} elseif {{{ch_match}}} {{ '
        'catch { refresh_hw_probe $__p } ; '
        'catch {set __addr [get_property INPUT_VALUE $__p]} ; '
        'if {$__addr eq ""} { catch {set __addr [get_property OUTPUT_VALUE $__p]} } ; '
        f'}} elseif {{{ch_legacy_match}}} {{ '
        'catch { refresh_hw_probe $__p } ; '
        'catch {set __addr [get_property INPUT_VALUE $__p]} ; '
        'if {$__addr eq ""} { catch {set __addr [get_property OUTPUT_VALUE $__p]} } ; '
        '} } } ; '
        'puts "VIOXADC|$__addr|$__val"'
    )


def parse_live_xadc_probes(output, parse_rows):
    for row in parse_rows(output, "VIOXADC", 3):
        addr_text, val_text = row
        return addr_text, val_text
    return None, None
