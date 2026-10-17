# Verifi: Pitch Outline and Demo Script

Code//Connect · Problem 03: Misinformation Control · Team Bug Beaters

Fill the [brackets] with real numbers and sources. Do not invent statistics.

## Pitch deck (7 slides, about 5 minutes)

**1. Problem**
- Rumors spread through forwarded messages faster than corrections.
- Existing fact-checks are slow and live on websites nobody opens from WhatsApp.
- Checking a message usually means pasting it into a service that now knows what you read.
- Evidence: [one real local example + one credible statistic with its source]

**2. Solution**
- Select or share a message, get a result in seconds, in Urdu, Roman Urdu or English.
- Works as a browser extension, a mobile Share target and a web page.
- Always a range plus sources, never a bare TRUE/FALSE.

**3. How it looks** (screenshots)
- Result card with confidence range bar and evidence list.
- "Hum judge nahi karte" screen for opinion, satire and religion.
- Rumor Radar.

**4. Privacy by design** (our differentiator)
- Message text is never stored or logged.
- On-device SimHash fingerprint, so repeated claims are answered from cache.
- k-anonymous prefix lookup: server sees 4 hex characters, not your message.
- Local differential privacy on reports, and a radar threshold of 10 distinct installs.

**5. Architecture**
- Extension, Flutter app and Next.js web, all on one API contract (`shared/API.md`).
- FastAPI backend with research agents and a scope gate.
- Signed fact-checker responses.

**6. Threat model summary**
- Table with 4 or 5 headline threats and their defenses (from `docs/threat-model.md`).
- Be upfront about residual risk. Judges respect honesty.

**7. Team and next steps**
- Ghunain: agents, mobile. Sharjeel: backend, security, privacy. Muheed: extension. Emaan: web, docs.
- Next: images and screenshots, more languages, partnerships with fact-checkers.

## Demo video (2 to 3 minutes)

| Time | Show | Say |
|---|---|---|
| 0:00 | Forwarded rumor on a phone | "Aisa message roz aata hai. Sach kya hai?" |
| 0:15 | Paste into web or share from the app | "Ek click mein check." |
| 0:30 | Result card, confidence bar, evidence | "Jawab ek range mein hai, saboot ke saath." |
| 1:00 | Paste an opinion | "Opinion par hum faisla nahi dete." |
| 1:20 | Same message again, instant result | "Doosri baar cache se, bina server ko pata chale." |
| 1:40 | Rumor Radar | "Jab 10 alag log report karein tab hi trending." |
| 2:10 | Fact-checker view | "Official jawab signed hota hai." |
| 2:30 | Privacy slide | "Aap ka message kahin save nahi hota." |

Record tips: use mock mode with a known-good example, record at 1080p, keep browser zoom at 110 to 125 percent so text is readable, and rehearse once before recording.
