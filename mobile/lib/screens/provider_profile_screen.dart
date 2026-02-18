import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/app_bar.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/platform_report_dialog.dart';
import 'provider_dashboard/reviews_tab.dart';
import 'network_video_player_screen.dart';
import 'service_request_form_screen.dart';
import '../services/providers_api.dart'; // Added
import '../services/api_config.dart';
import '../models/provider.dart'; // Added
import '../models/provider_portfolio_item.dart';
import '../models/provider_service.dart';
import '../models/user_summary.dart';
import '../services/chat_nav.dart';
import '../services/messaging_api.dart';
import '../services/account_api.dart';
import '../utils/auth_guard.dart'; // Added
import '../utils/whatsapp_helper.dart';

import 'provider_dashboard/provider_portfolio_manage_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String? providerId;
  final String? providerName;
  final String? providerCategory;
  final String? providerSubCategory;
  final double? providerRating;
  final int? providerOperations;
  final String? providerImage;
  final bool? providerVerified;
  final String? providerPhone;
  final double? providerLat;
  final double? providerLng;

  const ProviderProfileScreen({
    super.key,
    this.providerId,
    this.providerName,
    this.providerCategory,
    this.providerSubCategory,
    this.providerRating,
    this.providerOperations,
    this.providerImage,
    this.providerVerified,
    this.providerPhone,
    this.providerLat,
    this.providerLng,
  });

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final Color mainColor = Colors.deepPurple;

  bool _canManageGallery = false;

  int _selectedTabIndex = 0;

  bool _isFollowingProvider = false;
  bool _isFollowBusy = false;
  Set<int> _favoritePortfolioIds = <int>{};
  final Set<int> _portfolioFavoriteBusyIds = <int>{};
  final Set<int> _favoriteHighlightIndexes = <int>{};

  // عدادات أعلى الصفحة (من API العام لمقدم الخدمة)
  int? _completedRequests;
  int? _followersCount;
  int? _followingCount;
  int? _likesCount;

  int? _reviewersCount;

  final List<Map<String, dynamic>> tabs = const [
    {"title": "الملف الشخصي", "icon": Icons.person_outline},
    {"title": "التصنيفات", "icon": Icons.work_outline},
    {"title": "معرض خدماتي", "icon": Icons.photo_library},
    {"title": "المراجعات", "icon": Icons.reviews},
  ];

  // تصنيفات مقدم الخدمة (API) (الخدمات = التصنيفات الرئيسية/الفرعية)
  List<ProviderServiceSubcategory> _providerSubcategories = const [];
  bool _servicesLoading = true;

  // ✅ معرض خدماتي (API)
  bool _portfolioLoading = true;
  List<ProviderPortfolioItem> _portfolioItems = const [];

  String get providerName => _fullProfile?.displayName ?? widget.providerName ?? '—';

    String get providerCategory => (widget.providerCategory ?? '').trim();

  String get providerSubCategory =>
      (widget.providerSubCategory ?? '').trim();

  double get providerRating => _fullProfile?.ratingAvg ?? widget.providerRating ?? 0.0;

  int get providerOperations => _fullProfile?.ratingCount ?? widget.providerOperations ?? 0;

  String get providerImage =>
      _fullProfile?.imageUrl?.trim().isNotEmpty == true
          ? _fullProfile!.imageUrl!.trim()
          : (widget.providerImage ?? '').trim();

    bool get providerVerified =>
      (_fullProfile?.isVerifiedBlue ?? false) ||
      (_fullProfile?.isVerifiedGreen ?? false) ||
      (widget.providerVerified ?? false);

    String get providerPhone =>
      _fullProfile?.phone?.trim().isNotEmpty == true
        ? _fullProfile!.phone!.trim()
        : (widget.providerPhone ?? '').trim();

  String get providerHandle {
    final raw = (_fullProfile?.username ?? '').trim();
    if (raw.isNotEmpty) return raw.startsWith('@') ? raw : '@$raw';
    final pid = (widget.providerId ?? '').trim();
    return pid.isNotEmpty ? '#$pid' : '—';
  }

  String get providerEnglishName => '';

  String get providerAccountType => providerCategory;

  String get providerServicesDetails {
    final bio = (_fullProfile?.bio ?? '').trim();
    if (bio.isNotEmpty) return bio;
    return 'لا توجد نبذة متاحة حالياً.';
  }

  int get providerYearsExperience => _fullProfile?.yearsExperience ?? 0;

  String get providerExperienceYears =>
      providerYearsExperience > 0 ? '$providerYearsExperience سنة' : '—';

  String get providerCityName => (_fullProfile?.city ?? '').trim();
  String get providerRegionName => 'منطقة الرياض';
  String get providerCountryName => 'المملكة العربية السعودية';

  double? get providerLat => _fullProfile?.lat ?? widget.providerLat;
  double? get providerLng => _fullProfile?.lng ?? widget.providerLng;

  bool _isRemoteImage(String path) {
    final p = path.trim().toLowerCase();
    return p.startsWith('http://') || p.startsWith('https://');
  }

  Widget _providerAvatar() {
    if (providerImage.trim().isEmpty) {
      return const Icon(Icons.person, size: 36);
    }
    if (_isRemoteImage(providerImage)) {
      return Image.network(
        providerImage,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => const Icon(Icons.person, size: 36),
      );
    }
    return Image.asset(
      providerImage,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => const Icon(Icons.person, size: 36),
    );
  }

  String get providerWebsite => '';

  String get providerInstagramUrl => '';

  String get providerXUrl => '';

  String get providerSnapchatUrl => '';

  ProviderProfile? _fullProfile;

  @override
  void initState() {
    super.initState();
    _syncCanManageGallery();
    if (widget.providerId != null) {
      _loadProviderData();
      _loadProviderSubcategories();
      _loadProviderPortfolio();
      _syncClientSocialState();
    }
  }

  Future<void> _syncCanManageGallery() async {
    final providerId = int.tryParse((widget.providerId ?? '').trim());
    if (providerId == null) return;
    try {
      final me = await AccountApi().me();
      final raw = me['provider_profile_id'];
      final int? myProviderId = raw is int ? raw : int.tryParse((raw ?? '').toString());
      if (!mounted) return;
      setState(() {
        _canManageGallery = myProviderId != null && myProviderId == providerId;
      });
    } catch (_) {
      // Best-effort: keep hidden.
    }
  }

  Future<void> _openManageGallery() async {
    if (!_canManageGallery) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProviderPortfolioManageScreen(),
      ),
    );
    await _loadProviderPortfolio();
  }

  Future<void> _syncClientSocialState() async {
    final providerId = int.tryParse((widget.providerId ?? '').trim());
    if (providerId == null) return;
    try {
      final api = ProvidersApi();
      final following = await api.getMyFollowingProviders();
      final favorites = await api.getMyFavoriteMedia();
      if (!mounted) return;
      setState(() {
        _isFollowingProvider = following.any((p) => p.id == providerId);
        _favoritePortfolioIds = favorites.map((e) => e.id).toSet();
      });
    } catch (_) {}
  }

  Future<void> _toggleFollowProvider() async {
    if (!await checkAuth(context)) return;
    if (!mounted) return;
    final providerId = int.tryParse((widget.providerId ?? '').trim());
    if (providerId == null || _isFollowBusy) return;

    setState(() => _isFollowBusy = true);
    final api = ProvidersApi();
    final ok = _isFollowingProvider
        ? await api.unfollowProvider(providerId)
        : await api.followProvider(providerId);
    if (!mounted) return;
    setState(() => _isFollowBusy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذرت العملية، حاول مرة أخرى')),
      );
      return;
    }

    setState(() {
      _isFollowingProvider = !_isFollowingProvider;
      final current = _followersCount ?? 0;
      _followersCount = _isFollowingProvider
          ? current + 1
          : (current > 0 ? current - 1 : 0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFollowingProvider ? 'تمت المتابعة بنجاح' : 'تم إلغاء المتابعة',
        ),
      ),
    );
  }

  Future<void> _togglePortfolioFavorite(ProviderPortfolioItem item) async {
    if (!await checkAuth(context)) return;
    if (!mounted) return;
    if (_portfolioFavoriteBusyIds.contains(item.id)) return;
    setState(() => _portfolioFavoriteBusyIds.add(item.id));

    final isFav = _favoritePortfolioIds.contains(item.id);
    final api = ProvidersApi();
    final ok = isFav
        ? await api.unlikePortfolioItem(item.id)
        : await api.likePortfolioItem(item.id);
    if (!mounted) return;
    setState(() => _portfolioFavoriteBusyIds.remove(item.id));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث التفضيل')),
      );
      return;
    }
    setState(() {
      if (isFav) {
        _favoritePortfolioIds.remove(item.id);
      } else {
        _favoritePortfolioIds.add(item.id);
      }
    });
  }

  void _toggleHighlightFavorite(int index) {
    setState(() {
      if (_favoriteHighlightIndexes.contains(index)) {
        _favoriteHighlightIndexes.remove(index);
      } else {
        _favoriteHighlightIndexes.add(index);
      }
    });
  }

  List<ProviderPortfolioItem> get _highlightItems {
    return _portfolioItems
        .where(
          (item) =>
              item.fileType.toLowerCase() == 'video' &&
              item.fileUrl.trim().isNotEmpty,
        )
        .toList();
  }

  Future<void> _loadProviderPortfolio() async {
    final id = int.tryParse(widget.providerId ?? '');
    if (id == null) return;

    if (mounted) {
      setState(() => _portfolioLoading = true);
    }

    try {
      final items = await ProvidersApi().getProviderPortfolio(id);
      if (!mounted) return;
      setState(() {
        _portfolioItems = items;
        _portfolioLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _portfolioItems = const [];
        _portfolioLoading = false;
      });
    }
  }

  Future<void> _loadProviderData() async {
    try {
      final id = int.tryParse(widget.providerId!);
      if (id == null) return;
      
      final profile = await ProvidersApi().getProviderDetail(id);
      if (profile != null && mounted) {
        setState(() {
          _fullProfile = profile;
          _completedRequests = profile.completedRequests;
          _followersCount = profile.followersCount;
          _followingCount = profile.followingCount;
          _likesCount = profile.likesCount;
          _reviewersCount = profile.ratingCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading provider: $e');
    }
  }

  String _formatPhoneE164(String rawPhone) {
    final phone = rawPhone.replaceAll(RegExp(r'\s+'), '');
    if (phone.startsWith('+')) return phone;

    if (phone.startsWith('05') && phone.length == 10) {
      return '+966${phone.substring(1)}';
    }
    if (phone.startsWith('5') && phone.length == 9) {
      return '+966$phone';
    }
    return phone;
  }

  Future<void> _openPhoneCall() async {
    final e164 = _formatPhoneE164(providerPhone);
    final uri = Uri(scheme: 'tel', path: e164);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الاتصال')),
    );
  }

  String _buildWhatsAppMessage() {
    final buffer = StringBuffer();
    buffer.writeln('@${providerName.replaceAll(' ', '')}');
    buffer.writeln('السلام عليكم');
    buffer.writeln('أتواصل معك بخصوص خدماتك المعروضة في منصة (نوافذ)');
    return buffer.toString().trim();
  }

  Future<void> _openWhatsApp() async {
    final target = (_fullProfile?.whatsapp ?? '').trim().isNotEmpty
        ? _fullProfile!.whatsapp!.trim()
        : providerPhone;
    await WhatsAppHelper.open(
      context: context,
      contact: target,
      message: _buildWhatsAppMessage(),
    );
  }

  Future<void> _openInAppChat() async {
    if (!await checkAuth(context)) return;
    final providerId = (widget.providerId ?? '').trim();
    if (providerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المحادثة: لا يوجد مزود مرتبط.')),
      );
      return;
    }
    if (!mounted) return;

    // Open direct chat with provider (no request required)
    try {
      final api = MessagingApi();
      final thread = await api.getOrCreateDirectThread(int.parse(providerId));
      final threadId = thread['id'] as int?;
      if (threadId == null) throw Exception('no thread id');
      if (!mounted) return;
      ChatNav.openThread(
        context,
        threadId: threadId,
        name: providerName,
        isDirect: true,
        peerId: providerId,
        peerName: providerName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المحادثة. حاول مرة أخرى.')),
      );
    }
  }

  Future<void> _showShareAndReportSheet() async {
    final e164 = _formatPhoneE164(providerPhone);
    final shareLink = '${ApiConfig.baseUrl}/provider/${widget.providerId ?? ''}';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 22, color: Colors.black87),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'مشاركة نافذة مقدم الخدمة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: mainColor.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(14),
                    color: mainColor.withValues(alpha: 0.04),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: QrImageView(
                            data: shareLink,
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        e164,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: shareLink));
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم نسخ الرابط')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('نسخ الرابط', style: TextStyle(fontFamily: 'Cairo')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Share.share(shareLink);
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('مشاركة', style: TextStyle(fontFamily: 'Cairo')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showPlatformReportDialog(
                      context: context,
                      title: 'إبلاغ عن مزود خدمة',
                      reportedEntityLabel: 'بيانات المبلغ عنه:',
                      reportedEntityValue: '$providerName ($providerHandle)',
                      contextLabel: 'نوع البلاغ',
                      contextValue: 'مزود خدمة',
                    );
                  },
                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                  title: const Text('الإبلاغ عن مقدم الخدمة', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFollowersList() async {
    final providerId = int.tryParse((widget.providerId ?? '').trim());
    if (providerId == null) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final countText = _followersCount?.toString() ?? '—';
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            height: 380,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.groups_rounded, color: Colors.black87),
                      const SizedBox(width: 10),
                      Text(
                        'متابعون ($countText)',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<UserSummary>>(
                    future: ProvidersApi().getProviderFollowers(providerId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'لا يوجد متابعون حالياً',
                              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, i) {
                          final user = list[i];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(user.displayName[0].toUpperCase()),
                            ),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                            subtitle: user.username != null
                                ? Text(
                                    '@${user.username}',
                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFollowingList() async {
    final providerId = int.tryParse((widget.providerId ?? '').trim());
    if (providerId == null) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final countText = _followingCount?.toString() ?? '—';
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            height: 380,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'يتابع ($countText)',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<ProviderProfile>>(
                    future: ProvidersApi().getProviderFollowing(providerId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'لا يتابع أحداً حالياً',
                              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, i) {
                          final provider = list[i];
                          final displayName = provider.displayName ?? 'مزود';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: provider.imageUrl != null && provider.imageUrl!.trim().isNotEmpty
                                  ? NetworkImage(provider.imageUrl!)
                                  : null,
                              child: provider.imageUrl == null || provider.imageUrl!.trim().isEmpty
                                  ? Text(displayName[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                            subtitle: provider.city != null
                                ? Text(
                                    provider.city!,
                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                                  )
                                : null,
                            trailing: provider.isVerifiedBlue || provider.isVerifiedGreen
                                ? Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: provider.isVerifiedBlue ? Colors.blue : Colors.green,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProviderProfileScreen(
                                    providerId: provider.id.toString(),
                                    providerName: provider.displayName,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: const CustomAppBar(title: 'المزود'),
        drawer: const CustomDrawer(),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 128,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          const Color(0xFF8F6ED6),
                          const Color(0xFF7F57CF),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    left: 12,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: _isFollowingProvider
                              ? 'إلغاء المتابعة'
                              : 'متابعة',
                          onPressed: _isFollowBusy ? null : _toggleFollowProvider,
                          icon: _isFollowBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isFollowingProvider
                                      ? Icons.person_remove_alt_1_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  color: Colors.white,
                                ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'مشاركة/إبلاغ',
                          onPressed: _showShareAndReportSheet,
                          icon: const Icon(Icons.ios_share, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: -42,
                    right: 18,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: bgColor,
                      child: ClipOval(
                        child: SizedBox(
                          width: 78,
                          height: 78,
                          child: _providerAvatar(),
                        ),
                      ),
                    ),
                  ),
                  if (providerVerified)
                    Positioned(
                      bottom: -12,
                      right: 24,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: mainColor.withValues(alpha: 0.25), width: 1),
                        ),
                        child: Center(
                          child: Icon(Icons.check_circle, color: mainColor, size: 18),
                        ),
                      ),
                    ),
                  if (_fullProfile?.isOnline == true)
                    Positioned(
                      bottom: -12,
                      right: 78,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor ?? Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 52),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, size: 14, color: secondaryTextColor),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.star,
                          size: 17,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          providerRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${_reviewersCount?.toString() ?? '0'})',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$providerOperations عملية',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _circleStat(
                      icon: Icons.business_center_outlined,
                      value: _completedRequests,
                      onTap: () {},
                      isDark: isDark,
                    ),
                    _circleStat(
                      icon: Icons.groups_rounded,
                      value: _followersCount,
                      onTap: _showFollowersList,
                      isDark: isDark,
                    ),
                    _circleStat(
                      icon: Icons.person_add_alt_1_rounded,
                      value: _followingCount,
                      onTap: _showFollowingList,
                      isDark: isDark,
                    ),
                    _circleStat(
                      icon: Icons.thumb_up_alt_outlined,
                      value: _likesCount,
                      onTap: () {},
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              if (_highlightItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _highlightsRow(isDark: isDark),
                ),
              ],
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!await checkFullClient(context)) return;
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ServiceRequestFormScreen(
                            providerName: providerName,
                            providerId: widget.providerId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'طلب خدمة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tabs.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final isSelected = _selectedTabIndex == index;
                    final bg = isSelected
                        ? mainColor.withValues(alpha: 0.14)
                        : (isDark ? Colors.grey[850]! : Colors.grey.shade100);
                    final border = isSelected
                        ? mainColor.withValues(alpha: 0.35)
                        : (isDark ? Colors.grey[750]! : Colors.grey.shade200);
                    final iconColor = isSelected ? mainColor : (isDark ? Colors.grey[300]! : Colors.grey.shade700);
                    final titleColor = isSelected ? mainColor : textColor;

                    return InkWell(
                      onTap: () => setState(() => _selectedTabIndex = index),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 98),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(tabs[index]['icon'], size: 22, color: iconColor),
                            const SizedBox(height: 6),
                            if (_canManageGallery && index == 2)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      tabs[index]['title'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: titleColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        if (!mounted) return;
                                        setState(() => _selectedTabIndex = 2);
                                        await _openManageGallery();
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.settings_outlined,
                                          size: 16,
                                          color: titleColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                tabs[index]['title'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTabContent(),
              ),
              const SizedBox(height: 30),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleStat({
    required IconData icon,
    required int? value,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final ring = isDark ? Colors.grey[750]! : Colors.grey.shade300;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value == null ? '—' : value.toString(),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(
              painter: _DashedCirclePainter(
                color: ring,
                strokeWidth: 2,
                dashLength: 5,
                gapLength: 4,
              ),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(icon, color: mainColor, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightsRow({required bool isDark}) {
    final items = _highlightItems;
    final textColor = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.grey[400]! : Colors.grey.shade700;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'لمحات مقدم الخدمة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const Spacer(),
            Text(
              'اسحب يمين/يسار',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              final isFav = _favoriteHighlightIndexes.contains(index);
              return InkWell(
                onTap: () => _openHighlights(index),
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        image: DecorationImage(
                          image: NetworkImage(item.fileUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.18),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _toggleHighlightFavorite(index),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openHighlights(int initialIndex) async {
    final items = _highlightItems;
    if (items.isEmpty) return;
    final safeIndex = initialIndex.clamp(0, items.length - 1);
    final item = items[safeIndex];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NetworkVideoPlayerScreen(
          url: item.fileUrl,
          title: providerName,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _profileTab();
      case 1:
        return _servicesTab();
      case 2:
        return _galleryTab();
      case 3:
        final int? providerId = int.tryParse((widget.providerId ?? '').toString());
        return ReviewsTab(
          providerId: providerId,
          embedded: true,
          onOpenChat: (customerName) async {
            if (!context.mounted) return;
            await ChatNav.openInbox(context);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _profileTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850]! : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    final hasPhone = providerPhone.trim().isNotEmpty;
    final hasWhatsApp =
        ((_fullProfile?.whatsapp ?? '').trim().isNotEmpty) ||
        hasPhone;
    final lat = providerLat;
    final lng = providerLng;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formCard(
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نبذة عن مقدم الخدمة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                providerServicesDetails,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: secondaryTextColor,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _formCard(
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            children: [
              _labeledField(
                label: 'المدينة',
                value: providerCityName.trim().isEmpty ? '—' : providerCityName,
                borderColor: borderColor,
                isDark: isDark,
              ),
              const Divider(height: 18),
              _labeledField(
                label: 'سنوات الخبرة',
                value: providerExperienceYears,
                borderColor: borderColor,
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasPhone ? _openPhoneCall : null,
                icon: const Icon(Icons.call_rounded, size: 18),
                label: Text(
                  hasPhone ? 'اتصال' : 'لا يوجد رقم اتصال',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasWhatsApp ? _openWhatsApp : null,
                icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Color(0xFF25D366)),
                label: const Text(
                  'واتساب',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openInAppChat,
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text(
              'محادثة داخل التطبيق',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
            ),
          ),
        ),

        if (lat != null && lng != null) ...[
          const SizedBox(height: 12),
          _formCard(
            cardColor: cardColor,
            borderColor: borderColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'موقع مقدم الخدمة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lng),
                        initialZoom: 13,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.nawafeth.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _formCard({
    required Color cardColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _labeledField({
    required String label,
    required String value,
    required Color borderColor,
    required bool isDark,
    Widget? trailing,
  }) {
    final secondary = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    final valueColor = isDark ? Colors.white : Colors.black;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: secondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value.trim().isEmpty ? '—' : value.trim(),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Widget _servicesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    Widget header() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'التصنيفات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          TextButton.icon(
            onPressed: _servicesLoading ? null : _loadProviderSubcategories,
            icon: Icon(Icons.refresh, color: mainColor),
            label: Text(
              'تحديث',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: mainColor,
              ),
            ),
          ),
        ],
      );
    }

    if (_servicesLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            header(),
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (_providerSubcategories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            header(),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'لا توجد تصنيفات محددة حالياً',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadProviderSubcategories,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        header(),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _providerSubcategories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final s = _providerSubcategories[index];
            final cat = (s.categoryName ?? '').trim();
            final subtitle = cat.isNotEmpty ? cat : '—';

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey.shade200,
                ),
              ),
              child: ListTile(
                title: Text(
                  s.name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                trailing: const Icon(Icons.label_outline),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _loadProviderSubcategories() async {
    final id = int.tryParse((widget.providerId ?? '').trim());
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _providerSubcategories = const [];
        _servicesLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _servicesLoading = true);

    try {
      final subs = await ProvidersApi().getProviderSubcategories(id);
      if (!mounted) return;
      setState(() {
        _providerSubcategories = subs;
        _servicesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _providerSubcategories = const [];
        _servicesLoading = false;
      });
    }
  }

  Widget _galleryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850]! : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mainColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.photo_library, color: mainColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معرض خدماتي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'الأقسام التي أضافها مقدم الخدمة مع المحتوى والوصف',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_portfolioLoading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_portfolioItems.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'لا يوجد محتوى في المعرض حالياً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: secondaryTextColor,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _portfolioItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, index) {
              final item = _portfolioItems[index];
              final isVideo = item.fileType.toLowerCase() == 'video';
              final isFav = _favoritePortfolioIds.contains(item.id);

              return InkWell(
                onTap: () async {
                  if (isVideo) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NetworkVideoPlayerScreen(
                          url: item.fileUrl,
                          title: providerName,
                        ),
                      ),
                    );
                    return;
                  }
                  if (!mounted) return;
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) {
                      return Dialog(
                        insetPadding: const EdgeInsets.all(12),
                        backgroundColor: Colors.transparent,
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
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              child: Image.network(
                                item.fileUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      isVideo ? Icons.videocam_rounded : Icons.image,
                                      size: 34,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (isVideo)
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(Icons.play_circle_fill, size: 46, color: Colors.white),
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _togglePortfolioFavorite(item),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: _portfolioFavoriteBusyIds.contains(item.id)
                                        ? const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            isFav ? Icons.favorite : Icons.favorite_border,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          item.caption.trim().isEmpty ? (isVideo ? 'فيديو' : 'صورة') : item.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final radius = (size.shortestSide / 2) - strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * 3.141592653589793 * radius;
    final dashCount =
        (circumference / (dashLength + gapLength)).floor().clamp(8, 200);
    final sweep = (2 * 3.141592653589793) / dashCount;
    final dashSweep = sweep * (dashLength / (dashLength + gapLength));

    for (int i = 0; i < dashCount; i++) {
      final start = (sweep * i);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}
