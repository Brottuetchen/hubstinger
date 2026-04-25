import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kToken       = 'auth_token';
const _kBaseUrl     = 'server_base_url';
const _kDefaultUrl  = 'https://hub.t-acc.com';

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
    return prefs.getString(_kBaseUrl) ?? _kDefaultUrl;
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await deleteToken();
  }
}
