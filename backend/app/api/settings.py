import os

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:  # dotenv is optional
    pass


def mock_mode() -> bool:
    return os.getenv("MOCK_MODE", "true").lower() == "true"


def rate_limit_per_hour() -> int:
    return int(os.getenv("RATE_LIMIT_PER_HOUR", "20"))


def lookup_rate_limit_per_hour() -> int:
    return int(os.getenv("LOOKUP_RATE_LIMIT_PER_HOUR", "200"))


def report_rate_limit_per_hour() -> int:
    return int(os.getenv("REPORT_RATE_LIMIT_PER_HOUR", "30"))


def radar_min_reports() -> int:
    """A claim shows on the radar only after this many distinct installs reported it."""
    return max(1, int(os.getenv("RADAR_MIN_REPORTS", "10")))


def install_rate_limit_per_hour() -> int:
    """Token installs allowed per network (IPv4 /24, IPv6 /48) per hour."""
    return int(os.getenv("INSTALL_RATE_LIMIT_PER_HOUR", "30"))


def radar_min_networks() -> int:
    """A claim shows on the radar only if reports came from at least this many different networks."""
    return max(1, int(os.getenv("RADAR_MIN_NETWORKS", "3")))


def abuse_strike_limit() -> int:
    """Strikes (rate-limit hits, near-duplicate floods) within an hour before a token is blocked."""
    return int(os.getenv("ABUSE_STRIKE_LIMIT", "5"))


def abuse_block_seconds() -> int:
    return int(os.getenv("ABUSE_BLOCK_SECONDS", "3600"))


def near_dup_distance() -> int:
    """Two different fingerprints this close (Hamming bits) count as near-identical claims."""
    return int(os.getenv("NEAR_DUP_DISTANCE", "12"))


def near_dup_limit() -> int:
    """Near-identical variants one token may already have sent before the next one is a violation."""
    return int(os.getenv("NEAR_DUP_LIMIT", "5"))


def trust_proxy() -> bool:
    """Set TRUST_PROXY=true only behind a proxy you control (Render, Railway, nginx)."""
    return os.getenv("TRUST_PROXY", "false").lower() == "true"


def factcheck_keys() -> dict:
    """FACTCHECK_API_KEYS="Dawn Fact Desk:<key>,AFP Urdu:<key>" -> {name: key}. Keys under 16 chars are ignored."""
    out = {}
    for part in os.getenv("FACTCHECK_API_KEYS", "").split(","):
        part = part.strip()
        if ":" not in part:
            continue
        name, key = part.rsplit(":", 1)
        name, key = name.strip(), key.strip()
        if name and len(key) >= 16:
            out[name] = key
    return out


def factcheck_signing_key():
    """Base64 Ed25519 seed (see backend/scripts/make_signing_key.py). Unset = new random key per restart."""
    return os.getenv("FACTCHECK_SIGNING_KEY", "").strip() or None


def key_failure_limit() -> int:
    """Wrong fact-checker API keys allowed per network per hour before that network is locked out."""
    return int(os.getenv("FACTCHECK_KEY_FAILURE_LIMIT", "10"))


def cors_origins() -> list[str]:
    raw = os.getenv("CORS_ORIGINS", "http://localhost:3000")
    return [o.strip() for o in raw.split(",") if o.strip()]


TOKEN_TTL_SECONDS = 30 * 24 * 3600  # 2592000, matches API.md
QUICK_CHECK_TIMEOUT_SECONDS = 25
