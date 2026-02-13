import 'package:flutter/material.dart';
import '../widgets/app_bar.dart';
import '../widgets/banner_widget.dart';
import '../widgets/video_reels.dart';
import '../widgets/service_grid.dart';
import '../widgets/testimonials_slider.dart';
import '../widgets/provider_media_grid.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/profiles_slider.dart' as profiles;
import '../services/home_feed_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _warmupHomeFeed();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const CustomDrawer(), // ✅ فتح القائمة من اليسار

      extendBody: true,
      extendBodyBehindAppBar: true,

      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: CustomAppBar(
          showSearchField: false,
          forceDrawerIcon: true, // ✅ إجبار إظهار أيقونة القائمة دائماً
        ),
      ),

      body: const SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 0,
          bottom: 140, // ✅ لضمان عدم اختفاء المحتوى خلف الشريط السفلي
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ البنر
            SizedBox(height: 320, child: BannerWidget()),

            // ✅ الريلز بدون هوامش
            VideoReels(),

            // ✅ البروفايلات أيضاً بدون هوامش
            profiles.ProfilesSlider(),

            // ✅ باقي المحتوى داخل حواف ثابتة
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 6),
                  ProviderMediaGrid(),
                  SizedBox(height: 12),
                  ServiceGrid(),
                  SizedBox(height: 12),
                  TestimonialsSlider(),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
    );
  }
}
