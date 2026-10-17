"""Install tokens + rate limiting. In-memory for now; move to security/ when it grows."""
import secrets
import time
from collections import defaultdict, deque

from fastapi import Header

from backend.app.api import settings
from backend.app.api.errors import ApiError

_tokens: dict[str, float] = {}               # token -> expiry (unix seconds)
_hits: dict[str, deque] = defaultdict(deque)  # token -> timestamps of quick-checks


def issue_token() -> str:
    token = secrets.token_urlsafe(32)
    _tokens[token] = time.time() + settings.TOKEN_TTL_SECONDS
    return token


def require_token(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise ApiError(401, "invalid_token", "Missing install token.")
    token = authorization[len("Bearer "):].strip()
    expiry = _tokens.get(token)
    if expiry is None or expiry < time.time():
        _tokens.pop(token, None)
        raise ApiError(401, "invalid_token", "Invalid or expired install token.")
    return token


def check_rate_limit(token: str) -> None:
    now = time.time()
    window = 3600
    q = _hits[token]
    while q and q[0] <= now - window:
        q.popleft()
    if len(q) >= settings.rate_limit_per_hour():
        retry_after = max(1, int(q[0] + window - now))
        raise ApiError(429, "rate_limited", "Too many requests. Try again later.",
                       headers={"Retry-After": str(retry_after)})
    q.append(now)


def reset_state() -> None:  # for tests
    _tokens.clear()
    _hits.clear()
