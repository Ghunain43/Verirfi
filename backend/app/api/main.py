from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.app.api import settings
from backend.app.api.errors import register_error_handlers
from backend.app.api.routes import auth, quick_check

VERSION = "0.1.0"

app = FastAPI(title="Verifi API", version=VERSION)
register_error_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins(),  # explicit list, e.g. chrome-extension://<id>
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["Retry-After"],
)

v1 = APIRouter(prefix="/api/v1")
v1.include_router(auth.router)
v1.include_router(quick_check.router)


@v1.get("/health")
async def health():
    return {"status": "ok", "version": VERSION}


app.include_router(v1)


@app.get("/health")  # also at root, in case clients call it without the prefix
async def health_root():
    return {"status": "ok", "version": VERSION}
