import 'package:flutter/material.dart';

import '../../../core/games/learning_game.dart';
import '../../learning/data/models/learning_models.dart';
import 'web_game_view.dart';

/// Flappy-Bird-style arcade game, hosted on the web and embedded via WebView.
/// A correct answer to a study-set question revives the player.
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
  Widget build(BuildContext context, LearningMaterial material) {
    return WebGameView(
      slug: 'flappy',
      title: 'Flappy Quiz',
      quiz: material.quiz,
    );
  }
}

/// Space-shooter arcade game, hosted on the web and embedded via WebView.
class SpaceShooterWebGame extends LearningGame {
  @override
  String get id => 'space_shooter_web';

  @override
  String get name => 'Space Shooter';

  @override
  IconData get icon => Icons.rocket_launch;

  @override
  String get description =>
      'Blast waves of invaders — answer a question to get back in the fight.';

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return WebGameView(
      slug: 'shooter',
      title: 'Space Shooter',
      quiz: material.quiz,
    );
  }
}

/// Crossword built from the study set's word game (word + clue), hosted on the
/// web and embedded via WebView. Clues are listed as Across/Down hints.
class CrosswordWebGame extends LearningGame {
  @override
  String get id => 'crossword_web';

  @override
  String get name => 'Crossword';

  @override
  IconData get icon => Icons.grid_on;

  @override
  String get description =>
      'Fill the grid from the clues built on this set\'s key terms.';

  @override
  bool canPlay(LearningMaterial material) => material.wordGame.length >= 2;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return WebGameView(
      slug: 'crossword',
      title: 'Crossword',
      words: material.wordGame,
    );
  }
}

/// Space Hunter — arcade shooter; clear waves + bosses, then answer the study
/// set's questions to advance levels. Hosted on the web, embedded via WebView.
class SpaceHunterWebGame extends LearningGame {
  @override
  String get id => 'space_hunter_web';

  @override
  String get name => 'Space Hunter';

  @override
  IconData get icon => Icons.rocket;

  @override
  String get description =>
      'Blast waves and bosses, then answer questions to reach the next level.';

  @override
  bool canPlay(LearningMaterial material) => material.quiz.isNotEmpty;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return WebGameView(
      slug: 'space-hunter',
      title: 'Space Hunter',
      quiz: material.quiz,
    );
  }
}
