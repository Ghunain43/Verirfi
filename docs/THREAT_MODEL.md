# Threat model

This describes the current FastAPI implementation, not planned features. The current
API has install-token, quick-check, lookup, and health routes. Rumor reporting,
radar, and fact-check publishing are not implemented.

## What the server receives and processes

- `POST /api/v1/quick-check` receives the selected text (up to 2,000 characters),
  language hint, and client source. The text is processed by the research pipeline
  when mock mode is off.
- The API computes a fingerprint. For checkable results, an in-memory cache keeps
  the fingerprint, extracted claim, answer, confidence range, evidence, and check
  time. The original submitted text is not included in that cache.
- `GET /api/v1/lookup/{prefix}` returns cached entries for the supplied four-character
  fingerprint prefix. The response can include extracted claims and evidence; the
  lookup is not anonymous and requires an install token.
- Requests also contain an install token. The browser client stores this token in
  local storage. The backend keeps token expiry and rate-limit counters in memory.

## Logging and retention

- The quick-check route's own error handling logs error codes or exception types,
  not the submitted text.
- Agent error paths can log text derived from a claim, including search queries, and
  provider exception messages. Therefore the current implementation cannot guarantee
  that no user-derived text appears in logs; production logging should be reviewed
  and sanitized before making that privacy promise.
- The claim cache is in-memory and bounded; it is lost when the backend process
  restarts. It is not a persistent database.
- This is not equivalent to "the server only stores fingerprints": the in-memory
  cache also contains extracted claims, answers, and evidence.

## Risks and limitations

- A compromised backend process can access request text while processing it, active
  tokens, cached claims, and cached evidence.
- Install tokens are bearer credentials. Anyone who obtains one can use its
  remaining quota until expiry or process restart.
- Token state, rate limits, and cached claims are process-local. Restarts clear
  them, and multiple backend workers do not share them.
- Prefix lookup intentionally exposes every cached item in a matching bucket to an
  authenticated client. The client is expected to compare full fingerprints locally.
- Rate limiting is per token and in-memory; it does not stop Sybil abuse or coordinate
  across workers.
- CORS is configured by `CORS_ORIGINS`; it is a browser policy, not authentication.
- Upstream research providers receive information required to research checkable
  claims. Their retention and privacy practices are outside this application.

## Not protected against

- A malicious or compromised server, provider, browser, or client device.
- Users creating many installs to evade per-token rate limits.
- False or manipulated model outputs, source quality problems, or misleading claims.
- Rumor brigading, because reporting and radar endpoints are not yet implemented.
