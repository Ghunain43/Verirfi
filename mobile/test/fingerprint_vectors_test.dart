import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// ADJUST these two imports and the two function names below to match your files.
import 'package:verifi/normalize.dart';
import 'package:verifi/fingerprint.dart';

void main() {
  // flutter test runs from the package root (mobile/), so shared/ is one level up.
  final file = File('../shared/fingerprint_vectors.json');
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (data['vectors'] as List).cast<Map<String, dynamic>>();

  test('vectors file has at least 15 cases', () {
    expect(vectors.length, greaterThanOrEqualTo(15));
  });

  for (final v in vectors) {
    final name = v['name'] as String;
    final input = v['input'] as String;

    test('normalize: $name', () {
      expect(normalize(input), v['normalized']); // <- your normalize function
    });

    test('fingerprint: $name', () {
      expect(
        computeFingerprint(input),
        v['fingerprint'],
      ); // <- your fingerprint function
    });
  }
}
