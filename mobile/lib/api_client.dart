import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  // Your PC's LAN IP while developing. Change to the deployed URL later.
  static const base = 'http://192.168.18.19:8000';
  static const _prefKey = 'install_token';

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
        .timeout(const Duration(seconds: 10));
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
        .timeout(const Duration(seconds: 30));

    // Token expired, or the server restarted and forgot it: get a new one once.
    if (res.statusCode == 401 && !retried) {
      _token = null;
      await _install();
      return quickCheck(text, retried: true);
    }
    if (res.statusCode != 200) throw _toError(res);
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
