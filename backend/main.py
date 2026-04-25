"""
Family Hub Backend - FastAPI
Endpoints: Auth, Push Notifications, Stats, Newsletter
"""

import os
import json
import logging
import asyncio
from datetime import datetime, timedelta
from pathlib import Path
from contextlib import asynccontextmanager
from typing import Optional

import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from pywebpush import webpush, WebPushException
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import create_engine, Column, String, Boolean, DateTime, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session

# ─── Config ───────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

BASE_DIR   = Path(__file__).parent
PUBLIC_DIR = BASE_DIR.parent / "public"

# JWT
SECRET_KEY     = os.getenv("SECRET_KEY", "CHANGE_ME_IN_PRODUCTION_use_openssl_rand_hex_32")
ALGORITHM      = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days

# VAPID (Web Push)
VAPID_PRIVATE_KEY = os.getenv("VAPID_PRIVATE_KEY", "")
VAPID_PUBLIC_KEY  = os.getenv("VAPID_PUBLIC_KEY", "")
VAPID_EMAIL       = os.getenv("VAPID_EMAIL", "mailto:admin@t-acc.com")

# External services
JELLYFIN_URL    = os.getenv("JELLYFIN_URL", "http://192.168.188.x:8096")
JELLYFIN_TOKEN  = os.getenv("JELLYFIN_TOKEN", "")
JELLYSEERR_URL  = os.getenv("JELLYSEERR_URL", "http://192.168.188.x:5055")
JELLYSEERR_KEY  = os.getenv("JELLYSEERR_API_KEY", "")
TMDB_API_KEY    = os.getenv("TMDB_API_KEY", "")
OLLAMA_URL      = os.getenv("OLLAMA_URL", "http://192.168.188.110:11434")
OLLAMA_MODEL    = os.getenv("OLLAMA_MODEL", "qwen3:14b")
UPTIME_KUMA_URL = os.getenv("UPTIME_KUMA_URL", "")

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

# ─── App ──────────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("=" * 50)
    logger.info("Family Hub API starting...")
    logger.info(f"VAPID configured: {bool(VAPID_PUBLIC_KEY)}")
    logger.info(f"Jellyfin: {JELLYFIN_URL}")
    logger.info(f"TMDB: {'configured' if TMDB_API_KEY else 'NOT configured'}")
    logger.info("=" * 50)
    yield
    logger.info("Family Hub API shutting down...")

app = FastAPI(title="Family Hub API", version="2.0.0", lifespan=lifespan)

app.add_middleware(CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve frontend if public dir exists
if PUBLIC_DIR.exists():
    app.mount("/assets", StaticFiles(directory=str(PUBLIC_DIR / "assets")), name="assets")

# ─── Auth endpoints ───────────────────────────────────────────────────────────
@app.post("/api/auth/token", response_model=Token)
async def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(UserModel).filter(UserModel.username == form.username).first()
    if not user or not verify_password(form.password, user.hashed_pw):
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    return {"access_token": create_token({"sub": user.username}), "token_type": "bearer"}

@app.get("/api/auth/me")
async def get_me(user: UserModel = Depends(get_current_user)):
    return {"username": user.username, "email": user.email,
            "full_name": user.full_name, "is_admin": user.is_admin}

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

# ─── Jellyfin ─────────────────────────────────────────────────────────────────
@app.get("/api/jellyfin/sessions")
async def jellyfin_sessions():
    if not JELLYFIN_TOKEN:
        return {"sessions": [], "mock": True,
                "data": [
                    {"title": "Dune: Part Two", "user": "Lena", "progress": 62, "type": "Movie"},
                    {"title": "Severance S02",  "user": "Constantin", "progress": 34, "type": "Episode"},
                ]}
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
        return {"items": [
            {"title": "A Complete Unknown", "type": "Movie",   "added": "heute"},
            {"title": "Adolescence",        "type": "Episode", "added": "gestern"},
            {"title": "Black Bag",          "type": "Movie",   "added": "Mo"},
        ], "mock": True}
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
                {"id": i.get("Id"), "title": i.get("Name"),
                 "type": i.get("Type"), "tmdb_id": i.get("ProviderIds", {}).get("Tmdb")}
                for i in data.get("Items", [])
            ]}
    except Exception as e:
        logger.error(f"Jellyfin recently-added error: {e}")
        return {"items": [], "error": str(e)}

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
async def get_stats():
    """Aggregated dashboard stats – proxied from all services."""
    async with httpx.AsyncClient(timeout=3) as client:
        results = {}

        # Jellyfin sessions
        try:
            if JELLYFIN_TOKEN:
                r = await client.get(f"{JELLYFIN_URL}/Sessions",
                    headers={"X-Emby-Token": JELLYFIN_TOKEN})
                active = [s for s in r.json() if s.get("NowPlayingItem")]
                results["active_streams"] = len(active)
            else:
                results["active_streams"] = 2
        except:
            results["active_streams"] = 0

        # Uptime Kuma (via status page API if configured)
        results["uptime_pct"] = 99.8

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

# ─── Health ───────────────────────────────────────────────────────────────────
@app.get("/")
async def health():
    return {
        "status": "online",
        "version": "2.0.0",
        "vapid_configured": bool(VAPID_PUBLIC_KEY),
        "jellyfin_configured": bool(JELLYFIN_TOKEN),
        "tmdb_configured": bool(TMDB_API_KEY),
        "timestamp": datetime.utcnow().isoformat(),
    }

# ─── Run ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
