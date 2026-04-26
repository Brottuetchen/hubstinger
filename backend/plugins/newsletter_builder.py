"""
Newsletter Builder Plugin
Fetches Jellyfin data, enriches with TMDB metadata, generates Ollama summaries,
and renders the weekly Family Hub newsletter HTML.
"""

import json
from datetime import datetime, timedelta
from pathlib import Path

import httpx

OUTPUT_DIR = Path(__file__).parent.parent.parent / "newsletters"
OUTPUT_DIR.mkdir(exist_ok=True)


async def get_new_media(
    jellyfin_url: str,
    jellyfin_token: str,
    days: int = 7,
) -> list[dict]:
    """Fetch recently added items from Jellyfin."""
    if not jellyfin_url or not jellyfin_token:
        return []

    since = (datetime.utcnow() - timedelta(days=days)).isoformat()
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(
            f"{jellyfin_url}/Items",
            headers={"X-Emby-Token": jellyfin_token},
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
        return response.json().get("Items", [])


async def enrich_with_tmdb(item: dict, tmdb_api_key: str) -> dict:
    """Add TMDB poster, rating, runtime and genres to a Jellyfin item."""
    if not tmdb_api_key:
        return item

    tmdb_id = item.get("ProviderIds", {}).get("Tmdb")
    if not tmdb_id:
        return item

    media_type = "movie" if item.get("Type") == "Movie" else "tv"
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(
            f"https://api.themoviedb.org/3/{media_type}/{tmdb_id}",
            params={"api_key": tmdb_api_key, "language": "de-DE"},
        )
        tmdb = response.json()
        item["poster_path"] = tmdb.get("poster_path")
        item["vote_average"] = tmdb.get("vote_average")
        item["runtime"] = tmdb.get("runtime") or (tmdb.get("episode_run_time") or [None])[0]
        item["genres"] = [genre["name"] for genre in tmdb.get("genres", [])[:2]]
        item["tmdb_overview"] = tmdb.get("overview", "")
    return item


async def generate_summary(
    title: str,
    overview: str,
    ollama_url: str,
    ollama_model: str,
) -> str:
    """Use Ollama to write a short German summary."""
    if not overview or not ollama_url:
        return overview[:200]

    prompt = (
        f"Schreib eine kurze, ansprechende Zusammenfassung auf Deutsch "
        f"(maximal 2 Saetze, ohne Spoiler) fuer '{title}'. Originaltext: {overview}"
    )
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                f"{ollama_url}/api/generate",
                json={"model": ollama_model, "prompt": prompt, "stream": False},
            )
            return response.json().get("response", overview[:200])
    except Exception:
        return overview[:200]


async def get_watchtime_stats(
    jellyfin_url: str,
    jellyfin_token: str,
) -> list[dict]:
    """
    Get per-user watchtime from the Jellyfin playback reporting plugin.
    Returns an empty list if no backend data is available.
    """
    if not jellyfin_url or not jellyfin_token:
        return []

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(
                f"{jellyfin_url}/user_usage_stats/user_activity",
                headers={"X-Emby-Token": jellyfin_token},
                params={"days": 7, "end_date": datetime.utcnow().strftime("%Y-%m-%d")},
            )
            data = response.json()
            return [
                {
                    "name": item.get("user_name"),
                    "hours": round(item.get("total_play_duration", 0) / 3600, 1),
                }
                for item in data
            ]
    except Exception:
        return []


def render_html(
    week: int,
    year: int,
    media: list[dict],
    watchtime: list[dict],
    jellyseerr_url: str,
) -> str:
    """Render the newsletter as HTML."""
    movies = [item for item in media if item.get("Type") == "Movie"][:5]
    series = [item for item in media if item.get("Type") in ("Series", "Episode")][:3]

    def media_block(item: dict) -> str:
        poster = (
            f"https://image.tmdb.org/t/p/w342{item['poster_path']}"
            if item.get("poster_path")
            else ""
        )
        rating = f"★ {item['vote_average']:.1f}" if item.get("vote_average") else ""
        runtime = f"{item['runtime']} min" if item.get("runtime") else ""
        genres = " · ".join(item.get("genres", []))
        summary = item.get("ai_summary", item.get("tmdb_overview", "")[:200])
        tmdb_id = item.get("ProviderIds", {}).get("Tmdb", "")
        if jellyseerr_url and tmdb_id:
            media_path = "movie" if item.get("Type") == "Movie" else "tv"
            request_url = f"{jellyseerr_url}/{media_path}/{tmdb_id}"
            request_button = (
                f'<a href="{request_url}" '
                'style="display:inline-block;background:rgba(124,58,237,0.3);'
                'border:1px solid rgba(124,58,237,0.5);color:white;'
                'text-decoration:none;border-radius:10px;padding:7px 14px;'
                'font-size:12px;font-weight:600">Anfragen</a>'
            )
        else:
            request_button = ""

        return f"""
        <div style="display:flex;gap:16px;margin-bottom:24px;background:rgba(255,255,255,0.04);border-radius:16px;padding:16px;border:1px solid rgba(255,255,255,0.1)">
          {"<img src='" + poster + "' style='width:80px;height:120px;border-radius:10px;object-fit:cover;flex-shrink:0'>" if poster else "<div style='width:80px;height:120px;border-radius:10px;background:rgba(255,255,255,0.08);flex-shrink:0'></div>"}
          <div style="flex:1">
            <div style="font-size:16px;font-weight:700;margin-bottom:6px">{item.get("Name", "")}</div>
            <div style="font-size:12px;color:rgba(255,255,255,0.5);margin-bottom:8px">{rating} {'·' if rating and runtime else ''} {runtime} {'·' if genres else ''} {genres}</div>
            <div style="font-size:13px;color:rgba(255,255,255,0.65);line-height:1.5;margin-bottom:12px">{summary}</div>
            {request_button}
          </div>
        </div>
        """

    medals = ["🥇", "🥈", "🥉"]
    watchtime_rows = "".join(
        [
            f'<div style="display:flex;align-items:center;gap:12px;margin-bottom:8px">'
            f'<span style="font-size:18px">{medals[index] if index < len(medals) else "•"}</span>'
            f'<span style="flex:1;font-size:14px">{user["name"]}</span>'
            f'<span style="font-size:14px;font-weight:700;color:#7c3aed">{user["hours"]}h</span>'
            f"</div>"
            for index, user in enumerate(watchtime[:3])
        ]
    )

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
    <div style="font-size:28px;font-weight:800;letter-spacing:-0.5px">Wochennewsletter</div>
    <div style="font-size:13px;color:rgba(255,255,255,0.4);margin-top:8px">Neu diese Woche · Watchtime · Requests</div>
  </div>

  {"<div style='margin-bottom:32px'><div style='font-size:11px;letter-spacing:0.12em;text-transform:uppercase;color:rgba(255,255,255,0.35);margin-bottom:14px;font-weight:600'>NEUE FILME</div>" + "".join(media_block(item) for item in movies) + "</div>" if movies else ""}
  {"<div style='margin-bottom:32px'><div style='font-size:11px;letter-spacing:0.12em;text-transform:uppercase;color:rgba(255,255,255,0.35);margin-bottom:14px;font-weight:600'>NEUE SERIEN</div>" + "".join(media_block(item) for item in series) + "</div>" if series else ""}

  <div style="background:rgba(255,255,255,0.05);border-radius:20px;padding:20px;border:1px solid rgba(255,255,255,0.1);margin-bottom:32px">
    <div style="font-size:11px;letter-spacing:0.12em;text-transform:uppercase;color:rgba(255,255,255,0.35);margin-bottom:14px;font-weight:600">WATCHTIME DIESE WOCHE</div>
    {watchtime_rows}
    <div style="margin-top:12px;padding-top:12px;border-top:1px solid rgba(255,255,255,0.07);font-size:13px;color:rgba(255,255,255,0.5)">
      Gesamt: <strong style="color:white">{sum(user['hours'] for user in watchtime):.1f}h</strong>
    </div>
  </div>

  <div style="text-align:center;font-size:11px;color:rgba(255,255,255,0.25);padding-bottom:32px">
    Family Hub · Automatisch generiert via n8n + TMDB + Ollama<br>
    Jeden Freitag um 17:00 · KW {week}/{year}
  </div>
</body>
</html>"""


async def build_newsletter(
    jellyfin_url: str = "",
    jellyfin_token: str = "",
    tmdb_api_key: str = "",
    ollama_url: str = "",
    ollama_model: str = "llama3.2",
    jellyseerr_url: str = "",
) -> dict:
    """Main entry point called by the API."""
    now = datetime.utcnow()
    week = now.isocalendar()[1]
    year = now.year

    raw_media = await get_new_media(jellyfin_url, jellyfin_token, days=7)

    media = []
    for item in raw_media[:10]:
        enriched = await enrich_with_tmdb(item, tmdb_api_key)
        enriched["ai_summary"] = await generate_summary(
            enriched.get("Name", ""),
            enriched.get("tmdb_overview", enriched.get("Overview", "")),
            ollama_url,
            ollama_model,
        )
        media.append(enriched)

    watchtime = await get_watchtime_stats(jellyfin_url, jellyfin_token)
    html = render_html(week, year, media, watchtime, jellyseerr_url)

    output = {
        "title": f"KW {week} · {year}",
        "date": now.strftime("%d. %b %Y"),
        "week": week,
        "year": year,
        "count": len(media),
        "html": html,
        "media": [
            {
                "name": item.get("Name"),
                "type": item.get("Type"),
                "poster": item.get("poster_path"),
            }
            for item in media
        ],
        "watchtime": watchtime,
    }
    out_file = OUTPUT_DIR / f"kw{week}-{year}.json"
    with open(out_file, "w", encoding="utf-8") as file:
        json.dump(output, file, ensure_ascii=False, indent=2)

    return {"week": week, "year": year, "count": len(media), "file": str(out_file)}
