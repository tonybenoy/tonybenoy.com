import logging
import time
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import get_settings
from app.utils import get_repo_data_for_user, sort_repos, templates

logger = logging.getLogger(__name__)
limiter = Limiter(key_func=get_remote_address)
apps = APIRouter()

# Simple in-memory cache
_cache: dict[str, dict[str, Any]] = {}


def _get_cached_data(cache_key: str, ttl: int) -> Any | None:
    """Get data from cache if it exists and is not expired."""
    if cache_key not in _cache:
        return None

    cache_entry = _cache[cache_key]
    if time.time() - cache_entry["timestamp"] > ttl:
        del _cache[cache_key]
        return None

    return cache_entry["data"]


def _set_cache_data(cache_key: str, data: Any) -> None:
    """Store data in cache with timestamp."""
    _cache[cache_key] = {"data": data, "timestamp": time.time()}


@apps.get("/app")
@limiter.limit("10/minute")
async def apps_view(request: Request):
    """Display GitHub repositories with in-memory caching."""
    settings = get_settings()

    cache_key = f"github_repos_{settings.github_username}"
    cached_repos = _get_cached_data(cache_key, settings.cache_ttl)

    if cached_repos is not None:
        logger.info("Serving repositories from cache")
        repos = cached_repos
    else:
        logger.info("Fetching fresh repository data from GitHub")
        try:
            url = f"https://api.github.com/users/{settings.github_username}/repos?sort=pushed"
            repo_data = await get_repo_data_for_user(
                url=url, github_token=settings.github_token
            )
            repos = sort_repos(repo_data)

            # Cache the data
            _set_cache_data(cache_key, repos)
            logger.info(f"Cached {len(repos)} repositories")

        except Exception as e:
            logger.error(f"Failed to fetch GitHub data: {e}")
            raise HTTPException(
                status_code=503,
                detail="Unable to fetch repository data at this time",
            ) from e

    # Curated featured projects with context
    featured_projects = [
        {
            "name": "Sigyn",
            "label": "Open Source",
            "description": (
                "An open-source, serverless secret manager written in Rust. "
                "Keeps API keys, database credentials, and app secrets "
                "encrypted at rest and synced via git — no hosted "
                "infrastructure required. End-to-end encryption, role-based "
                "access control, and process injection built in."
            ),
            "url": "https://sigyn.org",
            "language": "Rust",
            "stats": ["sigyn.org", "Serverless", "Git-native sync"],
        },
        {
            "name": "Treening",
            "label": "Side Project",
            "description": (
                "A privacy-first fitness app that runs entirely in the "
                "browser. Log workouts, track sets and reps, visualize "
                "progress — all offline, no account needed, no data "
                "collected. Includes an AI workout assistant powered by "
                "WebGPU."
            ),
            "url": "https://treen.ing",
            "language": None,
            "stats": ["treen.ing", "Offline-first", "AI assistant"],
        },
        {
            "name": "cocapi",
            "label": "Published Library",
            "description": (
                "Python wrapper for the official Clash of Clans API with "
                "sync and async support, automatic key management, "
                "caching, retries, and optional Pydantic models for "
                "type-safe responses. Published on PyPI."
            ),
            "url": "https://tonybenoy.github.io/cocapi/",
            "language": "Python",
            "stats": ["PyPI published", "Async support", "Pydantic models"],
        },
        {
            "name": "tonybenoy.com",
            "label": "This Website",
            "description": (
                "The site you're on right now. FastAPI + Jinja2, deployed "
                "with Docker and nginx. Features an interactive terminal, "
                "in-browser AI chat via WebLLM, and a Matrix easter egg."
            ),
            "url": "https://github.com/tonybenoy/tonybenoy.com",
            "language": "Python",
            "stats": ["FastAPI", "Docker", "WebLLM"],
        },
    ]

    return templates.TemplateResponse(
        request,
        "apps.html",
        {
            "title": "Projects — Tony Benoy",
            "description": (
                "Sigyn — a Rust serverless secret manager (sigyn.org). "
                "Treening — a privacy-first fitness app (treen.ing). "
                "cocapi — Python Clash of Clans API wrapper on PyPI. "
                "Plus more open source on GitHub."
            ),
            "featured_projects": featured_projects,
            "repos": repos,
            "active_page": "apps",
            "repo_count": len(repos),
        },
    )
