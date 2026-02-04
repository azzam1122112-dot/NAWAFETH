import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import 'search_provider_screen.dart';
import 'urgent_request_screen.dart';
import 'request_quote_screen.dart';
import '../widgets/custom_drawer.dart';
import '../utils/auth_guard.dart';

class AddServiceScreen extends StatelessWidget {
  const AddServiceScreen({super.key});

  Future<void> _navigate(BuildContext context, Widget screen, {bool requireFullClient = false}) async {
    if (requireFullClient) {
      final ok = await checkFullClient(context);
      if (!ok) return;
    }
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF8F9FD),
        drawer: const CustomDrawer(),
        appBar: const CustomAppBar(title: "طلب خدمة جديدة"),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section مع تصميم احترافي
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            Colors.deepPurple.shade800,
                            Colors.deepPurple.shade700,
                          ]
                        : [
                            const Color(0xFF6A35FF),
                            const Color(0xFF8B5CF6),
                          ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepPurple.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              '✨',
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "مرحباً بك في نوافذ",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "اختر طريقة طلب الخدمة المناسبة لك",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Cairo',
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // قائمة البطاقات المحسّنة
              _buildEnhancedServiceCard(
                context,
                onTap: () => _navigate(context, const SearchProviderScreen()),
                emoji: "🔍",
                title: "البحث عن مزود خدمة",
                description: "استعرض مزودي الخدمات حسب الموقع والتخصص وتقييماتهم",
                buttonLabel: "ابدأ البحث",
                gradientColors: isDark
                    ? [Colors.blue.shade700, Colors.cyan.shade700]
                    : [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
              ),
              const SizedBox(height: 16),

              _buildEnhancedServiceCard(
                context,
                onTap: () => _navigate(
                  context,
                  const UrgentRequestScreen(),
                  requireFullClient: true,
                ),
                emoji: "⚡",
                title: "طلب خدمة عاجلة",
                description: "أرسل طلبًا عاجلًا وسيتم إشعار مزودي الخدمة فورًا",
                buttonLabel: "طلب عاجل",
                gradientColors: isDark
                    ? [Colors.orange.shade700, Colors.deepOrange.shade700]
                    : [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
              ),
              const SizedBox(height: 16),

              _buildEnhancedServiceCard(
                context,
                onTap: () => _navigate(
                  context,
                  const RequestQuoteScreen(),
                  requireFullClient: true,
                ),
                emoji: "💼",
                title: "طلب عروض أسعار",
                description: "صف خدمتك وانتظر عروض متعددة من مزودي الخدمة",
                buttonLabel: "طلب عرض",
                gradientColors: isDark
                    ? [Colors.green.shade700, Colors.teal.shade700]
                    : [const Color(0xFF10B981), const Color(0xFF14B8A6)],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------------------
  // 🟣 بطاقة احترافية محسّنة مع تدرجات لونية
  // -----------------------------------------
  Widget _buildEnhancedServiceCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onTap,
    required List<Color> gradientColors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Pattern decoration
            Positioned(
              top: -20,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
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
