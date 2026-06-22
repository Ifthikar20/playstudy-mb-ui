// Platform-agnostic embedder for a hosted web game bundle.
//
// `GameHostView` has one public API and two implementations chosen at compile
// time, so the rest of the app embeds a game the same way everywhere:
//
//   • mobile/desktop (dart:io)   → a WebView   (game_host_view_io.dart)
//   • web            (dart:html) → an <iframe>  (game_host_view_web.dart)
//
// Both load the same bundle from the games CDN and bridge it through the
// identical PlayStudy SDK contract (see GameEvent). This is what lets a game
// publish once and run on mobile and web with no game logic in the app core.

export 'game_event.dart';
export 'game_host_view_stub.dart'
    if (dart.library.io) 'game_host_view_io.dart'
    if (dart.library.html) 'game_host_view_web.dart';
