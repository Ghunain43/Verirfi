import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'fingerprint.dart';

/// Error shape from API.md section 6: {"error": {"code", "message"}}.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, {this.retryAfter});
  final int status;
  final String code;
  final String message;
  final int? retryAfter;

  @override
  String toString() => 'ApiException($status $code): $message';
}

class ApiClient {
  /// Deployed backend. For local testing run:
  /// flutter run --dart-define=API_BASE=http://192.168.18.19:8000
  static const base = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://verifi.fastapicloud.dev',
  );
  static const _prefKey = 'install_token';

  // The free backend sleeps when idle; the first request can take up to a minute to wake it.
  static const _wakeTimeout = Duration(seconds: 60);

  String? _token;

  ApiException _toError(http.Response res) {
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final e = j['error'] as Map<String, dynamic>;
      return ApiException(
        res.statusCode,
        (e['code'] ?? 'unknown').toString(),
        (e['message'] ?? '').toString(),
        retryAfter: int.tryParse(res.headers['retry-after'] ?? ''),
      );
    } catch (_) {
      return ApiException(res.statusCode, 'unknown', res.body);
    }
  }

  Future<String> _install() async {
    final res = await http
        .post(
          Uri.parse('$base/api/v1/auth/install'),
          headers: {'Content-Type': 'application/json'},
          body: '{}',
        )
        .timeout(_wakeTimeout);
    if (res.statusCode != 201 && res.statusCode != 200) throw _toError(res);
    final tok =
        (jsonDecode(res.body) as Map<String, dynamic>)['install_token']
            as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, tok);
    _token = tok;
    return tok;
  }

  Future<String> _ensureToken() async {
    if (_token != null) return _token!;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefKey);
    return _token ?? await _install();
  }

  Future<Map<String, dynamic>> quickCheck(
    String text, {
    bool retried = false,
  }) async {
    final token = await _ensureToken();
    final res = await http
        .post(
          Uri.parse('$base/api/v1/quick-check'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'text': text, 'lang': 'auto', 'source': 'mobile'}),
        )
        .timeout(_wakeTimeout);

    // Token expired, or the saved token is not valid for this server: get a new one once.
    if (res.statusCode == 401 && !retried) {
      _token = null;
      await _install();
      return quickCheck(text, retried: true);
    }
    if (res.statusCode != 200) throw _toError(res);
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Rumor Radar: community claims first, then recent false claims found by fact-checkers.
  /// Each item: fingerprint, claim, reports, first_seen, last_seen, origin ("community" | "web"),
  /// source_url, publisher, why.
  Future<List<Map<String, dynamic>>> radar({bool retried = false}) async {
    final token = await _ensureToken();
    final res = await http
        .get(
          Uri.parse('$base/api/v1/radar'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_wakeTimeout);

    if (res.statusCode == 401 && !retried) {
      _token = null;
      await _install();
      return radar(retried: true);
    }
    if (res.statusCode != 200) throw _toError(res);
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Lookup previously checked claims by fingerprint prefix (privacy-preserving).
  /// Returns a list of claims whose fingerprints start with the given 4-hex prefix.
  Future<List<Map<String, dynamic>>> lookup(
    String prefix, {
    bool retried = false,
  }) async {
    final token = await _ensureToken();
    final res = await http
        .get(
          Uri.parse('$base/api/v1/lookup/$prefix'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401 && !retried) {
      _token = null;
      await _install();
      return lookup(prefix, retried: true);
    }
    if (res.statusCode != 200) throw _toError(res);

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['entries'] as List).cast<Map<String, dynamic>>();
  }

  /// Check if a claim exists in the cache by computing its fingerprint
  /// and looking up the prefix. Returns the cached result if found.
  Future<Map<String, dynamic>?> checkCached(String text) async {
    final fp = computeFingerprint(text);
    final prefix = fp.substring(0, 4);
    final entries = await lookup(prefix);

    // Find exact match by full fingerprint
    for (final entry in entries) {
      if (entry['fingerprint'] == fp) {
        return entry;
      }
    }
    return null;
  }
}
