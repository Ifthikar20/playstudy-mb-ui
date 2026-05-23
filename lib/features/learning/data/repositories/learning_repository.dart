import 'package:uuid/uuid.dart';
import '../models/learning_models.dart';

/// Generates learning materials (summary + quiz + word game) from a piece of
/// content. Currently returns mocked content so the UI flow is runnable
/// before the AI backend is wired up.
class LearningRepository {
  static final LearningRepository _i = LearningRepository._();
  factory LearningRepository() => _i;
  LearningRepository._();

  final List<LearningMaterial> _library = [];
  final _uuid = const Uuid();

  List<LearningMaterial> get library => List.unmodifiable(_library);

  LearningMaterial? byId(String id) {
    for (final m in _library) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<LearningMaterial> generate({
    required SourceKind sourceKind,
    required String sourceRef,
    String? titleHint,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1400));

    final material = LearningMaterial(
      id: _uuid.v4(),
      title: titleHint?.trim().isNotEmpty == true
          ? titleHint!.trim()
          : _titleFor(sourceKind, sourceRef),
      sourceKind: sourceKind,
      sourceRef: sourceRef,
      summary: _mockSummary,
      keyPoints: _mockKeyPoints,
      quiz: _mockQuiz(),
      wordGame: _mockWordGame,
      createdAt: DateTime.now(),
    );

    _library.insert(0, material);
    return material;
  }

  void delete(String id) => _library.removeWhere((m) => m.id == id);

  String _titleFor(SourceKind kind, String ref) {
    switch (kind) {
      case SourceKind.link:
        final uri = Uri.tryParse(ref);
        return uri?.host.isNotEmpty == true ? uri!.host : 'Linked article';
      case SourceKind.file:
        return ref.split('/').last;
      case SourceKind.text:
        return 'Pasted notes';
    }
  }

  static const _mockSummary =
      'Photosynthesis is the process plants use to convert light energy '
      'into chemical energy stored as glucose. It happens in the chloroplasts '
      'of plant cells and uses carbon dioxide and water as inputs, producing '
      'oxygen as a by-product. The two main stages are the light-dependent '
      'reactions and the Calvin cycle.';

  static const _mockKeyPoints = [
    'Photosynthesis converts light energy into chemical energy.',
    'It occurs in chloroplasts, primarily in plant leaves.',
    'Inputs: carbon dioxide, water, and sunlight.',
    'Outputs: glucose and oxygen.',
    'Two stages: light reactions and the Calvin cycle.',
  ];

  List<QuizQuestion> _mockQuiz() => [
        QuizQuestion(
          id: _uuid.v4(),
          prompt: 'Where does photosynthesis take place in a plant cell?',
          choices: const ['Nucleus', 'Mitochondria', 'Chloroplast', 'Ribosome'],
          correctIndex: 2,
          explanation: 'Chloroplasts contain chlorophyll, which absorbs light.',
        ),
        QuizQuestion(
          id: _uuid.v4(),
          prompt: 'Which gas is released as a by-product of photosynthesis?',
          choices: const ['Carbon dioxide', 'Oxygen', 'Nitrogen', 'Hydrogen'],
          correctIndex: 1,
        ),
        QuizQuestion(
          id: _uuid.v4(),
          prompt: 'What is the main sugar produced by photosynthesis?',
          choices: const ['Fructose', 'Sucrose', 'Glucose', 'Lactose'],
          correctIndex: 2,
        ),
      ];

  static const _mockWordGame = [
    WordChallenge(
      word: 'CHLOROPLAST',
      clue: 'Organelle in plant cells where photosynthesis happens.',
    ),
    WordChallenge(
      word: 'GLUCOSE',
      clue: 'The simple sugar produced as the main output.',
    ),
    WordChallenge(
      word: 'OXYGEN',
      clue: 'The gas released into the atmosphere as a by-product.',
    ),
    WordChallenge(
      word: 'SUNLIGHT',
      clue: 'The energy source that drives the whole process.',
    ),
  ];
}
