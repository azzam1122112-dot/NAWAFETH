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

  Future<void> _reloadSectionFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        for (final id in _sections.keys) {
          _sections[id] = prefs.getBool('provider_section_done_$id') ?? false;
        }
      });
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _bootstrap();
    await _reloadSectionFlags();
  }

  String? _nextRecommendedSectionId() {
    // ترتيب واضح: الأهم أولاً ثم التحسينات الاختيارية.
    const important = <String>["service_details", "contact_full", "lang_loc"];
    const optional = <String>["additional", "content", "seo"];

    for (final id in important) {
      if ((_sections[id] ?? false) == false) return id;
    }
    for (final id in optional) {
      if ((_sections[id] ?? false) == false) return id;
    }
    return null;
  }

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
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('provider_section_done_$id', true);
      } catch (_) {
        // ignore
      }
    }

    // ✅ حدث الحالة دائماً بعد العودة (لأن الخطوات قد تحفظ تلقائياً وتحدث مفاتيح الإكمال)
    await _reloadSectionFlags();
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
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            "إكمال الملف التعريفي",
            style: TextStyle(
              fontFamily: "Cairo",
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeroHeader(percent: percent),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _basicSectionTile(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: _buildSectionTitle(
                    title: 'خطوات مهمة',
                    subtitle: 'اختصرها عليك: هذه أهم 3 خطوات لظهور ملفك بشكل قوي.',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _luxSectionTile(
                        id: "service_details",
                        title: "تفاصيل الخدمة",
                        subtitle: "أضف خدمة واحدة على الأقل باسم واضح.",
                        icon: Icons.home_repair_service_outlined,
                        color: Colors.indigo,
                        isOptional: false,
                      ),
                      _luxSectionTile(
                        id: "contact_full",
                        title: "معلومات التواصل",
                        subtitle: "واتساب/هاتف وروابط التواصل (اختياري جزئياً).",
                        icon: Icons.call_outlined,
                        color: Colors.blue,
                        isOptional: false,
                      ),
                      _luxSectionTile(
                        id: "lang_loc",
                        title: "اللغة والموقع",
                        subtitle: "حدد لغاتك وموقعك لتصل لعملائك أسرع.",
                        icon: Icons.language_outlined,
                        color: Colors.orange,
                        isOptional: false,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _buildOptionalPanel(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(percent: percent),
      ),
    );
  }

  Widget _buildHeroHeader({required int percent}) {
    final nextId = _nextRecommendedSectionId();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 78, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF3F2B96), Color(0xFF6A4CFF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملفك — بشكل احترافي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'املأ المهم أولاً… والباقي اختياري لتحسين ظهورك وثقة العملاء.',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _glassChip(text: 'سهولة تعبئة', icon: Icons.touch_app_outlined),
                        _glassChip(text: 'حفظ تلقائي داخل الأقسام', icon: Icons.auto_awesome),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildProgressRing(percent: percent),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      nextId == null ? null : () => _openSection(nextId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF3F2B96),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  label: Text(
                    nextId == null ? 'ملفك مكتمل' : 'متابعة الخطوة التالية',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _refresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'تحديث',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing({required int percent}) {
    final v = (percent / 100).clamp(0.0, 1.0);
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: v),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _glassChip({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: Colors.grey.shade600,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          collapsedIconColor: Colors.black45,
          iconColor: Colors.black54,
          title: const Text(
            'تحسينات اختيارية (تزيد ثقة العملاء)',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'هذه الأقسام ليست إلزامية، لكنها تعطي ملفك شكلاً أفخم وظهوراً أفضل.',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: Colors.grey.shade600,
              height: 1.25,
            ),
          ),
          children: [
            _luxSectionTile(
              id: 'additional',
              title: 'معلومات إضافية',
              subtitle: 'خبراتك، مؤهلاتك، ونبذة أعمق.',
              icon: Icons.notes_outlined,
              color: Colors.teal,
              isOptional: true,
            ),
            _luxSectionTile(
              id: 'content',
              title: 'معرض الأعمال (Portfolio)',
              subtitle: 'صور ونماذج أعمالك السابقة.',
              icon: Icons.image_outlined,
              color: Colors.purple,
              isOptional: true,
            ),
            _luxSectionTile(
              id: 'seo',
              title: 'SEO والكلمات المفتاحية',
              subtitle: 'كلمات تساعد العملاء في الوصول لك.',
              icon: Icons.search,
              color: Colors.blueGrey,
              isOptional: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _luxSectionTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isOptional,
  }) {
    final done = _sections[id] ?? false;
    final weight = _sectionPercent(id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done ? color.withValues(alpha: 0.45) : Colors.grey.shade200,
          width: done ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _openSection(id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 13.8,
                ),
              ),
            ),
            if (isOptional)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'اختياري',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  color: Colors.grey.shade700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (done)
                    const Icon(Icons.check_circle, color: Colors.green, size: 18)
                  else
                    Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      done ? 'مكتمل' : 'غير مكتمل',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                        color: done ? Colors.green : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Text(
                    '$weight%+',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      color: color,
                      fontSize: 11.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_left, color: Colors.black45),
      ),
    );
  }

  Widget _buildBottomBar({required int percent}) {
    final nextId = _nextRecommendedSectionId();
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: nextId == null ? null : () => _openSection(nextId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  nextId == null ? 'مكتمل ($percent%)' : 'متابعة',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'لاحقاً',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
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
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
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
        subtitle: Text(
          "تمت تعبئتها أثناء التسجيل. اضغط للمعاينة.",
          style: TextStyle(
            fontFamily: "Cairo",
            fontSize: 11.5,
            color: Colors.grey.shade700,
            height: 1.25,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$basePercent%",
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_left, color: Colors.black45),
          ],
        ),
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
