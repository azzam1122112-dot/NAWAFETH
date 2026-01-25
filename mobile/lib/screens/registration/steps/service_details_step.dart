import 'package:flutter/material.dart';

class ServiceDetailsStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ServiceDetailsStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<ServiceDetailsStep> createState() => _ServiceDetailsStepState();
}

class _ServiceDetailsStepState extends State<ServiceDetailsStep> {
  final List<_ServiceItem> _services = [];

  @override
  void initState() {
    super.initState();
    // ✅ خدمة افتراضية مضافة مسبقًا
    _services.add(
      _ServiceItem(
        initialName: "تصميم واجهات تطبيق خدمات",
        initialDescription:
            "تصميم واجهات عصرية لتطبيقات الخدمات:\n"
            "• واجهة أنيقة متوافقة مع الهوية البصرية\n"
            "• تجربة مستخدم سلسة ومناسبة للجوال\n"
            "• تسليم سريع مع إمكانية التعديل",
        isUrgent: true,
        isEditing: false, // افتراضيًا ملخّصة، ليست في وضع تحرير
      ),
    );
  }

  @override
  void dispose() {
    for (final s in _services) {
      s.dispose();
    }
    super.dispose();
  }

  void _addService() {
    setState(() {
      _services.add(
        _ServiceItem(
          isUrgent: false,
          isEditing: true, // الخدمة الجديدة تُفتح في وضع تعديل مباشرة
        ),
      );
    });
  }

  void _toggleEdit(int index, bool editing) {
    setState(() {
      _services[index].isEditing = editing;
    });
  }

  void _removeService(int index) {
    if (_services.length == 1) {
      _showSnack("يجب أن يكون لديك خدمة واحدة على الأقل في ملفك.");
      return;
    }
    final item = _services[index];
    setState(() {
      item.dispose();
      _services.removeAt(index);
    });
    _showSnack("تم حذف الخدمة بنجاح.");
  }

  void _saveService(int index) {
    final item = _services[index];
    final name = item.name.text.trim();

    if (name.isEmpty) {
      _showSnack("رجاء أدخل اسمًا واضحًا للخدمة قبل الحفظ.");
      return;
    }

    setState(() {
      item.isEditing = false;
    });

    _showSnack("تم حفظ بيانات الخدمة ${index + 1}.");
  }

  void _handleNext() {
    final hasValidService = _services.any((s) => s.name.text.trim().isNotEmpty);

    if (!hasValidService) {
      _showSnack("أضف على الأقل خدمة واحدة تحتوي على اسم قبل المتابعة.");
      return;
    }

    // 👇 هنا لاحقًا ممكن تجمع وترسل للباكند
    // final data = _services
    //     .where((s) => s.name.text.trim().isNotEmpty)
    //     .map((s) => {
    //       "name": s.name.text.trim(),
    //       "description": s.description.text.trim(),
    //       "price": s.price.text.trim(),
    //       "is_urgent": s.isUrgent,
    //     })
    //     .toList();

    widget.onNext();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _buildInfoCard(),
              const SizedBox(height: 18),

              // ✅ قائمة الكروت (ملخّصة أو تحرير حسب الحالة)
              ...List.generate(
                _services.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _services.length - 1 ? 0 : 16,
                  ),
                  child: _buildServiceCard(index),
                ),
              ),

              const SizedBox(height: 18),

              // ✅ زر إضافة خدمة
              Center(
                child: OutlinedButton.icon(
                  onPressed: _addService,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                  label: const Text(
                    "إضافة خدمة أخرى",
                    style: TextStyle(
                      fontFamily: "Cairo",
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    side: BorderSide(color: Colors.deepPurple.withOpacity(0.7)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // ✅ أزرار السابق / التالي
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      label: const Text(
                        "السابق",
                        style: TextStyle(
                          fontFamily: "Cairo",
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: Colors.deepPurple.withOpacity(0.7),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleNext,
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "التالي",
                        style: TextStyle(
                          fontFamily: "Cairo",
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// عنوان + وصف بسيط للخطوة
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "الخدمات التي تقدمها",
          style: TextStyle(
            fontFamily: "Cairo",
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "أضف الخدمات الأساسية التي ترغب أن يراها العميل في ملفك.",
          style: TextStyle(
            fontFamily: "Cairo",
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  /// كرت إرشادي في الأعلى
  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, color: Colors.deepPurple, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "بعد حفظ الخدمة، ستظهر في كرت ملخّص يحتوي على الاسم، نبذة قصيرة، "
              "وحالة كونها خدمة عاجلة أم لا. يمكنك تعديل أو حذف أي خدمة في أي وقت.",
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 12,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// كرت خدمة واحدة: إمّا ملخّص أو وضع تحرير
  Widget _buildServiceCard(int index) {
    final item = _services[index];

    if (item.isEditing) {
      // 🔧 وضع التحرير
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.deepPurple.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الهيدر
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "تعديل بيانات الخدمة ${index + 1}",
                        style: const TextStyle(
                          fontFamily: "Cairo",
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeService(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  tooltip: "حذف هذه الخدمة",
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildFieldLabel("اسم الخدمة"),
            const SizedBox(height: 6),
            _buildTextField(
              controller: item.name,
              hint: "مثلاً: تطوير موقع تعريفي لشركة",
              icon: Icons.home_repair_service_outlined,
            ),
            const SizedBox(height: 12),

            _buildFieldLabel("وصف مختصر عن الخدمة"),
            const SizedBox(height: 6),
            _buildTextField(
              controller: item.description,
              hint: "صف بإيجاز ما الذي تقدمه في هذه الخدمة.",
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Switch(
                  value: item.isUrgent,
                  activeColor: Colors.deepPurple,
                  onChanged: (val) {
                    setState(() {
                      item.isUrgent = val;
                    });
                  },
                ),
                const SizedBox(width: 4),
                const Text(
                  "تُقدَّم كخدمة عاجلة",
                  style: TextStyle(fontFamily: "Cairo", fontSize: 12.5),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                TextButton(
                  onPressed: () => _toggleEdit(index, false),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(
                      fontFamily: "Cairo",
                      color: Colors.black54,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _saveService(index),
                  icon: const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "حفظ",
                    style: TextStyle(
                      fontFamily: "Cairo",
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 📦 وضع الملخّص (الكرت المستطيل بعد الحفظ)
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.deepPurple.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان + شارة عاجلة
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name.text.isEmpty
                      ? "خدمة بدون اسم"
                      : item.name.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Cairo",
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (item.isUrgent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.bolt, size: 14, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text(
                        "خدمة عاجلة",
                        style: TextStyle(
                          fontFamily: "Cairo",
                          fontSize: 11.5,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // وصف مختصر (جزء فقط مع نقاط واختصار)
          Text(
            item.description.text.isEmpty
                ? "لا يوجد وصف بعد — يمكنك إضافة وصف مختصر يوضح تفاصيل هذه الخدمة."
                : item.description.text.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: "Cairo",
              fontSize: 12.5,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "… وصف تفصيلي أطول يظهر داخل ملفك عند زيارة العميل لصفحة خدمتك.",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 11,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              TextButton.icon(
                onPressed: () => _toggleEdit(index, true),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.deepPurple,
                ),
                label: const Text(
                  "تعديل",
                  style: TextStyle(
                    fontFamily: "Cairo",
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeService(index),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                tooltip: "حذف هذه الخدمة",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: "Cairo",
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Colors.deepPurple,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: "Cairo", fontSize: 13.5),
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon, color: Colors.deepPurple) : null,
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: "Cairo",
          fontSize: 13,
          color: Colors.grey,
        ),
        filled: true,
        fillColor: const Color(0xFFF9F7FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.deepPurple.withOpacity(0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.deepPurple.withOpacity(0.25)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.deepPurple, width: 1.4),
        ),
      ),
    );
  }
}

/// عنصر داخلي لإدارة الكنترولات لكل خدمة
class _ServiceItem {
  final TextEditingController name;
  final TextEditingController description;
  bool isUrgent;
  bool isEditing;

  _ServiceItem({
    String? initialName,
    String? initialDescription,
    this.isUrgent = false,
    this.isEditing = false,
  }) : name = TextEditingController(text: initialName ?? ''),
       description = TextEditingController(text: initialDescription ?? '');

  void dispose() {
    name.dispose();
    description.dispose();
  }
}
