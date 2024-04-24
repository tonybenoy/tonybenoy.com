from fastapi import APIRouter, Request, Response
from starlette.responses import RedirectResponse

from src.utils import calculate_svg_sizes, get_svg, templates, update_count

home = APIRouter()


@home.get("/")
@home.get("/index")
async def index(request: Request):
    return templates.TemplateResponse(
        "index.html", {"request": request, "title": "Tony"}
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
async def get_my_ip(request: Request):
    client_ip = request.client.host
    client_ua = request.headers.get("User-Agent")
    return {"ip": client_ip, "my_ua": client_ua}


# @home.get("/counter.svg")
# async def count_app():
#     count = update_count()
#     sizes = calculate_svg_sizes(count)
#     svg = get_svg(count, sizes["width"], sizes["recWidth"], sizes["textX"]).encode(
#         "utf-8"
#     )
#     headers = {"Cache-Control": "no-cache"}
#     return Response(content=svg, media_type="image/svg+xml", headers=headers)
