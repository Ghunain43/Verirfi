"""Install tokens (signed, stateless) + rate limiting (in-memory, per instance)."""
import hashlib
import hmac
import os
import secrets
import time
from collections import defaultdict, deque

from fastapi import Header

from backend.app.api import settings
from backend.app.api.errors import ApiError

_fallback_secret = secrets.token_hex(32)     # used only when TOKEN_SECRET is not set (dev)
_hits: dict[str, deque] = defaultdict(deque)  # "kind:token" -> timestamps


def _sign(body: str) -> str:
    key = (os.getenv("TOKEN_SECRET") or _fallback_secret).encode()
    return hmac.new(key, body.encode(), hashlib.sha256).hexdigest()[:40]


def issue_token() -> str:
    """Signed, self-validating token (expiry.nonce.signature). Nothing is stored server-side, so every
    replica accepts it and a restart or scale-to-zero does not invalidate it (set TOKEN_SECRET in production)."""
    body = f"{int(time.time()) + settings.TOKEN_TTL_SECONDS}.{secrets.token_urlsafe(16)}"
    return f"{body}.{_sign(body)}"


def require_token(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise ApiError(401, "invalid_token", "Missing install token.")
    token = authorization[len("Bearer "):].strip()
    body, _, sig = token.rpartition(".")
    exp = body.split(".", 1)[0]
    if not body or not exp.isdigit() or not hmac.compare_digest(sig, _sign(body)) or int(exp) < time.time():
        raise ApiError(401, "invalid_token", "Invalid or expired install token.")
    return token


def check_rate_limit(token: str, kind: str = "quick-check") -> None:
    """Sliding one-hour window per token. Each kind of call has its own counter and limit."""
    limit = settings.rate_limit_per_hour() if kind == "quick-check" else settings.lookup_rate_limit_per_hour()
    now = time.time()
    window = 3600
    q = _hits[f"{kind}:{token}"]
    while q and q[0] <= now - window:
        q.popleft()
    if len(q) >= limit:
        retry_after = max(1, int(q[0] + window - now))
        raise ApiError(429, "rate_limited", "Too many requests. Try again later.",
                       headers={"Retry-After": str(retry_after)})
    q.append(now)


def reset_state() -> None:  # for tests
    _hits.clear()
