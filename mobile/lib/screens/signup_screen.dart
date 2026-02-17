import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/app_bar.dart';

import '../services/auth_api.dart';
import '../services/account_api.dart';
import '../services/session_storage.dart';
import '../services/role_sync.dart';
import '../services/role_controller.dart';
import '../utils/local_user_state.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'terms_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedCity;
  bool _agreeToTerms = false;
  bool _loading = false;

  final _nameAllowedChars = RegExp(r'[A-Za-z\u0600-\u06FF ]');
  
  final List<String> _saudiCities = [
    'الرياض',
    'جدة',
    'مكة المكرمة',
    'المدينة المنورة',
    'الدمام',
    'الخبر',
    'الظهران',
    'الطائف',
    'تبوك',
    'بريدة',
    'خميس مشيط',
    'الهفوف',
    'حفر الباطن',
    'حائل',
    'نجران',
    'جازان',
    'ينبع',
    'القطيف',
    'أبها',
    'عرعر',
  ];

  @override
  void initState() {
    super.initState();
    _loadPhoneAndSetUsername();
  }
  
  Future<void> _loadPhoneAndSetUsername() async {
    final phone = await const SessionStorage().readPhone();
    if (phone != null && phone.isNotEmpty) {
      setState(() {
        _usernameController.text = '@$phone';
      });
    }
  }

  bool _isValidName(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[A-Za-z\u0600-\u06FF ]+$').hasMatch(v);
  }

  bool get _isPasswordValid => _passwordController.text.length >= 8;
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial =>
      _passwordController.text.contains(RegExp(r'[!@#\$&*~%^()\-_=+{};:,<.>]'));

  bool get _isAllValid =>
      _isValidName(_firstNameController.text) &&
      _isValidName(_lastNameController.text) &&
      _usernameController.text.isNotEmpty &&
      _selectedCity != null &&
      _emailController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text &&
      _isPasswordValid &&
      _hasLowercase &&
      _hasUppercase &&
      _hasNumber &&
      _hasSpecial &&
      _agreeToTerms;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    _submit();
  }

  Future<void> _skipForNow() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم المتابعة برقم الجوال فقط. يمكنك إكمال البيانات لاحقاً.'),
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _submit() async {
    if (!_agreeToTerms) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب الموافقة على الشروط والأحكام لإكمال التسجيل')),
      );
      return;
    }

    if (!_isAllValid) return;

    setState(() => _loading = true);
    try {
      final accessToken = await const SessionStorage().readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى التحقق برقم الجوال أولاً')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      await AuthApi().completeRegistration(
        accessToken: accessToken,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirm: _confirmPasswordController.text,
        acceptTerms: _agreeToTerms,
        city: _selectedCity,
      );

      // Best-effort: persist canonical identity (including userId) for per-user local state.
      try {
        final me = await AccountApi().me(accessToken: accessToken);

        String? nonEmpty(dynamic v) {
          final s = (v ?? '').toString().trim();
          return s.isEmpty ? null : s;
        }

        final userId = me['id'] is int ? me['id'] as int : int.tryParse((me['id'] ?? '').toString());
        if (userId != null) {
          await LocalUserState.setActiveUserId(userId);
        }

        await const SessionStorage().saveProfile(
          userId: userId,
          username: nonEmpty(me['username']) ?? _usernameController.text.trim(),
          email: nonEmpty(me['email']) ?? _emailController.text.trim(),
          firstName: nonEmpty(me['first_name']) ?? _firstNameController.text.trim(),
          lastName: nonEmpty(me['last_name']) ?? _lastNameController.text.trim(),
          phone: nonEmpty(me['phone']) ?? (await const SessionStorage().readPhone())?.trim(),
        );
      } catch (_) {
        await const SessionStorage().saveProfile(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: (await const SessionStorage().readPhone())?.trim(),
        );
      }

      // Best-effort: ensure local role flags match backend.
      try {
        await RoleSync.sync(accessToken: accessToken);
        await RoleController.instance.refreshFromPrefs();
      } catch (_) {
        // ignore
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إكمال التسجيل بنجاح')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إكمال التسجيل: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: const CustomDrawer(),
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF8F9FD),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: AppBar(
            backgroundColor: isDark ? Colors.grey[850] : Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Column(
              children: [
                const Text(
                  "✨ إنشاء حساب جديد",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  "انضم إلى منصة نوافذ",
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.grey[850]!,
                          Colors.grey[800]!,
                        ]
                      : [
                          Colors.white,
                          Colors.grey[50]!,
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header مع أيقونة
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFFA855F7),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '🎯',
                                style: TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "معلوماتك الشخصية",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Cairo',
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "املأ البيانات التالية لإكمال التسجيل",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Cairo',
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // الاسم الأول والأخير في صف واحد
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedField(
                            "الاسم الأول",
                            _firstNameController,
                            Icons.person_outline_rounded,
                            isDark: isDark,
                            keyboardType: TextInputType.name,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(_nameAllowedChars),
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEnhancedField(
                            "الاسم الأخير",
                            _lastNameController,
                            Icons.person_rounded,
                            isDark: isDark,
                            keyboardType: TextInputType.name,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(_nameAllowedChars),
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    
                    // اسم المستخدم (تلقائي)
                    _buildEnhancedField(
                      "اسم المستخدم",
                      _usernameController,
                      Icons.alternate_email_rounded,
                      isDark: isDark,
                      enabled: false,
                      hint: "يتم إنشاؤه تلقائياً",
                    ),
                    const SizedBox(height: 18),
                    
                    // المدينة
                    _buildCityDropdown(isDark),
                    const SizedBox(height: 18),
                    
                    // البريد الإلكتروني
                    _buildEnhancedField(
                      "البريد الإلكتروني",
                      _emailController,
                      Icons.email_outlined,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    
                    // كلمة المرور
                    _buildEnhancedField(
                      "كلمة المرور",
                      _passwordController,
                      Icons.lock_outline_rounded,
                      isDark: isDark,
                      obscure: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordValidation(),
                    const SizedBox(height: 18),
                    
                    // تأكيد كلمة المرور
                    _buildEnhancedField(
                      "تأكيد كلمة المرور",
                      _confirmPasswordController,
                      Icons.lock_open_rounded,
                      isDark: isDark,
                      obscure: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),
                    
                    // الموافقة على الشروط
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Checkbox(
                              value: _agreeToTerms,
                              onChanged: (val) =>
                                  setState(() => _agreeToTerms = val ?? false),
                              activeColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                children: [
                                  const TextSpan(text: 'أوافق على '),
                                  TextSpan(
                                    text: 'الشروط والأحكام',
                                    style: const TextStyle(
                                      color: Color(0xFF6366F1),
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const TermsScreen(),
                                          ),
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // زر إنشاء الحساب
                    Container(
                      decoration: BoxDecoration(
                        gradient: _isAllValid && !_loading
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF6366F1),
                                  Color(0xFFA855F7),
                                ],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                              )
                            : null,
                        color: _isAllValid && !_loading
                            ? null
                            : Colors.grey[400],
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _isAllValid && !_loading
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFF6366F1).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : [],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              (_isAllValid && !_loading) ? _onRegisterPressed : null,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: _loading
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: _isAllValid
                                            ? Colors.white
                                            : Colors.white70,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "إنشاء الحساب",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Cairo',
                                          color: _isAllValid
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loading ? null : _skipForNow,
                      child: Text(
                        "تخطي الآن والمتابعة برقم الجوال فقط",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: isDark ? Colors.grey[300] : Colors.black54,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscure = false,
    bool isDark = false,
    bool enabled = true,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Cairo',
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled
                ? (isDark ? Colors.grey[800] : Colors.white)
                : (isDark ? Colors.grey[850] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.grey[700]!
                  : const Color(0xFF6366F1).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            enabled: enabled,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Cairo',
              color: enabled
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.grey[600] : Colors.grey[500]),
            ),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
              prefixIcon: Icon(
                icon,
                color: enabled
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.grey[700] : Colors.grey[400]),
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCityDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "المدينة",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Cairo',
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.grey[700]!
                  : const Color(0xFF6366F1).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedCity,
            hint: Row(
              children: [
                Icon(
                  Icons.location_city_rounded,
                  color: const Color(0xFF6366F1).withOpacity(0.7),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'اختر مدينتك',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
            ),
            dropdownColor: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(14),
            items: _saudiCities.map((city) {
              return DropdownMenuItem<String>(
                value: city,
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Cairo',
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.location_on_rounded,
                      color: const Color(0xFF6366F1).withOpacity(0.6),
                      size: 18,
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCity = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'Cairo'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FaIcon(icon, size: 20, color: AppColors.deepPurple),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDADCE0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDADCE0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.deepPurple, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 14,
        ),
      ),
    );
  }

  Widget _buildPasswordValidation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidationRow("8 أحرف أو أكثر", _isPasswordValid),
        _buildValidationRow("حرف صغير", _hasLowercase),
        _buildValidationRow("حرف كبير", _hasUppercase),
        _buildValidationRow("رقم", _hasNumber),
        _buildValidationRow("رمز خاص", _hasSpecial),
      ],
    );
  }

  Widget _buildValidationRow(String text, bool valid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: valid ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Cairo',
              color: valid ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
