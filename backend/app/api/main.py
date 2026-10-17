from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.app.api import privacy_logging, settings
from backend.app.api.errors import register_error_handlers
from backend.app.api.routes import auth, factcheck, lookup, quick_check, report

VERSION = "0.1.0"

privacy_logging.install()

app = FastAPI(title="Verifi API", version=VERSION)
register_error_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins(),  # explicit list, e.g. chrome-extension://<id>
    allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
    expose_headers=["Retry-After"],
)

v1 = APIRouter(prefix="/api/v1")
v1.include_router(auth.router)
v1.include_router(quick_check.router)
v1.include_router(lookup.router)
v1.include_router(report.router)
v1.include_router(factcheck.router)


@v1.get("/health")
async def health():
    return {"status": "ok", "version": VERSION}


app.include_router(v1)


@app.get("/health")  # also at root, in case clients call it without the prefix
async def health_root():
    return {"status": "ok", "version": VERSION}
