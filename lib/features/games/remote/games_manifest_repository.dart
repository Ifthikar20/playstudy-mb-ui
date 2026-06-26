import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/config/app_config.dart';
import '../../../core/games/game_registry.dart';
import '../cache/bundle_serving.dart';
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
  static const _flagsBoxName = 'games_flags';
  static const _flagsCacheKey = 'entries';

  /// Loads the manifest (network, falling back to cache) and registers every
  /// playable game into [registry], then applies the server's per-game on/off
  /// flags. Never throws — a failure here must not block app startup; at worst
  /// the built-in native games remain and every game stays on (fail-open).
  Future<void> registerInto(GameRegistry registry) async {
    // Fetch the catalog and the on/off flags together so the kill-switch adds
    // no extra startup latency.
    final defsFuture = _load();
    final disabledFuture = _loadDisabledKeys();

    final defs = await defsFuture;
    final appVersion = AppConfig.instance.appVersion;
    final supportedSdk = AppConfig.instance.supportedSdkVersion;
    final registeredDefs = <RemoteGameDef>[];
    for (final def in defs) {
      if (def.key.isEmpty || def.slug.isEmpty) continue;
      if (!_meetsMinVersion(appVersion, def.minAppVersion)) continue;
      // Don't register a game built for a newer SDK than this app's host
      // understands — it would load but fail to talk to the bridge.
      if (def.sdkVersion > supportedSdk) continue;
      registry.register(RemoteWebGame(def));
      registeredDefs.add(def);
    }
    final registered = registeredDefs.length;
    // Pre-download the bundles in the background so they're playable offline
    // before the user opens them. Best-effort; cached versions are skipped.
    unawaited(_prewarm(registeredDefs));

    // Apply per-game on/off switches LAST, so the backend can also disable a
    // built-in (native) game — not just hide a remote one. Unknown keys no-op.
    final disabled = await disabledFuture;
    for (final key in disabled) {
      registry.unregister(key);
    }

    debugPrint('[games] registered $registered remote game(s) '
        'from ${defs.length} manifest entr${defs.length == 1 ? "y" : "ies"}'
        '${disabled.isEmpty ? "" : "; disabled ${disabled.length} via flags: $disabled"}');
  }

  /// Loads the per-game on/off flags (network, falling back to cache) and
  /// returns the keys the server has switched OFF. Games default to enabled, so
  /// a fetch failure with no cache returns an empty list — every game stays on.
  Future<List<String>> _loadDisabledKeys() async {
    try {
      final response = await _dio.get('games/flags/');
      final list = (response.data as List).cast<Map<String, dynamic>>();
      await _cacheFlags(list);
      return _disabledFrom(list);
    } catch (e) {
      debugPrint('[games] flags fetch failed ($e) — using cache');
      return _disabledFromCache();
    }
  }

  /// Keys whose flag is explicitly `enabled: false`. Anything else (missing or
  /// true) is treated as enabled, so the switch is opt-in and fail-open.
  List<String> _disabledFrom(List<Map<String, dynamic>> list) => [
        for (final m in list)
          if (m['enabled'] == false) (m['key'] as String? ?? ''),
      ].where((k) => k.isNotEmpty).toList(growable: false);

  Future<void> _cacheFlags(List<Map<String, dynamic>> raw) async {
    try {
      final box = await Hive.openBox<String>(_flagsBoxName);
      await box.put(_flagsCacheKey, jsonEncode(raw));
    } catch (e) {
      debugPrint('[games] flags cache write failed: $e');
    }
  }

  Future<List<String>> _disabledFromCache() async {
    try {
      final box = await Hive.openBox<String>(_flagsBoxName);
      final raw = box.get(_flagsCacheKey);
      if (raw == null) return const [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return _disabledFrom(list);
    } catch (e) {
      debugPrint('[games] flags cache read failed: $e');
      return const [];
    }
  }

  /// Download each registered bundle to disk (sequentially, to avoid a startup
  /// network burst) so games are available offline. No-op on web.
  Future<void> _prewarm(List<RemoteGameDef> defs) async {
    final base = AppConfig.instance.gamesBaseUrl;
    for (final def in defs) {
      await BundleServing.prewarm(
        slug: def.slug,
        version: def.version,
        onlineBase: base,
      );
    }
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
