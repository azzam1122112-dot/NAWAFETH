import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const String _brandLogoAsset = 'assets/images/p.png';

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

  /// Normalizes Saudi numbers to local format: 05XXXXXXXX (10 digits)
  /// Accepts inputs like: 05XXXXXXXX or 5XXXXXXXX.
  String? _normalizeSaudiToLocal05(String input) {
    final raw = input.trim();
    final digits = _keepDigits(raw);

    // Local: 05XXXXXXXX (10 digits)
    if (RegExp(r'^05\d{8}$').hasMatch(digits)) {
      return digits;
    }

    // Local without leading 0: 5XXXXXXXX (9 digits)
    if (RegExp(r'^5\d{8}$').hasMatch(digits)) {
      return '0$digits';
    }

    return null;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed(BuildContext context) async {
    final input = _phoneCtrl.text.trim();
    final phoneLocal = _normalizeSaudiToLocal05(input);
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الجوال أولاً')),
      );
      return;
    }

    if (phoneLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الجوال غير صحيح. مثال: 05xxxxxxxx'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    // نحفظ الرقم ونحوّل لصفحة OTP دائماً بعد التحقق من الصيغة.
    // إرسال OTP من السيرفر يحاول، لكن فشله لا يمنع الانتقال.
    String? devCode;
    try {
      final api = AuthApi();
      await const SessionStorage().savePhone(phoneLocal);
      try {
        devCode = await api.sendOtp(phone: phoneLocal);
      } catch (_) {
        // ignore
      }

      // ✅ If enabled, try to verify and navigate immediately (no OTP screen).
      // If it fails (network/server), we fall back to OTP screen.
      final didNavigate = await _autoVerifyAndNavigateIfEnabled(
        phone: phoneLocal,
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
          phone: phoneLocal,
          redirectTo: widget.redirectTo,
          initialDevCode: devCode,
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: const CustomDrawer(),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'الدخول',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.deepPurple, Colors.deepPurple],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.deepPurple,
              AppColors.deepPurple.withAlpha((0.82 * 255).toInt()),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.14 * 255).toInt()),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withAlpha((0.20 * 255).toInt()),
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Image.asset(
                                _brandLogoAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.widgets,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Center(
                        child: Text(
                          'مرحباً بك في نوافذ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'أدخل رقم جوالك للمتابعة. إذا لم يكن لديك حساب، سيتم إنشاء حساب تلقائياً بعد التحقق.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.white.withAlpha((0.88 * 255).toInt()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        constraints: const BoxConstraints(maxWidth: 440),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(((isDark ? 0.25 : 0.10) * 255).toInt()),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'الدخول / التسجيل',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              maxLength: 10,
                              decoration: InputDecoration(
                                labelText: 'رقم الجوال',
                                hintText: '05xxxxxxxx',
                                prefixIcon: const Icon(Icons.phone_android),
                                counterText: '',
                                filled: true,
                                fillColor: cs.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : () => _onLoginPressed(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepPurple,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                                        'متابعة',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'سيتم إرسال رمز تحقق (OTP) لتأكيد رقم الجوال.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: cs.onSurface.withAlpha((0.65 * 255).toInt()),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => _onGuestPressed(context),
                              child: Text(
                                'الدخول كزائر',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  color: cs.onSurface.withAlpha((0.75 * 255).toInt()),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
