import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/app_config.dart';
import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';
import '../data/game_score_scope.dart';
import '../host/game_host_view.dart';

/// Hosts an S3-hosted HTML5 game and bridges it to the app. The embedding is
/// delegated to [GameHostView] — a WebView on iOS, an <iframe> on web — so the
/// same bundle runs on every platform with no game logic in the app.
///
/// App-side concerns only: build the init payload from the study set, forward
/// gameplay rewards, and report the game's score up through [GameScoreScope] so
/// the launch page records it on the play session (one tracking path for both
/// native and web games — scores then sync across platforms).
class WebGameView extends StatefulWidget {
  final String slug; // CDN path segment: {gamesBaseUrl}/games/<slug>/
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
  // instant the game loads — no dependency on the bridge round-trip timing.
  String get _bundleUrl {
    final params = <String>[];
    if (_quizList.isNotEmpty) params.add('quiz=${_b64(_quizList)}');
    if (_wordList.isNotEmpty) params.add('words=${_b64(_wordList)}');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return '${AppConfig.instance.gamesBaseUrl}/games/${widget.slug}/index.html$query';
  }

  String get _payloadJson =>
      jsonEncode({'quiz': _quizList, 'words': _wordList});

  void _onEvent(GameEvent event) {
    switch (event.type) {
      case 'score':
      case 'gameover':
        if (event.score != null) GameScoreScope.report(context, event.score!);
        break;
      case 'reward':
        // Server recomputes + caps points; the fallback amount is only used
        // offline. Only recognized gameplay reasons are accepted by the backend.
        final reason = event.reason ?? 'Super Dash checkpoint';
        context
            .read<RewardsBloc>()
            .add(RecordActivity(points: 5, reason: reason));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: Colors.black,
      body: GameHostView(
        bundleUrl: _bundleUrl,
        payloadJson: _payloadJson,
        onEvent: _onEvent,
      ),
    );
  }
}
