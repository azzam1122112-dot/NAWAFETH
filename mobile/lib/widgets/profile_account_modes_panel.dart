import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'account_switch_sheet.dart';

class ProfileAccountModesPanel extends StatelessWidget {
  final bool isProviderRegistered;
  final bool isProviderActive;
  final bool isSwitching;
  final Future<void> Function(AccountMode mode) onSelectMode;
  final VoidCallback? onRegisterProvider;

  const ProfileAccountModesPanel({
    super.key,
    required this.isProviderRegistered,
    required this.isProviderActive,
    required this.isSwitching,
    required this.onSelectMode,
    this.onRegisterProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.deepPurple.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_circle_rounded, color: AppColors.deepPurple, size: 22),
              SizedBox(width: 8),
              Text(
                'الحسابات المتاحة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.softBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'تبديل مباشر بين حساب العميل ومقدم الخدمة مع إبراز الحساب النشط.',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 14),
          _modeCard(
            title: 'حساب العميل',
            subtitle: 'تصفح وطلب الخدمات ومتابعة الطلبات',
            icon: Icons.person_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF5B5BD6), Color(0xFF8C7BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            active: !isProviderActive,
            enabled: true,
            onTap: isSwitching ? null : () => onSelectMode(AccountMode.client),
          ),
          const SizedBox(height: 10),
          _modeCard(
            title: 'حساب مقدم الخدمة',
            subtitle: isProviderRegistered
                ? 'إدارة الخدمات والطلبات والتقييمات'
                : 'غير مفعل - سجّل كمقدم خدمة أولاً',
            icon: Icons.storefront_rounded,
            gradient: const LinearGradient(
              colors: [AppColors.deepPurple, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            active: isProviderActive,
            enabled: isProviderRegistered,
            onTap: isSwitching
                ? null
                : () {
                    if (isProviderRegistered) {
                      onSelectMode(AccountMode.provider);
                    } else {
                      onRegisterProvider?.call();
                    }
                  },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSwitching
                  ? null
                  : () {
                      if (!isProviderRegistered) {
                        onRegisterProvider?.call();
                        return;
                      }
                      onSelectMode(isProviderActive ? AccountMode.client : AccountMode.provider);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: isSwitching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(isProviderRegistered ? Icons.swap_horiz_rounded : Icons.rocket_launch_outlined),
              label: Text(
                isProviderRegistered
                    ? (isProviderActive ? 'الانتقال إلى حساب العميل' : 'الانتقال إلى حساب مقدم الخدمة')
                    : 'تفعيل حساب مقدم الخدمة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required bool active,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final borderColor = active
        ? AppColors.deepPurple.withValues(alpha: 0.45)
        : Colors.grey.withValues(alpha: 0.20);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: active ? 1.4 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: active ? 0.07 : 0.03),
              blurRadius: active ? 14 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: enabled ? AppColors.softBlue : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      height: 1.3,
                      color: enabled ? Colors.grey[600] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.deepPurple.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                active ? 'نشط' : (enabled ? 'متاح' : 'غير مفعل'),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: active ? AppColors.deepPurple : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
