import { normalize } from "./normalize";
import { simhashHex } from "./simhash";

export function computeFingerprint(text: string): string {
  return simhashHex(normalize(text));
}

/** First 4 hex characters: all the server ever sees during a private lookup. */
export function prefixOf(fingerprint: string): string {
  return fingerprint.slice(0, 4);
}
