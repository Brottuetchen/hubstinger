# Family Hub

Self-hosted media & homelab dashboard for iOS, iPad, and Android.

**Liquid Glass Dark UI · Customizable Widget Grid · Plugin System**

---

## Features

- 🪟 **Liquid Glass UI** – visionOS-inspired dark design system
- 🧩 **Widget Grid** – iOS-style home screen, drag-to-reorder, persisted per user in the backend
- 📺 **Now Streaming** – live Jellyfin session overview
- 📷 **Media Posters** – Jellyfin thumbnails via built-in image proxy
- 📬 **Weekly Newsletter** – auto-generated via n8n + TMDB + Ollama
- 🔌 **Plugin System** – 13 built-in plugins (Sonarr, Radarr, Immich, Proxmox, …)
- ⚙️ **Admin Panel** – web UI at `/admin` to configure & test plugins
- 🔔 **Push Notifications** – Web Push via VAPID (FCM-ready)
- 📱 **iPad** – sidebar layout with fully wired tab navigation
- 🔐 **Auth** – JWT login, secure storage, silent auto-refresh
- 🔄 **Token Auto-Refresh** – JWT renewed silently on app resume (< 2 days to expiry)

---

## Stack

| Layer | Tech |
|-------|------|
| App | Flutter 3.x (Dart) |
| State | Riverpod |
| Backend | FastAPI (Python 3.11+) |
| DB | SQLite via SQLAlchemy |
| Push | Web Push / VAPID (pywebpush) |
| Media | Jellyfin + Jellyseerr |
| Metadata | TMDB API |
| AI Summaries | Ollama |
| Automation | n8n |

---

## Quick Start

### 1 – Backend

**Option A – Installer (empfohlen)**

```bash
cd backend
bash install.sh
```

Das Script erledigt alles interaktiv:
- Python-Venv + `pip install`
- `SECRET_KEY` automatisch generieren
- `.env` befüllen (Jellyfin, Ollama, VAPID, …)
- Admin-User anlegen
- VAPID-Keys generieren
- Optionaler systemd-Service

Danach: `source venv/bin/activate && python main.py`

---

**Option B – Manuell**

```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# SECRET_KEY setzen:
sed -i "s|^SECRET_KEY=.*|SECRET_KEY=$(openssl rand -hex 32)|" .env
nano .env                         # Rest der Werte eintragen
python create_admin.py
python main.py
```

Backend läuft auf `http://localhost:8080`.
Admin-Panel: `http://localhost:8080/admin`

### 2 – Flutter App

Flutter 3.x SDK erforderlich → https://flutter.dev/docs/get-started/install

```bash
# Repo-Root

# Einmalig: Platform-Verzeichnisse (android/ ios/ web/) generieren
flutter create --org com.yourname --project-name family_hub .

# Dart-Pakete installieren
flutter pub get

# App starten (Gerät oder Emulator muss verbunden sein)
flutter run
```

Beim ersten Start erscheint ein **Server-URL**-Eingabefeld.
Trage dort deine Backend-URL ein (`http://192.168.1.x:8080` lokal oder `https://deine-domain.com`).

### 3 – Backend im Admin-UI konfigurieren

`http://localhost:8080/admin` öffnen, mit Admin-Zugangsdaten einloggen,
dann zuerst die **Core-Integrationen** konfigurieren:

- `Jellyfin`
- `TMDB`
- `Ollama`
- `Authentik`
- `Web Push / VAPID`

Danach kannst du im selben UI die optionalen Plugins aktivieren und mit URL/API-Keys befüllen
(`Sonarr`, `Immich`, `Jellyseerr`, `Proxmox`, …).

---

## Required vs. Optional Services

| Service | Zweck | Pflicht |
|---------|-------|:-------:|
| Family Hub Backend | API + Auth | ✅ |
| Jellyfin | Streams, Recently Added | ✅ für Media-Widgets |
| TMDB API | Film/Serien-Metadaten | empfohlen |
| Ollama | KI-Zusammenfassungen (Newsletter) | optional |
| n8n | Wöchentlicher Newsletter-Cron | optional |

Alle Integrationen und Plugins werden über das Admin-UI konfiguriert.
Bestehende `.env`-Werte dienen nur noch als Start-/Fallback-Migration.

---

## Plugin System

Auto-Discovery: Alle Dateien in `backend/plugins/` die `BasePlugin` erweitern
werden beim Start automatisch erkannt und im Admin-Panel angezeigt.

### Eingebaute Plugins

| Plugin | Stats | Newsletter |
|--------|-------|:----------:|
| Sonarr | missing / upcoming episodes | ✅ |
| Radarr | missing / total movies | ✅ |
| Proxmox | CPU %, RAM, VMs, LXC | – |
| Jellyseerr | pending / approved requests | ✅ |
| Uptime Kuma | up/down count, uptime % | ✅ (nur bei Ausfall) |
| Immich | Fotos / Videos, Storage GB | ✅ |
| Navidrome | Künstler, Now Playing | ✅ |
| Nextcloud | Dateien, Nutzer, Storage | – |
| n8n | Workflows, Executions | – |
| Gitea | Repos, Stars, Issues | ✅ |
| Portainer | Container running / stopped | – |
| Paperless-ngx | Dokumente, Inbox | ✅ |
| Audiobookshelf | Bücher, Podcasts, In-Progress | ✅ |

### Eigenes Plugin schreiben

`backend/plugins/my_plugin.py` erstellen:

```python
import httpx
from base_plugin import BasePlugin

class MyPlugin(BasePlugin):
    name        = "my_service"     # eindeutige snake_case ID
    label       = "My Service"
    description = "Kurzbeschreibung für Admin-UI"
    icon        = "🔧"
    version     = "1.0.0"

    config_schema = {
        "url": {
            "type": "url", "label": "Service URL",
            "placeholder": "http://192.168.1.10:1234",
            "required": True,
        },
        "api_key": {
            "type": "password", "label": "API Key",
            "required": True, "secret": True,   # wird in UI/API maskiert
        },
    }

    async def test(self) -> dict:
        # {"ok": True, "message": "..."} oder {"ok": False, "message": "..."}
        ...

    async def get_stats(self) -> dict:
        # Flaches Dict – Keys erscheinen in /api/stats
        return {"my_service_count": 42}

    async def get_newsletter_block(self) -> dict | None:
        # {"title": "...", "items": [{"title": "...", "subtitle": "..."}]}
        # oder None um Block zu überspringen
        return None
```

Backend neu starten → Plugin erscheint automatisch in `/admin`.

---

## Umgebungsvariablen

Alle Variablen mit Erklärung stehen in `backend/.env.example`.

| Variable | Beschreibung | Pflicht |
|----------|-------------|:-------:|
| `SECRET_KEY` | JWT-Signing-Key (`openssl rand -hex 32`) | ✅ |
| `JELLYFIN_URL` | einmaliger Migrations-Fallback für Admin-UI | optional |
| `JELLYFIN_TOKEN` | einmaliger Migrations-Fallback für Admin-UI | optional |
| `TMDB_API_KEY` | einmaliger Migrations-Fallback für Admin-UI | optional |
| `OLLAMA_URL` | einmaliger Migrations-Fallback für Admin-UI | optional |
| `VAPID_PRIVATE_KEY` | einmaliger Migrations-Fallback für Admin-UI | optional |
| `VAPID_PUBLIC_KEY` | einmaliger Migrations-Fallback für Admin-UI | optional |
| `VAPID_EMAIL` | einmaliger Migrations-Fallback für Admin-UI | optional |

Im laufenden Betrieb pflegst du diese Werte im `/admin`-UI, nicht in der App.

---

## VAPID-Keys generieren

```bash
cd backend && source venv/bin/activate
python -c "
from pywebpush import Vapid
v = Vapid()
v.generate_keys()
print('Schlüssel in vapid_keys.json gespeichert')
v.save_files()
"
```

Der Backend lädt `vapid_keys.json` automatisch wenn keine Env-Vars gesetzt sind.

---

## Cloudflare Tunnel (optional, für HTTPS)

```yaml
# ~/.cloudflared/config.yml
ingress:
  - hostname: hub.deine-domain.com
    service: http://localhost:8080
  - service: http_status:404
```

HTTPS ist für Web Push Notifications auf mobilen Browsern Pflicht.

---

## Authentik OIDC Setup

### 1 – Authentik Application anlegen
```
Authentik Admin → Applications → Create
  Name:     Family Hub
  Provider: (neu erstellen, s.u.)
```

### 2 – OAuth2/OIDC Provider
```
Providers → Create → OAuth2/OpenID Provider
  Name:           Family Hub
  Client type:    Confidential
  Client ID:      family-hub         ← AUTHENTIK_CLIENT_ID
  Client Secret:  (generiert)        ← AUTHENTIK_CLIENT_SECRET
  Redirect URI:   https://hub.example.com/api/auth/oidc/callback
  Scopes:         openid email profile
```

### 3 – .env setzen
```bash
AUTHENTIK_URL=https://auth.example.com
AUTHENTIK_CLIENT_ID=family-hub
AUTHENTIK_CLIENT_SECRET=<generated>
BACKEND_URL=https://hub.example.com   # für redirect_uri
```

### 4 – Flutter Deep Link (nach flutter create .)

**Android** – `android/app/src/main/AndroidManifest.xml` in `<activity>`:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="hubstinger" android:host="auth"/>
</intent-filter>
```

**iOS** – `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>hubstinger</string></array>
  </dict>
</array>
```

Nach diesen Änderungen erscheint der **"Mit Authentik anmelden"**-Button automatisch
im Login-Screen, sobald OIDC im Backend konfiguriert ist.

---

## Sicherheitshinweise (Produktion)

| Einstellung | Empfehlung |
|-------------|-----------|
| `SECRET_KEY` | `openssl rand -hex 32` – Backend startet nicht ohne diesen Wert |
| `CORS_ORIGINS` | Auf deine Domain einschränken, kein `*` |
| `ENABLE_DOCS` | `false` (Standard) – kein Swagger-UI in Produktion |
| HTTPS | Pflicht für Push & OIDC – Cloudflare Tunnel oder NPM |
| Login-Rate-Limit | Eingebaut: 10 Versuche/Minute pro IP |

---

## Native Push Notifications (Firebase / FCM)

Für native Push auf iOS/Android ist Firebase erforderlich:

1. Firebase-Projekt unter console.firebase.google.com erstellen
2. Android-App hinzufügen → `google-services.json` → `android/app/` ablegen
3. iOS-App hinzufügen → `GoogleService-Info.plist` → `ios/Runner/` ablegen
4. In `pubspec.yaml` ergänzen:
   ```yaml
   firebase_core: ^2.27.0
   firebase_messaging: ^14.7.0
   ```
5. `PushService.instance.registerFcmToken(token)` mit FCM-Token aufrufen

Ohne Firebase sendet das Backend weiterhin Web Push via VAPID an Browser-Subscriber.
