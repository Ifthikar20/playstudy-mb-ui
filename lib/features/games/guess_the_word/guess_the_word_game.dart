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
  String get emoji => '🔤';

  @override
  IconData get icon => Icons.spellcheck_outlined;

  @override
  String get description => 'Guess hidden vocabulary from clues. 6 lives per round.';

  @override
  bool canPlay(LearningMaterial material) => material.wordGame.isNotEmpty;

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return GuessWordWidget(challenges: material.wordGame);
  }
}
