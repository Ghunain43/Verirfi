import { ApiError, fetchPublicKey, lookup, quickCheck, report } from "./lib/api";
import type { LookupEntry, QuickCheckResponse, SignedFactCheck } from "./lib/api";
import { verifySignature } from "./lib/crypto";
import { computeFingerprint, prefixOf } from "./lib/fingerprint";
import { bestMatch } from "./lib/match";
import type { CheckView, FactCheckView, FlaggedEntry, Msg, Reply, RpcError } from "./lib/messages";

const BUCKET_TTL_MS = 5 * 60 * 1000;
const buckets = new Map<string, { at: number; entries: LookupEntry[] }>();
const inflight = new Map<string, Promise<LookupEntry[]>>();

async function getBucket(prefix: string): Promise<LookupEntry[]> {
  const hit = buckets.get(prefix);
  if (hit && Date.now() - hit.at < BUCKET_TTL_MS) return hit.entries;
  const pending = inflight.get(prefix);
  if (pending) return pending;
  const p = lookup(prefix)
    .then((r) => {
      buckets.set(prefix, { at: Date.now(), entries: r.entries });
      return r.entries;
    })
    .finally(() => inflight.delete(prefix));
  inflight.set(prefix, p);
  return p;
}

/** Fact-checker responses are shown only if the signature verifies against the server's pinned key. */
async function verifiedFactChecks(fingerprint: string, signed: SignedFactCheck[]): Promise<FactCheckView[]> {
  if (signed.length === 0) return [];
  let pk;
  try {
    pk = await fetchPublicKey();
  } catch {
    return [];
  }
  const { pinnedKeyId } = (await chrome.storage.local.get("pinnedKeyId")) as { pinnedKeyId?: string };
  if (!pinnedKeyId) await chrome.storage.local.set({ pinnedKeyId: pk.key_id }); // trust on first use
  else if (pinnedKeyId !== pk.key_id) return []; // the key changed: show nothing until the user resets the pin
  const out: FactCheckView[] = [];
  for (const s of signed) {
    if (s.key_id !== pk.key_id || !(await verifySignature(pk.public_key, s.payload, s.signature))) continue;
    try {
      const p = JSON.parse(s.payload);
      if (p.fingerprint !== fingerprint) continue; // a ruling for some other claim
      if (typeof p.source_url !== "string" || !p.source_url.startsWith("https://")) continue;
      out.push({
        id: s.id, publisher: p.publisher, rating: p.rating, summary: p.summary,
        source_url: p.source_url, claim: p.claim, published_at: p.published_at,
      });
    } catch {
      /* ignore malformed payloads */
    }
  }
  return out;
}

const evidenceView = (e: QuickCheckResponse["evidence"]) =>
  e.map(({ title, url, publisher, stance, snippet }) => ({ title, url, publisher, stance, snippet }));

async function check(text: string): Promise<CheckView> {
  const fingerprint = computeFingerprint(text);
  // 1. Private lookup first: only the 4-character prefix leaves the browser, never the text.
  try {
    const match = bestMatch(await getBucket(prefixOf(fingerprint)), fingerprint);
    if (match) {
      const factchecks = await verifiedFactChecks(match.fingerprint, match.factchecks);
      if (match.likely_answer !== null || factchecks.length > 0) {
        return {
          source: "cache", fingerprint, claim: match.claim, checkable: true, reason_unchecked: null,
          likely_answer: match.likely_answer, confidence_low: match.confidence_low,
          confidence_high: match.confidence_high, evidence: evidenceView(match.evidence), factchecks,
        };
      }
    }
  } catch (e) {
    if (e instanceof ApiError && e.code === "rate_limited") throw e;
    /* lookup failed: fall through to a full check */
  }
  // 2. Nothing known: send the selected text to the server, as the user asked by pressing Check.
  const r = await quickCheck(text);
  buckets.delete(prefixOf(fingerprint)); // the server now knows this claim
  return {
    source: "server", fingerprint, claim: r.claim, checkable: r.checkable, reason_unchecked: r.reason_unchecked,
    likely_answer: r.likely_answer, confidence_low: r.confidence_low, confidence_high: r.confidence_high,
    evidence: evidenceView(r.evidence), factchecks: [], took_ms: r.took_ms,
  };
}

const FALSE_WORDS = /\b(false|misleading|no evidence|not true|incorrect)\b/i;

async function lookupBucket(prefix: string): Promise<FlaggedEntry[]> {
  const entries = await getBucket(prefix);
  return entries.map((e) => ({
    fingerprint: e.fingerprint,
    flagged: e.factchecks.length > 0 || FALSE_WORDS.test(e.likely_answer ?? ""),
  }));
}

async function handle(msg: Msg): Promise<unknown> {
  switch (msg.type) {
    case "check":
      return check(msg.text);
    case "report":
      await report(msg.fingerprint);
      return {};
    case "lookupBucket":
      return lookupBucket(msg.prefix);
  }
}

function toRpcError(e: unknown): RpcError {
  if (e instanceof ApiError) return { code: e.code, message: e.message, retryAfter: e.retryAfter };
  return { code: "unknown", message: e instanceof Error ? e.message : "Something went wrong." };
}

chrome.runtime.onMessage.addListener((msg: Msg, _sender, sendResponse: (r: Reply<unknown>) => void) => {
  handle(msg).then(
    (data) => sendResponse({ ok: true, data }),
    (e) => sendResponse({ ok: false, error: toRpcError(e) }),
  );
  return true; // keep the channel open for the async reply
});
