import 'package:shared_preferences/shared_preferences.dart';

class LocalUserState {
  const LocalUserState._();

  static const String activeUserIdKey = 'active_user_id';

  static Future<int?> getActiveUserId(SharedPreferences prefs) async {
    if (prefs.containsKey(activeUserIdKey)) {
      return prefs.getInt(activeUserIdKey);
    }
    return null;
  }

  static Future<void> setActiveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getInt(activeUserIdKey);
    if (prev != null && prev != userId) {
      // User switched without a clean logout (e.g., token swap). Clear any
      // user-specific local state so it cannot bleed into the next session.
      await clearOnLogout();
    }
    await prefs.setInt(activeUserIdKey, userId);
  }

  static Future<void> clearActiveUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeUserIdKey);
  }

  static bool canMigrateLegacyKeys({required int? userId, required int? activeUserId}) {
    if (userId == null) return false;
    if (activeUserId == null) return false;
    return userId == activeUserId;
  }

  /// Clears auth- and provider-related local preferences that must never leak between users.
  ///
  /// Note: we intentionally do NOT clear general app preferences (theme/language/etc).
  static Future<void> clearOnLogout() async {
    final prefs = await SharedPreferences.getInstance();

    // Role flags
    await prefs.remove('isProvider');
    await prefs.remove('isProviderRegistered');

    // Active user marker
    await prefs.remove(activeUserIdKey);

    // Provider completion flags + all provider registration drafts (legacy + any user-scoped variants).
    final keys = prefs.getKeys();
    final toRemove = <String>[];

    bool isProviderKey(String k) {
      if (k.startsWith('provider_section_done_')) return true;
      if (k.startsWith('provider_') && k.contains('draft')) return true;
      if (k.contains('provider_') && k.contains('draft')) return true;
      if (k.contains('_draft_v')) return true;
      if (k.contains('provider_content_editor_draft')) return true;
      if (k.contains('register') && k.contains('provider') && k.contains('draft')) return true;
      // user-scoped variants
      if (k.contains('__u') && k.contains('provider_')) return true;
      if (k.contains('__u') && k.contains('provider_section_done_')) return true;
      return false;
    }

    for (final k in keys) {
      if (isProviderKey(k)) toRemove.add(k);
    }

    for (final k in toRemove) {
      await prefs.remove(k);
    }
  }
}
