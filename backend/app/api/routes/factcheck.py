import hmac
import json
import re
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Header, Request, Response

from backend.app.api import settings
from backend.app.api.abuse import client_ip, guard, network_of
from backend.app.api.errors import ApiError
from backend.app.api.factcheck_store import store
from backend.app.api.schemas import FactCheckList, FactCheckRequest, PublicKeyResponse, SignedFactCheck
from backend.app.api.security_deps import check_rate_limit
from backend.app.api.signing import get_signer

router = APIRouter()
_ID = re.compile(r"[0-9a-f]{32}")


def _match_key(provided: Optional[str]) -> Optional[str]:
    """Constant-time comparison against every configured key. Returns the publisher name."""
    if not provided:
        return None
    found = None
    for name, key in settings.factcheck_keys().items():
        if hmac.compare_digest(provided.encode("utf-8"), key.encode("utf-8")) and found is None:
            found = name
    return found


def require_factchecker(request: Request, x_api_key: Optional[str] = Header(default=None)) -> str:
    """Fact-checker API key in the X-API-Key header. Install tokens are NOT accepted here."""
    network = network_of(client_ip(request))
    guard.check_key_failures(network)
    publisher = _match_key(x_api_key)
    if publisher is None:
        guard.key_failure(network)
        raise ApiError(401, "invalid_token", "Missing or invalid fact-checker API key.")
    return publisher


def _public(record: dict) -> dict:
    return {k: record[k] for k in ("id", "payload", "signature", "key_id")}


@router.get("/factcheck/public-key", response_model=PublicKeyResponse)
async def public_key():
    s = get_signer()
    return PublicKeyResponse(key_id=s.key_id, algorithm="ed25519", public_key=s.public_key)


@router.post("/factcheck", response_model=SignedFactCheck, status_code=201)
async def publish(req: FactCheckRequest, publisher: str = Depends(require_factchecker)):
    """Publish (or replace) this publisher's signed response to a claim fingerprint.
    Clients receive it through GET /lookup/{prefix} in each entry's `factchecks` list."""
    check_rate_limit(f"fc:{publisher}", kind="factcheck")
    signer = get_signer()
    record_id = uuid.uuid4().hex
    published_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    payload = json.dumps(
        {
            "v": 1,
            "id": record_id,
            "fingerprint": req.fingerprint,
            "claim": req.claim,
            "rating": req.rating,
            "summary": req.summary,
            "source_url": req.source_url,
            "publisher": publisher,
            "published_at": published_at,
        },
        sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    )
    record = {
        "id": record_id, "payload": payload, "signature": signer.sign(payload), "key_id": signer.key_id,
        "fingerprint": req.fingerprint, "claim": req.claim, "publisher": publisher, "published_at": published_at,
    }
    store.publish(record)
    return _public(record)


@router.get("/factcheck", response_model=FactCheckList)
async def list_own(publisher: str = Depends(require_factchecker)):
    check_rate_limit(f"fc:{publisher}", kind="factcheck")
    return FactCheckList(items=[_public(r) for r in store.list_for(publisher)])


@router.delete("/factcheck/{record_id}", status_code=204)
async def retract(record_id: str, publisher: str = Depends(require_factchecker)):
    """Retract one of your own responses. Clients that already fetched it keep it until they refresh."""
    check_rate_limit(f"fc:{publisher}", kind="factcheck")
    if not _ID.fullmatch(record_id) or not store.delete(record_id, publisher):
        raise ApiError(404, "not_found", "No such response.")
    return Response(status_code=204)
