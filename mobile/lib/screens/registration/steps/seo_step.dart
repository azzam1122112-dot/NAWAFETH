import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/user_scoped_prefs.dart';

class SeoStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const SeoStep({super.key, required this.onNext, required this.onBack});

  @override
  State<SeoStep> createState() => _SeoStepState();
}

class _SeoStepState extends State<SeoStep> {
  static const String _draftKey = 'provider_seo_draft_v1';

  final TextEditingController keywordsController = TextEditingController();
  final TextEditingController metaDescriptionController = TextEditingController();
  final TextEditingController slugController = TextEditingController();

  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    void onChange() {
      _scheduleDraftSave();
      _updateSectionDone();
    }

    keywordsController.addListener(onChange);
    metaDescriptionController.addListener(onChange);
    slugController.addListener(onChange);
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

      if (keywordsController.text.trim().isEmpty) {
        keywordsController.text = asString(data['keywords']);
      }
      if (metaDescriptionController.text.trim().isEmpty) {
        metaDescriptionController.text = asString(data['meta']);
      }
      if (slugController.text.trim().isEmpty) {
        slugController.text = asString(data['slug']);
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
          'keywords': keywordsController.text.trim(),
          'meta': metaDescriptionController.text.trim(),
          'slug': slugController.text.trim(),
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
    final done = keywordsController.text.trim().isNotEmpty ||
        metaDescriptionController.text.trim().isNotEmpty ||
        slugController.text.trim().isNotEmpty;

    SharedPreferences.getInstance().then((prefs) async {
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.setBoolScoped(
        prefs,
        'provider_section_done_seo',
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
    keywordsController.dispose();
    metaDescriptionController.dispose();
    slugController.dispose();
    super.dispose();
  }

  void _submit() {
    _updateSectionDone();
    _clearDraft();
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
