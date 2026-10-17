# Verifi web

The Next.js web client currently supports the backend's install-token and quick-check
API:

- `POST /api/v1/auth/install`
- `GET /api/v1/lookup/{prefix}`
- `POST /api/v1/quick-check`

Before a check, the client computes the shared fingerprint, asks lookup for its
four-character prefix, and compares full fingerprints locally. If there is no exact
cached match, it sends `text`, `lang: "auto"`, and `source: "web"` to quick-check.
The fingerprint implementation uses `shared/normalize_map.json` and is defined by
the test vectors in `shared/fingerprint_vectors.json`.

The Radar, Admin, and Fact-checker routes are informational placeholders; reporting,
radar, and fact-check publishing are not implemented by the current backend and
those pages do not make API requests.

## Run locally

1. Start the backend using the instructions in `backend/README.md`.
2. From this directory, install dependencies with `npm install`.
3. Set `NEXT_PUBLIC_API_BASE` if the API is not at
   `http://localhost:8000/api/v1`.
4. Run `npm run dev`.

Set `NEXT_PUBLIC_USE_MOCK=true` only to preview the sample quick-check results
without contacting the backend. In normal use, leave it unset or set it to `false`.
Backend `MOCK_MODE` is separate and makes the backend itself return its sample
quick-check result.
