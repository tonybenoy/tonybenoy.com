import json

import redis
from fastapi import APIRouter, Request

from src.utils import get_repo_data_for_user, templates, sort_repos

apps = APIRouter()


@apps.get("/app")
async def apps_view(request: Request):
    r = redis.Redis(host="redis_db")
    resp = r.get("cached_val")
    if not resp:
        url = "https://api.github.com/users/tonybenoy/repos?sort=pushed"
        resp = []
        resp = sort_repos(get_repo_data_for_user(url=url, response=[]))
        print(resp)
        r.set(name="cached_val", value=json.dumps({"repos": resp}))
    else:
        resp = json.loads(resp)["repos"]
    return templates.TemplateResponse(
        "apps.html",
        {"request": request, "title": "My apps", "repos": resp, "active_page": "other"},
    )
