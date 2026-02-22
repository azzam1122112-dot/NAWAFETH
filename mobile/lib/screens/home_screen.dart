import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_bar.dart';
import '../widgets/banner_widget.dart';
import '../widgets/video_reels.dart';
import '../widgets/provider_media_grid.dart';
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0x14000000), width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const NotificationsIconButton(iconColor: Color(0xFF7C2A90)),
                  const Spacer(),
                  const _NawafethMark(),
                  const Spacer(),
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Color(0xFF7C2A90)),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: const SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 10,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(height: 255, child: BannerWidget()),
            ),
            SizedBox(height: 8),
            VideoReels(),
            SizedBox(height: 6),
            profiles.ProfilesSlider(),
            SizedBox(height: 8),
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
