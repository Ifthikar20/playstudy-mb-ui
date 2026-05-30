import 'package:flutter/material.dart';
import '../../../core/games/learning_game.dart';
import '../../learning/data/models/learning_models.dart';
import 'super_dash_widget.dart';

/// LearningGame adapter for Super Dash — registered in main.dart.
class SuperDashGame extends LearningGame {
  @override
  String get id => 'super_dash';

  @override
  String get name => 'Super Dash';

  @override
  String get emoji => '🏃';

  @override
  IconData get icon => Icons.directions_run;

  @override
  String get description =>
      'Endless runner — answer a quiz to pass each checkpoint.';

  @override
  List<Color> get coverColors =>
      const [Color(0xFF8FE3B6), Color(0xFF6B5CE7)];

  @override
  GameDifficulty get difficulty => GameDifficulty.medium;

  @override
  int questionCount(LearningMaterial m) => m.quiz.length;

  @override
  bool canPlay(LearningMaterial material) => material.quiz.isNotEmpty;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return SuperDashWidget(questions: material.quiz);
  }
}
