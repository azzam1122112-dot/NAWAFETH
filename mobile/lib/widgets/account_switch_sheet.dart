import 'package:flutter/material.dart';

enum AccountMode { client, provider }

class AccountSwitchSheet extends StatelessWidget {
  final AccountMode current;
  final bool providerEnabled;

  const AccountSwitchSheet({
    super.key,
    required this.current,
    required this.providerEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CA1AF), Color(0xFF2C3E50)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تبديل الحساب',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'اختر الحساب الذي تريد استخدامه الآن',
                          style: TextStyle(fontFamily: 'Cairo', color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AccountChoiceCard(
                title: 'حساب العميل',
                subtitle: 'تصفح واطلب الخدمات',
                icon: Icons.person_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                selected: current == AccountMode.client,
                enabled: true,
                onTap: () => Navigator.pop(context, AccountMode.client),
              ),
              const SizedBox(height: 10),
              _AccountChoiceCard(
                title: 'حساب مقدم الخدمة',
                subtitle: providerEnabled ? 'إدارة خدماتك وطلباتك' : 'غير متاح — سجّل كمقدم خدمة أولاً',
                icon: Icons.storefront_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                selected: current == AccountMode.provider,
                enabled: providerEnabled,
                onTap: providerEnabled ? () => Navigator.pop(context, AccountMode.provider) : null,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _AccountChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: Colors.black.withValues(alpha: 0.18), width: 1.2)
        : Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled ? 1 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: border,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontFamily: 'Cairo', color: Colors.black54, fontSize: 12, height: 1.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  const Icon(Icons.check_circle, color: Color(0xFF2E7D32))
                else
                  const Icon(Icons.chevron_left, color: Colors.black45),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
