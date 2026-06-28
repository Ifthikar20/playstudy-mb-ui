import 'package:flutter/material.dart';

import '../../../core/games/learning_game.dart';
import '../../learning/data/models/learning_models.dart';
import '../native/crossword_native_widget.dart';
import 'web_game_view.dart';

/// WebView-hosted games. Each renders the shared HTML5 canvas bundle from
/// games_host (`/games/<slug>/<version>/index.html`) through [WebGameView] —
/// the exact same bundle the web app embeds in an <iframe>. One implementation
/// per game, identical graphics and behaviour on web and mobile; no game logic
/// is duplicated in Dart. Bundles are cached on disk for offline play.
///
/// Crossword stays native for now (no HTML bundle exists yet). The class names
/// are unchanged so registration in main.dart stays the same.

class FlappyWebGame extends LearningGame {
  @override
  String get id => 'flappy_web';

  @override
  String get name => 'Flappy Pip';

  @override
  IconData get icon => Icons.flutter_dash;

  @override
  String get description =>
      'Ride Pip the pup on a flappy bird through swaying pipes and changing '
      'skies — grab bones, dodge bees, answer to revive.';

  @override
  List<Color> get coverColors =>
      const [Color(0xFFFBC78A), Color(0xFFEF4444)];

  @override
  GameDifficulty get difficulty => GameDifficulty.medium;

  @override
  int questionCount(LearningMaterial m) => m.quiz.length;

  @override
  bool canPlay(LearningMaterial material) => material.quiz.isNotEmpty;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return WebGameView(
      slug: 'flappy',
      title: name,
      gameKey: id,
      quiz: material.quiz,
    );
  }
}

class SpaceShooterWebGame extends LearningGame {
  @override
  String get id => 'space_shooter_web';

  @override
  String get name => 'Space Shooter';

  @override
  IconData get icon => Icons.rocket_launch_rounded;

  @override
  String get description =>
      'Pip pilots the hero ship against waves of invaders — grab power-ups and '
      'answer a question to launch the next wave.';

  @override
  List<Color> get coverColors =>
      const [Color(0xFF6B5CE7), Color(0xFF1F1B2E)];

  @override
  GameDifficulty get difficulty => GameDifficulty.hard;

  @override
  int questionCount(LearningMaterial m) => m.quiz.length;

  @override
  bool canPlay(LearningMaterial material) => material.quiz.isNotEmpty;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return WebGameView(
      slug: 'space-shooter',
      title: name,
      gameKey: id,
      quiz: material.quiz,
    );
  }
}

class CrosswordWebGame extends LearningGame {
  @override
  String get id => 'crossword_web';

  @override
  String get name => 'Crossword';

  @override
  IconData get icon => Icons.grid_on_rounded;

  @override
  String get description =>
      'Fill the grid from the clues built on this set\'s key terms.';

  @override
  List<Color> get coverColors =>
      const [Color(0xFFA8E6F0), Color(0xFF6B5CE7)];

  @override
  GameDifficulty get difficulty => GameDifficulty.medium;

  @override
  int questionCount(LearningMaterial m) => m.wordGame.length;

  @override
  bool canPlay(LearningMaterial material) => material.wordGame.length >= 2;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return CrosswordNativeWidget(words: material.wordGame);
  }
}

/// Space Hunter is a tougher variant of the space shooter (relentless waves,
/// faster fire, meaner bosses). Reuses the Space Shooter bundle turned up via
/// the `intensity` query param — one bundle, no duplicate game code.
class SpaceHunterWebGame extends LearningGame {
  @override
  String get id => 'space_hunter_web';

  @override
  String get name => 'Space Hunter';

  @override
  IconData get icon => Icons.rocket_rounded;

  @override
  String get description =>
      'Pip vs relentless waves and bosses — faster, fiercer, and gated on '
      'tougher questions.';

  @override
  List<Color> get coverColors =>
      const [Color(0xFFC4C0F5), Color(0xFF1F1B2E)];

  @override
  GameDifficulty get difficulty => GameDifficulty.hard;

  @override
  int questionCount(LearningMaterial m) => m.quiz.length;

  @override
  bool canPlay(LearningMaterial material) => material.quiz.isNotEmpty;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    // Same bundle as Space Shooter, turned up via the intensity param.
    return WebGameView(
      slug: 'space-shooter',
      title: name,
      gameKey: id,
      quiz: material.quiz,
      extraParams: const {'intensity': '1.4'},
    );
  }
}
