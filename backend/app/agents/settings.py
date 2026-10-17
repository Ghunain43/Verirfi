"""Agent settings, read from environment variables (.env at the repo root or in backend/)."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

_REPO_ROOT = Path(__file__).resolve().parents[3]
load_dotenv(_REPO_ROOT / ".env")
load_dotenv(_REPO_ROOT / "backend" / ".env")
load_dotenv()


def _env(name: str, default: str = "") -> str:
    # An empty value (e.g. a blank "GROQ_MODEL=" line) counts as "not set".
    return os.getenv(name) or default


@dataclass(frozen=True)
class AgentSettings:
    groq_api_key: str
    groq_model: str
    tavily_api_key: str
    mock_mode: bool
    quick_check_timeout: float


def get_settings() -> AgentSettings:
    """Read settings fresh on each call, so tests and .env edits take effect."""
    return AgentSettings(
        groq_api_key=_env("GROQ_API_KEY"),
        groq_model=_env("GROQ_MODEL", "llama-3.3-70b-versatile"),
        tavily_api_key=_env("TAVILY_API_KEY"),
        mock_mode=_env("MOCK_MODE", "false").lower() == "true",
        quick_check_timeout=float(_env("QUICK_CHECK_TIMEOUT", "22")),
    )
