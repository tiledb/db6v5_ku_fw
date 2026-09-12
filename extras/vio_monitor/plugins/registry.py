"""Discover, configure, and register HW Monitor plugins."""
from __future__ import annotations

import importlib.util
import json
import os
from typing import Any, Callable

from plugins.common.probe_config import probe_config_fields, sanitize_probe_updates

PLUGINS_ROOT = os.path.dirname(os.path.abspath(__file__))
MANIFEST_NAME = "manifest.json"
_tree_hooks: dict[str, Callable[..., None]] = {}
_registered_ids: set[str] = set()


def register_tree_hook(plugin_id: str, fn: Callable[..., None]) -> None:
    _tree_hooks[plugin_id] = fn


def tree_hooks(cfg: dict[str, Any] | None = None) -> list[Callable[..., None]]:
    """Return tree hooks in plugin tab order (config order, then name)."""
    if not cfg:
        return list(_tree_hooks.values())
    ranked = sorted(
        _tree_hooks.items(),
        key=lambda item: (
            plugin_config_order(cfg, plugin_manifest(item[0]) or {"id": item[0], "order": 100}),
            (plugin_manifest(item[0]) or {}).get("name", item[0]),
        ),
    )
    return [fn for _, fn in ranked]


def discover_plugins() -> list[dict[str, Any]]:
    """Return manifest dicts for every plugin folder under plugins/."""
    plugins: list[dict[str, Any]] = []
    for name in sorted(os.listdir(PLUGINS_ROOT)):
        plugin_dir = os.path.join(PLUGINS_ROOT, name)
        manifest_path = os.path.join(plugin_dir, MANIFEST_NAME)
        if not os.path.isdir(plugin_dir) or not os.path.isfile(manifest_path):
            continue
        try:
            with open(manifest_path, encoding="utf-8") as f:
                manifest = json.load(f)
        except (OSError, json.JSONDecodeError):
            continue
        manifest.setdefault("id", name)
        manifest["directory"] = plugin_dir
        plugins.append(manifest)
    return plugins


def plugin_config_order(cfg: dict[str, Any], manifest: dict[str, Any]) -> int:
    """Effective tab order: saved config overrides manifest default."""
    pid = manifest["id"]
    entry = cfg.get("plugins", {}).get(pid, {})
    if "order" in entry:
        return int(entry["order"])
    return int(manifest.get("order", 100))


def sorted_plugin_manifests(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    """All discovered plugins sorted by configured order."""
    plugins = discover_plugins()
    return sorted(
        plugins,
        key=lambda m: (plugin_config_order(cfg, m), m.get("name", m["id"])),
    )


def ensure_plugins_config(cfg: dict[str, Any]) -> dict[str, Any]:
    """Merge discovered plugins into cfg['plugins'] with defaults."""
    plugins_cfg = cfg.setdefault("plugins", {})
    for manifest in discover_plugins():
        pid = manifest["id"]
        entry = plugins_cfg.setdefault(pid, {})
        if "enabled" not in entry:
            entry["enabled"] = manifest.get("default_enabled", True)
        if "order" not in entry:
            entry["order"] = manifest.get("order", 100)
        if "auto_read_on_ready" not in entry:
            entry["auto_read_on_ready"] = bool(manifest.get("default_auto_read_on_ready", False))
    return cfg


def is_plugin_enabled(cfg: dict[str, Any], plugin_id: str) -> bool:
    plugins_cfg = cfg.get("plugins", {})
    entry = plugins_cfg.get(plugin_id, {})
    if "enabled" in entry:
        return bool(entry["enabled"])
    for manifest in discover_plugins():
        if manifest["id"] == plugin_id:
            return bool(manifest.get("default_enabled", True))
    return False


def enabled_plugins(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    return [p for p in sorted_plugin_manifests(cfg) if is_plugin_enabled(cfg, p["id"])]


def plugin_manifest(plugin_id: str) -> dict[str, Any] | None:
    for manifest in discover_plugins():
        if manifest["id"] == plugin_id:
            return manifest
    return None


def plugin_asset_path(plugin_id: str, filename: str) -> str | None:
    manifest = plugin_manifest(plugin_id)
    if not manifest:
        return None
    path = os.path.join(manifest["directory"], filename)
    if not os.path.isfile(path):
        return None
    root = os.path.abspath(manifest["directory"])
    if not os.path.abspath(path).startswith(root + os.sep):
        return None
    return path


def public_manifest(manifest: dict[str, Any], cfg: dict[str, Any]) -> dict[str, Any]:
    assets = manifest.get("assets", {})
    probe_fields = probe_config_fields(manifest, cfg)
    if "requires_ltx" in manifest:
        requires_ltx = bool(manifest["requires_ltx"])
    else:
        requires_ltx = bool(probe_fields)
    pub = {
        "id": manifest["id"],
        "name": manifest.get("name", manifest["id"]),
        "description": manifest.get("description", ""),
        "version": manifest.get("version", "1.0.0"),
        "order": plugin_config_order(cfg, manifest),
        "enabled": is_plugin_enabled(cfg, manifest["id"]),
        "requires_target": manifest.get("requires_target", True),
        "requires_device": manifest.get("requires_device", False),
        "requires_ltx": requires_ltx,
        "requires_readiness": bool(
            requires_ltx
            or manifest.get("requires_target", False)
        ),
        "auto_read_on_ready": bool(
            (cfg.get("plugins") or {}).get(manifest["id"], {}).get(
                "auto_read_on_ready",
                manifest.get("default_auto_read_on_ready", False),
            )
        ),
        "tree_node_types": manifest.get("tree_node_types", []),
        "assets": {
            "panel": assets.get("panel", "panel.html"),
            "script": assets.get("script", "plugin.js"),
            "styles": assets.get("styles", []),
            "external_scripts": assets.get("external_scripts", []),
        },
    }
    if probe_fields:
        pub["probe_config"] = probe_fields
    return pub


def load_plugin_backend(manifest: dict[str, Any]):
    backend_path = os.path.join(manifest["directory"], "backend.py")
    if not os.path.isfile(backend_path):
        return None
    module_name = f"hw_monitor_plugin_{manifest['id']}"
    spec = importlib.util.spec_from_file_location(module_name, backend_path)
    if spec is None or spec.loader is None:
        return None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def init_plugins(app, ctx: dict[str, Any], cfg: dict[str, Any] | None = None) -> None:
    """Register Flask blueprints and tree hooks for enabled plugins only."""
    cfg = ensure_plugins_config(cfg or {"plugins": {}})
    for manifest in discover_plugins():
        pid = manifest["id"]
        if pid in _registered_ids:
            continue
        if not is_plugin_enabled(cfg, pid):
            continue
        module = load_plugin_backend(manifest)
        if module is None:
            continue
        register = getattr(module, "register", None)
        if callable(register):
            register(app, ctx, manifest)
            _registered_ids.add(pid)


def ensure_plugins(app, ctx: dict[str, Any], cfg: dict[str, Any] | None = None) -> None:
    """Register newly enabled plugins (no-op for already registered ones)."""
    init_plugins(app, ctx, cfg)
