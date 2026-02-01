import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../widgets/custom_drawer.dart';

import '../services/auth_api.dart';
import '../services/account_api.dart';
import '../services/session_storage.dart';
import '../services/app_snackbar.dart';
import '../services/role_sync.dart';
import '../services/role_controller.dart';
import '../utils/local_user_state.dart';
import 'twofa_screen.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

const bool _devBypassOtp = bool.fromEnvironment('DEV_BYPASS_OTP', defaultValue: false);

class LoginScreen extends StatefulWidget {
  final Widget? redirectTo;

  const LoginScreen({super.key, this.redirectTo});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  Future<bool> _autoVerifyAndNavigateIfEnabled({required String phone, String? devCode}) async {
    // Disabled by default (including debug). Enable only explicitly via build flag.
    // Example:
    // `flutter run --dart-define=DEV_BYPASS_OTP=true`
    if (!_devBypassOtp) return false;

    final candidate = (devCode ?? '').trim();
    final code = candidate.isNotEmpty ? candidate : '0000';

    try {
      final result = await AuthApi().otpVerify(phone: phone, code: code);
      await const SessionStorage().saveTokens(access: result.access, refresh: result.refresh);

      // Best-effort: refresh user identity for UI.
      try {
        final me = await AccountApi().me(accessToken: result.access);

        String? nonEmpty(dynamic v) {
          final s = (v ?? '').toString().trim();
          return s.isEmpty ? null : s;
        }

        final userId = me['id'] is int ? me['id'] as int : int.tryParse((me['id'] ?? '').toString());
        if (userId != null) {
          await LocalUserState.setActiveUserId(userId);
        }

        await const SessionStorage().saveProfile(
          userId: userId,
          username: nonEmpty(me['username']),
          email: nonEmpty(me['email']),
          firstName: nonEmpty(me['first_name']),
          lastName: nonEmpty(me['last_name']),
          phone: nonEmpty(me['phone']),
        );
      } catch (_) {
        // ignore
      }

      // Best-effort: sync provider/client role flags for UI.
      try {
        await RoleSync.sync(accessToken: result.access);
        await RoleController.instance.refreshFromPrefs();
      } catch (_) {
        // ignore
      }

      if (!mounted) return true;

      final fullName = (await const SessionStorage().readFullName())?.trim();
      final username = (await const SessionStorage().readUsername())?.trim();
      final name = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : ((username != null && username.isNotEmpty) ? username : null);

      AppSnackBar.success(name == null ? 'تم تسجيل الدخول بنجاح. أهلاً بك!' : 'أهلاً $name، تم تسجيل الدخول بنجاح.');

      if (result.isNewUser || result.needsCompletion) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        );
        return true;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.redirectTo ?? const HomeScreen()),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _keepDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  /// Normalizes Saudi numbers to E.164: +9665XXXXXXXX
  /// Accepts inputs like: 05XXXXXXXX, +9665XXXXXXXX, 9665XXXXXXXX.
  String? _normalizeSaudiToE164(String input) {
    final raw = input.trim();
    final digits = _keepDigits(raw);

    // Local: 05XXXXXXXX (10 digits)
    if (RegExp(r'^05\d{8}$').hasMatch(digits)) {
      return '+966${digits.substring(1)}';
    }

    // International without plus: 9665XXXXXXXX (12 digits)
    if (RegExp(r'^9665\d{8}$').hasMatch(digits)) {
      return '+$digits';
    }

    // International with plus: +9665XXXXXXXX (we stripped '+', so same as above)
    return null;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed(BuildContext context) async {
    final input = _phoneCtrl.text.trim();
    final phoneE164 = _normalizeSaudiToE164(input);
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الجوال أولاً')),
      );
      return;
    }

    if (phoneE164 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الجوال غير صحيح. مثال: 05xxxxxxxx أو +9665xxxxxxxx'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    // We don't depend on any dev_code; user completes OTP manually.

    // نحفظ الرقم ونحوّل لصفحة OTP دائماً بعد التحقق من الصيغة.
    // إرسال OTP من السيرفر يحاول، لكن فشله لا يمنع الانتقال.
    try {
      final api = AuthApi();
      // Store a readable local format when possible.
      final digits = _keepDigits(input);
      final local = RegExp(r'^05\d{8}$').hasMatch(digits) ? digits : digits;
      await const SessionStorage().savePhone(local);
      try {
        await api.sendOtp(phone: phoneE164);
      } catch (_) {
        // ignore
      }

      // ✅ If enabled, try to verify and navigate immediately (no OTP screen).
      // If it fails (network/server), we fall back to OTP screen.
      final didNavigate = await _autoVerifyAndNavigateIfEnabled(
        phone: phoneE164,
        devCode: null,
      );
      if (didNavigate) return;

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال رمز التحقق')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ غير متوقع: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TwoFAScreen(
          phone: phoneE164,
          redirectTo: widget.redirectTo,
          initialDevCode: null,
        ),
      ),
    );
  }

  void _onGuestPressed(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "تسجيل الدخول",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.05 * 255).toInt()),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "أدخل رقم الجوال لتسجيل الدخول",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "رقم الجوال",
                    prefixIcon: const Icon(Icons.phone_android),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _onLoginPressed(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "تسجيل الدخول",
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _onGuestPressed(context),
                  child: const Text(
                    "الدخول كزائر",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // إنشاء حساب جديد يتم بعد OTP تلقائياً عند عدم وجود المستخدم.
              ],
            ),
          ),
        ),
      ),
    );
  }
}
