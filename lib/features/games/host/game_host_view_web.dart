// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'game_event.dart';

/// Web host: embeds the game bundle in a sandboxed <iframe> and bridges it via
/// `window.postMessage`. Security posture (the game is remote code from S3):
///   • sandbox = allow-scripts only — no same-origin, no top navigation, so a
///     game can't read the host app's storage or navigate it away.
///   • postMessage is pinned to the bundle's exact origin (never '*').
///   • inbound messages are accepted only from this iframe's window AND origin.
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
  late final String _origin;
  late final html.IFrameElement _iframe;
  html.EventListener? _messageListener;

  @override
  void initState() {
    super.initState();
    _origin = _originOf(widget.bundleUrl);
    _viewType = 'playstudy-game-${identityHashCode(this)}';
    _iframe = html.IFrameElement()
      ..src = widget.bundleUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      // Remote, untrusted code: run scripts, but no same-origin trust and no
      // ability to navigate the top window.
      ..setAttribute('sandbox', 'allow-scripts allow-pointer-lock')
      ..allow = 'autoplay; fullscreen; gamepad';

    _iframe.onLoad.listen((_) {
      _injectPayload();
      widget.onEvent(const GameEvent('loaded'));
    });
    _iframe.onError.listen((_) {
      widget.onEvent(const GameEvent('load_failed', {'message': 'iframe error'}));
    });

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _iframe);

    _messageListener = (event) => _onMessage(event);
    html.window.addEventListener('message', _messageListener);
  }

  void _onMessage(html.Event event) {
    if (event is! html.MessageEvent) return;
    // Accept only messages from our own iframe AND the expected origin.
    if (event.source != _iframe.contentWindow) return;
    if (_origin != '*' && event.origin != _origin) return;
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
    // Pinned target origin — the payload is never broadcast to '*'.
    _iframe.contentWindow?.postMessage(
      '{"type":"init","payload":${widget.payloadJson}}',
      _origin,
    );
  }

  static String _originOf(String url) {
    try {
      final u = Uri.parse(url);
      if (u.hasScheme && u.host.isNotEmpty) return u.origin;
    } catch (_) {}
    return '*'; // fallback (e.g. relative URL in local testing)
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
