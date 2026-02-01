import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_nav.dart';
import 'interactive_screen.dart';
import 'registration/register_service_provider.dart';
import 'provider_dashboard/provider_home_screen.dart';
import 'login_settings_screen.dart';
import '../widgets/custom_drawer.dart';
import '../services/account_api.dart';
import '../services/session_storage.dart';
import '../services/role_controller.dart';
import '../constants/colors.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with SingleTickerProviderStateMixin {
  final Color mainColor = AppColors.deepPurple;
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
      final hasProviderProfile = me['has_provider_profile'] == true;

      final isProviderRegisteredBackend = hasProviderProfile;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isProviderRegistered', isProviderRegisteredBackend);

      if (!isProviderRegisteredBackend) {
        await prefs.setBool('isProvider', false);
      }

      await RoleController.instance.refreshFromPrefs();

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
        phone: phone,
      );

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
      // Best-effort
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

  Future<void> _checkUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isProviderUser = prefs.getBool('isProvider') ?? false;
    final bool isRegistered = prefs.getBool('isProviderRegistered') ?? false;
    
    if (mounted) {
      setState(() {
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
            padding: const EdgeInsets.all(24),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'QR نافذتي',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepPurple
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 200,
                    height: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: link == null
                        ? const Center(child: Text('غير متوفر', style: TextStyle(fontFamily: 'Cairo')))
                        : QrImageView(data: link, padding: EdgeInsets.zero),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: link == null
                              ? null
                              : () async {
                                  await Clipboard.setData(ClipboardData(text: link));
                                  if (!context.mounted) return;
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ الرابط')),
                                  );
                                },
                           style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.deepPurple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                           ),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('نسخ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: link == null
                              ? null
                              : () async {
                                  await Share.share(link);
                                },
                          style: OutlinedButton.styleFrom(
                             foregroundColor: AppColors.deepPurple,
                             side: const BorderSide(color: AppColors.deepPurple),
                             padding: const EdgeInsets.symmetric(vertical: 12),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('مشاركة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && isProvider) {
      return const ProviderHomeScreen();
    }
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.deepPurple),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
      );
    }
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD), // Slightly off-white very clean background
        drawer: const CustomDrawer(),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 280.0,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.deepPurple,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                actions: [
                   IconButton(
                    icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                    onPressed: _showClientQrDialog,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                       // Cover Image or Gradient
                       _coverImage != null
                          ? Image.file(_coverImage!, fit: BoxFit.cover)
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.deepPurple, Color(0xFF8E44AD)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                        // Dark Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                        ),
                        
                        // User Info Centered
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 40),
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.2),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1)
                                    ),
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.white,
                                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                                      child: _profileImage == null
                                          ? const Icon(Icons.person, size: 50, color: AppColors.deepPurple)
                                          : null,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _pickImage(isCover: false),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.accentOrange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _fullName ?? 'مستخدم نافذة',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_username != null)
                                Text(
                                  '@$_username',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Edit Cover Button
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
                      color: Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Quick Stats
                _buildQuickStats(),
                const SizedBox(height: 24),
                
                // Account Type Badge
                _buildAccountTypeBadge(),
                const SizedBox(height: 24),

                // Main Action Cards
                _buildActionGrid(),
                
                const SizedBox(height: 24),

                // Provider Switch / Registration Section
                _buildProviderSection(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
      ),
    );
  }

  Widget _buildAccountTypeBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(Icons.verified_user_outlined, color: Colors.grey[600], size: 20),
           const SizedBox(width: 8),
           Text(
             'حساب عميل',
             style: TextStyle(
               fontFamily: 'Cairo',
               fontWeight: FontWeight.bold,
               color: Colors.grey[800],
               fontSize: 14
             ),
           ),
           if (_phone != null) ...[
             Container(
               margin: const EdgeInsets.symmetric(horizontal: 12),
               height: 16,
               width: 1,
               color: Colors.grey[300],
             ),
             Text(
               _phone!,
               style: TextStyle(
                 fontFamily: 'Cairo',
                 color: Colors.grey[600],
                 fontSize: 14
               ),
             ),
           ]
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem(
          value: _followingCount?.toString() ?? '0',
          label: 'أتابع',
          icon: Icons.person_add_alt_1_rounded,
          onTap: () {
            // Navigate to Following
             final isProviderAccount = RoleController.instance.notifier.value.isProvider;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InteractiveScreen(
                    mode: isProviderAccount ? InteractiveMode.provider : InteractiveMode.client,
                    initialTabIndex: 0,
                  ),
                ),
              );
          },
        ),
        Container(width: 1, height: 40, color: Colors.grey[300]),
        _statItem(
          value: _likesCount?.toString() ?? '0',
          label: 'مفضلتي',
          icon: Icons.thumb_up_alt_rounded,
          onTap: () {
             // Navigate to Favorites
             final isProviderAccount = RoleController.instance.notifier.value.isProvider;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InteractiveScreen(
                    mode: isProviderAccount ? InteractiveMode.provider : InteractiveMode.client,
                    initialTabIndex: 1,
                  ),
                ),
              );
          },
        ),
        Container(width: 1, height: 40, color: Colors.grey[300]),
        _statItem(
          value: '0', 
          label: 'نقاطي',
          icon: Icons.star_rounded,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _statItem({required String value, required String label, required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.deepPurple.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.deepPurple, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.softBlue,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return _profileEntryCard(
      title: 'الملف الشخصي',
      subtitle: 'إدارة بياناتك وإعدادات الدخول',
      icon: Icons.person_outline_rounded,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginSettingsScreen()),
        );
      },
    );
  }

  Widget _profileEntryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.deepPurple.withValues(alpha: 0.95),
                        AppColors.deepPurple.withValues(alpha: 0.70),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.softBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionCard({required String title, required IconData icon, required Color color, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
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
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.softBlue
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderSection() {
    if (isProviderRegistered) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CA1AF).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
             Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(
                     color: Colors.white.withValues(alpha: 0.2),
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: const Icon(Icons.dashboard_customize_outlined, color: Colors.white),
                 ),
                 const SizedBox(width: 12),
                 const Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'نافذة مزود الخدمة',
                         style: TextStyle(
                           fontFamily: 'Cairo',
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           color: Colors.white,
                         ),
                       ),
                       Text(
                         'إدارة خدماتك وعملائك في مكان واحد',
                         style: TextStyle(
                           fontFamily: 'Cairo',
                           fontSize: 12,
                           color: Colors.white70,
                         ),
                       ),
                     ],
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 20),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: () async {
                    await _syncRoleFromBackend();
                    final prefs = await SharedPreferences.getInstance();
                    final canSwitchToProvider = (prefs.getBool('isProviderRegistered') ?? false) == true;
                    
                    if (!canSwitchToProvider) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('حسابك عميل فقط حالياً. سجّل كمقدم خدمة أولاً.')),
                      );
                      return;
                    }

                    await RoleController.instance.setProviderMode(true);

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('جاري الانتقال إلى لوحة مقدم الخدمة...'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    setState(() { _isLoading = true; });
                    await _checkUserType();

                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/provider_dashboard',
                      (route) => false,
                    );
                 },
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.white,
                   foregroundColor: const Color(0xFF2C3E50),
                   elevation: 0,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   padding: const EdgeInsets.symmetric(vertical: 14),
                 ),
                 child: const Text(
                   'الدخول إلى لوحة مقدم الخدمة',
                   style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                 ),
               ),
             ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.deepPurple.withValues(alpha: 0.1)),
          boxShadow: [
             BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5)
             )
          ]
        ),
        child: Column(
          children: [
            const Icon(Icons.rocket_launch_outlined, size: 48, color: AppColors.deepPurple),
            const SizedBox(height: 16),
            const Text(
              'هل لديك مهارة؟',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.softBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'انضم إلى نخبة مزودي الخدمات وابدأ في زيادة دخلك اليوم معنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterServiceProviderPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('سجل كمقدم خدمة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }
  }
}
