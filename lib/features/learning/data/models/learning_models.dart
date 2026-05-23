import 'package:equatable/equatable.dart';

class QuizQuestion extends Equatable {
  final String id;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String? explanation;
  final String topic;

  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    this.explanation,
    this.topic = 'General',
  });

  @override
  List<Object?> get props =>
      [id, prompt, choices, correctIndex, explanation, topic];
}

/// A single round of Guess the Word.
class WordChallenge extends Equatable {
  final String word;
  final String clue;

  const WordChallenge({required this.word, required this.clue});

  @override
  List<Object?> get props => [word, clue];
}

/// Source of the uploaded content.
enum SourceKind { link, file, text }

/// Generated learning bundle from a piece of content.
class LearningMaterial extends Equatable {
  final String id;
  final String title;
  final SourceKind sourceKind;
  final String sourceRef; // url, file path, or "Pasted text"
  final String summary;
  final List<String> keyPoints;
  final List<QuizQuestion> quiz;
  final List<WordChallenge> wordGame;
  final List<String> topics;
  final DateTime createdAt;

  const LearningMaterial({
    required this.id,
    required this.title,
    required this.sourceKind,
    required this.sourceRef,
    required this.summary,
    required this.keyPoints,
    required this.quiz,
    required this.wordGame,
    required this.topics,
    required this.createdAt,
  });

  /// Quiz questions filtered to the given topics (or all if empty).
  List<QuizQuestion> quizForTopics(List<String> filter) {
    if (filter.isEmpty) return quiz;
    final set = filter.toSet();
    return quiz.where((q) => set.contains(q.topic)).toList();
  }

  @override
  List<Object?> get props =>
      [id, title, sourceKind, sourceRef, summary, keyPoints, quiz, wordGame, topics, createdAt];
}
