import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_texts.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/login_settings_screen.dart';
import '../screens/twofa_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/about_screen.dart';
import '../screens/contact_screen.dart';
import '../main.dart';
import '../services/session_storage.dart';
import '../utils/local_user_state.dart';
import '../services/account_api.dart';
import '../services/app_snackbar.dart';
import '../services/account_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SessionInfo {
  final bool loggedIn;
  final String? fullName;
  final String? username;
  final String? phone;

  const _SessionInfo({required this.loggedIn, this.fullName, this.username, this.phone});
}

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String selectedLanguage = "ar";

  Future<bool> _loadIsProviderRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('isProviderRegistered') ?? false) == true;
  }

  Future<_SessionInfo> _loadSessionInfo() async {
    const storage = SessionStorage();
    final loggedIn = await storage.isLoggedIn();
    final phone = (await storage.readPhone())?.trim();
    final username = (await storage.readUsername())?.trim();
    final fullName = (await storage.readFullName())?.trim();
    return _SessionInfo(
      loggedIn: loggedIn,
      phone: (phone == null || phone.isEmpty) ? null : phone,
      username: (username == null || username.isEmpty) ? null : username,
      fullName: (fullName == null || fullName.isEmpty) ? null : fullName,
    );
  }

  Future<void> _logout() async {
    await LocalUserState.clearOnLogout();
    await const SessionStorage().clear();
    if (!mounted) return;
    setState(() {});
    Navigator.of(context).pushNamedAndRemoveUntil('/entry', (r) => false);
  }

  Future<void> _deleteAccount() async {
    final access = await const SessionStorage().readAccessToken();
    if (access == null || access.trim().isEmpty) {
      await _logout();
      return;
    }

    try {
      await AccountApi().deleteMe(accessToken: access);
      final fullName = (await const SessionStorage().readFullName())?.trim();
      final username = (await const SessionStorage().readUsername())?.trim();
      final name = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : ((username != null && username.isNotEmpty) ? username : null);

      AppSnackBar.success(name == null ? 'تم حذف الحساب بنجاح. نأسف لرحيلك.' : 'تم حذف حسابك بنجاح يا $name. نأسف لرحيلك.');
    } catch (e) {
      AppSnackBar.error('تعذر حذف الحساب. حاول مرة أخرى لاحقاً.');
      return;
    }

    await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final themeController = MyThemeController.of(context);
    final isDarkMode = themeController?.themeMode == ThemeMode.dark;

    return FutureBuilder<_SessionInfo>(
      future: _loadSessionInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data ?? const _SessionInfo(loggedIn: false);
        final displayName = info.loggedIn
            ? (info.fullName ?? info.username ?? 'أهلاً بك')
            : 'مرحباً زائرنا الكريم';
        final handleText = (info.loggedIn && info.username != null) ? '@${info.username}' : '';

        return Drawer(
          backgroundColor: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
          // ✅ رأس القائمة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 60,
              right: 20,
              left: 20,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.deepPurple.withOpacity(0.15)
                      : Colors.deepPurple.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 👤 معلومات
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        color: isDark ? Colors.white : AppColors.primaryDark,
                      ),
                    ),
                    if (handleText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        handleText,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Cairo',
                          color: isDark ? Colors.grey[300] : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
                Column(
                  children: [
                    Switch(
                      value: isDarkMode,
                      activeColor: AppColors.primaryDark,
                      onChanged: (val) {
                        final mode = val ? ThemeMode.dark : ThemeMode.light;
                        themeController?.changeTheme(mode);
                      },
                    ),
                    Text(
                      isDarkMode ? "النمط الليلي" : "النمط النهاري",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Cairo',
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : const Color(0xFFE0E0E0),
          ),

          // ✅ عناصر القائمة
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              children: [
                if (!info.loggedIn)
                  _buildDrawerItem(
                    icon: Icons.login,
                    label: 'تسجيل الدخول',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(redirectTo: HomeScreen()),
                        ),
                      );
                    },
                    isDark: isDark,
                  ),
                _buildDrawerItem(
                  icon: Icons.home_outlined,
                  label: AppTexts.getText(context, "home"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  },
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  label: AppTexts.getText(context, "settings"),
                  onTap: () {
                    Navigator.pop(context); // إغلاق الـ Drawer
                    Future.delayed(const Duration(milliseconds: 100), () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FutureBuilder<String?>(
                            future: const SessionStorage().readPhone(),
                            builder: (context, snap) {
                              final phone = (snap.data ?? '').trim();
                              if (!info.loggedIn || phone.isEmpty) {
                                return const LoginScreen(redirectTo: LoginSettingsScreen());
                              }
                              return TwoFAScreen(
                                phone: phone,
                                redirectTo: const LoginSettingsScreen(),
                              );
                            },
                          ),
                        ),
                      );
                    });
                  },
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  icon: Icons.language,
                  label: AppTexts.getText(context, "language"),
                  onTap: () => _showLanguageDialog(),
                  isDark: isDark,
                ),
                FutureBuilder<bool>(
                  future: _loadIsProviderRegistered(),
                  builder: (context, providerSnap) {
                    final canShowProvider = providerSnap.data == true;
                    if (!canShowProvider) return const SizedBox.shrink();

                    return _buildDrawerItem(
                      icon: Icons.swap_horiz_rounded,
                      label: AppTexts.getText(context, "switch_account"),
                      onTap: () {
                        Navigator.pop(context); // إغلاق الـ Drawer
                        Future.delayed(const Duration(milliseconds: 100), () async {
                          await AccountSwitcher.show(context);
                        });
                      },
                      isDark: isDark,
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.article_outlined,
                  label: AppTexts.getText(context, "terms"),
                  onTap: () {
                    Navigator.pop(context); // إغلاق الـ Drawer
                    Future.delayed(const Duration(milliseconds: 100), () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                      );
                    });
                  },
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  icon: Icons.support_agent,
                  label: AppTexts.getText(context, "support"),
                  onTap: () {
                    Navigator.pop(context); // إغلاق الـ Drawer
                    Future.delayed(const Duration(milliseconds: 100), () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ContactScreen()),
                      );
                    });
                  },
                  isDark: isDark,
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  label: AppTexts.getText(context, "about"),
                  onTap: () {
                    Navigator.pop(context); // إغلاق الـ Drawer
                    Future.delayed(const Duration(milliseconds: 100), () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    });
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : const Color(0xFFE0E0E0),
          ),

          // ✅ أزرار أسفل
          if (info.loggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _buildActionBtn(
                    text: AppTexts.getText(context, "logout"),
                    color: AppColors.primaryDark,
                    onPressed: _logout,
                  ),
                  const SizedBox(height: 10),
                  _buildActionBtn(
                    text: AppTexts.getText(context, "delete"),
                    color: Colors.red.shade600,
                    onPressed: () => _showDeleteConfirmDialog(context),
                  ),
                ],
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  /// ✅ نافذة اختيار اللغة
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final themeController = MyThemeController.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "🌐 اختر اللغة",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _languageOption("ar", "🇸🇦", "العربية", themeController),
              const SizedBox(height: 10),
              _languageOption("en", "🇺🇸", "English", themeController),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "⚠️ تأكيد حذف الحساب",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: const Text(
            "سيتم حذف الحساب نهائياً. هل أنت متأكد؟",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
          actions: [
            TextButton(
              child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                "تأكيد الحذف",
                style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _languageOption(
    String code,
    String flag,
    String title,
    MyThemeController? controller,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Text(flag, style: const TextStyle(fontSize: 24)),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo')),
        trailing:
            selectedLanguage == code
                ? const Icon(Icons.check_circle, color: Colors.deepPurple)
                : null,
        onTap: () {
          setState(() => selectedLanguage = code);
          Navigator.pop(context);
          if (code == "ar") {
            controller?.changeLanguage(const Locale('ar', 'SA'));
          } else {
            controller?.changeLanguage(const Locale('en', 'US'));
          }
        },
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(
        icon,
        color: isDark ? Colors.white70 : AppColors.primaryDark,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: AppColors.primaryDark.withOpacity(0.08),
    );
  }

  Widget _buildActionBtn({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
