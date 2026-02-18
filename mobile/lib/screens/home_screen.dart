import 'package:flutter/material.dart';
import '../widgets/app_bar.dart';
import '../widgets/banner_widget.dart';
import '../widgets/video_reels.dart';
import '../widgets/provider_media_grid.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/profiles_slider.dart' as profiles;
import '../widgets/intro_welcome_dialog.dart';
import '../services/home_feed_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _introShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _warmupHomeFeed();
    _showIntroDialogOnce();
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

  void _showIntroDialogOnce() {
    if (_introShownThisSession) return;
    _introShownThisSession = true;

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
    final theme = Theme.of(context);
    final iconColor =
        theme.brightness == Brightness.dark ? Colors.white : Colors.deepPurple;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F1F5),
      drawer: const CustomDrawer(),

      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                NotificationsIconButton(iconColor: iconColor),
                const Spacer(),
                const _NawafethMark(),
                const Spacer(),
                Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu_rounded, color: iconColor),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ],
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
            SizedBox(height: 292, child: BannerWidget()),
            VideoReels(),
            profiles.ProfilesSlider(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        homeVariant: true,
      ),
    );
  }
}

class _NawafethMark extends StatelessWidget {
  const _NawafethMark();

  @override
  Widget build(BuildContext context) {
    Widget chip(Color c) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip(const Color(0xFFE97885)),
            const SizedBox(width: 3),
            chip(const Color(0xFFF2B24C)),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip(const Color(0xFFB68DF6)),
            const SizedBox(width: 3),
            chip(const Color(0xFF7DB2F8)),
          ],
        ),
      ],
    );
  }
}
