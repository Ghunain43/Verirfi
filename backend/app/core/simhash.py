"""64-bit SimHash over word 3-grams (API.md section 4).

Spec for the TypeScript (BigInt) and Dart ports:
 - input: the normalized string (see normalize.py), tokens split on single spaces
 - shingles: every window of 3 consecutive tokens joined by one space.
   If there are fewer than 3 tokens, the single shingle is all tokens joined by a space.
   No tokens at all -> fingerprint is 16 zeros.
 - shingle hash: FNV-1a 64 over the UTF-8 bytes, then the murmur3 fmix64 finalizer
 - every shingle has weight 1 (duplicates count). Bit i of the result is 1 if more shingles
   have bit i set than not set (ties give 0). Bit 63 is the most significant.
 - output: 16 lowercase hex characters, zero padded. Lookup prefix = first 4 hex characters.
 - Dart note: ints are signed 64-bit, so use >>> (unsigned shift) in fmix64.
"""
MASK = (1 << 64) - 1
FNV_OFFSET = 0xCBF29CE484222325
FNV_PRIME = 0x100000001B3


def fnv1a64(data: bytes) -> int:
    h = FNV_OFFSET
    for b in data:
        h ^= b
        h = (h * FNV_PRIME) & MASK
    return h


def fmix64(h: int) -> int:
    h ^= h >> 33
    h = (h * 0xFF51AFD7ED558CCD) & MASK
    h ^= h >> 33
    h = (h * 0xC4CEB9FE1A85EC53) & MASK
    h ^= h >> 33
    return h


def shingles(normalized: str) -> list[str]:
    tokens = normalized.split(" ") if normalized else []
    if not tokens:
        return []
    if len(tokens) < 3:
        return [" ".join(tokens)]
    return [" ".join(tokens[i:i + 3]) for i in range(len(tokens) - 2)]


def simhash64(normalized: str) -> int:
    counts = [0] * 64
    for sh in shingles(normalized):
        h = fmix64(fnv1a64(sh.encode("utf-8")))
        for i in range(64):
            counts[i] += 1 if (h >> i) & 1 else -1
    out = 0
    for i in range(64):
        if counts[i] > 0:
            out |= 1 << i
    return out


def simhash_hex(normalized: str) -> str:
    return f"{simhash64(normalized):016x}"


def hamming(a_hex: str, b_hex: str) -> int:
    return bin(int(a_hex, 16) ^ int(b_hex, 16)).count("1")


def prefix(fp_hex: str) -> str:
    return fp_hex[:4]
