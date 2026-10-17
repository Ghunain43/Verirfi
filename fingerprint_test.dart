import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/fingerprint.dart';
import 'package:mobile/normalize_map.g.dart';

// Run from the mobile/ folder:  flutter test test/fingerprint_test.dart

String? _pick(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is String) return v;
  }
  return null;
}

/// Collects every list of objects found in the vectors file, whatever its shape.
List<Map<String, dynamic>> _loadVectors() {
  final raw = jsonDecode(
    File('../shared/fingerprint_vectors.json').readAsStringSync(),
  );
  final lists = <List>[];
  if (raw is List) {
    lists.add(raw);
  } else if (raw is Map) {
    for (final v in raw.values) {
      if (v is List) lists.add(v);
    }
  }
  return [
    for (final l in lists)
      for (final e in l)
        if (e is Map) e.cast<String, dynamic>(),
  ];
}

void main() {
  test('matches the fingerprint the live server returned', () {
    expect(
      Fingerprint.of('The COVID-19 vaccine contains microchips'),
      '86292b0369e060a0',
    );
  });

  test('empty and punctuation-only text give the all-zero fingerprint', () {
    expect(Fingerprint.of(''), Fingerprint.empty);
    expect(Fingerprint.of('!!! ... ???'), Fingerprint.empty);
  });

  test('hamming distance and prefix', () {
    expect(Fingerprint.hamming('0000000000000000', 'ffffffffffffffff'), 64);
    expect(Fingerprint.hamming('86292b0369e060a0', '86292b0369e060a0'), 0);
    expect(Fingerprint.hamming('0000000000000000', '8000000000000001'), 2);
    expect(Fingerprint.prefix('86292b0369e060a0'), '8629');
  });

  test('generated map is in sync with shared/normalize_map.json', () {
    final shared = jsonDecode(
      File('../shared/normalize_map.json').readAsStringSync(),
    );
    expect(jsonDecode(kNormalizeMapJson), equals(shared));
  });

  group('shared/fingerprint_vectors.json', () {
    final vectors = _loadVectors();

    test('file has at least one vector', () {
      expect(vectors, isNotEmpty);
    });

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      test('vector $i', () {
        final input = _pick(v, ['input', 'text', 'raw', 'message', 'in']);
        final wantFp = _pick(v, ['fingerprint', 'expected', 'hex', 'fp', 'output']);
        final wantNorm = _pick(v, ['normalized', 'norm', 'expected_normalized']);
        if (input == null || (wantFp == null && wantNorm == null)) {
          fail('Unrecognised vector shape, paste it to Claude: $v');
        }
        if (wantNorm != null) {
          expect(Fingerprint.normalize(input), wantNorm, reason: 'normalize "$input"');
        }
        if (wantFp != null && Fingerprint.isValid(wantFp)) {
          expect(Fingerprint.of(input), wantFp, reason: 'fingerprint of "$input"');
        }
      });
    }
  });
}
