import re

from fastapi import APIRouter, Depends

from backend.app.api import settings
from backend.app.api.claim_cache import cache
from backend.app.api.errors import ApiError
from backend.app.api.mock import CHECKABLE
from backend.app.api.schemas import LookupResponse
from backend.app.api.security_deps import check_rate_limit, require_token

router = APIRouter()
_PREFIX = re.compile(r"[0-9a-fA-F]{4}")

# In mock mode, seed the API.md sample so client developers can try /lookup/a3f1 right away.
if settings.mock_mode():
    cache.put(CHECKABLE["fingerprint"], CHECKABLE)


@router.get("/lookup/{prefix}", response_model=LookupResponse)
async def lookup(prefix: str, token: str = Depends(require_token)):
    """Return every known checked claim whose fingerprint starts with this prefix.
    The client does the final Hamming-distance match, so the server never learns the exact message.
    The prefix is deliberately not logged."""
    if not _PREFIX.fullmatch(prefix):
        raise ApiError(400, "invalid_input", "Prefix must be exactly 4 hex characters.")
    check_rate_limit(token, kind="lookup")
    p = prefix.lower()
    return LookupResponse(prefix=p, entries=cache.bucket(p))
