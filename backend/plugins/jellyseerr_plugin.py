import httpx
from base_plugin import BasePlugin


class JellyseerrPlugin(BasePlugin):
    name        = "jellyseerr"
    label       = "Jellyseerr"
    description = "Pending & approved media requests from Jellyseerr"
    icon        = "🎥"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Jellyseerr URL",
            "placeholder": "http://192.168.1.10:5055",
            "required":    True,
            "hint":        "URL deiner Jellyseerr-Instanz",
        },
        "api_key": {
            "type":        "password",
            "label":       "API Key",
            "placeholder": "abc123...",
            "required":    True,
            "secret":      True,
            "hint":        "Jellyseerr → Settings → General → API Key",
        },
    }

    def _headers(self) -> dict:
        return {"X-Api-Key": self.cfg("api_key")}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v1/settings/public",
                                headers=self._headers())
                if r.status_code == 200:
                    app = r.json().get("applicationTitle", "Jellyseerr")
                    return {"ok": True, "message": f"{app} erreichbar"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v1/request/count",
                                headers=self._headers())
                if r.status_code != 200:
                    return {}
                d = r.json()
                return {
                    "jellyseerr_pending":  d.get("pending", 0),
                    "jellyseerr_approved": d.get("approved", 0),
                    "jellyseerr_available": d.get("available", 0),
                    "jellyseerr_total":    d.get("total", 0),
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v1/request",
                                headers=self._headers(),
                                params={"take": 5, "skip": 0, "sort": "added",
                                        "filter": "available"})
                if r.status_code != 200:
                    return None
                results = r.json().get("results", [])
                if not results:
                    return None
                items = []
                for req in results:
                    media = req.get("media", {})
                    title = media.get("originalTitle") or req.get("type", "")
                    year  = str(media.get("releaseDate", "") or "")[:4]
                    items.append({"title": title, "subtitle": year})
                return {"title": "🎥 Neu verfügbar", "items": items}
        except Exception:
            return None
