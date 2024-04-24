from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from src.routes.apps import apps
from src.routes.home import home

# import debugpy
# debugpy.listen(6000)
# debugpy.wait_for_client()


app = FastAPI()


app.mount("/static", StaticFiles(directory="src/static"), name="static")
app.include_router(home)
app.include_router(apps)
