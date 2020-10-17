from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from routes.home import home
# from .routes.apps import apps
import os

app = FastAPI()

app.mount("/static", StaticFiles(directory="static"), name="static")
app.include_router(home)

# app.include_router(apps)
