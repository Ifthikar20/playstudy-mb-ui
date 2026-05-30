import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../models/learning_models.dart';

/// Talks to the PlayStudy backend for study-set generation and the library.
///
/// Generation is async on the server: POST returns 202 + an id, then we poll
/// the status endpoint and fetch the full set when it is ready. The public
/// surface (`generate`, `library`, `byId`, `delete`) is unchanged from the
/// original mock so the bloc/UI are untouched apart from awaiting loads.
class LearningRepository {
  final ApiClient api;
  LearningRepository(this.api);

  final List<LearningMaterial> _library = [];
  final _uuid = const Uuid();

  List<LearningMaterial> get library => List.unmodifiable(_library);

  LearningMaterial? byId(String id) {
    for (final m in _library) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Refreshes the cached library from the server (lightweight rows).
  Future<void> loadLibrary() async {
    final response = await api.dio.get('studysets/');
    final results =
        (response.data['results'] as List).cast<Map<String, dynamic>>();
    _library
      ..clear()
      ..addAll(results.map(LearningMaterial.fromJson));
  }

  /// Fetches one full study set (with quiz + word game) by id.
  Future<LearningMaterial> fetch(String id) async {
    final response = await api.dio.get('studysets/$id/');
    return LearningMaterial.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LearningMaterial> generate({
    required SourceKind sourceKind,
    required String sourceRef,
    String? titleHint,
  }) async {
    var ref = sourceRef;
    if (sourceKind == SourceKind.file) {
      ref = await _upload(sourceRef);
    }

    final create = await api.dio.post(
      'studysets/',
      data: {
        'sourceKind': sourceKind.name, // link | file | text
        'sourceRef': ref,
        if (titleHint != null && titleHint.trim().isNotEmpty)
          'title': titleHint.trim(),
      },
      // Guards against duplicate sets if the request is retried on a flaky link.
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );

    final id = create.data['id'] as String;
    debugPrint('[learning] Created study set $id (HTTP ${create.statusCode}), polling status…');
    final material = await _pollUntilReady(id);
    debugPrint('[learning] Study set $id ready: "${material.title}"');
    _library.insert(0, material);
    return material;
  }

  Future<void> delete(String id) async {
    await api.dio.delete('studysets/$id/');
    _library.removeWhere((m) => m.id == id);
  }

  /// Generate a fresh pack of [count] quiz questions for [id] that don't
  /// repeat anything already on the set. Returns the new questions.
  Future<List<QuizQuestion>> generateQuizPack(String id,
      {int count = 10}) async {
    debugPrint('[learning] quiz-pack request id=$id count=$count');
    final response = await api.dio.post(
      'studysets/$id/quiz-pack/',
      data: {'count': count},
    );
    final list = (response.data as List).cast<Map<String, dynamic>>();
    debugPrint('[learning] quiz-pack got ${list.length} new questions');
    return list.map(QuizQuestion.fromJson).toList();
  }

  Future<LearningMaterial> _pollUntilReady(String id) async {
    // ~2 minutes max (60 * 2s) — generation is typically 10-40s.
    for (var i = 0; i < 60; i++) {
      final status = await api.dio.get('studysets/$id/status/');
      final value = status.data['status'] as String;
      debugPrint('[learning] poll $id (attempt ${i + 1}): status=$value');
      if (value == 'ready') return fetch(id);
      if (value == 'failed') {
        throw Exception(
            (status.data['error'] ?? 'Generation failed').toString());
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw Exception('Generation timed out. Please try again.');
  }

  Future<String> _upload(String path) async {
    final form = FormData.fromMap({'file': await MultipartFile.fromFile(path)});
    final response = await api.dio.post('uploads/', data: form);
    return response.data['key'] as String;
  }
}
