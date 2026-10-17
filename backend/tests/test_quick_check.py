"""Tests for the agents + run_quick_check using fake LLM and fake search (no network, no keys)."""
from __future__ import annotations

import asyncio
import json

import pytest

from backend.app.agents.common import VerifiError
from backend.app.agents.quick_check import QuickCheckPipeline, run_quick_check


class FakeLLM:
    """Dispatches on the prompt: scope gate vs evidence extraction."""

    def __init__(self, checkable=True, reason=None, stances=("contradicting", "contradicting", "neutral"), fail_evidence=False):
        self.checkable, self.reason, self.stances, self.fail_evidence = checkable, reason, stances, fail_evidence
        self.calls: list[str] = []

    async def generate_json(self, prompt, *, system=None, temperature=0.1):
        if "checkable factual claim" in prompt:
            self.calls.append("claim")
            if not self.checkable:
                return {"checkable": False, "reason_unchecked": self.reason, "lang": "en", "claim": None}
            return {
                "checkable": True, "reason_unchecked": None, "lang": "ur-Latn",
                "claim": {"text": "garam pani se dengue theek hota hai", "normalized_text": "Garam pani peene se dengue theek ho jata hai.",
                          "search_text": "Drinking hot water cures dengue", "claim_type": "health", "entities": ["dengue"], "confidence": 0.9},
            }
        self.calls.append("evidence")
        if self.fail_evidence:
            raise VerifiError("boom", code="groq_http_500")
        return {"evidence": [
            {"source_index": i, "evidence_text": f"point {i}", "stance": s, "relevance_score": 0.9, "confidence": 0.9}
            for i, s in enumerate(self.stances)
        ]}


class FakeTavily:
    configured = True

    def __init__(self, delay=0.0):
        self.queries: list[str] = []
        self.delay = delay

    async def search(self, query, *, max_results=5, search_depth="basic"):
        self.queries.append(query)
        if self.delay:
            await asyncio.sleep(self.delay)
        return [
            {"url": "https://www.who.int/dengue", "title": "WHO dengue", "content": "No cure, supportive care.", "score": 0.9},
            {"url": "https://www.cdc.gov/dengue", "title": "CDC dengue", "content": "Treat symptoms.", "score": 0.8},
            {"url": "https://reddit.com/r/x", "title": "Reddit thread", "content": "my aunt says...", "score": 0.7},
        ]


def pipe(llm=None, tavily=None):
    return QuickCheckPipeline(llm or FakeLLM(), tavily or FakeTavily())


@pytest.mark.asyncio
async def test_checkable_claim_returns_range_and_evidence(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "false")
    r = await run_quick_check("garam pani se dengue theek hota hai", "auto", pipeline=pipe())
    assert r.checkable and r.lang_detected == "ur-Latn"
    assert r.likely_answer.startswith("Most likely false")
    assert 0.0 <= r.confidence_low < r.confidence_high <= 1.0
    assert r.evidence[0].stance == "contradicting" and r.evidence[0].publisher in {"who.int", "cdc.gov"}
    assert r.evidence[-1].stance == "neutral" and r.evidence[-1].publisher == "reddit.com"  # neutral + low trust last


@pytest.mark.asyncio
async def test_scope_gate_skips_research(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "false")
    llm, tav = FakeLLM(checkable=False, reason="opinion"), FakeTavily()
    r = await run_quick_check("This party is the worst thing ever", "en", pipeline=pipe(llm, tav))
    assert not r.checkable and r.reason_unchecked == "opinion" and r.likely_answer is None and r.evidence == []
    assert tav.queries == [] and llm.calls == ["claim"]  # no research, no evidence call


@pytest.mark.asyncio
async def test_bad_reason_falls_back_to_no_claim(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "false")
    r = await run_quick_check("hello", "auto", pipeline=pipe(FakeLLM(checkable=False, reason="weird")))
    assert r.reason_unchecked == "no_claim"


@pytest.mark.asyncio
async def test_only_neutral_evidence_is_insufficient(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "false")
    r = await run_quick_check("claim", "auto", pipeline=pipe(FakeLLM(stances=("neutral", "neutral"))))
    assert r.likely_answer == "Not enough evidence to say." and r.confidence_high <= 0.2


@pytest.mark.asyncio
async def test_evidence_llm_failure_is_upstream_failed(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "false")
    with pytest.raises(VerifiError) as e:
        await run_quick_check("claim", "auto", pipeline=pipe(FakeLLM(fail_evidence=True)))
    assert e.value.code == "upstream_failed"


@pytest.mark.asyncio
async def test_timeout(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "false")
    monkeypatch.setenv("QUICK_CHECK_TIMEOUT", "0.05")
    with pytest.raises(VerifiError) as e:
        await run_quick_check("claim", "auto", pipeline=pipe(tavily=FakeTavily(delay=1)))
    assert e.value.code == "timeout"


@pytest.mark.asyncio
@pytest.mark.parametrize("text,lang", [("", "auto"), ("   ", "auto"), ("x" * 2001, "auto"), ("hi", "klingon")])
async def test_invalid_input(text, lang):
    with pytest.raises(VerifiError) as e:
        await run_quick_check(text, lang, pipeline=pipe())
    assert e.value.code == "invalid_input"


@pytest.mark.asyncio
async def test_mock_mode(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "true")
    ok = await run_quick_check("hot water cures dengue", "auto")
    no = await run_quick_check("This is the worst party", "auto")
    assert ok.checkable and ok.evidence and not no.checkable and no.reason_unchecked == "opinion"
    json.dumps(ok.model_dump())  # serialisable for the API layer
