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
