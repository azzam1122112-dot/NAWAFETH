import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/app_bar.dart';

import '../services/auth_api.dart';
import '../services/session_storage.dart';
import '../services/role_sync.dart';
import '../services/role_controller.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeToTerms = false;
  bool _loading = false;

  final _nameAllowedChars = RegExp(r'[A-Za-z\u0600-\u06FF ]');

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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegisterPressed() {
    _submit();
  }

  Future<void> _submit() async {
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
      );

      await const SessionStorage().saveProfile(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

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
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: const CustomAppBar(title: "إنشاء حساب جديد"),
      backgroundColor: const Color(0xFFF2F3F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildField(
                  "الاسم الأول",
                  _firstNameController,
                  FontAwesomeIcons.idCard,
                  keyboardType: TextInputType.name,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(_nameAllowedChars),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _buildField(
                  "الاسم الأخير",
                  _lastNameController,
                  FontAwesomeIcons.idCard,
                  keyboardType: TextInputType.name,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(_nameAllowedChars),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _buildField(
                  "اسم المستخدم",
                  _usernameController,
                  FontAwesomeIcons.user,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _buildField(
                  "البريد الإلكتروني",
                  _emailController,
                  FontAwesomeIcons.envelope,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _buildField(
                  "كلمة المرور",
                  _passwordController,
                  FontAwesomeIcons.lock,
                  obscure: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _buildPasswordValidation(),
                const SizedBox(height: 16),
                _buildField(
                  "تأكيد كلمة المرور",
                  _confirmPasswordController,
                  FontAwesomeIcons.lockOpen,
                  obscure: true,
                ),
                const SizedBox(height: 20),
                CheckboxListTile(
                  value: _agreeToTerms,
                  onChanged:
                      (val) => setState(() => _agreeToTerms = val ?? false),
                  title: const Text(
                    "أوافق على الشروط والأحكام",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  activeColor: AppColors.deepPurple,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: (_isAllValid && !_loading) ? _onRegisterPressed : null,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    "إنشاء الحساب",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (_loading) ...[
                  const SizedBox(height: 14),
                  const Center(
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
