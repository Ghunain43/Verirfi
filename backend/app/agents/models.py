"""Models matching shared/API.md section 3. Do not change fields without updating the contract."""
from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field


class Evidence(BaseModel):
    title: str
    url: str
    publisher: Optional[str] = None
    stance: Literal["supporting", "contradicting", "neutral"]
    quality: float  # 0..1, publisher credibility
    snippet: Optional[str] = None


class QuickCheckResult(BaseModel):
    checkable: bool
    claim: str
    reason_unchecked: Optional[str] = None
    likely_answer: Optional[str] = None
    confidence_low: float = 0.0
    confidence_high: float = 0.0
    evidence: list[Evidence] = Field(default_factory=list)
    lang_detected: str = "en"
