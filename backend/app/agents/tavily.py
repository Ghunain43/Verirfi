from __future__ import annotations

from typing import Any

from .common import VerifiError
from .http import request_json
from .settings import get_settings


class TavilyClient:
    """Tavily web search via REST. Returns normalized result dicts."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key if api_key is not None else get_settings().tavily_api_key

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    async def search(self, query: str, *, max_results: int = 5, search_depth: str = "basic") -> list[dict[str, Any]]:
        if not self.api_key:
            raise VerifiError("TAVILY_API_KEY is not set (put it in .env and restart)", code="tavily_missing_key")
        data = await request_json(
            "POST", "https://api.tavily.com/search", service="tavily",
            headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
            json_body={"query": query, "max_results": max_results, "search_depth": search_depth, "include_answer": False},
            timeout=12.0, retries=2,
        )
        return [
            {
                "url": r.get("url", ""),
                "title": r.get("title", ""),
                "content": r.get("content", ""),
                "score": float(r.get("score", 0.0) or 0.0),
            }
            for r in (data or {}).get("results", [])
            if r.get("url")
        ]
