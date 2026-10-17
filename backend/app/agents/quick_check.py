"""The single entry point the API layer calls (see shared/API.md section 3):

    result = await run_quick_check(claim, lang)

Pipeline: ClaimAgent (scope gate) -> ResearchAgent -> SourceAgent -> EvidenceAgent -> build_answer.
Nothing is stored. Raises VerifiError with code invalid_input / upstream_failed / timeout.
"""
from __future__ import annotations

import asyncio
from typing import Any

from .answer import build_answer
from .claim_agent import ClaimAgent
from .common import VerifiError, get_logger, truncate
from .evidence_agent import EvidenceAgent
from .llm import LLMClient
from .mock import mock_quick_check
from .models import QuickCheckResult
from .research_agent import ResearchAgent
from .settings import get_settings
from .source_agent import SourceAgent
from .tavily import TavilyClient

logger = get_logger(__name__)

MAX_CHARS = 2000
VALID_LANGS = {"auto", "en", "ur", "ur-Latn"}


class QuickCheckPipeline:
    def __init__(self, llm: LLMClient | None = None, tavily: TavilyClient | None = None) -> None:
        llm = llm or LLMClient()
        tavily = tavily or TavilyClient()
        self.claim_agent = ClaimAgent(llm)
        self.research_agent = ResearchAgent(llm, tavily, max_iterations=1, queries_per_round=2, llm_queries=False)
        self.source_agent = SourceAgent()
        self.evidence_agent = EvidenceAgent(llm)

    async def run(self, text: str, lang: str) -> QuickCheckResult:
        state: dict[str, Any] = {"input_text": text, "lang_hint": None if lang == "auto" else lang}
        state = await self.claim_agent.execute(state)
        if not state["checkable"]:
            return QuickCheckResult(
                checkable=False, claim=truncate(text, 300), reason_unchecked=state["reason_unchecked"],
                lang_detected=state["lang_detected"],
            )
        for agent in (self.research_agent, self.source_agent, self.evidence_agent):
            state = await agent.execute(state)

        likely, low, high, shown = build_answer(state["extracted_evidence"], state["evaluated_sources"])
        claim = state["extracted_claims"][0]
        return QuickCheckResult(
            checkable=True, claim=claim["normalized_text"], likely_answer=likely,
            confidence_low=low, confidence_high=high, evidence=shown, lang_detected=state["lang_detected"],
        )


_default: QuickCheckPipeline | None = None


async def run_quick_check(claim: str, lang: str = "auto", *, pipeline: QuickCheckPipeline | None = None) -> QuickCheckResult:
    text = (claim or "").strip()
    if not text:
        raise VerifiError("Text is empty", code="invalid_input")
    if len(text) > MAX_CHARS:
        raise VerifiError(f"Text is longer than {MAX_CHARS} characters", code="invalid_input")
    if lang not in VALID_LANGS:
        raise VerifiError(f"Unsupported lang '{lang}'", code="invalid_input")

    settings = get_settings()
    if settings.mock_mode:
        return mock_quick_check(text, lang)

    global _default
    if pipeline is None:
        _default = _default or QuickCheckPipeline()
        pipeline = _default
    try:
        return await asyncio.wait_for(pipeline.run(text, lang), timeout=settings.quick_check_timeout)
    except asyncio.TimeoutError:
        raise VerifiError("The check took too long", code="timeout")
    except VerifiError as exc:
        if exc.code in ("invalid_input", "timeout"):
            raise
        logger.warning("Quick check failed: %s (%s)", exc.message, exc.code)
        raise VerifiError(exc.message, code="upstream_failed") from exc
