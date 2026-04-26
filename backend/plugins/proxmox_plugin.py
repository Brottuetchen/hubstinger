import httpx
import ssl
from base_plugin import BasePlugin


class ProxmoxPlugin(BasePlugin):
    name        = "proxmox"
    label       = "Proxmox"
    description = "VM & container stats from your Proxmox VE host"
    icon        = "🖥️"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type":        "url",
            "label":       "Proxmox URL",
            "placeholder": "https://192.168.1.10:8006",
            "required":    True,
            "hint":        "URL deines Proxmox-Hosts (inkl. Port 8006)",
        },
        "token_id": {
            "type":        "text",
            "label":       "API Token ID",
            "placeholder": "root@pam!family-hub",
            "required":    True,
            "hint":        "Proxmox → Datacenter → API Tokens → Token ID",
        },
        "token_secret": {
            "type":        "password",
            "label":       "API Token Secret",
            "placeholder": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
            "required":    True,
            "secret":      True,
            "hint":        "Wird beim Erstellen des Tokens angezeigt",
        },
        "node": {
            "type":        "text",
            "label":       "Node Name",
            "placeholder": "pve",
            "required":    False,
            "hint":        "Proxmox Node-Name (Standard: pve)",
        },
        "verify_ssl": {
            "type":    "select",
            "label":   "SSL Zertifikat prüfen",
            "options": [
                {"value": "false", "label": "Nein (selbstsigniert)"},
                {"value": "true",  "label": "Ja"},
            ],
            "required": False,
        },
    }

    def _headers(self) -> dict:
        return {"Authorization": f"PVEAPIToken={self.cfg('token_id')}={self.cfg('token_secret')}"}

    def _base(self) -> str:
        return self.cfg("url").rstrip("/")

    def _verify(self) -> bool:
        return self.cfg("verify_ssl", "false").lower() == "true"

    def _node(self) -> str:
        return self.cfg("node") or "pve"

    async def test(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5, verify=self._verify()) as c:
                r = await c.get(f"{self._base()}/api2/json/version",
                                headers=self._headers())
                if r.status_code == 200:
                    version = r.json().get("data", {}).get("version", "?")
                    return {"ok": True, "message": f"Proxmox VE {version}"}
                return {"ok": False, "message": f"HTTP {r.status_code}"}
        except Exception as e:
            return {"ok": False, "message": str(e)}

    async def get_stats(self) -> dict:
        try:
            node = self._node()
            async with httpx.AsyncClient(timeout=5, verify=self._verify()) as c:
                r = await c.get(f"{self._base()}/api2/json/nodes/{node}/status",
                                headers=self._headers())
                if r.status_code != 200:
                    return {}
                d = r.json().get("data", {})
                cpu_pct  = round(d.get("cpu", 0) * 100, 1)
                mem_used = d.get("memory", {}).get("used", 0) / 1024**3
                mem_total= d.get("memory", {}).get("total", 1) / 1024**3

                # Count VMs + LXC containers
                r2 = await c.get(f"{self._base()}/api2/json/nodes/{node}/qemu",
                                 headers=self._headers())
                r3 = await c.get(f"{self._base()}/api2/json/nodes/{node}/lxc",
                                 headers=self._headers())
                vms = len(r2.json().get("data", [])) if r2.status_code == 200 else 0
                lxc = len(r3.json().get("data", [])) if r3.status_code == 200 else 0

                return {
                    "proxmox_cpu_pct":   cpu_pct,
                    "proxmox_mem_used":  round(mem_used, 1),
                    "proxmox_mem_total": round(mem_total, 1),
                    "proxmox_vms":       vms,
                    "proxmox_lxc":       lxc,
                    "proxmox_containers": vms + lxc,
                }
        except Exception:
            return {}

    async def get_newsletter_block(self) -> dict | None:
        return None  # Proxmox stats aren't relevant for newsletter
