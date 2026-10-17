from __future__ import annotations

import time
from abc import ABC, abstractmethod
from typing import Any

from .common import get_logger

logger = get_logger(__name__)


class BaseAgent(ABC):
    """Every agent implements `run(state) -> dict` and returns ONLY the keys it adds or changes.
    `execute` merges those updates into the full state, so agents never drop earlier keys."""

    name: str = "agent"

    async def execute(self, state: dict[str, Any]) -> dict[str, Any]:
        start = time.perf_counter()
        updates = await self.run(dict(state))
        logger.info("[%s] done in %.1fs", self.name, time.perf_counter() - start)
        return {**state, **(updates or {})}

    @abstractmethod
    async def run(self, state: dict[str, Any]) -> dict[str, Any]:
        """Return a dict of state updates."""
