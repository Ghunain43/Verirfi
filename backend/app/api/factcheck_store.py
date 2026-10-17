"""In-memory store of signed fact-checker responses, per fingerprint.
One response per publisher per fingerprint: publishing again replaces your earlier ruling.
Lost on restart (same as the claim cache); move to a database before real use."""
from collections import OrderedDict
from typing import Optional

MAX_FINGERPRINTS = 2000
MAX_PER_FINGERPRINT = 20


class FactCheckStore:
    def __init__(self) -> None:
        self._by_fp: "OrderedDict[str, list[dict]]" = OrderedDict()  # fingerprint -> records, newest first

    def publish(self, record: dict) -> None:
        fp = record["fingerprint"]
        records = [r for r in self._by_fp.get(fp, []) if r["publisher"] != record["publisher"]]
        records.insert(0, record)
        self._by_fp[fp] = records[:MAX_PER_FINGERPRINT]
        self._by_fp.move_to_end(fp)
        while len(self._by_fp) > MAX_FINGERPRINTS:
            self._by_fp.popitem(last=False)

    def bucket(self, prefix: str) -> dict:
        prefix = prefix.lower()
        return {fp: list(rs) for fp, rs in self._by_fp.items() if fp.startswith(prefix) and rs}

    def list_for(self, publisher: str) -> list:
        out = [r for rs in self._by_fp.values() for r in rs if r["publisher"] == publisher]
        out.sort(key=lambda r: r["published_at"], reverse=True)
        return out

    def delete(self, record_id: str, publisher: str) -> bool:
        for fp, records in list(self._by_fp.items()):
            for r in records:
                if r["id"] == record_id and r["publisher"] == publisher:
                    records.remove(r)
                    if not records:
                        del self._by_fp[fp]
                    return True
        return False

    def clear(self) -> None:
        self._by_fp.clear()


store = FactCheckStore()
