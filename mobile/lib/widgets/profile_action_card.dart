import 'package:flutter/material.dart';

import '../constants/colors.dart';

class ProfileActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final bool compact;

  const ProfileActionCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.accent = AppColors.deepPurple,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = (subtitle ?? '').trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 14 : 16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 44 : 46,
                  height: compact ? 44 : 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.70),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: compact ? 22 : 24),
                ),
                SizedBox(height: compact ? 10 : 14),
                Text(
                  title,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.softBlue,
                  ),
                ),
                if (!compact && hasSubtitle) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!.trim(),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                ],
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
