"""Regenerate shared/fingerprint_vectors.json. Run from the repo root:
    python -m backend.scripts.make_vectors
Re-run (and tell Muheed + Ghunain) whenever shared/normalize_map.json or the algorithm changes."""
import json
from pathlib import Path

from backend.app.core.fingerprint import compute_fingerprint
from backend.app.core.normalize import normalize
from backend.tests.test_normalize import ADVERSARIAL, BASE

EXTRA = [
    ("base_claim", BASE),
    ("two_tokens", "hot water"),
    ("one_token", "dengue"),
    ("urdu_script_claim", "\u06af\u0631\u0645 \u067e\u0627\u0646\u06cc \u067e\u06cc\u0646\u06d2 \u0633\u06d2 \u0688\u06cc\u0646\u06af\u06cc \u0679\u06be\u06cc\u06a9 \u06c1\u0648\u062a\u0627 \u06c1\u06d2"),
    ("roman_urdu_claim", "Garam pani peene se dengue theek ho jata hai, ye sach nhi hai"),
    ("long_claim", "The government announced that all schools will remain closed next week because of heavy rain and flooding across the province, officials said on Friday"),
]

cases = [(n, t) for n, t, _ in ADVERSARIAL] + EXTRA
out = {
    "version": 1,
    "_doc": "Every client must reproduce normalized and fingerprint exactly for every input.",
    "vectors": [
        {"name": n, "input": t, "normalized": normalize(t), "fingerprint": compute_fingerprint(t)}
        for n, t in cases
    ],
}
path = Path(__file__).resolve().parents[2] / "shared" / "fingerprint_vectors.json"
path.write_text(json.dumps(out, ensure_ascii=True, indent=1) + "\n", encoding="utf-8")
print("wrote", path, len(out["vectors"]), "vectors")
