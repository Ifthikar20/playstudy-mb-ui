import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/game_models.dart';

/// Repository for generating and storing games built from study notes.
/// Today this returns mocked content. Swap [generateFromImage] for a real
/// vision-model call (e.g. google_generative_ai) once the API is wired up.
class GameRepository {
  static final GameRepository _i = GameRepository._();
  factory GameRepository() => _i;
  GameRepository._();

  final List<Game> _library = [];
  final _uuid = const Uuid();

  List<Game> get library => List.unmodifiable(_library);

  /// Generate a game from a captured note image. For now this returns a
  /// mocked game so the UI flow is end-to-end runnable without a backend.
  Future<Game> generateFromImage({
    required String imagePath,
    required GameType type,
    String? subjectHint,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final id = _uuid.v4();
    final subject = subjectHint ?? _guessSubject();
    final title = '${subject} ${type.label}';

    final game = Game(
      id: id,
      title: title,
      subject: subject,
      type: type,
      createdAt: DateTime.now(),
      sourceImagePath: imagePath,
      questions: type == GameType.flashcards ? const [] : _mockQuestions(),
      flashcards: type == GameType.flashcards ? _mockFlashcards() : const [],
    );

    _library.insert(0, game);
    return game;
  }

  void delete(String id) => _library.removeWhere((g) => g.id == id);

  String _guessSubject() {
    const subjects = ['Biology', 'History', 'Math', 'Chemistry', 'Physics', 'Literature'];
    return subjects[Random().nextInt(subjects.length)];
  }

  List<GameQuestion> _mockQuestions() => [
        GameQuestion(
          id: _uuid.v4(),
          prompt: 'What is the powerhouse of the cell?',
          choices: const ['Nucleus', 'Mitochondria', 'Ribosome', 'Golgi apparatus'],
          correctIndex: 1,
          explanation: 'Mitochondria produce ATP, the cell\'s energy currency.',
        ),
        GameQuestion(
          id: _uuid.v4(),
          prompt: 'Which process converts light energy to chemical energy?',
          choices: const ['Respiration', 'Photosynthesis', 'Fermentation', 'Digestion'],
          correctIndex: 1,
        ),
        GameQuestion(
          id: _uuid.v4(),
          prompt: 'DNA is found primarily in which organelle?',
          choices: const ['Nucleus', 'Lysosome', 'Cytoplasm', 'Vacuole'],
          correctIndex: 0,
        ),
      ];

  List<Flashcard> _mockFlashcards() => [
        Flashcard(id: _uuid.v4(), front: 'Mitochondria', back: 'Powerhouse of the cell — produces ATP'),
        Flashcard(id: _uuid.v4(), front: 'Photosynthesis', back: 'Light energy → chemical energy in plants'),
        Flashcard(id: _uuid.v4(), front: 'Nucleus', back: 'Contains DNA, controls cell activity'),
      ];
}
