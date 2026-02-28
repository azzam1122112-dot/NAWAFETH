import 'package:flutter/material.dart';
import 'package:nawafeth/services/profile_service.dart';
import 'package:nawafeth/utils/debounced_save_runner.dart';

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
  final DebouncedSaveRunner _autoSaveRunner = DebouncedSaveRunner();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isInitialized = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    keywordsController.addListener(_onFieldChanged);
    metaDescriptionController.addListener(_onFieldChanged);
    slugController.addListener(_onFieldChanged);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final result = await ProfileService.fetchProviderProfile();
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final profile = result.data!;
      setState(() {
        _isInitialized = false;
        keywordsController.text = profile.seoKeywords;
        metaDescriptionController.text = profile.seoMetaDescription ?? '';
        slugController.text = profile.seoSlug ?? '';
        _isLoading = false;
        _saveError = null;
        _isInitialized = true;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _saveError = result.error ?? 'تعذر تحميل بيانات SEO';
      _isInitialized = true;
    });
  }

  void _onFieldChanged() {
    if (!_isInitialized) return;
    _autoSaveRunner.schedule(_saveSeo);
  }

  Future<void> _saveSeo() async {
    final payload = <String, dynamic>{
      'seo_keywords': keywordsController.text.trim(),
      'seo_meta_description': metaDescriptionController.text.trim(),
      'seo_slug': slugController.text.trim(),
    };

    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    final result = await ProfileService.updateProviderProfile(payload);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _saveError = result.isSuccess ? null : (result.error ?? 'فشل الحفظ');
    });
  }

  Future<void> _submit() async {
    await _autoSaveRunner.flush();
    widget.onNext();
  }

  @override
  void dispose() {
    keywordsController.removeListener(_onFieldChanged);
    metaDescriptionController.removeListener(_onFieldChanged);
    slugController.removeListener(_onFieldChanged);
    keywordsController.dispose();
    metaDescriptionController.dispose();
    slugController.dispose();
    _autoSaveRunner.dispose();
    super.dispose();
  }

  Widget _buildSaveStatus() {
    if (_isSaving) {
      return const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'جاري الحفظ التلقائي...',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
          ),
        ],
      );
    }

    if (_saveError != null) {
      return Text(
        _saveError!,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: Colors.redAccent,
        ),
      );
    }

    return const SizedBox.shrink();
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
                  '📈 إعدادات تحسين محركات البحث (SEO)',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'تحسين ظهورك في نتائج البحث بكتابة كلمات مفتاحية ووصف دقيق.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _buildSaveStatus(),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.deepPurple),
                    ),
                  )
                else ...[
                  TextFormField(
                    controller: keywordsController,
                    decoration: InputDecoration(
                      labelText: 'الكلمات المفتاحية',
                      hintText: 'مثلاً: تصميم، تطبيقات، خدمات إلكترونية',
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
                      labelText: 'وصف الصفحة (Meta Description)',
                      hintText: 'وصف يظهر في نتائج محركات البحث',
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
                      labelText: 'الرابط المخصص',
                      hintText: 'مثلاً: my-service-name',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _autoSaveRunner.flush();
                        widget.onBack();
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.deepPurple,
                      ),
                      label: const Text(
                        'السابق',
                        style: TextStyle(color: Colors.deepPurple),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text(
                        'تسجيل',
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
