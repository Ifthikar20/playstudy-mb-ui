import '../../features/learning/data/models/learning_models.dart';
import 'learning_game.dart';

/// Plug-and-play registry of [LearningGame]s.
///
/// Register games once at app startup (see `main.dart`). The material page
/// asks the registry for whatever games are playable for a given material —
/// it doesn't know about specific games, so adding a new one never requires
/// touching the UI layer.
class GameRegistry {
  GameRegistry._();
  static final GameRegistry instance = GameRegistry._();

  final List<LearningGame> _games = [];

  /// All registered games, in registration order.
  List<LearningGame> get all => List.unmodifiable(_games);

  /// Games whose [LearningGame.canPlay] returns true for [material].
  List<LearningGame> availableFor(LearningMaterial material) =>
      _games.where((g) => g.canPlay(material)).toList(growable: false);

  /// Look up a game by [LearningGame.id].
  LearningGame? byId(String id) {
    for (final g in _games) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Register a game. Calling twice with the same id replaces the first.
  void register(LearningGame game) {
    _games.removeWhere((g) => g.id == game.id);
    _games.add(game);
  }

  /// Remove a game by [LearningGame.id]. Used by the server kill-switch to
  /// pull a game — including a built-in/native one — at startup. No-op if no
  /// game with that id is registered.
  void unregister(String id) => _games.removeWhere((g) => g.id == id);

  /// Clear all games. Useful in tests.
  void clear() => _games.clear();
}
