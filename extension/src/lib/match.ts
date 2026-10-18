import type { LookupEntry } from "./api";
import { hamming } from "./simhash";

/** Closest cached entry within maxDistance bits. The server never sees the full fingerprint. */
export function bestMatch(entries: LookupEntry[], fingerprint: string, maxDistance = 3): LookupEntry | null {
  let best: LookupEntry | null = null;
  let bestDistance = maxDistance + 1;
  for (const e of entries) {
    const d = hamming(e.fingerprint, fingerprint);
    if (d < bestDistance) {
      best = e;
      bestDistance = d;
    }
  }
  return best;
}
