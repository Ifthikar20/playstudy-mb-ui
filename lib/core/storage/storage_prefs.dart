import 'package:shared_preferences/shared_preferences.dart';

/// User-controlled storage policy for offline downloads. The big consumer is
/// the game-bundle cache; this lets the user cap it (or turn it off) so the app
/// never crowds the device with downloaded files.
class StoragePrefs {
  static const _offlineKey = 'pref_offline_enabled';
  static const _limitKey = 'pref_offline_limit_mb';

  static const int defaultLimitMb = 250;
  static const List<int> limitOptionsMb = [100, 250, 500];

  /// Whether to download game bundles for offline play. Off = stream only,
  /// nothing stored on device.
  static Future<bool> offlineEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_offlineKey) ?? true;

  static Future<void> setOfflineEnabled(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_offlineKey, value);
  }

  /// Hard cap on the on-device bundle cache, in megabytes.
  static Future<int> limitMb() async =>
      (await SharedPreferences.getInstance()).getInt(_limitKey) ?? defaultLimitMb;

  static Future<int> limitBytes() async => (await limitMb()) * 1024 * 1024;

  static Future<void> setLimitMb(int value) async {
    await (await SharedPreferences.getInstance()).setInt(_limitKey, value);
  }
}
