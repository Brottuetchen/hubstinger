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
from typing import Optional
from urllib.parse import urlencode

import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response as StarletteResponse
from pywebpush import webpush, WebPushException
from jose import JWTError, jwt
from passlib.context import CryptContext
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

Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ─── Auth ─────────────────────────────────────────────────────────────────────
pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2  = OAuth2PasswordBearer(tokenUrl="api/auth/token")

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_ctx.verify(plain, hashed)

def hash_password(password: str) -> str:
    return pwd_ctx.hash(password)

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

# ─── Plugin Registry ──────────────────────────────────────────────────────────
from plugin_registry import registry as plugin_registry

# ─── Templates ────────────────────────────────────────────────────────────────
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))

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
    if not VAPID_EMAIL:
        logger.warning("⚠️  VAPID_EMAIL not set – push notifications disabled")

    logger.info(f"CORS:       {CORS_ORIGINS}")
    logger.info(f"Jellyfin:   {'✓ ' + JELLYFIN_URL if JELLYFIN_URL else '✗ not configured'}")
    logger.info(f"TMDB:       {'✓' if TMDB_API_KEY else '✗ not configured'}")
    logger.info(f"Ollama:     {'✓ ' + OLLAMA_URL if OLLAMA_URL else '✗ not configured'}")
    logger.info(f"VAPID:      {'✓' if VAPID_PUBLIC_KEY else '✗ not configured'}")
    logger.info(f"Authentik:  {'✓ ' + AUTHENTIK_URL if AUTHENTIK_URL else '✗ not configured'}")
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
async def oidc_login_url():
    """Return the Authentik authorization URL for the Flutter app to open."""
    if not AUTHENTIK_URL or not AUTHENTIK_CLIENT_ID:
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
        "client_id":     AUTHENTIK_CLIENT_ID,
        "response_type": "code",
        "scope":         "openid email profile",
        "redirect_uri":  f"{BACKEND_URL}/api/auth/oidc/callback",
        "state":         state,
        "nonce":         nonce,
    })
    return {"url": f"{AUTHENTIK_URL}/application/o/authorize/?{params}"}


@app.get("/api/auth/oidc/callback")
@limiter.limit("20/minute")
async def oidc_callback(
    request: Request,
    code: str,
    state: str,
    db: Session = Depends(get_db),
):
    """Authentik redirects here after login. Exchanges code, issues Hub JWT."""
    # Validate state
    state_data = _oidc_states.pop(state, None)
    if not state_data:
        raise HTTPException(status_code=400, detail="Invalid or expired OIDC state")

    # Exchange code for tokens
    token_url = f"{AUTHENTIK_URL}/application/o/token/"
    try:
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.post(token_url, data={
                "grant_type":   "authorization_code",
                "code":         code,
                "redirect_uri": f"{BACKEND_URL}/api/auth/oidc/callback",
                "client_id":    AUTHENTIK_CLIENT_ID,
                "client_secret": AUTHENTIK_CLIENT_SECRET,
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

    userinfo_url = f"{AUTHENTIK_URL}/application/o/userinfo/"
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
async def get_vapid_key():
    if not VAPID_PUBLIC_KEY:
        raise HTTPException(status_code=503, detail="VAPID not configured")
    return {"publicKey": VAPID_PUBLIC_KEY}

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

@app.post("/api/push/notify")
async def send_notification(payload: PushPayload, db: Session = Depends(get_db)):
    if not VAPID_PRIVATE_KEY:
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
                vapid_private_key=VAPID_PRIVATE_KEY,
                vapid_claims={"sub": VAPID_EMAIL},
            )
            results["sent"] += 1
        except WebPushException as e:
            logger.warning(f"Push failed for {sub.endpoint[:40]}...: {e}")
            if "410" in str(e) or "404" in str(e):
                db.delete(sub)
            results["failed"] += 1

    db.commit()
    return results

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
async def jellyfin_sessions():
    if not JELLYFIN_TOKEN:
        return {"sessions": [], "mock": True, "hint": "Set JELLYFIN_TOKEN in .env"}
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{JELLYFIN_URL}/Sessions",
                headers={"X-Emby-Token": JELLYFIN_TOKEN})
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
async def recently_added(days: int = 7, limit: int = 10):
    if not JELLYFIN_TOKEN:
        return {"items": [], "mock": True, "hint": "Set JELLYFIN_TOKEN in .env"}
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            since = (datetime.utcnow() - timedelta(days=days)).isoformat()
            r = await client.get(
                f"{JELLYFIN_URL}/Items",
                headers={"X-Emby-Token": JELLYFIN_TOKEN},
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
async def jellyfin_image(item_id: str, width: int = 200):
    """Proxy Jellyfin primary image so the app doesn't need the internal Jellyfin URL."""
    from fastapi.responses import Response as FastAPIResponse
    if not JELLYFIN_TOKEN or not JELLYFIN_URL:
        raise HTTPException(status_code=503, detail="Jellyfin not configured")
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            f"{JELLYFIN_URL}/Items/{item_id}/Images/Primary",
            headers={"X-Emby-Token": JELLYFIN_TOKEN},
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
async def tmdb_movie(tmdb_id: int):
    if not TMDB_API_KEY:
        raise HTTPException(status_code=503, detail="TMDB not configured")
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            f"https://api.themoviedb.org/3/movie/{tmdb_id}",
            params={"api_key": TMDB_API_KEY, "language": "de-DE",
                    "append_to_response": "videos,credits"},
        )
        return r.json()

@app.get("/api/tmdb/search")
async def tmdb_search(q: str, type: str = "movie"):
    if not TMDB_API_KEY:
        raise HTTPException(status_code=503, detail="TMDB not configured")
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            f"https://api.themoviedb.org/3/search/{type}",
            params={"api_key": TMDB_API_KEY, "query": q, "language": "de-DE"},
        )
        return r.json()

# ─── Ollama ───────────────────────────────────────────────────────────────────
@app.post("/api/ollama/summarize")
async def ollama_summarize(data: dict):
    title    = data.get("title", "")
    overview = data.get("overview", "")
    prompt   = f"Schreib eine kurze, ansprechende Zusammenfassung auf Deutsch (2 Sätze) für den Film/die Serie '{title}'. Originaltext: {overview}"
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(f"{OLLAMA_URL}/api/generate",
                json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False})
            return {"summary": r.json().get("response", overview)}
    except Exception as e:
        logger.error(f"Ollama error: {e}")
        return {"summary": overview, "error": str(e)}

# ─── Newsletter ───────────────────────────────────────────────────────────────
@app.post("/api/newsletter/generate")
async def generate_newsletter():
    """
    Called by n8n weekly. Fetches Jellyfin data + TMDB metadata + Ollama summaries,
    renders newsletter HTML and sends push notifications.
    """
    from plugins.newsletter_builder import build_newsletter
    try:
        result = await build_newsletter()
        # Send push to all subscribers
        await send_notification(PushPayload(
            title="📬 Neuer Family Hub Newsletter",
            body=f"KW {result['week']} ist da – {result['count']} Empfehlungen!",
            url="/newsletter",
        ))
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

    # ── Core Jellyfin (env-var based, always available when configured) ─────────
    async with httpx.AsyncClient(timeout=3) as client:
        try:
            if JELLYFIN_TOKEN:
                r = await client.get(f"{JELLYFIN_URL}/Sessions",
                    headers={"X-Emby-Token": JELLYFIN_TOKEN})
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
        await send_notification(PushPayload(
            title=f"⚠️ {service_name} ist offline",
            body="Uptime Kuma hat einen Ausfall erkannt.",
            url="/services",
        ))

    return {"received": True}

# ─── Admin UI ────────────────────────────────────────────────────────────────
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
    return result

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
    return result

@app.post("/api/plugins/{name}/test")
async def test_plugin(
    name: str,
    _user: UserModel = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return await plugin_registry.test_plugin(db, name)

# ─── Health ───────────────────────────────────────────────────────────────────
@app.get("/")
async def health():
    return {
        "status":              "online",
        "version":             "2.0.0",
        "vapid_configured":    bool(VAPID_PUBLIC_KEY),
        "jellyfin_configured": bool(JELLYFIN_TOKEN),
        "tmdb_configured":     bool(TMDB_API_KEY),
        "oidc_configured":     bool(AUTHENTIK_URL and AUTHENTIK_CLIENT_ID),
        "timestamp":           datetime.utcnow().isoformat(),
    }

# ─── Run ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
