"""Shared helpers for the agents (errors, logging, small text/URL utilities)."""
from __future__ import annotations

import json
import logging
import re
from typing import Any
from urllib.parse import urlparse


class VerifiError(Exception):
    """Error raised by agents and integrations.

    `code` values the API layer should map (see shared/API.md section 6):
      invalid_input -> 400, upstream_failed -> 502, timeout -> 504
    Other codes are internal detail and are converted to upstream_failed by run_quick_check.
    """

    def __init__(self, message: str, *, code: str = "upstream_failed") -> None:
        super().__init__(message)
        self.message = message
        self.code = code


def get_logger(name: str) -> logging.Logger:
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s"))
        logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    return logger


def clamp01(value: Any, default: float = 0.5) -> float:
    try:
        return max(0.0, min(1.0, float(value)))
    except (TypeError, ValueError):
        return default


def truncate(text: str | None, limit: int) -> str:
    text = (text or "").strip()
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def domain_of(url: str | None) -> str:
    if not url:
        return ""
    host = urlparse(url).netloc.lower()
    return host[4:] if host.startswith("www.") else host


def normalize_url(url: str | None) -> str:
    if not url:
        return ""
    parsed = urlparse(url.strip())
    host = parsed.netloc.lower()
    host = host[4:] if host.startswith("www.") else host
    return f"{host}{parsed.path.rstrip('/')}".lower()


def parse_json(text: str) -> Any:
    """Parse JSON from an LLM reply, tolerating code fences and surrounding prose."""
    cleaned = (text or "").strip()
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", cleaned, flags=re.IGNORECASE).strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass
    for open_ch, close_ch in (("{", "}"), ("[", "]")):
        start, end = cleaned.find(open_ch), cleaned.rfind(close_ch)
        if start != -1 and end > start:
            try:
                return json.loads(cleaned[start : end + 1])
            except json.JSONDecodeError:
                continue
    raise VerifiError("LLM did not return valid JSON", code="llm_bad_json")
