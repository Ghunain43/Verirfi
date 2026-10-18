# Veritus AI: pitch outline and demo script

Team **Bug Beaters** · Code//Connect '26, Problem 03 (Misinformation Control)

Deck file: `docs/pitch-deck.pptx`
Full reference: [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md) · Security: [THREAT_MODEL.md](THREAT_MODEL.md)
Demo video link: _add the unlisted YouTube or Drive link here_

Live web app: <https://veritusai.netlify.app> · API: <https://verifi.fastapicloud.dev/docs>

## 1. One-line pitch

Veritus AI lets anyone check a rumor before sharing it: paste, select or share a message, and get a likely answer with a confidence range and sources, without the server ever storing what you wrote.

## 2. Pitch outline (7 slides)

| # | Slide | Main point |
|---|---|---|
| 1 | Title | Veritus AI: check a rumor before you share it |
| 2 | Problem | Only 31% of 365 surveyed Pakistani residents checked information before passing it on (COVID-19 survey, July 2020, Esculapio journal). WhatsApp was the most common place they met misinformation (32%). |
| 3 | Solution | Send, research, understand. Range plus evidence, never a bare TRUE or FALSE. Opinions, satire, faith and predictions are not judged. |
| 4 | Product | Android app, Chrome extension, web app, one backend and one API contract |
| 5 | Privacy | Text is processed in memory only. Private lookup by 4-character prefix. Radar keeps only fingerprints and salted hashes. |
| 6 | Abuse protection | Rate limits, input limits, normalisation, radar threshold of 10 installs on 3 networks. Full list in `THREAT_MODEL.md`. |
| 7 | Next steps and team | Persistent storage, partner fact-checkers, more Urdu coverage |

## 3. Demo video script (about 3 minutes)

Set up before recording:
- Wake the backend one minute early (the free tier sleeps and the first request can take up to a minute).
- Web app on <https://veritusai.netlify.app>, or local with `NEXT_PUBLIC_USE_MOCK=true` (sample data).
- Browser zoom at 80 to 100 percent, tabs and bookmarks bar hidden.
- Phone: latest APK installed, screen recording on. Extension loaded unpacked.
- Windows: press `Win + G` to record, or use OBS. Rehearse once.

| Time | Screen | Say |
|---|---|---|
| 0:00 to 0:15 | Slide 1 or the home page | "Rumors spread on WhatsApp faster than anyone can fact-check them. Veritus AI lets you check a message before you forward it." |
| 0:15 to 0:50 | Web `/check`. Paste "Drinking hot water cures dengue fever." and press Check | "I paste a message. Veritus AI pulls out the claim, researches it and shows a likely answer. Notice it gives a confidence range and the sources, each marked supports or contradicts, not just true or false." Point at the range bar and an evidence card. |
| 0:50 to 1:10 | Paste "This party is the worst" and press Check | "It does not judge opinions, satire or beliefs. It says so and tells you why. This keeps it from becoming a censorship tool." |
| 1:10 to 1:40 | Phone: share a forward from WhatsApp to Veritus AI, then scan a screenshot | "On Android I share straight from WhatsApp. For a screenshot, the text is read on my phone first. Then I can tap Listen to hear the result." |
| 1:40 to 2:00 | Chrome: select text on a page, right-click, **Check with Veritus AI** | "In the browser I select text, right-click, and get the evidence in a small window without leaving the page." |
| 2:00 to 2:20 | `/radar` (web or app) | "The Rumor Radar shows false claims spreading now, each with a reason it is here. A community claim appears only after 10 installs on 3 networks have checked it, so one person cannot push a rumor. Web fact-checks fill the list when the community list is short." |
| 2:20 to 2:40 | Slide 5 (Privacy) | "There are no accounts. Message text is processed in memory and never stored or logged. Lookups send only a 4-character prefix, so the server never learns the exact message." |
| 2:40 to 3:00 | Slide 7 or the home page | "Veritus AI: check before you share." |

Optional extra (only if the backend serves them and time allows): `/admin` for trending claims and `/factcheck` for the fact-checker form, both behind the PIN screen.

Notes:
- If the demo runs on mock data, say "sample data" once, so the demo is honest.
- Keep each step to the time shown. If you run long, drop the extension step first.
- The web screenshots still show the working name "Verifi". The product name is Veritus AI. Say Veritus AI out loud.
- After recording, upload as unlisted on YouTube or Google Drive and paste the link at the top of this file. Do not commit the video file to the repo.

## 4. Screenshots

![Result card](images/result_card.png)
![Opinion case](images/result_opinion.png)
![Rumor radar](images/radar.png)
![Admin view](images/admin.png)
![Fact-checker form](images/factcheck.png)

More in `docs/screenshots/` for the web, Android app and extension.

## 5. Likely judge questions

| Question | Short answer |
|---|---|
| Does Veritus AI store my messages? | No. Text is processed in memory for one request and never stored or logged. The server keeps only fingerprints and counts. |
| Can someone fake a rumor onto the radar? | Not alone. A claim needs 10 installs on 3 networks. A large, coordinated attacker is a residual risk, listed in the threat model. |
| What if Veritus AI is wrong? | It always shows a range plus sources, can say "Not enough evidence to say", and refuses opinions. The UI says "Not a verdict. Weigh the sources yourself." |
| What does Veritus AI send to outside providers? | A fresh check sends the claim text to the search provider (Tavily) and the LLM provider (Groq). This is a known limit in the threat model. |
| Which languages work? | English, Urdu and Roman Urdu text. Android screenshot reading supports English and Roman Urdu, not Urdu script. |
| Is it censorship? | No. Nothing is blocked or removed. People simply see evidence before they forward. |
| Why Android, extension and web? | WhatsApp is on phones, many people read news in a browser, and the web app is the easiest to try. All three use one backend. |
| What is not finished? | Persistent storage, Urdu script reading, and the items in `THREAT_MODEL.md`, section 5. |
