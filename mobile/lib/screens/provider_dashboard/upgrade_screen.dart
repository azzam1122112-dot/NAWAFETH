import 'package:flutter/material.dart';
import 'package:nawafeth/screens/plans_screen.dart';

/// صفحة الترقية — تغليف لصفحة الباقات PlansScreen
/// يُستخدم كمدخل بديل من صفحة نافذتي إذا أردت إضافة تفاصيل لاحقاً.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlansScreen();
  }
}
