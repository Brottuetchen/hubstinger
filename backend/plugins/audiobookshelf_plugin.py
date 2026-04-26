import httpx
from base_plugin import BasePlugin


class AudiobookshelfPlugin(BasePlugin):
    name        = "audiobookshelf"
    label       = "Audiobookshelf"
    description = "Audiobook & podcast library stats from Audiobookshelf"
    icon        = "🎧"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Audiobookshelf URL",
            "placeholder": "http://192.168.1.10:13378",
            "required":    True,
            "hint":        "URL deiner Audiobookshelf-Instanz",
        },
        "token": {
            "type":        "password",
            "label":       "API Token",
            "placeholder": "abc123...",
            "required":    True,
            "secret":      True,
            "hint":        "Audiobookshelf → Settings → Users → API Token (Admin)",
        },
    }

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self.cfg('token')}"}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/authorize",
                                headers=self._headers())
                if r.status_code == 200:
                    user = r.json().get("user", {}).get("username", "?")
                    return {"ok": True, "message": f"Audiobookshelf: {user}"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/libraries",
                                headers=self._headers())
                if r.status_code != 200:
                    return {}
                libraries = r.json().get("libraries", [])
                total_books    = 0
                total_podcasts = 0
                in_progress    = 0

                for lib in libraries:
                    lib_id   = lib.get("id")
                    lib_type = lib.get("mediaType", "book")
                    r2 = await c.get(f"{self._base()}/api/libraries/{lib_id}/stats",
                                     headers=self._headers())
                    if r2.status_code == 200:
                        stats = r2.json()
                        if lib_type == "book":
                            total_books += stats.get("totalItems", 0)
                        elif lib_type == "podcast":
                            total_podcasts += stats.get("totalItems", 0)

                # Get sessions in progress
                r3 = await c.get(f"{self._base()}/api/me/listening-sessions",
                                 headers=self._headers(),
                                 params={"itemsPerPage": 1})
                if r3.status_code == 200:
                    in_progress = r3.json().get("total", 0)

                return {
                    "abs_books":       total_books,
                    "abs_podcasts":    total_podcasts,
                    "abs_in_progress": in_progress,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/libraries",
                                headers=self._headers())
                if r.status_code != 200:
                    return None
                libraries = r.json().get("libraries", [])
                if not libraries:
                    return None

                lib_id = libraries[0].get("id")
                r2 = await c.get(f"{self._base()}/api/libraries/{lib_id}/items",
                                 headers=self._headers(),
                                 params={"sort": "addedAt", "desc": 1, "limit": 5})
                if r2.status_code != 200:
                    return None
                items_raw = r2.json().get("results", [])
                items = [
                    {
                        "title":    it.get("media", {}).get("metadata", {}).get("title", ""),
                        "subtitle": it.get("media", {}).get("metadata", {}).get("authorName", ""),
                    }
                    for it in items_raw[:5]
                ]
                return {"title": "🎧 Neue Hörbücher", "items": items}
        except Exception:
            return None
