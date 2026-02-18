import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/role_controller.dart';
import '../utils/auth_guard.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool homeVariant;

  const CustomBottomNav({
    required this.currentIndex,
    this.homeVariant = false,
    super.key,
  });

  Future<void> _navigate(BuildContext context, int index) async {
    if (currentIndex >= 0 && index == currentIndex) return;
    final role = RoleController.instance.notifier.value;
    if (!homeVariant && index == 1 && role.isProvider) return;

    // Guard profile and secondary tabs
    if (index == 1 || index == 3) {
      if (!await checkAuth(context)) return;
    }

    if (!context.mounted) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        if (homeVariant) {
          Navigator.pushNamed(context, '/chats');
        } else {
          Navigator.pushReplacementNamed(context, '/orders');
        }
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/interactive');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  void _onAddServicePressed(BuildContext context) {
    Navigator.pushNamed(context, '/add_service');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<RoleState>(
      valueListenable: RoleController.instance.notifier,
      builder: (context, role, _) {
        final disableOrders = !homeVariant && role.isProvider;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // ✅ الشريط السفلي بخلفية منحنية ومرتبة
            ClipPath(
              clipper: CurvedNotchClipper(),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.08 * 255).toInt()),
                      blurRadius: 20,
                      spreadRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconWithLabel(
                      icon: Icons.home,
                      label: "الرئيسية",
                      selected: currentIndex == 0,
                      onTap: () => _navigate(context, 0),
                    ),
                    IconWithLabel(
                      icon: homeVariant
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.list_alt,
                      label: homeVariant ? "محادثاتي" : "طلباتي",
                      selected: currentIndex == 1,
                      enabled: !disableOrders,
                      onTap: () => _navigate(context, 1),
                    ),
                    const SizedBox(width: 40),
                    IconWithLabel(
                      icon: Icons.group,
                      label: "تفاعلي",
                      selected: currentIndex == 2,
                      onTap: () => _navigate(context, 2),
                    ),
                    IconWithLabel(
                      icon: Icons.person,
                      label: "نافذتي",
                      selected: currentIndex == 3,
                      onTap: () => _navigate(context, 3),
                    ),
                  ],
                ),
              ),
            ),
            if (currentIndex == 0)
              Positioned(
                bottom: 28,
                child: GestureDetector(
                  onTap: () => _onAddServicePressed(context),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0x40DA52FF),
                              Colors.transparent,
                            ],
                            radius: 0.6,
                          ),
                        ),
                      ),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            const BoxShadow(
                              color: Color(0x4DFF0000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 24, color: Colors.white),
                            SizedBox(height: 2),
                            Text(
                              "خدمة",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class IconWithLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const IconWithLabel({
    required this.icon,
    required this.label,
    required this.selected,
    this.enabled = true,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color activeColor = AppColors.accentOrange;
    final Color defaultColor = isDark ? Colors.white70 : AppColors.deepPurple;
    final Color disabledColor = isDark ? Colors.white24 : Colors.black26;

    final Color contentColor = enabled
        ? (selected ? activeColor : defaultColor)
        : disabledColor;

    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 28,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? activeColor.withAlpha(28) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: contentColor, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CurvedNotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const notchRadius = 38.0;
    final center = size.width / 2;

    path.lineTo(center - notchRadius * 1.8, 0);
    path.quadraticBezierTo(
      center - notchRadius,
      0,
      center - notchRadius * 0.95,
      notchRadius * 0.6,
    );
    path.arcToPoint(
      Offset(center + notchRadius * 0.95, notchRadius * 0.6),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(
      center + notchRadius,
      0,
      center + notchRadius * 1.8,
      0,
    );
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
