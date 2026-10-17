# Verifi: server privacy and abuse notes

Written from the backend code (`backend/app/api`, `backend/app/core`) as of the abuse-thresholds and `/factcheck` commits. For the threat model and pitch. Every statement below is something the code does today; the "Open items" at the end are things not yet verified or not yet built.

## 1. Principle

The server answers "is this claim true?" without needing to know who asked or keeping what they wrote. Clients look claims up by a 4-character fingerprint prefix first, and the server only sees the full message text if the user explicitly runs a check.

## 2. What the server never keeps

- **The text a user selects.** It is processed in memory to answer one request. The API code does not store it or log it, and the claim cache holds only the claim as extracted by the agents, never the original text.
- **User identity.** There are no accounts, names, emails or phone numbers. An "install" is a random token.
- **Raw IP addresses.** Network addresses are reduced to a coarse network (IPv4 /24, IPv6 /48) and then kept only as a salted hash (see section 3).
- **Which install reported which claim.** There is no such table (see "Reports" below).
- **The exact fingerprint of a lookup.** `/lookup` takes only the first 4 hex characters (1 in 65,536). The client does the final match locally.

## 3. What is kept, and for how long

Everything below is in memory only. Nothing is written to disk, and a restart clears it.

| Data | Form | Purpose | Lifetime |
|---|---|---|---|
| Install token | random string + expiry | authentication | 30 days or until restart |
| Rate-limit counters | timestamps per token and call type | request limits | 1 hour window |
| Strikes and blocks | timestamps per token | temporary block after repeated violations | 1 hour window, 1 hour block |
| Recent fingerprints per token | last 100 fingerprints with times | detect floods of near-identical claims | 1 hour window |
| Install counters | HMAC of the coarse network, with a random per-process secret | limit installs per network | 1 hour window |
| Claim cache | fingerprint, extracted claim, verdict, evidence, time | skip repeat research, serve `/lookup` | up to 5,000 entries, oldest dropped first |
| Reports | per fingerprint: set of HMAC(token + fingerprint), set of HMAC(network + fingerprint), first and last seen rounded to the minute | count distinct installs and networks for the radar | up to 20,000 fingerprints |
| Fact-check responses | signed payload, publisher name | public rulings shown to users | up to 2,000 fingerprints |
| Secrets | HMAC secret (random per process), signing key (from `.env`) | hashing and signing | process lifetime |

Two honest notes:
- **Recent fingerprints per token** do link a token to the fingerprints it checked for up to an hour. This is the price of detecting near-duplicate floods. The data is a 64-bit similarity hash of normalized text, not the text, and it is never written out or exposed.
- **Reports are unlinkable by design.** The identifier for an install is different for every claim, so the server cannot list "everything token X reported" without knowing the token, and it does not store the token with reports.

## 4. Reporting and the radar

- Clients send only a fingerprint, plus an optional coarse region that the server validates and **discards**.
- **Client-side noise:** with probability 0.25 a client sends a random fingerprint instead of the real one. This gives any single reporter plausible deniability. Random fingerprints never collect enough distinct installs to appear.
- A claim appears on `/radar` only after reports from at least **10 distinct installs and 3 distinct networks**, so one person cannot push a claim alone.
- Reports are accepted only with `noisy: true`. The server cannot verify that noise was actually applied.

## 5. Fact-checker responses

- Fact-checkers publish with their own API key (`X-API-Key`). Install tokens are not accepted.
- Each response is signed with Ed25519 over its exact payload. Clients verify the signature with the public key from `GET /factcheck/public-key`, then parse the payload.
- Responses reach users through `/lookup`, so the private-lookup design is unchanged.
- Fact-checkers can replace or retract only their own responses.

## 6. What leaves the server

The agents (Ghunain's code) call external providers (a search API and an LLM API) to research a claim. Whatever they send is subject to those providers' policies. See "Open items".

## 7. Logs

- The API code logs error codes and exception type names only. It never logs text, fingerprints, prefixes or tokens.
- uvicorn's access log is filtered: client addresses are replaced with `-`, and `/lookup/` and `/report` lines are dropped entirely, because the lookup prefix is part of the path. This was checked against a running server.
- **Hosting platforms keep their own request logs**, which can contain IP addresses and request paths, including lookup prefixes. The team cannot control those.

## 8. Abuse threats and responses

| Threat | What the server does | What still works for an attacker |
|---|---|---|
| Mass token creation | 30 installs per hour per coarse network; repeated limit hits earn strikes, then a 1 hour block | Many networks (VPN, botnet) can still mint tokens |
| Poisoning the radar | needs 10 installs and 3 networks; 30 reports per hour per token | An attacker with 3+ networks and 10 tokens succeeds |
| Unmasking a reporter | no install-to-claim table, per-claim unlinkable identifiers, client noise, threshold | Noise is applied by the client and cannot be enforced; a claim just above the threshold reveals that about 10 installs reported it |
| Scraping the cache through `/lookup` | 200 lookups per hour per token; the cache holds only claims already checked | Slow scraping across many tokens |
| Burning research quota | 20 checks per hour per token; flood detection (5 near-identical variants within 12 bits); 25 second timeout; repeats come from the cache | Token minting, as above |
| Guessing fact-checker keys | keys of 16+ characters, constant-time comparison, lockout after 10 failures per hour per network | Slow guessing from many networks (infeasible at this key length) |
| Forged or altered fact-checks | Ed25519 signature over the exact payload; key id; retraction by owner only | A compromised server could swap the public key unless clients pin it |
| Stolen fact-checker key | rotate by changing `.env` and restarting; retraction endpoint | Signed false rulings can be published until the key is removed; no audit log |
| Spoofed client IP | `X-Forwarded-For` is trusted only when `TRUST_PROXY=true`, and only its last entry | None when configured correctly; wrong configuration breaks per-network limits |

## 9. Known limitations

- Everything is in memory: a restart or redeploy clears tokens, the cache, reports and fact-check responses. Clients must request a new install token after a 401.
- Fingerprint lookup by exact 4-character prefix misses near-duplicates whose prefix differs.
- The coarse network is a /24, so many users behind one network count as one network for the radar.
- TLS is provided by the hosting platform, not by the app.
- The 25% noise rate is a design choice, not a formal differential-privacy guarantee.

## 10. Open items

1. **Confirm what the agents send to external providers** (the full selected text or only the extracted claim) and that the agents never log text. This depends on the agents' code and was not reviewed here.
2. **Pin the fact-check public key** in the extension, app and web build, so a compromised server cannot swap it.
3. **Set `TRUST_PROXY=true` and start uvicorn behind the host's proxy** when deployed, and check the host's log retention settings.
4. **Move storage off memory** (a database) if the project continues past the demo.
