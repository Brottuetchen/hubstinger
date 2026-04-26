import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kToken   = 'auth_token';
const _kBaseUrl = 'server_base_url';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Token ──────────────────────────────────────────────────────────────────

  Future<String?> getToken() => _storage.read(key: _kToken);

  Future<void> saveToken(String token) => _storage.write(key: _kToken, value: token);

  Future<void> deleteToken() => _storage.delete(key: _kToken);

  Future<bool> get isLoggedIn async => (await getToken()) != null;

  // ── Server URL ─────────────────────────────────────────────────────────────

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBaseUrl) ?? '';
  }

  Future<bool> get isConfigured async => (await getBaseUrl()).isNotEmpty;

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  // ── JWT helpers ────────────────────────────────────────────────────────────

  /// Decodes the expiry time from a JWT without signature verification.
  DateTime? getTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '='; break;
      }
      final map = jsonDecode(utf8.decode(base64Url.decode(payload)))
          as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await deleteToken();
  }
}
