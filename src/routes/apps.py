from fastapi import Request
import httpx
from fastapi import APIRouter
from src.utils import templates, get_repo_data_for_user

apps = APIRouter()


@apps.get("/app")
async def apps_view(request: Request):
    url = "https://api.github.com/users/tonybenoy/repos?sort=pushed"
    resp = []
    resp = get_repo_data_for_user(url=url, response=[])

    return templates.TemplateResponse(
        "apps.html", {"request": request, "title": "My apps", "repos": resp}
    )
