import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';
import '../data/game_score_scope.dart';
import '../data/game_session_repository.dart';
import '../cache/bundle_serving.dart';
import '../host/game_host_view.dart';

/// Hosts an S3-hosted HTML5 game and bridges it to the app. The embedding is
/// delegated to [GameHostView] — a WebView on iOS, an <iframe> on web — so the
/// same bundle runs on every platform with no game logic in the app.
///
/// App-side concerns only: build the init payload, forward gameplay rewards,
/// report the score up through [GameScoreScope] (one tracking path for native
/// and web games), and send load/error telemetry so a broken bundle is visible.
class WebGameView extends StatefulWidget {
  final String slug; // CDN path segment
  final String version; // immutable bundle version: /games/<slug>/<version>/
  final String gameKey; // stable id, for telemetry
  final String title;
  final List<QuizQuestion> quiz;
  final List<WordChallenge> words;

  /// Extra query params appended to the bundle URL (e.g. {'intensity': '1.4'}
  /// so Space Hunter reuses the Space Shooter bundle turned up). Lets variants
  /// share one bundle instead of duplicating it.
  final Map<String, String> extraParams;

  const WebGameView({
    super.key,
    required this.slug,
    required this.title,
    this.version = '1',
    this.gameKey = '',
    this.quiz = const [],
    this.words = const [],
    this.extraParams = const {},
  });

  @override
  State<WebGameView> createState() => _WebGameViewState();
}

class _WebGameViewState extends State<WebGameView> {
  GameSessionRepository? _telemetry;
  Future<String>? _baseFuture;

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
  // [base] is the local cache server (offline) or the online origin.
  String _bundleUrl(String base) {
    final params = <String>[];
    if (_quizList.isNotEmpty) params.add('quiz=${_b64(_quizList)}');
    if (_wordList.isNotEmpty) params.add('words=${_b64(_wordList)}');
    widget.extraParams.forEach((k, v) =>
        params.add('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}'));
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return '$base/games/${widget.slug}/${widget.version}/index.html$query';
  }

  String get _payloadJson =>
      jsonEncode({'quiz': _quizList, 'words': _wordList});

  @override
  void initState() {
    super.initState();
    if (widget.gameKey.isNotEmpty) {
      _telemetry = GameSessionRepository(context.read<ApiClient>());
    }
    // Resolve the bundle base once: a local cache server if the bundle is on
    // disk (offline-capable), otherwise the online origin.
    _baseFuture = BundleServing.resolveBase(
      slug: widget.slug,
      version: widget.version,
      onlineBase: AppConfig.instance.gamesBaseUrl,
    );
  }

  void _report(String kind, [String? message]) {
    _telemetry?.telemetry(
      gameKey: widget.gameKey,
      version: widget.version,
      kind: kind,
      message: message,
    );
  }

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
      case 'loaded':
        _report('loaded');
        break;
      case 'load_failed':
        _report('load_failed', event.message);
        break;
      case 'error':
        _report('error', event.message);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: Colors.black,
      body: FutureBuilder<String>(
        future: _baseFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return GameHostView(
            bundleUrl: _bundleUrl(snapshot.data!),
            payloadJson: _payloadJson,
            onEvent: _onEvent,
          );
        },
      ),
    );
  }
}
