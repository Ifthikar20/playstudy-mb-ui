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
  final String slug; // 'flappy' | 'shooter'
  final String title;
  final List<QuizQuestion> quiz;

  const WebGameView({
    super.key,
    required this.slug,
    required this.title,
    required this.quiz,
  });

  @override
  State<WebGameView> createState() => _WebGameViewState();
}

class _WebGameViewState extends State<WebGameView> {
  late final WebViewController _controller;
  bool _loading = true;

  String get _url =>
      '${AppConfig.instance.gamesBaseUrl}/games/${widget.slug}/index.html';

  String get _quizJson => jsonEncode({
        'quiz': widget.quiz
            .map((q) => {
                  'prompt': q.prompt,
                  'choices': q.choices,
                  'correctIndex': q.correctIndex,
                })
            .toList(),
      });

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
            _injectQuiz();
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_url));
  }

  void _injectQuiz() {
    // The game defines window.PlayStudyInit; safe to call once loaded.
    _controller.runJavaScript(
      'if(window.PlayStudyInit){window.PlayStudyInit($_quizJson);}',
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
        _injectQuiz(); // re-inject once the game signals it's initialized
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
