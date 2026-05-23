import 'dart:convert';
import 'package:equatable/equatable.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// User-defined plan to study for an exam.
/// The schedule is derived: every day from createdAt through examDate is
/// a session of [questionsPerDay] questions cycled from [topics].
class ExamPlan extends Equatable {
  final String id;
  final String materialId;
  final String materialTitle;
  final String examTitle;
  final DateTime examDate;
  final int questionsPerDay;
  final List<String> topics;
  final DateTime createdAt;
  final Map<String, DailyResult> results; // ymd → result

  const ExamPlan({
    required this.id,
    required this.materialId,
    required this.materialTitle,
    required this.examTitle,
    required this.examDate,
    required this.questionsPerDay,
    required this.topics,
    required this.createdAt,
    this.results = const {},
  });

  /// All scheduled day keys (yyyy-MM-dd) from creation through the exam.
  List<DateTime> get scheduledDays {
    final start = _dateOnly(createdAt);
    final end = _dateOnly(examDate);
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    return days;
  }

  int get totalDays => scheduledDays.length;
  int get completedDays => results.values.where((r) => r.completed).length;
  double get progress => totalDays == 0 ? 0 : completedDays / totalDays;

  int get daysUntilExam {
    final today = _dateOnly(DateTime.now());
    return _dateOnly(examDate).difference(today).inDays;
  }

  /// Is the user behind, on track, or ahead?
  bool get isToday {
    final today = _dateOnly(DateTime.now());
    return scheduledDays.any((d) => d.isAtSameMomentAs(today));
  }

  DailyResult? resultFor(DateTime day) =>
      results[_keyFor(day)];

  ExamPlan markCompleted({
    required DateTime day,
    required int correct,
    required int total,
  }) {
    final key = _keyFor(day);
    final next = Map<String, DailyResult>.from(results);
    next[key] = DailyResult(correct: correct, total: total, completed: true);
    return copyWith(results: next);
  }

  ExamPlan copyWith({
    String? examTitle,
    DateTime? examDate,
    int? questionsPerDay,
    List<String>? topics,
    Map<String, DailyResult>? results,
  }) {
    return ExamPlan(
      id: id,
      materialId: materialId,
      materialTitle: materialTitle,
      examTitle: examTitle ?? this.examTitle,
      examDate: examDate ?? this.examDate,
      questionsPerDay: questionsPerDay ?? this.questionsPerDay,
      topics: topics ?? this.topics,
      createdAt: createdAt,
      results: results ?? this.results,
    );
  }

  static String _keyFor(DateTime d) {
    final day = _dateOnly(d);
    return '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'materialId': materialId,
        'materialTitle': materialTitle,
        'examTitle': examTitle,
        'examDate': examDate.toIso8601String(),
        'questionsPerDay': questionsPerDay,
        'topics': topics,
        'createdAt': createdAt.toIso8601String(),
        'results': results.map((k, v) => MapEntry(k, v.toJson())),
      };

  static ExamPlan fromJson(Map<String, dynamic> j) => ExamPlan(
        id: j['id'] as String,
        materialId: j['materialId'] as String,
        materialTitle: j['materialTitle'] as String,
        examTitle: j['examTitle'] as String,
        examDate: DateTime.parse(j['examDate'] as String),
        questionsPerDay: j['questionsPerDay'] as int,
        topics: (j['topics'] as List).cast<String>(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        results: (j['results'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, DailyResult.fromJson(v as Map<String, dynamic>))),
      );

  static String encodeList(List<ExamPlan> plans) =>
      jsonEncode(plans.map((p) => p.toJson()).toList());

  static List<ExamPlan> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ExamPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  List<Object?> get props => [
        id,
        materialId,
        materialTitle,
        examTitle,
        examDate,
        questionsPerDay,
        topics,
        createdAt,
        results,
      ];
}

class DailyResult extends Equatable {
  final int correct;
  final int total;
  final bool completed;

  const DailyResult({
    required this.correct,
    required this.total,
    required this.completed,
  });

  Map<String, dynamic> toJson() =>
      {'correct': correct, 'total': total, 'completed': completed};

  static DailyResult fromJson(Map<String, dynamic> j) => DailyResult(
        correct: j['correct'] as int,
        total: j['total'] as int,
        completed: j['completed'] as bool,
      );

  @override
  List<Object?> get props => [correct, total, completed];
}
