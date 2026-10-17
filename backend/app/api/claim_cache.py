"""In-memory store of already-checked claims, keyed by fingerprint (API.md section 4).

Privacy: only the extracted claim, the verdict and the evidence are kept, never the
text the user selected, never who asked. Nothing here is written to disk.
"""
from collections import OrderedDict, defaultdict
from datetime import datetime, timezone
from typing import Optional

MAX_ENTRIES = 5000  # oldest entries are evicted first

# fields of a quick-check result that are worth keeping (server fields are added per request)
RESULT_KEYS = (
    "checkable", "claim", "reason_unchecked", "likely_answer",
    "confidence_low", "confidence_high", "evidence", "lang_detected",
)


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class ClaimCache:
    def __init__(self, max_entries: int = MAX_ENTRIES) -> None:
        self.max_entries = max_entries
        self._entries: "OrderedDict[str, dict]" = OrderedDict()   # fingerprint -> entry, oldest first
        self._buckets: dict[str, set[str]] = defaultdict(set)     # 4-hex prefix -> fingerprints

    def put(self, fingerprint: str, result: dict) -> None:
        fp = fingerprint.lower()
        entry = {k: result[k] for k in RESULT_KEYS if k in result}
        entry["fingerprint"] = fp
        entry["checked_at"] = _now()
        self._entries[fp] = entry
        self._entries.move_to_end(fp)
        self._buckets[fp[:4]].add(fp)
        while len(self._entries) > self.max_entries:
            old, _ = self._entries.popitem(last=False)
            bucket = self._buckets[old[:4]]
            bucket.discard(old)
            if not bucket:
                del self._buckets[old[:4]]

    def get(self, fingerprint: str) -> Optional[dict]:
        return self._entries.get(fingerprint.lower())

    def bucket(self, prefix: str) -> list[dict]:
        fps = sorted(self._buckets.get(prefix.lower(), ()))
        return [self._entries[fp] for fp in fps]

    def clear(self) -> None:
        self._entries.clear()
        self._buckets.clear()

    def __len__(self) -> int:
        return len(self._entries)


cache = ClaimCache()
