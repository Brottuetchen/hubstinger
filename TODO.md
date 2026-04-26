# Family Hub - TODO

> Stand: April 2026 · Branch: `claude/work-through-todos-xWv5P`

---

## 🔴 KRITISCH – vor dem ersten Start erledigen

- [ ] **`SECRET_KEY` setzen** – automatisch via `bash install.sh` oder manuell: `openssl rand -hex 32` → `.env`
- [ ] **Admin-User anlegen** – `bash install.sh` macht das interaktiv, oder: `python create_admin.py`
- [ ] **Jellyfin Token** holen – Jellyfin → Dashboard → API Keys → `+` (install.sh fragt danach)
- [ ] **CF Tunnel / NPM** konfigurieren – HTTPS Pflicht für Push & OIDC
- [ ] **`flutter create --org com.yourname --project-name family_hub .`** – einmalig nach Clone

---

## 🟠 OFFEN – App läuft, aber unvollständig

### Auth
- [x] Login Screen mit Username/Passwort
- [x] JWT Token Storage (flutter_secure_storage)
- [x] Logout + Token löschen
- [x] 401 Auto-Logout (ApiService löscht Token bei abgelaufenem JWT)
- [x] Backend: Authentik OIDC Endpoints (`/api/auth/oidc-url`, `/api/auth/oidc/callback`)
- [x] Flutter: "Mit Authentik anmelden"-Button + Deep-Link-Handler (`app_links`)
- [x] **Token Auto-Refresh** – `POST /api/auth/refresh` Backend + Flutter Refresh bei App-Resume & Startup
- [ ] **Authentik OIDC konfigurieren** – Provider in Authentik anlegen, `.env` befüllen, URL-Scheme in `AndroidManifest.xml` / `Info.plist` eintragen (siehe README)

### Flutter App
- [x] Widget Grid mit iOS-Edit-Mode
- [x] Layout-Persistenz (SharedPreferences)
- [x] Jellyfin Sessions → StreamingWidget
- [x] Jellyfin Recently Added → RecentlyWidget (mit Poster-Thumbnails)
- [x] Pull-to-Refresh auf Home Screen
- [x] Push Service (FCM-ready stub, registriert Token beim Backend)
- [x] **iPad Sidebar** – Tab-Wechsel vollständig verdrahtet (tabIndexProvider)
- [x] **Live Stat Widgets** – containers, proxmox, requests, uptime, nas ziehen echte Werte aus `/api/stats`
- [x] **Plugin Widgets** – Sonarr, Radarr, Immich, Navidrome im Widget-Editor verfügbar
- [ ] **App Icon** – Datei `assets/icons/app_icon.png` erstellen (512×512)
- [ ] **Splash Screen** – Loading-Bild beim Start

### Backend / Infrastruktur
- [ ] **TMDB Key** – kostenlos unter themoviedb.org/settings/api
- [ ] **Ollama** testen – `curl http://<ollama-host>:11434/api/generate -d '{"model":"llama3.2","prompt":"test","stream":false}'`
- [ ] **n8n Workflow** – Cron Fr 17:00 → `POST /api/newsletter/generate`
- [ ] **Uptime Kuma Webhook** – in Uptime Kuma auf `https://deine-domain.com/api/webhook/uptime-kuma` zeigen
- [ ] **Jellyfin Watchtime** – Playback Reporting Plugin in Jellyfin installieren

---

## 🟡 NICE TO HAVE

### Newsletter
- [ ] **SMTP Versand** – HTML-Mail via Mailcow / SMTP
- [ ] **Vorschau in App** – Newsletter vor Versand anzeigen
- [ ] **Manuell triggern** – Button in Settings
- [ ] **Empfänger verwalten** – Admin-UI für Verteiler

### Services Screen
- [ ] **Service-Tap** – öffnet Service im In-App Browser
- [ ] **Live Health-Check** – Ping-Status direkt in der App

### UX
- [ ] **Haptic Feedback** beim Widget bearbeiten
- [ ] **Deep Links** – Push Notification öffnet richtigen Screen
- [ ] **Dark/Light Mode**

---

## 🟢 LANGFRISTIG

### App Store / Play Store
- [ ] Apple Developer Account (99 €/Jahr)
- [ ] iOS Signing Certs in GitHub Secrets
- [ ] TestFlight Beta für Familie
- [ ] App Store Listing (Screenshots, Beschreibung)
- [ ] Google Play (25 € einmalig)

### Plugin Ökosystem
- [x] Plugin-Interface (`BasePlugin` ABC + `config_schema` + `get_newsletter_block`)
- [x] Plugin-Registry mit Auto-Discovery
- [x] Admin-Panel (`/admin`) zum Verwalten
- [x] 13 eingebaute Plugins (Sonarr, Radarr, Proxmox, Jellyseerr, Immich, Navidrome, Nextcloud, n8n, Gitea, Portainer, Paperless, Audiobookshelf, Uptime Kuma)
- [ ] Community Plugins Repo + Dokumentation

### Multi-User
- [ ] User-Management Screen (Admin)
- [ ] Per-User Watchtime & Notifications
- [ ] Familien-Profile mit eigenen Dashboards

---

## ✅ ERLEDIGT

**Code / Architektur**
- Flutter Projektstruktur + Liquid Glass Design System
- 4 Screens: Home, Services, Newsletter, Settings
- Widget Grid mit iOS Edit Mode + Layout-Persistenz
- FastAPI Backend mit SQLite/SQLAlchemy
- JWT Auth (Backend + Flutter)
- JWT Token Auto-Refresh (`POST /api/auth/refresh` + Flutter Refresh bei Resume/Start)
- Web Push / VAPID Backend
- Newsletter Builder Pipeline (Jellyfin → TMDB → Ollama → HTML)
- Uptime Kuma Webhook Endpoint
- Jellyfin Image-Proxy (`/api/jellyfin/image/{id}`)
- Plugin System (BasePlugin, Registry, Admin-UI, 13 Plugins)
- Plugin Stats in `/api/stats` aggregiert (parallel via asyncio.gather)
- Authentik OIDC Endpoints + Flutter Deep-Link-Handler
- iPad Sidebar Navigation (tabIndexProvider, vollständig verdrahtet)
- Live Stat Widgets (containers, proxmox, requests, uptime, nas → echte /api/stats Werte)
- Plugin Widgets: Sonarr, Radarr, Immich, Navidrome im Widget-Editor

**Hardening**
- `SECRET_KEY` Pflicht beim Start (harter Abbruch bei Default-Wert)
- Rate Limiting auf Login (10 req/min/IP via slowapi)
- Security Headers (X-Frame-Options, X-Content-Type-Options, …)
- CORS konfigurierbar per `CORS_ORIGINS` Env-Var
- Globaler Exception-Handler (kein Stack Trace in API-Responses)
- Swagger `/docs` standardmäßig deaktiviert

**Infrastruktur / Setup**
- `.env.example` vollständig mit Kommentaren
- `create_admin.py` interaktiv
- `install.sh` – vollständiger Installer (venv, SECRET_KEY, .env, Jellyfin, VAPID-Keys, Admin, systemd)
- README mit vollständiger Setup-Anleitung + Authentik OIDC Guide
- Repo bereinigt (keine hardcodierten IPs/Domains)
- Fresh-Clone buildbar (`flutter create .` + `flutter pub get`)
