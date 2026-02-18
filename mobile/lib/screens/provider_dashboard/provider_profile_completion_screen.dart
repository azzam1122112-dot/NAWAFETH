import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/colors.dart';
import '../../utils/user_scoped_prefs.dart';

import '../../services/account_api.dart';
import '../../services/providers_api.dart';
import '../../services/session_storage.dart';

// ⬇️ استيراد القوالب الموجودة
import '../registration/steps/additional_details_step.dart';
import '../registration/steps/contact_info_step.dart';
import '../registration/steps/language_location_step.dart';
import '../registration/steps/seo_step.dart';

import 'provider_completion_utils.dart';
import 'provider_service_categories_screen.dart';
import 'provider_portfolio_manage_screen.dart';

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
    return ProviderCompletionUtils.baseCompletionFromMe(
      _me,
      baseMax: _baseCompletionMax,
    );
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
      final userId = await UserScopedPrefs.readUserId();
      final updated = <String, bool>{};
      for (final id in _sections.keys) {
        final baseKey = 'provider_section_done_$id';
        updated[id] = (await UserScopedPrefs.getBoolScoped(
              prefs,
              baseKey,
              userId: userId,
            )) ??
            false;
      }
      if (!mounted) return;
      setState(() {
        _sections.addAll(updated);
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
        // تعديل البيانات الأساسية (حفظ تلقائي)
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (_) => const _BasicInfoScreen(),
          ),
        );
        // قسم الأساسيات محسوب من الباكند
        await _bootstrap();
        return;

      case "service_details":
        result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const ProviderServiceCategoriesScreen(),
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
            builder: (_) => const ProviderPortfolioManageScreen(),
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
        final userId = await UserScopedPrefs.readUserId();
        await UserScopedPrefs.setBoolScoped(
          prefs,
          'provider_section_done_$id',
          true,
          userId: userId,
        );
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
    _sectionWeights = ProviderCompletionUtils.buildSectionWeights(
      keys: _sections.keys.toList(growable: false),
      total: _optionalTotalPercent,
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserScopedPrefs.readUserId();
      for (final id in _sections.keys) {
        final baseKey = 'provider_section_done_$id';
        _sections[id] = (await UserScopedPrefs.getBoolScoped(
              prefs,
              baseKey,
              userId: userId,
            )) ??
            false;
      }

      final loggedIn = await const SessionStorage().isLoggedIn();
      if (!loggedIn) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        return;
      }

      // Prefill from local secure storage so the UI shows something even offline.
      try {
        const storage = SessionStorage();
        final localFull = (await storage.readFullName())?.trim();
        final localUser = (await storage.readUsername())?.trim();
        final localEmail = (await storage.readEmail())?.trim();
        final localPhone = (await storage.readPhone())?.trim();
        if (mounted) {
          setState(() {
            _fullName = (localFull == null || localFull.isEmpty) ? _fullName : localFull;
            _username = (localUser == null || localUser.isEmpty) ? _username : localUser;
            _email = (localEmail == null || localEmail.isEmpty) ? _email : localEmail;
            _phone = (localPhone == null || localPhone.isEmpty) ? _phone : localPhone;
          });
        }
      } catch (_) {
        // ignore
      }

      final me = await AccountApi().me();
      Map<String, dynamic>? providerProfile;
      try {
        providerProfile = await ProvidersApi().getMyProviderProfile();
      } catch (_) {
        providerProfile = null;
      }
      List<int> subcategories = <int>[];
      try {
        subcategories = await ProvidersApi().getMyProviderSubcategories();
      } catch (_) {
        subcategories = <int>[];
      }

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

      // Persist identity for other screens (profile / provider registration completion).
      try {
        await const SessionStorage().saveProfile(
          username: username,
          email: email,
          firstName: first,
          lastName: last,
          phone: phone,
        );
      } catch (_) {
        // ignore
      }

      if (!mounted) return;
      setState(() {
        _me = me;
        _fullName = fullName;
        _username = username;
        _email = email;
        _phone = phone;
        if (providerProfile != null) {
          bool hasAnyList(dynamic v) => v is List && v.any((e) => (e ?? '').toString().trim().isNotEmpty);
          bool hasAnyString(dynamic v) => (v ?? '').toString().trim().isNotEmpty;

          _sections['service_details'] =
              (_sections['service_details'] ?? false) || subcategories.isNotEmpty;
          _sections['contact_full'] =
              (_sections['contact_full'] ?? false) ||
              hasAnyString(providerProfile['whatsapp']) ||
              hasAnyString(providerProfile['website']) ||
              hasAnyList(providerProfile['social_links']);
          _sections['lang_loc'] =
              (_sections['lang_loc'] ?? false) ||
              hasAnyList(providerProfile['languages']) ||
              (providerProfile['lat'] != null && providerProfile['lng'] != null);
          _sections['additional'] =
              (_sections['additional'] ?? false) ||
              hasAnyString(providerProfile['about_details']) ||
              hasAnyList(providerProfile['qualifications']) ||
              hasAnyList(providerProfile['experiences']);
          _sections['content'] =
              (_sections['content'] ?? false) ||
              hasAnyList(providerProfile['content_sections']);
          _sections['seo'] =
              (_sections['seo'] ?? false) ||
              hasAnyString(providerProfile['seo_keywords']) ||
              hasAnyString(providerProfile['seo_meta_description']) ||
              hasAnyString(providerProfile['seo_slug']);
        }
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
          colors: [Color(0xFF0F4C81), Color(0xFF4D7CFE)],
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
                    foregroundColor: const Color(0xFF0F4C81),
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
              title: 'معرض الخدمات',
              subtitle: 'صور وفيديوهات لأعمالك السابقة.',
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
                  backgroundColor: const Color(0xFF0F4C81),
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

/// 🔹 شاشة تعديل البيانات الأساسية (من الباكند) مع حفظ تلقائي
class _BasicInfoScreen extends StatefulWidget {
  const _BasicInfoScreen();

  @override
  State<_BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<_BasicInfoScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _username;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    for (final c in [_firstName, _lastName, _phone, _email]) {
      c.addListener(_onAnyChange);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_firstName, _lastName, _phone, _email]) {
      c.removeListener(_onAnyChange);
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await AccountApi().me();

      String s(dynamic v) => (v ?? '').toString();

      _firstName.text = s(me['first_name']).trim();
      _lastName.text = s(me['last_name']).trim();
      _phone.text = s(me['phone']).trim();
      _email.text = s(me['email']).trim();
      _username = s(me['username']).trim().isEmpty ? null : s(me['username']).trim();

      // Also persist to secure storage for other screens.
      await const SessionStorage().saveProfile(
        username: _username,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        firstName: _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
        lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات الحساب.';
      });
    }
  }

  void _onAnyChange() {
    if (_loading) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), () async {
      await _save();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });

    try {
      final patch = <String, dynamic>{
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'phone': _phone.text.trim(),
      };
      // Email is optional to update; if backend rejects, we'll show an error.
      if (_email.text.trim().isNotEmpty) {
        patch['email'] = _email.text.trim();
      }

      final res = await AccountApi().updateMe(patch);
      await const SessionStorage().saveProfile(
        username: (res['username'] ?? _username)?.toString(),
        email: (res['email'] ?? '').toString(),
        firstName: (res['first_name'] ?? '').toString(),
        lastName: (res['last_name'] ?? '').toString(),
        phone: (res['phone'] ?? '').toString(),
      );

      if (!mounted) return;
      setState(() {
        _username = (res['username'] ?? _username)?.toString().trim();
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ البيانات حالياً.')),
      );
    }
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Cairo'),
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('بيانات التسجيل الأساسية', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.deepPurple,
          foregroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle, color: Colors.white),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(fontFamily: 'Cairo')),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.deepPurple),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'يتم حفظ التغييرات تلقائياً.',
                                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_username != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.alternate_email, color: Colors.black54),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '@$_username',
                                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_username != null) const SizedBox(height: 14),
                      TextField(
                        controller: _firstName,
                        decoration: _dec('الاسم الأول', Icons.person_outline),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lastName,
                        decoration: _dec('اسم العائلة', Icons.badge_outlined),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: _dec('رقم الجوال', Icons.phone_outlined),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec('البريد الإلكتروني', Icons.email_outlined),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : () async {
                          await _save();
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
