"""Abuse thresholds: install limit per network, strikes and temporary blocks per token,
and a near-identical-claim flood detector (uses the SimHash Hamming distance).

Privacy: IP addresses are never stored. Networks are reduced to an IPv4 /24 (IPv6 /48)
and then kept only as a salted HMAC with a random per-process secret, in memory, for one hour.
"""
import hashlib
import hmac
import ipaddress
import secrets
import time
from collections import defaultdict, deque

from fastapi import Request

from backend.app.api import settings
from backend.app.api.errors import ApiError

WINDOW = 3600  # seconds


def client_ip(request: Request) -> str:
    """Behind a trusted proxy the LAST X-Forwarded-For entry is the one the proxy added.
    Earlier entries are client-controlled and can be spoofed, so they are never used."""
    if settings.trust_proxy():
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[-1].strip()
    return request.client.host if request.client else "unknown"


def network_of(ip: str) -> str:
    try:
        ipaddress.ip_address(ip)
    except ValueError:
        return ip
    prefix = 24 if ipaddress.ip_address(ip).version == 4 else 48
    return str(ipaddress.ip_network(f"{ip}/{prefix}", strict=False))


def _retry(seconds: float) -> dict:
    return {"Retry-After": str(max(1, int(seconds)))}


class AbuseGuard:
    def __init__(self) -> None:
        self._secret = secrets.token_bytes(32)
        self._installs: dict[str, deque] = defaultdict(deque)   # hashed network -> install times
        self._strikes: dict[str, deque] = defaultdict(deque)    # token -> strike times
        self._blocked: dict[str, float] = {}                    # token -> blocked until (unix seconds)
        self._recent: dict[str, deque] = defaultdict(lambda: deque(maxlen=100))  # token -> (time, fingerprint int)
        self._key_failures: dict[str, deque] = defaultdict(deque)  # hashed network -> wrong-API-key times

    def reset(self) -> None:
        self._installs.clear()
        self._strikes.clear()
        self._blocked.clear()
        self._recent.clear()
        self._key_failures.clear()

    def _hash(self, value: str) -> str:
        return hmac.new(self._secret, value.encode("utf-8"), hashlib.sha256).hexdigest()[:32]

    # ---- rule 1: limit installs per network ----
    def check_install(self, network: str) -> None:
        now = time.time()
        q = self._installs[self._hash(network)]
        while q and q[0] <= now - WINDOW:
            q.popleft()
        if len(q) >= settings.install_rate_limit_per_hour():
            raise ApiError(429, "rate_limited", "Too many installs from this network. Try again later.",
                           headers=_retry(q[0] + WINDOW - now))
        q.append(now)

    # ---- rule 2: strikes lead to a temporary block ----
    def check_blocked(self, token: str) -> None:
        until = self._blocked.get(token)
        if until is None:
            return
        now = time.time()
        if until <= now:
            del self._blocked[token]
            return
        raise ApiError(429, "rate_limited", "This install is temporarily blocked for abuse. Try again later.",
                       headers=_retry(until - now))

    def strike(self, token: str, reason: str) -> None:
        now = time.time()
        q = self._strikes[token]
        while q and q[0] <= now - WINDOW:
            q.popleft()
        q.append(now)
        if len(q) >= settings.abuse_strike_limit():
            self._blocked[token] = now + settings.abuse_block_seconds()
            q.clear()

    # ---- rule 4: guessing fact-checker API keys ----
    def check_key_failures(self, network: str) -> None:
        now = time.time()
        q = self._key_failures[self._hash("key:" + network)]
        while q and q[0] <= now - WINDOW:
            q.popleft()
        if len(q) >= settings.key_failure_limit():
            raise ApiError(429, "rate_limited", "Too many failed attempts from this network. Try again later.",
                           headers=_retry(q[0] + WINDOW - now))

    def key_failure(self, network: str) -> None:
        self._key_failures[self._hash("key:" + network)].append(time.time())

    # ---- rule 3: flood of near-identical claims ----
    def check_near_duplicates(self, token: str, fingerprint_hex: str) -> None:
        """Exact repeats are harmless (the cache answers them). Many different-but-similar
        claims from one token are an attempt to dodge the cache and burn research quota."""
        fp = int(fingerprint_hex, 16)
        now = time.time()
        recent = self._recent[token]
        while recent and recent[0][0] <= now - WINDOW:
            recent.popleft()
        if any(f == fp for _, f in recent):
            return
        distance = settings.near_dup_distance()
        near = sum(1 for _, f in recent if bin(f ^ fp).count("1") <= distance)
        recent.append((now, fp))
        if near >= settings.near_dup_limit():
            self.strike(token, "near_duplicate")
            raise ApiError(429, "rate_limited", "Too many near-identical claims. Try again later.",
                           headers=_retry(300))


guard = AbuseGuard()
