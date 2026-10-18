# Veritus AI: Backend

FastAPI service used by the web app, the Android app and the Chrome extension. Live at <https://verifi.fastapicloud.dev> (interactive docs at `/docs`).

## Layout

```
app/api/       Routes (auth, quick-check, lookup, radar), settings, security, rate limits
app/agents/    Research pipeline: claim -> research -> source -> evidence -> answer (Tavily + Groq)
app/core/      Normalisation and claim fingerprinting (simhash)
tests/         pytest suite (no network needed)
```

## Run locally

From the **repo root** (the app imports as `backend.app...` and reads `shared/normalize_map.json`):

```bash
pip install -r backend/requirements.txt
cp .env.example .env          # fill in keys, or keep MOCK_MODE=true for sample answers
uvicorn backend.app.api.main:app --reload --port 8000
```

Open <http://localhost:8000/docs>. Run tests with `python -m pytest backend/tests`.

## Endpoints

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/health` | `{"status": "ok"}` |
| POST | `/api/v1/auth/install` | Returns `install_token` (valid 30 days) |
| POST | `/api/v1/quick-check` | Body: `text` (max 2000 chars), `lang` (`en`, `ur`, `ur-Latn`, `auto`), `source` (`web`, `mobile`, `extension`) |
| GET | `/api/v1/lookup/{prefix}` | Cached results for a 4-hex fingerprint prefix |
| GET | `/api/v1/radar` | Rumor Radar items |

Send the token as `Authorization: Bearer <token>`. Example:

```bash
B=https://verifi.fastapicloud.dev/api/v1
T=$(curl -s -X POST $B/auth/install -H 'Content-Type: application/json' -d '{}' | python -c 'import sys,json;print(json.load(sys.stdin)["install_token"])')
curl -s -X POST $B/quick-check -H "Authorization: Bearer $T" -H 'Content-Type: application/json' \
  -d '{"text":"Drinking hot water cures dengue fever.","lang":"auto","source":"web"}'
```

A checkable result contains `claim`, `likely_answer`, `confidence_low`, `confidence_high`, `evidence[]` (title, url, publisher, stance, quality, snippet), `fingerprint`, `cached` and `took_ms`. Text that is not a claim returns `checkable: false` with a `reason_unchecked`.

Errors use `{"error": {"code", "message"}}`: `invalid_input` 400, `invalid_token` 401, `rate_limited` 429 (with `Retry-After`), `upstream_failed` 502, `timeout` 504.

## Rumor Radar

`GET /radar` returns community claims first: claims checked by at least `RADAR_MIN_INSTALLS` (10) different installs on at least `RADAR_MIN_NETWORKS` (3) different networks, active in the last `RADAR_WINDOW_HOURS` (168). If fewer than `RADAR_FILL_TO` (5) qualify, it is topped up with recent false claims found by fact-checkers (Tavily search plus an LLM extraction, cached for 3 hours). Each item has `origin` (`community` or `web`), `why`, and for web claims a `source_url` and `publisher`.

The radar keeps only claim fingerprints and salted hashes of installs and networks, in memory.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `MOCK_MODE` | `true` | `false` runs the real pipeline. Set it explicitly in production |
| `GROQ_API_KEY`, `GROQ_MODEL` | none | LLM provider and the model name that works for your key |
| `TAVILY_API_KEY` | none | Web search |
| `TOKEN_SECRET` | random per start | Signs install tokens. Set it so tokens survive restarts and work across instances |
| `RADAR_SALT` | dev value | Salt for the radar hashes. Set a long random value |
| `CORS_ORIGINS` | `http://localhost:3000` | Comma-separated allowed web origins, no trailing slash |
| `RATE_LIMIT_PER_HOUR` | `20` | Checks per install per hour |
| `RADAR_TRUST_FORWARDED`, `RADAR_PROXY_HOPS` | `false`, `1` | Read the client network from `X-Forwarded-For` (only behind your own proxy) |
| `RADAR_WEB_ENABLED`, `RADAR_REGION` | `true`, empty | Web fact-check fill, and an optional region such as `Pakistan` |

## Deploy on FastAPI Cloud

Add a root `pyproject.toml` so the CLI finds the app and installs only the dependencies:

```toml
[project]
name = "verifi"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["fastapi[standard]>=0.115", "aiohttp>=3.9", "python-dotenv>=1.0", "pydantic>=2"]

[tool.fastapi]
entrypoint = "backend.app.api.main:app"

[tool.setuptools]
py-modules = []

[tool.uv]
package = false
```

Then, from the repo root:

```bash
fastapi login
fastapi cloud env set MOCK_MODE false     # repeat for the other variables above
fastapi deploy
```

Make sure `shared/normalize_map.json` is committed and included.

## Operating notes

- The claim cache, rate limits and radar are in memory. Restarts and sleeping on the free tier clear them. Tokens are signed and keep working.
- The free tier can run more than one replica under load, so cache and radar data may be split between them.
- The first request after idle can take up to a minute.
