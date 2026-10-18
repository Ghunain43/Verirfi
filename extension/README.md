# Verifi Chrome extension

Select text on any page, press **Check with Verifi**, read the result. Manifest V3, TypeScript.

## Build and load

```bash
cd extension
npm install
npm run check        # typecheck + tests + build
```
Then open `chrome://extensions`, turn on **Developer mode**, click **Load unpacked** and pick the `extension/dist` folder.
Start the backend first (`uvicorn backend.app.api.main:app --port 8000` from the repo root). The extension talks to
`http://localhost:8000/api/v1` by default; change it from the toolbar icon (a non-local server must be https).

## What it does

| Feature | Where |
|---|---|
| Floating **Check** button on selected text (15 to 2000 characters), result popup in a closed shadow root | `src/content.ts` |
| Private lookup first: only the 4-character fingerprint prefix is sent; the text is sent only if nothing matches | `src/background.ts` |
| Install token handling, 401 recovery (new token, one retry), rate-limit messages | `src/lib/api.ts` |
| Fingerprint port: normalize + 64-bit SimHash, must match `shared/fingerprint_vectors.json` | `src/lib/normalize.ts`, `simhash.ts` |
| Signed fact-checker responses: Ed25519 verified, key pinned on first use, ruling must be for the same fingerprint | `src/background.ts`, `src/lib/crypto.ts` |
| Opt-in anonymous report with 25% randomized-response noise | `src/lib/api.ts` (`withNoise`) |
| Compose-box underline (red wavy = known false or fact-checked, amber dotted = already checked); **off by default** | `src/compose.ts` |

## Privacy behaviour

- Pressing Check on a claim the server already knows does not send your text. Only a 4-hex-character prefix goes out.
- The compose-box underline sends one 4-character prefix per sentence you type, so it is off until you enable it in the toolbar popup.
- Page text is never inserted as HTML: everything from the server is rendered with `textContent`, and links must be `https://`.

## Known limits

- Compose underline needs a `contenteditable` box and the CSS Custom Highlight API (Chrome 105+). Plain `<textarea>` boxes are not underlined.
- Fact-checker signatures need Ed25519 in WebCrypto (Chrome 137+). On older versions rulings are hidden rather than trusted unverified.
- The UI code was written and type-checked but could only be unit-tested without a browser: click through it once in Chrome.
- Reset the pinned fact-checker key from the toolbar popup if the server's signing key changes on purpose.

## Tests

`npm test` runs the fingerprint port against the shared vectors, the matching and noise helpers, and a signature produced by the
real Python signer (cross-language check).
