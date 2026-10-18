# Veritus AI: Web app

The website for Veritus AI. Check a claim, see the evidence, and browse the Rumor Radar. Live at <https://veritusai.netlify.app>.

<p align="center"><img src="../docs/screenshots/web-home.jpg" alt="Home page" width="100%" /></p>
<p align="center">
  <img src="../docs/screenshots/web-check.jpg" alt="Check page" width="49%" />
  <img src="../docs/screenshots/web-radar.jpg" alt="Rumor Radar" width="49%" />
</p>

## Pages

| Route | What it is |
| --- | --- |
| `/` | Home: animated particle background, headline, entry points |
| `/check` | Paste text, get a verdict chip, confidence range and the evidence. Unrated text explains why |
| `/radar` | Rumor Radar with a "Why it's here" note and source link for each claim |
| `/factcheck` | Fact-checker form: publish a rated response for a claim (PIN screen first, see below) |
| `/admin` | Admin dashboard: trending claims and report counts (PIN screen first, see below) |

## Tech

Next.js 16 (App Router, Turbopack), React, TypeScript and Tailwind CSS v4. No UI library: the glass look, particles and tilt are plain CSS and a small canvas.

## Run locally

```bash
cd web
npm install
npm run dev          # http://localhost:3000
```

Create `web/.env.local`:

```
NEXT_PUBLIC_API_BASE=http://localhost:8000/api/v1
NEXT_PUBLIC_USE_MOCK=false
```

Set `NEXT_PUBLIC_USE_MOCK=true` to use built-in sample data without a backend.

## Environment variables

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_API_BASE` | Backend URL including `/api/v1`, no trailing slash. Production: `https://verifi.fastapicloud.dev/api/v1` |
| `NEXT_PUBLIC_USE_MOCK` | `true` uses sample data, `false` calls the backend |
| `NEXT_PUBLIC_ADMIN_PIN` | PIN for `/factcheck` and `/admin` |

`NEXT_PUBLIC_` values are baked in at build time. Change one, then redeploy.

## Project structure

```
src/app/            Routes: page.tsx (home), check/, radar/, factcheck/, admin/, layout.tsx
src/components/     Nav, ParticleField, Tilt, ResultCard, Gate
src/lib/api.ts      Backend client: install token, Bearer header, one retry after a 401
src/lib/types.ts    Shared types for results and radar items
src/lib/mock.ts     Sample data for mock mode
public/logo.png     Logo and favicon
```

## Fact-checker and admin tools

`/factcheck` and `/admin` are not linked from the main navigation. Both open on a PIN screen first.

<p align="center"><img src="../docs/screenshots/web-pin.jpg" alt="PIN screen" width="100%" /></p>

**Fact-checker (`/factcheck`).** Lets a fact-checker publish a response for a claim. Fill in the fact-checker API key, the claim fingerprint (hex), a verdict (for example False, True or Partly true), an explanation and a source link, then press **Publish response**.

<p align="center"><img src="../docs/screenshots/web-factcheck.jpg" alt="Fact-checker form" width="100%" /></p>

**Admin (`/admin`).** A read-only overview of the Rumor Radar: how many claims are trending, the total number of reports, and a table with each claim, its report count and when it was first and last seen.

<p align="center"><img src="../docs/screenshots/web-admin.jpg" alt="Admin dashboard" width="100%" /></p>

## How the PIN screen works

`Gate` wraps `/factcheck` and `/admin` through their layout files. It checks the PIN in the browser and remembers the unlock for the current tab only. This is a **soft lock for casual visitors, not real security**: the PIN ships inside the site's JavaScript. Do not protect anything sensitive with it.

## Deploy on Netlify

1. Import the repo. Base directory `web`, build command `npm run build`.
2. Add `web/netlify.toml`:
   ```toml
   [build]
     command = "npm run build"
     publish = ".next"

   [[plugins]]
     package = "@netlify/plugin-nextjs"
   ```
3. Set `NEXT_PUBLIC_API_BASE`, `NEXT_PUBLIC_USE_MOCK=false` and `NODE_VERSION=20` under Site configuration, then clear the cache and deploy.
4. Allow the site on the backend: `fastapi cloud env set CORS_ORIGINS https://<your-site>.netlify.app`, then `fastapi deploy`.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| Netlify "Page not found" on a published site | The Next.js runtime was not applied. Add the `netlify.toml` above and redeploy with a cleared cache |
| "Couldn't reach the server" | Request goes to `localhost` (variable missing at build time) or is blocked by CORS. Check `NEXT_PUBLIC_API_BASE`, then `CORS_ORIGINS` |
| Request returns 404 on `/auth/install` | `NEXT_PUBLIC_API_BASE` is missing `/api/v1` |
| Build says "Module not found" for a file that exists locally | Windows ignores letter case and Netlify does not. Fix the casing with `git mv` (rename in two steps) |
| First check is very slow | The free backend was asleep. Wait up to a minute, then try again |
