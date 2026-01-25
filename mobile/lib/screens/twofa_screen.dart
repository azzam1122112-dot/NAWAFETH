import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../services/auth_api.dart';
import '../services/account_api.dart';
import '../services/session_storage.dart';
import '../services/app_snackbar.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class TwoFAScreen extends StatefulWidget {
  final String phone;
  final Widget? redirectTo;
  final String? initialDevCode;

  const TwoFAScreen({
    super.key,
    required this.phone,
    this.redirectTo,
    this.initialDevCode,
  });

  @override
  State<TwoFAScreen> createState() => _TwoFAScreenState();
}

class _TwoFAScreenState extends State<TwoFAScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;

  String _formatError(Object e) {
    if (e is DioException) {
      final uri = e.requestOptions.uri;
      final baseUrl = e.requestOptions.baseUrl;
      final msg = (e.message ?? '').trim();
      final short = msg.isEmpty ? e.type.toString() : msg;
      return 'حدث خطأ في الاتصال بالشبكة: $short\nURL: $uri\nbaseUrl: $baseUrl\nError: ${e.error}';
    }
    return e.toString();
  }

  String _normalizeOtp(String input) {
    final trimmed = input.trim();
    final buffer = StringBuffer();
    for (final rune in trimmed.runes) {
      final ch = String.fromCharCode(rune);

      // Arabic-Indic digits: ٠١٢٣٤٥٦٧٨٩
      const arabicIndic = {
        '٠': '0',
        '١': '1',
        '٢': '2',
        '٣': '3',
        '٤': '4',
        '٥': '5',
        '٦': '6',
        '٧': '7',
        '٨': '8',
        '٩': '9',
      };

      // Eastern Arabic / Persian digits: ۰۱۲۳۴۵۶۷۸۹
      const easternArabic = {
        '۰': '0',
        '۱': '1',
        '۲': '2',
        '۳': '3',
        '۴': '4',
        '۵': '5',
        '۶': '6',
        '۷': '7',
        '۸': '8',
        '۹': '9',
      };

      if (arabicIndic.containsKey(ch)) {
        buffer.write(arabicIndic[ch]);
        continue;
      }
      if (easternArabic.containsKey(ch)) {
        buffer.write(easternArabic[ch]);
        continue;
      }
      if (RegExp(r'\d').hasMatch(ch)) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    try {
      await AuthApi().sendOtp(phone: widget.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إعادة إرسال الرمز')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إعادة الإرسال: ${_formatError(e)}')),
      );
    }
  }

  Future<void> _verify() async {
    final code = _normalizeOtp(_codeController.text);
    if (code.length != 4 || int.tryParse(code) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز مكون من 4 أرقام')),
      );
      return;
    }

    setState(() => _loading = true);

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    try {
      // ✅ OFFLINE 2FA LOGIC (Disconnected from Server)
      // We cannot check the real DB without connection, so we SIMULATE it:
      // If phone ends with '9' -> Treat as New User (Not Registered/Incomplete).
      // If phone ends with any other digit -> Treat as Existing User (Registered).
      
      final isNewUser = widget.phone.trim().endsWith('9');
      
      // Generate a Fake Token so the app "thinks" it's logged in.
      // Note: Real API calls in Home/Profile will fail with this token unless Backend is also mocked.
      final fakeToken = "OFFLINE_DEMO_TOKEN_${DateTime.now().millisecondsSinceEpoch}";
      
      await const SessionStorage().saveTokens(
        access: fakeToken,
        refresh: "OFFLINE_REFRESH",
      );

      if (!isNewUser) {
        // EXISTING USER SIMULATION
        // We set a fake profile so the Home Screen works locally.
        await const SessionStorage().saveProfile(
          username: "client_demo",
          email: "client@nawafeth.com",
          firstName: "عميل",
          lastName: "نوافذ",
        );
      } else {
         // NEW USER SIMULATION
         // Clear profile to force "Incomplete" state perception if checked manually
         await const SessionStorage().saveProfile(
          username: "", email: "", firstName: "", lastName: ""
        );
      }
      
      if (!mounted) return;

      if (isNewUser) {
        // Route to Signup (Simulating "Not Registered/Incomplete")
        AppSnackBar.success('أهلاً بك! يرجى استكمال تسجيل بياناتك.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        );
      } else {
        // Route to Home (Simulating "Registered & Complete")
        AppSnackBar.success('أهلاً عميل نوافذ، تم تسجيل الدخول بنجاح.');
        if (widget.redirectTo != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => widget.redirectTo!),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رمز غير صحيح أو حدث خطأ: ${_formatError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("التحقق الثنائي (2FA)"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ العنوان
                  const Text(
                    "🔐 مصادقة ثنائية مطلوبة",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    "من فضلك أدخل رمز التحقق المكوّن من 4 أرقام.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 20),

                  // ✅ إدخال الكود
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      letterSpacing: 4,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "••••",
                      counterText: "",
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.deepPurple,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.deepPurple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: _loading ? null : _resend,
                    child: const Text(
                      'إعادة إرسال الرمز',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ✅ زر التأكيد
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 40,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _loading ? null : _verify,
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
                            "تأكيد",
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
