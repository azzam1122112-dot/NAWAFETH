import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import 'search_provider_screen.dart';
import 'urgent_request_screen.dart';
import 'request_quote_screen.dart';
import 'login_screen.dart';
import '../widgets/custom_drawer.dart';

class AddServiceScreen extends StatelessWidget {
  const AddServiceScreen({super.key});

  void _navigateWithAuth(
    BuildContext context,
    Widget screen, {
    bool requireLogin = false,
  }) {
    const bool isLoggedIn = false; // لاحقاً يتم ربطه بالنظام الحقيقي

    if (requireLogin && !isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(redirectTo: screen)),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: const CustomDrawer(),
        appBar: const CustomAppBar(title: "إضافة خدمة"),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "مرحباً بك في منصة نوافذ!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white : AppColors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "اختر نوع الخدمة التي ترغب بطلبها:",
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // قائمة البطاقات
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildServiceCard(
                      context,
                      onTap:
                          () => _navigateWithAuth(
                            context,
                            const SearchProviderScreen(),
                          ),
                      title: "🔎 البحث عن مزود خدمة",
                      description:
                          "استعرض مزودي الخدمات حسب الموقع والتخصص وتقييماتهم.",
                      buttonLabel: "ابدأ البحث",
                    ),
                    const SizedBox(height: 16),

                    _buildServiceCard(
                      context,
                      onTap:
                          () => _navigateWithAuth(
                            context,
                            const UrgentRequestScreen(),
                            requireLogin: true,
                          ),
                      title: "⚡ طلب خدمة عاجلة",
                      description:
                          "أرسل طلبًا عاجلًا وسيتم إشعار مزودي الخدمة فورًا.",
                      buttonLabel: "طلب عاجل",
                    ),
                    const SizedBox(height: 16),

                    _buildServiceCard(
                      context,
                      onTap:
                          () => _navigateWithAuth(
                            context,
                            const RequestQuoteScreen(),
                            requireLogin: true,
                          ),
                      title: "📨 طلب عروض أسعار",
                      description:
                          "صف خدمتك وانتظر عروض متعددة من مزودي الخدمة.",
                      buttonLabel: "طلب عرض",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------
  // 🟣 بطاقة احترافية قابلة للنقر بالكامل
  // -----------------------------------------
  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: AppColors.deepPurple.withOpacity(0.08),
      highlightColor: AppColors.deepPurple.withOpacity(0.05),

      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withAlpha(30)
                  : Colors.deepPurple.withAlpha(18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // الوصف
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontFamily: 'Cairo',
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 14),

            // زر (للتأكيد البصري فقط — التفعيل على كامل البطاقة)
            Container(
              decoration: BoxDecoration(
                color: isDark 
                  ? Colors.deepPurple.shade700.withOpacity(0.9)
                  : AppColors.deepPurple.withOpacity(0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    buttonLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
