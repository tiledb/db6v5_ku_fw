#!/usr/bin/env python3
"""
VIO Monitor - Flask web app that browses a live FPGA over Vivado's Hardware
Manager (hw_server -> hw_target -> hw_device -> properties/VIOs), the same
way the Vivado GUI's Hardware Manager view does.

It reuses the same persistent Vivado TCL session mechanism that the
vivado-mcp MCP server uses (vivado_mcp's vivado_session.VivadoSession):
one long-lived `vivado -mode tcl` process is kept running and driven with
plain Hardware Manager Tcl commands (connect_hw_server, open_hw_target,
get_hw_devices, get_hw_vios, get_hw_probes, ...). There is no dedicated
hardware-manager tool in vivado-mcp itself (its get_signal_value/
get_signal_values only talk to the XSim simulator), so this app issues the
Tcl directly via run_tcl.

Every Tcl command issued in the background is appended to an in-memory
console log that the web page polls, so it reads like a live Vivado Tcl
terminal; the page also lets you type ad-hoc Tcl commands into that
terminal.

Previously connected hw_servers are persisted to hw_servers.json next to
this file (override with VIO_MONITOR_CONFIG) so they show up as one-click
options next time.

Usage:
    python3 app.py                      # serves on http://0.0.0.0:5050
    HW_SERVER_URL=localhost:3121 python3 app.py
"""
import glob
import itertools
import json
import os
import re
import shutil
import sys
import threading
import time
from collections import deque
from datetime import datetime

import pexpect
from flask import Flask, jsonify, request, render_template_string

# vivado-mcp ships its session manager as a top-level module inside its
# package directory (not importable as `vivado_mcp.vivado_session`).
_VIVADO_MCP_PKG_DIR = os.environ.get(
    "VIVADO_MCP_PKG_DIR",
    "/opt/oss-cad-suite/lib/python3.11/site-packages/vivado_mcp",
)
if _VIVADO_MCP_PKG_DIR not in sys.path:
    sys.path.insert(0, _VIVADO_MCP_PKG_DIR)

from vivado_session import get_session, CommandResult  # noqa: E402


def _robust_start(sess):
    """Start a VivadoSession's process, tolerating banner text VivadoSession
    itself doesn't handle.

    vivado_session.py's own start() blocks on `child.expect('Start of
    session', timeout=120)`. Vivado 2025.2 prints that line in its TCL-mode
    boot banner, but Vivado 2022.2 never does -- on that build the stock
    start() just eats a full 120s timeout and reports failure even though
    Vivado came up fine and was sitting at its prompt the whole time. This
    mirrors VivadoSession.start() exactly except it also accepts the
    'Vivado%' prompt itself as a valid readiness signal, since that's what
    actually matters.
    """
    if sess.is_running:
        return CommandResult(
            command="start", output="Session already running",
            return_value="0", success=True, elapsed_ms=0,
        )

    start_time = time.time()
    try:
        sess.child = pexpect.spawn(
            f"{sess.vivado_path} -mode tcl -nojournal -nolog",
            encoding="utf-8", timeout=sess.timeout, echo=False,
        )
        sess.child.expect(["Start of session", "Vivado%"], timeout=120)
        time.sleep(1)
        try:
            sess.child.read_nonblocking(size=100000, timeout=1)
        except (pexpect.TIMEOUT, pexpect.EOF):
            pass
        sess.child.sendline("")
        sess.child.expect("Vivado%", timeout=10)

        sess.is_running = True
        sess.stats["session_start"] = datetime.now().isoformat()
        elapsed = (time.time() - start_time) * 1000
        return CommandResult(
            command="start", output="Vivado session started successfully",
            return_value="0", success=True, elapsed_ms=elapsed,
        )
    except pexpect.TIMEOUT:
        sess.is_running = False
        elapsed = (time.time() - start_time) * 1000
        return CommandResult(
            command="start", output="Failed to start Vivado: Timeout waiting for startup",
            return_value="1", success=False, elapsed_ms=elapsed,
        )
    except Exception as e:
        sess.is_running = False
        elapsed = (time.time() - start_time) * 1000
        return CommandResult(
            command="start", output=f"Failed to start Vivado: {e}",
            return_value="1", success=False, elapsed_ms=elapsed,
        )


_VERSION_RE = re.compile(r"(\d{4}\.\d+)")


def _find_all_vivado():
    """Scan the usual Xilinx install locations for every `vivado` executable.

    `vivado` is usually not on PATH for a plain shell (it's only added by
    Xilinx's settings64.sh, which most people don't source for a background
    web server), so this scans install locations directly. Returns a list
    of {"version": ..., "path": ...} sorted newest first. The version
    label is parsed out of the install path itself (e.g.
    .../2025.2/Vivado/bin/vivado -> "2025.2") rather than asking each
    binary for its own version, which would mean spawning every one of
    them just to build the list.
    """
    paths = set()
    env_path = os.environ.get("VIVADO_PATH")
    if env_path and os.path.isfile(env_path):
        paths.add(env_path)
    which = shutil.which("vivado")
    if which:
        paths.add(which)
    for pattern in (
        "/tools/Xilinx/*/Vivado/bin/vivado",
        "/tools/Xilinx/*/Vivado/*/bin/vivado",
        "/opt/Xilinx/Vivado/*/bin/vivado",
        "/opt/Xilinx/*/Vivado/bin/vivado",
        "/opt/Xilinx/*/Vivado/*/bin/vivado",
    ):
        paths.update(glob.glob(pattern))

    versions = []
    for path in paths:
        matches = _VERSION_RE.findall(path)
        version = matches[-1] if matches else path
        versions.append({"version": version, "path": path})

    # Newest version first; ties fall back to path for a stable order.
    versions.sort(key=lambda v: (v["version"], v["path"]), reverse=True)
    return versions


CONFIG_PATH = os.environ.get(
    "VIO_MONITOR_CONFIG",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "hw_servers.json"),
)
_config_lock = threading.Lock()


def _load_config():
    if not os.path.exists(CONFIG_PATH):
        return {"hw_servers": []}
    try:
        with open(CONFIG_PATH) as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {"hw_servers": []}


def _save_config(cfg):
    tmp_path = CONFIG_PATH + ".tmp"
    with open(tmp_path, "w") as f:
        json.dump(cfg, f, indent=2)
    os.replace(tmp_path, CONFIG_PATH)


app = Flask(__name__)
session = get_session()
VIVADO_VERSIONS = _find_all_vivado()

_startup_cfg = _load_config()
_saved_vivado = _startup_cfg.get("vivado_path")
if _saved_vivado and os.path.isfile(_saved_vivado):
    VIVADO_PATH = _saved_vivado
elif VIVADO_VERSIONS:
    VIVADO_PATH = VIVADO_VERSIONS[0]["path"]
else:
    VIVADO_PATH = "vivado"
session.vivado_path = VIVADO_PATH

_lock = threading.Lock()  # serializes multi-step Tcl flows across requests

DEFAULT_HW_SERVER_URL = os.environ.get("HW_SERVER_URL", "localhost:3121")


# =============================================================================
# hw_servers.json persistence
# =============================================================================

def _add_hw_server(url, name=""):
    with _config_lock:
        cfg = _load_config()
        servers = cfg.setdefault("hw_servers", [])
        for s in servers:
            if s["url"] == url:
                if name:
                    s["name"] = name
                cfg["last_connected"] = url
                _save_config(cfg)
                return cfg
        servers.append({
            "url": url,
            "name": name,
            "added": datetime.now().isoformat(timespec="seconds"),
        })
        cfg["last_connected"] = url
        _save_config(cfg)
        return cfg


def _remove_hw_server(url):
    with _config_lock:
        cfg = _load_config()
        cfg["hw_servers"] = [s for s in cfg.get("hw_servers", []) if s["url"] != url]
        _save_config(cfg)
        return cfg


# =============================================================================
# Console log ("terminal" backing store)
# =============================================================================

_console_lock = threading.Lock()
_console = deque(maxlen=2000)
_console_ids = itertools.count(1)


def _log_console(cmd, result):
    entry = {
        "id": next(_console_ids),
        "ts": datetime.now().strftime("%H:%M:%S"),
        "cmd": cmd if len(cmd) <= 500 else cmd[:500] + " ...",
        "output": result.output,
        "success": result.success,
        "elapsed_ms": round(result.elapsed_ms, 1),
    }
    with _console_lock:
        _console.append(entry)
    return entry


# =============================================================================
# Vivado session helpers
# =============================================================================

def _ensure_started():
    if not session.is_running:
        result = _robust_start(session)
        _log_console("<start vivado session>", result)
        if not result.success:
            raise RuntimeError(f"Failed to start Vivado TCL session: {result.output}")


def _select_vivado_version(path):
    """Point the session at a different vivado executable.

    The Tcl session is a single long-lived process, so its executable can't
    be swapped underneath it -- if one is currently running it has to be
    stopped and a fresh one started with the new path (which also drops
    any hw_server connection the old process had open).
    """
    global VIVADO_PATH
    with _lock:
        was_running = session.is_running
        if was_running:
            stop_result = session.stop()
            _log_console(f"<stop vivado session (switching to {path})>", stop_result)
        VIVADO_PATH = path
        session.vivado_path = path
        with _config_lock:
            cfg = _load_config()
            cfg["vivado_path"] = path
            _save_config(cfg)
        if was_running:
            start_result = _robust_start(session)
            _log_console(f"<restart vivado session using {path}>", start_result)
            return start_result
    return None


def _run(cmd, timeout_override=None):
    """Run Tcl and log the literal command text -- not a paraphrase of it --
    so the terminal panel reflects exactly what was sent to Vivado."""
    _ensure_started()
    if timeout_override is not None:
        result = session.run_tcl(cmd, timeout_override=timeout_override)
    else:
        result = session.run_tcl(cmd)
    _log_console(cmd, result)
    return result


def _parse_rows(output, prefix, nfields):
    """Parse lines like 'PREFIX|a|b|...' (nfields total incl. prefix)."""
    rows = []
    needle = prefix + "|"
    for line in output.splitlines():
        line = line.strip()
        if not line.startswith(needle):
            continue
        parts = line.split("|", nfields - 1)
        if len(parts) != nfields:
            continue
        rows.append(parts[1:])
    return rows


# Tcl command builders -- all list output as PREFIX|field|field... lines so
# the Python side can parse it without needing a JSON encoder in Tcl.

def _tcl_list_targets():
    # Only one hw_server can be open in Vivado at a time, so there's no
    # server to filter by -- connect_hw_server already made it current.
    # Keep this on one line: multiline Tcl sent through vivado_session loses
    # puts output on Vivado 2022.2. The hw_target object name IS the display
    # name (e.g. host:3121/xilinx_tcf/Digilent/210249B07199).
    return 'foreach __t [get_hw_targets] { puts "TARGETROW|$__t" }'


def _parse_targets(output):
    """Extract hw_target names from Tcl list-targets output."""
    targets = [row[0] for row in _parse_rows(output, "TARGETROW", 2)]
    if targets:
        return targets
    # Fallback: bare `get_hw_targets` prints space-separated names on one line.
    for line in output.splitlines():
        line = line.strip()
        if not line or line.startswith("INFO:") or line.startswith("WARNING:"):
            continue
        if "|" in line:
            continue
        parts = line.split()
        if parts:
            return parts
    return []


def _tcl_open_target_and_list_devices(target):
    return (
        f"current_hw_target [get_hw_targets {{{target}}}] ; "
        "open_hw_target ; "
        'foreach __d [get_hw_devices] { puts "DEVICEROW|[get_property NAME $__d]|[get_property PART $__d]" }'
    )


_LIST_DEVICES_TCL = (
    'foreach __d [get_hw_devices] { puts "DEVICEROW|[get_property NAME $__d]|[get_property PART $__d]" }'
)


def _tcl_device_properties(device):
    return (
        f"set __dev [get_hw_devices {{{device}}}]\n"
        "foreach __prop [lsort [list_property $__dev]] {\n"
        "    if {[catch {set __val [get_property $__prop $__dev]} __err]} {\n"
        '        set __val "<error: $__err>"\n'
        "    }\n"
        '    puts "DEVPROP|$__prop|$__val"\n'
        "}\n"
    )


# Walks every hw_device on the currently open hw_target, refreshes every
# hw_vio on it, and dumps one pipe-delimited line per probe. Direction is
# discovered by trying INPUT_VALUE first (VIO capture probes, i.e.
# probe_in*) and falling back to OUTPUT_VALUE (VIO drive probes, i.e.
# probe_out*), instead of relying on an assumed property name.
_DUMP_VIOS_TCL = r"""
foreach __dev [get_hw_devices] {
    current_hw_device $__dev
    refresh_hw_device -update_hw_probes false $__dev
    set __vios [get_hw_vios -of_objects $__dev]
    if {[llength $__vios] > 0} { refresh_hw_vio $__vios }
    foreach __vio $__vios {
        set __vname [get_property NAME $__vio]
        foreach __p [get_hw_probes -of_objects $__vio] {
            set __pname [get_property NAME $__p]
            set __dir "IN"
            if {[catch {set __val [get_property INPUT_VALUE $__p]}]} {
                set __dir "OUT"
                if {[catch {set __val [get_property OUTPUT_VALUE $__p]}]} {
                    set __val "N/A"
                    set __dir "UNKNOWN"
                }
            }
            puts "VIOROW|[get_property NAME $__dev]|$__vname|$__pname|$__dir|$__val"
        }
    }
}
"""


@app.errorhandler(RuntimeError)
def handle_runtime_error(e):
    return jsonify({"success": False, "error": str(e)}), 500


# =============================================================================
# Vivado version selection
# =============================================================================

@app.route("/api/vivado/versions")
def api_vivado_versions():
    return jsonify({"versions": VIVADO_VERSIONS, "current": VIVADO_PATH})


@app.route("/api/vivado/select", methods=["POST"])
def api_vivado_select():
    data = request.get_json(silent=True) or {}
    path = (data.get("path") or "").strip()
    if not path:
        return jsonify({"success": False, "error": "path required"}), 400

    known_paths = {v["path"] for v in VIVADO_VERSIONS}
    if path not in known_paths and not os.path.isfile(path):
        return jsonify({"success": False, "error": f"no such vivado executable: {path}"}), 400

    result = _select_vivado_version(path)
    return jsonify({
        "success": True,
        "path": VIVADO_PATH,
        "restarted": result is not None,
        "restart_success": result.success if result else None,
        "restart_output": result.output if result else None,
    })


# =============================================================================
# hw_servers (config + connect)
# =============================================================================

@app.route("/api/hw_servers", methods=["GET"])
def api_hw_servers_list():
    return jsonify(_load_config())


@app.route("/api/hw_servers", methods=["POST"])
def api_hw_servers_add():
    data = request.get_json(silent=True) or {}
    url = (data.get("url") or "").strip()
    if not url:
        return jsonify({"success": False, "error": "url required"}), 400
    cfg = _add_hw_server(url, (data.get("name") or "").strip())
    return jsonify({"success": True, "hw_servers": cfg["hw_servers"]})


@app.route("/api/hw_servers", methods=["DELETE"])
def api_hw_servers_remove():
    data = request.get_json(silent=True) or {}
    url = (data.get("url") or "").strip()
    cfg = _remove_hw_server(url)
    return jsonify({"success": True, "hw_servers": cfg["hw_servers"]})


@app.route("/api/hw_servers/connect", methods=["POST"])
def api_hw_server_connect():
    data = request.get_json(silent=True) or {}
    url = (data.get("url") or DEFAULT_HW_SERVER_URL).strip()
    name = (data.get("name") or "").strip()
    if not url:
        return jsonify({"success": False, "error": "url required"}), 400

    with _lock:
        steps = {}
        steps["open_hw_manager"] = vars(_run("open_hw_manager"))
        steps["connect_hw_server"] = vars(_run(f"connect_hw_server -url {{{url}}}"))
        list_result = _run(_tcl_list_targets())
        steps["list_targets"] = vars(list_result)

    connect_success = steps["connect_hw_server"]["success"]
    # Require both steps to succeed so a broken target listing shows up as
    # an error instead of silently looking like "connected, zero targets".
    success = connect_success and steps["list_targets"]["success"]
    targets = _parse_targets(list_result.output)

    if connect_success:
        _add_hw_server(url, name)

    return jsonify({"success": success, "url": url, "steps": steps, "targets": targets})


# =============================================================================
# hw_targets
# =============================================================================

@app.route("/api/targets", methods=["GET"])
def api_targets_list():
    with _lock:
        result = _run(_tcl_list_targets())
    targets = _parse_targets(result.output)
    return jsonify({"success": result.success, "targets": targets, "output": result.output})


@app.route("/api/session/hw_state")
def api_session_hw_state():
    """Report live hw_manager state so the UI can restore after a page reload."""
    cfg = _load_config()
    if not session.is_running:
        return jsonify({
            "vivado_running": False,
            "connected": False,
            "server_url": cfg.get("last_connected"),
            "targets": [],
            "devices": [],
            "saved_hw_servers": cfg.get("hw_servers", []),
        })

    with _lock:
        servers_result = _run("get_hw_servers")
        targets_result = _run(_tcl_list_targets())
        devices_result = _run(_LIST_DEVICES_TCL)

    server_lines = [
        ln.strip() for ln in servers_result.output.splitlines()
        if ln.strip() and not ln.startswith("INFO:")
    ]
    connected = servers_result.success and bool(server_lines)
    server_url = server_lines[0] if server_lines else cfg.get("last_connected")
    targets = _parse_targets(targets_result.output)
    devices = [
        {"name": row[0], "part": row[1]}
        for row in _parse_rows(devices_result.output, "DEVICEROW", 3)
    ]

    return jsonify({
        "vivado_running": True,
        "connected": connected,
        "server_url": server_url,
        "targets": targets,
        "devices": devices,
        "target_open": bool(devices),
        "saved_hw_servers": cfg.get("hw_servers", []),
    })


@app.route("/api/targets/open", methods=["POST"])
def api_target_open():
    data = request.get_json(silent=True) or {}
    target = (data.get("target") or "").strip()
    if not target:
        return jsonify({"success": False, "error": "target required"}), 400
    with _lock:
        result = _run(_tcl_open_target_and_list_devices(target))
    devices = [
        {"name": row[0], "part": row[1]}
        for row in _parse_rows(result.output, "DEVICEROW", 3)
    ]
    return jsonify({
        "success": result.success,
        "target": target,
        "devices": devices,
        "output": result.output,
    })


# =============================================================================
# hw_devices
# =============================================================================

@app.route("/api/devices", methods=["GET"])
def api_devices_list():
    with _lock:
        result = _run(_LIST_DEVICES_TCL)
    devices = [
        {"name": row[0], "part": row[1]}
        for row in _parse_rows(result.output, "DEVICEROW", 3)
    ]
    return jsonify({"success": result.success, "devices": devices, "output": result.output})


@app.route("/api/devices/<device>/properties")
def api_device_properties(device):
    with _lock:
        result = _run(_tcl_device_properties(device), timeout_override=60)
    properties = [
        {"name": row[0], "value": row[1]}
        for row in _parse_rows(result.output, "DEVPROP", 3)
    ]
    return jsonify({
        "success": result.success,
        "device": device,
        "properties": properties,
        "output": result.output,
    })


# =============================================================================
# VIOs
# =============================================================================

@app.route("/api/vios")
def api_vios():
    with _lock:
        result = _run(_DUMP_VIOS_TCL, timeout_override=60)

    vios = {}
    for row in _parse_rows(result.output, "VIOROW", 6):
        device, vio, probe, direction, value = row
        key = f"{device} / {vio}"
        vios.setdefault(key, []).append(
            {"probe": probe, "direction": direction, "value": value}
        )

    return jsonify({"success": result.success, "output": result.output, "vios": vios})


# =============================================================================
# Session lifecycle / status / raw terminal
# =============================================================================

@app.route("/api/disconnect", methods=["POST"])
def api_disconnect():
    with _lock:
        result = _run("close_hw_target; disconnect_hw_server; close_hw_manager")
    return jsonify({"success": result.success, "output": result.output})


@app.route("/api/status")
def api_status():
    stats = session.get_stats()
    stats["vivado_path"] = VIVADO_PATH
    stats["vivado_versions"] = VIVADO_VERSIONS
    return jsonify(stats)


@app.route("/api/console")
def api_console():
    after = request.args.get("after", 0, type=int)
    with _console_lock:
        entries = [e for e in _console if e["id"] > after]
        last_id = _console[-1]["id"] if _console else after
    return jsonify({"entries": entries, "last_id": last_id})


@app.route("/api/tcl", methods=["POST"])
def api_tcl():
    data = request.get_json(silent=True) or {}
    cmd = (data.get("cmd") or "").strip()
    if not cmd:
        return jsonify({"success": False, "error": "cmd required"}), 400
    with _lock:
        result = _run(cmd)
    return jsonify({"success": result.success, "output": result.output})


# =============================================================================
# Web UI
# =============================================================================

INDEX_HTML = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>VIO Monitor</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: system-ui, sans-serif; margin: 2rem; background: #111; color: #eee; }
  h1 { font-size: 1.3rem; }
  h2 { font-size: 1rem; margin: 1.5rem 0 .5rem; border-bottom: 1px solid #333; padding-bottom: .25rem; }
  h3 { font-size: .95rem; margin: .5rem 0; }
  .row { display: flex; gap: .5rem; align-items: center; margin-bottom: .75rem; flex-wrap: wrap; }
  input[type=text], select { padding: .4rem; background: #222; color: #eee; border: 1px solid #444; border-radius: 4px; }
  button { padding: .35rem .7rem; border: 1px solid #444; border-radius: 4px; background: #2a2a2a; color: #eee; cursor: pointer; }
  button:hover { background: #333; }
  #status { font-size: .85rem; color: #999; white-space: pre-wrap; margin-bottom: 1rem; }
  table { border-collapse: collapse; width: 100%; margin-bottom: .5rem; }
  th, td { border: 1px solid #333; padding: .3rem .6rem; text-align: left; font-size: .85rem; }
  th { background: #1a1a1a; }
  .vio-group { background: #1a1a1a; font-weight: bold; }
  .dir-IN { color: #7fd; }
  .dir-OUT { color: #fc7; }
  .dir-UNKNOWN { color: #888; }
  .err { color: #f77; white-space: pre-wrap; }
  .muted { color: #777; font-size: .85rem; }
  .props-scroll { max-height: 320px; overflow-y: auto; }
  #terminal { background: #000; color: #9f9; font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              font-size: .8rem; height: 260px; overflow-y: auto; padding: .5rem; border-radius: 4px; border: 1px solid #333; }
  #terminal .term-cmd { color: #6cf; }
  #terminal .term-out { color: #ccc; white-space: pre-wrap; }
  #terminal .term-err { color: #f77; white-space: pre-wrap; }
  #termInputRow { display: flex; gap: .5rem; margin-top: .4rem; }
  #termInput { flex: 1; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
</style>
</head>
<body>
<h1>VIO Monitor</h1>
<div id="status">idle</div>

<h2>Vivado Version</h2>
<div class="row">
  <select id="vivadoVersionSelect" onchange="selectVivadoVersion()"></select>
</div>

<h2>Hardware Servers</h2>
<div class="row">
  <input type="text" id="newServerUrl" placeholder="host:port, e.g. localhost:3121" value="{{ default_url }}" size="24">
  <input type="text" id="newServerName" placeholder="name (optional)" size="16">
  <button onclick="addAndConnect()">Connect</button>
</div>
<div id="savedServersWrap"><p class="muted">Loading saved hw_servers...</p></div>

<h2>Targets</h2>
<div id="targetsWrap"><p class="muted">Connect to a hw_server to list its targets.</p></div>

<h2>Devices</h2>
<div id="devicesWrap"><p class="muted">Open a target to list its devices.</p></div>

<div id="propertiesWrap"></div>

<h2>VIOs</h2>
<div class="row">
  <label><input type="checkbox" id="autoRefresh" checked> auto-refresh</label>
  <button onclick="refreshVios()">Refresh now</button>
  <button onclick="disconnect()">Disconnect</button>
</div>
<div id="tableWrap"></div>

<h2>Terminal</h2>
<div id="terminal"></div>
<div id="termInputRow">
  <span>vivado%</span>
  <input type="text" id="termInput" placeholder="type a Tcl command and press Enter">
</div>

<script>
let vioTimer = null;
const INITIAL_CONFIG = {{ initial_config | safe }};

function setStatus(text, isErr) {
  const el = document.getElementById('status');
  el.textContent = text;
  el.className = isErr ? 'err' : '';
}

// --------------------------------------------------------- vivado version
async function loadVivadoVersions() {
  const r = await fetch('/api/vivado/versions');
  const j = await r.json();
  const sel = document.getElementById('vivadoVersionSelect');
  sel.innerHTML = '';
  if (!j.versions || j.versions.length === 0) {
    const opt = document.createElement('option');
    opt.textContent = 'no Vivado installs found (using "vivado" from PATH)';
    opt.disabled = true;
    opt.selected = true;
    sel.appendChild(opt);
    return;
  }
  for (const v of j.versions) {
    const opt = document.createElement('option');
    opt.value = v.path;
    opt.textContent = v.version + '   (' + v.path + ')';
    if (v.path === j.current) opt.selected = true;
    sel.appendChild(opt);
  }
}

async function selectVivadoVersion() {
  const sel = document.getElementById('vivadoVersionSelect');
  const path = sel.value;
  setStatus('switching to Vivado at ' + path + ' ...');
  try {
    const r = await fetch('/api/vivado/select', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({path})
    });
    const j = await r.json();
    if (!j.success) {
      setStatus('version switch failed: ' + (j.error || ''), true);
      return;
    }
    if (j.restarted) {
      setStatus(
        (j.restart_success ? 'session restarted' : 'session restart FAILED') +
        ' with ' + j.path + ' -- any hw_server connection was reset, reconnect below.',
        !j.restart_success
      );
      stopAutoRefresh();
      document.getElementById('targetsWrap').innerHTML = '<p class="muted">Connect to a hw_server to list its targets.</p>';
      document.getElementById('devicesWrap').innerHTML = '<p class="muted">Open a target to list its devices.</p>';
      document.getElementById('propertiesWrap').innerHTML = '';
      document.getElementById('tableWrap').innerHTML = '';
    } else {
      setStatus('will use ' + j.path + ' next time a session is started');
    }
  } catch (e) {
    setStatus('version switch error: ' + e, true);
  }
}

// ---------------------------------------------------------------- servers
function renderSavedServers(servers) {
  const wrap = document.getElementById('savedServersWrap');
  if (!servers || servers.length === 0) {
    wrap.innerHTML = '<p class="muted">No saved hw_servers yet.</p>';
    return;
  }
  let html = '<table><tr><th>URL</th><th>Name</th><th></th></tr>';
  for (const s of servers) {
    const u = s.url.replace(/'/g, "\\'");
    html += `<tr><td>${s.url}</td><td>${s.name || ''}</td>` +
            `<td><button onclick="connectServer('${u}')">Connect</button> ` +
            `<button onclick="removeServer('${u}')">Remove</button></td></tr>`;
  }
  html += '</table>';
  wrap.innerHTML = html;
}

async function loadSavedServers() {
  try {
    const r = await fetch('/api/hw_servers');
    const j = await r.json();
    renderSavedServers(j.hw_servers || []);
    if (j.last_connected) {
      document.getElementById('newServerUrl').value = j.last_connected;
    }
  } catch (e) {
    renderSavedServers(INITIAL_CONFIG.hw_servers || []);
    if (INITIAL_CONFIG.last_connected) {
      document.getElementById('newServerUrl').value = INITIAL_CONFIG.last_connected;
    }
  }
}

async function restoreSessionState() {
  try {
    const r = await fetch('/api/session/hw_state');
    const j = await r.json();
    if (j.saved_hw_servers && j.saved_hw_servers.length) {
      renderSavedServers(j.saved_hw_servers);
    }
    if (j.server_url) {
      document.getElementById('newServerUrl').value = j.server_url;
    }
    if (!j.connected) return;
    setStatus('restored connection to ' + (j.server_url || 'hw_server'));
    renderTargets(j.targets);
    if (j.target_open && j.devices && j.devices.length) {
      renderDevices(j.devices);
      startAutoRefresh();
      refreshVios();
    }
  } catch (e) {
    // non-fatal; saved servers still shown from loadSavedServers()
  }
}

async function removeServer(url) {
  await fetch('/api/hw_servers', {
    method: 'DELETE', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({url})
  });
  loadSavedServers();
}

async function addAndConnect() {
  const url = document.getElementById('newServerUrl').value.trim();
  const name = document.getElementById('newServerName').value.trim();
  if (!url) return;
  await connectServer(url, name);
}

async function connectServer(url, name) {
  setStatus('connecting to ' + url + ' ...');
  try {
    const r = await fetch('/api/hw_servers/connect', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({url, name: name || ''})
    });
    const j = await r.json();
    if (!j.success) {
      setStatus('connect failed -- see terminal for details', true);
      return;
    }
    setStatus('connected to ' + url);
    renderTargets(j.targets);
    document.getElementById('devicesWrap').innerHTML = '<p class="muted">Open a target to list its devices.</p>';
    document.getElementById('propertiesWrap').innerHTML = '';
    loadSavedServers();
  } catch (e) {
    setStatus('connect error: ' + e, true);
  }
}

// ---------------------------------------------------------------- targets
function renderTargets(targets) {
  const wrap = document.getElementById('targetsWrap');
  if (!targets || targets.length === 0) {
    wrap.innerHTML = '<p class="muted">No targets found on this hw_server.</p>';
    return;
  }
  let html = '<table><tr><th>Target</th><th></th></tr>';
  for (const t of targets) {
    const tEsc = t.replace(/'/g, "\\'");
    html += `<tr><td>${t}</td><td><button onclick="openTarget('${tEsc}')">Open</button></td></tr>`;
  }
  html += '</table>';
  wrap.innerHTML = html;
}

async function openTarget(target) {
  setStatus('opening target ' + target + ' ...');
  try {
    const r = await fetch('/api/targets/open', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({target})
    });
    const j = await r.json();
    if (!j.success) {
      setStatus('open target failed -- see terminal for details', true);
      return;
    }
    setStatus('opened target ' + target);
    renderDevices(j.devices);
    document.getElementById('propertiesWrap').innerHTML = '';
    startAutoRefresh();
    refreshVios();
  } catch (e) {
    setStatus('open target error: ' + e, true);
  }
}

// ---------------------------------------------------------------- devices
function renderDevices(devices) {
  const wrap = document.getElementById('devicesWrap');
  if (!devices || devices.length === 0) {
    wrap.innerHTML = '<p class="muted">No devices found on this target.</p>';
    return;
  }
  let html = '<table><tr><th>Device</th><th>Part</th><th></th></tr>';
  for (const d of devices) {
    const nEsc = d.name.replace(/'/g, "\\'");
    html += `<tr><td>${d.name}</td><td>${d.part}</td>` +
            `<td><button onclick="showDeviceProperties('${nEsc}')">Properties</button></td></tr>`;
  }
  html += '</table>';
  wrap.innerHTML = html;
}

async function showDeviceProperties(device) {
  setStatus('reading properties of ' + device + ' ...');
  const wrap = document.getElementById('propertiesWrap');
  try {
    const r = await fetch('/api/devices/' + encodeURIComponent(device) + '/properties');
    const j = await r.json();
    if (!j.success) {
      wrap.innerHTML = '';
      setStatus('properties failed -- see terminal for details', true);
      return;
    }
    setStatus('properties of ' + device + ' (' + j.properties.length + ')');
    let html = `<h3>Properties: ${device}</h3><div class="props-scroll"><table><tr><th>Property</th><th>Value</th></tr>`;
    for (const p of j.properties) {
      html += `<tr><td>${p.name}</td><td>${p.value}</td></tr>`;
    }
    html += '</table></div>';
    wrap.innerHTML = html;
  } catch (e) {
    setStatus('properties error: ' + e, true);
  }
}

// ---------------------------------------------------------------- VIOs
function renderVios(vios) {
  const wrap = document.getElementById('tableWrap');
  if (!vios || Object.keys(vios).length === 0) {
    wrap.innerHTML = '<p class="muted">No VIOs found.</p>';
    return;
  }
  let html = '<table><tr><th>VIO</th><th>Probe</th><th>Direction</th><th>Value</th></tr>';
  for (const [vio, probes] of Object.entries(vios)) {
    html += `<tr class="vio-group"><td colspan="4">${vio}</td></tr>`;
    for (const p of probes) {
      html += `<tr><td></td><td>${p.probe}</td><td class="dir-${p.direction}">${p.direction}</td><td>${p.value}</td></tr>`;
    }
  }
  html += '</table>';
  wrap.innerHTML = html;
}

async function refreshVios() {
  try {
    const r = await fetch('/api/vios');
    const j = await r.json();
    if (!j.success) {
      setStatus('VIO refresh failed -- see terminal for details', true);
      return;
    }
    setStatus('last VIO refresh: ' + new Date().toLocaleTimeString());
    renderVios(j.vios);
  } catch (e) {
    setStatus('VIO refresh error: ' + e, true);
  }
}

function startAutoRefresh() {
  stopAutoRefresh();
  if (document.getElementById('autoRefresh').checked) {
    vioTimer = setInterval(refreshVios, 2000);
  }
}
function stopAutoRefresh() {
  if (vioTimer) { clearInterval(vioTimer); vioTimer = null; }
}
document.getElementById('autoRefresh').addEventListener('change', () => {
  if (document.getElementById('autoRefresh').checked) startAutoRefresh();
  else stopAutoRefresh();
});

async function disconnect() {
  stopAutoRefresh();
  try {
    const r = await fetch('/api/disconnect', {method: 'POST'});
    const j = await r.json();
    setStatus(j.success ? 'disconnected' : 'disconnect failed -- see terminal for details', !j.success);
  } catch (e) {
    setStatus('disconnect error: ' + e, true);
  }
  document.getElementById('targetsWrap').innerHTML = '<p class="muted">Connect to a hw_server to list its targets.</p>';
  document.getElementById('devicesWrap').innerHTML = '<p class="muted">Open a target to list its devices.</p>';
  document.getElementById('propertiesWrap').innerHTML = '';
  document.getElementById('tableWrap').innerHTML = '';
}

// ---------------------------------------------------------------- terminal
let consoleCursor = 0;

async function pollConsole() {
  try {
    const r = await fetch('/api/console?after=' + consoleCursor);
    const j = await r.json();
    if (j.entries && j.entries.length) {
      const term = document.getElementById('terminal');
      for (const e of j.entries) {
        const cmdLine = document.createElement('div');
        cmdLine.className = 'term-cmd';
        cmdLine.textContent = '[' + e.ts + '] vivado% ' + e.cmd;
        term.appendChild(cmdLine);
        if (e.output) {
          const outLine = document.createElement('div');
          outLine.className = e.success ? 'term-out' : 'term-err';
          outLine.textContent = e.output;
          term.appendChild(outLine);
        }
      }
      consoleCursor = j.last_id;
      term.scrollTop = term.scrollHeight;
    }
  } catch (e) {
    // transient network hiccup while polling; ignore and retry next tick
  }
}
setInterval(pollConsole, 800);

document.getElementById('termInput').addEventListener('keydown', async (ev) => {
  if (ev.key !== 'Enter') return;
  const input = ev.target;
  const cmd = input.value;
  if (!cmd.trim()) return;
  input.value = '';
  input.disabled = true;
  try {
    await fetch('/api/tcl', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({cmd})
    });
  } catch (e) {
    // errors are surfaced through the terminal log itself
  }
  input.disabled = false;
  input.focus();
  pollConsole();
});

// ---------------------------------------------------------------- init
renderSavedServers(INITIAL_CONFIG.hw_servers || []);
if (INITIAL_CONFIG.last_connected) {
  document.getElementById('newServerUrl').value = INITIAL_CONFIG.last_connected;
}
loadVivadoVersions();
loadSavedServers();
restoreSessionState();
pollConsole();
</script>
</body>
</html>
"""


@app.route("/")
def index():
    cfg = _load_config()
    return render_template_string(
        INDEX_HTML,
        default_url=cfg.get("last_connected") or DEFAULT_HW_SERVER_URL,
        initial_config=json.dumps(cfg),
    )


if __name__ == "__main__":
    print(f"Using vivado executable: {VIVADO_PATH}")
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5050)), debug=False)
