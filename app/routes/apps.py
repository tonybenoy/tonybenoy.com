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

    return templates.TemplateResponse(
        request,
        "apps.html",
        {
            "title": "My Apps",
            "repos": repos,
            "active_page": "apps",
            "repo_count": len(repos),
        },
    )
