import 'package:shared_preferences/shared_preferences.dart';

/// Persists JWT access + refresh tokens. SharedPreferences keeps the wiring
/// dependency-free; swap for flutter_secure_storage when hardening for release.
class TokenStore {
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  Future<String?> accessToken() async =>
      (await SharedPreferences.getInstance()).getString(_accessKey);

  Future<String?> refreshToken() async =>
      (await SharedPreferences.getInstance()).getString(_refreshKey);

  Future<bool> hasTokens() async => (await accessToken()) != null;

  Future<void> setTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<void> setAccessToken(String access) async {
    await (await SharedPreferences.getInstance()).setString(_accessKey, access);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}
