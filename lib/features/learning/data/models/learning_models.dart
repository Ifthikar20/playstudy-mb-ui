import 'package:equatable/equatable.dart';

enum QuizDifficulty {
  easy,
  medium,
  hard;

  static QuizDifficulty fromString(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'easy':
        return QuizDifficulty.easy;
      case 'hard':
        return QuizDifficulty.hard;
      default:
        return QuizDifficulty.medium;
    }
  }

  String get label => switch (this) {
        QuizDifficulty.easy => 'Easy',
        QuizDifficulty.medium => 'Medium',
        QuizDifficulty.hard => 'Hard',
      };
}

class QuizQuestion extends Equatable {
  final String id;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String? explanation;
  final String topic;
  final QuizDifficulty difficulty;

  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    this.explanation,
    this.topic = 'General',
    this.difficulty = QuizDifficulty.medium,
  });

  @override
  List<Object?> get props =>
      [id, prompt, choices, correctIndex, explanation, topic, difficulty];

  static QuizQuestion fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: (j['id'] ?? '').toString(),
        prompt: j['prompt'] as String? ?? '',
        choices: (j['choices'] as List? ?? const []).cast<String>(),
        correctIndex: j['correctIndex'] as int? ?? 0,
        explanation: j['explanation'] as String?,
        topic: j['topic'] as String? ?? 'General',
        difficulty: QuizDifficulty.fromString(j['difficulty'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'choices': choices,
        'correctIndex': correctIndex,
        'explanation': explanation,
        'topic': topic,
        'difficulty': difficulty.name,
      };
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

  Map<String, dynamic> toJson() => {'word': word, 'clue': clue};
}

/// Source of the uploaded content.
enum SourceKind { link, file, text }

/// Instant, no-AI preview of the source, computed server-side from the
/// extracted text and shown within seconds while the full study set generates.
/// Mirrors the backend `preview` JSON.
class StudyPreview extends Equatable {
  final int wordCount;
  final int readingMinutes;
  final List<String> outline;
  final List<String> keyTerms;
  final List<String> summary;

  const StudyPreview({
    this.wordCount = 0,
    this.readingMinutes = 0,
    this.outline = const [],
    this.keyTerms = const [],
    this.summary = const [],
  });

  bool get isEmpty =>
      outline.isEmpty &&
      keyTerms.isEmpty &&
      summary.isEmpty &&
      wordCount == 0;

  @override
  List<Object?> get props =>
      [wordCount, readingMinutes, outline, keyTerms, summary];

  static StudyPreview fromJson(Map<String, dynamic> j) => StudyPreview(
        wordCount: j['wordCount'] as int? ?? 0,
        readingMinutes: j['readingMinutes'] as int? ?? 0,
        outline: (j['outline'] as List? ?? const []).cast<String>(),
        keyTerms: (j['keyTerms'] as List? ?? const []).cast<String>(),
        summary: (j['summary'] as List? ?? const []).cast<String>(),
      );
}

/// A progress tick emitted while a study set is generating: how far along the
/// batches are, plus the instant [preview] once the backend has computed it.
class GenerationUpdate extends Equatable {
  /// pending | processing | partial | ready | failed
  final String status;

  /// Fraction of batches complete, 0..1.
  final double progress;

  /// Null until the backend has extracted the text and built the preview.
  final StudyPreview? preview;

  /// Titles of the real AI sections generated so far — grows as batches land.
  final List<String> sectionTitles;

  const GenerationUpdate({
    required this.status,
    this.progress = 0,
    this.preview,
    this.sectionTitles = const [],
  });

  @override
  List<Object?> get props => [status, progress, preview, sectionTitles];
}

/// One readable chunk of the study material: condensed content, a real-world
/// example, and its own quiz (count scales with the section's complexity).
class StudySection extends Equatable {
  final String title;
  final String content;
  final String example;
  final List<String> keyTerms; // terms to highlight in [content]
  final List<QuizQuestion> quiz;

  const StudySection({
    required this.title,
    required this.content,
    required this.example,
    this.keyTerms = const [],
    required this.quiz,
  });

  @override
  List<Object?> get props => [title, content, example, keyTerms, quiz];

  static StudySection fromJson(Map<String, dynamic> j) => StudySection(
        title: j['title'] as String? ?? 'Section',
        content: j['content'] as String? ?? '',
        example: j['example'] as String? ?? '',
        keyTerms: (j['keyTerms'] as List? ?? const []).cast<String>(),
        quiz: (j['quiz'] as List? ?? const [])
            .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'example': example,
        'keyTerms': keyTerms,
        'quiz': quiz.map((q) => q.toJson()).toList(),
      };
}

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
  final List<StudySection> sections;
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
    required this.sections,
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
      [id, title, sourceKind, sourceRef, summary, keyPoints, quiz, wordGame, topics, sections, createdAt];

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
        sections: (j['sections'] as List? ?? const [])
            .map((e) => StudySection.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  /// Round-trips with [fromJson] for local (offline) persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sourceKind': sourceKind.name,
        'sourceRef': sourceRef,
        'summary': summary,
        'keyPoints': keyPoints,
        'quiz': quiz.map((q) => q.toJson()).toList(),
        'wordGame': wordGame.map((w) => w.toJson()).toList(),
        'topics': topics,
        'sections': sections.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}
