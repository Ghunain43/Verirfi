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


def radar_min_installs() -> int:
    return int(os.getenv("RADAR_MIN_INSTALLS", "10"))


def radar_min_networks() -> int:
    return int(os.getenv("RADAR_MIN_NETWORKS", "3"))


def radar_window_hours() -> int:
    return int(os.getenv("RADAR_WINDOW_HOURS", "168"))  # only claims active in the last 7 days


def radar_trust_forwarded() -> bool:
    # true only behind your own reverse proxy; otherwise X-Forwarded-For can be spoofed
    return os.getenv("RADAR_TRUST_FORWARDED", "false").lower() == "true"


def radar_proxy_hops() -> int:
    return max(1, int(os.getenv("RADAR_PROXY_HOPS", "1")))  # trusted reverse proxies in front of the app


def radar_salt() -> str:
    return os.getenv("RADAR_SALT", "dev-only-change-me")


def radar_fill_to() -> int:
    return int(os.getenv("RADAR_FILL_TO", "5"))  # fewer community claims than this -> add web-found false claims


def radar_web_enabled() -> bool:
    return os.getenv("RADAR_WEB_ENABLED", "true").lower() == "true"


def radar_web_ttl_minutes() -> int:
    return int(os.getenv("RADAR_WEB_TTL_MINUTES", "180"))


def radar_web_timeout_seconds() -> float:
    return float(os.getenv("RADAR_WEB_TIMEOUT_SECONDS", "20"))


def radar_region() -> str:
    return os.getenv("RADAR_REGION", "")  # e.g. "Pakistan" to bias the search to local rumors


def cors_origins() -> list[str]:
    raw = os.getenv("CORS_ORIGINS", "http://localhost:3000")
    return [o.strip() for o in raw.split(",") if o.strip()]


TOKEN_TTL_SECONDS = 30 * 24 * 3600  # 2592000, matches API.md
QUICK_CHECK_TIMEOUT_SECONDS = 25
