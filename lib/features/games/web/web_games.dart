import 'package:flutter/material.dart';

import '../../../core/games/learning_game.dart';
import '../../learning/data/models/learning_models.dart';
import '../native/crossword_native_widget.dart';
import '../native/flappy_native_widget.dart';
import '../native/shooter_native_widget.dart';

/// These were originally WebView-hosted games. They are now native Flutter
/// implementations (no hosted server, no WebView) so they work offline and on
/// every device. The class names are unchanged so registration in main.dart
/// stays the same.

class FlappyWebGame extends LearningGame {
  @override
  String get id => 'flappy_web';

  @override
  String get name => 'Flappy Quiz';

  @override
  IconData get icon => Icons.flutter_dash;

  @override
  String get description =>
      'Tap to fly through the gaps — answer a question to revive.';

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
    return FlappyNativeWidget(quiz: material.quiz);
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
      'Blast waves of invaders — answer a question to launch the next wave.';

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
    return ShooterNativeWidget(quiz: material.quiz);
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

/// Space Hunter is a tougher variant of the space shooter (more waves, faster
/// fire). Reuses the native shooter so it works offline like the rest.
class SpaceHunterWebGame extends LearningGame {
  @override
  String get id => 'space_hunter_web';

  @override
  String get name => 'Space Hunter';

  @override
  IconData get icon => Icons.rocket_rounded;

  @override
  String get description =>
      'Survive relentless waves — answer questions to reach the next level.';

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
    return ShooterNativeWidget(quiz: material.quiz);
  }
}
