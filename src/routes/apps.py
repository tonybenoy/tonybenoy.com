from fastapi import Request
import redis
import json
from fastapi import APIRouter
from src.utils import templates, get_repo_data_for_user
from datetime import timedelta

apps = APIRouter()


@apps.get("/app")
async def apps_view(request: Request):
    r = redis.Redis()
    resp = r.get("cached_val")
    if not resp:
        url = "https://api.github.com/users/tonybenoy/repos?sort=pushed"
        resp = []
        resp = get_repo_data_for_user(url=url, response=[])
        r.set(name="cached_val", value=json.dumps({"repos": resp}))
    else:
        resp = json.loads(resp)["repos"]
    return templates.TemplateResponse(
        "apps.html", {"request": request, "title": "My apps", "repos": resp}
    )
