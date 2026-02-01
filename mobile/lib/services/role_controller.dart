import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'role_sync.dart';

@immutable
class RoleState {
  final bool isProviderRegistered;
  final bool isProvider;

  const RoleState({
    required this.isProviderRegistered,
    required this.isProvider,
  });

  RoleState copyWith({
    bool? isProviderRegistered,
    bool? isProvider,
  }) {
    return RoleState(
      isProviderRegistered: isProviderRegistered ?? this.isProviderRegistered,
      isProvider: isProvider ?? this.isProvider,
    );
  }
}

class RoleController {
  RoleController._();

  static final RoleController instance = RoleController._();

  final ValueNotifier<RoleState> notifier =
      ValueNotifier<RoleState>(const RoleState(isProviderRegistered: false, isProvider: false));

  Future<void> initialize({String? accessToken, bool syncWithBackend = false}) async {
    if (syncWithBackend) {
      await RoleSync.sync(accessToken: accessToken);
    }
    await refreshFromPrefs();
  }

  Future<void> refreshFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getBool('isProviderRegistered') ?? false;
    final activeProvider = (prefs.getBool('isProvider') ?? false) && registered;

    notifier.value = RoleState(
      isProviderRegistered: registered,
      isProvider: activeProvider,
    );
  }

  Future<void> setProviderMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getBool('isProviderRegistered') ?? false;

    // Never enable provider mode unless the backend says a provider profile exists.
    final next = enabled && registered;

    await prefs.setBool('isProvider', next);
    notifier.value = notifier.value.copyWith(isProviderRegistered: registered, isProvider: next);
  }

  Future<void> syncFromBackend({String? accessToken}) async {
    await RoleSync.sync(accessToken: accessToken);
    await refreshFromPrefs();
  }
}
