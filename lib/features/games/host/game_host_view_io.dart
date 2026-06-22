import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'game_event.dart';

/// Mobile/desktop host: loads the game bundle in a WebView and bridges it via
/// the `PlayStudy` JavaScript channel. The game receives its init payload both
/// in the URL (already encoded by the caller) and via `window.PlayStudyInit`,
/// and emits [GameEvent]s as JSON messages on the channel.
class GameHostView extends StatefulWidget {
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
  State<GameHostView> createState() => _GameHostViewState();
}

class _GameHostViewState extends State<GameHostView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('PlayStudy', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _injectPayload();
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.bundleUrl));
  }

  void _injectPayload() {
    _controller.runJavaScript(
      'if(window.PlayStudyInit){window.PlayStudyInit(${widget.payloadJson});}',
    );
  }

  void _onMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    // 'ready' means the game initialized — re-inject in case the page-finished
    // injection raced ahead of the game defining PlayStudyInit.
    if (data['type'] == 'ready') _injectPayload();
    widget.onEvent(GameEvent.fromJson(data));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
