import httpx
from base_plugin import BasePlugin


class RadarrPlugin(BasePlugin):
    name        = "radarr"
    label       = "Radarr"
    description = "Wanted & missing movies from your Radarr instance"
    icon        = "🎬"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Radarr URL",
            "placeholder": "http://192.168.1.10:7878",
            "required":    True,
            "hint":        "URL deiner Radarr-Instanz",
        },
        "api_key": {
            "type":        "password",
            "label":       "API Key",
            "placeholder": "abc123...",
            "required":    True,
            "secret":      True,
            "hint":        "Radarr → Settings → General → API Key",
        },
    }

    def _headers(self) -> dict:
        return {"X-Api-Key": self.cfg("api_key")}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v3/system/status",
                                headers=self._headers())
                if r.status_code == 200:
                    version = r.json().get("version", "?")
                    return {"ok": True, "message": f"Radarr v{version}"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v3/wanted/missing",
                                headers=self._headers(), params={"pageSize": 1})
                missing = r.json().get("totalRecords", 0) if r.status_code == 200 else 0

                r2 = await c.get(f"{self._base()}/api/v3/movie",
                                 headers=self._headers())
                total = len(r2.json()) if r2.status_code == 200 else 0
                return {"radarr_missing": missing, "radarr_total": total}
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v3/wanted/missing",
                                headers=self._headers(),
                                params={"pageSize": 5, "sortKey": "title"})
                if r.status_code != 200:
                    return None
                movies = r.json().get("records", [])
                if not movies:
                    return None
                items = [
                    {"title": m.get("title", ""), "subtitle": str(m.get("year", ""))}
                    for m in movies
                ]
                return {"title": "🎬 Fehlende Filme", "items": items}
        except Exception:
            return None
