import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/home_service.dart';
import '../models/category_model.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import 'search_provider_screen.dart';
import 'urgent_request_screen.dart';
import 'request_quote_screen.dart';
import 'login_screen.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  List<CategoryModel> _categories = [];
  bool _loadingCats = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await HomeService.fetchCategories();
      if (mounted) setState(() { _categories = cats; _loadingCats = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _navigateWithAuth(BuildContext ctx, Widget screen) async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!ctx.mounted) return;
    if (!loggedIn) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => LoginScreen(redirectTo: screen)));
    } else {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = Colors.deepPurple;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5FA),
        drawer: const CustomDrawer(),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
        body: SafeArea(
          child: RefreshIndicator(
            color: purple,
            onRefresh: _loadCategories,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(child: _buildHeader(isDark, purple)),

                // ── Quick-action cards ──
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _actionCard(
                        isDark: isDark,
                        icon: Icons.search_rounded,
                        iconBg: purple.withValues(alpha: 0.1),
                        iconColor: purple,
                        title: 'البحث عن مزود خدمة',
                        subtitle: 'استعرض مزودي الخدمات حسب الموقع والتخصص.',
                        btnLabel: 'ابدأ البحث',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SearchProviderScreen())),
                      ),
                      const SizedBox(height: 10),
                      _actionCard(
                        isDark: isDark,
                        icon: Icons.bolt_rounded,
                        iconBg: Colors.orange.withValues(alpha: 0.12),
                        iconColor: Colors.orange.shade700,
                        title: 'طلب خدمة عاجلة',
                        subtitle: 'أرسل طلبًا عاجلًا وسيتم إشعار المزودين فورًا.',
                        btnLabel: 'طلب عاجل',
                        onTap: () => _navigateWithAuth(context, const UrgentRequestScreen()),
                      ),
                      const SizedBox(height: 10),
                      _actionCard(
                        isDark: isDark,
                        icon: Icons.request_quote_rounded,
                        iconBg: Colors.teal.withValues(alpha: 0.1),
                        iconColor: Colors.teal,
                        title: 'طلب عروض أسعار',
                        subtitle: 'صف خدمتك وانتظر عروضًا متعددة من المزودين.',
                        btnLabel: 'طلب عرض',
                        onTap: () => _navigateWithAuth(context, const RequestQuoteScreen()),
                      ),
                    ]),
                  ),
                ),

                // ── Categories section ──
                SliverToBoxAdapter(child: _buildCategoriesSection(isDark, purple)),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════

  Widget _buildHeader(bool isDark, Color purple) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [const Color(0xFFEDE7F6), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            children: [
              GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.menu_rounded, size: 18, color: isDark ? Colors.white70 : purple),
                ),
              ),
              const Spacer(),
              Text('إضافة خدمة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Cairo',
                      color: isDark ? Colors.white : Colors.black87)),
              const Spacer(),
              const SizedBox(width: 30),
            ],
          ),
          const SizedBox(height: 18),

          // Welcome
          Text('مرحباً بك في نوافذ!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Cairo',
                  color: isDark ? Colors.white : purple)),
          const SizedBox(height: 4),
          Text('اختر نوع الخدمة التي ترغب بطلبها:',
              style: TextStyle(fontSize: 11, fontFamily: 'Cairo',
                  color: isDark ? Colors.white60 : Colors.black54)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  ACTION CARD
  // ═══════════════════════════════════════

  Widget _actionCard({
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String btnLabel,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontFamily: 'Cairo',
                            color: isDark ? Colors.white54 : Colors.black45)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Button chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(btnLabel,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo', color: iconColor)),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_back_ios_new_rounded, size: 9, color: iconColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  CATEGORIES
  // ═══════════════════════════════════════

  Widget _buildCategoriesSection(bool isDark, Color purple) {
    if (_loadingCats) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: Colors.deepPurple, strokeWidth: 2)),
      );
    }
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التصنيفات المتاحة',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Cairo',
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchProviderScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : purple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : purple.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_catIcon(cat.name), size: 14, color: purple),
                      const SizedBox(width: 5),
                      Text(cat.name,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Cairo',
                              color: isDark ? Colors.white70 : Colors.black87)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _catIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('قانون') || n.contains('محام')) return Icons.gavel_rounded;
    if (n.contains('هندس')) return Icons.engineering_rounded;
    if (n.contains('تصميم')) return Icons.design_services_rounded;
    if (n.contains('توصيل')) return Icons.delivery_dining_rounded;
    if (n.contains('صح') || n.contains('طب')) return Icons.health_and_safety_rounded;
    if (n.contains('ترجم')) return Icons.translate_rounded;
    if (n.contains('برمج') || n.contains('تقن')) return Icons.code_rounded;
    if (n.contains('صيان')) return Icons.build_rounded;
    if (n.contains('رياض')) return Icons.fitness_center_rounded;
    if (n.contains('منزل')) return Icons.home_repair_service_rounded;
    if (n.contains('مال')) return Icons.attach_money_rounded;
    if (n.contains('تسويق')) return Icons.campaign_rounded;
    if (n.contains('تعليم') || n.contains('تدريب')) return Icons.school_rounded;
    if (n.contains('سيار') || n.contains('نقل')) return Icons.directions_car_rounded;
    if (n.contains('اتصال') || n.contains('شبك')) return Icons.cell_tower_rounded;
    return Icons.category_rounded;
  }
}
