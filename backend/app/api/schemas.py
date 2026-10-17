"""Pydantic models matching shared/API.md v1. Do not rename fields without Ghunain's OK."""
import re
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


class LookupEntry(BaseModel):
    fingerprint: str
    claim: str
    likely_answer: Optional[str] = None
    confidence_low: float = 0.0
    confidence_high: float = 0.0
    evidence: list[Evidence] = []
    checked_at: str


class LookupResponse(BaseModel):
    prefix: str
    entries: list[LookupEntry]


class ReportRequest(BaseModel):
    fingerprint: str
    region: Optional[str] = None
    noisy: bool

    @field_validator("fingerprint")
    @classmethod
    def fingerprint_ok(cls, v: str) -> str:
        if not re.fullmatch(r"[0-9a-fA-F]{16}", v):
            raise ValueError("fingerprint must be 16 hex characters")
        return v.lower()

    @field_validator("region")
    @classmethod
    def region_ok(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and not re.fullmatch(r"[A-Za-z0-9-]{2,8}", v):
            raise ValueError("region must be a short code like PK-SD")
        return v

    @field_validator("noisy")
    @classmethod
    def noisy_ok(cls, v: bool) -> bool:
        if v is not True:
            raise ValueError("reports are only accepted with client-side noise applied")
        return v


class RadarItem(BaseModel):
    fingerprint: str
    claim: str = ""
    reports: int
    first_seen: str
    last_seen: str


class RadarResponse(BaseModel):
    items: list[RadarItem]
