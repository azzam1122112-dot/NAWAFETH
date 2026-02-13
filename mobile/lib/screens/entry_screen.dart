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

        return const _GuestEntryLanding();
      },
    );
  }
}

class _GuestEntryLanding extends StatelessWidget {
  const _GuestEntryLanding();

  static const String _brandLogoAsset = 'assets/images/p.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF1D1458),
              Color(0xFF3E2F8E),
              Color(0xFF8E7CFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildLogoBadge(),
                const SizedBox(height: 20),
                const Text(
                  'نوافذ',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'منصة رقمية متكاملة تربط العملاء بمقدمي الخدمات بسهولة وموثوقية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
                const SizedBox(height: 26),
                _buildFeatureStrip(),
                const Spacer(flex: 3),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(35),
        border: Border.all(color: Colors.white.withAlpha(65), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipOval(
          child: Image.asset(
            _brandLogoAsset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.widgets_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureStrip() {
    Widget item(IconData icon, String text) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(28),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.white.withAlpha(220),
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
      ),
      child: Row(
        children: [
          item(Icons.verified_user_rounded, 'مزودون موثوقون'),
          item(Icons.flash_on_rounded, 'تنفيذ سريع'),
          item(Icons.support_agent_rounded, 'دعم مستمر'),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final login = ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(redirectTo: HomeScreen()),
          ),
        );
      },
      icon: const Icon(Icons.login_rounded, size: 20),
      label: const Text(
        'تسجيل الدخول',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: const Color(0xFF00C2A8),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    final guest = OutlinedButton.icon(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      },
      icon: const Icon(Icons.travel_explore_rounded, size: 20),
      label: const Text(
        'الدخول كزائر',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withAlpha(160), width: 1.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(24), width: 1),
          ),
          child: Text(
            'بمجرد إدخال رقم الجوال وتأكيده، إذا لم يكن لديك حساب مسبق سيتم إنشاء حساب جديد تلقائيًا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withAlpha(235),
            ),
          ),
        ),
        const SizedBox(height: 14),
        login,
        const SizedBox(height: 10),
        guest,
        const SizedBox(height: 10),
      ],
    );
  }
}
