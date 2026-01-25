import 'package:flutter/material.dart';

class SeoStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const SeoStep({super.key, required this.onNext, required this.onBack});

  @override
  State<SeoStep> createState() => _SeoStepState();
}

class _SeoStepState extends State<SeoStep> {
  final TextEditingController keywordsController = TextEditingController();
  final TextEditingController metaDescriptionController =
      TextEditingController();
  final TextEditingController slugController = TextEditingController();

  @override
  void dispose() {
    keywordsController.dispose();
    metaDescriptionController.dispose();
    slugController.dispose();
    super.dispose();
  }

  void _submit() {
    // هنا لاحقًا تقدر تضيف حفظ للبيانات في الـ API / قاعدة البيانات
    // الآن المطلوب فقط يعتبر الخطوة مكتملة ويرجع للشاشة السابقة بعلامة صح
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📈 إعدادات تحسين محركات البحث (SEO)",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "تحسين ظهورك في نتائج البحث بكتابة كلمات مفتاحية ووصف دقيق.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: keywordsController,
                  decoration: InputDecoration(
                    labelText: "الكلمات المفتاحية",
                    hintText: "مثلاً: تصميم، تطبيقات، خدمات إلكترونية",
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: metaDescriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "وصف الصفحة (Meta Description)",
                    hintText: "وصف يظهر في نتائج محركات البحث",
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: slugController,
                  decoration: InputDecoration(
                    labelText: "الرابط المخصص",
                    hintText: "مثلاً: my-service-name",
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.deepPurple,
                      ),
                      label: const Text(
                        "السابق",
                        style: TextStyle(color: Colors.deepPurple),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        "تسجيل",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
