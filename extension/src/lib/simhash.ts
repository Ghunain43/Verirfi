// Port of backend/app/core/simhash.py: 64-bit SimHash over word 3-grams, FNV-1a 64 + murmur3 fmix64.
const MASK = (1n << 64n) - 1n;
const FNV_OFFSET = 0xcbf29ce484222325n;
const FNV_PRIME = 0x100000001b3n;

export function fnv1a64(data: Uint8Array): bigint {
  let h = FNV_OFFSET;
  for (const b of data) {
    h ^= BigInt(b);
    h = (h * FNV_PRIME) & MASK;
  }
  return h;
}

export function fmix64(input: bigint): bigint {
  let h = input;
  h ^= h >> 33n;
  h = (h * 0xff51afd7ed558ccdn) & MASK;
  h ^= h >> 33n;
  h = (h * 0xc4ceb9fe1a85ec53n) & MASK;
  h ^= h >> 33n;
  return h;
}

export function shingles(normalized: string): string[] {
  const tokens = normalized ? normalized.split(" ") : [];
  if (tokens.length === 0) return [];
  if (tokens.length < 3) return [tokens.join(" ")];
  const out: string[] = [];
  for (let i = 0; i <= tokens.length - 3; i++) out.push(tokens.slice(i, i + 3).join(" "));
  return out;
}

export function simhashHex(normalized: string): string {
  const counts = new Array<number>(64).fill(0);
  const enc = new TextEncoder();
  for (const sh of shingles(normalized)) {
    const h = fmix64(fnv1a64(enc.encode(sh)));
    for (let i = 0; i < 64; i++) counts[i] += (h >> BigInt(i)) & 1n ? 1 : -1;
  }
  let out = 0n;
  for (let i = 0; i < 64; i++) if (counts[i] > 0) out |= 1n << BigInt(i);
  return out.toString(16).padStart(16, "0");
}

export function hamming(aHex: string, bHex: string): number {
  let x = BigInt("0x" + aHex) ^ BigInt("0x" + bHex);
  let n = 0;
  while (x) {
    n += Number(x & 1n);
    x >>= 1n;
  }
  return n;
}
