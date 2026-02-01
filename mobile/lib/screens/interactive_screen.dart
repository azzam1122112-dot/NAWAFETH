import 'package:flutter/material.dart';

import '../models/provider.dart';
import '../models/provider_portfolio_item.dart';
import '../models/user_summary.dart';
import '../services/account_api.dart';
import '../services/providers_api.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import 'network_video_player_screen.dart';
import 'service_request_form_screen.dart';

enum InteractiveMode {
  auto,
  client,
  provider,
}

class InteractiveScreen extends StatefulWidget {
  final InteractiveMode mode;
  final int initialTabIndex;

  const InteractiveScreen({
    super.key,
    this.mode = InteractiveMode.auto,
    this.initialTabIndex = 0,
  });

  @override
  State<InteractiveScreen> createState() => _InteractiveScreenState();
}

class _InteractiveScreenState extends State<InteractiveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late InteractiveMode _effectiveMode;

  final ProvidersApi _providersApi = ProvidersApi();
  final AccountApi _accountApi = AccountApi();

  bool _capabilitiesLoaded = false;

  String? _myHandle;

  // Data Futures
  Future<List<ProviderProfile>>? _followingFuture;
  Future<List<UserSummary>>? _followersFuture;
  Future<List<ProviderPortfolioItem>>? _favoritesFuture;

  @override
  void initState() {
    super.initState();
    // Default mode; will update in _loadCapabilitiesAndReload
    _effectiveMode =
        widget.mode == InteractiveMode.auto ? InteractiveMode.client : widget.mode;
    
    // Initialize controller with dummy length. We will re-initialize it once mode is confirmed.
    // Client: 2 tabs (Following, Favorites)
    // Provider: 3 tabs (Following, Followers, Favorites)
    final initialLength = _effectiveMode == InteractiveMode.provider ? 3 : 2;
    _tabController = TabController(
      length: initialLength, 
      vsync: this, 
      initialIndex: 0 // Will clamp/reset later
    );
    
    _loadCapabilitiesAndReload();
  }

  Future<void> _loadCapabilitiesAndReload() async {
    // Check if current user is provider to adjust API calls if needed
    try {
      final me = await _accountApi.me();
      final hasProviderProfile = me['has_provider_profile'] == true;
      final username = (me['username'] ?? '').toString().trim();
      if (!mounted) return;
      
      final newMode = hasProviderProfile ? InteractiveMode.provider : InteractiveMode.client;
      setState(() {
        _effectiveMode = newMode;
        _capabilitiesLoaded = true;
        _myHandle = username.isEmpty ? null : '@$username';
      });
      
      // Re-init tab controller with correct length based on mode
      final newLength = newMode == InteractiveMode.provider ? 3 : 2;
      // Preserve index if possible, else default to 0
      final newIndex = widget.initialTabIndex.clamp(0, newLength - 1);
      
      _tabController.dispose();
      _tabController = TabController(length: newLength, vsync: this, initialIndex: newIndex);
      
    } catch (_) {
      if (!mounted) return;
      // Default fallback to Client mode
      setState(() {
        _effectiveMode = InteractiveMode.client;
        _capabilitiesLoaded = true;
        _myHandle = null;
      });
      
      _tabController.dispose();
      _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    }
    _reload();
  }

  void _reload() {
    setState(() {
      // 1. Following: Providers I follow (Client/Provider can follow)
      _followingFuture = _providersApi.getMyFollowingProviders();
      
      // 2. Followers: Users following ME. 
      // If I am a Provider, I have followers. 
      // If Client, this might be empty usually, but "It should be the same".
      _followersFuture = _providersApi.getMyProviderFollowers();

      // 3. Favorites: media I liked (images/videos)
      _favoritesFuture = _providersApi.getMyFavoriteMedia();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tabStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 13,
      fontWeight: FontWeight.w800,
    );

    // Decide tabs based on mode
    final isClient = _effectiveMode == InteractiveMode.client;
    final tabs = isClient 
      ? const [
          Tab(text: 'من أتابع', icon: Icon(Icons.bookmark_border)),
          Tab(text: 'مفضلتي', icon: Icon(Icons.thumb_up_alt_outlined)),
        ]
      : const [
          Tab(text: 'من أتابع', icon: Icon(Icons.bookmark_border)),
          Tab(text: 'متابعيني', icon: Icon(Icons.person_add_alt)),
          Tab(text: 'مفضلتي', icon: Icon(Icons.thumb_up_alt_outlined)),
        ];

    final views = isClient
      ? [
          _buildFollowingTab(),
          _buildFavoritesTab(),
        ]
      : [
          _buildFollowingTab(),
          _buildFollowersTab(),
          _buildFavoritesTab(),
        ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: const CustomDrawer(),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFFF7ECFF),
                  Color(0xFFFDEBFA),
                  Color(0xFFF6F3FF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                )
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const SizedBox(width: 44),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _myHandle ?? 'تفاعلي',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF3B215E),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu_rounded, color: Color(0xFF3B215E)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x2A7C3AED)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF5A2FA6),
                        unselectedLabelColor: const Color(0xFF8C7AA7),
                        indicatorColor: const Color(0xFF5A2FA6),
                        indicatorWeight: 3,
                        labelStyle: tabStyle,
                        splashFactory: NoSplash.splashFactory,
                        tabs: tabs,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFDF4FF),
                Color(0xFFF8F7FF),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
          child: TabBarView(
            controller: _tabController,
            children: views,
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
      ),
    );
  }

  // --- TAB 1: Following (من أتابع) ---
  Widget _buildFollowingTab() {
     return FutureBuilder<List<ProviderProfile>>(
      future: _followingFuture,
      builder: (context, snapshot) {
        if (!_capabilitiesLoaded || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _emptyState(
            icon: Icons.bookmark_border,
            title: 'لا تتابع أحداً بعد',
            subtitle: 'تصفح مقدمي الخدمات وابدأ بمتابعتهم لتظهر تحديثاتهم هنا.',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final p = list[index];
            return _buildFollowingCard(context, p);
          },
        );
      },
    );
  }

  // Card style like Image 1: Pinkish bg, Avatar+Handle, Content
  Widget _buildFollowingCard(BuildContext context, ProviderProfile p) {
    final name = (p.displayName ?? '').trim();
    final bio = (p.bio ?? '').trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceRequestFormScreen(
              providerId: p.id.toString(),
              providerName: name.isEmpty ? null : name,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x2A7C3AED)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF3ECFF),
                    border: Border.all(color: const Color(0x2A7C3AED)),
                  ),
                  child: Icon(
                    p.isVerifiedBlue ? Icons.verified_rounded : Icons.person_rounded,
                    size: 18,
                    color: p.isVerifiedBlue ? Colors.blue : const Color(0xFF6D48B5),
                  ),
                ),
                const Spacer(),
                Text(
                  '@${p.id}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6E5A8D),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'فتح صفحة الطلب',
                  child: InkResponse(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceRequestFormScreen(
                            providerId: p.id.toString(),
                            providerName: name.isEmpty ? null : name,
                          ),
                        ),
                      );
                    },
                    radius: 22,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDEBFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x2ADB2777)),
                      ),
                      child: const Icon(
                        Icons.note_add_outlined,
                        size: 18,
                        color: Color(0xFF8F2D74),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name.isEmpty ? 'مزود خدمة' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D1B4E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bio.isEmpty ? '—' : bio,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                height: 1.25,
                color: Color(0xFF6E5A8D),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                _miniStat(Icons.thumb_up_alt_outlined, '${p.likesCount}'),
                const SizedBox(width: 10),
                _miniStat(Icons.groups_rounded, '${p.followersCount}'),
                const Spacer(),
                const Icon(Icons.chevron_left_rounded, color: Color(0xFF6D48B5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6D48B5)),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6D48B5),
          ),
        ),
      ],
    );
  }

  // --- TAB 2: Followers (متابعيني) ---
  Widget _buildFollowersTab() {
    return FutureBuilder<List<UserSummary>>(
      future: _followersFuture,
      builder: (context, snapshot) {
        if (!_capabilitiesLoaded || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _emptyState(
            icon: Icons.groups_rounded,
            title: 'لا يوجد متابعون حالياً',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          itemCount: list.length,
          separatorBuilder: (context, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final u = list[index];
            return _buildFollowerItem(u);
          },
        );
      },
    );
  }

  // List Item style like Image 2: Pink bg strip, User info
  Widget _buildFollowerItem(UserSummary u) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2A7C3AED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end, // RTL alignment
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '@${u.username ?? u.id}', 
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF2D1B4E),
                  ),
                ),
                Text(
                  u.displayName, 
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: const Color(0xFF6E5A8D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF3ECFF),
                child: const Icon(Icons.person_rounded, color: Color(0xFF6D48B5)),
              ),
              // Optional badge like in image
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF8F2D74),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.circle, color: Colors.white, size: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Favorites (مفضلتي) ---
  Widget _buildFavoritesTab() {
    return FutureBuilder<List<ProviderPortfolioItem>>(
      future: _favoritesFuture,
      builder: (context, snapshot) {
        if (!_capabilitiesLoaded || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _emptyState(
            icon: Icons.thumb_up_alt_outlined,
            title: 'لا توجد عناصر في مفضلتي بعد',
            subtitle: 'أي صور أو فيديوهات تعمل لها لايك ستظهر هنا.',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return _buildFavoriteMediaCard(context, item);
          },
        );
      },
    );
  }

  // Grid Card like Image 3
  Widget _buildFavoriteMediaCard(BuildContext context, ProviderPortfolioItem item) {
    final isVideo = item.fileType.toLowerCase() == 'video';
    final providerLabel = (item.providerUsername ?? '').trim().isNotEmpty
        ? '@${item.providerUsername}'
        : '@${item.providerId}';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (isVideo) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NetworkVideoPlayerScreen(
                url: item.fileUrl,
                title: item.providerDisplayName,
              ),
            ),
          );
          return;
        }
        showDialog<void>(
          context: context,
          builder: (context) {
            return Dialog(
              insetPadding: const EdgeInsets.all(12),
              backgroundColor: Colors.black,
              child: InteractiveViewer(
                child: Image.network(
                  item.fileUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'تعذر تحميل الصورة',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x2A7C3AED)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              item.fileUrl,
              fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFFF3ECFF),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, color: Color(0xFF6D48B5)),
                  ),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(0),
                    Colors.black.withAlpha(0),
                    Colors.black.withAlpha(120),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    providerLabel,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x2A7C3AED)),
                    ),
                    child: const Icon(Icons.person_rounded, size: 14, color: Color(0xFF6D48B5)),
                  ),
                ],
              ),
            ),
            if (isVideo)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 2),
                      Text(
                        'فيديو',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                item.providerDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 46, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _reload,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }


}
