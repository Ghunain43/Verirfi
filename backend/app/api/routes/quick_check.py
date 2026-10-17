import asyncio
import logging
import time

from fastapi import APIRouter, Depends

from backend.app.api import settings
from backend.app.api.abuse import guard
from backend.app.api.claim_cache import RESULT_KEYS, cache
from backend.app.api.errors import ApiError
from backend.app.api.mock import mock_response
from backend.app.api.schemas import QuickCheckRequest, QuickCheckResponse
from backend.app.api.security_deps import check_rate_limit, require_token
from backend.app.core.fingerprint import compute_fingerprint

log = logging.getLogger("verifi.quick_check")

try:
    from backend.app.agents import VerifiError, run_quick_check
    AGENTS_READY = True
except ImportError as exc:  # e.g. a dependency is missing
    log.warning("agents not importable, using API mock: %s", exc)
    AGENTS_READY = False

    class VerifiError(Exception):
        code = "upstream_failed"

router = APIRouter()


def _ms(start: float) -> int:
    return int((time.perf_counter() - start) * 1000)


@router.post("/quick-check", response_model=QuickCheckResponse)
async def quick_check(req: QuickCheckRequest, token: str = Depends(require_token)):
    check_rate_limit(token)

    if not AGENTS_READY:
        return mock_response(req.text)

    start = time.perf_counter()
    # Fingerprint of the text exactly as selected, so it matches what clients compute.
    fingerprint = compute_fingerprint(req.text)
    guard.check_near_duplicates(token, fingerprint)

    hit = cache.get(fingerprint)
    if hit is not None:  # same claim already checked: skip the slow, paid research
        fields = {k: hit[k] for k in RESULT_KEYS if k in hit}
        return QuickCheckResponse(**fields, fingerprint=fingerprint, cached=True, took_ms=_ms(start))

    try:
        result = await asyncio.wait_for(
            run_quick_check(req.text, req.lang),
            timeout=settings.QUICK_CHECK_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError:
        raise ApiError(504, "timeout", "Check took longer than 25 seconds.")
    except VerifiError as e:
        # log only the code, never the message text (privacy rule)
        log.warning("agent error code=%s", e.code)
        if e.code == "invalid_input":
            raise ApiError(400, "invalid_input", "Empty text, over 2000 chars, or bad lang.")
        if e.code == "timeout":
            raise ApiError(504, "timeout", "Check timed out.")
        raise ApiError(502, "upstream_failed", "Research provider failed.")
    except Exception as e:
        log.error("agent failure: %s", type(e).__name__)
        raise ApiError(502, "upstream_failed", "Research provider failed.")

    data = result.model_dump()
    if data["checkable"]:  # opinions, satire etc. have no verdict worth caching
        cache.put(fingerprint, data)

    return QuickCheckResponse(**data, fingerprint=fingerprint, cached=False, took_ms=_ms(start))
