import 'package:flutter/material.dart';
import '../../../core/games/learning_game.dart';
import '../../learning/data/models/learning_models.dart';
import 'guess_word_widget.dart';

/// Plug-and-play registration for Guess the Word.
/// Implements the [LearningGame] contract so the registry can list and
/// launch it without the UI layer knowing anything specific about it.
class GuessTheWordGame extends LearningGame {
  @override
  String get id => 'guess_the_word';

  @override
  String get name => 'Guess the Word';

  @override
  IconData get icon => Icons.spellcheck_rounded;

  @override
  String get description => 'Guess hidden vocabulary from clues. 6 lives per round.';

  @override
  List<Color> get coverColors => const [Color(0xFFD6F26C), Color(0xFF22C55E)];

  @override
  GameDifficulty get difficulty => GameDifficulty.easy;

  @override
  int questionCount(LearningMaterial m) => m.wordGame.length;

  @override
  bool canPlay(LearningMaterial material) => material.wordGame.isNotEmpty;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return GuessWordWidget(challenges: material.wordGame);
  }
}
