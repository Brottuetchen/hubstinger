import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await AuthService.instance.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<String> _base() => AuthService.instance.getBaseUrl();

  Future<dynamic> _get(String path, {bool auth = true}) async {
    final base = await _base();
    final uri = Uri.parse('$base$path');
    final res = await http.get(uri, headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 10));
    return _handle(res);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final base = await _base();
    final uri = Uri.parse('$base$path');
    final res = await http.post(uri,
        headers: await _headers(auth: auth),
        body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body.isNotEmpty ? jsonDecode(body) : null;
    }
    String msg = body;
    try { msg = (jsonDecode(body) as Map)['detail'] ?? body; } catch (_) {}
    throw ApiException(res.statusCode, msg);
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<String> login(String username, String password) async {
    final base = await _base();
    final uri = Uri.parse('$base/api/auth/token');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password})
        .timeout(const Duration(seconds: 10));
    final data = _handle(res) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    await AuthService.instance.saveToken(token);
    return token;
  }

  Future<Map<String, dynamic>> getMe() async =>
      (await _get('/api/auth/me')) as Map<String, dynamic>;

  // ── Jellyfin ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSessions() async =>
      (await _get('/api/jellyfin/sessions')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getRecentlyAdded({int days = 7, int limit = 10}) async =>
      (await _get('/api/jellyfin/recently-added?days=$days&limit=$limit'))
          as Map<String, dynamic>;

  // ── Stats ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async =>
      (await _get('/api/stats')) as Map<String, dynamic>;

  // ── Newsletter ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNewsletterArchive() async =>
      (await _get('/api/newsletter/archive')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> generateNewsletter() async =>
      (await _post('/api/newsletter/generate', {})) as Map<String, dynamic>;

  // ── VAPID / Push ───────────────────────────────────────────────────────────

  Future<String?> getVapidPublicKey() async {
    try {
      final data = await _get('/api/vapid-public-key', auth: false);
      return (data as Map<String, dynamic>)['publicKey'] as String?;
    } catch (_) { return null; }
  }

  // ── Health ─────────────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      await _get('/', auth: false);
      return true;
    } catch (_) { return false; }
  }
}
