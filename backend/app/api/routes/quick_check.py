import asyncio
import logging
import time

from fastapi import APIRouter, Depends

from backend.app.api import settings
from backend.app.api.errors import ApiError
from backend.app.api.mock import mock_response
from backend.app.api.schemas import QuickCheckRequest, QuickCheckResponse
from backend.app.api.security_deps import check_rate_limit, require_token
from backend.app.core.fingerprint import compute_fingerprint

router = APIRouter()
log = logging.getLogger("verifi.quick_check")


@router.post("/quick-check", response_model=QuickCheckResponse)
async def quick_check(req: QuickCheckRequest, token: str = Depends(require_token)):
    check_rate_limit(token)
    start = time.perf_counter()

    if settings.mock_mode():
        return mock_response(req.text)

    # Real path: call exactly the function from API.md section 3, nothing else from agents.
    try:
        from app.agents.quick_check import run_quick_check
    except ImportError:
        log.warning("agents not ready, falling back to mock")
        return mock_response(req.text)

    try:
        result = await asyncio.wait_for(
            run_quick_check(req.text, req.lang),
            timeout=settings.QUICK_CHECK_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError:
        raise ApiError(504, "timeout", "Check took longer than 25 seconds.")
    except Exception:
        # never log req.text: the server must not keep message text
        log.exception("agent failure")
        raise ApiError(502, "upstream_failed", "Research provider failed.")

    return QuickCheckResponse(
        **result.model_dump(),
        fingerprint=compute_fingerprint(result.claim),
        cached=False,
        took_ms=int((time.perf_counter() - start) * 1000),
    )
