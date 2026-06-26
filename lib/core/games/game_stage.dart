import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/games/data/game_score_scope.dart';
import '../../features/games/data/game_session_repository.dart';
import '../../features/learning/data/models/learning_models.dart';
import '../network/api_client.dart';
import 'learning_game.dart';

/// Drives a single, full-screen game that can be **closed (paused) and
/// resumed** without losing progress.
///
/// The game is kept mounted-but-hidden when closed (so its state survives) and
/// its animation loop is frozen via [TickerMode]. Reopening the same game +
/// study set simply shows it again; the game is only rebuilt fresh after it is
/// *finished* (lost / completed — the game calls [markFinished]) or replaced by
/// a different game.
class GameStageController extends ChangeNotifier {
  GameStageController._();
  static final GameStageController instance = GameStageController._();

  Widget? _game;
  String _key = '';
  String _title = '';
  bool _visible = false;
  bool _finished = false;
  int _lastScore = 0;

  // Server play-session tracking (best-effort).
  String? _sessionId;
  GameSessionRepository? _repo;

  Widget? get game => _game;
  String get sessionKey => _key;
  String get title => _title;
  bool get visible => _visible;

  /// True if a game with [key] is currently in progress (not finished), so it
  /// can be resumed instead of restarted.
  bool isLive(String key) => _game != null && _key == key && !_finished;

  /// Games report their latest score here (via [GameScoreScope]).
  void reportScore(int score) => _lastScore = score;

  /// A game calls this when the run is over (lost or completed) so the next
  /// open starts a fresh game instead of resuming the end screen.
  void markFinished() {
    if (_game == null) return;
    _finished = true;
    _completeSession();
  }

  /// Show the held game again (resume).
  void resume() {
    if (_game == null) return;
    _visible = true;
    notifyListeners();
  }

  /// Hide the game (pause). It stays mounted so it can be resumed.
  void close() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  /// Start a brand-new game, replacing (and recording) any current one.
  void launch({
    required String key,
    required String title,
    required Widget game,
    GameSessionRepository? repo,
    String? gameKey,
    String? studySetId,
  }) {
    _completeSession();
    _key = key;
    _title = title;
    _game = game;
    _finished = false;
    _visible = true;
    _lastScore = 0;
    _sessionId = null;
    _repo = repo;
    if (repo != null && gameKey != null) {
      repo.start(gameKey: gameKey, studySetId: studySetId).then((id) {
        _sessionId = id;
      });
    }
    notifyListeners();
  }

  void _completeSession() {
    final id = _sessionId;
    final repo = _repo;
    if (id != null && repo != null) {
      repo.complete(id, score: _lastScore);
    }
    _sessionId = null;
  }
}

/// Launches [game] full-screen for [material], or resumes it if a run is
/// already in progress. Call this instead of pushing a game route.
void launchGameFullscreen(
  BuildContext context, {
  required LearningGame game,
  required LearningMaterial material,
}) {
  final c = GameStageController.instance;
  final key = '${game.id}::${material.id}';
  if (c.isLive(key)) {
    c.resume();
    return;
  }
  final repo = GameSessionRepository(context.read<ApiClient>());
  final widget = GameScoreScope(
    onScore: c.reportScore,
    child: game.build(context, material),
  );
  c.launch(
    key: key,
    title: game.name,
    game: widget,
    repo: repo,
    gameKey: game.id,
    studySetId: material.id,
  );
}

/// Lets a running game reach the stage controller (e.g. to call
/// [GameStageController.markFinished] when the run ends).
class GameStageScope extends InheritedWidget {
  final GameStageController controller;
  const GameStageScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// Non-dependency lookup — safe to call from tick/build callbacks.
  static GameStageController? maybeOf(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<GameStageScope>();
    return (element?.widget as GameStageScope?)?.controller;
  }

  @override
  bool updateShouldNotify(GameStageScope oldWidget) => false;
}

/// Persistent host placed above the router (via `MaterialApp.builder`). Renders
/// the app and, when a game is active, the full-screen game on top of it —
/// kept mounted-but-paused while hidden.
class GameStage extends StatefulWidget {
  final Widget child;
  const GameStage({super.key, required this.child});

  @override
  State<GameStage> createState() => _GameStageState();
}

class _GameStageState extends State<GameStage> {
  GameStageController get _c => GameStageController.instance;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    // Go immersive while a game is on screen; restore normal bars otherwise.
    SystemChrome.setEnabledSystemUIMode(
      _c.game != null && _c.visible
          ? SystemUiMode.immersiveSticky
          : SystemUiMode.edgeToEdge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _c.game;
    return Stack(
      children: [
        widget.child,
        if (game != null)
          Positioned.fill(
            child: Offstage(
              offstage: !_c.visible,
              child: TickerMode(
                enabled: _c.visible,
                child: KeyedSubtree(
                  key: ValueKey(_c.sessionKey),
                  child: _GameLayer(controller: _c),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GameLayer extends StatelessWidget {
  final GameStageController controller;
  const _GameLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    // A nested Navigator gives the game its own routing context so in-game
    // dialogs (the quiz pop-up) work, and lets us intercept the system back
    // button to "close" (pause) rather than navigate the app underneath.
    return GameStageScope(
      controller: controller,
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) controller.close();
            },
            child: _FullscreenGame(
              title: controller.title,
              onClose: controller.close,
              child: controller.game!,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenGame extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;
  const _FullscreenGame({
    required this.title,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Slim top bar with the close (X) button — the only chrome over an
            // otherwise full-screen game.
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  _CloseButton(onTap: onClose),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
            Expanded(child: ClipRect(child: child)),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
