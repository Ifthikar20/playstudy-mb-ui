import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/exam_plan.dart';

/// Stores [ExamPlan]s in SharedPreferences as JSON. Swap for a backend
/// repository when the Django API is ready — keep the same surface.
class ExamPrepRepository {
  static final ExamPrepRepository _i = ExamPrepRepository._();
  factory ExamPrepRepository() => _i;
  ExamPrepRepository._();

  static const _key = 'exam_plans_v1';
  List<ExamPlan> _plans = [];
  bool _loaded = false;
  final _uuid = const Uuid();

  Future<List<ExamPlan>> all() async {
    if (!_loaded) await _load();
    return List.unmodifiable(_plans);
  }

  Future<ExamPlan> create({
    required String materialId,
    required String materialTitle,
    required String examTitle,
    required DateTime examDate,
    required int questionsPerDay,
    required List<String> topics,
  }) async {
    if (!_loaded) await _load();
    final plan = ExamPlan(
      id: _uuid.v4(),
      materialId: materialId,
      materialTitle: materialTitle,
      examTitle: examTitle,
      examDate: examDate,
      questionsPerDay: questionsPerDay,
      topics: topics,
      createdAt: DateTime.now(),
    );
    _plans = [plan, ..._plans];
    await _save();
    return plan;
  }

  Future<void> update(ExamPlan plan) async {
    if (!_loaded) await _load();
    _plans = _plans.map((p) => p.id == plan.id ? plan : p).toList();
    await _save();
  }

  Future<void> delete(String id) async {
    if (!_loaded) await _load();
    _plans = _plans.where((p) => p.id != id).toList();
    await _save();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _plans = raw == null ? <ExamPlan>[] : ExamPlan.decodeList(raw);
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ExamPlan.encodeList(_plans));
  }
}
