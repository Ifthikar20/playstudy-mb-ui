import '../../../../core/network/api_client.dart';
import '../models/exam_plan.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Backend-backed exam plans. The server stores the plan + recorded daily
/// results; the client derives the schedule/progress from those fields.
class ExamPrepRepository {
  final ApiClient api;
  ExamPrepRepository(this.api);

  Future<List<ExamPlan>> all() async {
    final response = await api.dio.get('examplans/');
    final results =
        (response.data['results'] as List).cast<Map<String, dynamic>>();
    return results.map(ExamPlan.fromJson).toList();
  }

  Future<ExamPlan> create({
    required String materialId,
    required String materialTitle,
    required String examTitle,
    required DateTime examDate,
    required int questionsPerDay,
    required List<String> topics,
  }) async {
    final response = await api.dio.post('examplans/', data: {
      'materialId': materialId,
      'examTitle': examTitle,
      'examDate': _ymd(examDate),
      'questionsPerDay': questionsPerDay,
      'topics': topics,
    });
    return ExamPlan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await api.dio.delete('examplans/$id/');
  }

  /// Records a completed daily session (upsert) and returns the updated plan.
  Future<ExamPlan> recordSession({
    required String planId,
    required DateTime day,
    required int correct,
    required int total,
  }) async {
    final response = await api.dio.post('examplans/$planId/sessions/', data: {
      'day': _ymd(day),
      'correct': correct,
      'total': total,
    });
    return ExamPlan.fromJson(response.data as Map<String, dynamic>);
  }
}
