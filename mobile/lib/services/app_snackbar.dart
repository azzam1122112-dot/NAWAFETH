import 'package:flutter/material.dart';

/// A root-level messenger key so SnackBars can be shown reliably
/// even during navigation (e.g., after login / delete-account).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AppSnackBar {
  const AppSnackBar._();

  static void success(String message, {Duration duration = const Duration(seconds: 3)}) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          backgroundColor: const Color(0xFF2E7D32),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void error(String message, {Duration duration = const Duration(seconds: 4)}) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          backgroundColor: const Color(0xFFC62828),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
