import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/user_scoped_prefs.dart';

import '../../../services/account_api.dart';
import '../../../services/providers_api.dart';

class ContactInfoStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// إذا كانت هذه الشاشة تُستخدم في التسجيل الأولي (حقول أساسية فقط)
  final bool isInitialRegistration;

  /// تستخدم لتغيير نص الزر إلى "إنهاء التسجيل"
  final bool isFinalStep;
  
  final Function(double)? onValidationChanged;

  // Optional external controllers (used by initial provider registration flow)
  final TextEditingController? phoneExternalController;
  final TextEditingController? whatsappExternalController;
  final TextEditingController? cityExternalController;

  const ContactInfoStep({
    super.key,
    required this.onNext,
    required this.onBack,
    this.isInitialRegistration = false,
    this.isFinalStep = false,
    this.onValidationChanged,
    this.phoneExternalController,
    this.whatsappExternalController,
    this.cityExternalController,
  });

  @override
  State<ContactInfoStep> createState() => _ContactInfoStepState();
}

class _ContactInfoStepState extends State<ContactInfoStep> {
  static const String _draftKeyFull = 'provider_contact_info_draft_full_v1';
  static const String _draftKeyInitial = 'provider_contact_info_draft_initial_v1';

  // Controllers
  late final TextEditingController websiteController;
  late final TextEditingController phoneController;
  late final TextEditingController whatsappController;
  late final TextEditingController cityController;
  late final List<TextEditingController> socialControllers;

  late final bool _ownsPhone;
  late final bool _ownsWhatsapp;
  late final bool _ownsCity;

  // Logo
  final ImagePicker _picker = ImagePicker();
  File? _logoFile;

  bool _loadingFromBackend = false;
  bool _saving = false;
  String? _initialWhatsapp;

  Timer? _draftTimer;
  Timer? _patchTimer;
  String? _lastPatchedWhatsapp;

  // Accordion state (للوضع الكامل فقط)
  Map<String, bool> expanded = {
    "website": false,
    "social": false,
    "whatsapp": false,
    "phone": false,
  };

  final socialIcons = [
    FontAwesomeIcons.linkedin,
    FontAwesomeIcons.facebook,
    FontAwesomeIcons.youtube,
    FontAwesomeIcons.instagram,
    FontAwesomeIcons.xTwitter,
    FontAwesomeIcons.snapchatGhost,
    FontAwesomeIcons.pinterest,
    FontAwesomeIcons.tiktok,
    FontAwesomeIcons.behance,
  ];

  final socialLabels = [
    "LinkedIn",
    "Facebook",
    "YouTube",
    "Instagram",
    "X (Twitter)",
    "Snapchat",
    "Pinterest",
    "TikTok",
    "Behance",
  ];

  @override
  void initState() {
    super.initState();

    websiteController = TextEditingController();
    _ownsPhone = widget.phoneExternalController == null;
    _ownsWhatsapp = widget.whatsappExternalController == null;
    _ownsCity = widget.cityExternalController == null;
    phoneController = widget.phoneExternalController ?? TextEditingController();
    whatsappController = widget.whatsappExternalController ?? TextEditingController();
    cityController = widget.cityExternalController ?? TextEditingController();
    socialControllers = List.generate(9, (_) => TextEditingController());

    void onAnyChange() {
      _validateForm();
      _scheduleDraftSave();
      _updateSectionDoneFlag();
      _scheduleWhatsappPatch();
    }

    phoneController.addListener(onAnyChange);
    whatsappController.addListener(onAnyChange);
    cityController.addListener(onAnyChange);
    websiteController.addListener(onAnyChange);
    for (final c in socialControllers) {
      c.addListener(onAnyChange);
    }

    // تأجيل الاستدعاء الأول حتى بعد اكتمال البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDraft();
      _validateForm();
      _updateSectionDoneFlag();
      _prefillFromBackendIfNeeded();
    });
  }

  String get _draftKey => widget.isInitialRegistration ? _draftKeyInitial : _draftKeyFull;

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserScopedPrefs.readUserId();
      final raw = await UserScopedPrefs.getStringScoped(
        prefs,
        _draftKey,
        userId: userId,
      );
      if (raw == null || raw.trim().isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;

      String asString(dynamic v) => (v ?? '').toString();
      List asList(dynamic v) => v is List ? v : const [];

      String keepDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');
      String normalizeLocal05(String input) {
        final digits = keepDigits(input.trim());
        if (RegExp(r'^05\d{8}$').hasMatch(digits)) return digits;
        if (RegExp(r'^5\d{8}$').hasMatch(digits)) return '0$digits';
        if (RegExp(r'^9665\d{8}$').hasMatch(digits)) return '0${digits.substring(3)}';
        if (RegExp(r'^009665\d{8}$').hasMatch(digits)) return '0${digits.substring(5)}';
        return input;
      }

      // Only fill if empty to avoid overriding user input.
      if (phoneController.text.trim().isEmpty) {
        phoneController.text = normalizeLocal05(asString(data['phone']));
      }
      if (whatsappController.text.trim().isEmpty) {
        whatsappController.text = asString(data['whatsapp']);
      }
      if (cityController.text.trim().isEmpty) {
        cityController.text = asString(data['city']);
      }
      if (websiteController.text.trim().isEmpty) {
        websiteController.text = asString(data['website']);
      }

      final socials = asList(data['social']);
      for (var i = 0; i < socialControllers.length && i < socials.length; i++) {
        if (socialControllers[i].text.trim().isEmpty) {
          socialControllers[i].text = asString(socials[i]);
        }
      }
    } catch (_) {
      // Best-effort.
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        String keepDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');
        String normalizeLocal05(String input) {
          final digits = keepDigits(input.trim());
          if (RegExp(r'^05\d{8}$').hasMatch(digits)) return digits;
          if (RegExp(r'^5\d{8}$').hasMatch(digits)) return '0$digits';
          if (RegExp(r'^9665\d{8}$').hasMatch(digits)) return '0${digits.substring(3)}';
          if (RegExp(r'^009665\d{8}$').hasMatch(digits)) return '0${digits.substring(5)}';
          return input.trim();
        }

        final prefs = await SharedPreferences.getInstance();
        final userId = await UserScopedPrefs.readUserId();
        final data = <String, dynamic>{
          'phone': normalizeLocal05(phoneController.text),
          'whatsapp': whatsappController.text.trim(),
          'city': cityController.text.trim(),
          'website': websiteController.text.trim(),
          'social': socialControllers.map((c) => c.text.trim()).toList(growable: false),
        };
        await UserScopedPrefs.setStringScoped(
          prefs,
          _draftKey,
          jsonEncode(data),
          userId: userId,
        );
      } catch (_) {
        // ignore
      }
    });
  }

  void _updateSectionDoneFlag() {
    if (widget.isInitialRegistration) return;
    final done = whatsappController.text.trim().isNotEmpty;
    // Best-effort; no need to await.
    SharedPreferences.getInstance().then((prefs) async {
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.setBoolScoped(
        prefs,
        'provider_section_done_contact_full',
        done,
        userId: userId,
      );
    }).catchError((_) {});
  }

  void _scheduleWhatsappPatch() {
    if (widget.isInitialRegistration) return;
    final whatsapp = whatsappController.text.trim();
    if (_lastPatchedWhatsapp != null && whatsapp == _lastPatchedWhatsapp) return;

    _patchTimer?.cancel();
    _patchTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      final current = whatsappController.text.trim();
      if (_lastPatchedWhatsapp != null && current == _lastPatchedWhatsapp) return;

      final ok = await _saveToBackendIfNeeded();
      if (ok) {
        _lastPatchedWhatsapp = current;
      }
    });
  }

  Future<void> _prefillFromBackendIfNeeded() async {
    // In the provider registration wizard, controllers are passed from outside.
    // In that case, do not override user input.
    if (!mounted) return;
    if (!_ownsPhone && !_ownsWhatsapp) return;

    setState(() => _loadingFromBackend = true);
    try {
      String keepDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');
      String normalizeLocal05(String input) {
        final digits = keepDigits(input.trim());
        if (RegExp(r'^05\d{8}$').hasMatch(digits)) return digits;
        if (RegExp(r'^5\d{8}$').hasMatch(digits)) return '0$digits';
        if (RegExp(r'^9665\d{8}$').hasMatch(digits)) return '0${digits.substring(3)}';
        if (RegExp(r'^009665\d{8}$').hasMatch(digits)) return '0${digits.substring(5)}';
        return input.trim();
      }

      final me = await AccountApi().me();
      final phone = (me['phone'] ?? '').toString().trim();
      if (_ownsPhone && phoneController.text.trim().isEmpty && phone.isNotEmpty) {
        phoneController.text = normalizeLocal05(phone);
      }

      // WhatsApp is stored on the provider profile.
      final myProfile = await ProvidersApi().getMyProviderProfile();
      final whatsapp = (myProfile?['whatsapp'] ?? '').toString().trim();
      _initialWhatsapp = whatsapp;
      _lastPatchedWhatsapp = whatsapp;
      if (_ownsWhatsapp && whatsappController.text.trim().isEmpty && whatsapp.isNotEmpty) {
        whatsappController.text = whatsapp;
      }
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) {
        setState(() => _loadingFromBackend = false);
      } else {
        _loadingFromBackend = false;
      }
    }
  }

  Future<bool> _saveToBackendIfNeeded() async {
    if (widget.isInitialRegistration) return true;
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final whatsapp = whatsappController.text.trim();
      if (_initialWhatsapp == null) {
        // If we didn't prefill, still keep a baseline to avoid spamming PATCH.
        _initialWhatsapp = whatsapp;
        return true;
      }
      if (whatsapp == _initialWhatsapp) return true;

      final updated = await ProvidersApi().updateMyProviderProfile({
        'whatsapp': whatsapp,
      });
      if (updated == null) { 
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ رقم الواتساب حالياً.')),
        );
        return false;
      }
      _initialWhatsapp = (updated['whatsapp'] ?? '').toString().trim();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatDioError(e))),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      } else {
        _saving = false;
      }
    }
  }

  String _formatDioError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'انتهت الجلسة. فضلاً سجّل الدخول مرة أخرى.';
      }

      final data = error.response?.data;
      if (data is String) {
        final msg = data.trim();
        if (msg.isNotEmpty) return msg;
      }

      if (data is Map) {
        final map = data.map((k, v) => MapEntry(k.toString(), v));
        final detail = map['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }

        final parts = <String>[];
        for (final entry in map.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is List) {
            final msgs = value
                .map((e) => e?.toString().trim())
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .toList();
            if (msgs.isNotEmpty) parts.add('$key: ${msgs.join('، ')}');
          } else if (value is String && value.trim().isNotEmpty) {
            parts.add('$key: ${value.trim()}');
          }
        }
        if (parts.isNotEmpty) return parts.join('\n');
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'تعذر الاتصال بالخادم حالياً. حاول مرة أخرى.';
        case DioExceptionType.connectionError:
          return 'لا يوجد اتصال بالإنترنت حالياً.';
        default:
          break;
      }

      if (status != null) {
        return 'تعذر حفظ رقم الواتساب حالياً (HTTP $status).';
      }
    }

    return 'تعذر حفظ رقم الواتساب حالياً.';
  }

  void _validateForm() {
    // حساب النسبة بناءً على الحقول المملوءة
    double completionPercent = 0.0;

    // للتسجيل الأولي: نحتاج المدينة + رقم الهاتف كحد أدنى
    if (widget.isInitialRegistration) {
      if (phoneController.text.trim().isNotEmpty) {
        completionPercent += 0.5;
      }
      if (cityController.text.trim().isNotEmpty) {
        completionPercent += 0.5;
      }
    } else {
      // رقم الهاتف الأساسي (60% من الصفحة)
      if (phoneController.text.trim().isNotEmpty) {
        completionPercent += 0.6;
      }

      // واتساب (40% من الصفحة - اختياري)
      if (whatsappController.text.trim().isNotEmpty) {
        completionPercent += 0.4;
      }
    }
    
    widget.onValidationChanged?.call(completionPercent);
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (picked != null) {
        setState(() {
          _logoFile = File(picked.path);
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذر اختيار الشعار حاليًا.")),
      );
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _patchTimer?.cancel();
    websiteController.dispose();
    if (_ownsPhone) {
      phoneController.dispose();
    }
    if (_ownsWhatsapp) {
      whatsappController.dispose();
    }
    if (_ownsCity) {
      cityController.dispose();
    }
    for (final c in socialControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final isInitial = widget.isInitialRegistration;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4FC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildLogoHeader(),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child:
                        isInitial ? _buildInitialForm() : _buildFullAccordion(),
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildHeader() {
    final subtitle =
        widget.isInitialRegistration
            ? "أدخل بيانات التواصل الأساسية ليتمكن العملاء من الوصول إليك."
            : "حدّث بيانات تواصلك لتسهل على العملاء الوصول إليك عبر القنوات المناسبة لهم.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "معلومات التواصل",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
            fontFamily: "Cairo",
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: "Cairo",
            color: Colors.black54,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ---------------- LOGO HEADER ----------------

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Row(
          children: [
            // دائرة الشعار
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: _logoFile != null ? FileImage(_logoFile!) : null,
              child:
                  _logoFile == null
                      ? const Icon(Icons.person, size: 34, color: Colors.white)
                      : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "شعار حسابك",
                    style: TextStyle(
                      fontFamily: "Cairo",
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "يُعرض الشعار في ملفك التعريفي وفي نتائج البحث. اختر صورة واضحة تمثل نشاطك.",
                    style: TextStyle(
                      fontFamily: "Cairo",
                      fontSize: 11.5,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _pickLogo,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              "تعديل الشعار",
              style: TextStyle(fontFamily: "Cairo"),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              side: const BorderSide(color: Colors.deepPurple),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- INITIAL FORM (بسيط) ----------------

  Widget _buildInitialForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTip(
          icon: Icons.info_outline,
          text:
              "هذه البيانات أساسية لإنشاء حسابك، يمكنك إضافة مزيد من وسائل التواصل لاحقًا من خلال إكمال الملف التعريفي.",
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: "المدينة",
          icon: Icons.location_city,
          child: _styledField(
            controller: cityController,
            hint: "مثال: الرياض",
            icon: Icons.location_city,
            keyboardType: TextInputType.text,
          ),
        ),
        _sectionCard(
          title: "رقم الهاتف الأساسي",
          icon: Icons.phone_android,
          child: _styledField(
            controller: phoneController,
            hint: "05xxxxxxxx",
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            maxLength: 10,
            // أثناء التسجيل: اسمح للمستخدم بتعديل رقم الجوال دائماً.
            // الحفظ يتم عند الإرسال من صفحة التسجيل عبر AccountApi.updateMe.
            readOnly: false,
          ),
        ),
        _sectionCard(
          title: "واتساب (اختياري)",
          icon: FontAwesomeIcons.whatsapp,
          child: _styledField(
            controller: whatsappController,
            hint: "https://wa.me/رقمك",
            icon: FontAwesomeIcons.whatsapp,
            keyboardType: TextInputType.url,
          ),
        ),
      ],
    );
  }

  // ---------------- FULL ACCORDION FORM ----------------

  Widget _buildFullAccordion() {
    return Column(
      children: [
        if (_loadingFromBackend)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        _infoTip(
          icon: Icons.info_outline,
          text:
              "يمكنك التحكم في كل وسيلة تواصل بشكل مستقل من خلال الكروت أدناه. اضغط على أي كرت لعرض حقوله.",
        ),
        const SizedBox(height: 14),

        // موقع إلكتروني
        _accordionCard(
          id: "website",
          icon: Icons.language,
          title: "الموقع الإلكتروني",
          child: _styledField(
            controller: websiteController,
            hint: "https://example.com",
            icon: Icons.link,
            keyboardType: TextInputType.url,
          ),
        ),

        // وسائل التواصل
        _accordionCard(
          id: "social",
          icon: Icons.share_outlined,
          title: "وسائل التواصل الاجتماعي",
          child: Column(
            children: List.generate(
              socialControllers.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _styledField(
                  controller: socialControllers[i],
                  hint: "رابط ${socialLabels[i]}",
                  icon: socialIcons[i],
                  keyboardType: TextInputType.url,
                ),
              ),
            ),
          ),
        ),

        // واتساب
        _accordionCard(
          id: "whatsapp",
          icon: FontAwesomeIcons.whatsapp,
          title: "واتساب",
          child: _styledField(
            controller: whatsappController,
            hint: "https://wa.me/رقمك",
            icon: FontAwesomeIcons.whatsapp,
            keyboardType: TextInputType.url,
          ),
        ),

        // رقم الهاتف
        _accordionCard(
          id: "phone",
          icon: Icons.phone,
          title: "رقم الهاتف",
          child: _styledField(
            controller: phoneController,
            hint: "05xxxxxxxx",
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            readOnly: true,
          ),
        ),
      ],
    );
  }

  // ---------------- ACCORDION CARD ----------------

  Widget _accordionCard({
    required String id,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final isOpen = expanded[id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color:
              isOpen
                  ? Colors.deepPurple.withOpacity(0.4)
                  : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.withOpacity(0.1),
              child: Icon(icon, color: Colors.deepPurple),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(
              isOpen ? Icons.expand_less : Icons.expand_more,
              color: Colors.deepPurple,
            ),
            onTap: () {
              setState(() => expanded[id] = !isOpen);
            },
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }

  // ---------------- SIMPLE SECTION CARD (للنموذج البسيط) ----------------

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.deepPurple.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.deepPurple, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: "Cairo",
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ---------------- INFO TIP ----------------

  Widget _infoTip({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontSize: 11.5,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- INPUT FIELD ----------------

  Widget _styledField({
    required TextEditingController controller,
    IconData? icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontFamily: "Cairo", fontSize: 13.5),
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: Colors.deepPurple) : null,
        hintText: hint,
        counterText: '',
        hintStyle: const TextStyle(
          color: Colors.grey,
          fontFamily: "Cairo",
          fontSize: 13,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F5FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.deepPurple, width: 1.4),
        ),
      ),
    );
  }

  // ---------------- ACTION BUTTONS ----------------

  Widget _buildActionButtons() {
    final primaryLabel = widget.isFinalStep ? "إنهاء التسجيل" : "التالي";

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text("السابق", style: TextStyle(fontFamily: "Cairo")),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              side: const BorderSide(color: Colors.deepPurple),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final ok = await _saveToBackendIfNeeded();
                    if (!ok) return;
                    widget.onNext();
                  },
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              primaryLabel,
              style: const TextStyle(fontFamily: "Cairo"),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
