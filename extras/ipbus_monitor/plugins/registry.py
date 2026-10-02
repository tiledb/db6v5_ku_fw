"""Discover and register IPBus monitor plugins."""

from __future__ import annotations

import importlib.util
import json
import os
from typing import Any, Callable

PLUGINS_ROOT = os.path.dirname(os.path.abspath(__file__))
MANIFEST_NAME = "manifest.json"
_tree_hooks: dict[str, Callable[..., None]] = {}
_registered_ids: set[str] = set()


def register_tree_hook(plugin_id: str, fn: Callable[..., None]) -> None:
    _tree_hooks[plugin_id] = fn


def discover_plugins() -> list[dict[str, Any]]:
    plugins: list[dict[str, Any]] = []
    for name in sorted(os.listdir(PLUGINS_ROOT)):
        plugin_dir = os.path.join(PLUGINS_ROOT, name)
        manifest_path = os.path.join(plugin_dir, MANIFEST_NAME)
        if not os.path.isdir(plugin_dir) or not os.path.isfile(manifest_path):
            continue
        try:
            with open(manifest_path, encoding="utf-8") as handle:
                manifest = json.load(handle)
        except (OSError, json.JSONDecodeError):
            continue
        manifest.setdefault("id", name)
        manifest["directory"] = plugin_dir
        plugins.append(manifest)
    return plugins


def plugin_config_order(cfg: dict[str, Any], manifest: dict[str, Any]) -> int:
    entry = (cfg.get("plugins") or {}).get(manifest["id"], {})
    if "order" in entry:
        return int(entry["order"])
    return int(manifest.get("order", 100))


def sorted_plugin_manifests(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    return sorted(
        discover_plugins(),
        key=lambda manifest: (plugin_config_order(cfg, manifest), manifest.get("name", manifest["id"])),
    )


def ensure_plugins_config(cfg: dict[str, Any]) -> dict[str, Any]:
    plugins_cfg = cfg.setdefault("plugins", {})
    for manifest in discover_plugins():
        entry = plugins_cfg.setdefault(manifest["id"], {})
        entry.setdefault("enabled", manifest.get("default_enabled", True))
        entry.setdefault("order", manifest.get("order", 100))
    return cfg


def is_plugin_enabled(cfg: dict[str, Any], plugin_id: str) -> bool:
    entry = (cfg.get("plugins") or {}).get(plugin_id, {})
    if "enabled" in entry:
        return bool(entry["enabled"])
    for manifest in discover_plugins():
        if manifest["id"] == plugin_id:
            return bool(manifest.get("default_enabled", True))
    return False


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
    return {
        "id": manifest["id"],
        "name": manifest.get("name", manifest["id"]),
        "description": manifest.get("description", ""),
        "version": manifest.get("version", "1.0.0"),
        "order": plugin_config_order(cfg, manifest),
        "enabled": is_plugin_enabled(cfg, manifest["id"]),
        "tree_node_types": manifest.get("tree_node_types", []),
        "assets": {
            "panel": assets.get("panel", "panel.html"),
            "script": assets.get("script", "plugin.js"),
            "styles": assets.get("styles", []),
            "external_scripts": assets.get("external_scripts", []),
        },
    }


def load_plugin_backend(manifest: dict[str, Any]):
    backend_path = os.path.join(manifest["directory"], "backend.py")
    if not os.path.isfile(backend_path):
        return None
    module_name = f"ipbus_monitor_plugin_{manifest['id']}"
    spec = importlib.util.spec_from_file_location(module_name, backend_path)
    if spec is None or spec.loader is None:
        return None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def tree_hooks(cfg: dict[str, Any]) -> list[Callable[..., None]]:
    ranked = sorted(
        _tree_hooks.items(),
        key=lambda item: (
            plugin_config_order(cfg, plugin_manifest(item[0]) or {"id": item[0]}),
            (plugin_manifest(item[0]) or {}).get("name", item[0]),
        ),
    )
    return [fn for plugin_id, fn in ranked if is_plugin_enabled(cfg, plugin_id)]


def init_plugins(app, ctx: dict[str, Any], cfg: dict[str, Any] | None = None) -> None:
    cfg = ensure_plugins_config(cfg or {"plugins": {}})
    for manifest in discover_plugins():
        plugin_id = manifest["id"]
        if plugin_id in _registered_ids or not is_plugin_enabled(cfg, plugin_id):
            continue
        module = load_plugin_backend(manifest)
        if module is None:
            continue
        register = getattr(module, "register", None)
        if callable(register):
            register(app, ctx, manifest)
            _registered_ids.add(plugin_id)
