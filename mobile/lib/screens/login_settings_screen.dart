import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dio/dio.dart';

import '../services/account_api.dart';
import '../services/session_storage.dart';

/// أيقونة Face ID: أيقونة شخص داخل مربع
class FaceIDIcon extends StatelessWidget {
  final double size;
  final Color color;
  const FaceIDIcon({super.key, this.size = 26, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.person_outline, color: color, size: size * 0.7),
    );
  }
}

class LoginSettingsScreen extends StatefulWidget {
  const LoginSettingsScreen({super.key});

  @override
  State<LoginSettingsScreen> createState() => _LoginSettingsScreenState();
}

class _LoginSettingsScreenState extends State<LoginSettingsScreen> {
  // بيانات من الجلسة
  String fullName = '';
  String username = '';
  String email = '';
  String phone = '';
  String password = '********';

  bool _saving = false;

  String _keepDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  /// Normalizes to local Saudi format: 05XXXXXXXX (10 digits).
  /// Returns null if the value is not a valid local Saudi mobile.
  String? _normalizeSaudiToLocal05(String input) {
    final digits = _keepDigits(input.trim());
    if (RegExp(r'^05\d{8}$').hasMatch(digits)) return digits;
    if (RegExp(r'^5\d{8}$').hasMatch(digits)) return '0$digits';
    if (RegExp(r'^9665\d{8}$').hasMatch(digits)) return '0${digits.substring(3)}';
    if (RegExp(r'^009665\d{8}$').hasMatch(digits)) return '0${digits.substring(5)}';
    return null;
  }

  // متحكمات
  final TextEditingController securityCodeCtrl = TextEditingController();
  final TextEditingController confirmSecurityCodeCtrl = TextEditingController();
  final TextEditingController faceIdCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  @override
  void dispose() {
    securityCodeCtrl.dispose();
    confirmSecurityCodeCtrl.dispose();
    faceIdCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIdentity() async {
    const storage = SessionStorage();
    final full = (await storage.readFullName())?.trim();
    final u = (await storage.readUsername())?.trim();
    final e = (await storage.readEmail())?.trim();
    final p = (await storage.readPhone())?.trim();

    if (!mounted) return;
    setState(() {
      fullName = (full == null || full.isEmpty) ? '' : full;
      username = (u == null || u.isEmpty) ? '' : u;
      email = (e == null || e.isEmpty) ? '' : e;
      phone = (p == null || p.isEmpty) ? '' : (_normalizeSaudiToLocal05(p) ?? p);
    });
  }

  Future<void> _saveAccountChanges() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final loggedIn = await const SessionStorage().isLoggedIn();
      if (!loggedIn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
        );
        return;
      }

      final patch = <String, dynamic>{};
      final u = username.trim();
      final p = phone.trim();
      final e = email.trim();

      if (u.isNotEmpty) patch['username'] = u;
      if (p.isNotEmpty) {
        final normalized = _normalizeSaudiToLocal05(p);
        if (normalized == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الجوال غير صحيح. مثال: 05xxxxxxxx'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        patch['phone'] = normalized;
      }
      if (e.isNotEmpty) patch['email'] = e;

      if (patch.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد تغييرات للحفظ')),
        );
        return;
      }

      final updated = await AccountApi().updateMe(patch);

      String? nonEmpty(dynamic v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }

      final firstName = nonEmpty(updated['first_name']);
      final lastName = nonEmpty(updated['last_name']);
      final updatedUsername = nonEmpty(updated['username']) ?? u;
      final updatedEmail = nonEmpty(updated['email']) ?? e;
      final updatedPhone = nonEmpty(updated['phone']) ?? p;

      await const SessionStorage().saveProfile(
        username: updatedUsername,
        email: updatedEmail,
        firstName: firstName,
        lastName: lastName,
        phone: updatedPhone,
      );

      if (!mounted) return;
      setState(() {
        username = updatedUsername;
        email = updatedEmail;
        phone = _normalizeSaudiToLocal05(updatedPhone) ?? updatedPhone;
        final parts = [
          if (firstName != null) firstName,
          if (lastName != null) lastName,
        ];
        fullName = parts.isEmpty ? fullName : parts.join(' ');
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ البيانات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      if (password != '********') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تغيير كلمة المرور غير مدعوم من هذه الشاشة حالياً')),
        );
      }
    } on DioException catch (e) {
      String message = 'تعذر حفظ البيانات، تحقق من الاتصال ثم أعد المحاولة';
      final data = e.response?.data;
      if (data is Map) {
        final detail = (data['detail'] ?? '').toString().trim();
        if (detail.isNotEmpty) {
          message = detail;
        } else {
          // Try to show first field error (e.g., phone/username/email).
          for (final entry in data.entries) {
            final key = entry.key?.toString();
            final val = entry.value;
            if (key == null) continue;
            if (val is List && val.isNotEmpty) {
              message = val.first.toString();
              break;
            }
            if (val is String && val.trim().isNotEmpty) {
              message = val.trim();
              break;
            }
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ البيانات، تحقق من الاتصال ثم أعد المحاولة'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إعدادات الدخول'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ✅ الهيدر
          Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.deepPurple,
                child: const Icon(Icons.person, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 12),
              Text(
                (fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : '')),
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (username.isNotEmpty)
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),

          // 🟣 معلومات الحساب
          _buildSection('معلومات الحساب', [
            _buildEditableField(
              icon: Icons.person_outline,
              label: 'اسم العضوية',
              value: username,
              onChanged: (val) => setState(() => username = val),
            ),
            _buildEditableField(
              icon: Icons.phone_android,
              label: 'رقم الجوال',
              value: phone,
              onChanged: (val) => setState(() => phone = val),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              maxLength: 10,
              hint: '05xxxxxxxx',
            ),
          ]),

          const SizedBox(height: 20),

          // 🔵 الأمان
          _buildSection('الأمان', [
            _buildEditableField(
              icon: Icons.email_outlined,
              label: 'البريد الإلكتروني',
              value: email,
              onChanged: (val) => setState(() => email = val),
            ),
            _buildEditableField(
              icon: Icons.lock_outline,
              label: 'كلمة المرور',
              value: password,
              isPassword: true,
              onChanged: (val) => setState(() => password = val),
            ),
            const SizedBox(height: 12),
            _buildPurpleButton(
              icon: Icons.key,
              label: 'إضافة رمز دخول آمان',
              onPressed: _showSecurityDialog,
            ),
          ]),

          const SizedBox(height: 20),

          // 🟢 طرق الدخول الإضافية
          _buildSection('طرق الدخول الإضافية', [
            _buildPurpleButton(
              iconWidget: const FaceIDIcon(size: 22, color: Colors.white),
              label: 'الدخول بمعرف الوجه',
              onPressed: _showFaceIdDialog,
            ),
          ]),

          const SizedBox(height: 30),

          // ✅ زر الحفظ
          ElevatedButton(
            onPressed: _saving ? null : _saveAccountChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'حفظ التغييرات',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// ✅ نافذة كرت رمز الأمان
  void _showSecurityDialog() {
    securityCodeCtrl.clear();
    confirmSecurityCodeCtrl.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Center(
          child: Card(
            color: Colors.white,
            elevation: 12,
            shadowColor: Colors.black45,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.deepPurple),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ),
                    const Text(
                      'إضافة رمز دخول آمان',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '⚠️ احتفظ بالرمز في مكان آمن ولا تشاركه مع أحد.',
                      style: TextStyle(fontFamily: 'Cairo'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: securityCodeCtrl,
                      decoration: const InputDecoration(labelText: 'رمز الآمان'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmSecurityCodeCtrl,
                      decoration: const InputDecoration(labelText: 'تأكيد رمز الآمان'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final code = securityCodeCtrl.text.trim();
                        final confirm = confirmSecurityCodeCtrl.text.trim();

                        if (code.isEmpty || confirm.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى إدخال الرمز وتأكيده'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (code != confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('رمز التأكيد غير مطابق'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(dialogContext);
                        await const SessionStorage().saveSecurityCode(code);
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('تم حفظ رمز الآمان'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// ✅ نافذة كرت Face ID
  void _showFaceIdDialog() {
    faceIdCodeCtrl.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Center(
          child: Card(
            color: Colors.white,
            elevation: 12,
            shadowColor: Colors.black45,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.deepPurple),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ),
                    const Text(
                      'إعداد الدخول بمعرف الوجه',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'قم بتأكيد هويتك عبر إدخال رمز تحقق لتفعيل الدخول بمعرف الوجه.',
                      style: TextStyle(fontFamily: 'Cairo'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: faceIdCodeCtrl,
                      decoration: const InputDecoration(labelText: 'أدخل رمز التحقق'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final code = faceIdCodeCtrl.text.trim();
                        if (code.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يرجى إدخال رمز التحقق'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(dialogContext);
                        await const SessionStorage().saveFaceIdCode(code);
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('تم حفظ إعداد معرف الوجه'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('تأكيد'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🟣 بناء قسم
  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.deepPurple.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  // 🟣 حقل إدخال
  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool isPassword = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? hint,
  }) {
    final controller = TextEditingController(text: value);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          labelText: label,
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.deepPurple),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
      ),
    );
  }

  // 🟣 زر بنفسجي
  Widget _buildPurpleButton({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: iconWidget ?? Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
/*
import 'package:flutter/material.dart';

import '../services/account_api.dart';
import '../services/session_storage.dart';

/// أيقونة Face ID: أيقونة شخص داخل مربع
class FaceIDIcon extends StatelessWidget {
  final double size;
  final Color color;
  const FaceIDIcon({super.key, this.size = 26, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.person_outline, color: color, size: size * 0.7),
    );
  }
}

class LoginSettingsScreen extends StatefulWidget {
  const LoginSettingsScreen({super.key});

  @override
  State<LoginSettingsScreen> createState() => _LoginSettingsScreenState();
}

class _LoginSettingsScreenState extends State<LoginSettingsScreen> {
  // بيانات من الجلسة
  String fullName = '';
  String username = '';
  String email = '';
  String phone = '';
  String password = "********";

  bool _saving = false;

  // متحكمات
  final TextEditingController securityCodeCtrl = TextEditingController();
  final TextEditingController confirmSecurityCodeCtrl = TextEditingController();
  final TextEditingController faceIdCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    const storage = SessionStorage();
    final full = (await storage.readFullName())?.trim();
    final u = (await storage.readUsername())?.trim();
    final e = (await storage.readEmail())?.trim();
    final p = (await storage.readPhone())?.trim();

    if (!mounted) return;
    setState(() {
      fullName = (full == null || full.isEmpty) ? '' : full;
      username = (u == null || u.isEmpty) ? '' : u;
      email = (e == null || e.isEmpty) ? '' : e;
      phone = (p == null || p.isEmpty) ? '' : p;
    });
  }

  Future<void> _saveAccountChanges() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final loggedIn = await const SessionStorage().isLoggedIn();
      if (!loggedIn) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
        );
        return;
      }

      final patch = <String, dynamic>{};
      final u = username.trim();
      final p = phone.trim();
      final e = email.trim();

      if (u.isNotEmpty) patch['username'] = u;
      if (p.isNotEmpty) patch['phone'] = p;
      if (e.isNotEmpty) patch['email'] = e;

      if (patch.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد تغييرات للحفظ')),
        );
        return;
      }

      final updated = await AccountApi().updateMe(patch);

      String? nonEmpty(dynamic v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }

      final firstName = nonEmpty(updated['first_name']);
      final lastName = nonEmpty(updated['last_name']);
      final updatedUsername = nonEmpty(updated['username']) ?? u;
      final updatedEmail = nonEmpty(updated['email']) ?? e;
      final updatedPhone = nonEmpty(updated['phone']) ?? p;

      await const SessionStorage().saveProfile(
        username: updatedUsername,
        email: updatedEmail,
        firstName: firstName,
        lastName: lastName,
        phone: updatedPhone,
      );

      if (!mounted) return;
      setState(() {
        username = updatedUsername;
        email = updatedEmail;
        phone = updatedPhone;
        final parts = [
          if (firstName != null) firstName,
          if (lastName != null) lastName,
        ];
        fullName = parts.isEmpty ? fullName : parts.join(' ');
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ البيانات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      if (password != '********') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تغيير كلمة المرور غير مدعوم من هذه الشاشة حالياً')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ البيانات، تحقق من الاتصال ثم أعد المحاولة'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("إعدادات الدخول"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ✅ الهيدر
          Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.deepPurple,
                child: const Icon(Icons.person, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 12),
              Text(
                (fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : '')),
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: "Cairo",
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (username.isNotEmpty)
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: "Cairo",
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                email,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: "Cairo",
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),

          // 🟣 معلومات الحساب
          _buildSection("معلومات الحساب", [
            _buildEditableField(
              icon: Icons.person_outline,
              label: "اسم العضوية",
              value: username,
              onChanged: (val) => setState(() => username = val),
            ),
            _buildEditableField(
              icon: Icons.phone_android,
              label: "رقم الجوال",
              value: phone,
              onChanged: (val) => setState(() => phone = val),
            ),
          ]),

          const SizedBox(height: 20),

          // 🔵 الأمان
          _buildSection("الأمان", [
            _buildEditableField(
              icon: Icons.email_outlined,
              label: "البريد الإلكتروني",
              value: email,
              onChanged: (val) => setState(() => email = val),
            ),
            _buildEditableField(
              icon: Icons.lock_outline,
              label: "كلمة المرور",
              value: password,
              isPassword: true,
              onChanged: (val) => setState(() => password = val),
            ),
            const SizedBox(height: 12),
            _buildPurpleButton(
              icon: Icons.key,
              label: "إضافة رمز دخول آمان",
              onPressed: () {
                _showSecurityDialog();
              },
            ),
          ]),

          const SizedBox(height: 20),

          // 🟢 طرق الدخول الإضافية
          _buildSection("طرق الدخول الإضافية", [
            _buildPurpleButton(
              iconWidget: const FaceIDIcon(size: 22, color: Colors.white),
              label: "الدخول بمعرف الوجه",
              onPressed: () {
                _showFaceIdDialog();
              },
            ),
          ]),

          const SizedBox(height: 30),

          // ✅ زر الحفظ
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("تم حفظ التغييرات"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              onPressed: _saving ? null : _saveAccountChanges,
              style: TextStyle(
                fontSize: 16,
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
              child: _saving
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                : const Text(
                  "حفظ التغييرات",
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: "Cairo",
                    fontWeight: FontWeight.bold,
                  ),
                ),
      builder:
          (context) => Center(
            child: Card(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black45,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر إغلاق
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.deepPurple,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        "إضافة رمز دخول آمان",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "⚠️ احتفظ بالرمز في مكان آمن ولا تشاركه مع أحد.",
                        style: TextStyle(fontFamily: 'Cairo'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: securityCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: "رمز الآمان",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: confirmSecurityCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: "تأكيد رمز الآمان",
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("تم حفظ رمز الآمان"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("حفظ"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  /// ✅ نافذة كرت Face ID
  void _showFaceIdDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Center(
            child: Card(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black45,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر إغلاق
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.deepPurple,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        "إعداد الدخول بمعرف الوجه",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "قم بتأكيد هويتك عبر إدخال رمز تحقق لتفعيل الدخول بمعرف الوجه.",
                        style: TextStyle(fontFamily: 'Cairo'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: faceIdCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: "أدخل رمز التحقق",
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("تم حفظ إعداد معرف الوجه"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("تأكيد"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  // 🟣 بناء قسم
  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.deepPurple.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  // 🟣 حقل إدخال
  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    bool isPassword = false,
  }) {
    final controller = TextEditingController(text: value);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.deepPurple),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
      ),
    );
  }

  // 🟣 زر بنفسجي
  Widget _buildPurpleButton({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: iconWidget ?? Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
*/
