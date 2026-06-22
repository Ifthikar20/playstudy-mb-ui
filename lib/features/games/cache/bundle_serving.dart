// Resolves the base URL a game bundle is loaded from. Conditional export:
//   • mobile/desktop (dart:io) → download to disk + serve from a local HTTP
//     server, so a game runs from cache and works offline.
//   • web (dart:html)         → pass through to the online origin (the browser
//     / a service worker handles offline caching).
//
// Both expose the same `BundleServing` API:
//   resolveBase(...) → the base to load the bundle from right now
//   prewarm(...)     → download the bundle ahead of time for offline use
export 'bundle_serving_io.dart'
    if (dart.library.html) 'bundle_serving_web.dart';
