"""LLM facade (Groq, OpenAI-compatible REST). Every agent talks to the model through LLMClient."""
from __future__ import annotations

import asyncio
from typing import Any

from .common import VerifiError, parse_json
from .http import request_json
from .settings import get_settings

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

# Groq's free tier limits tokens per minute: cap parallel requests per event loop.
MAX_CONCURRENT_REQUESTS = 3
_semaphores: dict[int, asyncio.Semaphore] = {}


def _semaphore() -> asyncio.Semaphore:
    key = id(asyncio.get_running_loop())
    if key not in _semaphores:
        _semaphores[key] = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)
    return _semaphores[key]


class LLMClient:
    def __init__(self, api_key: str | None = None, model: str | None = None) -> None:
        s = get_settings()
        self.api_key = api_key if api_key is not None else s.groq_api_key
        self.model = model or s.groq_model

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    async def generate(self, prompt: str, *, system: str | None = None, temperature: float = 0.2, json_mode: bool = False) -> str:
        if not self.api_key:
            raise VerifiError("GROQ_API_KEY is not set (put it in .env and restart)", code="llm_not_configured")
        sys_prompt = system or ""
        if json_mode:
            # Groq's JSON mode requires the word "JSON" to appear in the messages.
            sys_prompt += "\n\nRespond with a single valid JSON object only. No prose, no code fences."
        messages = []
        if sys_prompt.strip():
            messages.append({"role": "system", "content": sys_prompt.strip()})
        messages.append({"role": "user", "content": prompt})

        body: dict[str, Any] = {"model": self.model, "messages": messages, "temperature": temperature, "max_tokens": 2048}
        if "gpt-oss" in self.model:
            body["reasoning_effort"] = "low"  # keep reasoning models fast and stop them cutting off the JSON
        if json_mode:
            body["response_format"] = {"type": "json_object"}

        async with _semaphore():
            data = await request_json(
                "POST", GROQ_URL, service="groq",
                headers={"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"},
                json_body=body, timeout=15.0, retries=2,
            )
        try:
            return data["choices"][0]["message"]["content"] or ""
        except (KeyError, IndexError, TypeError) as exc:
            raise VerifiError(f"Unexpected Groq response: {str(data)[:200]}", code="groq_bad_response") from exc

    async def generate_json(self, prompt: str, *, system: str | None = None, temperature: float = 0.1) -> Any:
        text = await self.generate(prompt, system=system, temperature=temperature, json_mode=True)
        try:
            return parse_json(text)
        except VerifiError:
            raise VerifiError("LLM returned invalid JSON", code="llm_invalid_json")
