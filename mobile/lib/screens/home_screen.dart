import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/video_full_screen.dart';
import '../services/api_client.dart';
import '../services/home_service.dart';
import '../models/category_model.dart';
import '../models/banner_model.dart';
import '../models/provider_public_model.dart';

import 'search_provider_screen.dart';
import 'provider_profile_screen.dart';
import 'notifications_screen.dart';
import 'my_chats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // -- Data --
  List<CategoryModel> _categories = [];
  List<ProviderPublicModel> _providers = [];
  List<BannerModel> _banners = [];
  bool _isLoading = true;

  // -- Banner video --
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  // -- Reels auto scroll --
  final ScrollController _reelsScroll = ScrollController();
  Timer? _reelsTimer;
  double _reelsPos = 0;

  static const _reelLogos = [
    'assets/images/32.jpeg',
    'assets/images/841015.jpeg',
    'assets/images/879797.jpeg',
  ];
  static const _reelVideoPaths = [
    'assets/videos/1.mp4',
    'assets/videos/2.mp4',
    'assets/videos/3.mp4',
    'assets/videos/4.mp4',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideo();
    _loadData();
    _startReelsScroll();
  }

  void _initVideo() {
    _videoController = VideoPlayerController.asset('assets/videos/V16.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) { setState(() => _videoReady = true); _videoController!.play(); }
      });
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    final results = await Future.wait([
      HomeService.fetchCategories(),
      HomeService.fetchFeaturedProviders(limit: 10),
      HomeService.fetchHomeBanners(limit: 6),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<CategoryModel>;
      _providers = results[1] as List<ProviderPublicModel>;
      _banners = results[2] as List<BannerModel>;
      _isLoading = false;
    });
  }

  void _startReelsScroll() {
    _reelsTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_reelsScroll.hasClients && mounted) {
        _reelsPos += 1.0;
        final half = _reelsScroll.position.maxScrollExtent / 2;
        if (_reelsPos >= half) { _reelsScroll.jumpTo(0); _reelsPos = 0; }
        else { _reelsScroll.jumpTo(_reelsPos); }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_videoController == null || !_videoReady) return;
    if (state == AppLifecycleState.resumed) { _videoController!.play(); }
    else if (state == AppLifecycleState.paused) { _videoController!.pause(); }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    _reelsTimer?.cancel();
    _reelsScroll.dispose();
    super.dispose();
  }

  // =============================================
  //  BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = Colors.deepPurple;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5FA),
      drawer: const CustomDrawer(),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: purple,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // -- Hero header with video + search --
            SliverToBoxAdapter(child: _buildHero(isDark, purple)),

            // -- Reels carousel --
            SliverToBoxAdapter(child: _buildReels(isDark)),

            // -- Categories --
            SliverToBoxAdapter(child: _buildCategories(isDark, purple)),

            // -- Featured providers --
            if (_providers.isNotEmpty || _isLoading)
              SliverToBoxAdapter(child: _buildProviders(isDark, purple)),

            // -- Promo banners --
            if (_banners.isNotEmpty)
              SliverToBoxAdapter(child: _buildPromoBanners(isDark, purple)),

            // -- Bottom safe area --
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // =============================================
  //  HERO HEADER
  // =============================================

  Widget _buildHero(bool isDark, Color purple) {
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video background
          if (_videoReady && _videoController != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),

          // Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Top bar
                  Row(
                    children: [
                      // Menu
                      GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const Spacer(),
                      // Logo text
                      const Text(
                        'نوافــذ',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Cairo',
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
                        ),
                      ),
                      const Spacer(),
                      // Notifications
                      _heroIconBtn(Icons.notifications_none_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      }),
                      const SizedBox(width: 8),
                      // Chat
                      _heroIconBtn(Icons.chat_bubble_outline_rounded, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyChatsScreen()));
                      }),
                    ],
                  ),

                  const Spacer(),

                  // Tagline
                  const Text(
                    'اعثر على الخدمة المناسبة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Cairo', color: Colors.white,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 6)]),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'أكثر من ${_providers.length > 0 ? _providers.length : "100"} مقدم خدمة بين يديك',
                    style: TextStyle(fontSize: 11, fontFamily: 'Cairo', color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 12),

                  // Search bar
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchProviderScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text('ابحث عن خدمة أو مقدم خدمة...', style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // =============================================
  //  REELS CAROUSEL
  // =============================================

  Widget _buildReels(bool isDark) {
    final items = List.generate(20, (i) => i % _reelLogos.length);

    return Container(
      height: 90,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        controller: _reelsScroll,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final logoPath = _reelLogos[items[index]];
          final videoIdx = index % _reelVideoPaths.length;
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => VideoFullScreenPage(videoPaths: _reelVideoPaths, initialIndex: videoIdx),
            )),
            child: Container(
              width: 70, height: 70,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated ring
                  Container(
                    width: 70, height: 70,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [Color(0xFF9F57DB), Color(0xFFF1A559), Color(0xFFC8A5FC), Color(0xFF9F57DB)]),
                    ),
                  ),
                  // Logo
                  Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    ),
                    child: ClipOval(child: Image.asset(logoPath, fit: BoxFit.cover)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =============================================
  //  CATEGORIES
  // =============================================

  Widget _buildCategories(bool isDark, Color purple) {
    // Fallback static categories if API returns empty
    final cats = _categories.isNotEmpty
        ? _categories
        : _defaultCategories;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('التصنيفات', isDark),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cats.length,
              itemBuilder: (context, index) {
                final cat = cats[index];
                final icon = _categoryIcon(cat.name);
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchProviderScreen()));
                  },
                  child: Container(
                    width: 76,
                    margin: const EdgeInsets.only(left: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Icon(icon, size: 22, color: purple),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          cat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Cairo',
                            color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //  FEATURED PROVIDERS
  // =============================================

  Widget _buildProviders(bool isDark, Color purple) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('مقدمو الخدمة', isDark),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchProviderScreen())),
                child: Text('عرض الكل', style: TextStyle(fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: purple)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)))
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _providers.length,
                itemBuilder: (context, index) => _providerCard(_providers[index], isDark, purple),
              ),
            ),
        ],
      ),
    );
  }

  Widget _providerCard(ProviderPublicModel p, bool isDark, Color purple) {
    final profileUrl = ApiClient.buildMediaUrl(p.profileImage);
    final coverUrl = ApiClient.buildMediaUrl(p.coverImage);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderProfileScreen())),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 70,
                width: double.infinity,
                child: coverUrl != null
                    ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _gradientPlaceholder())
                    : _gradientPlaceholder(),
              ),
            ),

            // Avatar + Info
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: purple.withValues(alpha: 0.1),
                    backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                    child: profileUrl == null
                        ? Text(p.displayName.isNotEmpty ? p.displayName[0] : '؟',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: purple))
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                                  color: isDark ? Colors.white : Colors.black87)),
                            ),
                            if (p.isVerified) ...[
                              const SizedBox(width: 2),
                              Icon(Icons.verified, size: 11, color: p.isVerifiedBlue ? Colors.blue : Colors.green),
                            ],
                          ],
                        ),
                        if (p.city != null)
                          Text(p.city!, style: TextStyle(fontSize: 9, fontFamily: 'Cairo',
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniProviderStat(Icons.star_rounded, p.ratingAvg > 0 ? p.ratingAvg.toStringAsFixed(1) : '-', Colors.amber),
                  _miniProviderStat(Icons.people_outline, '${p.followersCount}', isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                  _miniProviderStat(Icons.favorite_outline, '${p.likesCount}', isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniProviderStat(IconData icon, String val, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(val, style: TextStyle(fontSize: 9.5, fontFamily: 'Cairo', color: color)),
      ],
    );
  }

  Widget _gradientPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade100],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
      ),
      child: const Center(child: Icon(Icons.image_outlined, size: 20, color: Colors.white54)),
    );
  }

  // =============================================
  //  PROMO BANNERS
  // =============================================

  Widget _buildPromoBanners(bool isDark, Color purple) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('عروض ترويجية', isDark),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final b = _banners[index];
                final url = ApiClient.buildMediaUrl(b.fileUrl);
                return Container(
                  width: 220,
                  margin: const EdgeInsets.only(left: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        url != null
                            ? Image.network(url, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _gradientPlaceholder())
                            : _gradientPlaceholder(),
                        // Bottom info
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (b.caption != null && b.caption!.isNotEmpty)
                                  Text(b.caption!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, fontFamily: 'Cairo', color: Colors.white)),
                                if (b.providerDisplayName != null)
                                  Text(b.providerDisplayName!, maxLines: 1,
                                    style: TextStyle(fontSize: 9, fontFamily: 'Cairo', color: Colors.white.withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //  HELPERS
  // =============================================

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Cairo',
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  IconData _categoryIcon(String name) {
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
    return Icons.category_rounded;
  }

  // Fallback categories when API returns empty
  static final _defaultCategories = [
    CategoryModel(id: 0, name: 'استشارات قانونية'),
    CategoryModel(id: 0, name: 'خدمات هندسية'),
    CategoryModel(id: 0, name: 'تصميم جرافيك'),
    CategoryModel(id: 0, name: 'توصيل سريع'),
    CategoryModel(id: 0, name: 'رعاية صحية'),
    CategoryModel(id: 0, name: 'ترجمة لغات'),
    CategoryModel(id: 0, name: 'برمجة مواقع'),
    CategoryModel(id: 0, name: 'صيانة أجهزة'),
  ];
}
