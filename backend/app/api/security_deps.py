"""Install tokens + rate limiting. In-memory for now; move to security/ when it grows."""
import secrets
import time
from collections import defaultdict, deque

from fastapi import Header

from backend.app.api import settings
from backend.app.api.errors import ApiError

_tokens: dict[str, float] = {}               # token -> expiry (unix seconds)
_hits: dict[str, deque] = defaultdict(deque)  # "kind:token" -> timestamps


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


def _limit(kind: str) -> int:
    if kind == "quick-check":
        return settings.rate_limit_per_hour()
    if kind == "report":
        return settings.report_rate_limit_per_hour()
    return settings.lookup_rate_limit_per_hour()  # lookup, radar


def check_rate_limit(token: str, kind: str = "quick-check") -> None:
    """Sliding one-hour window per token. Each kind of call has its own counter and limit."""
    limit = _limit(kind)
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
    _tokens.clear()
    _hits.clear()
