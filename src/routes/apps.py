from starlette.responses import RedirectResponse
from fastapi import Request
from fastapi import APIRouter
from ..main import templates

apps = APIRouter()


@apps.get("/apps")
def apps_view(request: Request):
    return templates.TemplateResponse(
        "apps.html", {"request": request, "title": "My apps"}
    )
