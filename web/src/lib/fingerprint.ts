import normalizeMap from "../../../shared/normalize_map.json";

const MASK_64 = (BigInt(1) << BigInt(64)) - BigInt(1);
const isLetter = /\p{L}/u;
const isInvisible = /\p{Cf}/u;
const charMap = normalizeMap.char_map as Record<string, string>;
const romanUrdu = normalizeMap.roman_urdu as Record<string, string>;

export function normalize(text: string): string {
  const mapped = Array.from(text.normalize("NFKC").toLowerCase())
    .filter((char) => {
      const codePoint = char.codePointAt(0)!;
      return !isInvisible.test(char) && !(codePoint >= 0xfe00 && codePoint <= 0xfe0f) && codePoint !== 0x034f;
    })
    .map((char) => charMap[char] ?? char)
    .join("");
  const tokens = mapped
    .replace(/[^\p{L}\p{N}\p{Mn}\p{Mc}]/gu, " ")
    .trim()
    .split(/\s+/u)
    .filter(Boolean)
    .map((token) => {
      let squeezed = "";
      let previous = "";
      let runLength = 0;
      for (const char of Array.from(token)) {
        runLength = char === previous ? runLength + 1 : 1;
        previous = char;
        if (runLength > 2 && isLetter.test(char)) continue;
        squeezed += char;
      }
      return romanUrdu[squeezed] ?? squeezed;
    });
  return tokens.join(" ");
}

function fnv1a64(value: string): bigint {
  let hash = BigInt("0xcbf29ce484222325");
  for (const byte of new TextEncoder().encode(value)) {
    hash ^= BigInt(byte);
    hash = (hash * BigInt("0x100000001b3")) & MASK_64;
  }
  return hash;
}

function fmix64(value: bigint): bigint {
  let hash = value;
  hash ^= hash >> BigInt(33);
  hash = (hash * BigInt("0xff51afd7ed558ccd")) & MASK_64;
  hash ^= hash >> BigInt(33);
  hash = (hash * BigInt("0xc4ceb9fe1a85ec53")) & MASK_64;
  hash ^= hash >> BigInt(33);
  return hash;
}

export function computeFingerprint(text: string): string {
  const normalized = normalize(text);
  const tokens = normalized ? normalized.split(" ") : [];
  const shingles = tokens.length === 0
    ? []
    : tokens.length < 3
      ? [tokens.join(" ")]
      : tokens.slice(0, tokens.length - 2).map((_, index) => tokens.slice(index, index + 3).join(" "));
  const weights = Array.from({ length: 64 }, () => 0);

  for (const shingle of shingles) {
    const hash = fmix64(fnv1a64(shingle));
    for (let bit = 0; bit < 64; bit++) {
      weights[bit] += (hash >> BigInt(bit)) & BigInt(1) ? 1 : -1;
    }
  }

  let fingerprint = BigInt(0);
  for (let bit = 0; bit < 64; bit++) {
    if (weights[bit] > 0) fingerprint |= BigInt(1) << BigInt(bit);
  }
  return fingerprint.toString(16).padStart(16, "0");
}
