# Family Hub - TODO

> Letzter Stand: April 2026 · Repo: github.com/Brottuetchen/hubstinger
> Stand Code: claude/work-through-todos-xWv5P

---

## 🔴 KRITISCH – App läuft nicht ohne das

- [x] **Dart Import-Fehler fixen** – Widget-Dateien aufgeteilt, jede Klasse in eigener Datei
- [x] **`backend/plugins/__init__.py`** angelegt
- [x] **API Service** (`lib/services/api_service.dart`) – HTTP-Calls mit JWT-Interceptor
- [x] **Auth Flow** – Login Screen ✓, Token Storage (flutter_secure_storage) ✓, Logout ✓
- [ ] **CF Tunnel / NPM** für `hub.t-acc.com` → HTTPS Pflicht für Push
- [ ] **`.env` befüllen** auf LXC 192.168.188.50 – Jellyfin, TMDB, Jellyseerr Keys
- [ ] **GitHub Token invalidieren** – den aus dem Chat sofort neu generieren

---

## 🟠 CORE FEATURES – App nutzbar aber unvollständig

### Auth & SSO
- [x] **Login Screen** (Email + Password) als Fallback
- [ ] **Authentik OAuth2/OIDC** einrichten
  - [ ] Authentik: neue Application + Provider anlegen (OIDC)
  - [ ] Redirect URI: `hubstinger://auth/callback`
  - [ ] Flutter: `flutter_appauth` + `flutter_secure_storage` einbinden
  - [ ] Backend: OIDC Token Verification gegen Authentik JWKS Endpoint
  - [ ] `GET /api/auth/oidc/callback` Endpoint im Backend
- [x] **Token Storage** – JWT sicher gespeichert (flutter_secure_storage)
- [ ] **Auto-Refresh** – Token renewal im Hintergrund
- [x] **Logout** – Token invalidieren + secure storage leeren

### Flutter App
- [x] **Widget Layout Persistence** – SharedPreferences, überlebt App-Neustart
- [x] **Echte Jellyfin Sessions** verdrahten → Now Streaming Widget (via Riverpod Provider)
- [x] **Echte Recently Added** verdrahten → Jellyfin Widget (via Riverpod Provider)
- [ ] **TMDB Poster** laden → `cached_network_image` nutzen
- [ ] **Push Notifications** – `firebase_messaging` initialisieren, beim Backend registrieren
- [ ] **iPad Sidebar Navigation** – Tab-Wechsel verdrahten
- [ ] **App Icon** – echtes Icon erstellen (192x192, 512x512)
- [ ] **Splash Screen** – Loading Screen beim Start

### Backend
- [ ] **Jellyfin Watchtime** – Jellyfin Playback Reporting Plugin installieren
- [ ] **n8n Newsletter Workflow** – Cron Fr 17:00 → POST `/api/newsletter/generate`
- [ ] **Uptime Kuma Webhook** – in Uptime Kuma auf `/api/webhook/uptime-kuma` zeigen
- [ ] **TMDB Key** holen (kostenlos: themoviedb.org/settings/api)
- [ ] **Ollama testen** – `curl http://192.168.188.110:11434/api/generate`

---

## 🟡 NICE TO HAVE – Deutlich besser mit, aber nicht blocking

### Neue Widgets
- [ ] **Sonarr Widget** – Upcoming Episodes, Calendar
- [ ] **Radarr Widget** – Wanted/Missing Movies
- [ ] **Immich Widget** – Recent Photos, Stats
- [ ] **Navidrome Widget** – Now Playing, Recently Played
- [ ] **Grafana Widget** – Embed Dashboard Panel
- [ ] **Nextcloud Widget** – Kalender Events

### Newsletter
- [ ] **HTML Mail** via Mailcow SMTP versenden
- [ ] **Newsletter Vorschau** in der App vor dem Versand
- [ ] **Manuell triggern** – Button in Settings
- [ ] **Empfänger verwalten** – wer bekommt den Newsletter

### Services Screen
- [ ] **Service Details** – Tap öffnet den Service im In-App Browser
- [ ] **Service Stats** – CPU/RAM direkt vom Service wenn API verfügbar
- [ ] **Ping/Health Check** live in der App

### UX
- [ ] **Dark/Light Mode Toggle** – aktuell nur Dark
- [ ] **Haptic Feedback** beim Widget bearbeiten
- [ ] **Pull to Refresh** auf allen Screens
- [ ] **Onboarding Flow** – Server URL Setup beim ersten Start
- [ ] **Deep Links** – Push Notification öffnet richtigen Screen

---

## 🟢 LANGFRISTIG – Public Release

### App Store / Play Store
- [ ] **Apple Developer Account** (99€/Jahr)
- [ ] **iOS Signing Certs** in GitHub Secrets hinterlegen
- [ ] **TestFlight** – Familie einladen
- [ ] **App Store Connect** – Listing, Screenshots, Beschreibung
- [ ] **Play Store** – Google Developer Account (25€ einmalig)

### Plugin System (Community)
- [ ] **Plugin Interface** finalisieren (`BasePlugin` + `NewsletterBlock`)
- [ ] **Plugin Registry** – Plugins aktivieren/deaktivieren per UI
- [ ] **Plugin Config UI** – API Keys per Widget eintragen
- [ ] **Community Plugins Repo** anlegen
- [ ] **Dokumentation** für Plugin-Entwickler

### Multi-User
- [ ] **User Management** Screen (Admin)
- [ ] **Per-User Watchtime** – eigene Stats pro User
- [ ] **Per-User Notifications** – jeder entscheidet selbst
- [ ] **Family Profiles** – unterschiedliche Dashboards

---

## ✅ ERLEDIGT

- [x] Flutter Projektstruktur
- [x] Liquid Glass Design System (`glass_card.dart`)
- [x] 4 Screens: Home, Services, Newsletter, Settings
- [x] Widget Grid mit iOS Edit Mode
- [x] FastAPI Backend Grundstruktur
- [x] JWT Auth Backend-seitig
- [x] Web Push / VAPID Backend
- [x] Newsletter Builder Pipeline (Jellyfin → TMDB → Ollama → HTML)
- [x] Uptime Kuma Webhook Endpoint
- [x] GitHub Actions CI/CD (iOS + Android)
- [x] VS Code Config (launch, settings, extensions)
- [x] CLAUDE.md für Claude Code Context
- [x] Repo auf GitHub gepusht (github.com/Brottuetchen/hubstinger)

---

## Authentik OAuth2 Setup – Schritt für Schritt

### 1. Authentik – Application anlegen
```
Authentik Admin → Applications → Create
Name:          Family Hub
Slug:          family-hub
Provider:      (neu erstellen, siehe unten)
```

### 2. Authentik – OAuth2/OIDC Provider
```
Providers → Create → OAuth2/OpenID Provider
Name:                  Family Hub
Authorization flow:    default-authorization-flow
Client type:           Public (kein Secret für mobile Apps)
Client ID:             family-hub  (merken!)
Redirect URIs:         hubstinger://auth/callback
Signing Key:           authentik Self-signed Certificate
Scopes:                openid, email, profile
```

### 3. Flutter – Dependencies
```yaml
# pubspec.yaml
flutter_appauth: ^7.0.0
flutter_secure_storage: ^9.0.0
```

### 4. Flutter – OAuth Flow
```dart
// lib/services/auth_service.dart
final appAuth = FlutterAppAuth();

Future<void> loginWithAuthentik() async {
  final result = await appAuth.authorizeAndExchangeCode(
    AuthorizationTokenRequest(
      'family-hub',                          // Client ID
      'hubstinger://auth/callback',          // Redirect URI
      issuer: 'https://auth.t-acc.com/application/o/family-hub/',
      scopes: ['openid', 'email', 'profile'],
    ),
  );
  // Speichern
  await storage.write(key: 'access_token', value: result.accessToken);
  await storage.write(key: 'id_token', value: result.idToken);
}
```

### 5. Backend – Token verifizieren
```python
# backend/main.py – OIDC verification
import httpx
from jose import jwt

AUTHENTIK_ISSUER = os.getenv("AUTHENTIK_ISSUER", "https://auth.t-acc.com/application/o/family-hub/")

async def verify_oidc_token(token: str) -> dict:
    # Fetch JWKS from Authentik
    async with httpx.AsyncClient() as client:
        r = await client.get(f"{AUTHENTIK_ISSUER}.well-known/openid-configuration")
        oidc_config = r.json()
        jwks_r = await client.get(oidc_config["jwks_uri"])
        jwks = jwks_r.json()
    # Verify token
    return jwt.decode(token, jwks, algorithms=["RS256"],
                      audience="family-hub", issuer=AUTHENTIK_ISSUER)
```

### 6. `.env` ergänzen
```bash
AUTHENTIK_ISSUER=https://auth.t-acc.com/application/o/family-hub/
AUTHENTIK_CLIENT_ID=family-hub
```
