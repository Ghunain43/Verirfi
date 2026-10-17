"""Fixed sample responses for MOCK_MODE=true, so the clients can be built before real keys exist."""
from __future__ import annotations

import re

from .models import Evidence, QuickCheckResult

_OPINION = re.compile(r"\b(worst|best|hate|love|stupid|disgusting|terrible|awesome)\b", re.IGNORECASE)


def mock_quick_check(text: str, lang: str = "auto") -> QuickCheckResult:
    if _OPINION.search(text):
        return QuickCheckResult(
            checkable=False, claim=text.strip()[:300], reason_unchecked="opinion", lang_detected="en"
        )
    return QuickCheckResult(
        checkable=True,
        claim="Drinking hot water cures dengue fever.",
        likely_answer="Most likely false: sources contradict this claim. Strongest source: who.int.",
        confidence_low=0.7,
        confidence_high=0.9,
        evidence=[
            Evidence(
                title="Dengue and severe dengue",
                url="https://www.who.int/news-room/fact-sheets/detail/dengue-and-severe-dengue",
                publisher="who.int", stance="contradicting", quality=0.85,
                snippet="No specific treatment exists; care is supportive.",
            )
        ],
        lang_detected="en",
    )
