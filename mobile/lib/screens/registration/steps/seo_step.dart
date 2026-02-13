import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/user_scoped_prefs.dart';
import '../../../services/providers_api.dart';
import '../../../widgets/profile_wizard_shell.dart';

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
  bool _loadingFromBackend = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadFromBackendBestEffort();
    void onChange() {
      _scheduleDraftSave();
      _updateSectionDone();
    }

    keywordsController.addListener(onChange);
    metaDescriptionController.addListener(onChange);
    slugController.addListener(onChange);
  }

  Future<void> _loadFromBackendBestEffort() async {
    if (_loadingFromBackend) return;
    setState(() => _loadingFromBackend = true);
    try {
      final profile = await ProvidersApi().getMyProviderProfile();
      if (profile == null) return;

      final keywords = (profile['seo_keywords'] ?? '').toString().trim();
      final meta = (profile['seo_meta_description'] ?? '').toString().trim();
      final slug = (profile['seo_slug'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        if (keywordsController.text.trim().isEmpty && keywords.isNotEmpty) {
          keywordsController.text = keywords;
        }
        if (metaDescriptionController.text.trim().isEmpty && meta.isNotEmpty) {
          metaDescriptionController.text = meta;
        }
        if (slugController.text.trim().isEmpty && slug.isNotEmpty) {
          slugController.text = slug;
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

  Future<bool> _saveToBackend() async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'seo_keywords': keywordsController.text.trim(),
        'seo_meta_description': metaDescriptionController.text.trim(),
        'seo_slug': slugController.text.trim(),
      };
      final updated = await ProvidersApi().updateMyProviderProfile(payload);
      if (updated == null) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ إعدادات SEO حالياً.')),
        );
        return false;
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ إعدادات SEO حالياً.')),
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

  Future<void> _submit() async {
    final ok = await _saveToBackend();
    if (!ok) return;
    _updateSectionDone();
    _clearDraft();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label, String hint, IconData icon) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
        prefixIcon: Icon(icon, color: const Color(0xFF0F4C81)),
        filled: true,
        fillColor: const Color(0xFFF7FAFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9E6FF)),
        ),
      );
    }

    return ProfileWizardShell(
      title: 'تهيئة الظهور في البحث',
      subtitle: 'أضف كلماتك الأساسية ووصفًا واضحًا لتحسين الوصول لخدماتك.',
      showTopLoader: _loadingFromBackend,
      onBack: widget.onBack,
      onNext: _submit,
      nextBusy: _saving,
      nextLabel: 'حفظ ومتابعة',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: keywordsController,
                  decoration: dec(
                    'الكلمات المفتاحية',
                    'مثال: صيانة، تشطيبات، مقاولات، خدمات منزلية',
                    Icons.tag,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: metaDescriptionController,
                  maxLines: 3,
                  decoration: dec(
                    'وصف مختصر',
                    'وصف يظهر للعميل في نتائج البحث.',
                    Icons.description,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: slugController,
                  decoration: dec(
                    'الرابط المخصص',
                    'مثال: nawafeth-maintenance',
                    Icons.link,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
