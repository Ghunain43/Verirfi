// Client for shared/API.md. Runs in the background service worker (and the popup for /health).
export interface Evidence {
  title: string;
  url: string;
  publisher: string | null;
  stance: "supporting" | "contradicting" | "neutral";
  quality: number;
  snippet: string | null;
}
export interface QuickCheckResponse {
  checkable: boolean;
  claim: string;
  reason_unchecked: string | null;
  likely_answer: string | null;
  confidence_low: number;
  confidence_high: number;
  evidence: Evidence[];
  lang_detected: string;
  fingerprint: string;
  cached: boolean;
  took_ms: number;
}
export interface SignedFactCheck {
  id: string;
  payload: string;
  signature: string;
  key_id: string;
}
export interface LookupEntry {
  fingerprint: string;
  claim: string;
  likely_answer: string | null;
  confidence_low: number;
  confidence_high: number;
  evidence: Evidence[];
  checked_at: string;
  factchecks: SignedFactCheck[];
}
export interface PublicKey {
  key_id: string;
  algorithm: string;
  public_key: string;
}

export class ApiError extends Error {
  constructor(public code: string, message: string, public status = 0, public retryAfter?: number) {
    super(message);
  }
}

export interface Settings {
  apiBase: string;
  composeUnderline: boolean;
}
export const DEFAULT_SETTINGS: Settings = { apiBase: "http://localhost:8000/api/v1", composeUnderline: false };

export async function getSettings(): Promise<Settings> {
  const { settings } = await chrome.storage.local.get("settings");
  return { ...DEFAULT_SETTINGS, ...(settings ?? {}) };
}

export async function saveSettings(patch: Partial<Settings>): Promise<Settings> {
  const next = { ...(await getSettings()), ...patch };
  await chrome.storage.local.set({ settings: next });
  return next;
}

interface StoredToken {
  token: string;
  expiresAt: number;
  base: string;
}

async function parseError(res: Response): Promise<ApiError> {
  const data = await res.json().catch(() => null);
  const retry = Number(res.headers.get("Retry-After")) || undefined;
  return new ApiError(data?.error?.code ?? "unknown", data?.error?.message ?? `Server error ${res.status}`, res.status, retry);
}

async function rawFetch(url: string, init: RequestInit): Promise<Response> {
  try {
    return await fetch(url, init);
  } catch {
    throw new ApiError("network", "Cannot reach the Verifi server.");
  }
}

async function ensureToken(base: string): Promise<string> {
  const { token } = (await chrome.storage.local.get("token")) as { token?: StoredToken };
  if (token && token.base === base && token.expiresAt > Date.now() + 60_000) return token.token;
  const res = await rawFetch(`${base}/auth/install`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  if (!res.ok) throw await parseError(res);
  const data = (await res.json()) as { install_token: string; expires_in: number };
  const stored: StoredToken = { token: data.install_token, expiresAt: Date.now() + data.expires_in * 1000, base };
  await chrome.storage.local.set({ token: stored });
  return stored.token;
}

async function call<T>(method: "GET" | "POST", path: string, body?: unknown, retry = true): Promise<T> {
  const { apiBase } = await getSettings();
  const token = await ensureToken(apiBase);
  const res = await rawFetch(`${apiBase}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (res.status === 401 && retry) {
    // The server restarted or the token expired: get a new one and try once more.
    await chrome.storage.local.remove("token");
    return call<T>(method, path, body, false);
  }
  if (!res.ok) throw await parseError(res);
  return (await res.json()) as T;
}

export const quickCheck = (text: string, lang = "auto") =>
  call<QuickCheckResponse>("POST", "/quick-check", { text, lang, source: "extension" });

export const lookup = (prefix: string) =>
  call<{ prefix: string; entries: LookupEntry[] }>("GET", `/lookup/${prefix}`);

export async function fetchPublicKey(): Promise<PublicKey> {
  const { apiBase } = await getSettings();
  const res = await rawFetch(`${apiBase}/factcheck/public-key`, { method: "GET" });
  if (!res.ok) throw await parseError(res);
  return (await res.json()) as PublicKey;
}

/** Randomized response (API.md section 5): with probability 0.25 send a random fingerprint instead. */
export function withNoise(fingerprint: string, random: () => number = Math.random): string {
  if (random() >= 0.25) return fingerprint;
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

export const report = (fingerprint: string) =>
  call<Record<string, never>>("POST", "/report", { fingerprint: withNoise(fingerprint), noisy: true });
