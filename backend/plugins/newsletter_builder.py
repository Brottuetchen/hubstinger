"""
Newsletter Builder Plugin
Fetches Jellyfin data → TMDB metadata → Ollama summaries → renders HTML
Called weekly by n8n via POST /api/newsletter/generate
"""

import json
import httpx
from datetime import datetime, timedelta
from pathlib import Path
import os

JELLYFIN_URL   = os.getenv("JELLYFIN_URL", "")
JELLYFIN_TOKEN = os.getenv("JELLYFIN_TOKEN", "")
TMDB_API_KEY   = os.getenv("TMDB_API_KEY", "")
OLLAMA_URL     = os.getenv("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL   = os.getenv("OLLAMA_MODEL", "qwen3:14b")
JELLYSEERR_URL = os.getenv("JELLYSEERR_URL", "")

OUTPUT_DIR = Path(__file__).parent.parent.parent / "newsletters"
OUTPUT_DIR.mkdir(exist_ok=True)


async def get_new_media(days: int = 7) -> list[dict]:
    """Fetch recently added items from Jellyfin."""
    if not JELLYFIN_TOKEN:
        return _mock_media()
    since = (datetime.utcnow() - timedelta(days=days)).isoformat()
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            f"{JELLYFIN_URL}/Items",
            headers={"X-Emby-Token": JELLYFIN_TOKEN},
            params={
                "SortBy": "DateCreated,SortName",
                "SortOrder": "Descending",
                "Recursive": "true",
                "Limit": 20,
                "IncludeItemTypes": "Movie,Series",
                "MinDateLastSaved": since,
                "Fields": "Overview,ProviderIds,RunTimeTicks",
            },
        )
        return r.json().get("Items", [])


async def enrich_with_tmdb(item: dict) -> dict:
    """Add TMDB poster, rating, runtime to a Jellyfin item."""
    if not TMDB_API_KEY:
        return item
    tmdb_id = item.get("ProviderIds", {}).get("Tmdb")
    if not tmdb_id:
        return item
    media_type = "movie" if item.get("Type") == "Movie" else "tv"
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(
            f"https://api.themoviedb.org/3/{media_type}/{tmdb_id}",
            params={"api_key": TMDB_API_KEY, "language": "de-DE"},
        )
        tmdb = r.json()
        item["poster_path"]    = tmdb.get("poster_path")
        item["vote_average"]   = tmdb.get("vote_average")
        item["runtime"]        = tmdb.get("runtime") or (tmdb.get("episode_run_time") or [None])[0]
        item["genres"]         = [g["name"] for g in tmdb.get("genres", [])[:2]]
        item["tmdb_overview"]  = tmdb.get("overview", "")
    return item


async def generate_summary(title: str, overview: str) -> str:
    """Use Ollama to write a German 2-sentence summary."""
    if not overview:
        return ""
    prompt = (
        f"Schreib eine kurze, ansprechende Zusammenfassung auf Deutsch (maximal 2 Sätze, "
        f"ohne Spoiler) für '{title}'. Originaltext: {overview}"
    )
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(
                f"{OLLAMA_URL}/api/generate",
                json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False},
            )
            return r.json().get("response", overview[:200])
    except Exception:
        return overview[:200]


async def get_watchtime_stats() -> list[dict]:
    """
    Get per-user watchtime from Jellyfin Stats plugin.
    Requires jellyfin-plugin-playbackreporting to be installed.
    Falls back to mock data.
    """
    if not JELLYFIN_TOKEN:
        return _mock_watchtime()
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            # PlaybackReporting plugin endpoint
            r = await client.get(
                f"{JELLYFIN_URL}/user_usage_stats/user_activity",
                headers={"X-Emby-Token": JELLYFIN_TOKEN},
                params={"days": 7, "end_date": datetime.utcnow().strftime("%Y-%m-%d")},
            )
            data = r.json()
            return [
                {"name": u.get("user_name"), "hours": round(u.get("total_play_duration", 0) / 3600, 1)}
                for u in data
            ]
    except Exception:
        return _mock_watchtime()


def render_html(week: int, year: int, media: list[dict], watchtime: list[dict]) -> str:
    """Render the newsletter as HTML."""
    movies  = [m for m in media if m.get("Type") == "Movie"][:5]
    series  = [m for m in media if m.get("Type") in ("Series", "Episode")][:3]
    top_user = watchtime[0] if watchtime else None

    def media_block(item: dict) -> str:
        poster = f"https://image.tmdb.org/t/p/w342{item['poster_path']}" if item.get("poster_path") else ""
        rating = f"★ {item['vote_average']:.1f}" if item.get("vote_average") else ""
        runtime = f"{item['runtime']} min" if item.get("runtime") else ""
        genres  = " · ".join(item.get("genres", []))
        summary = item.get("ai_summary", item.get("tmdb_overview", "")[:200])
        request_url = f"{JELLYSEERR_URL}/{'movie' if item.get('Type')=='Movie' else 'tv'}/{item.get('ProviderIds',{}).get('Tmdb','')}"
        return f"""
        <div style="display:flex;gap:16px;margin-bottom:24px;background:rgba(255,255,255,0.04);border-radius:16px;padding:16px;border:1px solid rgba(255,255,255,0.1)">
          {"<img src='"+poster+"' style='width:80px;height:120px;border-radius:10px;object-fit:cover;flex-shrink:0'>" if poster else "<div style='width:80px;height:120px;border-radius:10px;background:rgba(255,255,255,0.08);flex-shrink:0'></div>"}
          <div style="flex:1">
            <div style="font-size:16px;font-weight:700;margin-bottom:6px">{item.get("Name","")}</div>
            <div style="font-size:12px;color:rgba(255,255,255,0.5);margin-bottom:8px">{rating} {'·' if rating and runtime else ''} {runtime} {'·' if genres else ''} {genres}</div>
            <div style="font-size:13px;color:rgba(255,255,255,0.65);line-height:1.5;margin-bottom:12px">{summary}</div>
            <a href="{request_url}" style="display:inline-block;background:rgba(124,58,237,0.3);border:1px solid rgba(124,58,237,0.5);color:white;text-decoration:none;border-radius:10px;padding:7px 14px;font-size:12px;font-weight:600">📋 Anfragen</a>
          </div>
        </div>"""

    watchtime_rows = "".join([
        f'<div style="display:flex;align-items:center;gap:12px;margin-bottom:8px">'
        f'<span style="font-size:18px">{"🥇" if i==0 else "🥈" if i==1 else "🥉"}</span>'
        f'<span style="flex:1;font-size:14px">{u["name"]}</span>'
        f'<span style="font-size:14px;font-weight:700;color:#7c3aed">{u["hours"]}h</span>'
        f'</div>'
        for i, u in enumerate(watchtime[:3])
    ])

    return f"""<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Family Hub · KW {week} · {year}</title>
</head>
<body style="margin:0;padding:20px;background:#02030c;color:white;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:600px;margin:0 auto">

  <div style="text-align:center;padding:32px 0 24px">
    <div style="font-size:11px;letter-spacing:0.12em;text-transform:uppercase;color:rgba(255,255,255,0.38);margin-bottom:10px">Family Hub · KW {week} · {year}</div>
    <div style="font-size:28px;font-weight:800;letter-spacing:-0.5px">Wochennewsletter 🎬</div>
    <div style="font-size:13px;color:rgba(255,255,255,0.4);margin-top:8px">Neu diese Woche · Watchtime · Requests</div>
  </div>

  {"<div style='margin-bottom:32px'><div style='font-size:11px;letter-spacing:0.12em;text-transform:uppercase;color:rgba(255,255,255,0.35);margin-bottom:14px;font-weight:600'>🎬 NEUE FILME</div>" + "".join(media_block(m) for m in movies) + "</div>" if movies else ""}
  {"<div style='margin-bottom:32px'><div style='font-size:11px;letter-spacing:0.12em;text-transform:uppercase;color:rgba(255,255,255,0.35);margin-bottom:14px;font-weight:600'>📺 NEUE SERIEN</div>" + "".join(media_block(s) for s in series) + "</div>" if series else ""}

  <div style="background:rgba(255,255,255,0.05);border-radius:20px;padding:20px;border:1px solid rgba(255,255,255,0.1);margin-bottom:32px">
    <div style="font-size:11px;letter-spacing:0.12em;text-transform:uppercase;color:rgba(255,255,255,0.35);margin-bottom:14px;font-weight:600">📊 WATCHTIME DIESE WOCHE</div>
    {watchtime_rows}
    <div style="margin-top:12px;padding-top:12px;border-top:1px solid rgba(255,255,255,0.07);font-size:13px;color:rgba(255,255,255,0.5)">
      Gesamt: <strong style="color:white">{sum(u['hours'] for u in watchtime):.1f}h</strong>
    </div>
  </div>

  <div style="text-align:center;font-size:11px;color:rgba(255,255,255,0.25);padding-bottom:32px">
    Family Hub · Automatisch generiert via n8n + TMDB + Ollama<br>
    Jeden Freitag um 17:00 · KW {week}/{year}
  </div>
</body>
</html>"""


async def build_newsletter() -> dict:
    """Main entry point - called by the API."""
    now  = datetime.utcnow()
    week = now.isocalendar()[1]
    year = now.year

    # 1. Get new media from Jellyfin
    raw_media = await get_new_media(days=7)

    # 2. Enrich with TMDB
    media = []
    for item in raw_media[:10]:
        enriched = await enrich_with_tmdb(item)
        enriched["ai_summary"] = await generate_summary(
            enriched.get("Name", ""),
            enriched.get("tmdb_overview", enriched.get("Overview", "")),
        )
        media.append(enriched)

    # 3. Watchtime stats
    watchtime = await get_watchtime_stats()

    # 4. Render HTML
    html = render_html(week, year, media, watchtime)

    # 5. Save to archive
    output = {
        "title":    f"KW {week} · {year}",
        "date":     now.strftime("%d. %b %Y"),
        "week":     week,
        "year":     year,
        "count":    len(media),
        "html":     html,
        "media":    [{"name": m.get("Name"), "type": m.get("Type"), "poster": m.get("poster_path")} for m in media],
        "watchtime": watchtime,
    }
    out_file = OUTPUT_DIR / f"kw{week}-{year}.json"
    with open(out_file, "w") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    return {"week": week, "year": year, "count": len(media), "file": str(out_file)}


# ─── Mock data ────────────────────────────────────────────────────────────────
def _mock_media():
    return [
        {"Name": "A Complete Unknown", "Type": "Movie", "Overview": "Bob Dylan Biopic.",
         "ProviderIds": {"Tmdb": "661539"}},
        {"Name": "The Brutalist",      "Type": "Movie", "Overview": "Ein Architekt nach dem Krieg.",
         "ProviderIds": {"Tmdb": "1084736"}},
        {"Name": "Adolescence",        "Type": "Series", "Overview": "Crime Drama.",
         "ProviderIds": {"Tmdb": "242867"}},
    ]

def _mock_watchtime():
    return [
        {"name": "Constantin", "hours": 8.3},
        {"name": "Lena",       "hours": 5.8},
        {"name": "Emma",       "hours": 2.2},
    ]
