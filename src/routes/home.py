from starlette.responses import RedirectResponse
from fastapi import Request,Response
from fastapi import APIRouter

home = APIRouter()
from utils import templates,get_svg,calculate_svg_sizes,update_count


@home.get("/")
@home.get("/index")
async def index(request: Request):
    return templates.TemplateResponse(
        "index.html", {"request": request, "title": "Tony"}
    )


@home.get("/contact")
async def contact(request: Request):
    return templates.TemplateResponse(
        "contact.html", {"request": request, "title": "Contact Me"}
    )


@home.get("/favicon.ico")
async def favicon():
    return RedirectResponse(url="/static/img/favicon.ico")


@home.get("/myssh")
async def myssh():
    return RedirectResponse(url="/static/files/tony.sh")


@home.get("/noaccess3549987")
def get_my_ip(request: Request):
    client_ip = request.client.host
    client_ua = request.headers.get("User-Agent")
    return {"ip": client_ip, "my_ua": client_ua}


@home.get("/counter.svg")
def count_app():
    count = update_count()
    sizes = calculate_svg_sizes(count)
    svg = get_svg(count, sizes["width"], sizes["recWidth"], sizes["textX"]).encode(
        "utf-8"
    )
    headers = {"Cache-Control": "no-cache"}
    return Response(content=svg, media_type="image/svg+xml",headers=headers)
