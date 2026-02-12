import 'package:flutter/material.dart';

import '../services/account_api.dart';
import '../services/role_controller.dart';
import '../services/role_sync.dart';
import '../services/session_storage.dart';
import '../utils/local_user_state.dart';
import 'home_screen.dart';
import 'login_screen.dart';

enum _EntryState { loggedIn, loggedOut }

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final Future<_EntryState> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<_EntryState> _resolve() async {
    const storage = SessionStorage();
    final access = (await storage.readAccessToken())?.trim();

    if (access == null || access.isEmpty) {
      return _EntryState.loggedOut;
    }

    try {
      final me = await AccountApi().me(accessToken: access);

      String? nonEmpty(dynamic v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }

      final userId = me['id'] is int ? me['id'] as int : int.tryParse((me['id'] ?? '').toString());
      if (userId != null) {
        await LocalUserState.setActiveUserId(userId);
      }

      await storage.saveProfile(
        userId: userId,
        username: nonEmpty(me['username']),
        email: nonEmpty(me['email']),
        firstName: nonEmpty(me['first_name']),
        lastName: nonEmpty(me['last_name']),
        phone: nonEmpty(me['phone']),
      );

      // Best-effort: refresh role flags from backend for correct UI modes.
      try {
        await RoleSync.sync(accessToken: access);
        await RoleController.instance.refreshFromPrefs();
      } catch (_) {
        // ignore
      }

      return _EntryState.loggedIn;
    } catch (_) {
      await LocalUserState.clearOnLogout();
      await storage.clear();
      return _EntryState.loggedOut;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EntryState>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final state = snap.data ?? _EntryState.loggedOut;
        if (state == _EntryState.loggedIn) {
          return const HomeScreen();
        }

        return const LoginScreen(redirectTo: HomeScreen());
      },
    );
  }
}
