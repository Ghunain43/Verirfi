# Verifi Threat Model

Team Bug Beaters · Code//Connect, Problem 03 (Misinformation Control)
Status: v1 draft. Items marked "(verify)" must be confirmed with the owner of that component before the final submission.

## 1. What we protect

| Asset | Why it matters |
|---|---|
| Message text, sender, group | Private conversations. The server must never store them. |
| Install token | Only identity a client has. Used for rate limiting. |
| Rumor Radar integrity | If it can be gamed, Verifi itself becomes a misinformation tool. |
| Fact-checker responses | Must be provably from a real fact-checker. |
| Service availability | Free research and LLM calls cost money. |

## 2. Who might attack

- **Spammer**: floods /quick-check to burn research budget.
- **Rumor pusher**: fakes reports to push a false or true claim onto the radar.
- **Evader**: edits a message so it no longer matches a known claim.
- **Impersonator**: pretends to be a fact-checker.
- **Snoop**: wants to learn what a user checked (network observer, curious operator, third-party provider).

## 3. Threats and defenses

| # | Threat | Defense in our design | Residual risk |
|---|---|---|---|
| 1 | **Fake reports** push a claim onto the radar | A claim appears only after N = 10 reports from **distinct installs**. Reports carry only a fingerprint, never text. | Anyone can mint install tokens, so a determined attacker with many tokens (Sybil attack) can reach N. Per-IP and per-token abuse thresholds reduce this (verify). |
| 2 | **Spam / flooding** of /quick-check | 20 checks per install token per hour, 2000 characters per request, 25 s timeout. | Token farming bypasses the per-token limit. Needs IP-level limits (verify). |
| 3 | **Evasion** (homoglyphs, emoji, zero-width characters, Roman Urdu spelling variants) | Text is normalized on the client first: lowercase, Unicode NFKC, homoglyph mapping, emoji and zero-width removal, Roman Urdu canonical forms (`shared/normalize_map.json`). SimHash over word 3-grams means small edits only change a few bits, and matching uses Hamming distance. Shared test vectors keep Python, TypeScript and Dart identical. | Heavy paraphrase, translation to another language, and text inside images or screenshots can still evade the cache. They fall back to a fresh /quick-check. |
| 4 | **Server learns what a user checked** | Message text is processed in memory and not stored. Cache lookup sends only a 4-hex-character prefix, so the server returns a whole bucket and the client matches locally (k-anonymity). Reports use randomized-response noise applied on the client (local differential privacy). No accounts. | A fresh /quick-check still sends the text to our server and to the research/LLM provider. Network metadata (IP, timing) is visible to the operator. A rare message may sit alone in its prefix bucket. We state this honestly in the product. |
| 5 | **Fake fact-checker** answers | /factcheck needs a fact-checker API key. Official responses are signed and clients verify the signature (verify scheme with Sharjeel). | A leaked key allows forged answers until it is revoked. Key rotation needed. |
| 6 | **Token theft or replay** | Tokens are random and expire (30 days). On the web the token is the only thing in localStorage. A stolen token only grants the rate-limited quick-check quota. | XSS on the web app could read the token. Mitigation: no raw HTML rendering, strict CSP, `rel="noopener noreferrer"` on evidence links. |
| 7 | **Malicious content in evidence** (XSS, phishing links) | Evidence fields are rendered as plain text. Links open in a new tab with `noopener noreferrer`. | A legitimate-looking but wrong source can still be shown. Quality score and stance are displayed so users can judge. |
| 8 | **Verifi mislabels something** and causes harm | Output is always a **range plus evidence**, never a bare TRUE/FALSE. "Not enough evidence to say" is a valid answer. A scope gate refuses opinion, satire, religion, prediction and vague text. | The model can still be wrong. The UI invites users to read the sources. |
| 9 | **Prompt injection** inside the message ("ignore previous instructions...") | The message is treated as data to extract a claim from, and the final output is a structured result, not free action. (verify with Ghunain) | Cannot be fully eliminated. Structured output limits the damage. |
| 10 | **Logs leak message text** | Rule for every component: never log or store message text. Only fingerprints and counts persist. | Needs a code review pass before submission. |
| 11 | **Cross-site abuse of the API** | CORS uses an explicit allow-list of full origins. | Misconfigured allow-list. Review it before release. |

## 4. Out of scope (for now)

- Images, voice notes and video.
- Attackers who control the user's device.
- Legal takedown requests.

## 5. Pre-submission checklist

- [ ] No `console.log` or server log prints message text.
- [ ] `.env` files are not in git.
- [ ] CORS allow-list contains only our real origins.
- [ ] Fingerprint test vectors pass in Python, TypeScript and Dart.
- [ ] Radar threshold N = 10 is enforced on the server.
- [ ] Rate limit returns 429 with `Retry-After`.
- [ ] Fact-checker signature check is demonstrated.
