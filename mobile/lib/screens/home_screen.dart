import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_bar.dart';
import '../widgets/banner_widget.dart';
import '../widgets/video_reels.dart';
import '../widgets/provider_media_grid.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/profiles_slider.dart' as profiles;
import '../widgets/intro_welcome_dialog.dart';
import '../services/home_feed_service.dart';
import '../widgets/nawafeth_mark.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _introLastShownKey = 'intro_last_shown_yyyy_mm_dd';
  static bool _introCheckedThisSession = false;

  @override
  void initState() {
    super.initState();
    _warmupHomeFeed();
    _maybeShowIntroDialogOncePerDay();
  }

  void _warmupHomeFeed() {
    final feed = HomeFeedService.instance;
    Future(() async {
      await Future.wait([
        feed.getTopProviders(limit: 20),
        feed.getBannerItems(limit: 6),
        feed.getMediaItems(limit: 12),
        feed.getTestimonials(limit: 8),
      ]);
    });
  }

  static String _formatDayKey(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _maybeShowIntroDialogOncePerDay() async {
    if (_introCheckedThisSession) return;
    _introCheckedThisSession = true;

    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatDayKey(DateTime.now());
    final lastShown = prefs.getString(_introLastShownKey);
    if (lastShown == todayKey) return;

    // Mark as shown for today as soon as we decide to display it.
    await prefs.setString(_introLastShownKey, todayKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'intro',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 400),
        transitionBuilder: (ctx, anim, secondAnim, child) {
          return ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        pageBuilder: (ctx, anim, secondAnim) {
          return const IntroWelcomeDialog();
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1F5),
      drawer: const CustomDrawer(),

      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC2C0066), // بنفسجي غامق شفاف
                Color(0x002C0066),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  // القائمة على اليسار
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const Spacer(),
                  const _NawafethMark(),
                  const Spacer(),
                  // التنبيهات على اليمين
                  const NotificationsIconButton(iconColor: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),

      body: const SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 6,
          bottom: 140,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── الإعلانات والبانر ─────────────────────────────────
            SizedBox(height: 292, child: BannerWidget()),
            // ─── عروض الفيديو ────────────────────────────────────────
            _SectionHeader(title: 'عروض الفيديو', icon: Icons.play_circle_outline_rounded),
            VideoReels(),
            // ─── مزودو الخدمة ────────────────────────────────────────
            _SectionHeader(title: 'مزودو الخدمة', icon: Icons.people_alt_outlined),
            profiles.ProfilesSlider(),
            // ─── معرض الأعمال ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _SectionHeader(title: 'معرض الأعمال والإعلانات', icon: Icons.photo_library_outlined),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProviderMediaGrid(),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: const CustomBottomNav(
        currentIndex: 0,
      ),
    );
  }
}

class _NawafethMark extends StatelessWidget {
  const _NawafethMark();

  @override
  Widget build(BuildContext context) {
    return const NawafethMark();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF6A0DAD).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF6A0DAD), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C0066),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A0DAD).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
