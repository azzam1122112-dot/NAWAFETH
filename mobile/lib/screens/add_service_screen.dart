import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../utils/auth_guard.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import 'request_quote_screen.dart';
import 'search_provider_screen.dart';
import 'urgent_request_screen.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _navigate(
    BuildContext context,
    Widget screen, {
    bool requireFullClient = false,
  }) async {
    if (requireFullClient) {
      final ok = await checkFullClient(context);
      if (!ok) return;
    }

    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F6FB),
        drawer: const CustomDrawer(),
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: CustomAppBar(
            title: 'اختيار نوع الخدمة',
            showSearchField: false,
            forceDrawerIcon: true,
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
        body: Stack(
          children: [
            Positioned(
              top: -120,
              right: -90,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark.withValues(alpha: 0.16),
                      AppColors.primaryLight.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentOrange.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StaggeredEntrance(
                      controller: _entranceController,
                      begin: 0.00,
                      end: 0.35,
                      child: const _HeroPanel(),
                    ),
                    const SizedBox(height: 14),
                    _StaggeredEntrance(
                      controller: _entranceController,
                      begin: 0.18,
                      end: 0.54,
                      child: _ServiceOptionCard(
                        title: 'البحث عن مزود خدمة',
                        subtitle:
                            'استعرض مزودي الخدمة حسب الموقع، التقييم، وسابقة الأعمال ثم ابدأ مباشرة.',
                        badge: 'الأكثر استخداماً',
                        icon: Icons.travel_explore_rounded,
                        primary: const Color(0xFF5D4AA8),
                        secondary: const Color(0xFF7B63D2),
                        actionLabel: 'استعراض المزودين',
                        detail: 'انطلاقة سريعة',
                        onTap: () =>
                            _navigate(context, const SearchProviderScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StaggeredEntrance(
                      controller: _entranceController,
                      begin: 0.34,
                      end: 0.72,
                      child: _ServiceOptionCard(
                        title: 'طلب خدمة عاجلة',
                        subtitle:
                            'أرسل طلباً فورياً ليصل إلى مزودي الخدمة القريبين والمتاحين الآن.',
                        badge: 'استجابة فورية',
                        icon: Icons.bolt_rounded,
                        primary: const Color(0xFFF1973D),
                        secondary: const Color(0xFFDE6A22),
                        actionLabel: 'إنشاء طلب عاجل',
                        detail: 'للحالات المستعجلة',
                        onTap: () => _navigate(
                          context,
                          const UrgentRequestScreen(),
                          requireFullClient: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StaggeredEntrance(
                      controller: _entranceController,
                      begin: 0.52,
                      end: 1.00,
                      child: _ServiceOptionCard(
                        title: 'طلب عروض أسعار',
                        subtitle:
                            'صف احتياجك مرة واحدة واستلم عدة عروض لتقارن الجودة والتكلفة بثقة.',
                        badge: 'أفضل للتفاوض',
                        icon: Icons.request_quote_rounded,
                        primary: const Color(0xFF2D8B7B),
                        secondary: const Color(0xFF1F6B5F),
                        actionLabel: 'طلب عروض الآن',
                        detail: 'مقارنة ذكية',
                        onTap: () => _navigate(
                          context,
                          const RequestQuoteScreen(),
                          requireFullClient: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
  });

  final AnimationController controller;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.11),
      end: Offset.zero,
    ).animate(curved);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B479D), Color(0xFF7A63CA)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B479D).withValues(alpha: 0.26),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.26),
                  ),
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ابدأ طلبك بالطريقة الأنسب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'اختر نوع الخدمة أولاً ثم أكمل الطلب بخطوات بسيطة. كل خيار مصمم لحالة استخدام مختلفة.',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroChip(label: 'مسار واضح'),
              _HeroChip(label: 'سرعة في التنفيذ'),
              _HeroChip(label: 'نتائج أدق'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ServiceOptionCard extends StatelessWidget {
  const _ServiceOptionCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.actionLabel,
    required this.detail,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final String actionLabel;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7E3F4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251A4F).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                  gradient: LinearGradient(
                    colors: [primary, secondary],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: Color(0xFF5B5670),
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F0FD),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            detail,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5A489B),
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onTap,
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            textStyle: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          label: Text(actionLabel),
                        ),
                      ],
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
}
