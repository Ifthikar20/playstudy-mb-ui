import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-material quiz progress shared between the standalone Quiz tab
/// ([QuizView]) and the per-section quiz inside Study mode
/// ([StudyFlowView]). Records which questions have been answered (and
/// whether correctly) by stable question id, plus a "done" flag set when
/// the user finishes the standalone quiz so reopening lands on the
/// score/retry screen instead of a partial replay state.
class QuizProgressStore {
  static String _key(String materialId) => 'quiz_progress_v2_$materialId';

  static Future<_State> load(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(materialId));
    if (raw == null) return _State.empty();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return _State(
        answered: (m['answered'] as List?)?.cast<String>().toSet() ?? <String>{},
        correct: (m['correct'] as List?)?.cast<String>().toSet() ?? <String>{},
        done: (m['done'] as bool?) ?? false,
        lastIndex: (m['lastIndex'] as int?) ?? 0,
        score: (m['score'] as int?) ?? 0,
      );
    } catch (_) {
      return _State.empty();
    }
  }

  static Future<void> _save(String materialId, _State s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(materialId),
      jsonEncode({
        'answered': s.answered.toList(),
        'correct': s.correct.toList(),
        'done': s.done,
        'lastIndex': s.lastIndex,
        'score': s.score,
      }),
    );
  }

  /// Records one answered question. Both QuizView and StudyFlowView call this
  /// on every reveal so progress is unified across the two views.
  static Future<void> markAnswered(
    String materialId,
    String questionId, {
    required bool correct,
  }) async {
    final s = await load(materialId);
    s.answered.add(questionId);
    if (correct) s.correct.add(questionId);
    await _save(materialId, s);
  }

  /// Persists current cursor so the standalone Quiz tab resumes where left
  /// off until the user finishes (which calls [markDone]).
  static Future<void> saveCursor(
    String materialId, {
    required int lastIndex,
    required int score,
  }) async {
    final s = await load(materialId);
    s.lastIndex = lastIndex;
    s.score = score;
    await _save(materialId, s);
  }

  static Future<void> markDone(String materialId, {required int score}) async {
    final s = await load(materialId);
    s.done = true;
    s.score = score;
    await _save(materialId, s);
  }

  /// Fully resets all per-material quiz progress (used by "Restart quiz" and
  /// "Retry these"). Both answered-set + cursor + done flag are wiped.
  static Future<void> resetAll(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(materialId));
  }
}

class _State {
  Set<String> answered;
  Set<String> correct;
  bool done;
  int lastIndex;
  int score;
  _State({
    required this.answered,
    required this.correct,
    required this.done,
    required this.lastIndex,
    required this.score,
  });
  factory _State.empty() => _State(
        answered: <String>{},
        correct: <String>{},
        done: false,
        lastIndex: 0,
        score: 0,
      );
}

/// Public, immutable read-side view of the same state for widgets that just
/// want to render a "X of Y answered" indicator.
class QuizProgressSnapshot {
  final Set<String> answered;
  final Set<String> correct;
  final bool done;
  final int lastIndex;
  final int score;
  const QuizProgressSnapshot({
    required this.answered,
    required this.correct,
    required this.done,
    required this.lastIndex,
    required this.score,
  });

  static Future<QuizProgressSnapshot> load(String materialId) async {
    final s = await QuizProgressStore.load(materialId);
    return QuizProgressSnapshot(
      answered: Set.unmodifiable(s.answered),
      correct: Set.unmodifiable(s.correct),
      done: s.done,
      lastIndex: s.lastIndex,
      score: s.score,
    );
  }
}
