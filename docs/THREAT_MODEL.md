<<<<<<< Updated upstream
# Threat model (draft)
- What the server sees:
- What the server never sees:
- If the server is compromised:
- Abuse cases (brigading, fake fact-checks, cache poisoning, evasion):
- Not protected against:
=======
# Verifi Threat Model

Team Bug Beaters · Code//Connect, Problem 03 (Misinformation Control)
Status: v2. Backend facts come from `docs/PRIVACY_AND_ABUSE.md` (written from the backend code). Anything not yet confirmed is listed in section 5 as an open item, not hidden in the table.

## 1. What we protect

| Asset | Why it matters |
|---|---|
| Message text, sender, group | Private conversations. The server must never store them. |
| Install token | The only identity a client has. Used for rate limiting. |
| Rumor Radar integrity | If it can be gamed, Verifi itself becomes a misinformation tool. |
| Fact-checker responses | Must be provably from a real fact-checker. |
| Service availability | Research and LLM calls cost money. |

## 2. Who might attack

- **Spammer**: floods `/quick-check` to burn research budget.
- **Rumor pusher**: fakes reports to push a claim onto the radar.
- **Evader**: edits a message so it no longer matches a known claim.
- **Impersonator**: pretends to be a fact-checker.
- **Snoop**: wants to learn what a user checked (network observer, curious operator, third-party provider).

## 3. Threats and defenses

| # | Threat | Defense in the current design | Residual risk |
|---|---|---|---|
| 1 | **Fake reports** push a claim onto the radar | A claim appears only after reports from at least **10 distinct installs on 3 distinct networks**. Max 30 reports per hour per token. Reports carry only a fingerprint, never text. | An attacker with 10 tokens across 3 or more networks (VPN, botnet) still succeeds. |
| 2 | **Spam and flooding** of `/quick-check` | 20 checks per token per hour, 2000 characters per request, 25 s timeout, flood detection for near-identical variants, repeats answered from cache. Token creation is limited to 30 per hour per coarse network, with strikes and a 1 hour block after repeated violations. | Token minting from many networks. |
| 3 | **Evasion** (homoglyphs, emoji, zero-width characters, Roman Urdu spellings) | Text is normalized on the client first (lowercase, Unicode NFKC, homoglyph mapping, emoji and zero-width removal, Roman Urdu canonical forms in `shared/normalize_map.json`). SimHash over word 3-grams means small edits change only a few bits. Shared test vectors keep Python, TypeScript and Dart identical. | Heavy paraphrase, translation and text inside images can evade the cache and fall back to a fresh check. Lookup by exact 4-character prefix also misses near-duplicates whose prefix differs. |
| 4 | **Server learns what a user checked** | Text is processed in memory only and not stored. Lookup sends a 4-hex-character prefix (1 in 65,536); the client matches locally. Network addresses are reduced to a coarse network and kept only as a salted hash. No accounts. Reports use client-side noise (25%) and per-claim unlinkable identifiers, with no install-to-claim table. | A fresh check still sends text to our server and to the research and LLM providers. Hosting platforms keep their own request logs (IP, paths, lookup prefixes). Noise is applied by the client and cannot be enforced. A claim just over the radar threshold reveals that about 10 installs reported it. |
| 5 | **Fake fact-checker** answers | Publishing needs a fact-checker API key (`X-API-Key`); install tokens are rejected. Keys are 16+ characters, compared in constant time, with lockout after 10 failures per hour per network. Each response is signed with Ed25519 over its exact payload, and clients verify it using the key from `GET /factcheck/public-key`. Fact-checkers can replace or retract only their own responses. | A stolen key allows signed false rulings until it is removed (rotate in `.env` and restart). There is no audit log. A compromised server could swap the public key until clients pin it. |
| 6 | **Token theft or replay** | Tokens are random and expire after 30 days. On the web, the token is the only thing stored in the browser. A stolen token grants only the rate-limited quota. | XSS on the web app could read the token. Mitigation: React escapes all text, no raw HTML is rendered, and evidence links use `rel="noopener noreferrer"`. |
| 7 | **Malicious content in evidence** (phishing links, XSS) | Evidence fields are rendered as plain text. Links open in a new tab with `noopener noreferrer`. | A convincing but wrong source can still be shown. Quality score and stance are displayed so users can judge. |
| 8 | **Verifi mislabels something** and causes harm | Output is always a **range plus evidence**, never a bare TRUE or FALSE. "Not enough evidence to say" is a valid answer. A scope gate refuses opinion, satire, religion, prediction and vague text. | The model can still be wrong. The UI invites users to read the sources. |
| 9 | **Prompt injection** inside the message | The message is treated as data to extract a claim from, and the final output is a structured result. | Not yet reviewed (see open item 1). Cannot be fully eliminated. |
| 10 | **Logs leak message text** | The API code logs only error codes and exception type names, never text, fingerprints, prefixes or tokens. The uvicorn access log is filtered: client addresses are replaced and `/lookup/` and `/report` lines are dropped. | Hosting platform logs are outside our control. The agents' code has not been reviewed for logging (open item 1). |
| 11 | **Cross-site abuse of the API** | CORS uses an explicit allow-list of full origins. `X-Forwarded-For` is trusted only when `TRUST_PROXY=true`, and only its last entry. | A wrong allow-list or proxy setting breaks protection or per-network limits. |
| 12 | **State loss** | All server data is in memory. Clients request a new install token after a 401. | A restart clears the cache, reports, radar and fact-check responses. |

## 4. Out of scope (for now)

- Images, voice notes and video.
- Attackers who control the user's device.
- Legal takedown requests.
- Formal differential privacy. The 25% noise is a design choice, not a proven guarantee.

## 5. Open items (before final submission)

1. **Agents (Ghunain):** confirm whether the full selected text or only the extracted claim is sent to the search and LLM providers, that the agents never log text, and how prompt injection is handled.
2. **Public key pinning:** pin the fact-check public key in the extension, app and web build.
3. **Deployment:** set `TRUST_PROXY=true`, run uvicorn behind the host's proxy and check the host's log retention.
4. **Storage:** move to a database if the project continues past the demo.

## 6. Pre-submission checklist

- [ ] No `console.log` or server log prints message text.
- [ ] `.env` files are not in git.
- [ ] CORS allow-list contains only our real origins.
- [ ] Fingerprint test vectors pass in Python, TypeScript and Dart.
- [ ] Radar threshold (10 installs, 3 networks) is enforced on the server.
- [ ] Rate limit returns 429 with `Retry-After`.
- [ ] Fact-checker signature check is demonstrated.
>>>>>>> Stashed changes
