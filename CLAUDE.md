# Family Hub - Claude Code Context

This file tells Claude Code everything it needs to know about this project.
It is automatically read by Claude Code in VS Code.

---

## Project Overview

Family Hub is a self-hosted media & homelab dashboard app.
- **Flutter app** (iOS, iPad, Android) with Liquid Glass dark UI
- **FastAPI backend** (Python) running on LXC at `<backend-ip>:8080`
- **n8n automation** for weekly newsletter generation
- **Cloudflare Tunnel** for HTTPS → `<your-domain>`

---

## Architecture

```
Flutter App (iOS/iPad/Android)
    ↕ HTTPS
Cloudflare Tunnel (<your-domain>)
    ↕
FastAPI Backend (:8080) on LXC <backend-ip>
    ├── Jellyfin     (<homelab-ip>:8096)
    ├── Jellyseerr   (<homelab-ip>:5055)
    ├── TMDB API     (external)
    ├── Ollama       (<ollama-ip>:11434)
    └── Uptime Kuma  (<homelab-ip>:3001)

n8n (<homelab-ip>:5678)
    └── Weekly cron → POST /api/newsletter/generate
```

---

## Stack

| Component | Technology |
|-----------|-----------|
| App | Flutter 3.x (Dart) |
| State | flutter_riverpod |
| Animations | flutter_animate |
| HTTP | http |
| Deep Links | app_links |
| Backend | FastAPI + SQLAlchemy + SQLite |
| Auth | JWT (python-jose) + bcrypt + Authentik OIDC |
| Push | Web Push / VAPID (pywebpush) |
| Images | TMDB API (https://image.tmdb.org/t/p/w342{path}) |

---

## Key Files

```
family_hub/
├── lib/
│   ├── main.dart                          ← App entry, tab bar, deep links, auth gate
│   ├── core/constants/colors.dart         ← ALL design tokens (edit here)
│   ├── core/theme/app_theme.dart          ← MaterialApp theme
│   ├── models/models.dart                 ← All data models
│   ├── providers/providers.dart           ← Riverpod providers + AuthNotifier
│   ├── services/
│   │   ├── api_service.dart               ← All API calls
│   │   ├── auth_service.dart              ← Token storage + JWT expiry decoder
│   │   └── push_service.dart              ← Push notification stub
│   ├── widgets/glass/glass_card.dart      ← Liquid Glass component system
│   └── screens/
│       ├── home/home_screen.dart          ← Widget grid + iOS edit mode + iPad sidebar
│       ├── home/widgets/                  ← All home widgets (stat, streaming, recently, …)
│       ├── services/services_screen.dart  ← Service grid
│       ├── newsletter/newsletter_screen.dart
│       └── settings/settings_screen.dart
└── backend/
    ├── main.py                            ← FastAPI app + all endpoints
    ├── install.sh                         ← One-command setup script
    ├── create_admin.py                    ← Run once to create admin user
    ├── .env.example                       ← Copy to .env and fill in
    ├── base_plugin.py                     ← BasePlugin ABC
    ├── plugin_registry.py                 ← Auto-discovery + DB persistence
    └── plugins/                           ← 13 built-in plugins
```

---

## Design System - Liquid Glass

The entire UI uses a custom Liquid Glass system (`glass_card.dart`):

```dart
// Three weight levels:
GlassCard(weight: GlassWeight.thin,  ...)  // subtle, for chips/pills
GlassCard(weight: GlassWeight.mid,   ...)  // standard cards
GlassCard(weight: GlassWeight.thick, ...)  // hero panels, tab bar

// With color rim (refraction line at top):
GlassCard(rimColor: AppColors.violet.withOpacity(0.5), ...)

// With tint:
GlassCard(tint: AppColors.violet.withOpacity(0.18), ...)
```

**Color palette** (all in `colors.dart`):
- Primary: `violet #7C3AED`, `cyan #00B4D8`
- Accent: `green #10B981`, `amber #F59E0B`, `rose #EC4899`
- Background: `#02030C` with animated radial gradient orbs

---

## Widget System

Home screen has iOS-style editable widget grid.

**Adding a new widget:**
1. Create widget in `lib/screens/home/widgets/`
2. Register in `widget_editor_sheet.dart`:
```dart
'my_widget': {'label': 'My Widget', 'icon': '🔧', 'size': WidgetSize.small},
```
3. Add to switch in `home_screen.dart`:
```dart
'my_widget' => const MyWidget(),
```

**Widget sizes:**
- `small` → 1/2 width, ~120px tall
- `medium` → full width, ~180px tall
- `large` → full width, flexible
- `tall` → 1/2 width, spans 2 rows (for newsletter widget)

**Live stat widgets** read from `/api/stats` via `LiveStatWidget(statsKey: 'key_name', ...)`.
Plugin stats are aggregated in parallel via `asyncio.gather` in `main.py`.

---

## Backend API

Base URL: `https://<your-domain>` (or `http://<backend-ip>:8080` locally)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/token` | Login → JWT |
| POST | `/api/auth/refresh` | Renew JWT (auth required) |
| GET | `/api/auth/me` | Current user |
| GET | `/api/auth/oidc-url` | Authentik login URL |
| GET | `/api/auth/oidc/callback` | OIDC code exchange |
| GET | `/api/vapid-public-key` | Push key |
| POST | `/api/push/subscribe` | Register push |
| POST | `/api/push/notify` | Send push (admin) |
| GET | `/api/jellyfin/sessions` | Active streams |
| GET | `/api/jellyfin/recently-added` | New media |
| GET | `/api/jellyfin/image/{id}` | Image proxy |
| POST | `/api/ollama/summarize` | AI summary |
| POST | `/api/newsletter/generate` | Build newsletter |
| GET | `/api/newsletter/archive` | Past newsletters |
| GET | `/api/stats` | Dashboard stats (all plugins) |
| POST | `/api/webhook/uptime-kuma` | Alert webhook |
| GET | `/admin` | Plugin admin panel |
| GET/PUT | `/api/plugins/{name}/...` | Plugin CRUD (admin) |

---

## Plugin System

**Adding a new plugin:** create `backend/plugins/my_plugin.py` extending `BasePlugin`.
Auto-discovered at startup via `pkgutil.iter_modules`. Config stored in SQLite.

**Built-in plugins (13):** Sonarr, Radarr, Proxmox, Jellyseerr, Uptime Kuma, Immich,
Navidrome, Nextcloud, n8n, Gitea, Portainer, Paperless-ngx, Audiobookshelf.

---

## n8n Newsletter Workflow

**Trigger:** Every Friday 17:00 (cron)
**Steps:**
1. HTTP Request → `POST https://<your-domain>/api/newsletter/generate`
2. Backend fetches Jellyfin new media
3. Enriches with TMDB metadata
4. Generates German summaries via Ollama
5. Renders HTML newsletter
6. Saves to `/newsletters/kw{N}-{year}.json`
7. Sends push notification to all subscribers

---

## Cloudflare Setup

Backend is exposed via Cloudflare Tunnel:
```yaml
# ~/.cloudflared/config.yml on cloudflared LXC
ingress:
  - hostname: <your-domain>
    service: http://<backend-ip>:8080
  - service: http_status:404
```

---

## Local Development

**Backend:**
```bash
cd backend
bash install.sh    # first time (interactive setup)
# or manually:
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in your values
python create_admin.py
python main.py         # runs on :8080
```

**Flutter:**
```bash
# Einmalig nach Clone:
flutter create --org com.yourname --project-name family_hub .
flutter pub get
flutter run            # needs device/emulator
flutter run -d chrome  # web preview
```

**Build:**
```bash
flutter build apk --release         # Android
flutter build ipa --no-codesign     # iOS (Mac/CI only)
```

---

## Common Tasks for Claude Code

### "Add a new widget"
→ Create in `lib/screens/home/widgets/`, register in `widget_editor_sheet.dart` and `home_screen.dart`

### "Add a new API endpoint"
→ Add to `backend/main.py`, follow the existing pattern (Pydantic model + async def)

### "Change colors"
→ Edit `lib/core/constants/colors.dart`

### "Add a new service to the services screen"
→ Add entry to `_services` list in `lib/screens/services/services_screen.dart`

### "Fix push notifications not working"
→ Check VAPID keys in `backend/vapid_keys.json`, verify CF Tunnel is running, check browser console

### "Newsletter not generating"
→ Check n8n workflow, verify `/api/newsletter/generate` returns 200, check Ollama is running at OLLAMA_URL

### "Token expired / auth loop"
→ `POST /api/auth/refresh` renews token. Flutter auto-refreshes on app resume if < 2 days left.

---

## Infrastructure

Configure your actual IPs/ports in `backend/.env` (gitignored).
The table below shows the expected services – fill in your values:

| Service | Env Var | Default Port |
|---------|---------|:------------:|
| Family Hub Backend | `BACKEND_URL` | 8080 |
| Jellyfin | `JELLYFIN_URL` | 8096 |
| Jellyseerr | Plugin config | 5055 |
| n8n | Plugin config | 5678 |
| Ollama | `OLLAMA_URL` | 11434 |
| Proxmox | Plugin config | 8006 |
| Authentik | `AUTHENTIK_URL` | 9000 |
