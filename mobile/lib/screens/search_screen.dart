import 'package:flutter/material.dart';
import '../constants/colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? _selectedCategory;
  String? _selectedSubCategory;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  final List<String> _categories = [
    "تطوير برمجي",
    "تصميم",
    "استشارات قانونية",
    "تسويق",
    "طب",
    "تعليم",
  ];

  final List<String> _subCategories = [
    "تطبيقات موبايل",
    "مواقع ويب",
    "واجهات وتجربة مستخدم",
    "قواعد بيانات",
  ];

  String _deliveryOption = "فوري";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "طلبات الخدمة التنافسية",
          style: TextStyle(fontFamily: "Cairo", fontSize: 18),
        ),
        backgroundColor: AppColors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ اختيار التصنيف الرئيسي
            const Text(
              "اختر التصنيف الرئيسي",
              style: TextStyle(
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items:
                  _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              decoration: _inputDecoration("اختر تصنيف"),
            ),

            const SizedBox(height: 16),

            // ✅ اختيار التصنيف الفرعي
            const Text(
              "اختر التصنيف الفرعي",
              style: TextStyle(
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSubCategory,
              items:
                  _subCategories
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
              onChanged: (v) => setState(() => _selectedSubCategory = v),
              decoration: _inputDecoration("اختر تصنيف فرعي"),
            ),

            const SizedBox(height: 16),

            // ✅ عنوان مختصر
            TextField(
              controller: _titleController,
              decoration: _inputDecoration("أدخل عنوان مختصر للطلب (50 حرف)"),
              maxLength: 50,
            ),

            const SizedBox(height: 8),

            // ✅ تفاصيل الطلب
            TextField(
              controller: _detailsController,
              decoration: _inputDecoration("اكتب تفاصيل الطلب (500 حرف)"),
              maxLength: 500,
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            // ✅ آخر موعد لاستلام العروض
            Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: _inputDecoration("آخر موعد لاستلام العروض"),
                    readOnly: true,
                    onTap: () {
                      // ✅ فتح DatePicker
                      showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 7),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ✅ خيارات الإرسال
            const Text(
              "طريقة إرسال الطلب",
              style: TextStyle(
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold,
              ),
            ),
            Column(
              children: [
                RadioListTile(
                  title: const Text(
                    "إرسال فوري للمشتركين في الباقة الاحترافية",
                  ),
                  value: "فوري",
                  groupValue: _deliveryOption,
                  onChanged: (v) => setState(() => _deliveryOption = v!),
                ),
                RadioListTile(
                  title: const Text("بعد 24 ساعة للمشتركين في الباقة الذهبية"),
                  value: "24",
                  groupValue: _deliveryOption,
                  onChanged: (v) => setState(() => _deliveryOption = v!),
                ),
                RadioListTile(
                  title: const Text("بعد 72 ساعة للمشتركين في الباقة المجانية"),
                  value: "72",
                  groupValue: _deliveryOption,
                  onChanged: (v) => setState(() => _deliveryOption = v!),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ✅ زر إرسال
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                label: const Text(
                  "إرسال الطلب",
                  style: TextStyle(fontFamily: "Cairo"),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم إرسال الطلب بنجاح ✅")),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // ✅ قائمة مقدمي الخدمات (نتائج البحث)
            const Text(
              "مقدمو الخدمات المقترحون",
              style: TextStyle(
                fontFamily: "Cairo",
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder:
                  (_, index) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.deepPurple,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        "مقدم خدمة ${index + 1}",
                        style: const TextStyle(fontFamily: "Cairo"),
                      ),
                      subtitle: const Text(
                        "⭐ 4.5 (120 مراجعة)",
                        style: TextStyle(fontFamily: "Cairo"),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {},
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.deepPurple),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.deepPurple),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.deepPurple, width: 2),
      ),
    );
  }
}
