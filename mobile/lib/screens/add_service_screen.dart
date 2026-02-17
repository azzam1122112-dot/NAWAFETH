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
            title: 'نوع الخدمة',
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
                width: 220,
                height: 220,
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
                width: 240,
                height: 240,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = _ScreenMetrics.fromWidth(constraints.maxWidth);
                  final options = <_ServiceOptionData>[
                    _ServiceOptionData(
                      title: 'البحث عن مزود خدمة',
                      subtitle:
                          'استعرض مزودي الخدمة حسب الموقع والتقييم وسابقة الأعمال.',
                      badge: 'الأكثر استخداماً',
                      icon: Icons.travel_explore_rounded,
                      primary: const Color(0xFF5D4AA8),
                      secondary: const Color(0xFF7B63D2),
                      actionLabel: 'استعراض المزودين',
                      detail: 'انطلاقة سريعة',
                      onTap: () =>
                          _navigate(context, const SearchProviderScreen()),
                    ),
                    _ServiceOptionData(
                      title: 'طلب خدمة عاجلة',
                      subtitle:
                          'أرسل طلبًا فوريًا ليصل إلى المزودين القريبين والمتاحين الآن.',
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
                    _ServiceOptionData(
                      title: 'طلب عروض أسعار',
                      subtitle:
                          'صف احتياجك مرة واحدة واستلم عروضًا متعددة للمقارنة بثقة.',
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
                  ];

                  final optionWidgets = List<Widget>.generate(options.length, (
                    index,
                  ) {
                    final item = options[index];
                    final begin = 0.16 + (index * 0.18);
                    final end = ((begin + 0.45).clamp(0.0, 1.0)).toDouble();

                    return SizedBox(
                      width: metrics.cardWidth(constraints.maxWidth),
                      child: _StaggeredEntrance(
                        controller: _entranceController,
                        begin: begin,
                        end: end,
                        child: _ServiceOptionCard(
                          compact: metrics.compact,
                          title: item.title,
                          subtitle: item.subtitle,
                          badge: item.badge,
                          icon: item.icon,
                          primary: item.primary,
                          secondary: item.secondary,
                          actionLabel: item.actionLabel,
                          detail: item.detail,
                          onTap: item.onTap,
                        ),
                      ),
                    );
                  });

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      metrics.horizontalPadding,
                      12,
                      metrics.horizontalPadding,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StaggeredEntrance(
                          controller: _entranceController,
                          begin: 0.00,
                          end: 0.34,
                          child: _HeroPanel(compact: metrics.compact),
                        ),
                        SizedBox(height: metrics.gap),
                        Wrap(
                          spacing: metrics.gap,
                          runSpacing: metrics.gap,
                          children: optionWidgets,
                        ),
                      ],
                    ),
                  );
                },
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
  const _HeroPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 12 : 14,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
                width: compact ? 36 : 40,
                height: compact ? 36 : 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.26),
                  ),
                ),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                  size: compact ? 20 : 22,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Text(
                  'ابدأ طلبك',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            'اختر نوع الخدمة وابدأ طلبك بخطوات واضحة وسريعة.',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: compact ? 11 : 12,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Wrap(
            spacing: compact ? 6 : 8,
            runSpacing: compact ? 6 : 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ServiceOptionCard extends StatelessWidget {
  const _ServiceOptionCard({
    required this.compact,
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

  final bool compact;
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7E3F4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251A4F).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 10 : 11,
                  compact ? 8 : 9,
                  compact ? 10 : 11,
                  compact ? 8 : 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
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
                      width: compact ? 32 : 34,
                      height: compact ? 32 : 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: compact ? 17 : 18),
                    ),
                    SizedBox(width: compact ? 7 : 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 7 : 8,
                        vertical: compact ? 3 : 4,
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
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: compact ? 9 : 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 10 : 11,
                  compact ? 9 : 10,
                  compact ? 10 : 11,
                  compact ? 10 : 11,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: compact ? 11 : 12,
                        color: Color(0xFF5B5670),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 8 : 9,
                            vertical: compact ? 4 : 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F0FD),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            detail,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: compact ? 10 : 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5A489B),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onTap,
                          style: TextButton.styleFrom(
                            foregroundColor: primary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            textStyle: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            size: compact ? 16 : 17,
                          ),
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

class _ServiceOptionData {
  const _ServiceOptionData({
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
}

class _ScreenMetrics {
  const _ScreenMetrics({
    required this.compact,
    required this.twoColumns,
    required this.horizontalPadding,
    required this.gap,
  });

  final bool compact;
  final bool twoColumns;
  final double horizontalPadding;
  final double gap;

  static _ScreenMetrics fromWidth(double width) {
    final compact = width < 390;
    final twoColumns = width >= 700;
    return _ScreenMetrics(
      compact: compact,
      twoColumns: twoColumns,
      horizontalPadding: twoColumns ? 20 : (compact ? 10 : 12),
      gap: twoColumns ? 12 : 10,
    );
  }

  double cardWidth(double maxWidth) {
    if (!twoColumns) return maxWidth - (horizontalPadding * 2);
    final available = maxWidth - (horizontalPadding * 2) - gap;
    return available / 2;
  }
}
