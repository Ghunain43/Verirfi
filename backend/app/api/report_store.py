"""Opt-in rumor reports, counted per fingerprint by DISTINCT installs (API.md section 5).

Privacy design:
 - There is no table of "which install reported what". Each report is stored as
   HMAC(server_secret, install_token + ":" + fingerprint). That is enough to count
   distinct installs for one fingerprint, but the same install gets a different,
   unlinkable identifier for every other fingerprint, and the token itself is never stored.
 - The server secret is random per process and never written anywhere, so a restart
   also makes old identifiers meaningless. Everything is in memory.
 - Reports also record a salted hash of the reporter's coarse network (IPv4 /24, IPv6 /48), per
   fingerprint, so a claim only reaches the radar if reports came from several different networks.
   Raw IP addresses are never stored.
 - The region sent by clients is validated and then discarded.
 - Timestamps are rounded to the minute.
"""
import hashlib
import hmac
import secrets
from collections import OrderedDict
from datetime import datetime, timezone
from typing import Callable, Optional

MAX_FINGERPRINTS = 20000  # least recently reported fingerprints are evicted first
RADAR_LIMIT = 50


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:00Z")


class ReportStore:
    def __init__(self, max_fingerprints: int = MAX_FINGERPRINTS, secret: Optional[bytes] = None) -> None:
        self.max_fingerprints = max_fingerprints
        self._secret = secret or secrets.token_bytes(32)
        self._data: "OrderedDict[str, dict]" = OrderedDict()  # fingerprint -> {installs, first_seen, last_seen}

    def _install_id(self, token: str, fingerprint: str) -> str:
        msg = f"{token}:{fingerprint}".encode("utf-8")
        return hmac.new(self._secret, msg, hashlib.sha256).hexdigest()[:32]

    def _network_id(self, network: str, fingerprint: str) -> str:
        msg = f"net:{network}:{fingerprint}".encode("utf-8")
        return hmac.new(self._secret, msg, hashlib.sha256).hexdigest()[:32]

    def add(self, token: str, fingerprint: str, network: str = "unknown") -> None:
        fp = fingerprint.lower()
        now = _now()
        entry = self._data.get(fp)
        if entry is None:
            entry = {"installs": set(), "networks": set(), "first_seen": now, "last_seen": now}
            self._data[fp] = entry
        entry["installs"].add(self._install_id(token, fp))  # a repeat report from the same install counts once
        entry["networks"].add(self._network_id(network, fp))  # same idea for the (coarse) network
        entry["last_seen"] = now
        self._data.move_to_end(fp)
        while len(self._data) > self.max_fingerprints:
            self._data.popitem(last=False)

    def radar(self, min_reports: int, claim_for: Callable[[str], str],
              min_networks: int = 1, limit: int = RADAR_LIMIT) -> list[dict]:
        items = [
            {
                "fingerprint": fp,
                "claim": claim_for(fp),
                "reports": len(e["installs"]),
                "first_seen": e["first_seen"],
                "last_seen": e["last_seen"],
            }
            for fp, e in self._data.items()
            if len(e["installs"]) >= min_reports and len(e["networks"]) >= min_networks
        ]
        items.sort(key=lambda i: i["last_seen"], reverse=True)
        items.sort(key=lambda i: i["reports"], reverse=True)  # stable: ties keep newest first
        return items[:limit]

    def clear(self) -> None:
        self._data.clear()

    def __len__(self) -> int:
        return len(self._data)


store = ReportStore()
