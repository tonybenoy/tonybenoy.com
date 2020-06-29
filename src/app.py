from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from starlette.responses import RedirectResponse


app = FastAPI()

app.mount("/static", StaticFiles(directory="src/static"), name="static")
templates = Jinja2Templates(directory="src/templates")


@app.get("/")
async def index(request: Request):
    return templates.TemplateResponse(
        "index.html", {"request": request, "title": "Tony"}
    )


@app.get("/contact")
async def contact(request: Request):
    return templates.TemplateResponse(
        "contact.html", {"request": request, "title": "Contact Me"}
    )


@app.get("/myssh")
async def myssh(request: Request):
    return RedirectResponse(url="/static/files/tony.sh")


@app.get("/noaccess3549987")
def get_my_ip(request: Request):
    client_ip = request.client.host
    client_ua = request.headers.get("User-Agent")
    return {"ip": client_ip, "my_ua": client_ua}
