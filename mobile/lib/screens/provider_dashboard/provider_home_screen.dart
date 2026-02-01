
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/account_api.dart';
import '../../services/api_config.dart';
import '../../services/providers_api.dart';
import '../../services/reviews_api.dart';
import '../../services/role_controller.dart';
import '../../utils/user_scoped_prefs.dart';

import '../../widgets/bottom_nav.dart';
import '../../widgets/custom_drawer.dart';

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
  
  // Theme Colors for Provider (Professional Teal/Blue theme)
  final Color providerPrimary = const Color(0xFF00695C); // Teal 800
  final Color providerAccent = const Color(0xFF009688);  // Teal 500
  
  File? _profileImage;
  File? _coverImage;
  
  bool _isLoading = true;
  String? _providerDisplayName;
  String? _providerCity;
  String? _providerShareLink;
  int? _followersCount;
  int? _likesReceivedCount;
  double _profileCompletion = 0.0;

  double _ratingAvg = 0.0;
  int _ratingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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

      final providerDisplayName = (myProfile?['display_name'] ?? '').toString().trim();
      final providerCity = (myProfile?['city'] ?? '').toString().trim();

      // --- Profile Completion Logic (shared) ---
      final userId = await UserScopedPrefs.readUserId();
      final sectionDone = <String, bool>{};
      for (final id in ProviderCompletionUtils.sectionKeys) {
        final baseKey = 'provider_section_done_$id';
        sectionDone[id] =
            (await UserScopedPrefs.getBoolScoped(prefs, baseKey, userId: userId)) ?? false;
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
        final rating = await ReviewsApi().getProviderRatingSummary(providerId);
        final avg = rating?['avg_rating'] ??
            rating?['average'] ??
            rating?['avg'] ??
            rating?['rating'] ??
            0;
        final count = rating?['reviews_count'] ??
            rating?['count'] ??
            rating?['total'] ??
            0;

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
      }

      if (!mounted) return;
      setState(() {
        _providerShareLink = link;
        _followersCount = followersCount;
        _likesReceivedCount = likesReceivedCount;
        _providerDisplayName = providerDisplayName.isEmpty ? null : providerDisplayName;
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
        backgroundColor: const Color(0xFFF0F2F5),
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
                    icon: const Icon(Icons.qr_code, color: Colors.white),
                    onPressed: _showQrDialog,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (v) async {
                      if (v == 'client_mode') {
                        await _switchToClientMode();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                         value: 'client_mode',
                         child: Row(
                           children: [
                             Icon(Icons.person_outline, size: 20, color: Colors.black87),
                             SizedBox(width: 8),
                             Text('العودة لحساب العميل', style: TextStyle(fontFamily: 'Cairo')),
                           ],
                         ),
                      )
                    ],
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                       Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [providerPrimary, providerAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      if (_coverImage != null) Image.file(_coverImage!, fit: BoxFit.cover),
                      Container(color: Colors.black.withOpacity(0.3)),
                      
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 50),
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
                                    radius: 45,
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
                                fontSize: 20, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            if (_providerCity != null)
                              Text(
                                _providerCity!,
                                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(20),
                  child: Container(
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                 // Stats Cards
                 _buildStatsRow(),
                 const SizedBox(height: 16),
                 
                 // Completion Card
                 _buildCompletionCard(),
                 const SizedBox(height: 20),

                 // Main Actions Grid
                 _buildActionGrid(),
                 const SizedBox(height: 20),
                 
                 // Quick Links
                 _buildQuickLinks(),
                 const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
             label: 'المتابعين', 
             value: (_followersCount ?? 0).toString(),
             icon: Icons.people_outline,
             color: Colors.blue
          ),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _statItem(
             label: 'الإعجابات', 
             value: (_likesReceivedCount ?? 0).toString(),
             icon: Icons.favorite_border,
             color: Colors.red
          ),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _statItem(
             label: 'التقييم', 
             value: _ratingCount > 0
                ? '${_ratingAvg.toStringAsFixed(1)} (${_ratingCount})'
                : _ratingAvg.toStringAsFixed(1),
             icon: Icons.star_border,
             color: Colors.amber
          ),
        ],
      ),
    );
  }

  Widget _statItem({required String label, required String value, required IconData icon, required Color color}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'Cairo')),
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
          gradient: const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF00695C)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(color: const Color(0xFF00695C).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
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
            Expanded(child: _actionCard('الخدمات', Icons.design_services_outlined, Colors.purple, () => _navToServices())),
            const SizedBox(width: 16),
            Expanded(child: _actionCard('تتبع الطلبات', Icons.track_changes_outlined, Colors.orange, () => _navToOrders())),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _actionCard('التقييمات', Icons.rate_review_outlined, Colors.green, () => _navToReviews())),
            const SizedBox(width: 16),
            Expanded(child: _actionCard('الملف الشخصي', Icons.person_outline, Colors.blueGrey, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderProfileCompletionScreen())).then((_) => _loadProviderData());
            })),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('إعدادات سريعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _listTile('تعديل البيانات الأساسية', Icons.person_outline, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderProfileCompletionScreen()));
              }),
              Divider(height: 1, color: Colors.grey[100]),
              _listTile('إدارة الباقات والاشتراك', Icons.card_membership, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()));
              }),
               Divider(height: 1, color: Colors.grey[100]),
              _listTile('خدمات إضافية', Icons.add_box_outlined, () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const AdditionalServicesScreen()));
              }),
            ],
          ),
        )
      ],
    );
  }

  Widget _listTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
         padding: const EdgeInsets.all(8),
         decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
         child: Icon(icon, size: 20, color: Colors.black54),
      ),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }

  void _navToServices() {
    // Navigate to a screen that shows ServicesTab 
    // For simplicity I'll push a scaffolding containing the tab
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('خدماتي', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: providerPrimary, foregroundColor: Colors.white,),
      body: const ServicesTab(),
    )));
  }

  void _navToOrders() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderOrdersScreen()));
  }

  Future<void> _switchToClientMode() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري التبديل إلى حساب العميل...')),
    );
    await RoleController.instance.setProviderMode(false);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
  }

  void _navToReviews() {
     Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('التقييمات', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: providerPrimary, foregroundColor: Colors.white,),
      body: const ReviewsTab(),
    )));
  }
}
