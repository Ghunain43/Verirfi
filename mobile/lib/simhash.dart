/// 64-bit SimHash over word 3-grams (API.md section 4).
///
/// Spec for Dart port:
/// - input: the normalized string (see normalize.dart), tokens split on single spaces
/// - shingles: every window of 3 consecutive tokens joined by one space.
///   If there are fewer than 3 tokens, the single shingle is all tokens joined by a space.
///   No tokens at all -> fingerprint is 16 zeros.
/// - shingle hash: FNV-1a 64 over the UTF-8 bytes, then the murmur3 fmix64 finalizer
/// - every shingle has weight 1 (duplicates count). Bit i of the result is 1 if more shingles
///   have bit i set than not set (ties give 0). Bit 63 is the most significant.
/// - output: 16 lowercase hex characters, zero padded. Lookup prefix = first 4 hex characters.
/// - Dart note: ints are signed 64-bit, so use >>> (unsigned shift) in fmix64.
library;

import 'dart:convert';

const int _mask = 0xFFFFFFFFFFFFFFFF;
const int _fnvOffset = 0xCBF29CE484222325;
const int _fnvPrime = 0x100000001B3;

int _fnv1a64(List<int> data) {
  int h = _fnvOffset;
  for (final b in data) {
    h ^= b;
    h = (h * _fnvPrime) & _mask;
  }
  return h;
}

int _fmix64(int h) {
  // Use >>> for unsigned right shift in Dart
  h ^= h >>> 33;
  h = (h * 0xFF51AFD7ED558CCD) & _mask;
  h ^= h >>> 33;
  h = (h * 0xC4CEB9FE1A85EC53) & _mask;
  h ^= h >>> 33;
  return h;
}

List<String> _shingles(String normalized) {
  final tokens = normalized.isEmpty ? <String>[] : normalized.split(' ');
  
  if (tokens.isEmpty) {
    return [];
  }
  
  if (tokens.length < 3) {
    return [tokens.join(' ')];
  }
  
  final result = <String>[];
  for (int i = 0; i <= tokens.length - 3; i++) {
    result.add([tokens[i], tokens[i + 1], tokens[i + 2]].join(' '));
  }
  return result;
}

int simhash64(String normalized) {
  final counts = List<int>.filled(64, 0);
  
  for (final sh in _shingles(normalized)) {
    final h = _fmix64(_fnv1a64(utf8.encode(sh)));
    for (int i = 0; i < 64; i++) {
      counts[i] += ((h >>> i) & 1) == 1 ? 1 : -1;
    }
  }
  
  int out = 0;
  for (int i = 0; i < 64; i++) {
    if (counts[i] > 0) {
      out |= 1 << i;
    }
  }
  
  return out;
}

String simhashHex(String normalized) {
  final hash = simhash64(normalized);
  return hash.toRadixString(16).padLeft(16, '0');
}

int hamming(String aHex, String bHex) {
  final xor = int.parse(aHex, radix: 16) ^ int.parse(bHex, radix: 16);
  return xor.toRadixString(2).replaceAll('0', '').length;
}

String prefix(String fpHex) {
  return fpHex.substring(0, 4);
}
