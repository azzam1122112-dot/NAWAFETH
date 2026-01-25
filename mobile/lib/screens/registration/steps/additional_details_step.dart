import 'package:flutter/material.dart';

class AdditionalDetailsStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AdditionalDetailsStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<AdditionalDetailsStep> createState() => _AdditionalDetailsStepState();
}

class _AdditionalDetailsStepState extends State<AdditionalDetailsStep> {
  // نبذة عامة عن المزود وخدماته
  final TextEditingController aboutController = TextEditingController(
    text:
        "مزود خدمات متخصص في تقديم حلول رقمية مخصصة، مع التركيز على الجودة والالتزام بمواعيد التسليم.",
  );

  // قوائم ديناميكية للمؤهلات والخبرات
  final List<String> qualifications = ["بكالوريوس في علوم الحاسب"];

  final List<String> experiences = [
    "أكثر من 3 سنوات في تطوير الأنظمة والمنصات الخدمية.",
  ];

  final TextEditingController _dialogController = TextEditingController();

  @override
  void dispose() {
    aboutController.dispose();
    _dialogController.dispose();
    super.dispose();
  }

  void _showAddDialog({
    required String title,
    required void Function(String value) onConfirm,
    String? hint,
  }) {
    _dialogController.clear();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: "Cairo",
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: _dialogController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint ?? "",
              hintStyle: const TextStyle(fontFamily: "Cairo"),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(fontFamily: "Cairo")),
            ),
            ElevatedButton(
              onPressed: () {
                final value = _dialogController.text.trim();
                if (value.isNotEmpty) {
                  onConfirm(value);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("إضافة", style: TextStyle(fontFamily: "Cairo")),
            ),
          ],
        );
      },
    );
  }

  void _addQualification() {
    _showAddDialog(
      title: "إضافة مؤهل جديد",
      hint: "مثال: شهادة مهنية، دورة معتمدة، أو درجة علمية",
      onConfirm: (value) {
        setState(() => qualifications.add(value));
      },
    );
  }

  void _addExperience() {
    _showAddDialog(
      title: "إضافة خبرة جديدة",
      hint: "مثال: تنفيذ نظام متكامل لقطاع معين، أو مشاريع معينة",
      onConfirm: (value) {
        setState(() => experiences.add(value));
      },
    );
  }

  void _removeQualification(int index) {
    setState(() => qualifications.removeAt(index));
  }

  void _removeExperience(int index) {
    setState(() => experiences.removeAt(index));
  }

  void _handleNext() {
    // كلها اختيارية، لكن لو حاب تضيف تحقق بسيط ممكن هنا
    widget.onNext();
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

              // نبذة تفصيلية عامة عن المزود وخدماته
              _buildAboutCard(),
              const SizedBox(height: 16),

              // كرت المؤهلات
              _buildQualificationsCard(),
              const SizedBox(height: 16),

              // كرت الخبرات العملية
              _buildExperiencesCard(),
              const SizedBox(height: 26),

              // أزرار الانتقال
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

  // ================= UI Helpers =================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "تفاصيل عنك كمقدم خدمة",
          style: TextStyle(
            fontFamily: "Cairo",
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        SizedBox(height: 6),
        Text(
          "عرّف عملاءك على مؤهلاتك وخبراتك ونبذة تفصيلية عنك وعن أسلوب عملك.",
          style: TextStyle(
            fontFamily: "Cairo",
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

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
          Icon(Icons.person_outline, color: Colors.deepPurple, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "هذه المعلومات تظهر في ملفك التعريفي وتساعد العميل على فهم خبرتك "
              "وقيمة الخدمات التي تقدمها. اكتبها بطريقة مهنية وبسيطة.",
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

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
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
        border: Border.all(color: Colors.deepPurple.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.menu_book_outlined,
            title: "نبذة تفصيلية عنك وعن خدماتك",
          ),
          const SizedBox(height: 10),
          TextField(
            controller: aboutController,
            maxLines: 5,
            maxLength: 1000,
            style: const TextStyle(fontFamily: "Cairo", fontSize: 13.5),
            decoration: InputDecoration(
              counterText: "",
              hintText:
                  "اكتب وصفًا تعريفيًا شاملًا عنك، عن طريقة عملك، وقيمة الخدمات التي تقدمها.",
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
                borderSide: BorderSide(
                  color: Colors.deepPurple.withOpacity(0.35),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.deepPurple.withOpacity(0.25),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Colors.deepPurple, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "حاول أن تذكر طريقة تعاملك مع العميل، أسلوب تنفيذك للمشاريع، وما يميّزك عن غيرك.",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 11.5,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualificationsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
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
        border: Border.all(color: Colors.deepPurple.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.workspace_premium_outlined,
            title: "المؤهلات والشهادات",
          ),
          const SizedBox(height: 8),
          const Text(
            "أضف مؤهلاتك العلمية أو الدورات المهنية أو الشهادات المعتمدة.",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 11.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          if (qualifications.isEmpty)
            const Text(
              "لم تقم بإضافة أي مؤهل حتى الآن.",
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 12,
                color: Colors.black45,
              ),
            )
          else
            Column(
              children: List.generate(
                qualifications.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          qualifications[index],
                          style: const TextStyle(
                            fontFamily: "Cairo",
                            fontSize: 12.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeQualification(index),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        tooltip: "حذف المؤهل",
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addQualification,
              icon: const Icon(Icons.add, size: 18, color: Colors.deepPurple),
              label: const Text(
                "إضافة مؤهل",
                style: TextStyle(
                  fontFamily: "Cairo",
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperiencesCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
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
        border: Border.all(color: Colors.deepPurple.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.timeline_outlined,
            title: "الخبرات العملية",
          ),
          const SizedBox(height: 8),
          const Text(
            "اذكر الخبرات أو المشاريع المهمة التي نفذتها، أو نوعية العملاء الذين تعاملت معهم.",
            style: TextStyle(
              fontFamily: "Cairo",
              fontSize: 11.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          if (experiences.isEmpty)
            const Text(
              "لم تقم بإضافة أي خبرة حتى الآن.",
              style: TextStyle(
                fontFamily: "Cairo",
                fontSize: 12,
                color: Colors.black45,
              ),
            )
          else
            Column(
              children: List.generate(
                experiences.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          experiences[index],
                          style: const TextStyle(
                            fontFamily: "Cairo",
                            fontSize: 12.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeExperience(index),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        tooltip: "حذف الخبرة",
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addExperience,
              icon: const Icon(Icons.add, size: 18, color: Colors.deepPurple),
              label: const Text(
                "إضافة خبرة",
                style: TextStyle(
                  fontFamily: "Cairo",
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.deepPurple),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: "Cairo",
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
