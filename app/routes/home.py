import logging

from fastapi import APIRouter, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.responses import RedirectResponse

from app.utils import templates

# Use the same limiter instance as main app
limiter = Limiter(key_func=get_remote_address)

logger = logging.getLogger(__name__)
home = APIRouter()


@home.get("/")
@home.get("/index")
@limiter.limit("30/minute")
async def index(request: Request):
    """Home page with rate limiting."""
    return templates.TemplateResponse(
        request, "index.html", {"title": "Tony", "active_page": "home"}
    )


@home.get("/test")
async def test():
    return {"result": "It works!"}


@home.get("/favicon.ico")
async def favicon():
    return RedirectResponse(url="/static/img/favicon.ico")


@home.get("/myssh")
async def myssh():
    return RedirectResponse(url="/static/files/tony.sh")


@home.get("/client_ip")
@limiter.limit("10/minute")
async def get_my_ip(request: Request):
    """Get client IP and user agent information."""
    client_ip = request.client.host if request.client else "unknown"
    client_ua = request.headers.get("User-Agent")
    forwarded_for = request.headers.get("X-Forwarded-For")
    real_ip = request.headers.get("X-Real-IP")

    return {
        "ip": client_ip,
        "user_agent": client_ua,
        "x_forwarded_for": forwarded_for,
        "x_real_ip": real_ip,
    }


@home.get("/health")
async def health_check():
    """Health check endpoint for monitoring."""
    return {
        "status": "healthy",
        "timestamp": "2025-01-01T00:00:00Z",  # Dynamic in real implementation
        "version": "2.0.0",
    }


@home.get("/metrics")
@limiter.limit("5/minute")
async def metrics(request: Request):
    """Basic metrics endpoint."""
    import time

    try:
        import psutil
    except ImportError:
        return {"status": "ok", "message": "Detailed metrics not available"}

    return {
        "uptime": time.time(),  # Would track actual uptime
        "memory_usage": psutil.virtual_memory().percent,
        "cpu_usage": psutil.cpu_percent(),
        "disk_usage": psutil.disk_usage("/").percent,
        "requests_total": "N/A",  # Would implement proper metrics
        "status": "ok",
    }
