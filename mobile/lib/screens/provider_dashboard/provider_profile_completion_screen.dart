import 'package:flutter/material.dart';
import '../../constants/colors.dart';

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
  // ✅ النسبة الأساسية القادمة من التسجيل الأولي (3 خطوات تسجيل)
  static const double _baseCompletion = 0.30; // 30%

  // الأقسام الاختيارية (6 أقسام = 70%)
  final Map<String, bool> _sections = {
    "service_details": false,
    "additional": false,
    "contact_full": false,
    "lang_loc": false,
    "content": false,
    "seo": false,
  };

  double get _perSectionWeight => 0.70 / _sections.length;

  double get _completionPercent {
    final done = _sections.values.where((v) => v).length;
    final dynamicPart = done * _perSectionWeight;
    return (_baseCompletion + dynamicPart).clamp(0.0, 1.0);
  }

  int _sectionPercent() {
    // كل قسم من الاختياري يمثل نفس النسبة تقريباً
    return (_perSectionWeight * 100).round();
  }

  // فتح شاشة القسم ثم تحديده كمكتمل إذا رجع بقيمة true
  Future<void> _openSection(String id) async {
    bool? result;

    switch (id) {
      case "basic":
        // عرض البيانات الأساسية (عرض فقط أو تعديل بسيط)
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const _BasicInfoPlaceholderScreen(),
          ),
        );
        // قسم الأساسيات دائماً مكتمل (30%) – لا نغير حالة
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_completionPercent * 100).round();
    final sectionPercent = _sectionPercent();

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
                        color: Colors.black12.withOpacity(0.05),
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
                      extra: "يمثل حوالي $sectionPercent٪ من اكتمال الملف.",
                      icon: Icons.home_repair_service_outlined,
                      color: Colors.indigo,
                    ),
                    _sectionTile(
                      id: "additional",
                      title: "معلومات إضافية عنك وخدماتك",
                      subtitle: "تفاصيل موسّعة عن خدماتك ومؤهلاتك وخبراتك.",
                      extra: "يمثل حوالي $sectionPercent٪ من اكتمال الملف.",
                      icon: Icons.notes_outlined,
                      color: Colors.teal,
                    ),
                    _sectionTile(
                      id: "contact_full", // 💡 نستخدم نفس المفتاح الموجود في الماب
                      title: "معلومات التواصل الكاملة",
                      subtitle:
                          "روابط التواصل الاجتماعي، واتساب، موقع إلكتروني، رابط موقعك.",
                      extra: "يمثل حوالي $sectionPercent٪ من اكتمال الملف.",
                      icon: Icons.call_outlined,
                      color: Colors.blue,
                    ),
                    _sectionTile(
                      id: "lang_loc",
                      title: "اللغة ونطاق الخدمة",
                      subtitle: "اللغات التي تجيدها ونطاق تقديم خدماتك.",
                      extra: "يمثل حوالي $sectionPercent٪ من اكتمال الملف.",
                      icon: Icons.language_outlined,
                      color: Colors.orange,
                    ),
                    _sectionTile(
                      id: "content",
                      title: "محتوى أعمالك (Portfolio)",
                      subtitle: "أضف صوراً أو نماذج من أعمالك السابقة.",
                      extra: "يمثل حوالي $sectionPercent٪ من اكتمال الملف.",
                      icon: Icons.image_outlined,
                      color: Colors.purple,
                    ),
                    _sectionTile(
                      id: "seo",
                      title: "SEO والكلمات المفتاحية",
                      subtitle: "تعريف محركات البحث بنوعية خدمتك.",
                      extra: "يمثل حوالي $sectionPercent٪ من اكتمال الملف.",
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

  // 🔷 كرت الأساسيات (دايمًا مكتمل – 30%)
  Widget _basicSectionTile() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.deepPurple.withOpacity(0.4),
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
        trailing: const Icon(Icons.check_circle, color: Colors.green, size: 22),
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
            color: Colors.black12.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: done ? color.withOpacity(0.4) : Colors.grey.shade200,
          width: done ? 1.4 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _openSection(id),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.08),
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

/// 🔹 شاشة بسيطة لمعاينة/تعديل البيانات الأساسية (محاكاة)
class _BasicInfoPlaceholderScreen extends StatelessWidget {
  const _BasicInfoPlaceholderScreen();

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
          children: const [
            Text(
              "هذه البيانات تم إدخالها أثناء التسجيل الأولي.",
              style: TextStyle(fontFamily: "Cairo", color: Colors.black54),
            ),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("الاسم / اسم الحساب"),
              subtitle: Text("سيتم جلبه من قاعدة البيانات لاحقاً."),
            ),
            ListTile(
              leading: Icon(Icons.category_outlined),
              title: Text("تصنيف الاختصاص"),
              subtitle: Text("يُعرض هنا التصنيف الرئيسي والتخصصات."),
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text("بيانات التواصل الأساسية"),
              subtitle: Text("رقم الجوال / واتساب الأساسي."),
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
