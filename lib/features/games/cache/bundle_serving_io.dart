import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Mobile/desktop offline support for S3-hosted games.
///
/// We are NOT streaming: a bundle is downloaded once to the app's cache
/// directory (mirroring the host layout `/games/<slug>/<version>/…` plus the
/// shared `/playstudy-sdk.js`) and then served to the WebView by a tiny local
/// HTTP server on 127.0.0.1. Because the version is immutable, a cached bundle
/// is never re-downloaded, and the game runs with no network — fully offline.
///
/// If a bundle isn't cached yet and we're offline, [resolveBase] falls back to
/// the online origin (which will simply fail to load until the user is online
/// once to populate the cache).
class BundleServing {
  static final Dio _dio = Dio();
  static HttpServer? _server;
  static String? _root;

  /// The base URL to load `<base>/games/<slug>/<version>/index.html` from now:
  /// the local server if the bundle is cached/cacheable, else the online origin.
  static Future<String> resolveBase({
    required String slug,
    required String version,
    required String onlineBase,
  }) async {
    try {
      final root = await _cacheRoot();
      if (await _ensureCached(root, slug, version, onlineBase)) {
        return await _ensureServer(root);
      }
    } catch (e) {
      debugPrint('[games] offline cache unavailable ($e) — using online origin');
    }
    return onlineBase;
  }

  /// Download a bundle ahead of time so it's available offline later. Safe to
  /// call on every launch — cached (immutable) versions are skipped.
  static Future<void> prewarm({
    required String slug,
    required String version,
    required String onlineBase,
  }) async {
    try {
      await _ensureCached(await _cacheRoot(), slug, version, onlineBase);
    } catch (e) {
      debugPrint('[games] prewarm $slug@$version failed: $e');
    }
  }

  static Future<String> _cacheRoot() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/games_cache';
  }

  /// Ensures the bundle's files (+ the SDK) are on disk. Returns true if the
  /// bundle's index.html is present afterwards.
  static Future<bool> _ensureCached(
    String root,
    String slug,
    String version,
    String onlineBase,
  ) async {
    final bundleDir = '$root/games/$slug/$version';
    final index = File('$bundleDir/index.html');
    if (await index.exists()) {
      // Immutable version already cached. Make sure the (shared) SDK is too.
      await _ensureSdk(root, onlineBase);
      return true;
    }
    // Needs the network to populate the cache the first time.
    final files = await _fileList(onlineBase, slug, version);
    for (final f in files) {
      await _download(
        '$onlineBase/games/$slug/$version/$f',
        '$bundleDir/$f',
      );
    }
    await _ensureSdk(root, onlineBase, force: true);
    return index.exists();
  }

  /// The bundle's file list comes from an optional `bundle.json`
  /// (`{"files": ["index.html", "assets/…", …]}`). Falls back to just
  /// index.html so single-file games work with no extra metadata.
  static Future<List<String>> _fileList(
    String base,
    String slug,
    String version,
  ) async {
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

  static Future<void> _ensureSdk(
    String root,
    String base, {
    bool force = false,
  }) async {
    final sdk = File('$root/playstudy-sdk.js');
    if (!force && await sdk.exists()) return;
    try {
      await _download('$base/playstudy-sdk.js', '$root/playstudy-sdk.js');
    } catch (_) {/* SDK may be vendored in the bundle; non-fatal */}
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
