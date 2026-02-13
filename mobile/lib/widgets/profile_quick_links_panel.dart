import 'package:flutter/material.dart';

import '../constants/colors.dart';

class ProfileQuickLinkItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const ProfileQuickLinkItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

class ProfileQuickLinksPanel extends StatelessWidget {
  final String title;
  final List<ProfileQuickLinkItem> items;

  const ProfileQuickLinksPanel({
    super.key,
    this.title = 'إعدادات سريعة',
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.softBlue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _itemTile(items[i]),
                if (i < items.length - 1)
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.20)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemTile(ProfileQuickLinkItem item) {
    return ListTile(
      onTap: item.onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.deepPurple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon, size: 20, color: AppColors.deepPurple),
      ),
      title: Text(
        item.title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: AppColors.softBlue,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }
}
