import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'models/learning_models.dart';

/// On-device cache of study-set data so the library and games work offline.
///
/// Designed to stay small so it can't overload the app:
///  • The **library index** (lightweight rows: title/summary, no quiz/words) is
///    a tiny regular box — cheap to keep fully in memory.
///  • **Full materials** (quiz/words/sections) go in a *lazy* box, so their
///    bodies are read from disk on demand and never all sit in RAM at once.
///  • Full materials are capped at [_maxMaterials] with **LRU eviction**, so
///    disk use is bounded no matter how many sets the user generates.
class LearningCache {
  static const _libraryBox = 'learning_library'; // Box<String>
  static const _materialsBox = 'learning_materials'; // LazyBox<String>
  static const _indexBox = 'learning_index'; // Box<int> : id -> lastAccess ms
  static const _libraryKey = 'rows';
  static const _maxMaterials = 40;

  Box<String>? _library;
  LazyBox<String>? _materials;
  Box<int>? _index;
  Future<void>? _opening;

  // Single-flight so concurrent first calls don't open the same box twice.
  Future<void> _ensureOpen() => _opening ??= _open();

  Future<void> _open() async {
    _library = await Hive.openBox<String>(_libraryBox);
    _materials = await Hive.openLazyBox<String>(_materialsBox);
    _index = await Hive.openBox<int>(_indexBox);
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

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

  // --- Full materials (quiz/words/sections) --------------------------------

  Future<void> saveMaterial(LearningMaterial material) async {
    if (material.id.isEmpty) return;
    try {
      await _ensureOpen();
      await _materials!.put(material.id, jsonEncode(material.toJson()));
      await _index!.put(material.id, _now);
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
      await _index!.put(id, _now); // touch for LRU
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
      await _index!.delete(id);
    } catch (e) {
      debugPrint('[learning] removeMaterial failed: $e');
    }
  }

  /// Evicts the least-recently-used full materials beyond the cap. The library
  /// row stays, so the set still shows — it just re-downloads when next opened.
  Future<void> _evict() async {
    final materials = _materials!;
    if (materials.length <= _maxMaterials) return;
    final index = _index!;
    final byAge = materials.keys.toList()
      ..sort((a, b) => (index.get(a) ?? 0).compareTo(index.get(b) ?? 0));
    final overflow = materials.length - _maxMaterials;
    for (final key in byAge.take(overflow)) {
      await materials.delete(key);
      await index.delete(key);
    }
  }
}
