import 'package:shared_preferences/shared_preferences.dart';

import 'account_api.dart';
import 'session_storage.dart';
import '../utils/local_user_state.dart';

class RoleSync {
  /// Best-effort sync of local role flags with backend.
  ///
  /// Updates:
  /// - `isProviderRegistered`: whether the user is registered as provider on backend
  /// - `isProvider`: forced to false when backend says user is not provider
  static Future<void> sync({String? accessToken}) async {
    final loggedIn = await const SessionStorage().isLoggedIn();
    if (!loggedIn) return;

    final me = await AccountApi().me(accessToken: accessToken);

    // Keep user identity in sync as a defense-in-depth measure. This also
    // ensures user-switch cleanup runs if the token belongs to a different user.
    final rawId = me['id'];
    final int? userId = rawId is int ? rawId : int.tryParse((rawId ?? '').toString());
    if (userId != null) {
      try {
        await const SessionStorage().saveUserId(userId);
      } catch (_) {
        // ignore
      }
      try {
        await LocalUserState.setActiveUserId(userId);
      } catch (_) {
        // ignore
      }
    }

    final hasProviderProfile = me['has_provider_profile'] == true;

    // Only consider the user "provider-registered" if a provider profile exists.
    // This keeps pure-client accounts from seeing/entering provider mode.
    final isProviderRegistered = hasProviderProfile;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isProviderRegistered', isProviderRegistered);

    if (!isProviderRegistered) {
      await prefs.setBool('isProvider', false);
    }
  }
}
