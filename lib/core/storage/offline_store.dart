import '../../features/games/cache/bundle_serving.dart';
import '../../features/learning/data/learning_cache.dart';
import 'storage_prefs.dart';

export '../../features/learning/data/learning_cache.dart' show OfflineSet;

/// Single read/manage point for everything stored for offline play: the
/// quizzes (study-set data) and the downloaded game files. Total is capped at
/// [StoragePrefs.maxOfflineBytes].
class OfflineStore {
  static int get limitBytes => StoragePrefs.maxOfflineBytes;

  /// Total on-device offline footprint: quizzes + downloaded games.
  static Future<int> usageBytes() async {
    final quizzes = await LearningCache().usageBytes();
    final games = await BundleServing.usageBytes();
    return quizzes + games;
  }

  static Future<int> quizBytes() => LearningCache().usageBytes();
  static Future<int> gameBytes() => BundleServing.usageBytes();

  /// The saved offline quizzes, newest first.
  static Future<List<OfflineSet>> sets() => LearningCache().offlineEntries();

  /// Free one saved quiz to make room for new ones.
  static Future<void> removeSet(String id) =>
      LearningCache().removeMaterial(id);

  /// Wipe everything (quizzes + downloaded games).
  static Future<void> clearAll() async {
    await LearningCache().clearMaterials();
    await BundleServing.clearDownloads();
  }

  static Future<void> clearGames() => BundleServing.clearDownloads();

  /// Whether the offline store is at/over its cap (used to warn the user).
  static Future<bool> isFull() async => (await usageBytes()) >= limitBytes;
}
