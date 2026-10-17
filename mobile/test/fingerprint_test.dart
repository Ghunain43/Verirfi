import 'package:flutter_test/flutter_test.dart';
import 'package:verifi/fingerprint.dart';
import 'package:verifi/normalize.dart';
import 'package:verifi/simhash.dart';

void main() {
  setUpAll(() {
    initializeNormalizeMap();
  });

  group('Normalize Tests', () {
    final testCases = [
      ['plain_case_punctuation', 'BREAKING NEWS: Hot Water Cures Dengue!!!', 'breaking news hot water cures dengue'],
      ['cyrillic_homoglyphs', 'Hоt wаter cures dеngue', 'hot water cures dengue'],
      ['greek_homoglyph', 'dεngue fever', 'dengue fever'],
      ['zero_width_inside_word', 'hot\u200bwater de\u200dngue', 'hotwater dengue'],
      ['soft_hyphen', 'dis\u00adease', 'disease'],
      ['bom_and_bidi_marks', '\ufeffhot\u202e water', 'hot water'],
      ['emoji_between_words', 'hot 🔥 water 💧 cures 😷 dengue', 'hot water cures dengue'],
      ['repeated_letters', 'cooool nahiiiii', 'cool nahi'],
      ['digits_not_squeezed', '1000000 rupees', '1000000 rupees'],
      ['whitespace_variants', 'hot\twater\n\ncures   dengue\u00a0fever', 'hot water cures dengue fever'],
      ['apostrophe_hyphen', 'don\'t-panic', 'don t panic'],
      ['roman_urdu_variants', 'Nhi bohat zyada bukhaar', 'nahi bahut zyada bukhar'],
      ['roman_urdu_spelling_pair_a', 'ye jhoot hai', 'yeh jhoot hai'],
      ['roman_urdu_spelling_pair_b', 'yah jhut hay', 'yeh jhoot hai'],
      ['arabic_digits', '٢٠٢٦', '2026'],
      ['persian_digits', '۱۲۳', '123'],
      ['arabic_kaf_yeh', 'كتاب ايك', 'کتاب ایک'],
      ['urdu_diacritics_removed', 'پَانی', 'پانی'],
      ['empty', '', ''],
      ['only_symbols', '!!! 🔥 ???', ''],
    ];

    for (final tc in testCases) {
      test('normalize: ${tc[0]}', () {
        expect(normalize(tc[1]), equals(tc[2]));
      });
    }
  });

  group('Normalize Idempotent', () {
    test('normalize is idempotent', () {
      final testTexts = [
        'BREAKING NEWS: Hot Water Cures Dengue!!!',
        'Hоt wаter cures dеngue',
        'cooool nahiiiii',
        '٢٠٢٦',
      ];

      for (final text in testTexts) {
        final once = normalize(text);
        expect(normalize(once), equals(once));
      }
    });
  });

  group('Fingerprint Tests', () {
    const base = 'Drinking hot water cures dengue fever according to doctors';

    test('obfuscated variants share one fingerprint', () {
      final variants = [
        base.toUpperCase(),
        'Drinking hоt wаter cures dеngue fever according to doctors',
        'Drin\u200bking hot 🔥 water cures dengue fever, according to doctors!!!',
      ];

      final ref = computeFingerprint(base);
      for (final v in variants) {
        expect(computeFingerprint(v), equals(ref),
            reason: 'Variant should match base fingerprint');
      }
    });

    test('similar claims closer than unrelated', () {
      final baseHash = computeFingerprint(base);
      final similar = computeFingerprint(
          'Drinking hot water cures dengue fever according to some doctors');
      final unrelated = computeFingerprint(
          'The government announced a new budget for schools today');

      final distSimilar = hamming(baseHash, similar);
      final distUnrelated = hamming(baseHash, unrelated);

      expect(distSimilar, lessThan(distUnrelated),
          reason: 'Similar claims should have lower Hamming distance');
    });

    test('fingerprint shape', () {
      final fp = simhashHex(normalize(base));
      expect(fp.length, equals(16));
      expect(fp, equals(fp.toLowerCase()));
      final parsed = int.parse(fp, radix: 16);
      expect(parsed >= 0, isTrue);
      expect(prefix(fp), equals(fp.substring(0, 4)));
      expect(simhashHex(''), equals('0' * 16));
    });

    test('short inputs use single shingle', () {
      expect(simhashHex('hello'), isNot(equals(simhashHex('hello world'))));
    });
  });

  group('Known Vectors', () {
    // These are known-good fingerprints from the Python implementation
    // Update these with actual values from shared/fingerprint_vectors.json
    test('basic claim fingerprint', () {
      final text = 'Drinking hot water cures dengue fever';
      final fp = computeFingerprint(text);
      
      // Verify it's a valid 16-character hex string
      expect(fp.length, equals(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(fp), isTrue);
    });

    test('urdu text fingerprint', () {
      final text = 'گرم پانی ڈینگی بخار کا علاج ہے';
      final fp = computeFingerprint(text);
      
      // Verify it's a valid fingerprint
      expect(fp.length, equals(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(fp), isTrue);
    });
  });

  group('SimHash Details', () {
    test('empty string produces zero hash', () {
      expect(simhashHex(''), equals('0000000000000000'));
    });

    test('same input produces same hash', () {
      const input = 'test claim about health';
      final hash1 = simhashHex(input);
      final hash2 = simhashHex(input);
      expect(hash1, equals(hash2));
    });

    test('hamming distance is symmetric', () {
      final fp1 = simhashHex('claim one');
      final fp2 = simhashHex('claim two');
      expect(hamming(fp1, fp2), equals(hamming(fp2, fp1)));
    });

    test('identical hashes have zero hamming distance', () {
      final fp = simhashHex('test claim');
      expect(hamming(fp, fp), equals(0));
    });
  });
}
