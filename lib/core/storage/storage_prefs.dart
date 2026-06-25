import 'package:shared_preferences/shared_preferences.dart';

/// User-controlled offline policy. The cap is fixed at 50 MB so downloaded
/// quizzes + games can never crowd the device; the user manages what's kept
/// from the Offline screen.
class StoragePrefs {
  static const _offlineKey = 'pref_offline_enabled';

  /// Hard ceiling on everything stored for offline play (quizzes + game files).
  static const int maxOfflineMb = 50;
  static const int maxOfflineBytes = maxOfflineMb * 1024 * 1024;

  /// Whether to keep quizzes/games for offline play. Off = stream only.
  static Future<bool> offlineEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_offlineKey) ?? true;

  static Future<void> setOfflineEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_offlineKey, value);
  }

  static Future<int> limitBytes() async => maxOfflineBytes;
}
