"""
PluginRegistry – auto-discovers and manages Family Hub plugins.

Scans backend/plugins/ for BasePlugin subclasses, stores enabled-state
and config in the DB, and provides a unified interface for the API.
"""

import importlib
import inspect
import json
import logging
import pkgutil
from pathlib import Path
from typing import TYPE_CHECKING

from base_plugin import BasePlugin

if TYPE_CHECKING:
    from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


class PluginRegistry:
    def __init__(self):
        self._classes: dict[str, type[BasePlugin]] = {}
        self._discover()

    # ── Discovery ───────────────────────────────────────────────────────────────

    def _discover(self):
        plugins_dir = Path(__file__).parent / "plugins"
        for finder, module_name, _ in pkgutil.iter_modules([str(plugins_dir)]):
            if module_name.startswith("_"):
                continue
            try:
                module = importlib.import_module(f"plugins.{module_name}")
                for attr in dir(module):
                    cls = getattr(module, attr)
                    if (
                        isinstance(cls, type)
                        and issubclass(cls, BasePlugin)
                        and cls is not BasePlugin
                        and hasattr(cls, "name")
                        and hasattr(cls, "label")
                    ):
                        self._classes[cls.name] = cls
                        logger.info(f"Plugin discovered: {cls.name} ({cls.label})")
            except Exception as e:
                logger.warning(f"Failed to load plugin module '{module_name}': {e}")

    # ── DB helpers ──────────────────────────────────────────────────────────────

    def _get_db_record(self, db: "Session", name: str):
        from main import PluginConfigModel  # avoid circular import
        return db.query(PluginConfigModel).filter(PluginConfigModel.name == name).first()

    def _upsert(self, db: "Session", name: str, enabled: bool | None = None,
                config: dict | None = None):
        from main import PluginConfigModel
        record = self._get_db_record(db, name)
        if record is None:
            record = PluginConfigModel(name=name, enabled=False, config_json="{}")
            db.add(record)
        if enabled is not None:
            record.enabled = enabled
        if config is not None:
            record.config_json = json.dumps(config)
        db.commit()
        db.refresh(record)
        return record

    # ── Public API ──────────────────────────────────────────────────────────────

    def list_all(self, db: "Session") -> list[dict]:
        """Return all discovered plugins with their current status."""
        result = []
        for name, cls in self._classes.items():
            record = self._get_db_record(db, name)
            enabled   = record.enabled if record else False
            cfg       = json.loads(record.config_json) if record else {}
            # Mask secret values for the API response
            safe_cfg  = _mask_secrets(cfg, cls.config_schema)
            configured = _is_configured(cfg, cls.config_schema)
            result.append({
                "name":          cls.name,
                "label":         cls.label,
                "description":   cls.description,
                "icon":          cls.icon,
                "version":       getattr(cls, "version", "1.0.0"),
                "enabled":       enabled,
                "configured":    configured,
                "config_schema": cls.config_schema,
                "config":        safe_cfg,
            })
        return sorted(result, key=lambda p: p["label"])

    def set_enabled(self, db: "Session", name: str, enabled: bool) -> dict:
        if name not in self._classes:
            return {"error": f"Plugin '{name}' not found"}
        self._upsert(db, name, enabled=enabled)
        return {"name": name, "enabled": enabled}

    def save_config(self, db: "Session", name: str, config: dict) -> dict:
        if name not in self._classes:
            return {"error": f"Plugin '{name}' not found"}
        # Preserve existing secrets if masked value is sent back
        record = self._get_db_record(db, name)
        existing = json.loads(record.config_json) if record else {}
        cls = self._classes[name]
        merged = _merge_config(existing, config, cls.config_schema)
        self._upsert(db, name, config=merged)
        return {"name": name, "saved": True}

    async def test_plugin(self, db: "Session", name: str) -> dict:
        if name not in self._classes:
            return {"ok": False, "message": f"Plugin '{name}' not found"}
        record = self._get_db_record(db, name)
        if not record:
            return {"ok": False, "message": "Nicht konfiguriert"}
        cfg = json.loads(record.config_json)
        instance = self._classes[name](cfg)
        if not instance.is_configured():
            return {"ok": False, "message": "Pflichtfelder fehlen"}
        try:
            return await instance.test()
        except Exception as e:
            return {"ok": False, "message": str(e)}

    def get_instance(self, db: "Session", name: str) -> BasePlugin | None:
        """Return a configured, enabled plugin instance (or None)."""
        record = self._get_db_record(db, name)
        if not record or not record.enabled:
            return None
        cfg = json.loads(record.config_json)
        cls = self._classes.get(name)
        if cls is None:
            return None
        return cls(cfg)

    def get_all_instances(self, db: "Session") -> list[BasePlugin]:
        """Return all enabled, configured plugin instances."""
        result = []
        for name in self._classes:
            instance = self.get_instance(db, name)
            if instance and instance.is_configured():
                result.append(instance)
        return result


# ── Helpers ────────────────────────────────────────────────────────────────────

_MASK = "••••••••"

def _mask_secrets(cfg: dict, schema: dict) -> dict:
    masked = {}
    for k, v in cfg.items():
        field_schema = schema.get(k, {})
        if field_schema.get("secret") and v:
            masked[k] = _MASK
        else:
            masked[k] = v
    return masked

def _merge_config(existing: dict, incoming: dict, schema: dict) -> dict:
    merged = dict(existing)
    for k, v in incoming.items():
        field_schema = schema.get(k, {})
        if field_schema.get("secret") and v == _MASK:
            pass  # keep existing secret
        else:
            merged[k] = v
    return merged

def _is_configured(cfg: dict, schema: dict) -> bool:
    for field, field_schema in schema.items():
        if field_schema.get("required") and not cfg.get(field):
            return False
    return bool(cfg) or not schema  # unconfigured if schema exists but cfg is empty


# Singleton
registry = PluginRegistry()
