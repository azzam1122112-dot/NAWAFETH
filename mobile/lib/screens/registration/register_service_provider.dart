import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../../utils/user_scoped_prefs.dart';

// استيراد الخطوات
import 'steps/personal_info_step.dart';
import 'steps/service_classification_step.dart';
import 'steps/contact_info_step.dart';

import '../../services/providers_api.dart';
import '../../services/account_api.dart';
import '../../services/role_controller.dart';
import '../../services/session_storage.dart';

import '../signup_screen.dart';

class RegisterServiceProviderPage extends StatefulWidget {
  const RegisterServiceProviderPage({super.key});

  @override
  State<RegisterServiceProviderPage> createState() =>
      _RegisterServiceProviderPageState();
}

class _RegisterServiceProviderPageState
    extends State<RegisterServiceProviderPage>
    with SingleTickerProviderStateMixin {
  static const String _draftPrefsKey = 'provider_registration_draft_v1';

  final List<String> stepTitles = [
    'المعلومات الأساسية',
    'تصنيف الاختصاص',
    'بيانات التواصل',
  ];

  int _currentStep = 0;
  late ScrollController _scrollController;
  late AnimationController _animationController;

  bool _showSuccessOverlay = false;
  bool _submitting = false;

  // Registration draft (required by backend)
  final TextEditingController _displayNameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _whatsappCtrl = TextEditingController();

  String _accountTypeAr = 'فرد';
  bool _acceptsUrgent = false;
  int? _selectedCategoryId;
  List<int> _selectedSubcategoryIds = [];
  
  // تتبع نسبة إكمال كل صفحة (من 0.0 إلى 1.0)
  Map<int, double> _stepCompletion = {
    0: 0.0, // المعلومات الأساسية
    1: 0.0, // تصنيف الاختصاص
    2: 0.0, // بيانات التواصل
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _loadDraft();
    _prefillFromAccount();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (_currentStep < stepTitles.length - 1) {
      setState(() {
        _currentStep++;
        _animationController.forward(from: 0);
      });
      _scrollToCurrentStep();
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserScopedPrefs.readUserId();
      final draft = <String, dynamic>{
        'display_name': _displayNameCtrl.text,
        'bio': _bioCtrl.text,
        'city': _cityCtrl.text,
        'phone': _phoneCtrl.text,
        'whatsapp': _whatsappCtrl.text,
        'account_type_ar': _accountTypeAr,
        'accepts_urgent': _acceptsUrgent,
        'step': _currentStep,
      };
      await UserScopedPrefs.setStringScoped(
        prefs,
        _draftPrefsKey,
        jsonEncode(draft),
        userId: userId,
      );
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserScopedPrefs.readUserId();
      final raw = await UserScopedPrefs.getStringScoped(
        prefs,
        _draftPrefsKey,
        userId: userId,
      );
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      if (_displayNameCtrl.text.trim().isEmpty) {
        _displayNameCtrl.text = (decoded['display_name'] ?? '').toString();
      }
      if (_bioCtrl.text.trim().isEmpty) {
        _bioCtrl.text = (decoded['bio'] ?? '').toString();
      }
      if (_cityCtrl.text.trim().isEmpty) {
        _cityCtrl.text = (decoded['city'] ?? '').toString();
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        _phoneCtrl.text = (decoded['phone'] ?? '').toString();
      }
      if (_whatsappCtrl.text.trim().isEmpty) {
        _whatsappCtrl.text = (decoded['whatsapp'] ?? '').toString();
      }
      final at = (decoded['account_type_ar'] ?? '').toString().trim();
      if (at.isNotEmpty) {
        _accountTypeAr = at;
      }
      final au = decoded['accepts_urgent'];
      if (au is bool) {
        _acceptsUrgent = au;
      }

      if (!mounted) return;
      setState(() {
        // Keep user on the same step only if it's within range
        final s = decoded['step'];
        final step = s is int ? s : int.tryParse((s ?? '').toString());
        if (step != null && step >= 0 && step < stepTitles.length) {
          _currentStep = step;
        }
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _prefillFromAccount() async {
    // Fast prefill from local storage (so fields are populated immediately).
    try {
      const storage = SessionStorage();
      final localFull = (await storage.readFullName())?.trim();
      final localPhone = (await storage.readPhone())?.trim();

      if (_phoneCtrl.text.trim().isEmpty && localPhone != null && localPhone.isNotEmpty) {
        _phoneCtrl.text = localPhone;
      }
      if (_displayNameCtrl.text.trim().isEmpty && localFull != null && localFull.isNotEmpty) {
        _displayNameCtrl.text = localFull;
      }
    } catch (_) {
      // ignore
    }

    try {
      final me = await AccountApi().me();
      final phone = (me['phone'] ?? '').toString().trim();
      final first = (me['first_name'] ?? '').toString().trim();
      final last = (me['last_name'] ?? '').toString().trim();
      final fullName = ('$first $last').trim();

      if (_phoneCtrl.text.trim().isEmpty && phone.isNotEmpty) {
        _phoneCtrl.text = phone;
      }
      if (_displayNameCtrl.text.trim().isEmpty && fullName.isNotEmpty) {
        _displayNameCtrl.text = fullName;
      }

      // Persist latest identity best-effort.
      String? nonEmpty(dynamic v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }
      await const SessionStorage().saveProfile(
        username: nonEmpty(me['username']),
        email: nonEmpty(me['email']),
        firstName: nonEmpty(me['first_name']),
        lastName: nonEmpty(me['last_name']),
        phone: nonEmpty(me['phone']),
      );
      await _saveDraft();
    } catch (_) {
      // ignore
    }
  }

  void _onNextFromStep0() {
    final displayName = _displayNameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    if (displayName.isEmpty || bio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أكمل بيانات هذه الصفحة قبل المتابعة (الاسم الكامل + النبذة).',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    _saveDraft();
    _goToNextStep();
  }

  void _onNextFromStep1() {
    _saveDraft();
    _goToNextStep();
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _animationController.forward(from: 0);
      });
      _scrollToCurrentStep();
    }
  }

  void _scrollToCurrentStep() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final screenWidth =
          box?.constraints.maxWidth ?? MediaQuery.of(context).size.width;
      const itemWidth = 120.0;
      final offset =
          (_currentStep * itemWidth) - (screenWidth / 2 - itemWidth / 2);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          offset.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _updateStepCompletion(int step, double completionPercent) {
    setState(() {
      _stepCompletion[step] = completionPercent.clamp(0.0, 1.0);
    });
  }

  String _providerTypeToBackend(String ar) {
    final v = ar.trim();
    if (v == 'منشأة') return 'company';
    return 'individual';
  }

  Future<void> _submitProviderRegistration() async {
    if (_submitting) return;

    final displayName = _displayNameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    // Required across the 3-step flow.
    if (displayName.isEmpty || bio.isEmpty || city.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أكمل البيانات المطلوبة: الاسم، النبذة، المدينة، رقم الهاتف.'),
        ),
      );
      return;
    }

    await _saveDraft();

    setState(() {
      _submitting = true;
    });

    try {
      // Ensure the primary phone is saved on the user account.
      // Provider registration endpoint does not include phone in its payload.
      await AccountApi().updateMe({'phone': phone});

      await ProvidersApi().registerProvider(
        providerType: _providerTypeToBackend(_accountTypeAr),
        displayName: displayName,
        bio: bio,
        city: city,
        acceptsUrgent: _acceptsUrgent,
        subcategoryIds: _selectedSubcategoryIds.isNotEmpty ? _selectedSubcategoryIds : null,
      );
      final whatsapp = _whatsappCtrl.text.trim();
      if (whatsapp.isNotEmpty) {
        await ProvidersApi().updateMyProviderProfile({
          'whatsapp': whatsapp,
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isProviderRegistered', true);
      await RoleController.instance.setProviderMode(true);
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.removeScoped(prefs, _draftPrefsKey, userId: userId);

      if (!mounted) return;
      setState(() {
        _showSuccessOverlay = true;
      });
    } on DioException catch (e) {
      String msg = 'تعذر التسجيل كمقدم خدمة. حاول مرة أخرى.';
      final data = e.response?.data;
      if (data is Map) {
        final detail = (data['detail'] ?? '').toString().trim();
        if (detail.isNotEmpty) {
          msg = detail;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      // If backend still blocks by role, guide user to complete registration.
      if ((e.response?.statusCode ?? 0) == 403) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ غير متوقع أثناء التسجيل.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  double get _completionPercent {
    // حساب مجموع نسب إكمال جميع الصفحات
    double totalCompletion = _stepCompletion.values.reduce((a, b) => a + b);
    // القسمة على عدد الصفحات للحصول على النسبة الإجمالية
    return totalCompletion / stepTitles.length;
  }

  Widget _buildStepItem(String title, int index) {
    final bool isActive = index == _currentStep;
    final bool isCompleted = index < _currentStep;

    final Color activeColor = Colors.deepPurple;
    final Color completedColor = Colors.green;
    final Color circleColor =
        isCompleted
            ? completedColor
            : (isActive ? activeColor : Colors.grey.shade300);
    final Color iconColor =
        isActive || isCompleted ? Colors.white : Colors.black87;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: isActive ? 34 : 30,
          height: isActive ? 34 : 30,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : [],
          ),
          child: Center(
            child: Icon(
              isCompleted ? Icons.check : Icons.circle,
              size: isCompleted ? 18 : 10,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 110,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // شريط علوي
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      "التسجيل كمقدم خدمة",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            // مؤشرات الخطوات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SizedBox(
                height: 74,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: stepTitles.length,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder:
                      (context, index) =>
                          _buildStepItem(stepTitles[index], index),
                ),
              ),
            ),

            // شريط التقدم + نص بسيط
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: LinearProgressIndicator(
                            value: _completionPercent,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.orangeAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "${(_completionPercent * 100).round()}%",
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "ثلاث خطوات بسيطة لإنشاء حسابك المبدئي.",
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final steps = [
      PersonalInfoStep(
        onNext: _onNextFromStep0,
        onValidationChanged: (percent) => _updateStepCompletion(0, percent),
        displayNameController: _displayNameCtrl,
        bioController: _bioCtrl,
        initialAccountType: _accountTypeAr,
        onAccountTypeChanged: (v) => _accountTypeAr = v,
      ),
      ServiceClassificationStep(
        onNext: _onNextFromStep1,
        onBack: _goToPreviousStep,
        onValidationChanged: (percent) => _updateStepCompletion(1, percent),
        onUrgentChanged: (v) => _acceptsUrgent = v,
        onCategoriesChanged: (categoryId, subcategoryIds) {
          _selectedCategoryId = categoryId;
          _selectedSubcategoryIds = subcategoryIds;
        },
      ),
      ContactInfoStep(
        onNext: _submitProviderRegistration,
        onBack: _goToPreviousStep,
        isInitialRegistration: true,
        isFinalStep: true,
        onValidationChanged: (percent) => _updateStepCompletion(2, percent),
        phoneExternalController: _phoneCtrl,
        whatsappExternalController: _whatsappCtrl,
        cityExternalController: _cityCtrl,
      ),
    ];

    // Keep step widgets mounted to avoid losing user input when navigating back.
    return IndexedStack(
      index: _currentStep,
      children: steps,
    );
  }

  Widget _buildSuccessCard(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الأيقونة
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  "🎉 تم إنشاء حسابك بنجاح",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // نسبة إكمال الملف الشخصي (30% فقط بعد التسجيل)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "نسبة إكمال الملف: %30",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "تم تسجيلك كمزود خدمة لدى تطبيق نوافذ.\nأصبح لديك الآن حساب كمقدم خدمة، يمكنك إكمال ملفك التعريفي لتحسين ظهورك أمام العملاء.",
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontFamily: 'Cairo',
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F4FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.deepPurple.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: const [
                      _SuccessHintRow(
                        icon: Icons.person_outline,
                        text: "أضف تفاصيل أكثر عنك وعن خبراتك.",
                      ),
                      SizedBox(height: 4),
                      _SuccessHintRow(
                        icon: Icons.home_repair_service_outlined,
                        text: "عرّف بخدماتك وأعمالك السابقة.",
                      ),
                      SizedBox(height: 4),
                      _SuccessHintRow(
                        icon: Icons.language_outlined,
                        text: "حدّد لغاتك وموقعك الجغرافي.",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // زر الانتقال للوحة المزود (سأكمل الآن)
                ElevatedButton(
                  onPressed: () async {
                    // ✅ حفظ نوع المستخدم كمقدم خدمة
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isProviderRegistered', true);
                    await RoleController.instance.setProviderMode(true);
                    
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/profile',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "الانتقال إلى لوحة المزود و إكمال الملف",
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    // ✅ حفظ نوع المستخدم كمقدم خدمة حتى لو أغلق الآن
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isProviderRegistered', true);
                    await RoleController.instance.setProviderMode(true);
                    
                    if (!context.mounted) return;
                    // الرجوع للصفحة الرئيسية
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    "إغلاق الآن (سأكمل لاحقًا)",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.black54,
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            body: Column(
              children: [
                _buildStepHeader(),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: _buildStepContent(),
                  ),
                ),
              ],
            ),
          ),

          if (_submitting)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  ),
                ),
              ),
            ),

          if (_showSuccessOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: _buildSuccessCard(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuccessHintRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SuccessHintRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.deepPurple),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Cairo',
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
