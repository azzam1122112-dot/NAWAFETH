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
  // First ensure logged in
  if (!await checkAuth(context)) return false;

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
    if (!context.mounted) return false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إكمال التسجيل', textAlign: TextAlign.right),
        content: const Text(
          'للاستفادة من هذه الميزة (الطلبات، التقييم، التسجيل كمزود، إلخ)، يرجى استكمال بياناتك الأساسية.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              );
            },
            child: const Text('إكمال الآن'),
          ),
        ],
      ),
    );
    return false;
  }
  
  return true;
}
