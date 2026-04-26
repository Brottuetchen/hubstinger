import httpx
from base_plugin import BasePlugin


class PaperlessPlugin(BasePlugin):
    name        = "paperless"
    label       = "Paperless-ngx"
    description = "Document count & inbox from your Paperless-ngx instance"
    icon        = "📄"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Paperless URL",
            "placeholder": "http://192.168.1.10:8000",
            "required":    True,
            "hint":        "URL deiner Paperless-ngx-Instanz",
        },
        "token": {
            "type":        "password",
            "label":       "API Token",
            "placeholder": "abc123...",
            "required":    True,
            "secret":      True,
            "hint":        "Paperless → Admin → Auth Token (oder /api/token/ Endpoint)",
        },
    }

    def _headers(self) -> dict:
        return {"Authorization": f"Token {self.cfg('token')}"}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/documents/?page_size=1",
                                headers=self._headers())
                if r.status_code == 200:
                    count = r.json().get("count", 0)
                    return {"ok": True, "message": f"{count} Dokumente gefunden"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/documents/?page_size=1",
                                headers=self._headers())
                total = r.json().get("count", 0) if r.status_code == 200 else 0

                r2 = await c.get(f"{self._base()}/api/correspondents/",
                                 headers=self._headers(),
                                 params={"page_size": 1})
                correspondents = r2.json().get("count", 0) if r2.status_code == 200 else 0

                # Inbox = documents with no tag (or tagged as inbox)
                r3 = await c.get(f"{self._base()}/api/documents/",
                                 headers=self._headers(),
                                 params={"page_size": 1, "is_tagged": "false"})
                inbox = r3.json().get("count", 0) if r3.status_code == 200 else 0

                return {
                    "paperless_total":          total,
                    "paperless_correspondents": correspondents,
                    "paperless_inbox":          inbox,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self._base()}/api/documents/",
                                headers=self._headers(),
                                params={"page_size": 5, "ordering": "-created"})
                if r.status_code != 200:
                    return None
                docs = r.json().get("results", [])
                if not docs:
                    return None
                items = [
                    {
                        "title":    doc.get("title", ""),
                        "subtitle": (doc.get("created") or "")[:10],
                    }
                    for doc in docs[:5]
                ]
                return {"title": "📄 Neue Dokumente", "items": items}
        except Exception:
            return None
