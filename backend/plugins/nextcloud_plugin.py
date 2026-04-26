import httpx
from base_plugin import BasePlugin


class NextcloudPlugin(BasePlugin):
    name        = "nextcloud"
    label       = "Nextcloud"
    description = "Storage usage & active users from your Nextcloud instance"
    icon        = "☁️"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Nextcloud URL",
            "placeholder": "https://cloud.example.com",
            "required":    True,
            "hint":        "URL deiner Nextcloud-Instanz",
        },
        "username": {
            "type":        "text",
            "label":       "Admin Benutzername",
            "placeholder": "admin",
            "required":    True,
            "hint":        "Nextcloud Admin-Benutzer",
        },
        "password": {
            "type":        "password",
            "label":       "Passwort / App-Token",
            "placeholder": "••••••••",
            "required":    True,
            "secret":      True,
            "hint":        "Nextcloud → Settings → Security → App passwords",
        },
    }

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    def _auth(self) -> tuple[str, str]:
        return (self.cfg("username"), self.cfg("password"))

    def _headers(self) -> dict:
        return {"OCS-APIREQUEST": "true", "Accept": "application/json"}

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(
                    f"{self._base()}/ocs/v2.php/cloud/capabilities",
                    auth=self._auth(), headers=self._headers())
                if r.status_code == 200:
                    version = (r.json().get("ocs", {}).get("data", {})
                               .get("version", {}).get("string", "?"))
                    return {"ok": True, "message": f"Nextcloud {version}"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(
                    f"{self._base()}/ocs/v2.php/apps/serverinfo/api/v1/info",
                    auth=self._auth(), headers=self._headers())
                if r.status_code != 200:
                    return {}
                info = r.json().get("ocs", {}).get("data", {})
                storage    = info.get("nextcloud", {}).get("storage", {})
                system     = info.get("nextcloud", {}).get("system", {})
                active_u   = info.get("activeUsers", {})

                num_files  = storage.get("num_files", 0)
                num_users  = storage.get("num_users", 0)
                used_bytes = system.get("usedspace", 0)
                used_gb    = round(int(used_bytes) / 1024**3, 1)
                active_5m  = active_u.get("last5minutes", 0)

                return {
                    "nextcloud_files":     num_files,
                    "nextcloud_users":     num_users,
                    "nextcloud_used_gb":   used_gb,
                    "nextcloud_active":    active_5m,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        return None  # Storage stats not newsletter-relevant
