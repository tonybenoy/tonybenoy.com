import logging

from fastapi import APIRouter, Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.utils import templates

# Use the same limiter instance as main app
limiter = Limiter(key_func=get_remote_address)

logger = logging.getLogger(__name__)
photography = APIRouter()


@photography.get("/photography")
@limiter.limit("30/minute")
async def photography_page(request: Request):
    """Photography gallery page with embedded Instagram feed."""
    return templates.TemplateResponse(
        request,
        "photography.html",
        {
            "title": "Tony Benoy Photography - Travel & Life Moments",
            "description": "Discover Tony Benoy's photography collection featuring travel experiences, life moments, and artistic captures. Follow his visual journey across Estonia and beyond.",
            "active_page": "photography",
            "instagram_username": "tonybenoy",
        },
    )
