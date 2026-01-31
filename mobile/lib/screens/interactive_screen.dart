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
  late InteractiveMode _effectiveMode;

  final ProvidersApi _providersApi = ProvidersApi();
  final AccountApi _accountApi = AccountApi();

  bool _hasProviderProfile = false;
  bool _capabilitiesLoaded = false;

  Future<List<ProviderProfile>>? _clientFollowingFuture;
  Future<List<ProviderProfile>>? _clientSavedFuture;
  Future<List<UserSummary>>? _providerFollowersFuture;
  Future<List<UserSummary>>? _providerLikersFuture;

  @override
  void initState() {
    super.initState();
    _effectiveMode = widget.mode == InteractiveMode.auto ? InteractiveMode.client : widget.mode;
    final tabsCount = _tabsCountForMode(_effectiveMode);
    final initial = widget.initialTabIndex.clamp(0, tabsCount - 1);
    _tabController = TabController(length: tabsCount, vsync: this, initialIndex: initial);
    _loadCapabilitiesAndReload();
  }

  int _tabsCountForMode(InteractiveMode mode) => 2;

  Future<void> _loadCapabilitiesAndReload() async {
    final needsCapabilityLookup =
        widget.mode == InteractiveMode.provider || widget.mode == InteractiveMode.auto;
    if (!needsCapabilityLookup) {
      setState(() {
        _hasProviderProfile = false;
        _capabilitiesLoaded = true;
        _effectiveMode = widget.mode;
      });
      _reload();
      return;
    }

    try {
      final me = await _accountApi.me();
      final hasProviderProfile = me['has_provider_profile'] == true;
      if (!mounted) return;
      setState(() {
        _hasProviderProfile = hasProviderProfile;
        _capabilitiesLoaded = true;
        if (widget.mode == InteractiveMode.auto) {
          _effectiveMode = hasProviderProfile ? InteractiveMode.provider : InteractiveMode.client;
        } else {
          _effectiveMode = widget.mode;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasProviderProfile = false;
        _capabilitiesLoaded = true;
        if (widget.mode == InteractiveMode.auto) {
          _effectiveMode = InteractiveMode.client;
        } else {
          _effectiveMode = widget.mode;
        }
      });
    }

    if (!mounted) return;
    _reload();
  }

  void _reload() {
    setState(() {
      if (_effectiveMode == InteractiveMode.client) {
        _clientFollowingFuture = _providersApi.getMyFollowingProviders();
        _clientSavedFuture = _providersApi.getMyLikedProviders();
        _providerFollowersFuture = null;
        _providerLikersFuture = null;
      } else {
        _clientFollowingFuture = null;
        _clientSavedFuture = null;
        _providerFollowersFuture = _hasProviderProfile
            ? _providersApi.getMyProviderFollowers()
            : Future.value(const <UserSummary>[]);
        _providerLikersFuture = _hasProviderProfile
            ? _providersApi.getMyProviderLikers()
            : Future.value(const <UserSummary>[]);
      }
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

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const CustomAppBar(title: 'تفاعلي'),
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          tabs: _effectiveMode == InteractiveMode.client
              ? const [
                  Tab(text: 'من أتابع', icon: Icon(Icons.group)),
                  Tab(text: 'المحفوظات', icon: Icon(Icons.bookmark)),
                ]
              : const [
                  Tab(text: 'المتابعون', icon: Icon(Icons.groups_rounded)),
                  Tab(text: 'المعجبون', icon: Icon(Icons.thumb_up_alt_outlined)),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _effectiveMode == InteractiveMode.client
            ? [
                _buildClientFollowingTab(),
                _buildClientSavedTab(),
              ]
            : [
                _buildProviderFollowersTab(),
                _buildProviderLikersTab(),
              ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
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
            Icon(icon, size: 46, color: Colors.grey.shade500),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerCard(ProviderProfile p) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final displayName = (p.displayName ?? '').trim().isEmpty ? '—' : p.displayName!.trim();
    final city = (p.city ?? '').trim().isEmpty ? '—' : p.city!.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primaryColor.withValues(alpha: 0.10),
          child: Icon(Icons.person, color: primaryColor),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Cairo',
          ),
        ),
        subtitle: Text(
          'المدينة: $city · المتابعون: ${p.followersCount} · الإعجابات: ${p.likesCount}',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'عرض الملف',
              icon: const Icon(Icons.open_in_new),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderProfileScreen(providerId: p.id.toString()),
                  ),
                );
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.chat, size: 18, color: Colors.white),
              label: const Text(
                'مراسلة',
                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo'),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      name: displayName,
                      isOnline: false,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _userCard(UserSummary u) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final initials = u.displayName.isNotEmpty ? u.displayName.characters.first : 'م';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primaryColor.withValues(alpha: 0.10),
          child: Text(
            initials,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
        ),
        title: Text(
          u.displayName,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Cairo',
          ),
        ),
        subtitle: Text(
          u.username == null ? '—' : '@${u.username}',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        trailing: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.chat, size: 18, color: Colors.white),
          label: const Text(
            'مراسلة',
            style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo'),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(
                  name: u.displayName,
                  isOnline: false,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildClientFollowingTab() {
    final future = _clientFollowingFuture;
    if (future == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await future;
      },
      child: FutureBuilder<List<ProviderProfile>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? const <ProviderProfile>[];
          if (list.isEmpty) {
            return _emptyState(
              icon: Icons.group_outlined,
              title: 'لا تتابع أي مقدم خدمة حالياً',
              subtitle: 'ابدأ بمتابعة مقدمي الخدمات لتظهر هنا.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (context, index) => _providerCard(list[index]),
          );
        },
      ),
    );
  }

  Widget _buildClientSavedTab() {
    final future = _clientSavedFuture;
    if (future == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await future;
      },
      child: FutureBuilder<List<ProviderProfile>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? const <ProviderProfile>[];
          if (list.isEmpty) {
            return _emptyState(
              icon: Icons.bookmark_border,
              title: 'لا توجد عناصر في المحفوظات',
              subtitle: 'سيظهر هنا ما قمت بحفظه/الإعجاب به.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (context, index) => _providerCard(list[index]),
          );
        },
      ),
    );
  }

  Widget _buildProviderFollowersTab() {
    if (!_capabilitiesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasProviderProfile) {
      return _emptyState(
        icon: Icons.groups_rounded,
        title: 'لا يوجد متابعون حتى الآن',
        subtitle: 'أكمل تسجيل مقدم الخدمة لتظهر قائمة المتابعين هنا.',
      );
    }

    final future = _providerFollowersFuture;
    if (future == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await future;
      },
      child: FutureBuilder<List<UserSummary>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? const <UserSummary>[];
          if (list.isEmpty) {
            return _emptyState(
              icon: Icons.groups_rounded,
              title: 'لا يوجد متابعون حتى الآن',
              subtitle: 'سيظهر المتابعون هنا عند متابعة ملفك كمقدم خدمة.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (context, index) => _userCard(list[index]),
          );
        },
      ),
    );
  }

  Widget _buildProviderLikersTab() {
    if (!_capabilitiesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasProviderProfile) {
      return _emptyState(
        icon: Icons.thumb_up_alt_outlined,
        title: 'لا توجد إعجابات حتى الآن',
        subtitle: 'أكمل تسجيل مقدم الخدمة لتظهر قائمة المعجبين هنا.',
      );
    }

    final future = _providerLikersFuture;
    if (future == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await future;
      },
      child: FutureBuilder<List<UserSummary>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? const <UserSummary>[];
          if (list.isEmpty) {
            return _emptyState(
              icon: Icons.thumb_up_alt_outlined,
              title: 'لا توجد إعجابات حتى الآن',
              subtitle: 'سيظهر المعجبون هنا عند إعجاب العملاء بملفك.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            itemBuilder: (context, index) => _userCard(list[index]),
          );
        },
      ),
    );
  }
}
