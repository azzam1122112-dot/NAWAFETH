import 'package:flutter/material.dart';

import '../models/provider.dart';
import '../models/provider_portfolio_item.dart';
import '../models/user_summary.dart';
import '../services/account_api.dart';
import '../services/chat_nav.dart';
import '../services/providers_api.dart';
import '../constants/colors.dart';
import '../widgets/app_bar.dart';
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
    _effectiveMode =
        widget.mode == InteractiveMode.auto ? InteractiveMode.client : widget.mode;
    
    final initialLength = _effectiveMode == InteractiveMode.provider ? 3 : 2;
    _tabController = TabController(
      length: initialLength, 
      vsync: this, 
      initialIndex: 0 
    );
    
    _loadCapabilitiesAndReload();
  }

  Future<void> _loadCapabilitiesAndReload() async {
    try {
      final me = await _accountApi.me();
      final hasProviderProfile = me['has_provider_profile'] == true;
      final username = (me['username'] ?? '').toString().trim();
      if (!mounted) return;
      
      final newMode = widget.mode == InteractiveMode.auto
          ? (hasProviderProfile ? InteractiveMode.provider : InteractiveMode.client)
          : widget.mode;

      final effectiveMode = (newMode == InteractiveMode.provider && !hasProviderProfile)
          ? InteractiveMode.client
          : newMode;

      final newLength = effectiveMode == InteractiveMode.provider ? 3 : 2;
      final newIndex = widget.initialTabIndex.clamp(0, newLength - 1);
      final newController = TabController(length: newLength, vsync: this, initialIndex: newIndex);
      final oldController = _tabController;

      setState(() {
        _effectiveMode = effectiveMode;
        _capabilitiesLoaded = true;
        _myHandle = username.isEmpty ? null : '@$username';
        _tabController = newController;
      });
      oldController.dispose();
      
    } catch (_) {
      if (!mounted) return;
      final effectiveMode = widget.mode == InteractiveMode.provider
          ? InteractiveMode.provider
          : InteractiveMode.client;

      final newLength = effectiveMode == InteractiveMode.provider ? 3 : 2;
      final newIndex = widget.initialTabIndex.clamp(0, newLength - 1);
      final newController = TabController(length: newLength, vsync: this, initialIndex: newIndex);
      final oldController = _tabController;

      setState(() {
        _effectiveMode = effectiveMode;
        _capabilitiesLoaded = true;
        _myHandle = null;
        _tabController = newController;
      });
      oldController.dispose();
    }
    _reload();
  }

  void _reload() {
    setState(() {
      _followingFuture = _providersApi.getMyFollowingProviders();
      _followersFuture = _providersApi.getMyProviderFollowers();
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
    // Elegant tab style
    const tabLabelStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );
     const tabUnselectedLabelStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 14,
      fontWeight: FontWeight.normal,
    );

    final isClient = _effectiveMode == InteractiveMode.client;
    final tabs = isClient 
      ? const [
          Tab(text: 'من أتابع'),
          Tab(text: 'مفضلتي'),
        ]
      : const [
          Tab(text: 'من أتابع'),
          Tab(text: 'متابعيني'),
          Tab(text: 'مفضلتي'),
        ];

    final views = isClient
      ? [
          _buildGenericTab(_buildFollowingTab()),
          _buildGenericTab(_buildFavoritesTab()),
        ]
      : [
          _buildGenericTab(_buildFollowingTab()),
          _buildGenericTab(_buildFollowersTab()),
          _buildGenericTab(_buildFavoritesTab()),
        ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: const CustomDrawer(),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 180.0,
                floating: false,
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: AppColors.deepPurple,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                actions: [
                   const NotificationsIconButton(iconColor: Colors.white),
                   IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                    onPressed: () => ChatNav.openInbox(context),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.deepPurple,
                          Color(0xFF8E44AD), // A bit lighter purple
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative circles
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: -30,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                         Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 40),
                              Text(
                                _myHandle ?? 'تفاعلي',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                ),
                              ),
                              if (_myHandle != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'مساحتك الشخصية',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Container(
                         decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: AppColors.deepPurple,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepPurple.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.deepPurple,
                          labelStyle: tabLabelStyle,
                          unselectedLabelStyle: tabUnselectedLabelStyle,
                          
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                          tabs: tabs,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: views,
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
      ),
    );
  }

  // Wrapper with background
  Widget _buildGenericTab(Widget child) {
    return Container(
      color: Colors.white, // Main body background
      child: child,
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

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: list.length,
          separatorBuilder: (context, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final p = list[index];
            return _buildFollowingCard(context, p);
          },
        );
      },
    );
  }

  Widget _buildFollowingCard(BuildContext context, ProviderProfile p) {
    final name = (p.displayName ?? '').trim();
    final bio = (p.bio ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                     radius: 24,
                     backgroundColor: AppColors.primaryLight,
                     child: Icon(
                        p.isVerifiedBlue ? Icons.verified_rounded : Icons.person, // Changed to person to be safer
                        color: p.isVerifiedBlue ? Colors.blue : AppColors.deepPurple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'مزود خدمة' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.softBlue,
                            ),
                          ),
                          Text(
                             '@${p.id}',
                             style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Button
                    InkWell(
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
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.deepPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.deepPurple.withValues(alpha: 0.3)),
                        ),
                        child: const Text('طلب خدمة', style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepPurple
                        )),
                      ),
                    )
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniStat(Icons.thumb_up_alt_rounded, '${p.likesCount} إعجاب'),
                    _miniStat(Icons.groups_rounded, '${p.followersCount} متابع'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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

  Widget _buildFollowerItem(UserSummary u) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          )
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.deepPurple.withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: AppColors.deepPurple),
        ),
        title: Text(
          u.displayName,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
           '@${u.username ?? u.id}', 
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Colors.grey[600],
            ),
        ),
        trailing: Container(
           width: 32,
           height: 32,
           decoration: BoxDecoration(
             color: AppColors.primaryLight.withValues(alpha: 0.5),
             shape: BoxShape.circle,
           ),
           child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.deepPurple),
        ),
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85, // More vertical space for a nice card look
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

  Widget _buildFavoriteMediaCard(BuildContext context, ProviderPortfolioItem item) {
    final isVideo = item.fileType.toLowerCase() == 'video';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                backgroundColor: Colors.transparent, // Clean look
                elevation: 0,
                child: InteractiveViewer(
                  child: ClipRRect(
                     borderRadius: BorderRadius.circular(12),
                     child: Image.network(
                      item.fileUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item.fileUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  if (isVideo)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                ],
              ),
            ),
             Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10, 
                      backgroundColor: AppColors.deepPurple.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, size: 12, color: AppColors.deepPurple)
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.providerDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.deepPurple.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.softBlue,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.5
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
             SizedBox(
               width: 150,
               child: ElevatedButton(
                onPressed: _reload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPurple,
                  elevation: 0,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
             ),
          ],
        ),
      ),
    );
  }
}
