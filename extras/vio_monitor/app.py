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
from flask import Flask, jsonify, request, render_template_string, send_file
from werkzeug.utils import secure_filename

_APP_DIR = os.path.dirname(os.path.abspath(__file__))
if _APP_DIR not in sys.path:
    sys.path.insert(0, _APP_DIR)

from plugins import registry as plugin_registry  # noqa: E402

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
        cfg = {"hw_servers": []}
    else:
        try:
            with open(CONFIG_PATH) as f:
                cfg = json.load(f)
        except (json.JSONDecodeError, OSError):
            cfg = {"hw_servers": []}
    return plugin_registry.ensure_plugins_config(cfg)


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


def _set_last_target(target):
    with _config_lock:
        cfg = _load_config()
        cfg["last_target"] = target
        _save_config(cfg)
        return cfg


def _set_last_device(device):
    with _config_lock:
        cfg = _load_config()
        cfg["last_device"] = device
        _save_config(cfg)
        return cfg


def _set_ltx_path(path):
    path = _abs_ltx_path(path)
    with _config_lock:
        cfg = _load_config()
        cfg["last_ltx"] = path
        files = cfg.setdefault("ltx_files", [])
        if path and path not in files:
            files.insert(0, path)
            cfg["ltx_files"] = files[:20]
        _save_config(cfg)
        return cfg


def _repo_root():
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _uploads_root():
    return os.path.join(_repo_root(), "bin", "uploads")


def _abs_hw_file_path(path):
    """Resolve hardware-related file paths to an absolute filesystem path."""
    if not path:
        return path
    path = path.strip()
    if os.path.isabs(path):
        return os.path.abspath(path)
    for base in (os.getcwd(), _repo_root(), os.path.dirname(os.path.abspath(__file__))):
        candidate = os.path.normpath(os.path.join(base, path))
        if os.path.isfile(candidate):
            return candidate
    return os.path.normpath(os.path.join(_repo_root(), path))


def _abs_ltx_path(path):
    return _abs_hw_file_path(path)


def _find_ltx_candidates():
    """Return absolute *.ltx paths under common project/build locations."""
    roots = set()
    here = os.path.dirname(os.path.abspath(__file__))
    roots.add(here)
    roots.add(os.path.dirname(here))
    roots.add(_repo_root())
    env_root = os.environ.get("VIO_MONITOR_LTX_ROOT")
    if env_root:
        roots.add(os.path.abspath(env_root))
    cfg = _load_config()
    found = set()
    for p in cfg.get("ltx_files", []):
        if p:
            abs_p = _abs_ltx_path(p)
            if os.path.isfile(abs_p):
                found.add(abs_p)
    for root in roots:
        if not os.path.isdir(root):
            continue
        for pattern in ("**/*.ltx",):
            for path in glob.glob(os.path.join(root, pattern), recursive=True):
                if os.path.isfile(path):
                    found.add(os.path.abspath(path))
    return sorted(found, reverse=True)


def _find_program_candidates(ext):
    """Return absolute *.{bit,bin} paths under common project/build locations."""
    if ext not in ("bit", "bin"):
        return []
    roots = set()
    here = os.path.dirname(os.path.abspath(__file__))
    roots.add(here)
    roots.add(os.path.dirname(here))
    roots.add(_repo_root())
    env_root = os.environ.get("VIO_MONITOR_BITSTREAM_ROOT")
    if env_root:
        roots.add(os.path.abspath(env_root))
    cfg = _load_config()
    cfg_key = f"{ext}_files"
    found = set()
    for p in cfg.get(cfg_key, []):
        if p:
            abs_p = _abs_hw_file_path(p)
            if os.path.isfile(abs_p):
                found.add(abs_p)
    for root in roots:
        if not os.path.isdir(root):
            continue
        pattern = os.path.join(root, f"**/*.{ext}")
        for path in glob.glob(pattern, recursive=True):
            if os.path.isfile(path):
                found.add(os.path.abspath(path))
    return sorted(found, reverse=True)


def _set_program_path(path, ext):
    path = _abs_hw_file_path(path)
    if ext not in ("bit", "bin"):
        return _load_config()
    with _config_lock:
        cfg = _load_config()
        cfg[f"last_{ext}"] = path
        files = cfg.setdefault(f"{ext}_files", [])
        if path and path not in files:
            files.insert(0, path)
            cfg[f"{ext}_files"] = files[:20]
        _save_config(cfg)
        return cfg


TCL_HISTORY_PATH = os.environ.get(
    "VIO_MONITOR_TCL_HISTORY",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "tcl_history.json"),
)
TCL_HISTORY_MAX_ENTRIES = 10000
TCL_HISTORY_MAX_LINE_LEN = 10000
_history_lock = threading.Lock()


def _load_tcl_history():
    if not os.path.exists(TCL_HISTORY_PATH):
        return []
    try:
        with open(TCL_HISTORY_PATH, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, list):
            return [str(line) for line in data[-TCL_HISTORY_MAX_ENTRIES:]]
    except (json.JSONDecodeError, OSError, TypeError):
        pass
    return []


def _append_tcl_history(cmd):
    cmd = cmd.strip()[:TCL_HISTORY_MAX_LINE_LEN]
    if not cmd:
        return _load_tcl_history()
    with _history_lock:
        history = _load_tcl_history()
        if history and history[-1] == cmd:
            return history
        history.append(cmd)
        history = history[-TCL_HISTORY_MAX_ENTRIES:]
        tmp_path = TCL_HISTORY_PATH + ".tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(history, f)
        os.replace(tmp_path, TCL_HISTORY_PATH)
        return history


def _require_open_target():
    """Return an error response tuple if no hw_target is open, else None."""
    if not _load_config().get("last_target"):
        return jsonify({"success": False, "error": "open a target first"}), 400
    return None

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

def _filter_tcl_lines(output):
    """Return useful Tcl stdout lines, skipping Vivado INFO/WARNING banners."""
    return [
        ln.strip() for ln in output.splitlines()
        if ln.strip()
        and not ln.startswith("INFO:")
        and not ln.startswith("WARNING:")
    ]


def _looks_like_hw_target(name):
    """True for real hw_target paths, not error-message tokens."""
    if not name or " " in name:
        return False
    if "/" not in name:
        return False
    low = name.lower()
    return "xilinx_tcf" in low or ":312" in name or name.count("/") >= 2


def _parse_hw_servers(output):
    """Extract hw_server URLs from get_hw_servers output."""
    servers = []
    for line in _filter_tcl_lines(output):
        if " " in line:
            continue
        if line.startswith("Resolution:"):
            continue
        if ":" in line:
            servers.append(line)
    return servers


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
    targets = [t for t in targets if _looks_like_hw_target(t)]
    if targets:
        return targets
    # Fallback: bare `get_hw_targets` prints space-separated paths on one line.
    for line in _filter_tcl_lines(output):
        if "|" in line:
            continue
        parts = [p for p in line.split() if _looks_like_hw_target(p)]
        if parts:
            return parts
    return []


def _tcl_open_target(target):
    return (
        f"catch {{ close_hw_target }} ; "
        f"current_hw_target [get_hw_targets {{{target}}}] ; "
        "open_hw_target"
    )


_LIST_DEVICES_TCL = (
    'foreach __d [get_hw_devices] { puts "DEVICEROW|$__d|" }'
)


def _parse_devices(output):
    """Parse DEVICEROW lines; fall back to bare get_hw_devices output."""
    devices = []
    for row in _parse_rows(output, "DEVICEROW", 3):
        name = row[0].strip()
        if name:
            part = row[1].strip() if len(row) > 1 else ""
            devices.append({"name": name, "part": part})
    if devices:
        return devices
    for line in output.splitlines():
        line = line.strip()
        if not line or line.startswith(("INFO:", "WARNING:", "ERROR:")):
            continue
        if "|" in line:
            continue
        for name in line.split():
            devices.append({"name": name, "part": ""})
    return devices


def _enrich_device_parts(devices):
    """Fetch PART separately — nested get_property inside puts breaks output capture."""
    enriched = []
    for d in devices:
        part_result = _run(f'get_property PART [get_hw_devices {{{d["name"]}}}]')
        part = ""
        if part_result.success and part_result.output.strip():
            part = part_result.output.strip().splitlines()[-1].strip()
        enriched.append({"name": d["name"], "part": part})
    return enriched


def _list_devices():
    result = _run(_LIST_DEVICES_TCL)
    devices = _parse_devices(result.output)
    if devices and not any(d.get("part") for d in devices):
        devices = _enrich_device_parts(devices)
    return devices, result


def _open_hw_target(target):
    open_result = _run(_tcl_open_target(target))
    devices, list_result = _list_devices()
    return open_result, devices, list_result


def _tcl_select_device(device):
    return f'current_hw_device [get_hw_devices {{{device}}}]'


def _tcl_apply_ltx(device, ltx_path):
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        f'set_property PROBES.FILE {{{ltx_path}}} $__dev ; '
        'refresh_hw_device -update_hw_probes true $__dev ; '
        'puts "LTXROW|$__dev|[get_property PROBES.FILE $__dev]"'
    )


def _tcl_program_bit(device, bit_path):
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        f'set_property PROGRAM.FILE {{{bit_path}}} $__dev ; '
        'program_hw_devices $__dev ; '
        f'puts "PROGROW|bit|ok|$__dev|{bit_path}"'
    )


def _tcl_program_bin(device, bin_path):
    return (
        f'set __dev [get_hw_devices {{{device}}}] ; '
        'current_hw_device $__dev ; '
        'set __part [get_property PART $__dev] ; '
        'set __cp [lindex [get_cfgmem_parts $__part] 0] ; '
        'if {$__cp eq ""} { puts "PROGROW|bin|error|no_cfgmem_part|" } '
        'else { '
        'set __cm [get_property PROGRAM.HW_CFGMEM $__dev] ; '
        'if {$__cm eq ""} { set __cm [create_hw_cfgmem -hw_device $__dev $__cp] } ; '
        f'set_property PROGRAM.FILES {{{bin_path}}} $__cm ; '
        'set_property PROGRAM.BLANK_CHECK 0 $__cm ; '
        'set_property PROGRAM.ERASE 1 $__cm ; '
        'set_property PROGRAM.CFG_PROGRAM 1 $__cm ; '
        'set_property PROGRAM.VERIFY 1 $__cm ; '
        'set_property PROGRAM.CHECKSUM 0 $__cm ; '
        'program_hw_cfgmem -hw_cfgmem $__cm ; '
        f'puts "PROGROW|bin|ok|$__dev|{bin_path}" '
        '}'
    )


def _tcl_list_vio_tree(device=None):
    dev_filter = (
        f'set __devs [list [get_hw_devices {{{device}}}]] ; '
        if device else
        'set __devs [get_hw_devices] ; '
    )
    return (
        dev_filter +
        'foreach __dev $__devs { '
        'current_hw_device $__dev ; '
        'set __vios [get_hw_vios -of_objects $__dev] ; '
        'foreach __vio $__vios { '
        'puts "VIONODE|$__dev|[get_property NAME $__vio]" '
        '} }'
    )


def _vivado_tree_label():
    for v in VIVADO_VERSIONS:
        if v["path"] == VIVADO_PATH:
            return f"Vivado {v['version']}"
    return "Vivado"


def _build_hw_tree(vivado_label, server_url, targets, devices, vio_nodes, open_target=None):
    """Build hierarchical tree: Vivado -> server -> targets -> devices -> plugin nodes."""
    if open_target is None:
        open_target = _load_config().get("last_target")

    server_node = {
        "type": "server",
        "name": server_url or "(not connected)",
        "full": server_url or "",
        "children": [],
    }
    for target in targets:
        short = target.split("/")[-1] if "/" in target else target
        is_open = target == open_target
        tnode = {
            "type": "target",
            "name": short,
            "full": target,
            "open": is_open,
            "children": [],
        }
        target_devices = devices if is_open else []
        for d in target_devices:
            short_d = d["name"].split("/")[-1] if "/" in d["name"] else d["name"]
            dnode = {
                "type": "device",
                "name": short_d,
                "full": d["name"],
                "part": d.get("part", ""),
                "children": [],
            }
            for hook in plugin_registry.tree_hooks():
                hook(dnode, d["name"], vio_nodes)
            tnode["children"].append(dnode)
        server_node["children"].append(tnode)

    return {
        "type": "vivado",
        "name": vivado_label,
        "full": VIVADO_PATH,
        "children": [server_node],
    }


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
        devices, devices_result = _list_devices()

    server_lines = _parse_hw_servers(servers_result.output)
    connected = servers_result.success and bool(server_lines)
    server_url = server_lines[0] if server_lines else cfg.get("last_connected")
    targets = _parse_targets(targets_result.output)

    return jsonify({
        "vivado_running": True,
        "connected": connected,
        "server_url": server_url,
        "targets": targets,
        "devices": devices,
        "target_open": bool(cfg.get("last_target") and cfg.get("last_target") in targets),
        "saved_hw_servers": cfg.get("hw_servers", []),
        "last_target": cfg.get("last_target"),
        "last_device": cfg.get("last_device"),
        "last_ltx": cfg.get("last_ltx"),
    })


@app.route("/api/targets/open", methods=["POST"])
def api_target_open():
    data = request.get_json(silent=True) or {}
    target = (data.get("target") or "").strip()
    if not target:
        return jsonify({"success": False, "error": "target required"}), 400
    with _lock:
        open_result, devices, list_result = _open_hw_target(target)
    if open_result.success:
        _set_last_target(target)
        if devices:
            _set_last_device(devices[0]["name"])
    return jsonify({
        "success": open_result.success,
        "target": target,
        "devices": devices,
        "output": open_result.output + "\n" + list_result.output,
    })


# =============================================================================
# hw_devices
# =============================================================================

@app.route("/api/devices", methods=["GET"])
def api_devices_list():
    with _lock:
        devices, result = _list_devices()
    return jsonify({"success": result.success, "devices": devices, "output": result.output})


@app.route("/api/devices/<path:device>/select", methods=["POST"])
def api_device_select(device):
    blocked = _require_open_target()
    if blocked:
        return blocked
    with _lock:
        result = _run(_tcl_select_device(device))
    if result.success:
        _set_last_device(device)
    return jsonify({"success": result.success, "device": device, "output": result.output})


# =============================================================================
# Plugins
# =============================================================================

@app.route("/api/plugins")
def api_plugins_list():
    cfg = _load_config()
    return jsonify({
        "plugins": [
            plugin_registry.public_manifest(m, cfg)
            for m in plugin_registry.discover_plugins()
        ],
    })


@app.route("/api/plugins/config", methods=["POST"])
def api_plugins_config():
    data = request.get_json(silent=True) or {}
    incoming = data.get("plugins") or {}
    with _config_lock:
        cfg = _load_config()
        plugins_cfg = cfg.setdefault("plugins", {})
        for plugin_id, entry in incoming.items():
            if not plugin_registry.plugin_manifest(plugin_id):
                continue
            plugins_cfg.setdefault(plugin_id, {})
            if "enabled" in entry:
                plugins_cfg[plugin_id]["enabled"] = bool(entry["enabled"])
        _save_config(cfg)
    return jsonify({"success": True, "plugins": cfg.get("plugins", {})})


@app.route("/plugins/<plugin_id>/assets/<path:filename>")
def plugin_assets(plugin_id, filename):
    if ".." in filename or filename.startswith("/"):
        return jsonify({"error": "invalid path"}), 400
    path = plugin_registry.plugin_asset_path(plugin_id, filename)
    if not path:
        return jsonify({"error": "not found"}), 404
    return send_file(path)


STATIC_DIR = os.path.join(_APP_DIR, "static")


@app.route("/static/<path:filename>")
def static_files(filename):
    if ".." in filename:
        return jsonify({"error": "invalid path"}), 400
    path = os.path.join(STATIC_DIR, filename)
    if not os.path.isfile(path):
        return jsonify({"error": "not found"}), 404
    return send_file(path)


# =============================================================================
# Tree / LTX / programming
# =============================================================================

@app.route("/api/tree")
def api_tree():
    cfg = _load_config()
    vivado_label = _vivado_tree_label()
    server_hint = cfg.get("last_connected", "") or "(not connected)"

    def _tree_response(**extra):
        base = {
            "success": True,
            "connected": False,
            "targets": [],
            "devices": [],
            "tree": _build_hw_tree(
                vivado_label, server_hint, [], [], [], open_target=None,
            ),
            "last_target": cfg.get("last_target"),
            "last_device": cfg.get("last_device"),
            "last_ltx": cfg.get("last_ltx"),
            "vivado_path": VIVADO_PATH,
            "vivado_label": vivado_label,
            "server_url": "",
        }
        base.update(extra)
        return jsonify(base)

    if not session.is_running:
        return _tree_response()

    try:
        with _lock:
            servers_result = _run("get_hw_servers")
            if not servers_result.success:
                return _tree_response(error=servers_result.output.strip() or "hw_server not connected")

            server_lines = _parse_hw_servers(servers_result.output)
            if not server_lines:
                return _tree_response(
                    error="hw_server not connected",
                )

            server_url = server_lines[0]
            targets_result = _run(_tcl_list_targets())
            targets = _parse_targets(targets_result.output) if targets_result.success else []
            if not targets_result.success:
                return jsonify({
                    "success": True,
                    "connected": True,
                    "server_url": server_url,
                    "targets": [],
                    "devices": [],
                    "target_open": False,
                    "tree": _build_hw_tree(
                        vivado_label, server_url, [], [], [], open_target=None,
                    ),
                    "last_target": cfg.get("last_target"),
                    "last_device": cfg.get("last_device"),
                    "last_ltx": cfg.get("last_ltx"),
                    "vivado_path": VIVADO_PATH,
                    "vivado_label": vivado_label,
                    "error": targets_result.output.strip() or "failed to list targets",
                })

            open_target = cfg.get("last_target")
            target_open = bool(open_target and open_target in targets)
            devices = []
            vio_nodes = []
            if target_open:
                devices, _devices_result = _list_devices()
                vio_tree_result = _run(_tcl_list_vio_tree())
                if vio_tree_result.success:
                    vio_nodes = _parse_rows(vio_tree_result.output, "VIONODE", 3)

            tree = _build_hw_tree(
                vivado_label, server_url, targets, devices, vio_nodes,
                open_target=open_target if target_open else None,
            )
            return jsonify({
                "success": True,
                "connected": True,
                "server_url": server_url,
                "targets": targets,
                "devices": devices,
                "target_open": target_open,
                "tree": tree,
                "last_target": cfg.get("last_target"),
                "last_device": cfg.get("last_device"),
                "last_ltx": cfg.get("last_ltx"),
                "vivado_path": VIVADO_PATH,
                "vivado_label": vivado_label,
            })
    except Exception as exc:
        return _tree_response(error=str(exc))


@app.route("/api/ltx", methods=["GET"])
def api_ltx_list():
    cfg = _load_config()
    candidates = _find_ltx_candidates()
    saved = [_abs_ltx_path(p) for p in cfg.get("ltx_files", []) if p]
    saved = [p for p in saved if os.path.isfile(p)]
    last = _abs_ltx_path(cfg.get("last_ltx", "")) if cfg.get("last_ltx") else ""
    return jsonify({
        "candidates": candidates,
        "saved": saved,
        "last_ltx": last if last and os.path.isfile(last) else "",
    })


@app.route("/api/ltx", methods=["POST"])
def api_ltx_apply():
    data = request.get_json(silent=True) or {}
    ltx_path = _abs_ltx_path((data.get("path") or "").strip())
    device = (data.get("device") or _load_config().get("last_device") or "").strip()
    if not ltx_path:
        return jsonify({"success": False, "error": "path required"}), 400
    blocked = _require_open_target()
    if blocked:
        return blocked
    if not os.path.isfile(ltx_path):
        return jsonify({"success": False, "error": f"file not found: {ltx_path}"}), 400
    if not device:
        return jsonify({"success": False, "error": "no device selected"}), 400

    with _lock:
        result = _run(_tcl_apply_ltx(device, ltx_path), timeout_override=120)

    rows = _parse_rows(result.output, "LTXROW", 3)
    applied = rows[0][1] if rows else ltx_path
    if result.success:
        _set_ltx_path(ltx_path)

    return jsonify({
        "success": result.success,
        "path": ltx_path,
        "applied": applied,
        "device": device,
        "output": result.output,
    })


@app.route("/api/file_last", methods=["POST"])
def api_file_last():
    """Remember the most recently selected file path (without programming/loading)."""
    data = request.get_json(silent=True) or {}
    kind = (data.get("type") or "").strip().lower()
    path = _abs_hw_file_path((data.get("path") or "").strip())
    if not path:
        return jsonify({"success": False, "error": "path required"}), 400
    if kind == "ltx":
        _set_ltx_path(path)
    elif kind in ("bit", "bin"):
        _set_program_path(path, kind)
    else:
        return jsonify({"success": False, "error": "type must be ltx, bit, or bin"}), 400
    return jsonify({"success": True, "path": path, "type": kind})


@app.route("/api/upload", methods=["POST"])
def api_upload():
    """Upload .ltx / .bit / .bin into bin/uploads/<timestamp>/."""
    kind = (request.form.get("type") or "").strip().lower()
    if kind not in ("ltx", "bit", "bin"):
        return jsonify({"success": False, "error": "type must be ltx, bit, or bin"}), 400
    upload = request.files.get("file")
    if upload is None or not upload.filename:
        return jsonify({"success": False, "error": "file required"}), 400
    orig_name = os.path.basename(upload.filename)
    if not orig_name.lower().endswith(f".{kind}"):
        return jsonify({"success": False, "error": f"expected .{kind} file"}), 400

    safe_name = secure_filename(orig_name)
    if not safe_name.lower().endswith(f".{kind}"):
        safe_name = f"{safe_name}.{kind}" if safe_name else f"upload.{kind}"

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest_dir = os.path.join(_uploads_root(), ts)
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.abspath(os.path.join(dest_dir, safe_name))
    upload.save(dest_path)

    if kind == "ltx":
        _set_ltx_path(dest_path)
    else:
        _set_program_path(dest_path, kind)

    return jsonify({
        "success": True,
        "path": dest_path,
        "type": kind,
        "folder": dest_dir,
    })


@app.route("/api/program_files")
def api_program_files_list():
    ext = (request.args.get("ext") or "bit").strip().lower()
    if ext not in ("bit", "bin"):
        return jsonify({"error": "ext must be bit or bin"}), 400
    return jsonify(_program_files_payload(ext))


def _program_files_payload(ext):
    cfg = _load_config()
    candidates = _find_program_candidates(ext)
    saved = [_abs_hw_file_path(p) for p in cfg.get(f"{ext}_files", []) if p]
    saved = [p for p in saved if os.path.isfile(p)]
    last_raw = cfg.get(f"last_{ext}", "")
    last = _abs_hw_file_path(last_raw) if last_raw else ""
    return {
        "ext": ext,
        "candidates": candidates,
        "saved": saved,
        f"last_{ext}": last if last and os.path.isfile(last) else "",
    }


@app.route("/api/bit")
def api_bit_list():
    payload = _program_files_payload("bit")
    return jsonify({
        "candidates": payload["candidates"],
        "saved": payload["saved"],
        "last_bit": payload["last_bit"],
    })


@app.route("/api/bin")
def api_bin_list():
    payload = _program_files_payload("bin")
    return jsonify({
        "candidates": payload["candidates"],
        "saved": payload["saved"],
        "last_bin": payload["last_bin"],
    })


@app.route("/api/program", methods=["POST"])
def api_program():
    data = request.get_json(silent=True) or {}
    kind = (data.get("type") or "").strip().lower()
    file_path = _abs_hw_file_path((data.get("path") or "").strip())
    device = (data.get("device") or _load_config().get("last_device") or "").strip()
    if kind not in ("bit", "bin"):
        return jsonify({"success": False, "error": "type must be bit or bin"}), 400
    if not file_path:
        return jsonify({"success": False, "error": "path required"}), 400
    blocked = _require_open_target()
    if blocked:
        return blocked
    if not os.path.isfile(file_path):
        return jsonify({"success": False, "error": f"file not found: {file_path}"}), 400
    if not device:
        return jsonify({"success": False, "error": "no device selected"}), 400
    if not file_path.lower().endswith(f".{kind}"):
        return jsonify({"success": False, "error": f"expected .{kind} file"}), 400

    timeout = 300 if kind == "bit" else 900
    tcl = _tcl_program_bit(device, file_path) if kind == "bit" else _tcl_program_bin(device, file_path)
    with _lock:
        result = _run(tcl, timeout_override=timeout)

    rows = _parse_rows(result.output, "PROGROW", 5)
    status = rows[0][1] if rows else ""
    detail = rows[0][2] if rows else ""
    ok = result.success and status == "ok"
    if ok:
        _set_program_path(file_path, kind)

    return jsonify({
        "success": ok,
        "type": kind,
        "path": file_path,
        "device": device,
        "detail": detail,
        "output": result.output,
    })


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


@app.route("/api/tcl/history", methods=["GET"])
def api_tcl_history():
    return jsonify({"history": _load_tcl_history()})


@app.route("/api/tcl", methods=["POST"])
def api_tcl():
    data = request.get_json(silent=True) or {}
    cmd = (data.get("cmd") or "").strip()
    if not cmd:
        return jsonify({"success": False, "error": "cmd required"}), 400
    if len(cmd) > TCL_HISTORY_MAX_LINE_LEN:
        return jsonify({
            "success": False,
            "error": f"command too long (max {TCL_HISTORY_MAX_LINE_LEN} chars)",
        }), 400
    with _lock:
        result = _run(cmd)
    history = _append_tcl_history(cmd)
    return jsonify({
        "success": result.success,
        "output": result.output,
        "history": history,
    })


# =============================================================================
# Web UI
# =============================================================================

UI_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui.html")


def _load_ui_template():
    with open(UI_PATH, encoding="utf-8") as f:
        return f.read()


@app.route("/")
def index():
    cfg = _load_config()
    return render_template_string(
        _load_ui_template(),
        default_url=cfg.get("last_connected") or DEFAULT_HW_SERVER_URL,
        initial_config=json.dumps(cfg),
    )


def _plugin_context():
    return {
        "run": _run,
        "lock": _lock,
        "parse_rows": _parse_rows,
        "require_open_target": _require_open_target,
        "load_config": _load_config,
    }


plugin_registry.init_plugins(app, _plugin_context(), _load_config())


if __name__ == "__main__":
    print(f"Using vivado executable: {VIVADO_PATH}")
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5050)), debug=False)
