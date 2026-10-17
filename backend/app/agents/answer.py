"""Evidence -> "likely answer" text + confidence RANGE. Computed in code, not by the LLM.

We never output a bare TRUE/FALSE. The range says how sure we are about `likely_answer`;
it gets wider when few sources decide the question and is low when evidence is insufficient.
"""
from __future__ import annotations

from typing import Any

from .common import clamp01, truncate
from .models import Evidence

INSUFFICIENT = "Not enough evidence to say."
MAX_EVIDENCE = 6



def _weight(e: dict[str, Any], quality: dict[str, float]) -> float:
    return clamp01(e.get("relevance_score")) * clamp01(e.get("confidence")) * (0.5 + 0.5 * quality.get(e.get("source_id"), 0.5))


def build_answer(
    evidence: list[dict[str, Any]], sources: list[dict[str, Any]]
) -> tuple[str, float, float, list[Evidence]]:
    """Return (likely_answer, confidence_low, confidence_high, evidence_for_display)."""
    by_id = {s["id"]: s for s in sources}
    quality = {sid: clamp01(s.get("quality_score"), 0.5) for sid, s in by_id.items()}

    scored = [(e, _weight(e, quality)) for e in evidence if e.get("stance") in ("supporting", "contradicting")]
    sup = sum(w for e, w in scored if e["stance"] == "supporting")
    con = sum(w for e, w in scored if e["stance"] == "contradicting")
    n_sup = sum(1 for e, _ in scored if e["stance"] == "supporting")
    n_con = len(scored) - n_sup

    shown = _display_evidence(evidence, by_id, quality)
    if n_sup + n_con == 0:
        return INSUFFICIENT, 0.0, 0.2, shown

    ratio = sup / (sup + con)
    if ratio >= 0.85:
        text = "Most likely true: sources support this claim."
    elif ratio >= 0.65:
        text = "Probably true: most sources support it, but not all."
    elif ratio >= 0.35:
        text = "Mixed evidence: sources disagree."
    elif ratio >= 0.15:
        text = "Probably false: most sources contradict it."
    else:
        text = "Most likely false: sources contradict this claim."

    top = max(scored, key=lambda p: p[1])[0]
    publisher = by_id.get(top.get("source_id"), {}).get("publisher")
    if publisher:
        text += f" Strongest source: {publisher}."

    decisiveness = abs(ratio - 0.5) * 2
    coverage = min(1.0, (n_sup + n_con) / 3)
    centre = min(0.95, 0.6 * decisiveness + 0.4 * coverage)
    half = 0.08 + 0.17 * (1.0 - coverage)
    return text, round(max(0.0, centre - half), 2), round(min(1.0, centre + half), 2), shown


def _display_evidence(evidence: list[dict[str, Any]], by_id: dict[str, dict[str, Any]], quality: dict[str, float]) -> list[Evidence]:
    ordered = sorted(
        evidence,
        key=lambda e: (e.get("stance") == "neutral", -_weight(e, quality)),
    )
    out: list[Evidence] = []
    seen: set[str] = set()
    for e in ordered:
        src = by_id.get(e.get("source_id"))
        if not src or src["url"] in seen:
            continue
        seen.add(src["url"])
        out.append(
            Evidence(
                title=truncate(src.get("title") or src["url"], 200), url=src["url"], publisher=src.get("publisher"),
                stance=e["stance"], quality=round(quality.get(src["id"], 0.5), 2),
                snippet=truncate(e.get("evidence_text"), 300),
            )
        )
        if len(out) >= MAX_EVIDENCE:
            break
    return out
