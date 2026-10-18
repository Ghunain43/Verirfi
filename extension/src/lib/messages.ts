export interface FactCheckView {
  id: string;
  publisher: string;
  rating: string;
  summary: string;
  source_url: string;
  claim: string;
  published_at: string;
}

export interface EvidenceView {
  title: string;
  url: string;
  publisher: string | null;
  stance: "supporting" | "contradicting" | "neutral";
  snippet: string | null;
}

export interface CheckView {
  source: "cache" | "server";
  fingerprint: string;
  claim: string;
  checkable: boolean;
  reason_unchecked: string | null;
  likely_answer: string | null;
  confidence_low: number;
  confidence_high: number;
  evidence: EvidenceView[];
  factchecks: FactCheckView[];
  took_ms?: number;
}

export type Msg =
  | { type: "check"; text: string }
  | { type: "report"; fingerprint: string }
  | { type: "lookupBucket"; prefix: string };

export interface FlaggedEntry {
  fingerprint: string;
  flagged: boolean; // looks false or misleading
}

export interface RpcError {
  code: string;
  message: string;
  retryAfter?: number;
}
export type Reply<T> = { ok: true; data: T } | { ok: false; error: RpcError };

export async function rpc<T>(msg: Msg): Promise<T> {
  const res = (await chrome.runtime.sendMessage(msg)) as Reply<T> | undefined;
  if (!res) throw { code: "network", message: "No response from the extension." } satisfies RpcError;
  if (!res.ok) throw res.error;
  return res.data;
}
