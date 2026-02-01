import 'package:shared_preferences/shared_preferences.dart';

import '../services/session_storage.dart';
import 'local_user_state.dart';

class UserScopedPrefs {
  const UserScopedPrefs._();

  static String scopedKey(String baseKey, {required int? userId}) {
    if (userId == null) return baseKey;
    return '${baseKey}__u$userId';
  }

  static Future<int?> readUserId() => const SessionStorage().readUserId();

  /// Reads a bool from the scoped key. If missing, falls back to legacy (unscoped)
  /// key and optionally migrates it to scoped.
  static Future<bool?> getBoolScoped(
    SharedPreferences prefs,
    String baseKey, {
    required int? userId,
    bool migrateFromLegacy = true,
  }) async {
    final scoped = scopedKey(baseKey, userId: userId);
    if (prefs.containsKey(scoped)) {
      return prefs.getBool(scoped);
    }

    if (!migrateFromLegacy) return null;

    final activeUserId = await LocalUserState.getActiveUserId(prefs);
    final canMigrate = LocalUserState.canMigrateLegacyKeys(
      userId: userId,
      activeUserId: activeUserId,
    );

    if (!canMigrate) {
      // Legacy value may belong to a different user/device session.
      return null;
    }

    if (prefs.containsKey(baseKey)) {
      final legacy = prefs.getBool(baseKey);
      if (userId != null && legacy != null) {
        await prefs.setBool(scoped, legacy);
      }
      return legacy;
    }

    return null;
  }

  static Future<void> setBoolScoped(
    SharedPreferences prefs,
    String baseKey,
    bool value, {
    required int? userId,
  }) async {
    final scoped = scopedKey(baseKey, userId: userId);
    if (userId == null) {
      await prefs.setBool(baseKey, value);
      return;
    }
    await prefs.setBool(scoped, value);
  }

  static Future<String?> getStringScoped(
    SharedPreferences prefs,
    String baseKey, {
    required int? userId,
    bool migrateFromLegacy = true,
  }) async {
    final scoped = scopedKey(baseKey, userId: userId);
    if (prefs.containsKey(scoped)) {
      return prefs.getString(scoped);
    }

    if (!migrateFromLegacy) return null;

    final activeUserId = await LocalUserState.getActiveUserId(prefs);
    final canMigrate = LocalUserState.canMigrateLegacyKeys(
      userId: userId,
      activeUserId: activeUserId,
    );

    if (!canMigrate) {
      return null;
    }

    if (prefs.containsKey(baseKey)) {
      final legacy = prefs.getString(baseKey);
      if (userId != null && legacy != null) {
        await prefs.setString(scoped, legacy);
      }
      return legacy;
    }

    return null;
  }

  static Future<void> setStringScoped(
    SharedPreferences prefs,
    String baseKey,
    String value, {
    required int? userId,
  }) async {
    final scoped = scopedKey(baseKey, userId: userId);
    if (userId == null) {
      await prefs.setString(baseKey, value);
      return;
    }
    await prefs.setString(scoped, value);
  }

  static Future<void> removeScoped(
    SharedPreferences prefs,
    String baseKey, {
    required int? userId,
  }) async {
    final scoped = scopedKey(baseKey, userId: userId);
    await prefs.remove(scoped);
  }
}
