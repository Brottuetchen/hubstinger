import httpx
from base_plugin import BasePlugin


class UptimeKumaPlugin(BasePlugin):
    name        = "uptime_kuma"
    label       = "Uptime Kuma"
    description = "Service uptime & availability from Uptime Kuma status pages"
    icon        = "✅"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Uptime Kuma URL",
            "placeholder": "http://192.168.1.10:3001",
            "required":    True,
            "hint":        "Basis-URL deiner Uptime Kuma Instanz",
        },
        "status_page_slug": {
            "type":        "text",
            "label":       "Status Page Slug",
            "placeholder": "home",
            "required":    True,
            "hint":        "Slug deiner öffentlichen Status Page (z.B. 'home')",
        },
    }

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    def _slug(self) -> str:
        return self.cfg("status_page_slug") or "home"

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/status-page/{self._slug()}")
                if r.status_code == 200:
                    title = r.json().get("config", {}).get("title", "Uptime Kuma")
                    return {"ok": True, "message": f"Status Page '{title}' gefunden"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(
                    f"{self._base()}/api/status-page/heartbeat/{self._slug()}")
                if r.status_code != 200:
                    return {}
                data = r.json()
                heartbeat_list = data.get("heartbeatList", {})
                uptime_list    = data.get("uptimeList", {})

                total  = len(heartbeat_list)
                up     = 0
                for monitor_id, beats in heartbeat_list.items():
                    latest = beats[-1] if beats else {}
                    if latest.get("status") == 1:
                        up += 1

                # Average 24h uptime across all monitors
                uptime_values = [
                    v for k, v in uptime_list.items() if k.endswith("_24")
                ]
                avg_uptime = (
                    round(sum(uptime_values) / len(uptime_values) * 100, 1)
                    if uptime_values else 0.0
                )

                return {
                    "uptime_kuma_total":    total,
                    "uptime_kuma_up":       up,
                    "uptime_kuma_down":     total - up,
                    "uptime_kuma_pct":      avg_uptime,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(
                    f"{self._base()}/api/status-page/heartbeat/{self._slug()}")
                if r.status_code != 200:
                    return None
                heartbeat_list = r.json().get("heartbeatList", {})
                down = []
                for monitor_id, beats in heartbeat_list.items():
                    latest = beats[-1] if beats else {}
                    if latest.get("status") != 1:
                        down.append({"title": latest.get("name", monitor_id),
                                     "subtitle": "⚠️ Offline"})
                if not down:
                    return None  # no news = good news
                return {"title": "⚠️ Services offline", "items": down[:5]}
        except Exception:
            return None
