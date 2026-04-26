import httpx
from base_plugin import BasePlugin


class SonarrPlugin(BasePlugin):
    name        = "sonarr"
    label       = "Sonarr"
    description = "Upcoming episodes & missing series from your Sonarr instance"
    icon        = "📡"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Sonarr URL",
            "placeholder": "http://192.168.1.10:8989",
            "required":    True,
            "hint":        "URL deiner Sonarr-Instanz",
        },
        "api_key": {
            "type":        "password",
            "label":       "API Key",
            "placeholder": "abc123...",
            "required":    True,
            "secret":      True,
            "hint":        "Sonarr → Settings → General → API Key",
        },
        "upcoming_days": {
            "type":        "number",
            "label":       "Upcoming (Tage)",
            "placeholder": "7",
            "required":    False,
            "hint":        "Wie viele Tage vorausschauen",
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
                    return {"ok": True, "message": f"Sonarr v{version}"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v3/wanted/missing",
                                headers=self._headers(),
                                params={"pageSize": 1})
                missing = r.json().get("totalRecords", 0) if r.status_code == 200 else 0

                days = int(self.cfg("upcoming_days") or 7)
                from datetime import datetime, timedelta, timezone
                start = datetime.now(timezone.utc).strftime("%Y-%m-%d")
                end   = (datetime.now(timezone.utc) + timedelta(days=days)).strftime("%Y-%m-%d")
                r2 = await c.get(f"{self._base()}/api/v3/calendar",
                                 headers=self._headers(),
                                 params={"start": start, "end": end})
                upcoming = len(r2.json()) if r2.status_code == 200 else 0
                return {"sonarr_missing": missing, "sonarr_upcoming": upcoming}
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            from datetime import datetime, timedelta, timezone
            days  = int(self.cfg("upcoming_days") or 7)
            start = datetime.now(timezone.utc).strftime("%Y-%m-%d")
            end   = (datetime.now(timezone.utc) + timedelta(days=days)).strftime("%Y-%m-%d")
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v3/calendar",
                                headers=self._headers(),
                                params={"start": start, "end": end})
                if r.status_code != 200 or not r.json():
                    return None
                items = [
                    {
                        "title":    ep.get("series", {}).get("title", ep.get("title", "")),
                        "subtitle": f"S{ep.get('seasonNumber',0):02d}E{ep.get('episodeNumber',0):02d} · "
                                    f"{ep.get('airDateUtc','')[:10]}",
                    }
                    for ep in r.json()[:5]
                ]
                return {"title": f"📡 Upcoming Serien ({days} Tage)", "items": items}
        except Exception:
            return None
