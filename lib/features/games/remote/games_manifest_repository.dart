import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/config/app_config.dart';
import '../../../core/games/game_registry.dart';
import 'remote_web_game.dart';

/// Fetches the server-published games manifest and registers each entry as a
/// [RemoteWebGame] in the [GameRegistry] — the mechanism that lets a new game
/// ship from the backend with no app release.
///
/// Resilient by design: the last good manifest is cached in Hive, so games
/// keep showing offline and on a flaky network. The manifest endpoint is
/// unauthenticated catalog data, so this uses its own bare [Dio] (no token /
/// refresh interceptor needed) and can run at startup before sign-in.
class GamesManifestRepository {
  final Dio _dio;

  GamesManifestRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '${AppConfig.instance.apiBaseUrl}/api/v1/',
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ));

  static const _boxName = 'games_manifest';
  static const _cacheKey = 'entries';

  /// Loads the manifest (network, falling back to cache) and registers every
  /// playable game into [registry]. Never throws — a failure here must not
  /// block app startup; at worst the built-in native games remain.
  Future<void> registerInto(GameRegistry registry) async {
    final defs = await _load();
    final appVersion = AppConfig.instance.appVersion;
    final supportedSdk = AppConfig.instance.supportedSdkVersion;
    var registered = 0;
    for (final def in defs) {
      if (def.key.isEmpty || def.slug.isEmpty) continue;
      if (!_meetsMinVersion(appVersion, def.minAppVersion)) continue;
      // Don't register a game built for a newer SDK than this app's host
      // understands — it would load but fail to talk to the bridge.
      if (def.sdkVersion > supportedSdk) continue;
      registry.register(RemoteWebGame(def));
      registered++;
    }
    debugPrint('[games] registered $registered remote game(s) '
        'from ${defs.length} manifest entr${defs.length == 1 ? "y" : "ies"}');
  }

  /// Network first; on any failure fall back to the cached manifest. A
  /// successful fetch refreshes the cache.
  Future<List<RemoteGameDef>> _load() async {
    try {
      final response = await _dio.get('games/');
      final list = (response.data as List).cast<Map<String, dynamic>>();
      await _cache(list);
      return list.map(RemoteGameDef.fromJson).toList();
    } catch (e) {
      debugPrint('[games] manifest fetch failed ($e) — using cache');
      return _cached();
    }
  }

  Future<void> _cache(List<Map<String, dynamic>> raw) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      await box.put(_cacheKey, jsonEncode(raw));
    } catch (e) {
      debugPrint('[games] manifest cache write failed: $e');
    }
  }

  Future<List<RemoteGameDef>> _cached() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final raw = box.get(_cacheKey);
      if (raw == null) return const [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(RemoteGameDef.fromJson).toList();
    } catch (e) {
      debugPrint('[games] manifest cache read failed: $e');
      return const [];
    }
  }
}

/// True if [appVersion] >= [minVersion] (dotted-int semver). A blank/garbage
/// [minVersion] is treated as "no minimum", and an unparseable [appVersion]
/// fails open so games still show rather than silently disappearing.
bool _meetsMinVersion(String appVersion, String minVersion) {
  if (minVersion.trim().isEmpty) return true;
  final app = _semver(appVersion);
  final min = _semver(minVersion);
  if (app == null || min == null) return true;
  for (var i = 0; i < 3; i++) {
    if (app[i] != min[i]) return app[i] > min[i];
  }
  return true;
}

List<int>? _semver(String v) {
  final core = v.split('+').first.split('-').first.trim();
  if (core.isEmpty) return null;
  final parts = core.split('.');
  final out = <int>[0, 0, 0];
  for (var i = 0; i < parts.length && i < 3; i++) {
    final n = int.tryParse(parts[i]);
    if (n == null) return null;
    out[i] = n;
  }
  return out;
}
