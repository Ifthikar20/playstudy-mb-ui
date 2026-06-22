// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'game_event.dart';

/// Web host: embeds the game bundle in a sandboxed <iframe> and bridges it via
/// `window.postMessage`, mirroring the mobile WebView host so the same bundle
/// runs unchanged on web. The game receives its init payload in the URL and via
/// a posted `{type:'init', payload}` message, and emits [GameEvent]s by posting
/// JSON back to its parent.
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
  late final String _viewType;
  late final html.IFrameElement _iframe;
  html.EventListener? _messageListener;

  @override
  void initState() {
    super.initState();
    _viewType = 'playstudy-game-${identityHashCode(this)}';
    _iframe = html.IFrameElement()
      ..src = widget.bundleUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      // Sandbox remote game code: allow it to run scripts but not to navigate
      // the top window or claim same-origin trust with the host app.
      ..setAttribute('sandbox', 'allow-scripts allow-pointer-lock')
      ..allow = 'autoplay; fullscreen; gamepad';

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _iframe);

    _messageListener = (event) => _onMessage(event);
    html.window.addEventListener('message', _messageListener);
  }

  void _onMessage(html.Event event) {
    if (event is! html.MessageEvent) return;
    // Only accept messages from our own iframe's window.
    if (event.source != _iframe.contentWindow) return;
    Map<String, dynamic> data;
    try {
      final raw = event.data;
      data = (raw is String ? jsonDecode(raw) : raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (data['type'] == 'ready') _injectPayload();
    widget.onEvent(GameEvent.fromJson(data));
  }

  void _injectPayload() {
    _iframe.contentWindow?.postMessage(
      '{"type":"init","payload":${widget.payloadJson}}',
      '*',
    );
  }

  @override
  void dispose() {
    if (_messageListener != null) {
      html.window.removeEventListener('message', _messageListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
