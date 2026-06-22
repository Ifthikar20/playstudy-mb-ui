import 'package:flutter/material.dart';

import 'game_event.dart';

/// Fallback used on platforms that are neither dart:io nor dart:html. Games are
/// only hostable in a WebView (mobile) or an iframe (web), so anywhere else we
/// render a clear placeholder rather than fail to compile.
class GameHostView extends StatelessWidget {
  final String bundleUrl;
  final String payloadJson;
  final GameEventCallback onEvent;

  const GameHostView({
    super.key,
    required this.bundleUrl,
    required this.payloadJson,
    required this.onEvent,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Games are not supported on this platform.'),
    );
  }
}
