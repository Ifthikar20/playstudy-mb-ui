/// Web build: games load from the online origin; offline caching is handled by
/// a service worker (see games_host/sw.js), not by the app. These are no-ops
/// that keep the cross-platform [BundleServing] API uniform.
class BundleServing {
  static Future<String> resolveBase({
    required String slug,
    required String version,
    required String onlineBase,
  }) async =>
      onlineBase;

  static Future<void> prewarm({
    required String slug,
    required String version,
    required String onlineBase,
  }) async {}
}
