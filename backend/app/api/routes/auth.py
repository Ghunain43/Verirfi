from fastapi import APIRouter, Request

from backend.app.api import settings
from backend.app.api.abuse import client_ip, guard, network_of
from backend.app.api.schemas import InstallResponse
from backend.app.api.security_deps import issue_token

router = APIRouter()


@router.post("/auth/install", response_model=InstallResponse, status_code=201)
async def install(request: Request):
    guard.check_install(network_of(client_ip(request)))
    return InstallResponse(install_token=issue_token(), expires_in=settings.TOKEN_TTL_SECONDS)
