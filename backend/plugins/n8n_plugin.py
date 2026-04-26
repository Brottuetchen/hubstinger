import httpx
from base_plugin import BasePlugin


class N8nPlugin(BasePlugin):
    name        = "n8n"
    label       = "n8n"
    description = "Active workflows & recent executions from your n8n instance"
    icon        = "⚡"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "n8n URL",
            "placeholder": "http://192.168.1.10:5678",
            "required":    True,
            "hint":        "URL deiner n8n-Instanz",
        },
        "api_key": {
            "type":        "password",
            "label":       "API Key",
            "placeholder": "n8n_api_...",
            "required":    True,
            "secret":      True,
            "hint":        "n8n → Settings → n8n API → Create an API key",
        },
    }

    def _headers(self) -> dict:
        return {"X-N8N-API-KEY": self.cfg("api_key")}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v1/workflows?limit=1",
                                headers=self._headers())
                if r.status_code == 200:
                    return {"ok": True, "message": "n8n erreichbar"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v1/workflows",
                                headers=self._headers(),
                                params={"limit": 100})
                workflows = r.json().get("data", []) if r.status_code == 200 else []
                active    = sum(1 for w in workflows if w.get("active"))
                total     = len(workflows)

                r2 = await c.get(f"{self._base()}/api/v1/executions",
                                 headers=self._headers(),
                                 params={"limit": 20, "status": "success"})
                recent_ok = len(r2.json().get("data", [])) if r2.status_code == 200 else 0

                r3 = await c.get(f"{self._base()}/api/v1/executions",
                                 headers=self._headers(),
                                 params={"limit": 20, "status": "error"})
                recent_err = len(r3.json().get("data", [])) if r3.status_code == 200 else 0

                return {
                    "n8n_workflows":       total,
                    "n8n_active":          active,
                    "n8n_executions_ok":   recent_ok,
                    "n8n_executions_err":  recent_err,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        return None  # Workflow stats not newsletter-relevant
