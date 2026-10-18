# Veritus AI: Chrome extension

Check a claim without leaving the page. Select text, right-click, and get the evidence in a small window.

<p align="center">
  <img src="../docs/screenshots/extension-menu.png" alt="Right-click menu" width="62%" />
  <img src="../docs/screenshots/extension-popup.png" alt="Result window" width="26%" />
</p>

## Install (no store fee)

1. Open `chrome://extensions` and turn on **Developer mode**.
2. Click **Load unpacked** and choose this `extension` folder (the one that contains `manifest.json`).
3. Pin Veritus AI from the puzzle icon.

<p align="center"><img src="../docs/screenshots/extension-installed.png" alt="Installed extension" width="320" /></p>

After changing any file, press the refresh icon on the extension's card.

## Use

- **Right-click:** select text on any page, choose **Check with Veritus AI**. A small window opens and runs the check.
- **Toolbar:** click the icon. Text you selected on the page is already filled in. Otherwise paste a claim and press **Check** (or Ctrl+Enter).
- **Radar tab:** the same Rumor Radar as the web and the app.
- The extension cannot read Chrome's own pages (`chrome://`) or the Web Store. Paste the text instead.

## Files

| File | Purpose |
| --- | --- |
| `manifest.json` | Manifest V3 config, permissions, icons |
| `background.js` | Service worker: context menu and the result window |
| `popup.html`, `popup.css`, `popup.js` | The interface: check, results, radar |
| `api.js` | Backend client: stores the install token in `chrome.storage.local`, retries once after a 401 |
| `icons/` | Extension icons |

The backend address is the `BASE` constant at the top of `api.js`.

## Permissions

| Permission | Why |
| --- | --- |
| `contextMenus` | The right-click item |
| `activeTab`, `scripting` | Read the text you selected, only when you click the toolbar icon |
| `storage` | Keep the anonymous install token |
| Host `https://verifi.fastapicloud.dev/*` | Call the backend. No other site is contacted |

The extension sends only the text you choose to check. Nothing is saved or logged, and there is no tracking.

## Publish to the Chrome Web Store (optional)

Needs a developer account with a one-time registration fee, screenshots, a short privacy statement and Google's review. For demos and judging, Load unpacked or sharing the folder is enough.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| Error in the popup | Open `chrome://extensions`, click **Inspect views** on the card, and read the first red line in the console |
| First check is slow | The free backend was asleep, so wait up to a minute |
| Right-click item missing | Reload the extension, then reload the page |
