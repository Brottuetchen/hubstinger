import hashlib
import httpx
from base_plugin import BasePlugin


class NavidromePlugin(BasePlugin):
    name        = "navidrome"
    label       = "Navidrome"
    description = "Music library stats & now playing via Subsonic API"
    icon        = "🎵"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Navidrome URL",
            "placeholder": "http://192.168.1.10:4533",
            "required":    True,
            "hint":        "URL deiner Navidrome-Instanz",
        },
        "username": {
            "type":        "text",
            "label":       "Benutzername",
            "placeholder": "admin",
            "required":    True,
            "hint":        "Navidrome-Benutzer (Admin empfohlen)",
        },
        "password": {
            "type":        "password",
            "label":       "Passwort",
            "placeholder": "••••••••",
            "required":    True,
            "secret":      True,
            "hint":        "Navidrome-Passwort (wird als MD5 gesendet)",
        },
    }

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    def _subsonic_params(self, extra: dict | None = None) -> dict:
        import secrets as sec
        salt   = sec.token_hex(6)
        token  = hashlib.md5((self.cfg("password") + salt).encode()).hexdigest()
        params = {
            "u": self.cfg("username"),
            "t": token,
            "s": salt,
            "v": "1.16.1",
            "c": "familyhub",
            "f": "json",
        }
        if extra:
            params.update(extra)
        return params

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/rest/ping.view",
                                params=self._subsonic_params())
                if r.status_code == 200:
                    status = r.json().get("subsonic-response", {}).get("status")
                    if status == "ok":
                        return {"ok": True, "message": "Navidrome verbunden"}
                    return {"ok": False, "message": "Auth fehlgeschlagen"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/rest/getArtists.view",
                                params=self._subsonic_params())
                artists = 0
                if r.status_code == 200:
                    index = r.json().get("subsonic-response", {}).get("artists", {}).get("index", [])
                    artists = sum(len(i.get("artist", [])) for i in index)

                r2 = await c.get(f"{self._base()}/rest/getAlbumList2.view",
                                 params=self._subsonic_params({"type": "alphabeticalByName", "size": 1}))
                albums = 0
                songs  = 0
                if r2.status_code == 200:
                    info = r2.json().get("subsonic-response", {})
                    # Use getMusicFolders stats if available
                    pass

                # Get now playing
                r3 = await c.get(f"{self._base()}/rest/getNowPlaying.view",
                                 params=self._subsonic_params())
                now_playing = 0
                if r3.status_code == 200:
                    entries = r3.json().get("subsonic-response", {}).get("nowPlaying", {}).get("entry", [])
                    now_playing = len(entries)

                return {
                    "navidrome_artists":     artists,
                    "navidrome_now_playing": now_playing,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/rest/getAlbumList2.view",
                                params=self._subsonic_params({
                                    "type": "recentlyPlayed", "size": 5}))
                if r.status_code != 200:
                    return None
                albums = r.json().get("subsonic-response", {}).get("albumList2", {}).get("album", [])
                if not albums:
                    return None
                items = [
                    {"title": a.get("name", ""), "subtitle": a.get("artist", "")}
                    for a in albums[:5]
                ]
                return {"title": "🎵 Zuletzt gehört", "items": items}
        except Exception:
            return None
