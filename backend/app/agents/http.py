from __future__ import annotations

import asyncio
import json
from typing import Any

import aiohttp

from .common import VerifiError, get_logger

logger = get_logger(__name__)


async def request_json(
    method: str,
    url: str,
    *,
    service: str,
    headers: dict[str, str] | None = None,
    json_body: Any = None,
    timeout: float = 15.0,
    retries: int = 2,
) -> Any:
    """HTTP call returning parsed JSON. Retries on 429/5xx/network errors with a short backoff."""
    last: VerifiError | None = None
    for attempt in range(1, retries + 1):
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=timeout)) as session:
                async with session.request(method, url, headers=headers, json=json_body) as resp:
                    text = await resp.text()
                    if resp.status == 429 or resp.status >= 500:
                        last = VerifiError(f"{service} HTTP {resp.status}: {text[:200]}", code=f"{service}_http_{resp.status}")
                        logger.warning("%s (attempt %s/%s)", last.message, attempt, retries)
                    elif resp.status >= 400:
                        raise VerifiError(f"{service} HTTP {resp.status}: {text[:200]}", code=f"{service}_http_{resp.status}")
                    else:
                        return json.loads(text) if text.strip() else None
        except (aiohttp.ClientError, asyncio.TimeoutError) as exc:
            last = VerifiError(f"{service} request failed: {exc}", code=f"{service}_network")
            logger.warning("%s (attempt %s/%s)", last.message, attempt, retries)
        if attempt < retries:
            await asyncio.sleep(0.5 * attempt)
    raise last or VerifiError(f"{service} request failed", code=f"{service}_failed")
