import '../../../core/network/api_client.dart';

/// A study set's progress summary in the analytics board.
class SetProgress {
  final String id;
  final String title;
  final int sectionsTotal;
  final int sectionsCompleted;
  final int secondsSpent;
  final int? avgScorePct;
  final List<SectionProgress> sections;
  const SetProgress({
    required this.id,
    required this.title,
    required this.sectionsTotal,
    required this.sectionsCompleted,
    required this.secondsSpent,
    required this.avgScorePct,
    required this.sections,
  });

  static SetProgress fromJson(Map<String, dynamic> j) => SetProgress(
        id: (j['id'] ?? '').toString(),
        title: j['title'] as String? ?? '',
        sectionsTotal: j['sectionsTotal'] as int? ?? 0,
        sectionsCompleted: j['sectionsCompleted'] as int? ?? 0,
        secondsSpent: j['secondsSpent'] as int? ?? 0,
        avgScorePct: j['avgScorePct'] as int?,
        sections: (j['sections'] as List? ?? const [])
            .map((e) => SectionProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SectionProgress {
  final int index;
  final String title;
  final int secondsSpent;
  final bool completed;
  final int? scorePct;
  const SectionProgress({
    required this.index,
    required this.title,
    required this.secondsSpent,
    required this.completed,
    required this.scorePct,
  });

  static SectionProgress fromJson(Map<String, dynamic> j) => SectionProgress(
        index: j['index'] as int? ?? 0,
        title: j['title'] as String? ?? '',
        secondsSpent: j['secondsSpent'] as int? ?? 0,
        completed: j['completed'] as bool? ?? false,
        scorePct: j['scorePct'] as int?,
      );
}

class Analytics {
  final String studentName;
  final int secondsSpent;
  final int sectionsCompleted;
  final int sectionsTotal;
  final int completionPct;
  final int points;
  final int streak;
  final int studySetCount;
  final List<SetProgress> studySets;
  const Analytics({
    required this.studentName,
    required this.secondsSpent,
    required this.sectionsCompleted,
    required this.sectionsTotal,
    required this.completionPct,
    required this.points,
    required this.streak,
    required this.studySetCount,
    required this.studySets,
  });

  static Analytics fromJson(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>? ?? const {};
    final s = j['student'] as Map<String, dynamic>? ?? const {};
    return Analytics(
      studentName: s['name'] as String? ?? 'Student',
      secondsSpent: t['secondsSpent'] as int? ?? 0,
      sectionsCompleted: t['sectionsCompleted'] as int? ?? 0,
      sectionsTotal: t['sectionsTotal'] as int? ?? 0,
      completionPct: t['completionPct'] as int? ?? 0,
      points: t['points'] as int? ?? 0,
      streak: t['streak'] as int? ?? 0,
      studySetCount: t['studySets'] as int? ?? 0,
      studySets: (j['studySets'] as List? ?? const [])
          .map((e) => SetProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LinkedPerson {
  final int linkId;
  final String id;
  final String name;
  final String email;
  const LinkedPerson(
      {required this.linkId, required this.id, required this.name, required this.email});
  static LinkedPerson fromJson(Map<String, dynamic> j) => LinkedPerson(
        linkId: j['linkId'] as int? ?? 0,
        id: (j['id'] ?? '').toString(),
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
      );
}

class FamilyStatus {
  final bool isParent;
  final List<LinkedPerson> children;
  final List<LinkedPerson> parents;
  const FamilyStatus(
      {required this.isParent, required this.children, required this.parents});
  static FamilyStatus fromJson(Map<String, dynamic> j) => FamilyStatus(
        isParent: j['isParent'] as bool? ?? false,
        children: (j['children'] as List? ?? const [])
            .map((e) => LinkedPerson.fromJson(e as Map<String, dynamic>))
            .toList(),
        parents: (j['parents'] as List? ?? const [])
            .map((e) => LinkedPerson.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Talks to the backend family/guardian + progress endpoints.
class FamilyRepository {
  final ApiClient api;
  FamilyRepository(this.api);

  // --- Progress (the student records their own time + completion) ---
  Future<void> heartbeat({
    required String studySetId,
    required int sectionIndex,
    required String sectionTitle,
    required int seconds,
  }) async {
    await api.dio.post('progress/heartbeat/', data: {
      'studySetId': studySetId,
      'sectionIndex': sectionIndex,
      'sectionTitle': sectionTitle,
      'seconds': seconds,
    });
  }

  Future<void> completeSection({
    required String studySetId,
    required int sectionIndex,
    required String sectionTitle,
    required int correct,
    required int total,
  }) async {
    await api.dio.post('progress/complete/', data: {
      'studySetId': studySetId,
      'sectionIndex': sectionIndex,
      'sectionTitle': sectionTitle,
      'correct': correct,
      'total': total,
    });
  }

  // --- Guardian linking ---
  Future<FamilyStatus> status() async {
    final r = await api.dio.get('guardian/status/');
    return FamilyStatus.fromJson(r.data as Map<String, dynamic>);
  }

  Future<String> issueCode() async {
    final r = await api.dio.post('guardian/code/');
    return r.data['code'] as String;
  }

  Future<String> redeem(String code) async {
    final r = await api.dio.post('guardian/redeem/', data: {'code': code});
    return (r.data['student']?['name'] as String?) ?? 'student';
  }

  Future<Analytics> childAnalytics(String studentId) async {
    final r = await api.dio.get('guardian/children/$studentId/');
    return Analytics.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> unlink(int linkId) async {
    await api.dio.delete('guardian/links/$linkId/');
  }
}
