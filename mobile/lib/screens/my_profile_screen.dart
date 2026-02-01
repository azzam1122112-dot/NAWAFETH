import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import 'interactive_screen.dart';
import 'registration/register_service_provider.dart';
import 'provider_dashboard/provider_home_screen.dart';
import '../widgets/custom_drawer.dart';
import '../services/account_api.dart';
import '../services/session_storage.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with SingleTickerProviderStateMixin {
  final Color mainColor = Colors.deepPurple;
  File? _profileImage;
  File? _coverImage;
  bool isProvider = false;
  bool isProviderRegistered = false;
  bool _isLoading = true;
  String? _fullName;
  String? _username;
  String? _phone;
  String? _email;
  int? _followingCount;
  int? _likesCount;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadIdentityFromStorage();
    _refreshRoleAndUserType();
  }

  Future<void> _refreshRoleAndUserType() async {
    await _syncRoleFromBackend();
    await _checkUserType();
  }

  Future<void> _syncRoleFromBackend() async {
    try {
      final loggedIn = await const SessionStorage().isLoggedIn();
      if (!loggedIn) return;

      final me = await AccountApi().me();
      final role = (me['role_state'] ?? '').toString().trim();
      final hasProviderProfile = me['has_provider_profile'] == true;
      final isProviderFlag = me['is_provider'] == true;

      // We only allow switching to provider mode when a provider profile exists.
      // This avoids showing/allowing the provider account for pure-client users.
      final isProviderRegisteredBackend = hasProviderProfile;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isProviderRegistered', isProviderRegisteredBackend);

      // Defensive: if backend says not a provider, force provider mode off.
      if (!isProviderRegisteredBackend) {
        await prefs.setBool('isProvider', false);
      }

      // Sync identity + real counters (best-effort)
      String? nonEmpty(dynamic v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }

      final firstName = nonEmpty(me['first_name']);
      final lastName = nonEmpty(me['last_name']);
      final username = nonEmpty(me['username']);
      final email = nonEmpty(me['email']);
      final phone = nonEmpty(me['phone']);

      final fullNameParts = [
        if (firstName != null) firstName,
        if (lastName != null) lastName,
      ];
      final fullName = fullNameParts.isEmpty ? null : fullNameParts.join(' ');

      await const SessionStorage().saveProfile(
        username: username,
        email: email,
        firstName: firstName,
        lastName: lastName,
      );
      if (phone != null) {
        await const SessionStorage().savePhone(phone);
      }

      int? asInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        final s = (v ?? '').toString().trim();
        return int.tryParse(s);
      }

      if (!mounted) return;
      setState(() {
        _userId = asInt(me['id']);
        _fullName = fullName;
        _username = username;
        _email = email;
        _phone = phone;
        _followingCount = asInt(me['following_count']);
        _likesCount = asInt(me['likes_count']);
      });
    } catch (_) {
      // Best-effort: keep local state if backend call fails.
    }
  }

  Future<void> _loadIdentityFromStorage() async {
    const storage = SessionStorage();
    final fullName = (await storage.readFullName())?.trim();
    final username = (await storage.readUsername())?.trim();
    final email = (await storage.readEmail())?.trim();
    final phone = (await storage.readPhone())?.trim();
    if (!mounted) return;
    setState(() {
      _fullName = (fullName == null || fullName.isEmpty) ? null : fullName;
      _username = (username == null || username.isEmpty) ? null : username;
      _email = (email == null || email.isEmpty) ? null : email;
      _phone = (phone == null || phone.isEmpty) ? null : phone;
    });
  }

  // ✅ التحقق من نوع المستخدم
  Future<void> _checkUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isProviderUser = prefs.getBool('isProvider') ?? false;
    final bool isRegistered = prefs.getBool('isProviderRegistered') ?? false;
    
    if (mounted) {
      setState(() {
        // Never enter provider mode unless provider profile exists.
        isProvider = isProviderUser && isRegistered;
        isProviderRegistered = isRegistered;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage({required bool isCover}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        isCover
            ? _coverImage = File(picked.path)
            : _profileImage = File(picked.path);
      });
    }
  }

  String? _buildClientShareLink() {
    final id = _userId;
    if (id == null) return null;

    // Deep-link style payload (real, deterministic, no fake numbers).
    // If/when a public web profile exists, this can be swapped to https URL.
    return 'nawafeth://user/$id';
  }

  void _showClientQrDialog() {
    final link = _buildClientShareLink();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2, size: 22, color: Colors.deepPurple),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'QR نافذتي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 190,
                    height: 190,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child:
                        link == null
                            ? const Center(
                              child: Text(
                                'غير متوفر حالياً',
                                style: TextStyle(fontFamily: 'Cairo'),
                              ),
                            )
                            : QrImageView(
                              data: link,
                              padding: EdgeInsets.zero,
                            ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    link ?? '—',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              link == null
                                  ? null
                                  : () async {
                                    await Clipboard.setData(ClipboardData(text: link));
                                    if (!context.mounted) return;
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('تم نسخ الرابط')),
                                    );
                                  },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text(
                            'نسخ الرابط',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              link == null
                                  ? null
                                  : () async {
                                    // share_plus already in dependencies.
                                    // ignore: avoid_dynamic_calls
                                    await Share.share(link);
                                  },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text(
                            'مشاركة',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statCircle({
    required IconData icon,
    required String value,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey.shade900 : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: mainColor.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: mainColor, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ إذا كان مقدم خدمة، عرض لوحة المزود
    if (!_isLoading && isProvider) {
      return const ProviderHomeScreen();
    }
    
    // ✅ إذا كان قيد التحميل، عرض شاشة تحميل
    if (_isLoading) {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: CustomAppBar(showSearchField: false),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.deepPurple,
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
      );
    }
    
    // ✅ عرض بروفايل العميل العادي
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final followingText = _followingCount == null ? '—' : _followingCount.toString();
    final favoritesText = _likesCount == null ? '—' : _likesCount.toString();
    final interactionCount = (_followingCount != null && _likesCount != null)
      ? (_followingCount! + _likesCount!)
      : null;
    final interactionText = interactionCount == null ? '—' : interactionCount.toString();
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // ✅ أضف هذا السطر لفتح القائمة من اليسار
      drawer: const CustomDrawer(),

      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: CustomAppBar(showSearchField: false, title: 'نافذتي'),
      ),

      bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 190,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient:
                            _coverImage == null
                                ? LinearGradient(
                                  colors: [
                                    isDark ? Colors.deepPurple.shade800 : mainColor,
                                    isDark ? Colors.deepPurple.shade900.withValues(alpha: 0.6) : mainColor.withValues(alpha: 0.6),
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
                      child: Stack(
                        children: [
                          // ✅ زر تعديل الغلاف (مطابق للتصميم: زر "تعديل")
                          Positioned(
                            top: 8,
                            left: 16,
                            child: SafeArea(
                              bottom: false,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _pickImage(isCover: true),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.90),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'تعديل',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ✅ زر QR (يسار الهيدر مثل التصميم)
                          Positioned(
                            top: 92,
                            left: 16,
                            child: SafeArea(
                              bottom: false,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _showClientQrDialog,
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.qr_code_2,
                                      color: Colors.deepPurple,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // ✅ زر التبديل إلى وضع مقدم الخدمة (يظهر فقط إذا كان مسجلاً)
                          if (isProviderRegistered)
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
                                        await _syncRoleFromBackend();
                                        final prefs = await SharedPreferences.getInstance();
                                        final canSwitchToProvider =
                                            (prefs.getBool('isProviderRegistered') ?? false) == true;
                                        if (!canSwitchToProvider) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.info_outline, color: Colors.white),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'حسابك عميل فقط حالياً. سجّل كمقدم خدمة أولاً.',
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.deepPurple,
                                              duration: const Duration(seconds: 4),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }

                                        await prefs.setBool('isProvider', true);

                                        if (!context.mounted) return;

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.white),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'جاري الانتقال للوحة التحكم...',
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );

                                        setState(() {
                                          _isLoading = true;
                                        });
                                        await _checkUserType();
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
                                            Text(
                                              'لوحة مقدم الخدمة',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 14,
                                              color: Colors.deepPurple,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      top: 130,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.grey[800] : Colors.white,
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                                backgroundImage:
                                    _profileImage != null
                                        ? FileImage(_profileImage!)
                                        : null,
                                child:
                                    _profileImage == null
                                        ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 40,
                                        )
                                        : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _pickImage(isCover: false),
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: mainColor,
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                
                // ✅ شارة حساب العميل لتوضيح الواجهة
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'حساب مستخدم',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_fullName != null) ...[
                  Text(
                    _fullName!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                ],
                if (_username != null)
                  Text(
                    '@$_username',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.black54,
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (_phone != null || _email != null) ...[
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      if (_phone != null)
                        Text(
                          _phone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.black54,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (_email != null)
                        Text(
                          _email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.black54,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // ✅ شريط الأيقونات/الإحصائيات (مطابق للتصميم)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      _statCircle(
                        icon: Icons.bookmark_border,
                        value: favoritesText,
                        onTap: () {
                          // ينتقل لتفاعلي > المحفوظات
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InteractiveScreen(initialTabIndex: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      _statCircle(
                        icon: Icons.person_outline,
                        value: followingText,
                        onTap: () {
                          // ينتقل لتفاعلي > من أتابع
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InteractiveScreen(initialTabIndex: 0),
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      _statCircle(
                        icon: Icons.thumb_up_alt_outlined,
                        value: interactionText,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InteractiveScreen(initialTabIndex: 0),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // ✅ يظهر زر التسجيل كمقدم خدمة فقط إذا لم يكن مسجلاً بعد
                if (!isProviderRegistered)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.deepPurple.shade900.withValues(alpha: 0.3)
                            : mainColor.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'انضم الآن وشارك مهاراتك مع الباحثين عنها بسهولة!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const RegisterServiceProviderPage(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.person_add_alt_1,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'سجل كمقدم خدمة',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.deepPurple.shade700
                                  : mainColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          Positioned(
            top: 190,
            left: 20,
            right: 20,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
