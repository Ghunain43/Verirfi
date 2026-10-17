import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'normalize_map.g.dart';

/// Dart port of backend/app/core normalize.py and simhash.py (API.md section 4).
///
/// Must return exactly the same 16 hex characters as the Python version for
/// every input. `test/fingerprint_test.dart` checks this against
/// shared/fingerprint_vectors.json.
///
/// Dart ints are signed 64-bit on Android/iOS, so unsigned shifts (>>>) are
/// used wherever Python uses >> on a masked value.
class Fingerprint {
  Fingerprint._();

  /// Two messages are "the same claim" if their fingerprints differ in at most
  /// this many of the 64 bits. Confirm the value with Sharjeel.
  static const int matchDistance = 3;

  /// Fingerprint of text with no words.
  static const String empty = '0000000000000000';

  // ---- tables (generated from shared/normalize_map.json) -----------------

  static final Map<String, String> _charMap = _section('char_map');
  static final Map<String, String> _romanUrdu = _section('roman_urdu');

  static Map<String, String> _section(String name) {
    final root = jsonDecode(kNormalizeMapJson) as Map<String, dynamic>;
    final part = (root[name] as Map<String, dynamic>?) ?? const {};
    return part.map((k, v) => MapEntry(k, v.toString()));
  }

  // ---- normalize ---------------------------------------------------------

  // Category Cf, variation selectors FE00-FE0F, combining grapheme joiner 034F.
  static final RegExp _invisible = RegExp(
    r'[\p{Cf}' +
        String.fromCharCode(0xFE00) +
        '-' +
        String.fromCharCode(0xFE0F) +
        String.fromCharCode(0x034F) +
        r']',
    unicode: true,
  );

  // Anything that is not a letter, digit or combining mark becomes a space.
  static final RegExp _notKept = RegExp(
    r'[^\p{L}\p{N}\p{Mn}\p{Mc}]',
    unicode: true,
  );

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  /// Runs of 3+ identical letters become 2 ("nahiiii" -> "nahii").
  static String _squeeze(String token) {
    final out = StringBuffer();
    int? prev;
    var run = 0;
    for (final r in token.runes) {
      if (r == prev) {
        run++;
      } else {
        prev = r;
        run = 1;
      }
      if (run > 2 && _letter.hasMatch(String.fromCharCode(r))) continue;
      out.writeCharCode(r);
    }
    return out.toString();
  }

  static String normalize(String text) {
    var t = unorm.nfkc(text).toLowerCase();
    t = t.replaceAll(_invisible, '');

    final mapped = StringBuffer();
    for (final r in t.runes) {
      final ch = String.fromCharCode(r);
      mapped.write(_charMap[ch] ?? ch);
    }
    t = mapped.toString().replaceAll(_notKept, ' ');

    final tokens = <String>[];
    for (final tok in t.split(' ')) {
      if (tok.isEmpty) continue;
      final s = _squeeze(tok);
      tokens.add(_romanUrdu[s] ?? s);
    }
    return tokens.join(' ');
  }

  // ---- simhash -----------------------------------------------------------

  // 64-bit constants built from two 32-bit halves so no literal overflows.
  static final int _fnvOffset = (0xCBF29CE4 << 32) | 0x84222325;
  static const int _fnvPrime = 0x100000001B3;
  static final int _mix1 = (0xFF51AFD7 << 32) | 0xED558CCD;
  static final int _mix2 = (0xC4CEB9FE << 32) | 0x1A85EC53;

  static int _fnv1a64(List<int> data) {
    var h = _fnvOffset;
    for (final b in data) {
      h ^= b;
      h = h * _fnvPrime; // wraps at 64 bits
    }
    return h;
  }

  static int _fmix64(int h) {
    h ^= h >>> 33;
    h = h * _mix1;
    h ^= h >>> 33;
    h = h * _mix2;
    h ^= h >>> 33;
    return h;
  }

  static List<String> _shingles(String normalized) {
    if (normalized.isEmpty) return const [];
    final tokens = normalized.split(' ');
    if (tokens.length < 3) return [tokens.join(' ')];
    return [
      for (var i = 0; i <= tokens.length - 3; i++)
        tokens.sublist(i, i + 3).join(' '),
    ];
  }

  static String _toHex(int v) {
    final hi = (v >>> 32) & 0xFFFFFFFF;
    final lo = v & 0xFFFFFFFF;
    return hi.toRadixString(16).padLeft(8, '0') +
        lo.toRadixString(16).padLeft(8, '0');
  }

  static int _fromHex(String hex) {
    final hi = int.parse(hex.substring(0, 8), radix: 16);
    final lo = int.parse(hex.substring(8, 16), radix: 16);
    return (hi << 32) | lo;
  }

  /// SimHash of an already normalized string, as 16 lowercase hex characters.
  static String hexOfNormalized(String normalized) {
    final shingles = _shingles(normalized);
    if (shingles.isEmpty) return empty;
    final counts = List<int>.filled(64, 0);
    for (final s in shingles) {
      final h = _fmix64(_fnv1a64(utf8.encode(s)));
      for (var i = 0; i < 64; i++) {
        counts[i] += ((h >>> i) & 1) == 1 ? 1 : -1;
      }
    }
    var out = 0;
    for (var i = 0; i < 64; i++) {
      if (counts[i] > 0) {
        out |= (1 << i);
      }
    }
    return _toHex(out);
  }

  // ---- public API --------------------------------------------------------

  /// Fingerprint of a raw message, computed on the device.
  static String of(String text) => hexOfNormalized(normalize(text));

  /// First 4 hex characters. This is all that is sent to /lookup.
  static String prefix(String fp) => fp.substring(0, 4);

  static final RegExp _hex16 = RegExp(r'^[0-9a-f]{16}$');
  static bool isValid(String fp) => _hex16.hasMatch(fp);

  /// Number of differing bits between two fingerprints (0..64).
  static int hamming(String a, String b) {
    final x = _fromHex(a) ^ _fromHex(b);
    var count = 0;
    for (var i = 0; i < 64; i++) {
      count += (x >>> i) & 1;
    }
    return count;
  }
}
