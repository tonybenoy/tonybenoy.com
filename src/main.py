from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import redis
from src.routes.home import home
from src.routes.apps import apps

app = FastAPI()

r = redis.StrictRedis(host="localhost", port=6379, db=0)
app.mount("/static", StaticFiles(directory="src/static"), name="static")
app.include_router(home)
app.include_router(apps)
