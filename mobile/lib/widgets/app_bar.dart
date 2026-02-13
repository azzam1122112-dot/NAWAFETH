import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/chat_nav.dart';
import '../services/notifications_badge_controller.dart';

class NotificationsIconButton extends StatefulWidget {
  final Color iconColor;

  const NotificationsIconButton({super.key, required this.iconColor});

  @override
  State<NotificationsIconButton> createState() => _NotificationsIconButtonState();
}

class _NotificationsIconButtonState extends State<NotificationsIconButton> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: NotificationsBadgeController.instance.unreadNotifier,
      builder: (context, unread, _) {
        final showBadge = unread != null && unread > 0;
        final label = (unread ?? 0) > 99 ? '99+' : (unread ?? 0).toString();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_none,
                color: widget.iconColor,
              ),
              onPressed: () async {
                await Navigator.pushNamed(context, '/notifications');
                await NotificationsBadgeController.instance.refresh();
              },
            ),
            if (showBadge)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showSearchField;
  final bool showBackButton;
  final bool forceDrawerIcon; // جديد: لإجبار إظهار أيقونة القائمة بدلاً من الرجوع

  const CustomAppBar({
    super.key,
    this.title,
    this.showSearchField = true,
    this.showBackButton = false,
    this.forceDrawerIcon = false, // افتراضياً false
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : AppColors.primaryDark;
    
    // ✅ تحديد ما إذا كان يجب إظهار زر العودة تلقائياً
    // إذا كان forceDrawerIcon = true، لا تظهر زر الرجوع أبداً
    final bool canPop = Navigator.of(context).canPop();
    final bool shouldShowBack = !forceDrawerIcon && (showBackButton || canPop);

    return SafeArea(
      bottom: false,
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        titleSpacing: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // ✅ زر العودة أو القائمة الجانبية
              if (shouldShowBack)
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: iconColor,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              else
                Builder(
                  builder:
                      (context) => IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: iconColor,
                        ),
                        onPressed: () {
                          final scaffold = Scaffold.maybeOf(context);
                          if (scaffold?.hasDrawer ?? false) {
                            scaffold!.openDrawer();
                          } else {
                            debugPrint('❗ Scaffold لا يحتوي على drawer');
                          }
                        },
                      ),
                ),

              const SizedBox(width: 12),

              // ✅ عنوان أو حقل بحث
              if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: isDark ? Colors.white : AppColors.deepPurple,
                    ),
                  ),
                )
              else if (showSearchField)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/search_provider');
                      },
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.1)
                              : const Color.fromRGBO(255, 255, 255, 0.15),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : const Color.fromRGBO(103, 58, 183, 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 20,
                              color: isDark ? Colors.white70 : AppColors.deepPurple,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'بحث...',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : AppColors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              const Spacer(),

              // ✅ أيقونة الإشعارات
              NotificationsIconButton(iconColor: iconColor),

              const SizedBox(width: 8),

              // ✅ المحادثات داخل التطبيق (بديل شعار التطبيق)
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: iconColor),
                onPressed: () {
                  ChatNav.openInbox(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

