import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';

/// Hosts an externally-hosted HTML5 game in a WebView and bridges it to the
/// app: it injects the study set's quiz into the game and listens for the
/// game's events (`reward`, `score`, `gameover`) over the "PlayStudy" channel.
///
/// Keeping the game code on the web means it can be updated without shipping
/// an app release, and the same build runs on iOS, Android, and web.
class WebGameView extends StatefulWidget {
  final String slug; // 'flappy' | 'shooter' | 'crossword'
  final String title;
  final List<QuizQuestion> quiz;
  final List<WordChallenge> words;

  const WebGameView({
    super.key,
    required this.slug,
    required this.title,
    this.quiz = const [],
    this.words = const [],
  });

  @override
  State<WebGameView> createState() => _WebGameViewState();
}

class _WebGameViewState extends State<WebGameView> {
  late final WebViewController _controller;
  bool _loading = true;

  List<Map<String, dynamic>> get _quizList => widget.quiz
      .map((q) => {
            'prompt': q.prompt,
            'choices': q.choices,
            'correctIndex': q.correctIndex,
            'explanation': q.explanation ?? '',
            'topic': q.topic,
          })
      .toList();

  List<Map<String, dynamic>> get _wordList =>
      widget.words.map((w) => {'word': w.word, 'clue': w.clue}).toList();

  String _b64(Object data) => base64Url.encode(utf8.encode(jsonEncode(data)));

  // Pass quiz + words in the URL (base64url JSON) so they're available the
  // instant the game loads — no dependency on the JS-channel round-trip timing.
  String get _url {
    final params = <String>[];
    if (_quizList.isNotEmpty) params.add('quiz=${_b64(_quizList)}');
    if (_wordList.isNotEmpty) params.add('words=${_b64(_wordList)}');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return '${AppConfig.instance.gamesBaseUrl}/games/${widget.slug}/index.html$query';
  }

  String get _payloadJson =>
      jsonEncode({'quiz': _quizList, 'words': _wordList});

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
      ..loadRequest(Uri.parse(_url));
  }

  void _injectPayload() {
    // The game defines window.PlayStudyInit; safe to call once loaded.
    _controller.runJavaScript(
      'if(window.PlayStudyInit){window.PlayStudyInit($_payloadJson);}',
    );
  }

  void _onMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (data['type']) {
      case 'ready':
        _injectPayload(); // re-inject once the game signals it's initialized
        break;
      case 'reward':
        final reason = data['reason'] as String? ?? 'Super Dash checkpoint';
        // Server recomputes + caps points; the fallback amount is only used
        // offline. Only gameplay reasons are accepted by the backend.
        context.read<RewardsBloc>().add(
              RecordActivity(points: 5, reason: reason),
            );
        break;
      // 'score' / 'gameover' are handled inside the game UI; no-op here.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
