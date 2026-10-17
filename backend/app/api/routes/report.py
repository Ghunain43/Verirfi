from fastapi import APIRouter, Depends

from backend.app.api import settings
from backend.app.api.claim_cache import cache
from backend.app.api.report_store import store
from backend.app.api.schemas import RadarResponse, ReportRequest
from backend.app.api.security_deps import check_rate_limit, require_token
from backend.app.core.fingerprint import compute_fingerprint

router = APIRouter()


def _claim_for(fingerprint: str) -> str:
    """Claim text if this fingerprint was checked on this server, otherwise empty.
    The server never learns the text of a reported message, only its fingerprint."""
    entry = cache.get(fingerprint)
    return entry["claim"] if entry else ""


@router.post("/report", status_code=202)
async def report(req: ReportRequest, token: str = Depends(require_token)):
    """Opt-in anonymous report. Clients apply randomized-response noise before sending:
    with probability 0.25 they send a random fingerprint instead of the real one.
    Random fingerprints never reach the radar threshold, real rumors do.
    The region is validated and deliberately discarded."""
    check_rate_limit(token, kind="report")
    store.add(token, req.fingerprint)
    return {}


@router.get("/radar", response_model=RadarResponse)
async def radar(token: str = Depends(require_token)):
    check_rate_limit(token, kind="radar")
    return RadarResponse(items=store.radar(settings.radar_min_reports(), _claim_for))


# In mock mode, seed a few trending claims so the web radar page can be built before real reports exist.
if settings.mock_mode():
    _DEMO = [
        ("a3f19c2b7d4e8a01", "Drinking hot water cures dengue fever.", 14),
        ("527daef0465c7fb2", "All schools will stay closed next week because of flooding.", 11),
        (compute_fingerprint("Free petrol coupons are being given on WhatsApp"),
         "Free petrol coupons are being given on WhatsApp.", 10),
    ]
    for _fp, _claim, _n in _DEMO:
        cache.put(_fp, {"checkable": True, "claim": _claim})
        for _i in range(_n):
            store.add(f"demo-install-{_i}", _fp)
