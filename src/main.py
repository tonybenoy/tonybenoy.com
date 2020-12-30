from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

# import debugpy
# debugpy.listen(6000)
# debugpy.wait_for_client()


from src.routes.home import home
from src.routes.apps import apps

app = FastAPI()


app.mount("/static", StaticFiles(directory="src/static"), name="static")
app.include_router(home)
app.include_router(apps)
