import { QuickCheckResult, RadarItem } from "./types";
import { pickMock, MOCK_RADAR } from "./mock";

export const BASE = process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000/api/v1";
export const USE_MOCK = process.env.NEXT_PUBLIC_USE_MOCK === "true";
const TOKEN_KEY = "verifi_install_token";

export class ApiError extends Error {
  constructor(public status: number, public code: string, public retryAfter?: number) {
    super(code);
  }
}

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function toError(res: Response) {
  let code = "unknown";
  try {
    const body = await res.json();
    code = body?.error?.code ?? code;
  } catch {}
  const ra = Number(res.headers.get("Retry-After"));
  return new ApiError(res.status, code, ra > 0 ? ra : undefined);
}

async function getToken(force = false): Promise<string> {
  if (!force) {
    const saved = localStorage.getItem(TOKEN_KEY);
    if (saved) return saved;
  }
  const res = await fetch(`${BASE}/auth/install`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  if (!res.ok) throw await toError(res);
  const data = await res.json();
  localStorage.setItem(TOKEN_KEY, data.install_token);
  return data.install_token;
}

// Authenticated call; on 401, fetch a new token and retry once
async function authed(path: string, init: RequestInit = {}): Promise<Response> {
  const run = (token: string) =>
    fetch(`${BASE}${path}`, {
      ...init,
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    });
  let res = await run(await getToken());
  if (res.status === 401) res = await run(await getToken(true));
  if (!res.ok) throw await toError(res);
  return res;
}

export async function quickCheck(text: string): Promise<QuickCheckResult> {
  if (USE_MOCK) {
    await sleep(800);
    return pickMock(text);
  }
  const res = await authed("/quick-check", {
    method: "POST",
    body: JSON.stringify({ text, lang: "auto", source: "web" }),
  });
  return res.json();
}

export async function getRadar(): Promise<RadarItem[]> {
  if (USE_MOCK) {
    await sleep(500);
    return MOCK_RADAR;
  }
  const res = await authed("/radar");
  const data = await res.json();
  return data.items;
}
