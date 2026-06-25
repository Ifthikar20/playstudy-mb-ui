import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../learning_cache.dart';
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
  final _cache = LearningCache();

  List<LearningMaterial> get library => List.unmodifiable(_library);

  LearningMaterial? byId(String id) {
    for (final m in _library) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Refreshes the library from the server, persisting it locally. Falls back
  /// to the on-device cache when offline so the library still loads.
  Future<void> loadLibrary() async {
    try {
      final response = await api.dio.get('studysets/');
      final results =
          (response.data['results'] as List).cast<Map<String, dynamic>>();
      final rows = results.map(LearningMaterial.fromJson).toList();
      _library
        ..clear()
        ..addAll(rows);
      await _cache.saveLibrary(rows);
    } catch (e) {
      final cached = await _cache.loadLibrary();
      if (cached.isEmpty) rethrow; // nothing offline to show — surface the error
      debugPrint('[learning] library offline — ${cached.length} cached set(s)');
      _library
        ..clear()
        ..addAll(cached);
    }
  }

  /// Fetches one full study set (with quiz + word game) by id, caching it for
  /// offline play. Falls back to the cached copy when offline.
  Future<LearningMaterial> fetch(String id) async {
    try {
      final response = await api.dio.get('studysets/$id/');
      final material =
          LearningMaterial.fromJson(response.data as Map<String, dynamic>);
      await _cache.saveMaterial(material);
      return material;
    } catch (e) {
      final cached = await _cache.loadMaterial(id);
      if (cached != null) {
        debugPrint('[learning] set $id served from offline cache');
        return cached;
      }
      rethrow;
    }
  }

  Future<LearningMaterial> generate({
    required SourceKind sourceKind,
    required String sourceRef,
    String? titleHint,
    void Function(GenerationUpdate update)? onUpdate,
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
    final material = await _pollUntilReady(id, onUpdate);
    debugPrint('[learning] Study set $id ready: "${material.title}"');
    _library.insert(0, material);
    await _cache.saveMaterial(material);
    await _cache.saveLibrary(_library);
    return material;
  }

  Future<void> delete(String id) async {
    await api.dio.delete('studysets/$id/');
    _library.removeWhere((m) => m.id == id);
    await _cache.removeMaterial(id);
    await _cache.saveLibrary(_library);
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

  Future<LearningMaterial> _pollUntilReady(
      String id, void Function(GenerationUpdate)? onUpdate) async {
    // ~5 minutes max (150 * 2s). Generation fans out into one batch per chunk
    // that complete independently, so `progress` climbs and the instant
    // preview lands within a few seconds — surfaced via [onUpdate].
    for (var i = 0; i < 150; i++) {
      final data = (await api.dio.get('studysets/$id/status/')).data
          as Map<String, dynamic>;
      final value = data['status'] as String;
      debugPrint('[learning] poll $id (attempt ${i + 1}): status=$value');

      if (onUpdate != null) {
        final previewJson = data['preview'] as Map<String, dynamic>?;
        final preview = (previewJson == null || previewJson.isEmpty)
            ? null
            : StudyPreview.fromJson(previewJson);
        onUpdate(GenerationUpdate(
          id: id,
          status: value,
          progress: (data['progress'] as num?)?.toDouble() ?? 0,
          preview: preview,
          sectionTitles:
              (data['keyPoints'] as List? ?? const []).cast<String>(),
        ));
      }

      if (value == 'ready') return fetch(id);
      if (value == 'failed') {
        throw Exception((data['error'] ?? 'Generation failed').toString());
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    throw Exception('Generation timed out after 5 minutes. Please try again.');
  }

  // Photos snapped on a phone are often 4-12 MB at 4000px+. Uploading them raw
  // is slow on mobile data and forces the server to OCR a huge image. We
  // downscale + re-encode images client-side first so the upload is much
  // smaller (and OCR faster) without touching legibility for note text.
  static const _imageExts = {'png', 'jpg', 'jpeg'};
  static const _maxImageDimension = 2600;
  static const _imageJpegQuality = 85;

  Future<String> _upload(String path) async {
    final form = await _buildUploadForm(path);
    final response = await api.dio.post('uploads/', data: form);
    return response.data['key'] as String;
  }

  Future<FormData> _buildUploadForm(String path) async {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (_imageExts.contains(ext)) {
      try {
        final original = await File(path).readAsBytes();
        // Decode/resize/encode is CPU-heavy — run it off the UI isolate.
        final compressed = await compute(_compressImage, original);
        if (compressed != null && compressed.length < original.length) {
          debugPrint(
              '[learning] image compressed ${original.length} -> ${compressed.length} bytes');
          return FormData.fromMap({
            'file': MultipartFile.fromBytes(
              compressed,
              filename: '${p.basenameWithoutExtension(path)}.jpg',
            ),
          });
        }
      } catch (e) {
        // Any failure (unsupported encoding, OOM) falls back to the raw file
        // so uploads never break just because compression couldn't run.
        debugPrint('[learning] image compression skipped: $e');
      }
    }
    return FormData.fromMap({'file': await MultipartFile.fromFile(path)});
  }

  /// Top-level-safe (static) so it can run in a background isolate via
  /// [compute]. Returns null when the bytes aren't a decodable image.
  static Uint8List? _compressImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    var image = decoded;
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > _maxImageDimension) {
      image = image.width >= image.height
          ? img.copyResize(image, width: _maxImageDimension)
          : img.copyResize(image, height: _maxImageDimension);
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: _imageJpegQuality));
  }
}
