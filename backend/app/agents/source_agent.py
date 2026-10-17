"""Agent 3: research results -> deduplicated sources scored by publisher credibility (no LLM, instant)."""
from __future__ import annotations

from typing import Any

from .base import BaseAgent
from .common import clamp01, domain_of, get_logger, normalize_url, truncate

logger = get_logger(__name__)

HIGH_TRUST = {
    "reuters.com", "apnews.com", "bbc.com", "bbc.co.uk", "nature.com", "science.org", "who.int", "un.org",
    "worldbank.org", "imf.org", "oecd.org", "nih.gov", "cdc.gov", "sec.gov", "nasa.gov", "economist.com",
    "ft.com", "wsj.com", "nytimes.com", "washingtonpost.com", "theguardian.com", "dawn.com", "arxiv.org",
    "pubmed.ncbi.nlm.nih.gov", "thelancet.com", "bloomberg.com","mayoclinic.org", "yalemedicine.org", "nhs.uk", "tribune.com.pk",
"thenews.com.pk", "geo.tv", "dawn.com", "who.int", "cdc.gov", "afp.com"
    # fact-checkers
    "snopes.com", "factcheck.org", "politifact.com", "afp.com", "fullfact.org", "reuters.com",
}
LOW_TRUST = {
    "reddit.com", "quora.com", "facebook.com", "x.com", "twitter.com", "tiktok.com", "instagram.com",
    "pinterest.com", "medium.com", "blogspot.com", "wordpress.com", "youtube.com", "answers.com",
}


def _in(domain: str, names: set[str]) -> bool:
    return any(domain == n or domain.endswith("." + n) for n in names)


def heuristic(domain: str) -> tuple[float, str]:
    d = domain.lower()
    if _in(d, LOW_TRUST):
        return 0.25, "social"
    if d.endswith(".gov") or ".gov." in d or d.endswith(".mil"):
        return 0.88, "government"
    if d.endswith(".edu") or ".edu." in d or ".ac." in d:
        return 0.85, "academic"
    if d.endswith(".int"):
        return 0.85, "organization"
    if _in(d, HIGH_TRUST):
        return 0.85, "news"
    if d.endswith("wikipedia.org"):
        return 0.65, "reference"
    if d.endswith(".org"):
        return 0.6, "organization"
    return 0.5, "other"


class SourceAgent(BaseAgent):
    name = "source_agent"

    def __init__(self, max_sources: int = 8) -> None:
        self.max_sources = max_sources

    async def run(self, state: dict[str, Any]) -> dict[str, Any]:
        merged = self._dedupe(state.get("research_results", []))
        if not merged:
            logger.warning("No research results to evaluate")
            return {"evaluated_sources": []}
        for s in merged:
            s["_q"], s["_type"] = heuristic(s["domain"])
        merged.sort(key=lambda s: s["relevance_score"] * s["_q"], reverse=True)
        sources = [
            {
                "id": f"s{i}", "url": s["url"], "title": s["title"], "domain": s["domain"],
                "publisher": truncate(s["domain"], 120), "source_type": s["_type"], "quality_score": s["_q"],
                "relevance_score": round(s["relevance_score"], 3), "content": s["content"],
                "claim_ids": sorted(s["claim_ids"]),
            }
            for i, s in enumerate(merged[: self.max_sources])
        ]
        return {"evaluated_sources": sources}

    @staticmethod
    def _dedupe(results: list[dict[str, Any]]) -> list[dict[str, Any]]:
        by_key: dict[str, dict[str, Any]] = {}
        for r in results:
            key = normalize_url(r["url"])
            if not key:
                continue
            cur = by_key.get(key)
            if cur is None:
                by_key[key] = {
                    "url": r["url"], "title": r.get("title", ""), "content": r.get("content", ""),
                    "domain": domain_of(r["url"]), "relevance_score": clamp01(r.get("score"), 0.0),
                    "claim_ids": {r["claim_id"]},
                }
            else:
                cur["claim_ids"].add(r["claim_id"])
                cur["relevance_score"] = max(cur["relevance_score"], clamp01(r.get("score"), 0.0))
                if len(r.get("content", "")) > len(cur["content"]):
                    cur["content"] = r["content"]
        return list(by_key.values())
