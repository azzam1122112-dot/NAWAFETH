import 'package:flutter/material.dart';

import '../models/provider.dart';
import '../models/user_summary.dart';
import '../screens/provider_profile_screen.dart';
import '../services/account_api.dart';
import '../services/providers_api.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import 'chat_detail_screen.dart';

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
  // ignore: unused_field
  late InteractiveMode _effectiveMode;

  final ProvidersApi _providersApi = ProvidersApi();
  final AccountApi _accountApi = AccountApi();

  // ignore: unused_field
  bool _hasProviderProfile = false;
  bool _capabilitiesLoaded = false;

  // Data Futures
  Future<List<ProviderProfile>>? _followingFuture;
  Future<List<UserSummary>>? _followersFuture;
  Future<List<ProviderProfile>>? _favoritesFuture;

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
      if (!mounted) return;
      
      final newMode = hasProviderProfile ? InteractiveMode.provider : InteractiveMode.client;
      setState(() {
        _hasProviderProfile = hasProviderProfile;
        _effectiveMode = newMode;
        _capabilitiesLoaded = true;
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
        _hasProviderProfile = false;
        _effectiveMode = InteractiveMode.client;
        _capabilitiesLoaded = true;
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

      // 3. Favorites: Providers I Liked (or "Projects" I liked)
      // Using 'getMyLikedProviders' as proxy for Favorites
      _favoritesFuture = _providersApi.getMyLikedProviders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // Custom Tab Indicator/Label styles
    const tabStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 14,
      fontWeight: FontWeight.bold,
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

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const CustomAppBar(title: 'تفاعلي'),
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          indicatorWeight: 3,
          labelStyle: tabStyle,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: views,
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final p = list[index];
            // Render as a "Project" card style as per Image 1
            return _buildFollowingCard(p);
          },
        );
      },
    );
  }

  // Card style like Image 1: Pinkish bg, Avatar+Handle, Content
  Widget _buildFollowingCard(ProviderProfile p) {
    // If we have an image URL from backend, use it. Otherwise, use a standard asset or null.
    // Assuming ProviderProfile model might be extended in future to hold 'projectImage' etc.
    // For now we rely on p.placeholderImage or similar IF it comes from real data, 
    // but user requested "No fake data". So if data is missing, we show text or empty.
    
    // Clean data extraction
    final name = p.displayName ?? ''; 
    final bio = p.bio ?? '';
    final hasImage = false; // Until backend provides real project images url

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEAF8), // Light pinkish background match
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pink.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Handle + Avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '@${p.id}', // Using ID as handle since username not always available in this model
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              if (p.isVerifiedBlue) 
                const Icon(Icons.verified, color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: const Icon(Icons.person, color: Colors.grey), 
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Content
          Center(
            child: Column(
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (hasImage) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 120, 
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      // Image logic when available
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        color: const Color(0xFFFDEAF8), // Light pinkish
        borderRadius: BorderRadius.circular(8),
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
                    color: Colors.black87,
                  ),
                ),
                Text(
                  u.displayName, 
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey.shade700,
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
                backgroundColor: Colors.white,
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              // Optional badge like in image
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 10),
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
    return FutureBuilder<List<ProviderProfile>>(
      future: _favoritesFuture,
      builder: (context, snapshot) {
        if (!_capabilitiesLoaded || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _emptyState(
            icon: Icons.thumb_up_alt_outlined,
            title: 'لم تقم بالإعجاب بأي شيء بعد',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85, 
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final p = list[index];
            return _buildFavoriteCard(p);
          },
        );
      },
    );
  }

  // Grid Card like Image 3
  Widget _buildFavoriteCard(ProviderProfile p) {
    // Only show real data. If no image is provided from backend, show initial or simple placeholder color, 
    // but do not insert fake asset path.
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300, 
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // If we had a real image URL, we would load it here.
          // Since we don't use fake data, we leave it as a solid color tile with the name.
          Center(
             child: Padding(
               padding: const EdgeInsets.all(8.0),
               child: Text(
                 p.displayName ?? '',
                 textAlign: TextAlign.center,
                 style: const TextStyle(
                   fontFamily: 'Cairo',
                   fontSize: 12,
                   color: Colors.black54,
                 ),
               ),
             ),
          ),

          // Overlay Info
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${p.id}',
                  style: const TextStyle(
                    color: Colors.black87, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.person, size: 14, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
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
