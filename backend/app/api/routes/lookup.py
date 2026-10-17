import re

from fastapi import APIRouter, Depends

from backend.app.api import settings
from backend.app.api.claim_cache import cache
from backend.app.api.errors import ApiError
from backend.app.api.factcheck_store import store as factchecks
from backend.app.api.mock import CHECKABLE
from backend.app.api.schemas import LookupResponse
from backend.app.api.security_deps import check_rate_limit, require_token

router = APIRouter()
_PREFIX = re.compile(r"[0-9a-fA-F]{4}")

# In mock mode, seed the API.md sample so client developers can try /lookup/a3f1 right away.
if settings.mock_mode():
    cache.put(CHECKABLE["fingerprint"], CHECKABLE)


def _public(record: dict) -> dict:
    return {k: record[k] for k in ("id", "payload", "signature", "key_id")}


@router.get("/lookup/{prefix}", response_model=LookupResponse)
async def lookup(prefix: str, token: str = Depends(require_token)):
    """Return every known checked claim whose fingerprint starts with this prefix, with any signed
    fact-checker responses attached. The client does the final Hamming-distance match, so the server
    never learns the exact message. Our code does not log the prefix, and privacy_logging.py keeps
    uvicorn's access log from doing so either."""
    if not _PREFIX.fullmatch(prefix):
        raise ApiError(400, "invalid_input", "Prefix must be exactly 4 hex characters.")
    check_rate_limit(token, kind="lookup")
    p = prefix.lower()

    official = factchecks.bucket(p)  # fingerprint -> signed responses, newest first
    entries = []
    for e in cache.bucket(p):
        entries.append({**e, "factchecks": [_public(r) for r in official.pop(e["fingerprint"], [])]})
    for fp, records in official.items():  # fact-checked but never AI-checked: minimal entry
        entries.append({
            "fingerprint": fp, "claim": records[0]["claim"], "likely_answer": None,
            "confidence_low": 0.0, "confidence_high": 0.0, "evidence": [],
            "checked_at": records[0]["published_at"], "factchecks": [_public(r) for r in records],
        })
    entries.sort(key=lambda e: e["fingerprint"])
    return LookupResponse(prefix=p, entries=entries)
