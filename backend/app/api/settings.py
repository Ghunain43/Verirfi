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


def cors_origins() -> list[str]:
    raw = os.getenv("CORS_ORIGINS", "http://localhost:3000")
    return [o.strip() for o in raw.split(",") if o.strip()]


TOKEN_TTL_SECONDS = 30 * 24 * 3600  # 2592000, matches API.md
QUICK_CHECK_TIMEOUT_SECONDS = 25
