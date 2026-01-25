import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import '../constants/colors.dart';
import 'my_profile_screen.dart';

class RequestQuoteScreen extends StatefulWidget {
  const RequestQuoteScreen({super.key});

  @override
  State<RequestQuoteScreen> createState() => _RequestQuoteScreenState();
}

class _RequestQuoteScreenState extends State<RequestQuoteScreen> {
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

  String? selectedMainCategory;
  String? selectedSubCategory;
  DateTime? selectedDate;

  final List<String> mainCategories = [
    "اتصالات وشبكات",
    "تصميم وصناعة المحتوى",
    "التسويق",
    "التطوير البرمجي",
    "الاستشارات الهندسية",
    "الاستشارات القانونية",
    "الاستشارات الصحية",
    "الاستشارات المالية",
  ];

  final List<String> subCategories = [
    "تطوير تطبيقات",
    "تصميم واجهات",
    "AutoCAD",
    "Primavera",
    "قواعد البيانات",
    "Power BI",
  ];

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 60,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "تم إرسال طلبك بنجاح!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "ستتلقى العروض قريبًا في قسم\nنافذتي > طلباتي > طلبات العروض",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("اذهب إلى نافذتي"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
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
    return Scaffold(
      appBar: const CustomAppBar(title: "طلب عروض أسعار"),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("التصنيف الرئيسي:"),
            _buildDropdown(
              value: selectedMainCategory,
              hint: "اختر تصنيف الخدمة",
              items: mainCategories,
              onChanged: (val) => setState(() => selectedMainCategory = val),
            ),
            const SizedBox(height: 20),

            _buildLabel("المجال الفرعي:"),
            _buildDropdown(
              value: selectedSubCategory,
              hint: "اختر المجال الفرعي",
              items: subCategories,
              onChanged: (val) => setState(() => selectedSubCategory = val),
            ),
            const SizedBox(height: 20),

            _buildLabel("عنوان الطلب:"),
            TextField(
              controller: _titleController,
              maxLength: 50,
              decoration: _inputDecoration("أدخل عنوان الطلب"),
            ),
            const SizedBox(height: 16),

            _buildLabel("تفاصيل الطلب:"),
            TextField(
              controller: _detailsController,
              maxLength: 500,
              maxLines: 4,
              decoration: _inputDecoration("أدخل تفاصيل أكثر عن طلبك"),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.attach_file),
              label: const Text("إرفاق ملف"),
              style: _buttonStyle(),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.mic),
              label: const Text("تسجيل رسالة صوتية"),
              style: _buttonStyle(),
            ),
            const SizedBox(height: 24),

            _buildLabel("آخر موعد لاستلام العروض:"),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 2)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  locale: const Locale('ar', 'SA'),
                );
                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),
                    Text(
                      selectedDate != null
                          ? DateFormat.yMMMMd('ar_SA').format(selectedDate!)
                          : "اختر التاريخ",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("إلغاء"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showSuccessDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("تقديم"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _dropdownDecoration(hint),
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(Icons.arrow_drop_down),
      menuMaxHeight: 250,
      dropdownColor: Colors.white,
      style: const TextStyle(fontSize: 15, color: Colors.black),
      isExpanded: true,
      alignment: Alignment.centerRight,
      items:
          items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.deepPurple, width: 1.5),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
