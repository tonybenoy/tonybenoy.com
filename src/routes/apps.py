from fastapi import Request
import httpx
from fastapi import APIRouter
from src.utils import templates, get_repo_data_for_user
from datetime import timedelta
import redis

apps = APIRouter()

r = redis.StrictRedis(host="localhost", port=6379, db=0)


@apps.get("/app")
async def apps_view(request: Request):
    resp = r.get("cached_val")
    if not resp:
        url = "https://api.github.com/users/tonybenoy/repos?sort=pushed"
        resp = []
        resp = get_repo_data_for_user(url=url, response=[])
        r.setex(name="cached_val", time=timedelta(minutes=60), value=resp)
    return templates.TemplateResponse(
        "apps.html", {"request": request, "title": "My apps", "repos": resp}
    )
