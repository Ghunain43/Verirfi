"""Pydantic models matching shared/API.md v1. Do not rename fields without Ghunain's OK."""
from typing import Literal, Optional

from pydantic import BaseModel, field_validator

MAX_TEXT_CHARS = 2000


class InstallResponse(BaseModel):
    install_token: str
    expires_in: int


class QuickCheckRequest(BaseModel):
    text: str
    lang: Literal["en", "ur", "ur-Latn", "auto"] = "auto"
    source: Literal["extension", "mobile", "web"]

    @field_validator("text")
    @classmethod
    def text_ok(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("empty text")
        if len(v) > MAX_TEXT_CHARS:
            raise ValueError("text too long")
        return v


class Evidence(BaseModel):
    title: str
    url: str
    publisher: Optional[str] = None
    stance: Literal["supporting", "contradicting", "neutral"]
    quality: float
    snippet: Optional[str] = None


class QuickCheckResponse(BaseModel):
    checkable: bool
    claim: str
    reason_unchecked: Optional[str] = None
    likely_answer: Optional[str] = None
    confidence_low: float = 0.0
    confidence_high: float = 0.0
    evidence: list[Evidence] = []
    lang_detected: str = "en"
    fingerprint: str
    cached: bool = False
    took_ms: int
