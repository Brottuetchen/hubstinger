# Family Hub

Self-hosted media & homelab dashboard for iOS, iPad, and Android.

**Liquid Glass Dark UI · Widget Grid · Plugin System**

---

## Features

- 🪟 **Liquid Glass UI** – visionOS-inspired, fully custom
- 🧩 **Widget Grid** – iOS-style customizable home screen, persisted locally
- 📺 **Now Streaming** – live Jellyfin sessions
- 📬 **Newsletter** – auto-generated weekly via n8n + TMDB + Ollama
- 📊 **Watchtime** – per-user leaderboard from Jellyfin
- 🔔 **Push Notifications** – Web Push via VAPID (Uptime Kuma / n8n)
- 📱 **iPad support** – sidebar layout at ≥600px
- 🔐 **Auth** – JWT login, secure token storage

---

## Stack

| Layer | Tech |
|-------|------|
| App | Flutter 3.x (Dart) |
| State | Riverpod |
| Backend | FastAPI (Python 3.11+) |
| DB | SQLite (via SQLAlchemy) |
| Automation | n8n |
| Media | Jellyfin + Jellyseerr |
| Metadata | TMDB API |
| AI Summaries | Ollama |
| Monitoring | Uptime Kuma |
| Push | Web Push / VAPID |

---

## Setup

### 1. Backend

```bash
cd backend

# Create virtual environment
python3 -m venv venv && source venv/bin/activate  # Linux/Mac
# OR: python -m venv venv && venv\Scripts\activate   # Windows

# Install dependencies
pip install -r requirements.txt

# Configure
cp .env.example .env
nano .env          # Fill in all required values (see comments in .env.example)

# Generate SECRET_KEY
openssl rand -hex 32   # Paste output into .env as SECRET_KEY

# Create admin user (interactive)
python create_admin.py

# Start server
python main.py         # Runs on port 8080 by default
```

### 2. Flutter App

```bash
# Install Flutter: https://flutter.dev/docs/get-started/install
flutter pub get
flutter run            # needs connected device or emulator
```

On first launch, the app shows a **Server URL** field — enter the URL of your backend (e.g. `http://192.168.1.10:8080` or `https://your-domain.com`).

### 3. Required services

| Service | Purpose | Required |
|---------|---------|----------|
| FastAPI backend | API, auth, push | ✅ |
| Jellyfin | Media server | ✅ for streaming/recently widgets |
| TMDB API key | Movie metadata & posters | ✅ for newsletter |
| Ollama | German AI summaries | optional |
| Jellyseerr | Media requests | optional |
| Uptime Kuma | Service monitoring | optional |
| n8n | Weekly newsletter automation | optional |

### 4. VAPID Push Notifications

```bash
cd backend

# Generate VAPID keys (one time)
python -c "
from pywebpush import Vapid
import json, pathlib
v = Vapid()
v.generate_keys()
data = {'private_key': v.private_key.decode(), 'public_key': v.public_key.decode()}
pathlib.Path('vapid_keys.json').write_text(json.dumps(data, indent=2))
print('Saved to vapid_keys.json')
"
```

Or set `VAPID_PRIVATE_KEY` / `VAPID_PUBLIC_KEY` directly in `.env`.

### 5. n8n Newsletter Workflow

1. In n8n: create a new workflow
2. Trigger: **Cron** → Friday 17:00 (`0 17 * * 5`)
3. Node: **HTTP Request** → `POST https://your-backend.com/api/newsletter/generate`
4. Activate workflow

---

## Building

### Android

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS (requires macOS + Xcode)

```bash
flutter build ipa --release
```

### GitHub Actions (CI/CD)

Push to `main` → automatic builds for both platforms.

For TestFlight / App Store, add these secrets to your GitHub repo:
- `IOS_CERTIFICATE_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `KEYCHAIN_PASSWORD`
- `APP_STORE_KEY_ID`
- `APP_STORE_ISSUER_ID`
- `APP_STORE_API_KEY`

---

## Widget System

Each widget is a self-contained `ConsumerWidget`. Layout persists via SharedPreferences.

```dart
// Adding a custom widget:
// 1. Create lib/screens/home/widgets/my_widget.dart
// 2. Register in widget_editor_sheet.dart:
'my_widget': {'label': 'My Widget', 'icon': '🔧', 'size': WidgetSize.small},
// 3. Add to switch in home_screen.dart:
'my_widget' => const MyWidget(),
```

---

## Backend Plugin System

```python
# backend/plugins/my_plugin.py
# Add custom data sources for the newsletter or stats API
```

---

## Roadmap

- [ ] v2.1 – TMDB poster images in app (cached_network_image)
- [ ] v2.2 – Jellyfin watch history per user
- [ ] v2.3 – Auto token refresh
- [ ] v2.5 – Sonarr/Radarr calendar widget
- [ ] v2.5 – Immich recent photos widget
- [ ] v3.0 – App Store release

---

## License

MIT
