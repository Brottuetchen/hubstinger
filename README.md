# Family Hub 🎬

Self-hosted media & homelab dashboard for iOS, iPad, and Android.

**Liquid Glass Dark UI · Widget Grid · Plugin System**

---

## Features

- 🪟 **Liquid Glass UI** – visionOS-inspired, fully custom
- 🧩 **Widget Grid** – iOS-style customizable home screen
- 📺 **Now Streaming** – live Jellyfin sessions
- 📬 **Newsletter** – auto-generated weekly via n8n + TMDB + Ollama
- 📊 **Watchtime** – family leaderboard per week
- 🔔 **Push Notifications** – via Uptime Kuma + n8n webhooks
- 📱 **iPad support** – sidebar layout auto-switches at 600px
- 🔌 **Plugin system** – Jellyfin, Jellyseerr, TMDB, n8n, Uptime Kuma

---

## Stack

| Layer | Tech |
|-------|------|
| App | Flutter 3.x |
| Backend | FastAPI (Python) |
| Automation | n8n |
| Media | Jellyfin + Jellyseerr |
| Metadata | TMDB API |
| AI Summaries | Ollama (Qwen3:14b) |
| Monitoring | Uptime Kuma |
| Push | Web Push / VAPID |

---

## Quick Start

### 1. Prerequisites

```bash
# Install Flutter
winget install Flutter.Flutter   # Windows
brew install flutter             # macOS

# Verify
flutter doctor
```

### 2. Clone & run

```bash
git clone https://github.com/YOUR_USERNAME/family-hub.git
cd family-hub
flutter pub get
flutter run
```

### 3. Configure server

In Settings → Server URL, enter your backend URL:
```
https://hub.t-acc.com
```

### 4. TMDB API Key

1. Register at [themoviedb.org](https://www.themoviedb.org/)
2. API → Settings → API Key (free)
3. Enter in Settings → TMDB API

---

## Building

### Android (Windows/Linux/Mac)

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS (Mac only or GitHub Actions)

```bash
flutter build ipa --release
```

### GitHub Actions (recommended)

Push to `main` → automatic builds for both platforms.

For TestFlight, add these secrets to your GitHub repo:
- `IOS_CERTIFICATE_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `KEYCHAIN_PASSWORD`
- `APP_STORE_KEY_ID`
- `APP_STORE_ISSUER_ID`
- `APP_STORE_API_KEY`

---

## Backend (FastAPI)

```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python create_admin.py
python main.py  # runs on :8080
```

---

## Widget System

Each widget is a self-contained Flutter widget registered in `widget_defs`:

```dart
// Adding a custom widget:
// 1. Create lib/screens/home/widgets/my_widget.dart
// 2. Register in widget_editor_sheet.dart:
'my_widget': {'label': 'My Widget', 'icon': '🔧', 'size': WidgetSize.small},
// 3. Add to switch in home_screen.dart:
'my_widget' => const MyWidget(),
```

---

## Plugin System (Backend)

```python
# backend/plugins/my_plugin.py
class MyPlugin(BasePlugin):
    name = "my_service"
    config_schema = {"url": str, "api_key": str}

    def get_stats(self) -> dict: ...
    def get_newsletter_block(self) -> NewsletterBlock: ...
```

---

## Roadmap

- [ ] v2.1 – Live TMDB posters in app
- [ ] v2.2 – Jellyfin watch history per user
- [ ] v2.5 – Sonarr/Radarr calendar widget
- [ ] v2.5 – Immich recent photos widget
- [ ] v3.0 – App Store release

---

## Credits

Built by Constantin Trapp · Self-hosted on Proxmox VE
Powered by Jellyfin, n8n, Ollama, TMDB
