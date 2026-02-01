import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/account_api.dart';
import '../../services/api_config.dart';
import '../../services/providers_api.dart';

import '../../widgets/app_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/custom_drawer.dart';

import 'profile_tab.dart';
import 'services_tab.dart';
import 'reviews_tab.dart';
import '../verification_screen.dart';
import '../plans_screen.dart';
import '../additional_services_screen.dart';
import '../registration/steps/content_step.dart';
import '../interactive_screen.dart';

// ✅ شاشة إكمال الملف التعريفي (تكون موجودة عندك وتستدعي فيها القوالب)
import 'provider_profile_completion_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen>
    with SingleTickerProviderStateMixin {
  final Color mainColor = Colors.deepPurple;

  File? _profileImage;
  File? _coverImage;
  File? _reelVideo;

  late AnimationController _controller;

  final String _currentPlanName = "—";

  String? _providerShareLink;

  String? _providerDisplayName;
  String? _providerCity;

  int? _followersCount;
  int? _likesReceivedCount;

  // ✅ نسبة اكتمال الملف (متوافقة مع شاشة إكمال الملف التعريفي)
  double _profileCompletion = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _loadProviderHeaderData();
  }

  Future<void> _loadProviderHeaderData() async {
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

      final myProfile = await ProvidersApi().getMyProviderProfile();
      final providerDisplayName = (myProfile?['display_name'] ?? '').toString().trim();
      final providerCity = (myProfile?['city'] ?? '').toString().trim();

      // Compute completion percent using the exact same logic used in ProviderProfileCompletionScreen.
      double baseCompletion() {
        bool hasName() {
          final first = (me['first_name'] ?? '').toString().trim();
          final last = (me['last_name'] ?? '').toString().trim();
          final user = (me['username'] ?? '').toString().trim();
          return first.isNotEmpty || last.isNotEmpty || user.isNotEmpty;
        }

        bool hasPhone() => (me['phone'] ?? '').toString().trim().isNotEmpty;
        bool hasEmail() => (me['email'] ?? '').toString().trim().isNotEmpty;

        const baseMax = 0.30;
        final parts = <bool>[hasName(), hasPhone(), hasEmail()];
        final done = parts.where((v) => v).length;
        final ratio = done / parts.length;
        return (baseMax * ratio).clamp(0.0, baseMax);
      }

      const optionalTotal = 70;
      const sectionKeys = <String>[
        'service_details',
        'additional',
        'contact_full',
        'lang_loc',
        'content',
        'seo',
      ];

      Map<String, int> buildWeights() {
        final base = optionalTotal ~/ sectionKeys.length; // 11
        var remainder = optionalTotal - (base * sectionKeys.length); // 4
        final weights = <String, int>{};
        for (final k in sectionKeys) {
          final extra = remainder > 0 ? 1 : 0;
          if (remainder > 0) remainder -= 1;
          weights[k] = base + extra;
        }
        return weights;
      }

      final weights = buildWeights();
      final completedOptional = sectionKeys.where((id) {
        return prefs.getBool('provider_section_done_$id') == true;
      }).fold<int>(0, (sum, id) => sum + (weights[id] ?? 0));

      final completionPercent = (baseCompletion() + (completedOptional / 100.0)).clamp(0.0, 1.0);

      String? link;
      if (providerId != null) {
        // Public link (API endpoint is guaranteed to exist today).
        link = '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/providers/$providerId/';
      }
      if (!mounted) return;
      setState(() {
        _providerShareLink = link;
        _followersCount = followersCount;
        _likesReceivedCount = likesReceivedCount;
        _providerDisplayName = providerDisplayName.isEmpty ? null : providerDisplayName;
        _providerCity = providerCity.isEmpty ? null : providerCity;
        _profileCompletion = completionPercent;
      });
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // اختيار صورة الغلاف / الصورة الشخصية
  Future<void> _pickImage({required bool isCover}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        if (isCover) {
          _coverImage = File(picked.path);
        } else {
          _profileImage = File(picked.path);
        }
      });
    }
  }

  // اختيار فيديو ريلز
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      if (!context.mounted) return;
      setState(() {
        _reelVideo = File(picked.path);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم اختيار فيديو ريلز بنجاح")),
      );
    }
  }

  // نافذة QR
  void _showQrDialog() {
    final link = _providerShareLink;
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "رمز QR الخاص بك",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          link ?? 'لم يتم العثور على رابط الملف حالياً',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (link == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('الرابط غير متوفر حالياً')),
                              );
                              return;
                            }
                            Clipboard.setData(
                              ClipboardData(text: link),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("تم نسخ الكود")),
                            );
                          },
                          icon: const Icon(
                            Icons.copy,
                            color: Colors.deepPurple,
                          ),
                          tooltip: "نسخ",
                        ),
                        IconButton(
                          onPressed: () {
                            if (link == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('الرابط غير متوفر حالياً')),
                              );
                              return;
                            }
                            Share.share(link);
                          },
                          icon: const Icon(
                            Icons.share,
                            color: Colors.deepPurple,
                          ),
                          tooltip: "مشاركة",
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "إغلاق",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  // عنصر إحصائية بتصميم كرت
  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: mainColor),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: "Cairo",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: "Cairo",
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // أزرار التنقل الثلاثة
  Widget _dashboardButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: mainColor),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Cairo",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // كرت الباقة (ذهبي بسيط)
  Widget _planCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Color(0xFFF9A825)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentPlanName,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlansScreen()),
              );
            },
            child: const Text(
              "ترقية",
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 12,
                color: Color(0xFFF57F17),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ كرت اكتمال الملف — كامل الكرت ينقل إلى شاشة إكمال الملف التعريفي
  Widget _profileCompletionCard() {
    final percent = (_profileCompletion * 100).round();
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProviderProfileCompletionScreen(),
          ),
        );
        await _loadProviderHeaderData();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F4FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "اكتمال الملف",
                  style: TextStyle(
                    fontFamily: "Cairo",
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  "$percent%",
                  style: TextStyle(
                    fontFamily: "Cairo",
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: mainColor,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: mainColor.withValues(alpha: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: LinearProgressIndicator(
                value: _profileCompletion,
                minHeight: 6,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(mainColor),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "اضغط هنا لإكمال بقية بيانات ملفك التعريفي.",
              style: TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontFamily: "Cairo",
              ),
            ),
          ],
        ),
      ),
    );
  }

  // رأس الصفحة: غلاف + صورة شخصية + اسم
  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _pickImage(isCover: true),
          child: Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient:
                  _coverImage == null
                      ? LinearGradient(
                        colors: [
                          mainColor,
                          mainColor.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      )
                      : null,
              image:
                  _coverImage != null
                      ? DecorationImage(
                        image: FileImage(_coverImage!),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
          ),
        ),
        // زر الكاميرا وزر التبديل
        Positioned(
          top: 12,
          right: 16,
          child: SafeArea(
            bottom: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: Colors.deepPurple.shade100, width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isProvider', false);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.person_outline, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'تم التبديل إلى وضع العميل',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.indigo,
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      
                      Navigator.pushReplacementNamed(context, '/profile');
                    }
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.swap_horiz, // أيقونة تبديل أوضح
                          size: 20,
                          color: Colors.deepPurple,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'تبديل لنمط العميل',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // زر الكاميرا (يسار)
        Positioned(
          top: 12,
          left: 16,
          child: SafeArea(
            bottom: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black38, // لون أغمق قليلاً للشفافية
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: "تغيير الغلاف",
                onPressed: () => _pickImage(isCover: true),
              ),
            ),
          ),
        ),
        // صورة شخصية
        Positioned(
          bottom: -40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => _pickImage(isCover: false),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                      child:
                          _profileImage == null
                              ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 38,
                              )
                              : null,
                    ),
                  ),
                  Positioned(
                    bottom: 3,
                    right: 3,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: mainColor,
                      child: const Icon(
                        Icons.edit,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ريلز
  Widget _reelsRow() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _pickVideo,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: mainColor, width: 2),
                  color: Colors.white,
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: Icon(
                    _reelVideo == null ? Icons.add : Icons.edit,
                    color: mainColor,
                    size: 26,
                  ),
                ),
              ),
            );
          } else {
            return RotationTransition(
              turns: _controller,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFE1BEE7), Color(0xFFFFB74D)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.deepPurple,
                    size: 26,
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  // زر خدمة إضافية (pill)
  Widget _servicePill(
    IconData icon,
    String label,
    Color color, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: "Cairo",
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // الخدمات الإضافية
  Widget _extraServicesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              "خدمات إضافية لتعزيز ظهورك:",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontFamily: "Cairo",
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _servicePill(
                  Icons.campaign,
                  "ترويج",
                  Colors.green,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("خدمة الترويج قيد التطوير 🚀"),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _servicePill(
                  Icons.monetization_on,
                  "ترقية",
                  Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlansScreen()),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _servicePill(
                  Icons.verified,
                  "توثيق",
                  Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VerificationScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdditionalServicesScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "عرض كل الخدمات الإضافية",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Cairo",
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        drawer: const CustomDrawer(),
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: CustomAppBar(showSearchField: false, title: 'نافذتي'),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 52),
              
              // ✅ شارة توضيحية لنمط مزود الخدمة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.business_center, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'لوحة مزود الخدمة',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      _providerDisplayName ?? '—',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        color: Colors.black87,
                      ),
                    ),
                    if (_providerCity != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _providerCity!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'Cairo',
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // بطاقة رئيسية تحت الغلاف
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // الإحصائيات + الباقة + اكتمال الملف
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ✅ إحصائيات المتابعين والمتابعون
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const InteractiveScreen(
                                        mode: InteractiveMode.provider,
                                        initialTabIndex: 0,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.groups_rounded,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      _followersCount == null ? '—' : _followersCount.toString(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'متابع',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 40),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const InteractiveScreen(
                                        mode: InteractiveMode.provider,
                                        initialTabIndex: 1,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.thumb_up_alt_outlined,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      _likesReceivedCount == null ? '—' : _likesReceivedCount.toString(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'معجب',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _statItem(
                                icon: Icons.thumb_up_alt_outlined,
                                label: "إعجابات",
                                value: _likesReceivedCount == null ? "—" : _likesReceivedCount.toString(),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const InteractiveScreen(
                                        mode: InteractiveMode.provider,
                                        initialTabIndex: 1,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              _statItem(
                                icon: Icons.person_outline,
                                label: "عملاء",
                                value: "—",
                              ),
                              const SizedBox(width: 6),
                              _statItem(
                                icon: Icons.groups_rounded,
                                label: "متابعون",
                                value: _followersCount == null ? "—" : _followersCount.toString(),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const InteractiveScreen(
                                        mode: InteractiveMode.provider,
                                        initialTabIndex: 0,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              _statItem(
                                icon: Icons.qr_code,
                                label: "QR",
                                value: "",
                                onTap: _showQrDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _planCard(),
                          const SizedBox(height: 10),
                          _profileCompletionCard(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              _reelsRow(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _dashboardButton(Icons.person, "الملف الشخصي", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileTab(),
                            ),
                          );
                        }),
                        _dashboardButton(
                          Icons.home_repair_service,
                          "خدماتي",
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ServicesTab(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _dashboardButton(Icons.reviews, "المراجعات", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReviewsTab(),
                            ),
                          );
                        }),
                        _dashboardButton(
                          Icons.photo_library_outlined,
                          "معرض الأعمال",
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ContentStep(
                                      onBack: () => Navigator.pop(context),
                                      onNext: () => Navigator.pop(context),
                                    ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _extraServicesSection(),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
