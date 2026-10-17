# Verifi API Contract (v1)

Single source of truth for the backend, extension, mobile app and web app.
Any change to this file goes through Ghunain and is announced to the team.

- Base URL (local): `http://localhost:8000/api/v1`
- Format: JSON over HTTPS, UTF-8
- Principle: the server never stores message text, sender or group. Only the extracted claim is processed, and only fingerprints and counts are kept.

---

## 1. Anonymous install token

No accounts. Each client install gets a random token and sends it on every request.

### `POST /auth/install`
Request: `{}`

Response `201`:
```json
{ "install_token": "string", "expires_in": 2592000 }
```

Send it on all other calls:
`Authorization: Bearer <install_token>`

---

## 2. Quick check (the main endpoint)

### `POST /quick-check`

Request:
```json
{
  "text": "string (max 2000 chars)",
  "lang": "en | ur | ur-Latn | auto",
  "source": "extension | mobile | web"
}
```

- `lang`: `ur-Latn` means Roman Urdu. Default is `auto`.
- `text` is processed in memory and is not stored.

Response `200`:
```json
{
  "checkable": true,
  "claim": "Normalized claim as a clear standalone sentence",
  "reason_unchecked": null,
  "likely_answer": "Most likely false: official sources say X.",
  "confidence_low": 0.62,
  "confidence_high": 0.81,
  "evidence": [
    {
      "title": "Source title",
      "url": "https://example.com/article",
      "publisher": "Example News",
      "stance": "supporting | contradicting | neutral",
      "quality": 0.8,
      "snippet": "Short excerpt in our own words"
    }
  ],
  "lang_detected": "en",
  "fingerprint": "hex string",
  "cached": false,
  "took_ms": 6400
}
```

Rules:
- If `checkable` is `false` (opinion, satire, religion, prediction, too vague), then `reason_unchecked` is one of `opinion | satire | religious | prediction | too_vague | no_claim`. `likely_answer` is `null`, `evidence` is `[]` and no research runs.
- We show a **range** (`confidence_low` to `confidence_high`) and evidence, never a bare TRUE/FALSE.
- `likely_answer` is empty or `"Not enough evidence to say"` when sources are insufficient. That is a valid answer.
- `fingerprint` is computed on the server too, so clients can confirm they match (see section 4).

Errors: see section 6.

---

## 3. Python contract (backend internal)

Ghunain owns `backend/app/agents/`, Sharjeel owns `backend/app/api/`.
The route calls exactly this function and never touches agent internals.

```python
# backend/app/agents/quick_check.py
from pydantic import BaseModel
from typing import Literal, Optional

class Evidence(BaseModel):
    title: str
    url: str
    publisher: Optional[str] = None
    stance: Literal["supporting", "contradicting", "neutral"]
    quality: float            # 0..1
    snippet: Optional[str] = None

class QuickCheckResult(BaseModel):
    checkable: bool
    claim: str
    reason_unchecked: Optional[str] = None
    likely_answer: Optional[str] = None
    confidence_low: float = 0.0
    confidence_high: float = 0.0
    evidence: list[Evidence] = []
    lang_detected: str = "en"

async def run_quick_check(claim: str, lang: str) -> QuickCheckResult: ...
```

Until the real agents are ready, `run_quick_check` returns fake data in this exact shape.

---

## 4. Private lookup (Phase 2)

Clients compute a fingerprint locally and check a cache before any network call.

### Fingerprint spec (owner: Sharjeel, must match in Python, TypeScript and Dart)
1. Normalize: lowercase, Unicode NFKC, map homoglyphs to ASCII, remove emoji and zero-width characters, collapse whitespace.
2. Roman Urdu spelling variants are mapped to canonical forms (table lives in `shared/normalize_map.json`).
3. SimHash over word 3-grams, 64 bits, output as 16 hex characters.

A shared test file `shared/fingerprint_vectors.json` holds input and expected-output pairs. Every client must pass it.

### `GET /lookup/{prefix}`
`prefix` is the first 4 hex characters of the fingerprint. The server returns every known checked claim in that bucket. The client does the final match locally (Hamming distance), so the server never learns the exact message.

Response `200`:
```json
{
  "prefix": "a3f1",
  "entries": [
    { "fingerprint": "a3f19c...", "claim": "", "likely_answer": "",
      "confidence_low": 0.0, "confidence_high": 0.0,
      "evidence": [], "checked_at": "2026-10-17T10:00:00Z" }
  ]
}
```

---

## 5. Rumor reporting and radar (Phase 3)

### `POST /report`
Opt-in anonymous report. Only the fingerprint is sent, with randomized-response noise applied on the client.
```json
{ "fingerprint": "hex", "region": "optional coarse region code", "noisy": true }
```
Response `202`: `{}`

### `GET /radar`
Aggregated trending claims. A claim appears only after at least `N` reports from distinct installs (default `N = 10`).
```json
{ "items": [ { "fingerprint": "", "claim": "", "reports": 42, "first_seen": "", "last_seen": "" } ] }
```

### `POST /factcheck` (fact-checker only)
Signed publishing of an official response to a claim. Requires a fact-checker API key. Details to be added by Sharjeel.

---

## 6. Errors

All errors share one shape:
```json
{ "error": { "code": "rate_limited", "message": "Human-readable text" } }
```

| HTTP | code | Meaning |
|---|---|---|
| 400 | `invalid_input` | Empty text, over 2000 chars, bad `lang` |
| 401 | `invalid_token` | Missing or expired install token |
| 429 | `rate_limited` | Too many requests; see `Retry-After` header |
| 502 | `upstream_failed` | Research or LLM provider failed |
| 504 | `timeout` | Check took longer than 25 seconds |

---

## 7. Limits

- 2000 characters per request
- Rate limit: 20 quick-checks per install token per hour (tunable)
- Timeout: 25 seconds, target under 10 seconds
- CORS: explicit allow-list of origins (full URLs with `https://`); the extension uses its own `chrome-extension://<id>` origin

---

## 8. Health

`GET /health` returns `{ "status": "ok", "version": "x.y.z" }`. No token needed.

---

## 9. Mock mode

Set `MOCK_MODE=true` in `.env` and `/quick-check` returns fixed sample responses (one checkable, one opinion) so clients can be built before the real agents are done.

Sample checkable response:
```json
{
  "checkable": true,
  "claim": "Drinking hot water cures dengue fever.",
  "reason_unchecked": null,
  "likely_answer": "Most likely false: health authorities say there is no cure, only supportive care.",
  "confidence_low": 0.7,
  "confidence_high": 0.9,
  "evidence": [
    { "title": "Dengue fact sheet", "url": "https://www.who.int/news-room/fact-sheets/detail/dengue-and-severe-dengue",
      "publisher": "WHO", "stance": "contradicting", "quality": 0.95,
      "snippet": "No specific treatment exists; care is supportive." }
  ],
  "lang_detected": "en",
  "fingerprint": "a3f19c2b7d4e8a01",
  "cached": false,
  "took_ms": 120
}
```

Sample unchecked response:
```json
{
  "checkable": false,
  "claim": "This party is the worst thing to happen to our country.",
  "reason_unchecked": "opinion",
  "likely_answer": null,
  "confidence_low": 0.0,
  "confidence_high": 0.0,
  "evidence": [],
  "lang_detected": "en",
  "fingerprint": "5c01e9aa13b27f64",
  "cached": false,
  "took_ms": 80
}
```

---

## Change log
- v1: initial contract (quick-check, install token, errors, limits, mock mode)
