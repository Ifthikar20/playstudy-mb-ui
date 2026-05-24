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

  static QuizQuestion fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: (j['id'] ?? '').toString(),
        prompt: j['prompt'] as String? ?? '',
        choices: (j['choices'] as List? ?? const []).cast<String>(),
        correctIndex: j['correctIndex'] as int? ?? 0,
        explanation: j['explanation'] as String?,
        topic: j['topic'] as String? ?? 'General',
      );
}

/// A single round of Guess the Word.
class WordChallenge extends Equatable {
  final String word;
  final String clue;

  const WordChallenge({required this.word, required this.clue});

  @override
  List<Object?> get props => [word, clue];

  static WordChallenge fromJson(Map<String, dynamic> j) => WordChallenge(
        word: j['word'] as String? ?? '',
        clue: j['clue'] as String? ?? '',
      );
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

  static SourceKind _kindFrom(String? raw) {
    switch (raw) {
      case 'link':
        return SourceKind.link;
      case 'file':
        return SourceKind.file;
      default:
        return SourceKind.text;
    }
  }

  /// Parses the API shape. `quiz`/`wordGame` are absent on lightweight library
  /// rows and default to empty until the detail endpoint is fetched.
  static LearningMaterial fromJson(Map<String, dynamic> j) => LearningMaterial(
        id: (j['id'] ?? '').toString(),
        title: j['title'] as String? ?? '',
        sourceKind: _kindFrom(j['sourceKind'] as String?),
        sourceRef: j['sourceRef'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        keyPoints: (j['keyPoints'] as List? ?? const []).cast<String>(),
        quiz: (j['quiz'] as List? ?? const [])
            .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        wordGame: (j['wordGame'] as List? ?? const [])
            .map((e) => WordChallenge.fromJson(e as Map<String, dynamic>))
            .toList(),
        topics: (j['topics'] as List? ?? const []).cast<String>(),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
