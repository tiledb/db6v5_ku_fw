"""System Monitor Tcl helpers shared by xadc / tilecal_xadc plugins."""


def tcl_dump_sysmon(device=None):
    dev_filter = (
        f'set __devs [list [get_hw_devices {{{device}}}]] ; '
        if device else
        'set __devs [get_hw_devices] ; '
    )
    return (
        dev_filter +
        'foreach __dev $__devs { '
        'current_hw_device $__dev ; '
        'set __sms [get_hw_sysmons -of_objects $__dev] ; '
        'if {[llength $__sms] > 0} { catch { refresh_hw_sysmon $__sms } } ; '
        'foreach __sm $__sms { '
        'set __sname [get_property NAME $__sm] ; '
        'foreach __prop [lsort [list_property $__sm]] { '
        'if {![catch {set __val [get_property $__prop $__sm]}]} { '
        'puts "SYSMONROW|$__dev|$__sname|$__prop|$__val" '
        '} } } }'
    )


def parse_sysmon(output, parse_rows):
    rows = []
    for row in parse_rows(output, "SYSMONROW", 5):
        device, sysmon, prop, value = row
        rows.append({
            "device": device,
            "sysmon": sysmon,
            "property": prop,
            "value": value,
        })
    return rows
