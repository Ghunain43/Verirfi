/// Fingerprint generation for claim text.
/// 
/// Computes a 64-bit SimHash fingerprint of normalized text that can be used
/// to identify similar claims while preserving user privacy.
library;

import 'normalize.dart';
import 'simhash.dart';

/// Fingerprint of the text exactly as the user selected it.
/// Clients compute the same fingerprint to enable privacy-preserving lookups.
String computeFingerprint(String text) {
  return simhashHex(normalize(text));
}
