import 'package:equatable/equatable.dart';

enum GameType { quiz, flashcards, matching, fillInBlank }

extension GameTypeX on GameType {
  String get label {
    switch (this) {
      case GameType.quiz:
        return 'Quiz';
      case GameType.flashcards:
        return 'Flashcards';
      case GameType.matching:
        return 'Matching';
      case GameType.fillInBlank:
        return 'Fill in the Blank';
    }
  }

  String get emoji {
    switch (this) {
      case GameType.quiz:
        return '🎯';
      case GameType.flashcards:
        return '🃏';
      case GameType.matching:
        return '🧩';
      case GameType.fillInBlank:
        return '✏️';
    }
  }
}

/// A single question in a generated game.
class GameQuestion extends Equatable {
  final String id;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String? explanation;

  const GameQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    this.explanation,
  });

  @override
  List<Object?> get props => [id, prompt, choices, correctIndex, explanation];
}

/// A flashcard: front/back pair.
class Flashcard extends Equatable {
  final String id;
  final String front;
  final String back;

  const Flashcard({required this.id, required this.front, required this.back});

  @override
  List<Object?> get props => [id, front, back];
}

/// A game generated from a study note image.
class Game extends Equatable {
  final String id;
  final String title;
  final String subject;
  final GameType type;
  final DateTime createdAt;
  final String? sourceImagePath;
  final List<GameQuestion> questions;
  final List<Flashcard> flashcards;

  const Game({
    required this.id,
    required this.title,
    required this.subject,
    required this.type,
    required this.createdAt,
    this.sourceImagePath,
    this.questions = const [],
    this.flashcards = const [],
  });

  @override
  List<Object?> get props =>
      [id, title, subject, type, createdAt, sourceImagePath, questions, flashcards];
}
