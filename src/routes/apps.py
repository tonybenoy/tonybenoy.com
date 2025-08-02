import json
import logging

import redis
from fastapi import APIRouter, HTTPException, Request
from redis.exceptions import RedisError
from slowapi import Limiter
from slowapi.util import get_remote_address

from config import get_settings
from utils import get_repo_data_for_user, sort_repos, templates

logger = logging.getLogger(__name__)
limiter = Limiter(key_func=get_remote_address)
apps = APIRouter()


@apps.get("/app")
@limiter.limit("10/minute")
async def apps_view(request: Request):
    """Display GitHub repositories with Redis caching."""
    settings = get_settings()

    try:
        # Initialize Redis connection with proper configuration
        redis_client = redis.Redis(
            host=settings.redis_host,
            port=settings.redis_port,
            db=settings.redis_db,
            password=settings.redis_password,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
        )

        # Try to get cached data
        cache_key = f"github_repos_{settings.github_username}"
        cached_data = redis_client.get(cache_key)

        if cached_data:
            logger.info("Serving repositories from cache")
            repos = json.loads(cached_data)["repos"]
        else:
            logger.info("Fetching fresh repository data from GitHub")
            # Fetch fresh data from GitHub
            url = f"https://api.github.com/users/{settings.github_username}/repos?sort=pushed"

            try:
                repo_data = await get_repo_data_for_user(
                    url=url, github_token=settings.github_token
                )
                repos = sort_repos(repo_data)

                # Cache the data
                cache_data = json.dumps({"repos": repos})
                redis_client.setex(cache_key, settings.redis_cache_ttl, cache_data)
                logger.info(f"Cached {len(repos)} repositories")

            except Exception as e:
                logger.error(f"Failed to fetch GitHub data: {e}")
                raise HTTPException(
                    status_code=503,
                    detail="Unable to fetch repository data at this time",
                ) from e

    except RedisError as e:
        logger.warning(
            f"Redis connection failed: {e}. Falling back to direct GitHub API"
        )
        # Fallback to direct API call without caching
        try:
            url = f"https://api.github.com/users/{settings.github_username}/repos?sort=pushed"
            repo_data = await get_repo_data_for_user(
                url=url, github_token=settings.github_token
            )
            repos = sort_repos(repo_data)
        except Exception as e:
            logger.error(f"Failed to fetch GitHub data without cache: {e}")
            raise HTTPException(
                status_code=503, detail="Service temporarily unavailable"
            ) from e

    return templates.TemplateResponse(
        "apps.html",
        {
            "request": request,
            "title": "My Apps",
            "repos": repos,
            "active_page": "apps",
            "repo_count": len(repos),
        },
    )
