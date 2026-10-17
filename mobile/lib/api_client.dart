import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // Android emulator -> host machine. For a physical phone use your PC's LAN IP.
  static const base = 'http://192.168.18.19:8000';

  Future<Map<String, dynamic>> quickCheck(String text) async {
    final res = await http
        .post(
          Uri.parse('$base/api/v1/quick-check'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'lang': 'auto'}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('${res.statusCode}: ${res.body}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
