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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: AppBar(
            backgroundColor: isDark ? Colors.grey[850] : Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Column(
              children: [
                const Text(
                  "🌟 اطلب خدمتك الآن",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  "اختر الطريقة المناسبة لك",
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // عنوان القسم
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF6366F1),
                            const Color(0xFF8B5CF6),
                          ]
                        : [
                            const Color(0xFF6366F1),
                            const Color(0xFFA855F7),
                          ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '🎯',
                          style: TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ابدأ رحلتك مع نوافذ",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "اختر الطريقة التي تناسب احتياجك وسنساعدك في إيجاد أفضل مزودي الخدمات",
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              fontFamily: 'Cairo',
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                // Pattern decoration - Circles
                Positioned(
                  top: -40,
                  left: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  right: -50,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  top: 30,
                  right: 30,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon & Title Row
                      Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 36),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.8,
                          fontFamily: 'Cairo',
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              buttonLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
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
        ),
      ),
    );
  }
}
