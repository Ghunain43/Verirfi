import { BASE, USE_MOCK, sleep, toError } from "./api";

export type FactcheckSubmission = {
  fingerprint: string;
  verdict: string;
  explanation: string;
  source_url: string;
};

export async function submitFactcheck(apiKey: string, s: FactcheckSubmission): Promise<void> {
  if (USE_MOCK) {
    await sleep(600);
    return;
  }
  // TODO: confirm the auth header name and body format with Sharjeel
  const res = await fetch(`${BASE}/factcheck`, {
    method: "POST",
   headers: { "Content-Type": "application/json", "X-API-Key": apiKey },
    body: JSON.stringify(s),
  });
  if (!res.ok) throw await toError(res);
}
