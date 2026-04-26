import httpx
from base_plugin import BasePlugin


class PortainerPlugin(BasePlugin):
    name        = "portainer"
    label       = "Portainer"
    description = "Docker container stats from your Portainer instance"
    icon        = "🐳"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Portainer URL",
            "placeholder": "http://192.168.1.10:9000",
            "required":    True,
            "hint":        "URL deiner Portainer-Instanz",
        },
        "api_key": {
            "type":        "password",
            "label":       "API Key",
            "placeholder": "ptr_xxx...",
            "required":    True,
            "secret":      True,
            "hint":        "Portainer → Account → Access tokens → Add access token",
        },
        "endpoint_id": {
            "type":        "number",
            "label":       "Endpoint ID",
            "placeholder": "1",
            "required":    False,
            "hint":        "Portainer Environment ID (Standard: 1)",
        },
    }

    def _headers(self) -> dict:
        return {"X-API-Key": self.cfg("api_key")}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    def _endpoint(self) -> int:
        return int(self.cfg("endpoint_id") or 1)

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/status",
                                headers=self._headers())
                if r.status_code == 200:
                    version = r.json().get("Version", "?")
                    return {"ok": True, "message": f"Portainer {version}"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            eid = self._endpoint()
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(
                    f"{self._base()}/api/endpoints/{eid}/docker/containers/json",
                    headers=self._headers(),
                    params={"all": "true"})
                if r.status_code != 200:
                    return {}
                containers = r.json()
                running = sum(1 for ct in containers if ct.get("State") == "running")
                stopped = sum(1 for ct in containers if ct.get("State") in ("exited", "stopped"))
                total   = len(containers)

                return {
                    "portainer_total":   total,
                    "portainer_running": running,
                    "portainer_stopped": stopped,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        return None  # Container stats not newsletter-relevant
