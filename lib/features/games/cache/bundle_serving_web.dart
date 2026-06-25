/// Web build: games load from the online origin; offline caching is handled by
/// a service worker (see games_host/sw.js), not by the app. These keep the
/// cross-platform [BundleServing] API uniform; storage management is the
/// browser's, so usage/clear are no-ops here.
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

  static Future<int> usageBytes() async => 0;

  static Future<void> clearDownloads() async {}
}
