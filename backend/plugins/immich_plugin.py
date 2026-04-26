import httpx
from base_plugin import BasePlugin


class ImmichPlugin(BasePlugin):
    name        = "immich"
    label       = "Immich"
    description = "Photo library stats & recently uploaded assets"
    icon        = "📷"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Immich URL",
            "placeholder": "http://192.168.1.10:2283",
            "required":    True,
            "hint":        "URL deiner Immich-Instanz",
        },
        "api_key": {
            "type":        "password",
            "label":       "API Key",
            "placeholder": "abc123...",
            "required":    True,
            "secret":      True,
            "hint":        "Immich → Account Settings → API Keys → New API Key",
        },
    }

    def _headers(self) -> dict:
        return {"x-api-key": self.cfg("api_key")}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/server-info/version",
                                headers=self._headers())
                if r.status_code == 200:
                    v = r.json()
                    version = f"{v.get('major','?')}.{v.get('minor','?')}.{v.get('patch','?')}"
                    return {"ok": True, "message": f"Immich v{version}"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/asset/statistics",
                                headers=self._headers())
                if r.status_code != 200:
                    return {}
                d = r.json()
                total   = d.get("total", 0)
                photos  = d.get("photos", 0)
                videos  = d.get("videos", 0)

                # Storage usage via server stats (admin only)
                storage_gb = 0.0
                r2 = await c.get(f"{self._base()}/api/server-info/statistics",
                                 headers=self._headers())
                if r2.status_code == 200:
                    usage = r2.json().get("usageByUser", [])
                    total_bytes = sum(u.get("usage", 0) for u in usage)
                    storage_gb = round(total_bytes / 1024**3, 1)

                return {
                    "immich_total":      total,
                    "immich_photos":     photos,
                    "immich_videos":     videos,
                    "immich_storage_gb": storage_gb,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/asset",
                                headers=self._headers(),
                                params={"take": 5, "order": "desc"})
                if r.status_code != 200 or not r.json():
                    return None
                items = [
                    {
                        "title":    a.get("originalFileName", ""),
                        "subtitle": (a.get("fileCreatedAt") or "")[:10],
                    }
                    for a in r.json()[:5]
                ]
                return {"title": "📷 Neue Fotos", "items": items}
        except Exception:
            return None
