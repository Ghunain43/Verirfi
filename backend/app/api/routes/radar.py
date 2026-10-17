from datetime import timedelta

from fastapi import APIRouter, Depends

from backend.app.api import settings
from backend.app.api.claim_cache import cache
from backend.app.api.radar_store import _utcnow, radar_store
from backend.app.api.schemas import RadarResponse
from backend.app.api.security_deps import check_rate_limit, require_token
from backend.app.api.web_radar import top_false_claims

router = APIRouter()

# In mock mode, seed a few trending claims so the Rumor Radar page has something to show locally
# (a real run needs 10 installs on 3 networks, which is hard to fake on localhost).
_SEED = (
    ("a3f19c2b7d4e8a01", "Drinking hot water cures dengue fever.", 42, 48),
    ("77aa10c4be92d3e5", "Free laptops are being given to all students this week.", 27, 24),
    ("0be4f7a19c3d5521", "Petrol will be unavailable from tomorrow.", 13, 6),
)


def seed_demo() -> None:
    now = _utcnow()
    for fp, claim, installs, hours_ago in _SEED:
        for i in range(installs):
            radar_store.record(fp, claim, f"seed-{fp}-{i}", f"10.{i % 7}.{i}.1",
                               now=now - timedelta(hours=hours_ago) + timedelta(minutes=i))


if settings.mock_mode():
    seed_demo()


@router.get("/radar", response_model=RadarResponse)
async def radar(token: str = Depends(require_token)):
    """Community rumors (N installs on M networks), topped up to 5 with web-found false claims."""
    check_rate_limit(token, kind="radar")
    items = radar_store.trending(
        settings.radar_min_installs(), settings.radar_min_networks(), settings.radar_window_hours()
    )
    for i in items:  # if this claim was already fact-checked here, reuse that verdict as the reason
        hit = cache.get(i["fingerprint"])
        i["why"] = (hit or {}).get("likely_answer") or None
    target = settings.radar_fill_to()
    if len(items) < target:  # not enough community rumors: fill up with false claims found on the web
        seen = {i["fingerprint"] for i in items}
        for w in await top_false_claims(target):
            if len(items) >= target:
                break
            if w["fingerprint"] not in seen:
                items.append(w)
                seen.add(w["fingerprint"])
    return RadarResponse(items=items)
