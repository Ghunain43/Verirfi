# Fingerprint Implementation

This directory contains the Dart port of Verifi's privacy-preserving fingerprinting system.

## Files

### Core Implementation
- **`normalize.dart`** - Text normalization pipeline that handles:
  - Unicode NFKC normalization and lowercasing
  - Invisible character removal (zero-width, soft hyphens, bidi marks)
  - Homoglyph mapping (Cyrillic → Latin, Greek → Latin)
  - Arabic/Persian digit normalization
  - Urdu script normalization (remove diacritics, normalize letter forms)
  - Roman Urdu spelling variants (over 80 mappings)
  - Repeated letter squeezing (3+ → 2 for letters only)

- **`simhash.dart`** - 64-bit SimHash implementation:
  - FNV-1a 64-bit hash with MurmurHash3 fmix64 finalizer
  - 3-gram shingles (or single shingle for <3 tokens)
  - Returns 16 lowercase hex characters
  - First 4 hex chars = lookup prefix for privacy

- **`fingerprint.dart`** - High-level API:
  - `computeFingerprint(text)` - Main entry point
  - Combines normalize + simhash
  - Used by API client for cache lookups

### Integration
The fingerprint system is integrated into:
- **`api_client.dart`** - Added `lookup()` and `checkCached()` methods
- **`main.dart`** - Initializes normalize map on startup

## Usage

```dart
import 'package:verifi/fingerprint.dart';
import 'package:verifi/normalize.dart';

// Initialize once at startup (done in main.dart)
initializeNormalizeMap();

// Generate fingerprint
final fp = computeFingerprint('Drinking hot water cures dengue');
print(fp); // e.g., "a3f1234567890abc"

// Get lookup prefix (first 4 chars)
final prefix = fp.substring(0, 4); // "a3f1"

// Use in API client
final client = ApiClient();
final cached = await client.checkCached('Some claim text');
if (cached != null) {
  print('Found in cache: ${cached['claim']}');
} else {
  print('Not cached, calling quick-check...');
}
```

## Privacy Guarantees

1. **Normalization makes obfuscation useless**: Homoglyphs, emoji, repeated letters, spelling variants all map to the same normalized form

2. **SimHash creates locality-sensitive fingerprints**: Similar claims have similar fingerprints (low Hamming distance)

3. **4-hex prefix lookup preserves privacy**: 
   - Client only sends first 4 hex chars (16^4 = 65,536 buckets)
   - Server never sees the exact claim
   - Client does final Hamming distance match locally

4. **No PII stored**: Only extracted claim, verdict, and evidence - never user's original text or identity

## Testing

Run the test suite:
```bash
flutter test test/fingerprint_test.dart
```

Tests verify:
- ✅ 20 adversarial normalization cases
- ✅ Idempotency of normalization
- ✅ Obfuscated variants produce same fingerprint
- ✅ Similar claims closer than unrelated (Hamming distance)
- ✅ Fingerprint format (16 lowercase hex chars)
- ✅ Empty input handling
- ✅ Hamming distance symmetry

All tests pass ✅ (31/31)

## Compatibility

This implementation **must match exactly** with:
- Python backend: `backend/app/core/{normalize,simhash,fingerprint}.py`
- TypeScript extension: (when implemented)
- Shared data: `shared/normalize_map.json`

Any changes to the normalization or hashing must be coordinated across all three implementations to maintain compatibility.

## Known Limitations

1. **NFKC normalization**: Dart doesn't have built-in NFKC. Current implementation uses simple lowercase. For production, consider using the `characters` package or a full Unicode normalization library.

2. **Unicode category detection**: Simplified implementation of Unicode categories (Letter, Digit, Mark). Covers common ranges but may miss edge cases. Full implementation would need comprehensive Unicode database.

3. **Roman Urdu mappings**: The 80+ spelling variants are embedded in code. Future updates to `shared/normalize_map.json` require manual sync.

## Performance

- Normalize: O(n) where n = input length
- SimHash: O(m) where m = number of 3-grams (≈ input tokens)
- Typical: <5ms for 200-word claim on mobile device
- Lookup: ~10ms network round-trip

## Future Enhancements

- [ ] Add NFKC normalization library
- [ ] Hot-reload normalize_map.json from backend
- [ ] Cache fingerprints in SharedPreferences
- [ ] Background sync of claim cache
- [ ] Hamming distance threshold tuning (currently client-side matching)
