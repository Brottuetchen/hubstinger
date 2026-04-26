"""
BasePlugin – abstract base class for all Family Hub plugins.

To create a plugin:
1. Create backend/plugins/my_plugin.py
2. Subclass BasePlugin
3. Set class attributes (name, label, description, icon, config_schema)
4. Implement test(), get_stats(), get_newsletter_block()
5. Restart the backend – the plugin is auto-discovered and appears in /admin

Example:
    class MyPlugin(BasePlugin):
        name        = "my_service"
        label       = "My Service"
        description = "Does something useful"
        icon        = "🔧"
        config_schema = {
            "url":     {"type": "url",      "label": "Service URL", "required": True},
            "api_key": {"type": "password", "label": "API Key",     "required": True, "secret": True},
        }

        async def test(self) -> dict:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(self.cfg("url") + "/api/v3/system/status",
                                headers={"X-Api-Key": self.cfg("api_key")})
                return {"ok": r.status_code == 200, "message": r.json().get("version", "OK")}

        async def get_stats(self) -> dict:
            return {"my_stat": 42}

        async def get_newsletter_block(self) -> dict | None:
            return {"title": "My Block", "items": []}
"""

from abc import ABC, abstractmethod
from typing import Any


class BasePlugin(ABC):
    # ── Required class attributes ───────────────────────────────────────────────
    name:        str  # unique snake_case id, e.g. "sonarr"
    label:       str  # display name, e.g. "Sonarr"
    description: str  # one-line description
    icon:        str  # emoji

    # Optional
    version: str = "1.0.0"

    # Config schema – defines the form fields shown in /admin
    # Format: {field_name: {type, label, required?, secret?, placeholder?, hint?}}
    # Types: "text" | "url" | "password" | "number" | "select"
    # For "select": add "options": [{"value": "v", "label": "L"}, ...]
    config_schema: dict[str, dict] = {}

    def __init__(self, config: dict[str, Any]):
        self._config = config

    def cfg(self, key: str, default: Any = "") -> Any:
        """Get a config value."""
        return self._config.get(key, default)

    def is_configured(self) -> bool:
        """Returns True if all required fields are set."""
        for field, schema in self.config_schema.items():
            if schema.get("required") and not self._config.get(field):
                return False
        return True

    # ── Interface ───────────────────────────────────────────────────────────────

    async def test(self) -> dict:
        """
        Test the connection / configuration.
        Return {"ok": True/False, "message": "Version 4.0.1" or "Connection refused"}.
        """
        return {"ok": True, "message": "Kein Test implementiert"}

    async def get_stats(self) -> dict:
        """
        Return stats to be included in GET /api/stats.
        Return {} if this plugin doesn't provide stats.
        Example: {"sonarr_upcoming": 3, "sonarr_missing": 12}
        """
        return {}

    async def get_newsletter_block(self) -> dict | None:
        """
        Return a newsletter block to be included in the weekly newsletter.
        Return None if this plugin doesn't contribute to the newsletter.
        Format: {"title": str, "items": [{"title": str, "subtitle"?: str, ...}]}
        """
        return None
