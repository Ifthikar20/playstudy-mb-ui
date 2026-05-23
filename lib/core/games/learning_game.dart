import 'package:flutter/material.dart';
import '../../features/learning/data/models/learning_models.dart';

/// Contract every PlayStudy game implements.
///
/// To add a new game:
///   1. Create a class that extends [LearningGame].
///   2. Implement [id], [name], [emoji] (or [icon]), [description], [build].
///   3. Optionally override [canPlay] to gate on what the material contains
///      (e.g. flashcards-required, min question count, etc.).
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

  /// Whether this game can be played for the given material.
  /// Default: true. Override to require specific content.
  bool canPlay(LearningMaterial material) => true;

  /// Build the playable widget. Receives the full material so the game can
  /// read whichever fields it needs.
  Widget build(BuildContext context, LearningMaterial material);
}
