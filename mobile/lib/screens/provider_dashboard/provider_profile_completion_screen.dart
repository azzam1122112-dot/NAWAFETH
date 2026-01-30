import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/colors.dart';

import '../../services/account_api.dart';
import '../../services/session_storage.dart';

// ⬇️ استيراد القوالب الموجودة
import '../registration/steps/service_details_step.dart';
import '../registration/steps/additional_details_step.dart';
import '../registration/steps/contact_info_step.dart';
import '../registration/steps/language_location_step.dart';
import '../registration/steps/content_step.dart';
import '../registration/steps/seo_step.dart';

class ProviderProfileCompletionScreen extends StatefulWidget {
  const ProviderProfileCompletionScreen({super.key});

  @override
  State<ProviderProfileCompletionScreen> createState() =>
      _ProviderProfileCompletionScreenState();
}

class _ProviderProfileCompletionScreenState
    extends State<ProviderProfileCompletionScreen> {
  // ✅ الحد الأعلى للجزء الأساسي (بيانات التسجيل الأساسية)
  static const double _baseCompletionMax = 0.30; // 30%
  static const int _optionalTotalPercent = 70; // 70%

  bool _loading = true;
  Map<String, dynamic>? _me;

  String? _fullName;
  String? _username;
  String? _phone;
  String? _email;

  // الأقسام الاختيارية (6 أقسام = 70%)
  final Map<String, bool> _sections = {
    "service_details": false,
    "additional": false,
    "contact_full": false,
    "lang_loc": false,
    "content": false,
    "seo": false,
  };

  // ✅ أوزان صحيحة (integers) مجموعها 70% تماماً (بدون تجاوز 100% بسبب التقريب)
  late final Map<String, int> _sectionWeights;

  double get _baseCompletion {
    // يعكس فعلياً ما هو موجود في الباكند (بدون بيانات وهمية).
    final me = _me;
    if (me == null) return 0.0;

    bool hasName() {
      final first = (me['first_name'] ?? '').toString().trim();
      final last = (me['last_name'] ?? '').toString().trim();
      final user = (me['username'] ?? '').toString().trim();
      return first.isNotEmpty || last.isNotEmpty || user.isNotEmpty;
    }

    bool hasPhone() => (me['phone'] ?? '').toString().trim().isNotEmpty;
    bool hasEmail() => (me['email'] ?? '').toString().trim().isNotEmpty;

    final parts = <bool>[hasName(), hasPhone(), hasEmail()];
    final done = parts.where((v) => v).length;
    final ratio = done / parts.length;
    return (_baseCompletionMax * ratio).clamp(0.0, _baseCompletionMax);
  }

  double get _completionPercent {
    final completedOptional = _sections.entries
        .where((e) => e.value)
        .fold<int>(0, (sum, e) => sum + (_sectionWeights[e.key] ?? 0));

    final dynamicPart = completedOptional / 100.0;
    return (_baseCompletion + dynamicPart).clamp(0.0, 1.0);
  }

  int _sectionPercent(String id) => _sectionWeights[id] ?? 0;

  // فتح شاشة القسم ثم تحديده كمكتمل إذا رجع بقيمة true
  Future<void> _openSection(String id) async {
    bool? result;

    switch (id) {
      case "basic":
        // عرض البيانات الأساسية (عرض فقط)
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => _BasicInfoScreen(
                  fullName: _fullName,
                  username: _username,
                  phone: _phone,
                  email: _email,
                ),
          ),
        );
        // قسم الأساسيات محسوب من الباكند
        return;

      case "service_details":
        // هذه خطوة بدون Scaffold، نغلفها بواجهة بسيطة
        result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => _SingleStepWrapper(
                  title: "تفاصيل الخدمة",
                  child: ServiceDetailsStep(
                    onBack: () => Navigator.pop(context, false),
                    onNext: () => Navigator.pop(context, true),
                  ),
                ),
          ),
        );
        break;

      case "additional":
        result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => _SingleStepWrapper(
                  title: "معلومات إضافية عنك وخدماتك",
                  child: AdditionalDetailsStep(
                    onBack: () => Navigator.pop(context, false),
                    onNext: () => Navigator.pop(context, true),
                  ),
                ),
          ),
        );
        break;

      case "contact_full":
        // ContactInfoStep عنده Scaffold جاهز
        result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => ContactInfoStep(
                  isInitialRegistration: false,
                  isFinalStep: false,
                  onBack: () => Navigator.pop(context, false),
                  onNext: () => Navigator.pop(context, true),
                ),
          ),
        );
        break;

      case "lang_loc":
        // نفس القالب المستخدم في التسجيل ولكن كخطوة مستقلة
        result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => LanguageLocationStep(
                  onBack: () => Navigator.pop(context, false),
                  onNext: () => Navigator.pop(context, true),
                ),
          ),
        );
        break;

      case "content":
        result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => ContentStep(
                  onBack: () => Navigator.pop(context, false),
                  onNext: () => Navigator.pop(context, true),
                ),
          ),
        );
        break;

      case "seo":
        result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => SeoStep(
                  onBack: () => Navigator.pop(context, false),
                  onNext: () => Navigator.pop(context, true),
                ),
          ),
        );
        break;

      default:
        result = false;
    }

    // ✅ لا نضع علامة صح إلا إذا رجعت الشاشة بـ true
    if (result == true && id != "basic") {
      setState(() {
        _sections[id] = true;
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('provider_section_done_$id', true);
      } catch (_) {
        // ignore
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _sectionWeights = _buildSectionWeights();
    _bootstrap();
  }

  Map<String, int> _buildSectionWeights() {
    // توزيع 70% على 6 أقسام بدون كسور:
    // 70 / 6 = 11 والباقي 4 → 4 أقسام = 12% و قسمين = 11% (المجموع 70%)
    final keys = _sections.keys.toList(growable: false);
    final base = _optionalTotalPercent ~/ keys.length; // 11
    var remainder = _optionalTotalPercent - (base * keys.length); // 4

    final weights = <String, int>{};
    for (final k in keys) {
      final extra = remainder > 0 ? 1 : 0;
      if (remainder > 0) remainder -= 1;
      weights[k] = base + extra;
    }
    return weights;
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final id in _sections.keys) {
        _sections[id] = prefs.getBool('provider_section_done_$id') ?? false;
      }

      final loggedIn = await const SessionStorage().isLoggedIn();
      if (!loggedIn) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        return;
      }

      final me = await AccountApi().me();

      String? nonEmpty(dynamic v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }

      final first = nonEmpty(me['first_name']);
      final last = nonEmpty(me['last_name']);
      final username = nonEmpty(me['username']);
      final email = nonEmpty(me['email']);
      final phone = nonEmpty(me['phone']);

      final fullNameParts = [
        if (first != null) first,
        if (last != null) last,
      ];
      final fullName = fullNameParts.isEmpty ? null : fullNameParts.join(' ');

      if (!mounted) return;
      setState(() {
        _me = me;
        _fullName = fullName;
        _username = username;
        _email = email;
        _phone = phone;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_completionPercent * 100).clamp(0.0, 100.0).round();

    if (_loading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Color(0xFFF3F4FC),
          body: Center(
            child: CircularProgressIndicator(color: AppColors.deepPurple),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4FC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text(
            "إكمال الملف التعريفي",
            style: TextStyle(
              fontFamily: "Cairo",
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 🔹 كرت النسبة العامة
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "نسبة اكتمال الملف",
                        style: TextStyle(
                          fontFamily: "Cairo",
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: LinearProgressIndicator(
                          value: _completionPercent,
                          minHeight: 7,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.deepPurple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            "$percent%",
                            style: const TextStyle(
                              fontFamily: "Cairo",
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              "حوالي 30٪ من التسجيل الأساسي، والباقي من إكمال الأقسام أدناه.",
                              style: TextStyle(
                                fontFamily: "Cairo",
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  children: [
                    // ✅ كرت الأساسيات (مكتمل)
                    _basicSectionTile(),
                    const SizedBox(height: 4),

                    // ✅ باقي الأقسام
                    _sectionTile(
                      id: "service_details",
                      title: "تفاصيل الخدمة",
                      subtitle: "اسم الخدمة ووصف مختصر.",
                        extra:
                          "يمثل ${_sectionPercent('service_details')}٪ من اكتمال الملف.",
                      icon: Icons.home_repair_service_outlined,
                      color: Colors.indigo,
                    ),
                    _sectionTile(
                      id: "additional",
                      title: "معلومات إضافية عنك وخدماتك",
                      subtitle: "تفاصيل موسّعة عن خدماتك ومؤهلاتك وخبراتك.",
                        extra:
                          "يمثل ${_sectionPercent('additional')}٪ من اكتمال الملف.",
                      icon: Icons.notes_outlined,
                      color: Colors.teal,
                    ),
                    _sectionTile(
                      id: "contact_full", // 💡 نستخدم نفس المفتاح الموجود في الماب
                      title: "معلومات التواصل الكاملة",
                      subtitle:
                          "روابط التواصل الاجتماعي، واتساب، موقع إلكتروني، رابط موقعك.",
                        extra:
                          "يمثل ${_sectionPercent('contact_full')}٪ من اكتمال الملف.",
                      icon: Icons.call_outlined,
                      color: Colors.blue,
                    ),
                    _sectionTile(
                      id: "lang_loc",
                      title: "اللغة ونطاق الخدمة",
                      subtitle: "اللغات التي تجيدها ونطاق تقديم خدماتك.",
                        extra:
                          "يمثل ${_sectionPercent('lang_loc')}٪ من اكتمال الملف.",
                      icon: Icons.language_outlined,
                      color: Colors.orange,
                    ),
                    _sectionTile(
                      id: "content",
                      title: "محتوى أعمالك (Portfolio)",
                      subtitle: "أضف صوراً أو نماذج من أعمالك السابقة.",
                        extra:
                          "يمثل ${_sectionPercent('content')}٪ من اكتمال الملف.",
                      icon: Icons.image_outlined,
                      color: Colors.purple,
                    ),
                    _sectionTile(
                      id: "seo",
                      title: "SEO والكلمات المفتاحية",
                      subtitle: "تعريف محركات البحث بنوعية خدمتك.",
                      extra:
                          "يمثل ${_sectionPercent('seo')}٪ من اكتمال الملف.",
                      icon: Icons.search,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔷 كرت الأساسيات (محسوب من بيانات الحساب)
  Widget _basicSectionTile() {
    final basePercent = (_baseCompletion * 100).round();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.deepPurple.withValues(alpha: 0.4),
          width: 1.4,
        ),
      ),
      child: ListTile(
        onTap: () => _openSection("basic"),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white,
          child: Icon(
            Icons.person_pin_circle_outlined,
            color: AppColors.deepPurple,
          ),
        ),
        title: const Text(
          "بيانات التسجيل الأساسية",
          style: TextStyle(
            fontFamily: "Cairo",
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          "المعلومات الأساسية + تصنيف الاختصاص + بيانات التواصل الأساسية.\nتمت تعبئتها أثناء التسجيل.",
          style: TextStyle(
            fontFamily: "Cairo",
            fontSize: 11.5,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        trailing: Text(
          "$basePercent%",
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            color: Colors.green,
          ),
        ),
      ),
    );
  }

  // 🔷 كروت باقي الأقسام
  Widget _sectionTile({
    required String id,
    required String title,
    required String subtitle,
    required String extra,
    required IconData icon,
    required Color color,
  }) {
    final done = _sections[id] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
                        color: Colors.black12.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: done ? color.withValues(alpha: 0.4) : Colors.grey.shade200,
          width: done ? 1.4 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _openSection(id),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.08),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: "Cairo",
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontSize: 11.5,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              extra,
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 10.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing:
            done
                ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
                : const Icon(Icons.chevron_left, color: Colors.black45),
      ),
    );
  }
}

/// 🔹 شاشة لمعاينة البيانات الأساسية (من الباكند)
class _BasicInfoScreen extends StatelessWidget {
  final String? fullName;
  final String? username;
  final String? phone;
  final String? email;

  const _BasicInfoScreen({
    required this.fullName,
    required this.username,
    required this.phone,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "بيانات التسجيل الأساسية",
          style: TextStyle(fontFamily: "Cairo"),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "هذه البيانات تُجلب من حسابك في النظام.",
              style: TextStyle(fontFamily: "Cairo", color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("الاسم", style: TextStyle(fontFamily: 'Cairo')),
              subtitle: Text(
                fullName ?? '—',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text(
                "اسم المستخدم",
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              subtitle: Text(
                username == null ? '—' : '@$username',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text(
                "رقم الجوال",
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              subtitle: Text(
                phone ?? '—',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text(
                "البريد الإلكتروني",
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              subtitle: Text(
                email ?? '—',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 شاشة تغلّف بعض القوالب التي ليست Scaffold
class _SingleStepWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const _SingleStepWrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontFamily: "Cairo")),
      ),
      body: child,
    );
  }
}
