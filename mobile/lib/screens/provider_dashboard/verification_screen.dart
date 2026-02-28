import 'package:flutter/material.dart';
import 'package:nawafeth/screens/verification_screen.dart' as main_screen;

/// صفحة التوثيق — تغليف لصفحة التوثيق الرئيسية
/// يُستخدم كمدخل بديل من مجلد provider_dashboard.
class ProviderVerificationScreen extends StatelessWidget {
  const ProviderVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const main_screen.VerificationScreen();
  }
}
