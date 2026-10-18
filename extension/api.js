// Backend client. Install token lives in chrome.storage.local; a 401 gets a fresh token and one retry.
const BASE = "https://verifi.fastapicloud.dev/api/v1";
const TIMEOUT_MS = 60000; // the free backend can take up to a minute to wake up

export class ApiError extends Error {
  constructor(status, code, retryAfter) { super(code); this.status = status; this.code = code; this.retryAfter = retryAfter; }
}

async function request(path, { method = "GET", body, token } = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(BASE + path, {
      method, signal: ctrl.signal,
      headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (res.ok) return res.json();
    let code = "unknown";
    try { code = (await res.json()).error?.code ?? code; } catch {}
    throw new ApiError(res.status, code, Number(res.headers.get("retry-after")) || null);
  } catch (e) {
    if (e instanceof ApiError) throw e;
    throw new ApiError(0, e.name === "AbortError" ? "timeout" : "network");
  } finally {
    clearTimeout(timer);
  }
}

async function newToken() {
  const { install_token } = await request("/auth/install", { method: "POST", body: {} });
  await chrome.storage.local.set({ token: install_token });
  return install_token;
}

async function authed(path, opts = {}, retried = false) {
  const { token: saved } = await chrome.storage.local.get("token");
  const token = saved || (await newToken());
  try {
    return await request(path, { ...opts, token });
  } catch (e) {
    if (e.status === 401 && !retried) { await chrome.storage.local.remove("token"); return authed(path, opts, true); }
    throw e;
  }
}

export const quickCheck = (text) => authed("/quick-check", { method: "POST", body: { text, lang: "auto", source: "extension" } });
export const getRadar = async () => (await authed("/radar")).items;
