import { DEFAULT_SETTINGS, getSettings, saveSettings } from "./lib/api";

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const baseInput = $<HTMLInputElement>("base");
const composeBox = $<HTMLInputElement>("compose");
const status = $("status");
const msg = $("msg");

async function showStatus(base: string): Promise<void> {
  status.className = "small";
  status.textContent = "Checking server\u2026";
  try {
    const res = await fetch(`${base}/health`);
    const data = await res.json();
    status.className = "small ok";
    status.textContent = `Server reachable (version ${data.version}).`;
  } catch {
    status.className = "small bad";
    status.textContent = "Can't reach the server. Check the address below.";
  }
}

async function init(): Promise<void> {
  const s = await getSettings();
  baseInput.value = s.apiBase;
  composeBox.checked = s.composeUnderline;
  void showStatus(s.apiBase);
}

$("save").addEventListener("click", async () => {
  msg.textContent = "";
  let base = baseInput.value.trim().replace(/\/+$/, "");
  if (!base) base = DEFAULT_SETTINGS.apiBase;
  let url: URL;
  try {
    url = new URL(base);
  } catch {
    msg.textContent = "That is not a valid address. Example: https://your-server.example/api/v1";
    return;
  }
  const isLocal = url.hostname === "localhost" || url.hostname === "127.0.0.1";
  if (!isLocal && url.protocol !== "https:") {
    msg.textContent = "Use https:// for a server that is not on this computer.";
    return;
  }
  if (!isLocal) {
    // Must be requested from a click so the browser can ask the user.
    const granted = await chrome.permissions.request({ origins: [`${url.origin}/*`] });
    if (!granted) {
      msg.textContent = "Permission to contact that server was not granted.";
      return;
    }
  }
  await saveSettings({ apiBase: base });
  await chrome.storage.local.remove(["token", "pinnedKeyId"]); // a different server means a new install
  msg.textContent = "Saved.";
  void showStatus(base);
});

composeBox.addEventListener("change", () => void saveSettings({ composeUnderline: composeBox.checked }));

$("resetkey").addEventListener("click", async () => {
  await chrome.storage.local.remove("pinnedKeyId");
  msg.textContent = "Pinned key cleared. The next fact-check will pin the server's current key.";
});

void init();
