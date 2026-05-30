import 'package:flutter/material.dart';
import '../../features/learning/data/models/learning_models.dart';

/// Contract every PlayStudy game implements.
///
/// To add a new game:
///   1. Create a class that extends [LearningGame].
///   2. Implement [id], [name], [icon] (or [emoji]), [description], [build].
///   3. Optionally override [coverColors], [difficulty], [questionCount],
///      and [canPlay] to gate on what the material contains.
///   4. Register it once at app startup:
///        GameRegistry.instance.register(MyAwesomeGame());
///
/// The widget you return from [build] gets the full [LearningMaterial], so
/// it can pull whatever fields it needs (quiz, wordGame, summary, etc.) and
/// is free to use Flame, plain Flutter, or anything else.
abstract class LearningGame {
  /// Stable identifier — used for routing, analytics, save-state keys.
  String get id;

  /// Short human-readable name shown on the game card.
  String get name;

  /// Emoji shown on the game card. Use [icon] instead if you prefer.
  String get emoji => '🎮';

  /// Optional Material icon (takes precedence over [emoji] if non-null).
  IconData? get icon => null;

  /// One-line description shown under the title.
  String get description;

  /// Two-stop gradient used as the cover art behind the game's icon when
  /// no [coverImage] is provided. Defaults to a soft indigo wash so a new
  /// game still looks polished out of the box.
  List<Color> get coverColors => const [Color(0xFF9D8DFA), Color(0xFF6B5CE7)];

  /// Optional asset image path (e.g. 'assets/games/flappy.png'). When set,
  /// the UI shows it as the tile's cover instead of [coverColors] + icon.
  String? get coverImage => null;

  /// How hard the game is, label used on the cover badge.
  GameDifficulty get difficulty => GameDifficulty.medium;

  /// How many "questions" (quiz items, words, rounds) the game will use
  /// for the given material. Shown on the cover so the user knows what
  /// they're getting into. Default returns the quiz count.
  int questionCount(LearningMaterial material) => material.quiz.length;

  /// Whether this game can be played for the given material.
  /// Default: true. Override to require specific content.
  bool canPlay(LearningMaterial material) => true;

  /// Build the playable widget. Receives the full material so the game can
  /// read whichever fields it needs.
  Widget build(BuildContext context, LearningMaterial material);
}

enum GameDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        GameDifficulty.easy => 'Easy',
        GameDifficulty.medium => 'Medium',
        GameDifficulty.hard => 'Hard',
      };
}
