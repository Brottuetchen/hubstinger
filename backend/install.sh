#!/usr/bin/env bash
# Family Hub Backend – Installer
# Run from the backend/ directory: bash install.sh
set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}  ✓${RESET} $*"; }
info() { echo -e "${CYAN}  →${RESET} $*"; }
warn() { echo -e "${YELLOW}  ⚠${RESET} $*"; }
die()  { echo -e "${RED}  ✗ ERROR:${RESET} $*" >&2; exit 1; }
header() { echo -e "\n${BOLD}${CYAN}$*${RESET}"; echo "──────────────────────────────────────────────"; }

# ─── Helpers ──────────────────────────────────────────────────────────────────
ask() {
    # ask <var_name> <prompt> [default]
    local var="$1" prompt="$2" default="${3:-}"
    local display_default=""
    [[ -n "$default" ]] && display_default=" [${default}]"
    read -rp "  ${prompt}${display_default}: " value
    value="${value:-$default}"
    printf -v "$var" '%s' "$value"
}

ask_secret() {
    # ask_secret <var_name> <prompt>
    local var="$1" prompt="$2"
    read -rsp "  ${prompt}: " value; echo
    printf -v "$var" '%s' "$value"
}

set_env() {
    # set_env KEY VALUE  – writes/replaces a KEY=VALUE line in .env
    local key="$1" value="$2"
    if grep -q "^${key}=" .env 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" .env
    else
        echo "${key}=${value}" >> .env
    fi
}

# ─── Sanity checks ────────────────────────────────────────────────────────────
header "Family Hub Backend – Installer"
echo "  This script sets up the backend from scratch."
echo "  It is safe to re-run – existing values are not overwritten."
echo ""

[[ "$(basename "$PWD")" == "backend" ]] || \
    die "Run this script from the backend/ directory:\n  cd backend && bash install.sh"

# Python version check (3.11+)
PYTHON=$(command -v python3 || command -v python || true)
[[ -n "$PYTHON" ]] || die "python3 not found. Install Python 3.11+ first."
PY_VERSION=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
(( PY_MAJOR >= 3 && PY_MINOR >= 11 )) || \
    die "Python 3.11+ required. Found Python $PY_VERSION."
ok "Python $PY_VERSION"

# openssl (for SECRET_KEY)
command -v openssl &>/dev/null || die "openssl not found – needed to generate SECRET_KEY."
ok "openssl"

# ─── Virtual environment ──────────────────────────────────────────────────────
header "1 / 5  Python environment"

if [[ -d venv ]]; then
    ok "venv already exists – skipping creation"
else
    info "Creating virtual environment …"
    "$PYTHON" -m venv venv
    ok "venv created"
fi

# Activate
# shellcheck disable=SC1091
source venv/bin/activate

info "Installing / upgrading dependencies …"
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
ok "Dependencies installed"

# ─── .env setup ───────────────────────────────────────────────────────────────
header "2 / 5  Environment file (.env)"

if [[ ! -f .env ]]; then
    cp .env.example .env
    ok ".env created from .env.example"
else
    ok ".env already exists – only missing keys will be added"
fi

# SECRET_KEY – always generate if empty
CURRENT_SK=$(grep -E "^SECRET_KEY=" .env | cut -d= -f2- || true)
if [[ -z "$CURRENT_SK" ]]; then
    NEW_SK=$(openssl rand -hex 32)
    set_env "SECRET_KEY" "$NEW_SK"
    ok "SECRET_KEY generated and saved"
else
    ok "SECRET_KEY already set"
fi

# BACKEND_URL
echo ""
warn "The backend URL is used for OIDC redirect URIs and push links."
CURRENT_BU=$(grep -E "^BACKEND_URL=" .env | cut -d= -f2- || true)
ask BACKEND_URL "Backend public URL" "${CURRENT_BU:-http://localhost:8080}"
set_env "BACKEND_URL" "$BACKEND_URL"

# CORS_ORIGINS
CURRENT_CO=$(grep -E "^CORS_ORIGINS=" .env | cut -d= -f2- || true)
ask CORS_ORIGINS "CORS origins (comma-separated, * for dev)" "${CURRENT_CO:-*}"
set_env "CORS_ORIGINS" "$CORS_ORIGINS"

ok ".env configured"

# ─── Jellyfin ─────────────────────────────────────────────────────────────────
header "3 / 5  Jellyfin (required for media widgets)"

CURRENT_JU=$(grep -E "^JELLYFIN_URL=" .env | cut -d= -f2- || true)
CURRENT_JT=$(grep -E "^JELLYFIN_TOKEN=" .env | cut -d= -f2- || true)

if [[ -n "$CURRENT_JU" && -n "$CURRENT_JT" ]]; then
    ok "Jellyfin already configured (${CURRENT_JU})"
else
    echo "  Get the token: Jellyfin → Dashboard → API Keys → +"
    ask JF_URL "Jellyfin URL" "${CURRENT_JU:-http://192.168.1.10:8096}"
    ask JF_TOKEN "Jellyfin API token" "${CURRENT_JT:-}"
    [[ -n "$JF_URL" ]]   && set_env "JELLYFIN_URL"   "$JF_URL"
    [[ -n "$JF_TOKEN" ]] && set_env "JELLYFIN_TOKEN" "$JF_TOKEN"
    [[ -n "$JF_URL" && -n "$JF_TOKEN" ]] && ok "Jellyfin configured" || warn "Skipped – media widgets will be disabled"
fi

# Optional integrations (TMDB, Ollama, VAPID e-mail)
echo ""
info "Optional: TMDB API key (free at themoviedb.org/settings/api)"
CURRENT_TM=$(grep -E "^TMDB_API_KEY=" .env | cut -d= -f2- || true)
if [[ -z "$CURRENT_TM" ]]; then
    ask TMDB_KEY "TMDB API key (leave empty to skip)" ""
    [[ -n "$TMDB_KEY" ]] && set_env "TMDB_API_KEY" "$TMDB_KEY" && ok "TMDB configured" || warn "Skipped"
else
    ok "TMDB already configured"
fi

info "Optional: Ollama URL (for AI summaries in newsletter)"
CURRENT_OL=$(grep -E "^OLLAMA_URL=" .env | cut -d= -f2- || true)
if [[ -z "$CURRENT_OL" ]]; then
    ask OL_URL "Ollama URL (leave empty to skip)" ""
    [[ -n "$OL_URL" ]] && set_env "OLLAMA_URL" "$OL_URL" && ok "Ollama configured" || warn "Skipped"
else
    ok "Ollama already configured (${CURRENT_OL})"
fi

info "Optional: VAPID contact e-mail (required for Web Push notifications)"
CURRENT_VE=$(grep -E "^VAPID_EMAIL=" .env | cut -d= -f2- || true)
if [[ -z "$CURRENT_VE" ]]; then
    ask VAPID_EMAIL "Contact e-mail for VAPID (leave empty to skip)" ""
    [[ -n "$VAPID_EMAIL" ]] && set_env "VAPID_EMAIL" "$VAPID_EMAIL" && ok "VAPID e-mail set" || warn "Skipped – push notifications disabled"
else
    ok "VAPID e-mail already set"
fi

# ─── Admin user ───────────────────────────────────────────────────────────────
header "4 / 5  Admin user"

DB_FILE="familyhub.db"
if [[ -f "$DB_FILE" ]]; then
    ok "Database already exists – skipping admin creation"
    info "To add another admin: python create_admin.py"
else
    info "Creating admin account …"
    python create_admin.py
fi

# ─── VAPID keys ───────────────────────────────────────────────────────────────
header "5 / 5  VAPID keys (Web Push)"

VAPID_FILE="vapid_keys.json"
CURRENT_VPK=$(grep -E "^VAPID_PRIVATE_KEY=" .env | cut -d= -f2- || true)

if [[ -f "$VAPID_FILE" || -n "$CURRENT_VPK" ]]; then
    ok "VAPID keys already present"
else
    info "Generating VAPID keys …"
    python -c "
import json, base64
from py_vapid import Vapid
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

v = Vapid()
v.generate_keys()

private_pem = v.private_pem().decode()
pub_bytes   = v.public_key.public_bytes(Encoding.X962, PublicFormat.UncompressedPoint)
public_b64  = base64.urlsafe_b64encode(pub_bytes).rstrip(b'=').decode()

with open('vapid_keys.json', 'w') as f:
    json.dump({'private_key': private_pem, 'public_key': public_b64}, f, indent=2)
print('  Keys saved to vapid_keys.json')
"
    ok "VAPID keys generated (vapid_keys.json)"
fi

# ─── systemd service (optional) ───────────────────────────────────────────────
echo ""
read -rp "  Install as systemd service? [y/N] " SYSTEMD_CHOICE
if [[ "${SYSTEMD_CHOICE,,}" == "y" ]]; then
    SERVICE_NAME="familyhub"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    WORK_DIR="$(pwd)"
    VENV_BIN="${WORK_DIR}/venv/bin"
    CURRENT_USER="$(whoami)"

    # Use sudo only when not already root
    _sudo() { [[ "$(id -u)" == "0" ]] && "$@" || sudo "$@"; }

    _sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Family Hub Backend
After=network.target

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${WORK_DIR}
EnvironmentFile=${WORK_DIR}/.env
ExecStart=${VENV_BIN}/python main.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    _sudo systemctl daemon-reload
    _sudo systemctl enable --now "$SERVICE_NAME"
    ok "Service installed and started: systemctl status ${SERVICE_NAME}"
else
    info "Skipped systemd setup"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${GREEN}  ✓  Family Hub Backend ready!${RESET}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  Start:        ${CYAN}source venv/bin/activate && python main.py${RESET}"
echo -e "  Admin panel:  ${CYAN}${BACKEND_URL}/admin${RESET}"
echo -e "  Plugins:      configure in Admin panel (Sonarr, Radarr, Immich, …)"
echo ""
echo -e "  Next steps:"
echo -e "   • Set JELLYFIN_TOKEN in .env if not done (Jellyfin → API Keys → +)"
echo -e "   • Point Cloudflare Tunnel or NPM to port 8080 for HTTPS"
echo -e "   • Run: ${CYAN}flutter create --org com.yourname --project-name family_hub ../${RESET}"
echo -e "   • Then: ${CYAN}cd .. && flutter pub get && flutter run${RESET}"
echo ""
