import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/storage/storage_prefs.dart';
import 'models/learning_models.dart';

/// One study set saved for offline play.
class OfflineSet {
  final String id;
  final String title;
  final int bytes;
  final int savedAt; // ms since epoch
  const OfflineSet({
    required this.id,
    required this.title,
    required this.bytes,
    required this.savedAt,
  });
}

/// On-device cache of study-set data so quizzes play with no internet.
///
/// Stays small and managed:
///  • The **library index** (lightweight rows) is a tiny regular box.
///  • **Full materials** (quiz/words/sections) live in a *lazy* box — bodies
///    read on demand, never all in RAM.
///  • A **meta** box records each set's size + title so the Offline screen can
///    list them and the user can free individual ones.
///  • Total is held under the 50 MB cap via LRU eviction; [evictionSignal]
///    fires when something was auto-removed so the UI can tell the user.
class LearningCache {
  static const _libraryBox = 'learning_library'; // Box<String>
  static const _materialsBox = 'learning_materials'; // LazyBox<String>
  static const _metaBox = 'learning_meta'; // Box<String> : id -> {ts,bytes,title}
  static const _libraryKey = 'rows';

  /// Bumped whenever a save evicted an older set to stay under the cap.
  static final ValueNotifier<int> evictionSignal = ValueNotifier<int>(0);

  Box<String>? _library;
  LazyBox<String>? _materials;
  Box<String>? _meta;
  Future<void>? _opening;

  Future<void> _ensureOpen() => _opening ??= _open();

  Future<void> _open() async {
    _library = await Hive.openBox<String>(_libraryBox);
    _materials = await Hive.openLazyBox<String>(_materialsBox);
    _meta = await Hive.openBox<String>(_metaBox);
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> _metaOf(String id) {
    final raw = _meta!.get(id);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // --- Library (lightweight rows) ------------------------------------------

  Future<void> saveLibrary(List<LearningMaterial> rows) async {
    try {
      await _ensureOpen();
      await _library!.put(
        _libraryKey,
        jsonEncode(rows.map((m) => m.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[learning] saveLibrary failed: $e');
    }
  }

  Future<List<LearningMaterial>> loadLibrary() async {
    try {
      await _ensureOpen();
      final raw = _library!.get(_libraryKey);
      if (raw == null) return const [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(LearningMaterial.fromJson).toList();
    } catch (e) {
      debugPrint('[learning] loadLibrary failed: $e');
      return const [];
    }
  }

  // --- Full materials (offline quizzes) ------------------------------------

  Future<void> saveMaterial(LearningMaterial material) async {
    if (material.id.isEmpty) return;
    try {
      await _ensureOpen();
      final body = jsonEncode(material.toJson());
      await _materials!.put(material.id, body);
      await _meta!.put(
        material.id,
        jsonEncode({
          'ts': _now,
          'bytes': utf8.encode(body).length,
          'title': material.title,
        }),
      );
      await _evict();
    } catch (e) {
      debugPrint('[learning] saveMaterial failed: $e');
    }
  }

  Future<LearningMaterial?> loadMaterial(String id) async {
    try {
      await _ensureOpen();
      final raw = await _materials!.get(id);
      if (raw == null) return null;
      final m = _metaOf(id)..['ts'] = _now; // touch for LRU
      await _meta!.put(id, jsonEncode(m));
      return LearningMaterial.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[learning] loadMaterial failed: $e');
      return null;
    }
  }

  Future<void> removeMaterial(String id) async {
    try {
      await _ensureOpen();
      await _materials!.delete(id);
      await _meta!.delete(id);
    } catch (e) {
      debugPrint('[learning] removeMaterial failed: $e');
    }
  }

  Future<void> clearMaterials() async {
    try {
      await _ensureOpen();
      await _materials!.clear();
      await _meta!.clear();
    } catch (e) {
      debugPrint('[learning] clearMaterials failed: $e');
    }
  }

  /// Total bytes used by cached full materials.
  Future<int> usageBytes() async {
    await _ensureOpen();
    var total = 0;
    for (final key in _meta!.keys) {
      total += (_metaOf(key.toString())['bytes'] as int? ?? 0);
    }
    return total;
  }

  /// The saved offline quizzes, newest first — drives the Offline screen.
  Future<List<OfflineSet>> offlineEntries() async {
    await _ensureOpen();
    final out = <OfflineSet>[];
    for (final key in _meta!.keys) {
      final m = _metaOf(key.toString());
      out.add(OfflineSet(
        id: key.toString(),
        title: (m['title'] as String?) ?? 'Study set',
        bytes: (m['bytes'] as int?) ?? 0,
        savedAt: (m['ts'] as int?) ?? 0,
      ));
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  /// Evict least-recently-used quizzes until under the cap. Signals the UI so
  /// it can tell the user something was removed to make room.
  Future<void> _evict() async {
    var total = await usageBytes();
    if (total <= StoragePrefs.maxOfflineBytes) return;
    final entries = await offlineEntries()
      ..sort((a, b) => a.savedAt.compareTo(b.savedAt)); // oldest first
    var removed = false;
    for (final e in entries) {
      if (total <= StoragePrefs.maxOfflineBytes) break;
      await removeMaterial(e.id);
      total -= e.bytes;
      removed = true;
    }
    if (removed) evictionSignal.value++;
  }
}
