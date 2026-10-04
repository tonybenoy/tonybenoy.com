from fastapi import APIRouter
from fastapi.responses import RedirectResponse

photography = APIRouter()

VSCO_URL = "https://vsco.co/tonybenoy"


@photography.get("/photography", include_in_schema=False)
async def photography_redirect():
    """Photos live on VSCO; keep old /photography links working."""
    return RedirectResponse(url=VSCO_URL, status_code=302)
