import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth/user.dart';

/// Persists JWT access + refresh tokens, plus a cached copy of the signed-in
/// user so the app can stay logged in offline. SharedPreferences keeps the
/// wiring dependency-free; swap for flutter_secure_storage when hardening for
/// release.
class TokenStore {
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _userKey = 'auth_user';

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

  /// Caches the signed-in user so a returning user is shown immediately even
  /// when `/me` can't be reached (offline / flaky network).
  Future<void> cacheUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': user.id,
        'email': user.email,
        'name': user.name,
        'avatarUrl': user.avatarUrl,
      }),
    );
  }

  Future<User?> cachedUser() async {
    final raw = (await SharedPreferences.getInstance()).getString(_userKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return User(
        id: (j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        name: (j['name'] ?? 'Student').toString(),
        avatarUrl: j['avatarUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_userKey);
  }
}
