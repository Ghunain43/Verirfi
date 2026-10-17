# agents/ (owner: Ghunain)

Entry point for the API layer (Sharjeel):

```python
from backend.app.agents import run_quick_check, VerifiError
result = await run_quick_check(text, lang)   # -> QuickCheckResult (shared/API.md section 3)
```

- `VerifiError.code`: `invalid_input` -> 400, `upstream_failed` -> 502, `timeout` -> 504.
- The route adds `fingerprint`, `cached`, `took_ms` itself.
- `MOCK_MODE=true` makes `run_quick_check` return fixed samples (no keys needed).
- Nothing is stored. All state lives in memory for the duration of one call.
- Env: `GROQ_API_KEY`, `GROQ_MODEL` (default llama-3.3-70b-versatile), `TAVILY_API_KEY`, `MOCK_MODE`, `QUICK_CHECK_TIMEOUT` (default 22s).
- Needs in backend/requirements.txt: `aiohttp`, `python-dotenv`, `pydantic>=2`, and for tests `pytest`, `pytest-asyncio`.
- Tests: `python -m pytest backend/tests/test_quick_check.py` (run from the repo root; no network).

Pipeline: claim_agent (scope gate) -> research_agent -> source_agent -> evidence_agent -> answer.build_answer
