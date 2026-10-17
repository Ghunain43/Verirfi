"""In-memory Rumor Radar: which claims are being checked by many different people.

Privacy: no raw install token, no IP address and no user text is stored. Each report keeps only
a salted hash of the install token and a salted hash of the coarse network (IPv4 /24, IPv6 /48),
next to the extracted claim and its fingerprint. Nothing is written to disk.
"""
import hashlib
import ipaddress
import threading
from collections import OrderedDict
from datetime import datetime, timedelta, timezone
from typing import Optional

from backend.app.api import settings

MAX_ENTRIES = 5000   # oldest-activity claims are evicted first
MAX_RESULTS = 50


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def network_key(ip: Optional[str]) -> str:
    """Coarse network identifier: same /24 (IPv4) or /48 (IPv6) counts as one network."""
    try:
        addr = ipaddress.ip_address((ip or "").strip())
    except ValueError:
        return "unknown"
    prefix = 24 if addr.version == 4 else 48
    return str(ipaddress.ip_network(f"{addr}/{prefix}", strict=False))


def client_ip(request) -> Optional[str]:
    """Caller IP. Only trusts X-Forwarded-For when RADAR_TRUST_FORWARDED=true (behind your own proxy)."""
    if settings.radar_trust_forwarded():
        fwd = request.headers.get("x-forwarded-for")
        if fwd:
            return fwd.split(",")[0].strip()
    return request.client.host if request.client else None


class RadarStore:
    def __init__(self, max_entries: int = MAX_ENTRIES) -> None:
        self.max_entries = max_entries
        self._entries: "OrderedDict[str, dict]" = OrderedDict()  # fingerprint -> entry, least recent first
        self._lock = threading.Lock()

    @staticmethod
    def _hash(kind: str, value: str) -> str:
        return hashlib.sha256(f"{settings.radar_salt()}|{kind}|{value}".encode()).hexdigest()[:16]

    def record(self, fingerprint: str, claim: str, install_token: str, ip: Optional[str],
               now: Optional[datetime] = None) -> None:
        now = now or _utcnow()
        fp = fingerprint.lower()
        install = self._hash("install", install_token)
        network = self._hash("network", network_key(ip))
        with self._lock:
            e = self._entries.get(fp)
            if e is None:
                e = {"claim": claim, "installs": set(), "networks": set(), "first_seen": now, "last_seen": now}
                self._entries[fp] = e
            e["installs"].add(install)   # sets: repeat checks by one install never inflate the count
            e["networks"].add(network)
            if now > e["last_seen"]:
                e["last_seen"] = now
            self._entries.move_to_end(fp)
            while len(self._entries) > self.max_entries:
                self._entries.popitem(last=False)

    def trending(self, min_installs: int, min_networks: int, window_hours: int,
                 now: Optional[datetime] = None) -> list[dict]:
        cutoff = (now or _utcnow()) - timedelta(hours=window_hours)
        with self._lock:
            rows = [
                {
                    "fingerprint": fp,
                    "claim": e["claim"],
                    "reports": len(e["installs"]),
                    "first_seen": _iso(e["first_seen"]),
                    "last_seen": _iso(e["last_seen"]),
                }
                for fp, e in self._entries.items()
                if len(e["installs"]) >= min_installs
                and len(e["networks"]) >= min_networks
                and e["last_seen"] >= cutoff
            ]
        rows.sort(key=lambda r: (r["reports"], r["last_seen"]), reverse=True)
        return rows[:MAX_RESULTS]

    def clear(self) -> None:
        with self._lock:
            self._entries.clear()

    def __len__(self) -> int:
        return len(self._entries)


radar_store = RadarStore()
