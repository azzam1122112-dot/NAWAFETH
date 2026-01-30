import 'package:shared_preferences/shared_preferences.dart';

import 'account_api.dart';
import 'session_storage.dart';

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

    final role = (me['role_state'] ?? '').toString().trim();
    final hasProviderProfile = me['has_provider_profile'] == true;
    final isProviderFlag = me['is_provider'] == true;

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
