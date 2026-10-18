# Veritus AI Threat Model

Team **Bug Beaters** · Code//Connect '26, Problem 03 (Misinformation Control)

Status: v3. Rewritten to match the current backend, web, Android and extension READMEs. Anything the READMEs do not confirm is listed in section 5 or 6 instead of being presented as built.

## 1. What we protect

| Asset | Why it matters |
| --- | --- |
| Message text | Private conversations. It must never be stored or logged. |
| Install token | The only identity a client has. Used for rate limiting. |
| Rumor Radar integrity | If it can be gamed, Veritus AI itself becomes a misinformation tool. |
| Answer quality | A wrong or manipulated answer can do harm. |
| Service availability and budget | Search and LLM calls cost money and the free tier is small. |

## 2. What the server sees, and what it never sees

| The server sees | The server never keeps |
| --- | --- |
| The text of a **fresh** check, for the length of one request, in memory | The text after the request ends. It is not stored or logged |
| A 4-hex-character fingerprint prefix on lookup (1 in 65,536) | The full claim from a lookup |
| An anonymous signed install token | Accounts, names, phone numbers, contacts, WhatsApp sender or group |
| A coarse network (IPv4 /24 or IPv6 /48), kept only as a salted hash | Raw IP addresses and raw tokens in the radar |
| Claim fingerprints and counts, in memory | Message text in the cache or radar |

**If the server is compromised**, or restarts: an attacker would find only fingerprints, salted hashes and counts. Message text is not at rest, but text being processed during an active request could be read. A leaked `TOKEN_SECRET` lets an attacker forge install tokens, and a leaked `RADAR_SALT` weakens the hashes. Rotate both and redeploy. A restart clears the cache, radar and rate limits.

**Outside providers.** A fresh check sends the claim text to the search provider (Tavily) and the LLM provider (Groq). Hosting platforms (FastAPI Cloud, Netlify) keep their own request logs. These are outside our control and are stated openly as a known limit.

## 3. Who might attack

- **Spammer:** floods `/quick-check` to burn search and LLM budget.
- **Rumor pusher:** tries to push a false or harmless claim onto the Rumor Radar.
- **Evader:** edits a message so it no longer matches a known claim.
- **Snoop:** wants to learn what a user checked (network observer, curious operator, third-party provider).
- **Injector:** puts instructions or links inside a message to steer the model or the reader.
- **Token thief:** reuses a stolen install token.

## 4. Threats and defenses

| # | Threat | Defense in the current build | Residual risk |
| --- | --- | --- | --- |
| 1 | **Fake radar entries.** Someone pushes a claim onto the radar | A community claim appears only after checks from at least **10 different installs on at least 3 different networks** within 168 hours (`RADAR_MIN_INSTALLS`, `RADAR_MIN_NETWORKS`, `RADAR_WINDOW_HOURS`). Only fingerprints and salted hashes are counted. Web fact-check items come from fact-checker sources, not from users | An attacker with 10 tokens across 3 or more networks (VPN, botnet) can still qualify. The threshold is a speed bump, not a guarantee |
| 2 | **Spam and flooding** of `/quick-check` | 20 checks per install per hour (`RATE_LIMIT_PER_HOUR`), 2000-character cap, strict input validation, `429` with `Retry-After`, repeat claims answered from cache, `504` timeout | A scripted attacker can mint many install tokens. In-memory limits reset on restart and can split across replicas |
| 3 | **Evasion.** Look-alike letters, emoji, zero-width characters, Roman Urdu spellings | Text is normalised (lowercase, Unicode normalisation, look-alike mapping, emoji and zero-width removal, Roman Urdu canonical forms from `shared/normalize_map.json`). The fingerprint is a SimHash, so small edits change only a few bits. Python, TypeScript and Dart share the same normalisation and test vectors | Heavy paraphrase, translation and text inside images can miss the cache and fall back to a fresh check. A lookup by exact 4-character prefix misses near-duplicates whose prefix differs |
| 4 | **The server learns what a user checked** | Text is processed in memory and not stored or logged. Lookup sends only a 4-hex prefix. No accounts. Networks are reduced to a coarse range and kept only as a salted hash. Android screenshots are read on the device | A fresh check still sends text to our server, Tavily and Groq. Hosting platforms keep request logs (IP, paths, lookup prefixes). A claim just over the radar threshold reveals that about 10 installs checked it |
| 5 | **Token theft or replay** | Tokens are random, signed and expire after 30 days. On the web the token is the only thing kept in the browser (extension: `chrome.storage.local`, Android: on-device storage). A stolen token only grants the rate-limited quota. Clients fetch a new token after a `401` | Cross-site scripting on the web app could read the token. React escapes text and evidence links use `rel="noopener noreferrer"` |
| 6 | **Malicious content in evidence** (phishing links, scripts) | Evidence fields are rendered as plain text. Links open in a new tab. Source quality and stance are shown so users can judge | A convincing but wrong source can still be shown |
| 7 | **Veritus AI mislabels something** and causes harm | Output is always a **confidence range plus evidence**, never a bare TRUE or FALSE. "Not enough evidence to say" is a valid answer. The scope gate refuses opinion, satire, faith, predictions and vague text and says why. The UI says "Not a verdict. Weigh the sources yourself." | The model can still be wrong |
| 8 | **Prompt injection** inside the message | The message is treated as data to extract a claim from, and the output is a structured result with a checked schema | Not yet formally reviewed (open item 1). It cannot be fully eliminated |
| 9 | **Logs leak message text** | The design rule is that message text is never logged. Clients and the API keep no text on disk | Hosting platform logs are outside our control. The agents' code still needs a logging review (open item 1) |
| 10 | **Cross-site abuse of the API** | CORS allows only the origins in `CORS_ORIGINS` (full origins, no trailing slash). `X-Forwarded-For` is trusted only when `RADAR_TRUST_FORWARDED=true`, using `RADAR_PROXY_HOPS` | A wrong allow-list or proxy setting breaks protection or makes radar networks wrong |
| 11 | **Extension misuse** | Minimal permissions. The text is read only when the user clicks the toolbar icon or the context menu. Only the backend host is contacted | A malicious page cannot read results, but users can still be shown a wrong answer |
| 12 | **Web admin and fact-checker pages exposed** | The `/factcheck` and `/admin` pages are behind a PIN screen | The PIN ships inside the site's JavaScript. It is a **soft lock, not security**. Protect nothing sensitive with it (open item 3) |
| 13 | **State loss** | All server data is in memory. Tokens are signed so they survive restarts | A restart or sleep clears the cache, radar and rate limits |

## 5. Open items (before final submission)

1. **Agents:** confirm whether the full selected text or only the extracted claim is sent to the search and LLM providers, confirm the agents never log text, and review prompt-injection handling.
2. **Secrets:** set long random `TOKEN_SECRET` and `RADAR_SALT` in production, keep `.env` out of git, and rotate if they ever leak.
3. **Admin and fact-checker pages:** the PIN is client-side only. Before any real use, move these tools behind a server-side check, or remove them from the public site.
4. **Deployment:** set `RADAR_TRUST_FORWARDED=true` behind the host's proxy with the right `RADAR_PROXY_HOPS`, and check the host's log retention.
5. **Storage:** move to a database if the project continues past the demo.

## 6. Earlier design ideas not confirmed in the current backend

These appeared in an earlier version of this document and are **not** listed in the current backend README. Do not claim them in the demo unless the backend code is confirmed to do them:

- A separate `/report` endpoint with client-side noise (25%) and per-claim unlinkable identifiers.
- Fact-checker answers signed with Ed25519, a `/factcheck/public-key` endpoint and public-key pinning, with API keys and lockouts.
- Token minting limits per network, strike and block rules, and flood detection for near-identical variants.
- Filtered access logs that drop `/lookup/` lines.

If any of these exist in the code, add them to section 4 with their real settings.

## 7. Out of scope (for now)

- Images, voice notes and video (screenshots on Android are read as text only).
- Attackers who control the user's device.
- Legal takedown requests.
- Formal differential privacy or any provable privacy guarantee.

## 8. Pre-submission checklist

- [ ] No `console.log`, print or server log writes message text.
- [ ] `.env` files are not in git. `.env.example` has no real keys.
- [ ] `TOKEN_SECRET` and `RADAR_SALT` are long random values in production.
- [ ] `CORS_ORIGINS` contains only our real origins.
- [ ] Fingerprint test vectors pass in Python, TypeScript and Dart.
- [ ] The radar threshold (10 installs, 3 networks) is enforced on the server.
- [ ] The rate limit returns `429` with `Retry-After`.
- [ ] The deployed backend runs with `MOCK_MODE=false`.
- [ ] The extension requests only the permissions listed in its README.
