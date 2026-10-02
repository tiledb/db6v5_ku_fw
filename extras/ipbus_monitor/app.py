#!/usr/bin/env python3
"""IPBus monitor.

Same plugin shell as the VIO monitor, but the transport is ControlHub /
uHAL (``extras/ipbus_monitor/lib``) instead of a Vivado JTAG chain. One
connection reaches both daughterboard FPGAs.

Run it with the project virtualenv (this file switches to it automatically):

    extras/.pyenv312/bin/python extras/ipbus_monitor/app.py

The page is http://0.0.0.0:5051
"""

from __future__ import annotations

import json
import os
import sys

_APP_DIR = os.path.dirname(os.path.abspath(__file__))
_VENV_PY = os.path.abspath(os.path.join(_APP_DIR, "..", ".pyenv312", "bin", "python"))
if os.path.isfile(_VENV_PY) and os.path.realpath(sys.executable) != os.path.realpath(_VENV_PY):
    os.execv(_VENV_PY, [_VENV_PY, *sys.argv])

if _APP_DIR not in sys.path:
    sys.path.insert(0, _APP_DIR)

from flask import Flask, jsonify, render_template_string, request, send_file

from plugins import registry as plugin_registry
from plugins.common.session import SESSION, SIDES

CONFIG_PATH = os.environ.get(
    "IPBUS_MONITOR_CONFIG",
    os.path.join(_APP_DIR, "ipbus_connections.json"),
)
UI_PATH = os.path.join(_APP_DIR, "ui.html")

app = Flask(__name__)


def _default_config() -> dict:
    return {
        "controlhub": "localhost",
        "ppr": "192.168.0.1",
        "md": 0,
        "plugins": {},
    }


def load_config() -> dict:
    cfg = _default_config()
    if os.path.isfile(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, encoding="utf-8") as handle:
                stored = json.load(handle)
            if isinstance(stored, dict):
                cfg.update(stored)
        except (OSError, json.JSONDecodeError):
            pass
    return plugin_registry.ensure_plugins_config(cfg)


def save_config(cfg: dict) -> None:
    with open(CONFIG_PATH, "w", encoding="utf-8") as handle:
        json.dump(cfg, handle, indent=2)
        handle.write("\n")


def require_connected():
    if SESSION.connected:
        return None
    return jsonify({"success": False, "error": "Not connected"}), 400


def _parse_int(text: str) -> int:
    return int(str(text).strip(), 0)


def _run_console(line: str) -> str:
    parts = line.split()
    if not parts:
        return ""
    cmd = parts[0].lower()
    if cmd == "read" and len(parts) >= 2:
        count = _parse_int(parts[2]) if len(parts) > 2 else 1
        value = SESSION.ppr_read(_parse_int(parts[1]), count)
        if isinstance(value, list):
            return " ".join(f"0x{item:08X}" for item in value)
        return f"0x{value:08X}"
    if cmd == "write" and len(parts) >= 3:
        SESSION.ppr_write(_parse_int(parts[1]), _parse_int(parts[2]))
        return "ok"
    if cmd == "dbread" and len(parts) >= 2:
        sides = SESSION.read_both(_parse_int(parts[1]))
        return " ".join(f"{side}=0x{sides[side]:08X}" for side in ("A", "B"))
    if cmd == "dbwrite" and len(parts) >= 4:
        SESSION.write_side(parts[1].upper(), _parse_int(parts[2]), _parse_int(parts[3]))
        return "ok"
    raise ValueError("commands: read ADDR [N] | write ADDR VALUE | dbread REG | dbwrite A|B REG VALUE")


def _tree(cfg: dict) -> dict | None:
    if not SESSION.connected:
        return None
    md_node = {
        "type": "md",
        "name": f"MD {SESSION.md}",
        "full": str(SESSION.md),
        "children": [
            {"type": "side", "name": side["label"], "full": side["id"], "children": []}
            for side in SIDES
        ],
    }
    for hook in plugin_registry.tree_hooks(cfg):
        hook(md_node)
    return {
        "type": "ppr",
        "name": SESSION.ppr_ip,
        "full": f"{SESSION.controlhub} → {SESSION.ppr_ip}",
        "children": [md_node],
    }


@app.route("/api/status")
def api_status():
    cfg = load_config()
    return jsonify({
        "connected": SESSION.connected,
        "controlhub": SESSION.controlhub or cfg.get("controlhub"),
        "ppr": SESSION.ppr_ip or cfg.get("ppr"),
        "md": SESSION.md if SESSION.connected else cfg.get("md", 0),
        "python": sys.executable,
    })


@app.route("/api/connect", methods=["POST"])
def api_connect():
    body = request.get_json(silent=True) or {}
    controlhub = str(body.get("controlhub") or "localhost").strip()
    ppr = str(body.get("ppr") or "192.168.0.1").strip()
    try:
        md = int(body.get("md", 0))
    except (TypeError, ValueError):
        return jsonify({"success": False, "error": "md must be 0..3"}), 400
    try:
        with SESSION.lock:
            SESSION.connect(controlhub, ppr, md)
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 500
    cfg = load_config()
    cfg["controlhub"] = controlhub
    cfg["ppr"] = ppr
    cfg["md"] = md
    save_config(cfg)
    return jsonify({"success": True, "controlhub": controlhub, "ppr": ppr, "md": md})


@app.route("/api/disconnect", methods=["POST"])
def api_disconnect():
    with SESSION.lock:
        SESSION.disconnect()
    return jsonify({"success": True})


@app.route("/api/md", methods=["POST"])
def api_md():
    blocked = require_connected()
    if blocked:
        return blocked
    body = request.get_json(silent=True) or {}
    try:
        with SESSION.lock:
            SESSION.set_md(int(body.get("md", 0)))
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400
    cfg = load_config()
    cfg["md"] = SESSION.md
    save_config(cfg)
    return jsonify({"success": True, "md": SESSION.md})


@app.route("/api/tree")
def api_tree():
    return jsonify({
        "connected": SESSION.connected,
        "tree": _tree(load_config()),
    })


@app.route("/api/plugins")
def api_plugins():
    cfg = load_config()
    plugins = [
        plugin_registry.public_manifest(manifest, cfg)
        for manifest in plugin_registry.sorted_plugin_manifests(cfg)
    ]
    return jsonify({"plugins": plugins})


@app.route("/api/plugins/config", methods=["POST"])
def api_plugins_config():
    body = request.get_json(silent=True) or {}
    cfg = load_config()
    plugins_cfg = cfg.setdefault("plugins", {})
    for item in body.get("plugins") or []:
        plugin_id = str(item.get("id") or "")
        if not plugin_registry.plugin_manifest(plugin_id):
            continue
        entry = plugins_cfg.setdefault(plugin_id, {})
        if "enabled" in item:
            entry["enabled"] = bool(item["enabled"])
        if "order" in item:
            entry["order"] = int(item["order"])
    save_config(cfg)
    return jsonify({"success": True})


@app.route("/api/console")
def api_console():
    return jsonify({"lines": list(SESSION.log)})


@app.route("/api/console", methods=["POST"])
def api_console_run():
    blocked = require_connected()
    if blocked:
        return blocked
    line = str((request.get_json(silent=True) or {}).get("command") or "").strip()
    if not line:
        return jsonify({"success": False, "error": "empty command"}), 400
    try:
        with SESSION.lock:
            output = _run_console(line)
    except Exception as exc:
        SESSION._note(f"> {line}", error=True)
        SESSION._note(str(exc), error=True)
        return jsonify({"success": False, "error": str(exc), "lines": list(SESSION.log)}), 400
    SESSION._note(f"> {line}")
    if output:
        SESSION._note(output)
    return jsonify({"success": True, "output": output, "lines": list(SESSION.log)})


@app.route("/plugins/<plugin_id>/assets/<path:filename>")
def plugin_asset(plugin_id, filename):
    path = plugin_registry.plugin_asset_path(plugin_id, filename)
    if not path:
        return jsonify({"success": False, "error": "not found"}), 404
    return send_file(path)


@app.route("/static/<path:filename>")
def static_file(filename):
    path = os.path.join(_APP_DIR, "static", filename)
    root = os.path.abspath(os.path.join(_APP_DIR, "static"))
    if not os.path.isfile(path) or not os.path.abspath(path).startswith(root + os.sep):
        return jsonify({"success": False, "error": "not found"}), 404
    return send_file(path)


@app.route("/")
def index():
    cfg = load_config()
    with open(UI_PATH, encoding="utf-8") as handle:
        template = handle.read()
    return render_template_string(template, initial_config=json.dumps(cfg))


plugin_registry.init_plugins(app, {
    "session": SESSION,
    "require_connected": require_connected,
    "load_config": load_config,
}, load_config())


if __name__ == "__main__":
    print(f"Python: {sys.executable}")
    print("IPBus monitor on http://0.0.0.0:5051")
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5051")), debug=False, threaded=True)
