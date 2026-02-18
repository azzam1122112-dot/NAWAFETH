import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/user_scoped_prefs.dart';
import '../../../services/providers_api.dart';
import '../../../widgets/profile_wizard_shell.dart';

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
  static const String _draftKey = 'provider_additional_details_draft_v1';

  // نبذة عامة عن المزود وخدماته
  final TextEditingController aboutController = TextEditingController();

  // سنوات الخبرة
  final TextEditingController yearsExperienceController = TextEditingController();

  // قوائم ديناميكية للمؤهلات والخبرات
  final List<String> qualifications = [];

  final List<String> experiences = [];

  final TextEditingController _dialogController = TextEditingController();

  Timer? _draftTimer;
  bool _loadingFromBackend = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadFromBackendBestEffort();
    aboutController.addListener(() {
      _scheduleDraftSave();
      _updateSectionDone();
    });

    yearsExperienceController.addListener(() {
      _scheduleDraftSave();
      _updateSectionDone();
    });
  }

  Future<void> _loadFromBackendBestEffort() async {
    if (_loadingFromBackend) return;
    setState(() => _loadingFromBackend = true);
    try {
      final profile = await ProvidersApi().getMyProviderProfile();
      if (profile == null) return;

      List<String> asList(dynamic v) {
        if (v is! List) return <String>[];
        return v
            .map((e) => (e ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final about = (profile['about_details'] ?? '').toString().trim();
      final yearsExpRaw = (profile['years_experience'] ?? '').toString().trim();
      final qs = asList(profile['qualifications']);
      final ex = asList(profile['experiences']);

      if (!mounted) return;
      setState(() {
        if (aboutController.text.trim().isEmpty && about.isNotEmpty) {
          aboutController.text = about;
        }

        if (yearsExperienceController.text.trim().isEmpty && yearsExpRaw.isNotEmpty) {
          yearsExperienceController.text = yearsExpRaw;
        }

        if (qualifications.isEmpty && qs.isNotEmpty) {
          qualifications.addAll(qs);
        }
        if (experiences.isEmpty && ex.isNotEmpty) {
          experiences.addAll(ex);
        }
      });
      _updateSectionDone();
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
      List<String> asStringList(dynamic v) {
        if (v is! List) return <String>[];
        return v.map((e) => (e ?? '').toString()).where((s) => s.trim().isNotEmpty).toList();
      }

      if (aboutController.text.trim().isEmpty) {
        aboutController.text = asString(data['about']);
      }

      if (yearsExperienceController.text.trim().isEmpty) {
        yearsExperienceController.text = asString(data['years_experience']);
      }

      final qs = asStringList(data['qualifications']);
      final ex = asStringList(data['experiences']);
      if (mounted) {
        setState(() {
          if (qualifications.isEmpty && qs.isNotEmpty) {
            qualifications.addAll(qs);
          }
          if (experiences.isEmpty && ex.isNotEmpty) {
            experiences.addAll(ex);
          }
        });
      }

      _updateSectionDone();
    } catch (_) {
      // Best-effort.
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = await UserScopedPrefs.readUserId();
        final data = <String, dynamic>{
          'about': aboutController.text.trim(),
          'years_experience': yearsExperienceController.text.trim(),
          'qualifications': qualifications,
          'experiences': experiences,
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

  void _updateSectionDone() {
    final years = int.tryParse(yearsExperienceController.text.trim()) ?? 0;
    final done =
        aboutController.text.trim().isNotEmpty ||
        years > 0 ||
        qualifications.isNotEmpty ||
        experiences.isNotEmpty;
    SharedPreferences.getInstance().then((prefs) async {
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.setBoolScoped(
        prefs,
        'provider_section_done_additional',
        done,
        userId: userId,
      );
    }).catchError((_) {});
  }

  void _clearDraft() {
    SharedPreferences.getInstance().then((prefs) async {
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.removeScoped(prefs, _draftKey, userId: userId);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    aboutController.dispose();
    yearsExperienceController.dispose();
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
        _scheduleDraftSave();
        _updateSectionDone();
      },
    );
  }

  void _addExperience() {
    _showAddDialog(
      title: "إضافة خبرة جديدة",
      hint: "مثال: تنفيذ نظام متكامل لقطاع معين، أو مشاريع معينة",
      onConfirm: (value) {
        setState(() => experiences.add(value));
        _scheduleDraftSave();
        _updateSectionDone();
      },
    );
  }

  void _removeQualification(int index) {
    setState(() => qualifications.removeAt(index));
    _scheduleDraftSave();
    _updateSectionDone();
  }

  void _removeExperience(int index) {
    setState(() => experiences.removeAt(index));
    _scheduleDraftSave();
    _updateSectionDone();
  }

  Future<bool> _saveToBackend() async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final yearsParsed = int.tryParse(yearsExperienceController.text.trim());
      final years = (yearsParsed == null || yearsParsed < 0) ? 0 : yearsParsed;
      final payload = <String, dynamic>{
        'years_experience': years,
        'about_details': aboutController.text.trim(),
        'qualifications': qualifications,
        'experiences': experiences,
      };
      final updated = await ProvidersApi().updateMyProviderProfile(payload);
      if (updated == null) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التفاصيل الإضافية حالياً.')),
        );
        return false;
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التفاصيل الإضافية حالياً.')),
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

  Future<void> _handleNext() async {
    final ok = await _saveToBackend();
    if (!ok) return;
    _updateSectionDone();
    _clearDraft();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileWizardShell(
      title: 'تفاصيل إضافية عنك',
      subtitle: 'عرّف العملاء بخبرتك ومؤهلاتك لتعزيز الثقة قبل طلب الخدمة.',
      showTopLoader: _loadingFromBackend,
      onBack: widget.onBack,
      onNext: _handleNext,
      nextBusy: _saving,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 18),
                _buildYearsExperienceCard(),
                const SizedBox(height: 16),
                _buildAboutCard(),
                const SizedBox(height: 16),
                _buildQualificationsCard(),
                const SizedBox(height: 16),
                _buildExperiencesCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= UI Helpers =================

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

  Widget _buildYearsExperienceCard() {
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
            icon: Icons.work_outline,
            title: 'سنوات الخبرة',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: yearsExperienceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'مثال: 5',
              hintStyle: const TextStyle(
                fontFamily: 'Cairo',
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
            'اكتب عدد سنوات خبرتك في مجالك (اختياري).',
            style: TextStyle(
              fontFamily: 'Cairo',
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
