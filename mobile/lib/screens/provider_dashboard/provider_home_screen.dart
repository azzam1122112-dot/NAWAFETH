
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/account_api.dart';
import '../../services/api_config.dart';
import '../../services/providers_api.dart';
import '../../services/reviews_api.dart';
import '../../services/account_switcher.dart';
import '../../constants/colors.dart';

import '../../widgets/bottom_nav.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/profile_account_modes_panel.dart';
import '../../widgets/account_switch_sheet.dart';
import '../../widgets/profile_action_card.dart';
import '../../widgets/profile_quick_links_panel.dart';

import 'services_tab.dart'; 
import 'reviews_tab.dart'; 
import 'provider_completion_utils.dart';
import 'provider_orders_screen.dart';
import 'provider_profile_completion_screen.dart';
import '../plans_screen.dart';
import '../additional_services_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen>
    with SingleTickerProviderStateMixin {
  
  final Color providerPrimary = AppColors.deepPurple;
  final Color providerAccent = AppColors.primaryDark;
  
  File? _profileImage;
  File? _coverImage;
  
  bool _isLoading = true;
  String? _providerDisplayName;
  String? _providerUsername;
  String? _providerCity;
  String? _providerShareLink;
  int? _followersCount;
  int? _likesReceivedCount;
  double _profileCompletion = 0.0;

  double _ratingAvg = 0.0;
  int _ratingCount = 0;
  bool _switchingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    try {
      final me = await AccountApi().me();
      final id = me['provider_profile_id'];
      final int? providerId = id is int ? id : int.tryParse((id ?? '').toString());

      int? asInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse((v ?? '').toString());
      }

      final followersCount = asInt(me['provider_followers_count']);
      final likesReceivedCount = asInt(me['provider_likes_received_count']);

      Map<String, dynamic>? myProfile;
      try {
        myProfile = await ProvidersApi().getMyProviderProfile();
      } catch (_) {}
      List<int> subcategoryIds = <int>[];
      try {
        subcategoryIds = await ProvidersApi().getMyProviderSubcategories();
      } catch (_) {
        subcategoryIds = <int>[];
      }

      final providerDisplayName = (myProfile?['display_name'] ?? '').toString().trim();
      final providerUsername = (me['username'] ?? '').toString().trim();
      final providerCity = (myProfile?['city'] ?? '').toString().trim();

      // --- Profile Completion Logic (backend-driven) ---
      bool hasAnyString(dynamic v) => (v ?? '').toString().trim().isNotEmpty;
      bool hasAnyList(dynamic v) =>
          v is List && v.any((e) => (e ?? '').toString().trim().isNotEmpty);
      final sectionDone = <String, bool>{
        'service_details': subcategoryIds.isNotEmpty,
        'contact_full':
            hasAnyString(myProfile?['whatsapp']) ||
            hasAnyString(myProfile?['website']) ||
            hasAnyList(myProfile?['social_links']),
        'lang_loc':
            hasAnyList(myProfile?['languages']) ||
            (myProfile?['lat'] != null && myProfile?['lng'] != null),
        'additional':
            hasAnyString(myProfile?['about_details']) ||
            hasAnyList(myProfile?['qualifications']) ||
            hasAnyList(myProfile?['experiences']),
        'content': hasAnyList(myProfile?['content_sections']),
        'seo':
            hasAnyString(myProfile?['seo_keywords']) ||
            hasAnyString(myProfile?['seo_meta_description']) ||
            hasAnyString(myProfile?['seo_slug']),
      };
      for (final key in ProviderCompletionUtils.sectionKeys) {
        sectionDone.putIfAbsent(key, () => false);
      }
      final completionPercent = ProviderCompletionUtils.completionPercent(
        me: me,
        sectionDone: sectionDone,
      );
      // ----------------------------------------

      String? link;
      if (providerId != null) {
        link = '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/providers/$providerId/';
      }

      // --- Provider Rating (real, non-dummy) ---
      double ratingAvg = 0.0;
      int ratingCount = 0;
      if (providerId != null) {
        try {
          final rating = await ReviewsApi().getProviderRatingSummary(providerId);
          final avg = rating['rating_avg'] ?? 0;
          final count = rating['rating_count'] ?? 0;

        double asDouble(dynamic v) {
          if (v is double) return v;
          if (v is int) return v.toDouble();
          if (v is num) return v.toDouble();
          return double.tryParse((v ?? '').toString()) ?? 0.0;
        }

        int asIntSafe(dynamic v) {
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse((v ?? '').toString()) ?? 0;
        }

          ratingAvg = asDouble(avg);
          ratingCount = asIntSafe(count);
          if (ratingCount <= 0) {
            ratingAvg = 0.0;
            ratingCount = 0;
          }
        } catch (_) {
          // ignore: keep defaults
        }
      }

      if (!mounted) return;
      setState(() {
        _providerShareLink = link;
        _followersCount = followersCount;
        _likesReceivedCount = likesReceivedCount;
        _providerDisplayName = providerDisplayName.isEmpty ? null : providerDisplayName;
        _providerUsername = providerUsername.isEmpty ? null : providerUsername;
        _providerCity = providerCity.isEmpty ? null : providerCity;
        _profileCompletion = completionPercent;
        _ratingAvg = ratingAvg;
        _ratingCount = ratingCount;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage({required bool isCover}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        isCover ? _coverImage = File(picked.path) : _profileImage = File(picked.path);
      });
    }
  }

  void _showQrDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('QR ملف المزود', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: providerPrimary)),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                height: 200,
                child: _providerShareLink == null 
                  ? const Center(child: Text('الرابط غير متوفر'))
                  : QrImageView(data: _providerShareLink!, padding: EdgeInsets.zero,),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _providerShareLink == null ? null : () {
                   Clipboard.setData(ClipboardData(text: _providerShareLink!));
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرابط')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('نسخ الرابط', style: TextStyle(fontFamily: 'Cairo')),
                style: ElevatedButton.styleFrom(backgroundColor: providerPrimary, foregroundColor: Colors.white),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: providerPrimary)),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.primaryLight,
        drawer: const CustomDrawer(),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 280.0,
                floating: false,
                pinned: true,
                backgroundColor: providerPrimary,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                    onPressed: () async => AccountSwitcher.show(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                    onPressed: _showQrDialog,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              providerPrimary,
                              providerAccent,
                              AppColors.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      if (_coverImage != null) Image.file(_coverImage!, fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 54),
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    color: Colors.white24,
                                  ),
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                                    child: _profileImage == null ? Icon(Icons.storefront, size: 40, color: providerPrimary) : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _pickImage(isCover: false),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _providerDisplayName ?? 'مزود خدمة محترف',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_providerUsername != null)
                              Text(
                                '@$_providerUsername',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            if (_providerCity != null)
                              Text(
                                _providerCity!,
                                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                              ),
                            const SizedBox(height: 5),
                            Text(
                              'نافذتي - مقدم الخدمة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 40,
                        left: 16,
                        child: GestureDetector(
                          onTap: () => _pickImage(isCover: true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'غطاء',
                                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(30),
                  child: Container(
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: RefreshIndicator(
            color: AppColors.deepPurple,
            onRefresh: _loadProviderData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildStatsRow(),
                  const SizedBox(height: 14),
                  _buildAccountModesSection(),
                  const SizedBox(height: 14),
                  _buildCompletionCard(),
                  const SizedBox(height: 18),
                  _buildActionGrid(),
                  const SizedBox(height: 18),
                  _buildQuickLinks(),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
      ),
    );
  }

  Widget _buildAccountModesSection() {
    return ProfileAccountModesPanel(
      isProviderRegistered: true,
      isProviderActive: true,
      isSwitching: _switchingAccount,
      onSelectMode: _onSelectMode,
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
             label: 'المتابعين', 
             value: (_followersCount ?? 0).toString(),
             icon: Icons.people_outline,
             color: AppColors.deepPurple,
          ),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _statItem(
             label: 'الإعجابات', 
             value: (_likesReceivedCount ?? 0).toString(),
             icon: Icons.thumb_up_alt_outlined,
             color: AppColors.deepPurple,
          ),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _statItem(
             label: 'التقييم', 
             value: _ratingCount > 0
                ? '${_ratingAvg.toStringAsFixed(1)} ($_ratingCount)'
                : _ratingAvg.toStringAsFixed(1),
             icon: Icons.star_rounded,
             color: AppColors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _statItem({required String label, required String value, required IconData icon, required Color color}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Cairo',
            color: AppColors.softBlue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionCard() {
    final percent = (_profileCompletion * 100).round();
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProviderProfileCompletionScreen()),
        );
        await _loadProviderData();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.deepPurple]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(color: AppColors.deepPurple.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _profileCompletion,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 4,
                ),
                Text('$percent%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أكمل ملفك التعريفي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('زيادة اكتمال الملف تزيد من ظهورك في البحث', style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ProfileActionCard(
                title: 'الخدمات',
                icon: Icons.design_services_outlined,
                accent: AppColors.deepPurple,
                compact: true,
                onTap: _navToServices,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ProfileActionCard(
                title: 'تتبع الطلبات',
                icon: Icons.track_changes_outlined,
                accent: AppColors.deepPurple,
                compact: true,
                onTap: _navToOrders,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ProfileActionCard(
                title: 'التقييمات',
                icon: Icons.rate_review_outlined,
                accent: AppColors.deepPurple,
                compact: true,
                onTap: _navToReviews,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ProfileActionCard(
                title: 'الملف الشخصي',
                icon: Icons.person_outline,
                accent: AppColors.deepPurple,
                compact: true,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderProfileCompletionScreen()))
                      .then((_) => _loadProviderData());
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickLinks() {
    return ProfileQuickLinksPanel(
      title: 'إعدادات سريعة',
      items: [
        ProfileQuickLinkItem(
          title: 'إدارة الباقات والاشتراك',
          icon: Icons.card_membership,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()));
          },
        ),
        ProfileQuickLinkItem(
          title: 'خدمات إضافية',
          icon: Icons.add_box_outlined,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdditionalServicesScreen()));
          },
        ),
      ],
    );
  }

  void _navToServices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('خدماتي', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: providerPrimary,
            foregroundColor: Colors.white,
          ),
          body: const ServicesTab(embedded: true),
        ),
      ),
    );
  }

  void _navToOrders() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderOrdersScreen()));
  }

  void _navToReviews() {
     Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('التقييمات', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: providerPrimary, foregroundColor: Colors.white,),
      body: const ReviewsTab(embedded: true),
    )));
  }

  Future<void> _onSelectMode(AccountMode mode) async {
    if (_switchingAccount) return;
    setState(() => _switchingAccount = true);
    try {
      await AccountSwitcher.switchTo(context, mode);
    } finally {
      if (mounted) {
        setState(() => _switchingAccount = false);
      }
    }
  }
}
