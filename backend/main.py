"""
Family Hub Backend - FastAPI
Endpoints: Auth, Push Notifications, Stats, Newsletter
"""

import os
import sys
import json
import logging
import asyncio
import secrets
from datetime import datetime, timedelta
from pathlib import Path
from contextlib import asynccontextmanager
from typing import Any, Optional
from urllib.parse import urlencode

import httpx
import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends, status, Request

load_dotenv()  # Load .env from backend/ directory before reading os.getenv()
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response as StarletteResponse
from pywebpush import webpush, WebPushException
from jose import JWTError, jwt
import bcrypt as _bcrypt
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from sqlalchemy import create_engine, Column, String, Boolean, DateTime, Float, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel

# ─── Config ───────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

BASE_DIR   = Path(__file__).parent
PUBLIC_DIR = BASE_DIR.parent / "public"

# JWT
_SECRET_KEY_DEFAULT = "CHANGE_ME_IN_PRODUCTION_use_openssl_rand_hex_32"
SECRET_KEY          = os.getenv("SECRET_KEY", _SECRET_KEY_DEFAULT)
ALGORITHM           = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days

# VAPID (Web Push)
VAPID_PRIVATE_KEY = os.getenv("VAPID_PRIVATE_KEY", "")
VAPID_PUBLIC_KEY  = os.getenv("VAPID_PUBLIC_KEY", "")
VAPID_EMAIL       = os.getenv("VAPID_EMAIL", "")

# CORS – comma-separated list of allowed origins; * only for dev
_cors_raw    = os.getenv("CORS_ORIGINS", "")
CORS_ORIGINS = [o.strip() for o in _cors_raw.split(",") if o.strip()] or ["*"]

# Public backend URL (needed for OIDC redirect_uri)
BACKEND_URL  = os.getenv("BACKEND_URL", "http://localhost:8080")

# Authentik OIDC
AUTHENTIK_URL           = os.getenv("AUTHENTIK_URL", "")           # e.g. https://auth.example.com
AUTHENTIK_CLIENT_ID     = os.getenv("AUTHENTIK_CLIENT_ID", "")
AUTHENTIK_CLIENT_SECRET = os.getenv("AUTHENTIK_CLIENT_SECRET", "")

# External services
JELLYFIN_URL    = os.getenv("JELLYFIN_URL", "")
JELLYFIN_TOKEN  = os.getenv("JELLYFIN_TOKEN", "")
JELLYSEERR_URL  = os.getenv("JELLYSEERR_URL", "")
JELLYSEERR_KEY  = os.getenv("JELLYSEERR_API_KEY", "")
TMDB_API_KEY    = os.getenv("TMDB_API_KEY", "")
OLLAMA_URL      = os.getenv("OLLAMA_URL", "")
OLLAMA_MODEL    = os.getenv("OLLAMA_MODEL", "llama3.2")
UPTIME_KUMA_URL = os.getenv("UPTIME_KUMA_URL", "")

# In-memory OIDC state store {state: {"created": datetime, "nonce": str}}
# Single-instance only – fine for self-hosted
_oidc_states: dict[str, dict] = {}

# Load VAPID from file if not in env
_vapid_file = BASE_DIR / "vapid_keys.json"
if _vapid_file.exists() and not VAPID_PRIVATE_KEY:
    with open(_vapid_file) as f:
        _vk = json.load(f)
        VAPID_PRIVATE_KEY = _vk.get("private_key", "")
        VAPID_PUBLIC_KEY  = _vk.get("public_key", "")

# ─── Database ─────────────────────────────────────────────────────────────────
DATABASE_URL = f"sqlite:///{BASE_DIR}/familyhub.db"
engine       = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base         = declarative_base()

class UserModel(Base):
    __tablename__ = "users"
    username   = Column(String, primary_key=True, index=True)
    email      = Column(String, unique=True, index=True)
    full_name  = Column(String)
    hashed_pw  = Column(String)
    is_admin   = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class PushSubModel(Base):
    __tablename__ = "push_subscriptions"
    endpoint   = Column(String, primary_key=True)
    auth       = Column(String)
    p256dh     = Column(String)
    username   = Column(String, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class FcmTokenModel(Base):
    __tablename__ = "fcm_tokens"
    token      = Column(String, primary_key=True)
    username   = Column(String, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class PluginConfigModel(Base):
    __tablename__ = "plugin_configs"
    name        = Column(String, primary_key=True, index=True)
    enabled     = Column(Boolean, default=False)
    config_json = Column(Text, default="{}")
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class CoreConfigModel(Base):
    __tablename__ = "core_configs"
    name        = Column(String, primary_key=True, index=True)
    enabled     = Column(Boolean, default=False)
    config_json = Column(Text, default="{}")
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class DashboardLayoutModel(Base):
    __tablename__ = "dashboard_layouts"
    username    = Column(String, primary_key=True, index=True)
    layout_json = Column(Text, default="[]")
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ─── Auth ─────────────────────────────────────────────────────────────────────
oauth2 = OAuth2PasswordBearer(tokenUrl="api/auth/token")

def verify_password(plain: str, hashed: str) -> bool:
    try:
        return _bcrypt.checkpw(plain.encode(), hashed.encode())
    except Exception:
        return False  # OIDC users have no bcrypt hash

def hash_password(password: str) -> str:
    return _bcrypt.hashpw(password.encode(), _bcrypt.gensalt()).decode()

def create_token(data: dict) -> str:
    payload = data.copy()
    payload["exp"] = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def get_current_user(token: str = Depends(oauth2), db: Session = Depends(get_db)) -> UserModel:
    try:
        payload  = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = db.query(UserModel).filter(UserModel.username == username).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user

def require_admin(user: UserModel = Depends(get_current_user)) -> UserModel:
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Admin required")
    return user

# ─── Pydantic schemas ─────────────────────────────────────────────────────────
class Token(BaseModel):
    access_token: str
    token_type: str

class PushSubscription(BaseModel):
    endpoint: str
    keys: dict  # {auth, p256dh}

class PushPayload(BaseModel):
    title: str
    body: str
    url: str = "/"
    icon: str = "/assets/icons/app-icon-192.png"
    badge: str = "/assets/icons/app-icon-192.png"

class UserCreate(BaseModel):
    username: str
    email: str
    full_name: Optional[str] = None
    password: str

class PluginToggleBody(BaseModel):
    enabled: bool

class PluginConfigBody(BaseModel):
    config: dict

class DashboardLayoutBody(BaseModel):
    slots: list[dict]

# ─── Plugin Registry ──────────────────────────────────────────────────────────
from plugin_registry import registry as plugin_registry

PLUGIN_SERVICE_META = {
    "audiobookshelf": {"category": "Media", "icon_key": "audiobookshelf"},
    "gitea": {"category": "Dev", "icon_key": "gitea"},
    "immich": {"category": "Media", "icon_key": "immich"},
    "jellyseerr": {"category": "Media", "icon_key": "jellyseerr"},
    "n8n": {"category": "Tools", "icon_key": "n8n"},
    "navidrome": {"category": "Media", "icon_key": "navidrome"},
    "nextcloud": {"category": "Storage", "icon_key": "nextcloud"},
    "paperless": {"category": "Tools", "icon_key": "paperless"},
    "portainer": {"category": "Infra", "icon_key": "portainer"},
    "proxmox": {"category": "Infra", "icon_key": "proxmox"},
    "radarr": {"category": "Media", "icon_key": "radarr"},
    "sonarr": {"category": "Media", "icon_key": "sonarr"},
    "uptime_kuma": {"category": "Monitor", "icon_key": "uptime_kuma"},
}

_MASK = "••••••••"

CORE_INTEGRATIONS = [
    {
        "name": "jellyfin",
        "label": "Jellyfin",
        "description": "Core media source for streams, recent items and watchtime",
        "category": "Media",
        "icon_key": "jellyfin",
        "show_in_app": True,
        "config_schema": {
            "url": {
                "type": "url",
                "label": "Jellyfin URL",
                "required": True,
                "placeholder": "http://192.168.1.10:8096",
            },
            "token": {
                "type": "password",
                "label": "API Token",
                "required": True,
                "secret": True,
                "placeholder": "abc123...",
            },
        },
    },
    {
        "name": "tmdb",
        "label": "TMDB",
        "description": "Metadata and posters for newsletters and media enrichment",
        "category": "Media",
        "icon_key": "tmdb",
        "show_in_app": True,
        "config_schema": {
            "api_key": {
                "type": "password",
                "label": "TMDB API Key",
                "required": True,
                "secret": True,
                "placeholder": "tmdb_...",
            },
        },
    },
    {
        "name": "ollama",
        "label": "Ollama",
        "description": "Local AI summaries for the newsletter pipeline",
        "category": "Tools",
        "icon_key": "ollama",
        "show_in_app": True,
        "config_schema": {
            "url": {
                "type": "url",
                "label": "Ollama URL",
                "required": True,
                "placeholder": "http://192.168.1.10:11434",
            },
            "model": {
                "type": "text",
                "label": "Model",
                "required": True,
                "placeholder": "llama3.2",
            },
        },
    },
    {
        "name": "authentik",
        "label": "Authentik",
        "description": "OIDC login provider for Family Hub",
        "category": "Security",
        "icon_key": "authentik",
        "show_in_app": True,
        "config_schema": {
            "url": {
                "type": "url",
                "label": "Authentik URL",
                "required": True,
                "placeholder": "https://auth.example.com",
            },
            "client_id": {
                "type": "text",
                "label": "Client ID",
                "required": True,
                "placeholder": "family-hub",
            },
            "client_secret": {
                "type": "password",
                "label": "Client Secret",
                "required": True,
                "secret": True,
                "placeholder": "secret",
            },
            "backend_url": {
                "type": "url",
                "label": "Backend URL",
                "required": True,
                "placeholder": "https://hub.example.com",
                "hint": "Wird fuer die OIDC Redirect-URL verwendet.",
            },
        },
    },
    {
        "name": "vapid",
        "label": "Web Push / VAPID",
        "description": "Browser Push fuer Benachrichtigungen und Newsletter-Hinweise",
        "category": "Notifications",
        "icon_key": "notification",
        "show_in_app": False,
        "config_schema": {
            "public_key": {
                "type": "text",
                "label": "Public Key",
                "required": True,
                "placeholder": "BL0...",
            },
            "private_key": {
                "type": "password",
                "label": "Private Key",
                "required": True,
                "secret": True,
                "placeholder": "7jW...",
            },
            "email": {
                "type": "text",
                "label": "Kontakt E-Mail",
                "required": True,
                "placeholder": "mailto:admin@example.com",
            },
        },
    },
]

WIDGET_CATALOG = [
    {"id": "streaming", "label": "Jetzt gestreamt", "icon_key": "streaming", "default_size": "large", "requires_core": "jellyfin"},
    {"id": "newsletter", "label": "Newsletter", "icon_key": "newsletter", "default_size": "tall"},
    {"id": "recently", "label": "Neu in Jellyfin", "icon_key": "movie", "default_size": "large", "requires_core": "jellyfin"},
    {"id": "watchtime", "label": "Watchtime", "icon_key": "watchtime", "default_size": "large", "requires_core": "jellyfin"},
    {"id": "containers", "label": "Container", "icon_key": "portainer", "default_size": "small", "requires_plugin": "portainer"},
    {"id": "streams_count", "label": "Aktive Streams", "icon_key": "active_streams", "default_size": "small", "requires_core": "jellyfin"},
    {"id": "uptime", "label": "Uptime Kuma", "icon_key": "uptime_kuma", "default_size": "small", "requires_plugin": "uptime_kuma"},
    {"id": "nas", "label": "NAS Speicher", "icon_key": "nextcloud", "default_size": "small", "requires_plugin": "nextcloud"},
    {"id": "proxmox", "label": "Proxmox CPU", "icon_key": "proxmox", "default_size": "small", "requires_plugin": "proxmox"},
    {"id": "requests", "label": "Jellyseerr", "icon_key": "jellyseerr", "default_size": "small", "requires_plugin": "jellyseerr"},
    {"id": "sonarr", "label": "Sonarr Upcoming", "icon_key": "sonarr", "default_size": "small", "requires_plugin": "sonarr"},
    {"id": "radarr", "label": "Radarr Missing", "icon_key": "radarr", "default_size": "small", "requires_plugin": "radarr"},
    {"id": "immich", "label": "Immich Fotos", "icon_key": "immich", "default_size": "small", "requires_plugin": "immich"},
    {"id": "navidrome", "label": "Navidrome", "icon_key": "navidrome", "default_size": "small", "requires_plugin": "navidrome"},
]

DEFAULT_WIDGET_ORDER = [
    "streaming",
    "newsletter",
    "containers",
    "streams_count",
    "recently",
    "watchtime",
    "uptime",
    "nas",
]

VALID_WIDGET_SIZES = {"small", "medium", "large", "tall"}

# ─── Templates ────────────────────────────────────────────────────────────────
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))

def _core_defaults() -> dict[str, dict[str, Any]]:
    return {
        "jellyfin": {
            "url": JELLYFIN_URL,
            "token": JELLYFIN_TOKEN,
        },
        "tmdb": {
            "api_key": TMDB_API_KEY,
        },
        "ollama": {
            "url": OLLAMA_URL,
            "model": OLLAMA_MODEL or "llama3.2",
        },
        "authentik": {
            "url": AUTHENTIK_URL,
            "client_id": AUTHENTIK_CLIENT_ID,
            "client_secret": AUTHENTIK_CLIENT_SECRET,
            "backend_url": BACKEND_URL,
        },
        "vapid": {
            "public_key": VAPID_PUBLIC_KEY,
            "private_key": VAPID_PRIVATE_KEY,
            "email": VAPID_EMAIL,
        },
    }

def _core_meta(name: str) -> dict[str, Any]:
    for item in CORE_INTEGRATIONS:
        if item["name"] == name:
            return item
    raise KeyError(name)

def _core_schema(name: str) -> dict[str, Any]:
    return _core_meta(name).get("config_schema", {})

def _mask_config(cfg: dict[str, Any], schema: dict[str, Any]) -> dict[str, Any]:
    masked = {}
    for key, value in cfg.items():
        if schema.get(key, {}).get("secret") and value:
            masked[key] = _MASK
        else:
            masked[key] = value
    return masked

def _merge_config(existing: dict[str, Any], incoming: dict[str, Any], schema: dict[str, Any]) -> dict[str, Any]:
    merged = dict(existing)
    for key, value in incoming.items():
        if schema.get(key, {}).get("secret") and value == _MASK:
            continue
        merged[key] = value
    return merged

def _is_configured(cfg: dict[str, Any], schema: dict[str, Any]) -> bool:
    for field, field_schema in schema.items():
        if field_schema.get("required") and not cfg.get(field):
            return False
    return bool(cfg) or not schema

def _get_core_record(db: Session, name: str) -> CoreConfigModel | None:
    return db.query(CoreConfigModel).filter(CoreConfigModel.name == name).first()

def _core_config(db: Session, name: str) -> dict[str, Any]:
    config = dict(_core_defaults().get(name, {}))
    record = _get_core_record(db, name)
    if record and record.config_json:
        try:
            config.update(json.loads(record.config_json))
        except json.JSONDecodeError:
            logger.warning("Invalid core config JSON for %s", name)
    return config

def _core_enabled(db: Session, name: str) -> bool:
    record = _get_core_record(db, name)
    if record is not None:
        return bool(record.enabled)
    return _is_configured(_core_config(db, name), _core_schema(name))

def _core_value(db: Session, name: str, key: str, default: Any = "") -> Any:
    return _core_config(db, name).get(key, default)

def _serialize_core_integration(db: Session, name: str) -> dict[str, Any]:
    meta = _core_meta(name)
    config = _core_config(db, name)
    configured = _is_configured(config, meta["config_schema"])
    enabled = _core_enabled(db, name)
    return {
        "name": meta["name"],
        "label": meta["label"],
        "description": meta["description"],
        "category": meta["category"],
        "icon_key": meta["icon_key"],
        "enabled": enabled,
        "configured": configured,
        "online": enabled and configured,
        "config_schema": meta["config_schema"],
        "config": _mask_config(config, meta["config_schema"]),
        "source": "core",
        "version": "core",
        "show_in_app": meta.get("show_in_app", True),
    }

def _list_core_integrations(db: Session) -> list[dict[str, Any]]:
    return [_serialize_core_integration(db, item["name"]) for item in CORE_INTEGRATIONS]

def _save_core_config(db: Session, name: str, config: dict[str, Any]) -> dict[str, Any]:
    _core_meta(name)
    record = _get_core_record(db, name)
    created = record is None
    existing = _core_config(db, name)
    merged = _merge_config(existing, config, _core_schema(name))
    if record is None:
        record = CoreConfigModel(name=name, enabled=False, config_json="{}")
        db.add(record)
    record.config_json = json.dumps(merged)
    if created and _is_configured(merged, _core_schema(name)):
        record.enabled = True
    db.commit()
    db.refresh(record)
    return _serialize_core_integration(db, name)

def _set_core_enabled(db: Session, name: str, enabled: bool) -> dict[str, Any]:
    _core_meta(name)
    record = _get_core_record(db, name)
    if record is None:
        record = CoreConfigModel(name=name, enabled=enabled, config_json="{}")
        db.add(record)
    else:
        record.enabled = enabled
    db.commit()
    db.refresh(record)
    return _serialize_core_integration(db, name)

def _plugin_config_value(db: Session, name: str, key: str, default: Any = "") -> Any:
    record = db.query(PluginConfigModel).filter(PluginConfigModel.name == name).first()
    if not record or not record.config_json:
        return default
    try:
        return json.loads(record.config_json).get(key, default)
    except json.JSONDecodeError:
        return default

async def _test_core_integration(db: Session, name: str) -> dict[str, Any]:
    config = _core_config(db, name)
    schema = _core_schema(name)
    if not _is_configured(config, schema):
        return {"ok": False, "message": "Pflichtfelder fehlen"}

    try:
        if name == "jellyfin":
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(
                    f"{config['url']}/System/Info/Public",
                    headers={"X-Emby-Token": config["token"]},
                )
                if response.status_code != 200:
                    return {"ok": False, "message": f"HTTP {response.status_code}"}
                data = response.json()
                return {"ok": True, "message": data.get("ServerName", "Verbunden")}

        if name == "tmdb":
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(
                    "https://api.themoviedb.org/3/configuration",
                    params={"api_key": config["api_key"]},
                )
                if response.status_code != 200:
                    return {"ok": False, "message": f"HTTP {response.status_code}"}
                return {"ok": True, "message": "TMDB API erreichbar"}

        if name == "ollama":
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(f"{config['url']}/api/tags")
                if response.status_code != 200:
                    return {"ok": False, "message": f"HTTP {response.status_code}"}
                return {"ok": True, "message": f"Model {config.get('model', 'gesetzt')}"}

        if name == "authentik":
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(
                    f"{config['url']}/application/o/.well-known/openid-configuration"
                )
                if response.status_code != 200:
                    return {"ok": False, "message": f"HTTP {response.status_code}"}
                return {"ok": True, "message": "OIDC Discovery erfolgreich"}

        if name == "vapid":
            return {"ok": True, "message": "VAPID Keys sind hinterlegt"}
    except Exception as exc:
        return {"ok": False, "message": str(exc)}

    return {"ok": False, "message": "Kein Test verfuegbar"}

def _core_integration_status(db: Session) -> dict[str, bool]:
    status = {}
    for core in CORE_INTEGRATIONS:
        if not core.get("show_in_app", True):
            continue
        serialized = _serialize_core_integration(db, core["name"])
        status[core["name"]] = bool(serialized["enabled"] and serialized["configured"])
    return status

def _plugin_records_by_name(db: Session) -> dict[str, dict]:
    records: dict[str, dict] = {}
    for plugin in plugin_registry.list_all(db):
        records[plugin["name"]] = plugin
    return records

def _plugin_serialized(db: Session, name: str) -> dict[str, Any]:
    for plugin in plugin_registry.list_all(db):
        if plugin["name"] == name:
            return plugin
    raise KeyError(name)

def _build_service_catalog(db: Session) -> list[dict]:
    core_status = _core_integration_status(db)
    services = []

    for core in CORE_INTEGRATIONS:
        if not core.get("show_in_app", True):
            continue
        serialized = _serialize_core_integration(db, core["name"])
        services.append({
            "name": serialized["name"],
            "label": serialized["label"],
            "description": serialized["description"],
            "category": serialized["category"],
            "icon_key": serialized["icon_key"],
            "enabled": serialized["enabled"],
            "configured": serialized["configured"],
            "online": serialized["online"],
            "source": "core",
        })

    for plugin in plugin_registry.list_all(db):
        meta = PLUGIN_SERVICE_META.get(plugin["name"], {})
        enabled = bool(plugin["enabled"])
        configured = bool(plugin["configured"])
        services.append({
            "name": plugin["name"],
            "label": plugin["label"],
            "description": plugin["description"],
            "category": meta.get("category", "Tools"),
            "icon_key": meta.get("icon_key", plugin["name"]),
            "enabled": enabled,
            "configured": configured,
            "online": enabled and configured,
            "source": "plugin",
        })

    return sorted(services, key=lambda item: (item["category"], item["label"].lower()))

def _widget_available(widget_def: dict, core_status: dict[str, bool], plugins_by_name: dict[str, dict]) -> bool:
    required_core = widget_def.get("requires_core")
    if required_core and not core_status.get(required_core, False):
        return False

    required_plugin = widget_def.get("requires_plugin")
    if required_plugin:
        plugin = plugins_by_name.get(required_plugin)
        if not plugin or not plugin["enabled"] or not plugin["configured"]:
            return False

    return True

def _build_widget_catalog(db: Session) -> list[dict]:
    core_status = _core_integration_status(db)
    plugins_by_name = _plugin_records_by_name(db)
    return [
        widget_def for widget_def in WIDGET_CATALOG
        if _widget_available(widget_def, core_status, plugins_by_name)
    ]

def _default_layout_for_catalog(catalog: list[dict]) -> list[dict]:
    catalog_by_id = {item["id"]: item for item in catalog}
    layout = []
    for widget_id in DEFAULT_WIDGET_ORDER:
        widget_def = catalog_by_id.get(widget_id)
        if widget_def is None:
            continue
        layout.append({"id": widget_def["id"], "size": widget_def["default_size"]})
    return layout

def _sanitize_layout(slots: list[dict], catalog: list[dict]) -> list[dict]:
    catalog_by_id = {item["id"]: item for item in catalog}
    sanitized = []

    for slot in slots:
        widget_id = slot.get("id")
        widget_def = catalog_by_id.get(widget_id)
        if widget_def is None:
            continue

        size = slot.get("size")
        if size not in VALID_WIDGET_SIZES:
            size = widget_def["default_size"]

        sanitized.append({"id": widget_id, "size": size})

    seen = set()
    unique = []
    for slot in sanitized:
        if slot["id"] in seen:
            continue
        seen.add(slot["id"])
        unique.append(slot)

    return unique

def _get_dashboard_layout(db: Session, username: str) -> DashboardLayoutModel | None:
    return db.query(DashboardLayoutModel).filter(DashboardLayoutModel.username == username).first()

def _resolve_dashboard_layout(db: Session, username: str) -> list[dict]:
    catalog = _build_widget_catalog(db)
    default_layout = _default_layout_for_catalog(catalog)
    record = _get_dashboard_layout(db, username)
    if record is None:
        return default_layout

    try:
        stored_layout = json.loads(record.layout_json)
    except json.JSONDecodeError:
        stored_layout = []

    sanitized = _sanitize_layout(stored_layout, catalog)
    return sanitized or default_layout

def _save_dashboard_layout(db: Session, username: str, slots: list[dict]) -> list[dict]:
    catalog = _build_widget_catalog(db)
    sanitized = _sanitize_layout(slots, catalog)
    record = _get_dashboard_layout(db, username)
    if record is None:
        record = DashboardLayoutModel(username=username, layout_json="[]")
        db.add(record)

    record.layout_json = json.dumps(sanitized)
    db.commit()
    db.refresh(record)
    return sanitized

# ─── App ──────────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("=" * 50)
    logger.info("Family Hub API starting...")

    # Hard-abort on default secret key – no silent security holes
    if SECRET_KEY == _SECRET_KEY_DEFAULT:
        logger.critical("FATAL: SECRET_KEY is the default placeholder.")
        logger.critical("       Run: openssl rand -hex 32  and set it in .env")
        sys.exit(1)

    if CORS_ORIGINS == ["*"]:
        logger.warning("⚠️  CORS_ORIGINS=* – restrict in production via CORS_ORIGINS env var")
    with SessionLocal() as db:
        vapid_ready = _serialize_core_integration(db, "vapid")["configured"]
        jellyfin_ready = _serialize_core_integration(db, "jellyfin")["configured"]
        tmdb_ready = _serialize_core_integration(db, "tmdb")["configured"]
        ollama_ready = _serialize_core_integration(db, "ollama")["configured"]
        authentik_ready = _serialize_core_integration(db, "authentik")["configured"]

    if not vapid_ready:
        logger.warning("⚠️  VAPID not configured – push notifications disabled")

    logger.info(f"CORS:       {CORS_ORIGINS}")
    logger.info(f"Jellyfin:   {'✓' if jellyfin_ready else '✗ not configured'}")
    logger.info(f"TMDB:       {'✓' if tmdb_ready else '✗ not configured'}")
    logger.info(f"Ollama:     {'✓' if ollama_ready else '✗ not configured'}")
    logger.info(f"VAPID:      {'✓' if vapid_ready else '✗ not configured'}")
    logger.info(f"Authentik:  {'✓' if authentik_ready else '✗ not configured'}")
    logger.info("=" * 50)
    yield
    logger.info("Family Hub API shutting down...")

limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Family Hub API",
    version="2.0.0",
    lifespan=lifespan,
    # Hide docs in production by checking an env var
    docs_url="/docs" if os.getenv("ENABLE_DOCS", "").lower() == "true" else None,
    redoc_url=None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── Security headers ──────────────────────────────────────────────────────────
class _SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> StarletteResponse:
        response = await call_next(request)
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("X-XSS-Protection", "1; mode=block")
        response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
        response.headers.setdefault(
            "Permissions-Policy", "camera=(), microphone=(), geolocation=()")
        return response

app.add_middleware(_SecurityHeadersMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

# ── Global exception handler (no stack traces in responses) ───────────────────
@app.exception_handler(Exception)
async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
    logger.error("Unhandled exception on %s %s: %s",
                 request.method, request.url.path, exc, exc_info=True)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})

# ── Static assets ─────────────────────────────────────────────────────────────
if PUBLIC_DIR.exists():
    app.mount("/assets", StaticFiles(directory=str(PUBLIC_DIR / "assets")), name="assets")

# ─── Auth endpoints ───────────────────────────────────────────────────────────
@app.post("/api/auth/token", response_model=Token)
@limiter.limit("10/minute")
async def login(
    request: Request,
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = db.query(UserModel).filter(UserModel.username == form.username).first()
    if not user or not verify_password(form.password, user.hashed_pw):
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    return {"access_token": create_token({"sub": user.username}), "token_type": "bearer"}

@app.get("/api/auth/me")
async def get_me(user: UserModel = Depends(get_current_user)):
    return {"username": user.username, "email": user.email,
            "full_name": user.full_name, "is_admin": user.is_admin}

@app.post("/api/auth/refresh", response_model=Token)
async def refresh_token(user: UserModel = Depends(get_current_user)):
    """Issue a fresh JWT for the currently authenticated user."""
    return {"access_token": create_token({"sub": user.username}), "token_type": "bearer"}

# ─── OIDC / Authentik ─────────────────────────────────────────────────────────
@app.get("/api/auth/oidc-url")
async def oidc_login_url(db: Session = Depends(get_db)):
    """Return the Authentik authorization URL for the Flutter app to open."""
    authentik = _core_config(db, "authentik")
    authentik_url = authentik.get("url", "")
    authentik_client_id = authentik.get("client_id", "")
    backend_url = authentik.get("backend_url", BACKEND_URL)
    if not authentik_url or not authentik_client_id or not _core_enabled(db, "authentik"):
        raise HTTPException(status_code=503, detail="OIDC not configured")
    state = secrets.token_urlsafe(32)
    nonce = secrets.token_urlsafe(32)
    _oidc_states[state] = {"created": datetime.utcnow(), "nonce": nonce}
    # Purge states older than 10 minutes
    cutoff = datetime.utcnow() - timedelta(minutes=10)
    stale  = [k for k, v in _oidc_states.items() if v["created"] < cutoff]
    for k in stale:
        del _oidc_states[k]

    params = urlencode({
        "client_id":     authentik_client_id,
        "response_type": "code",
        "scope":         "openid email profile",
        "redirect_uri":  f"{backend_url}/api/auth/oidc/callback",
        "state":         state,
        "nonce":         nonce,
    })
    return {"url": f"{authentik_url}/application/o/authorize/?{params}"}


@app.get("/api/auth/oidc/callback")
@limiter.limit("20/minute")
async def oidc_callback(
    request: Request,
    code: str,
    state: str,
    db: Session = Depends(get_db),
):
    """Authentik redirects here after login. Exchanges code, issues Hub JWT."""
    authentik = _core_config(db, "authentik")
    authentik_url = authentik.get("url", "")
    authentik_client_id = authentik.get("client_id", "")
    authentik_client_secret = authentik.get("client_secret", "")
    backend_url = authentik.get("backend_url", BACKEND_URL)
    if not authentik_url or not authentik_client_id or not authentik_client_secret:
        raise HTTPException(status_code=503, detail="OIDC not configured")

    # Validate state
    state_data = _oidc_states.pop(state, None)
    if not state_data:
        raise HTTPException(status_code=400, detail="Invalid or expired OIDC state")

    # Exchange code for tokens
    token_url = f"{authentik_url}/application/o/token/"
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.post(token_url, data={
                "grant_type":   "authorization_code",
                "code":         code,
                "redirect_uri": f"{backend_url}/api/auth/oidc/callback",
                "client_id":    authentik_client_id,
                "client_secret": authentik_client_secret,
            })
            if r.status_code != 200:
                logger.error("OIDC token exchange failed: %s %s", r.status_code, r.text)
                raise HTTPException(status_code=502, detail="OIDC token exchange failed")
            token_data = r.json()
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Authentik unreachable: {e}")

    # Fetch user claims from userinfo endpoint using access token.
    # This avoids trusting unsigned/unverified ID token payloads.
    access_token = token_data.get("access_token", "")
    if not access_token:
        raise HTTPException(status_code=502, detail="OIDC access token missing")

    userinfo_url = f"{authentik_url}/application/o/userinfo/"
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            userinfo_resp = await c.get(
                userinfo_url,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            if userinfo_resp.status_code != 200:
                logger.error("OIDC userinfo failed: %s %s", userinfo_resp.status_code, userinfo_resp.text)
                raise HTTPException(status_code=502, detail="OIDC userinfo failed")
            claims = userinfo_resp.json()
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"OIDC userinfo unreachable: {e}")

    oidc_sub   = claims.get("sub", "")
    email      = claims.get("email", "")
    full_name  = claims.get("name", "") or claims.get("preferred_username", email)

    if not email:
        raise HTTPException(status_code=400, detail="No email in OIDC token")

    # Create or update user
    user = db.query(UserModel).filter(UserModel.email == email).first()
    if user is None:
        username = email.split("@")[0].replace(".", "_").lower()
        # Ensure username uniqueness
        base, n = username, 1
        while db.query(UserModel).filter(UserModel.username == username).first():
            username = f"{base}{n}"; n += 1
        user = UserModel(
            username=username,
            email=email,
            full_name=full_name,
            hashed_pw=f"oidc:{oidc_sub}",  # no password login for OIDC users
            is_admin=False,
        )
        db.add(user)
        db.commit()
        logger.info("OIDC: new user created: %s (%s)", username, email)
    else:
        user.full_name = full_name
        db.commit()

    hub_token = create_token({"sub": user.username})
    # Redirect to Flutter deep link; browser shows fallback if app not installed
    # Put token in fragment so it isn't sent in server logs, referers, or proxies.
    redirect_url = f"hubstinger://auth#token={hub_token}"
    return RedirectResponse(url=redirect_url, status_code=302)

# ─── Push Notifications ───────────────────────────────────────────────────────
@app.get("/api/vapid-public-key")
async def get_vapid_key(db: Session = Depends(get_db)):
    vapid_public_key = _core_value(db, "vapid", "public_key", "")
    if not vapid_public_key or not _core_enabled(db, "vapid"):
        raise HTTPException(status_code=503, detail="VAPID not configured")
    return {"publicKey": vapid_public_key}

@app.post("/api/push/subscribe")
async def subscribe(sub: PushSubscription, db: Session = Depends(get_db)):
    existing = db.query(PushSubModel).filter(PushSubModel.endpoint == sub.endpoint).first()
    if existing:
        existing.auth   = sub.keys.get("auth", "")
        existing.p256dh = sub.keys.get("p256dh", "")
    else:
        db.add(PushSubModel(
            endpoint=sub.endpoint,
            auth=sub.keys.get("auth", ""),
            p256dh=sub.keys.get("p256dh", ""),
            username="anonymous",
        ))
    db.commit()
    return {"status": "subscribed"}

async def _send_push_notification(payload: PushPayload, db: Session):
    vapid_private_key = _core_value(db, "vapid", "private_key", "")
    vapid_email = _core_value(db, "vapid", "email", "")
    if not vapid_private_key or not vapid_email or not _core_enabled(db, "vapid"):
        raise HTTPException(status_code=503, detail="VAPID not configured")

    subs = db.query(PushSubModel).all()
    results = {"sent": 0, "failed": 0}

    notification_data = json.dumps({
        "title": payload.title,
        "body":  payload.body,
        "url":   payload.url,
        "icon":  payload.icon,
        "badge": payload.badge,
    })

    for sub in subs:
        try:
            webpush(
                subscription_info={
                    "endpoint": sub.endpoint,
                    "keys": {"auth": sub.auth, "p256dh": sub.p256dh},
                },
                data=notification_data,
                vapid_private_key=vapid_private_key,
                vapid_claims={"sub": vapid_email},
            )
            results["sent"] += 1
        except WebPushException as e:
            logger.warning(f"Push failed for {sub.endpoint[:40]}...: {e}")
            if "410" in str(e) or "404" in str(e):
                db.delete(sub)
            results["failed"] += 1

    db.commit()
    return results

@app.post("/api/push/notify")
async def send_notification(payload: PushPayload, db: Session = Depends(get_db)):
    return await _send_push_notification(payload, db)

class FcmSubscribeBody(BaseModel):
    fcm_token: str

@app.post("/api/push/subscribe-fcm")
async def subscribe_fcm(
    body: FcmSubscribeBody,
    user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Register an FCM device token for native push notifications."""
    existing = db.query(FcmTokenModel).filter(FcmTokenModel.token == body.fcm_token).first()
    if existing:
        existing.username  = user.username
        existing.updated_at = datetime.utcnow()
    else:
        db.add(FcmTokenModel(token=body.fcm_token, username=user.username))
    db.commit()
    return {"status": "registered"}

# ─── Jellyfin ─────────────────────────────────────────────────────────────────
@app.get("/api/jellyfin/sessions")
async def jellyfin_sessions(db: Session = Depends(get_db)):
    jellyfin_url = _core_value(db, "jellyfin", "url", "")
    jellyfin_token = _core_value(db, "jellyfin", "token", "")
    if not jellyfin_url or not jellyfin_token or not _core_enabled(db, "jellyfin"):
        return {"sessions": [], "hint": "Jellyfin ist im Admin-UI noch nicht konfiguriert."}
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(
                f"{jellyfin_url}/Sessions",
                headers={"X-Emby-Token": jellyfin_token},
            )
            sessions = r.json()
            return {"sessions": [
                {
                    "title":    s.get("NowPlayingItem", {}).get("Name", ""),
                    "user":     s.get("UserName", ""),
                    "progress": round((s.get("PlayState", {}).get("PositionTicks", 0) /
                                       max(s.get("NowPlayingItem", {}).get("RunTimeTicks", 1), 1)) * 100),
                    "type":     s.get("NowPlayingItem", {}).get("Type", ""),
                }
                for s in sessions if s.get("NowPlayingItem")
            ]}
    except Exception as e:
        logger.error(f"Jellyfin error: {e}")
        return {"sessions": [], "error": str(e)}

@app.get("/api/jellyfin/recently-added")
async def recently_added(days: int = 7, limit: int = 10, db: Session = Depends(get_db)):
    jellyfin_url = _core_value(db, "jellyfin", "url", "")
    jellyfin_token = _core_value(db, "jellyfin", "token", "")
    if not jellyfin_url or not jellyfin_token or not _core_enabled(db, "jellyfin"):
        return {"items": [], "hint": "Jellyfin ist im Admin-UI noch nicht konfiguriert."}
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            since = (datetime.utcnow() - timedelta(days=days)).isoformat()
            r = await client.get(
                f"{jellyfin_url}/Items",
                headers={"X-Emby-Token": jellyfin_token},
                params={"SortBy": "DateCreated,SortName", "SortOrder": "Descending",
                        "Recursive": "true", "Limit": limit,
                        "IncludeItemTypes": "Movie,Episode",
                        "MinDateLastSaved": since, "Fields": "Overview,PrimaryImageAspectRatio"},
            )
            data = r.json()
            return {"items": [
                {
                    "id":      i.get("Id"),
                    "title":   i.get("Name"),
                    "type":    i.get("Type"),
                    "tmdb_id": i.get("ProviderIds", {}).get("Tmdb"),
                    "added":   (i.get("DateCreated") or "")[:10],
                    "has_image": bool(i.get("ImageTags", {}).get("Primary")),
                }
                for i in data.get("Items", [])
            ]}
    except Exception as e:
        logger.error(f"Jellyfin recently-added error: {e}")
        return {"items": [], "error": str(e)}

@app.get("/api/jellyfin/image/{item_id}")
async def jellyfin_image(item_id: str, width: int = 200, db: Session = Depends(get_db)):
    """Proxy Jellyfin primary image so the app doesn't need the internal Jellyfin URL."""
    from fastapi.responses import Response as FastAPIResponse
    jellyfin_url = _core_value(db, "jellyfin", "url", "")
    jellyfin_token = _core_value(db, "jellyfin", "token", "")
    if not jellyfin_url or not jellyfin_token or not _core_enabled(db, "jellyfin"):
        raise HTTPException(status_code=503, detail="Jellyfin not configured")
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            f"{jellyfin_url}/Items/{item_id}/Images/Primary",
            headers={"X-Emby-Token": jellyfin_token},
            params={"fillWidth": width, "quality": 90},
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Image not found")
        return FastAPIResponse(
            content=r.content,
            media_type=r.headers.get("content-type", "image/jpeg"),
            headers={"Cache-Control": "public, max-age=86400"},
        )

# ─── TMDB ─────────────────────────────────────────────────────────────────────
@app.get("/api/tmdb/movie/{tmdb_id}")
async def tmdb_movie(tmdb_id: int, db: Session = Depends(get_db)):
    tmdb_api_key = _core_value(db, "tmdb", "api_key", "")
    if not tmdb_api_key or not _core_enabled(db, "tmdb"):
        raise HTTPException(status_code=503, detail="TMDB not configured")
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            f"https://api.themoviedb.org/3/movie/{tmdb_id}",
            params={"api_key": tmdb_api_key, "language": "de-DE",
                    "append_to_response": "videos,credits"},
        )
        return r.json()

@app.get("/api/tmdb/search")
async def tmdb_search(q: str, type: str = "movie", db: Session = Depends(get_db)):
    tmdb_api_key = _core_value(db, "tmdb", "api_key", "")
    if not tmdb_api_key or not _core_enabled(db, "tmdb"):
        raise HTTPException(status_code=503, detail="TMDB not configured")
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            f"https://api.themoviedb.org/3/search/{type}",
            params={"api_key": tmdb_api_key, "query": q, "language": "de-DE"},
        )
        return r.json()

# ─── Ollama ───────────────────────────────────────────────────────────────────
@app.post("/api/ollama/summarize")
async def ollama_summarize(data: dict, db: Session = Depends(get_db)):
    title    = data.get("title", "")
    overview = data.get("overview", "")
    ollama_url = _core_value(db, "ollama", "url", "")
    ollama_model = _core_value(db, "ollama", "model", OLLAMA_MODEL or "llama3.2")
    if not ollama_url or not _core_enabled(db, "ollama"):
        raise HTTPException(status_code=503, detail="Ollama not configured")
    prompt   = f"Schreib eine kurze, ansprechende Zusammenfassung auf Deutsch (2 Sätze) für den Film/die Serie '{title}'. Originaltext: {overview}"
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(
                f"{ollama_url}/api/generate",
                json={"model": ollama_model, "prompt": prompt, "stream": False},
            )
            return {"summary": r.json().get("response", overview)}
    except Exception as e:
        logger.error(f"Ollama error: {e}")
        return {"summary": overview, "error": str(e)}

# ─── Newsletter ───────────────────────────────────────────────────────────────
@app.post("/api/newsletter/generate")
async def generate_newsletter(db: Session = Depends(get_db)):
    """
    Called by n8n weekly. Fetches Jellyfin data + TMDB metadata + Ollama summaries,
    renders newsletter HTML and sends push notifications.
    """
    from plugins.newsletter_builder import build_newsletter
    try:
        result = await build_newsletter(
            jellyfin_url=_core_value(db, "jellyfin", "url", ""),
            jellyfin_token=_core_value(db, "jellyfin", "token", ""),
            tmdb_api_key=_core_value(db, "tmdb", "api_key", ""),
            ollama_url=_core_value(db, "ollama", "url", ""),
            ollama_model=_core_value(db, "ollama", "model", OLLAMA_MODEL or "llama3.2"),
            jellyseerr_url=_plugin_config_value(db, "jellyseerr", "url", ""),
        )
        # Send push to all subscribers
        await _send_push_notification(PushPayload(
            title="📬 Neuer Family Hub Newsletter",
            body=f"KW {result['week']} ist da – {result['count']} Empfehlungen!",
            url="/newsletter",
        ), db)
        return result
    except Exception as e:
        logger.error(f"Newsletter generation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/newsletter/archive")
async def newsletter_archive():
    archive_dir = BASE_DIR.parent / "newsletters"
    if not archive_dir.exists():
        return {"newsletters": []}
    newsletters = []
    for f in sorted(archive_dir.glob("*.json"), reverse=True)[:10]:
        with open(f) as fp:
            newsletters.append(json.load(fp))
    return {"newsletters": newsletters}

# ─── Stats ────────────────────────────────────────────────────────────────────
@app.get("/api/stats")
async def get_stats(db: Session = Depends(get_db)):
    """Aggregated dashboard stats – Jellyfin core + all enabled plugin stats."""
    results: dict = {}
    jellyfin_url = _core_value(db, "jellyfin", "url", "")
    jellyfin_token = _core_value(db, "jellyfin", "token", "")

    # ── Core Jellyfin (env-var based, always available when configured) ─────────
    async with httpx.AsyncClient(timeout=3) as client:
        try:
            if jellyfin_url and jellyfin_token and _core_enabled(db, "jellyfin"):
                r = await client.get(
                    f"{jellyfin_url}/Sessions",
                    headers={"X-Emby-Token": jellyfin_token},
                )
                active = [s for s in r.json() if s.get("NowPlayingItem")]
                results["active_streams"] = len(active)
        except Exception:
            results["active_streams"] = 0

    # ── Plugin stats (all enabled + configured plugins in parallel) ─────────────
    instances = plugin_registry.get_all_instances(db)
    if instances:
        plugin_results = await asyncio.gather(
            *[inst.get_stats() for inst in instances],
            return_exceptions=True,
        )
        for plugin_stats in plugin_results:
            if isinstance(plugin_stats, dict):
                results.update(plugin_stats)

    results["timestamp"] = datetime.utcnow().isoformat()
    return results

# ─── Uptime Kuma webhook ──────────────────────────────────────────────────────
@app.post("/api/webhook/uptime-kuma")
async def uptime_kuma_webhook(data: dict, db: Session = Depends(get_db)):
    """Uptime Kuma calls this when a service goes down/up."""
    monitor  = data.get("monitor", {})
    heartbeat = data.get("heartbeat", {})
    is_down  = heartbeat.get("status") == 0

    if is_down:
        service_name = monitor.get("name", "Service")
        await _send_push_notification(PushPayload(
            title=f"⚠️ {service_name} ist offline",
            body="Uptime Kuma hat einen Ausfall erkannt.",
            url="/services",
        ), db)

    return {"received": True}

# ─── Admin UI ────────────────────────────────────────────────────────────────
@app.get("/api/app/bootstrap")
async def app_bootstrap(
    user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    services = _build_service_catalog(db)
    widget_catalog = _build_widget_catalog(db)
    return {
        "services": services,
        "integrations": services,
        "widgets": {
            "catalog": widget_catalog,
            "layout": _resolve_dashboard_layout(db, user.username),
        },
    }

@app.put("/api/dashboard/layout")
async def save_dashboard_layout(
    body: DashboardLayoutBody,
    user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    layout = _save_dashboard_layout(db, user.username, body.slots)
    return {"layout": layout}

@app.get("/api/core-integrations")
async def list_core_integrations(
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return _list_core_integrations(db)

@app.put("/api/core-integrations/{name}/toggle")
async def toggle_core_integration(
    name: str,
    body: PluginToggleBody,
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    try:
        return _set_core_enabled(db, name, body.enabled)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Core integration '{name}' not found")

@app.put("/api/core-integrations/{name}/config")
async def update_core_config(
    name: str,
    body: PluginConfigBody,
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    try:
        return _save_core_config(db, name, body.config)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Core integration '{name}' not found")

@app.post("/api/core-integrations/{name}/test")
async def test_core_integration(
    name: str,
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    try:
        return await _test_core_integration(db, name)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Core integration '{name}' not found")

@app.get("/admin", response_class=HTMLResponse)
async def admin_ui(request: Request):
    return templates.TemplateResponse("admin.html", {"request": request})

# ─── Plugin API ───────────────────────────────────────────────────────────────
@app.get("/api/plugins")
async def list_plugins(
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return plugin_registry.list_all(db)

@app.put("/api/plugins/{name}/toggle")
async def toggle_plugin(
    name: str,
    body: PluginToggleBody,
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    result = plugin_registry.set_enabled(db, name, body.enabled)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return _plugin_serialized(db, name)

@app.put("/api/plugins/{name}/config")
async def update_plugin_config(
    name: str,
    body: PluginConfigBody,
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    result = plugin_registry.save_config(db, name, body.config)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return _plugin_serialized(db, name)

@app.post("/api/plugins/{name}/test")
async def test_plugin(
    name: str,
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return await plugin_registry.test_plugin(db, name)

# ─── Health ───────────────────────────────────────────────────────────────────
@app.get("/")
async def health(db: Session = Depends(get_db)):
    return {
        "status":              "online",
        "version":             "2.0.0",
        "vapid_configured":    _serialize_core_integration(db, "vapid")["configured"],
        "jellyfin_configured": _serialize_core_integration(db, "jellyfin")["configured"],
        "tmdb_configured":     _serialize_core_integration(db, "tmdb")["configured"],
        "oidc_configured":     _serialize_core_integration(db, "authentik")["configured"],
        "timestamp":           datetime.utcnow().isoformat(),
    }

# ─── Run ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
