import httpx
from base_plugin import BasePlugin


class GiteaPlugin(BasePlugin):
    name        = "gitea"
    label       = "Gitea"
    description = "Repository & issue stats from your Gitea instance"
    icon        = "🐙"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Gitea URL",
            "placeholder": "http://192.168.1.10:3000",
            "required":    True,
            "hint":        "URL deiner Gitea-Instanz",
        },
        "token": {
            "type":        "password",
            "label":       "Access Token",
            "placeholder": "abc123...",
            "required":    True,
            "secret":      True,
            "hint":        "Gitea → Settings → Applications → Generate Token",
        },
    }

    def _headers(self) -> dict:
        return {"Authorization": f"token {self.cfg('token')}"}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v1/user",
                                headers=self._headers())
                if r.status_code == 200:
                    login = r.json().get("login", "?")
                    return {"ok": True, "message": f"Gitea: @{login}"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v1/repos/search",
                                headers=self._headers(),
                                params={"limit": 50, "token": self.cfg("token")})
                repos = r.json().get("data", []) if r.status_code == 200 else []
                total_repos  = len(repos)
                total_stars  = sum(r.get("stars_count", 0) for r in repos)

                r2 = await c.get(f"{self._base()}/api/v1/repos/issues/search",
                                 headers=self._headers(),
                                 params={"state": "open", "type": "issues", "limit": 1})
                open_issues = 0
                if r2.status_code == 200:
                    # Gitea returns X-Total-Count header
                    open_issues = int(r2.headers.get("X-Total-Count", 0))

                return {
                    "gitea_repos":       total_repos,
                    "gitea_stars":       total_stars,
                    "gitea_open_issues": open_issues,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/v1/repos/search",
                                headers=self._headers(),
                                params={"sort": "newest", "limit": 5})
                if r.status_code != 200:
                    return None
                repos = r.json().get("data", [])
                if not repos:
                    return None
                items = [
                    {
                        "title":    repo.get("full_name", ""),
                        "subtitle": f"⭐ {repo.get('stars_count',0)} · {(repo.get('updated','')or'')[:10]}",
                    }
                    for repo in repos[:5]
                ]
                return {"title": "🐙 Repos", "items": items}
        except Exception:
            return None
