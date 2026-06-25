import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/storage_prefs.dart';

/// Mobile/desktop offline support for S3-hosted games — with a hard storage
/// budget so downloads can't crowd the device.
///
/// We are NOT streaming: a bundle is downloaded once to the app cache
/// (mirroring `/games/<slug>/<version>/…` + the shared `/playstudy-sdk.js`)
/// and served to the WebView from a local 127.0.0.1 HTTP server. Immutable
/// versions are cached once. Total bundle size is kept under the user's limit
/// ([StoragePrefs.limitBytes]) via LRU eviction. When the user turns offline
/// off, nothing is stored — games stream from the origin instead.
class BundleServing {
  static final Dio _dio = Dio();
  static HttpServer? _server;
  static String? _root;

  /// The base URL to load the bundle from now: the local server if cached/
  /// cacheable (and offline is enabled), else the online origin.
  static Future<String> resolveBase({
    required String slug,
    required String version,
    required String onlineBase,
  }) async {
    if (!await StoragePrefs.offlineEnabled()) return onlineBase;
    try {
      final root = await _cacheRoot();
      if (await _ensureCached(root, slug, version, onlineBase)) {
        await _touch(root, slug, version);
        await _enforceBudget(root);
        return await _ensureServer(root);
      }
    } catch (e) {
      debugPrint('[games] offline cache unavailable ($e) — using online origin');
    }
    return onlineBase;
  }

  /// Pre-download a bundle for offline use. Skips when offline is off or the
  /// cache is already at the budget (so prewarming never overfills).
  static Future<void> prewarm({
    required String slug,
    required String version,
    required String onlineBase,
  }) async {
    try {
      if (!await StoragePrefs.offlineEnabled()) return;
      final root = await _cacheRoot();
      final gamesDir = '$root/games';
      if (await _dirSize(gamesDir) >= await StoragePrefs.limitBytes()) return;
      if (await _ensureCached(root, slug, version, onlineBase)) {
        await _touch(root, slug, version);
      }
    } catch (e) {
      debugPrint('[games] prewarm $slug@$version failed: $e');
    }
  }

  /// Bytes currently used by the on-device game cache.
  static Future<int> usageBytes() async {
    try {
      return await _dirSize(await _cacheRoot());
    } catch (_) {
      return 0;
    }
  }

  /// Delete all downloaded bundles (and the SDK). The library/study data is a
  /// separate, tiny cache and is not touched here.
  static Future<void> clearDownloads() async {
    try {
      final dir = Directory(await _cacheRoot());
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('[games] clearDownloads failed: $e');
    }
  }

  static Future<String> _cacheRoot() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/games_cache';
  }

  static Future<bool> _ensureCached(
    String root,
    String slug,
    String version,
    String onlineBase,
  ) async {
    final bundleDir = '$root/games/$slug/$version';
    final index = File('$bundleDir/index.html');
    if (await index.exists()) {
      await _ensureSdk(root, onlineBase);
      return true;
    }
    final files = await _fileList(onlineBase, slug, version);
    for (final f in files) {
      await _download('$onlineBase/games/$slug/$version/$f', '$bundleDir/$f');
    }
    await _ensureSdk(root, onlineBase, force: true);
    return index.exists();
  }

  static Future<List<String>> _fileList(
      String base, String slug, String version) async {
    try {
      final r = await _dio.get<String>(
        '$base/games/$slug/$version/bundle.json',
        options: Options(responseType: ResponseType.plain),
      );
      final data = jsonDecode(r.data ?? '{}') as Map<String, dynamic>;
      final files = (data['files'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty && !e.contains('..'))
          .toList();
      if (!files.contains('index.html')) files.add('index.html');
      return files;
    } catch (_) {
      return const ['index.html'];
    }
  }

  static Future<void> _ensureSdk(String root, String base,
      {bool force = false}) async {
    final sdk = File('$root/playstudy-sdk.js');
    if (!force && await sdk.exists()) return;
    try {
      await _download('$base/playstudy-sdk.js', '$root/playstudy-sdk.js');
    } catch (_) {/* may be vendored in the bundle */}
  }

  static Future<void> _download(String url, String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final resp = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    await file.writeAsBytes(resp.data ?? const []);
  }

  // --- LRU index + budget enforcement --------------------------------------

  static String _indexPath(String root) => '$root/.access.json';

  static Future<Map<String, int>> _loadIndex(String root) async {
    try {
      final f = File(_indexPath(root));
      if (!await f.exists()) return {};
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _touch(String root, String slug, String version) async {
    final idx = await _loadIndex(root);
    idx['$slug/$version'] = DateTime.now().millisecondsSinceEpoch;
    try {
      await File(_indexPath(root)).writeAsString(jsonEncode(idx));
    } catch (_) {}
  }

  /// Evict least-recently-used bundles until total bundle size is under budget.
  static Future<void> _enforceBudget(String root) async {
    final limit = await StoragePrefs.limitBytes();
    var total = await _dirSize('$root/games');
    if (total <= limit) return;
    final idx = await _loadIndex(root);
    final ordered = idx.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value)); // oldest first
    for (final e in ordered) {
      if (total <= limit) break;
      final dir = Directory('$root/games/${e.key}');
      if (await dir.exists()) {
        total -= await _dirSize(dir.path);
        await dir.delete(recursive: true);
      }
      idx.remove(e.key);
    }
    try {
      await File(_indexPath(root)).writeAsString(jsonEncode(idx));
    } catch (_) {}
  }

  static Future<int> _dirSize(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  // --- local server --------------------------------------------------------

  static Future<String> _ensureServer(String root) async {
    final existing = _server;
    if (existing != null && _root == root) {
      return 'http://127.0.0.1:${existing.port}';
    }
    _root = root;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((req) => _serve(req, root));
    return 'http://127.0.0.1:${server.port}';
  }

  static Future<void> _serve(HttpRequest req, String root) async {
    final res = req.response;
    try {
      final path = req.uri.path;
      if (path.contains('..')) {
        res.statusCode = HttpStatus.forbidden;
      } else {
        final file = File('$root$path');
        if (await file.exists()) {
          res.headers.contentType = _contentType(path);
          await res.addStream(file.openRead());
        } else {
          res.statusCode = HttpStatus.notFound;
        }
      }
    } catch (_) {
      res.statusCode = HttpStatus.internalServerError;
    }
    await res.close();
  }

  static ContentType _contentType(String p) {
    if (p.endsWith('.html')) return ContentType.html;
    if (p.endsWith('.js')) return ContentType('application', 'javascript');
    if (p.endsWith('.css')) return ContentType('text', 'css');
    if (p.endsWith('.json')) return ContentType('application', 'json');
    if (p.endsWith('.png')) return ContentType('image', 'png');
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) {
      return ContentType('image', 'jpeg');
    }
    if (p.endsWith('.svg')) return ContentType('image', 'svg+xml');
    if (p.endsWith('.wasm')) return ContentType('application', 'wasm');
    if (p.endsWith('.mp3')) return ContentType('audio', 'mpeg');
    if (p.endsWith('.ogg')) return ContentType('audio', 'ogg');
    return ContentType.binary;
  }
}
