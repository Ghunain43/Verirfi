// Port of backend/app/core/normalize.py. Must produce identical output (see shared/fingerprint_vectors.json).
import map from "../../../shared/normalize_map.json";

const CHAR_MAP: Record<string, string> = map.char_map;
const ROMAN_URDU: Record<string, string> = map.roman_urdu;

const RE_FORMAT = /^\p{Cf}$/u;
const RE_KEEP = /^[\p{L}\p{N}\p{Mn}\p{Mc}]$/u;
const RE_LETTER = /^\p{L}$/u;

function invisible(ch: string): boolean {
  const cp = ch.codePointAt(0)!;
  return RE_FORMAT.test(ch) || (cp >= 0xfe00 && cp <= 0xfe0f) || cp === 0x034f;
}

/** Runs of 3+ identical letters become 2. Digits are never squeezed. */
export function squeeze(token: string): string {
  let out = "";
  let prev: string | null = null;
  let run = 0;
  for (const ch of token) {
    if (ch === prev) run += 1;
    else {
      prev = ch;
      run = 1;
    }
    if (run > 2 && RE_LETTER.test(ch)) continue;
    out += ch;
  }
  return out;
}

export function normalize(text: string): string {
  const lowered = text.normalize("NFKC").toLowerCase();
  let mapped = "";
  for (const ch of lowered) {
    if (invisible(ch)) continue;
    const m = CHAR_MAP[ch];
    mapped += m !== undefined ? m : ch;
  }
  let spaced = "";
  for (const ch of mapped) spaced += RE_KEEP.test(ch) ? ch : " ";
  const tokens: string[] = [];
  for (const raw of spaced.split(" ")) {
    if (!raw) continue;
    const tok = squeeze(raw);
    tokens.push(ROMAN_URDU[tok] ?? tok);
  }
  return tokens.join(" ");
}
