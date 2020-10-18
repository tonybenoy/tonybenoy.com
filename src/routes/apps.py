from fastapi import Request
import httpx
from fastapi import APIRouter
from src.utils import templates

apps = APIRouter()


@apps.get("/apps")
async def apps_view(request: Request):
    url = "https://api.github.com/users/tonybenoy/repos?sort=pushed"
    async with httpx.AsyncClient() as client:
        repos = await client.get(url=url)
    return templates.TemplateResponse(
        "apps.html", {"request": request, "title": "My apps", "repos": repos.json()}
    )
