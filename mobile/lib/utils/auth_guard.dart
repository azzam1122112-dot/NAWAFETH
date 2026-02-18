// auth_guard.dart
import 'package:flutter/material.dart';
import '../services/account_api.dart';
import '../services/session_storage.dart';
import '../screens/signup_screen.dart';

/// Checks if user is logged in (at least Phone Only)
Future<bool> checkAuth(BuildContext context) async {
  final token = await const SessionStorage().readAccessToken();
  if (token != null && token.isNotEmpty) return true;

  if (!context.mounted) return false;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تسجيل دخول', textAlign: TextAlign.right),
      content: const Text(
        'عذراً، هذه الميزة تتطلب تسجيل الدخول. هل تود المتابعة لصفحة الدخول؟',
        textAlign: TextAlign.right,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pushNamed(context, '/login');
          },
          child: const Text('دخول'),
        ),
      ],
    ),
  );
  return false;
}

/// Checks if user has completed profile (Full Client)
Future<bool> checkFullClient(BuildContext context) async {
  final token = await const SessionStorage().readAccessToken();
  final hasToken = token != null && token.isNotEmpty;

  Future<void> showRegistrationRequiredDialog({required bool canOpenSignup}) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF9C2D9E), width: 1.2),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Text(
                        'x',
                        style: TextStyle(
                          color: Color(0xFF7F1D8D),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'نرجو استكمال معلومات التسجيل لتتمكن من الاستفادة من خدمات المنصة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    color: Color(0xFF7F1D8D),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEBC8EE),
                        foregroundColor: const Color(0xFF7F1D8D),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (canOpenSignup) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignUpScreen()),
                          );
                        } else {
                          Navigator.pushNamed(context, '/login');
                        }
                      },
                      child: const Text(
                        'التسجيل',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  if (!hasToken) {
    await showRegistrationRequiredDialog(canOpenSignup: false);
    return false;
  }

  bool isCompleted = false;
  try {
    final me = await AccountApi().me();
    final role = (me['role_state'] ?? '').toString().trim().toLowerCase();
    isCompleted = role == 'client' || role == 'provider' || role == 'staff';
  } catch (_) {
    // Fallback local check when backend is temporarily unavailable.
    final username = await const SessionStorage().readUsername();
    isCompleted = username != null && username.trim().isNotEmpty;
  }

  if (!isCompleted) {
    await showRegistrationRequiredDialog(canOpenSignup: true);
    return false;
  }
  
  return true;
}
