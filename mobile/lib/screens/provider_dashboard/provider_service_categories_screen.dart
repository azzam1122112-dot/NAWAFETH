import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/colors.dart';
import '../../models/category.dart';
import '../../services/providers_api.dart';
import '../../utils/user_scoped_prefs.dart';

class ProviderServiceCategoriesScreen extends StatefulWidget {
  const ProviderServiceCategoriesScreen({super.key});

  @override
  State<ProviderServiceCategoriesScreen> createState() => _ProviderServiceCategoriesScreenState();
}

class _ProviderServiceCategoriesScreenState extends State<ProviderServiceCategoriesScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Category> _categories = const [];
  final Set<int> _selectedSubcategoryIds = <int>{};

  bool _acceptsUrgent = false;

  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ProvidersApi();
      final categories = await api.getCategories();
      final selected = await api.getMyProviderSubcategories();

      // Best effort: read accepts_urgent from provider profile
      bool acceptsUrgent = false;
      try {
        final profile = await api.getMyProviderProfile();
        acceptsUrgent = profile?['accepts_urgent'] == true;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedSubcategoryIds
          ..clear()
          ..addAll(selected);
        _acceptsUrgent = acceptsUrgent;
        _loading = false;
      });

      await _persistDoneFlag();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل التصنيفات حالياً.';
      });
    }
  }

  Future<void> _persistDoneFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.setBoolScoped(
        prefs,
        'provider_section_done_service_details',
        _selectedSubcategoryIds.isNotEmpty,
        userId: userId,
      );
    } catch (_) {
      // ignore
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 550), () async {
      await _saveNow(showSnackOnError: false);
    });
  }

  Future<void> _saveNow({required bool showSnackOnError}) async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final api = ProvidersApi();
      final ids = _selectedSubcategoryIds.toList()..sort();
      await api.setMyProviderSubcategories(ids);
      await _persistDoneFlag();
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      if (showSnackOnError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الخدمات حالياً.')),
        );
      }
    }
  }

  Future<void> _toggleUrgent(bool value) async {
    setState(() {
      _acceptsUrgent = value;
      _saving = true;
    });

    try {
      final res = await ProvidersApi().updateMyProviderProfile({'accepts_urgent': value});
      if (!mounted) return;
      setState(() {
        _acceptsUrgent = (res?['accepts_urgent'] == true);
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث إعداد الطلبات العاجلة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: AppColors.deepPurple,
          foregroundColor: Colors.white,
          title: const Text('الخدمات والتخصصات', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () async {
                await _saveNow(showSnackOnError: true);
                if (!mounted) return;
                Navigator.pop(context, _selectedSubcategoryIds.isNotEmpty);
              },
              child: const Text('تم', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(fontFamily: 'Cairo')),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الطلبات العاجلة',
                                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'فعّل استقبال العاجل ليظهر لك صندوق الوارد العاجل حسب تخصصاتك.',
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _acceptsUrgent,
                              onChanged: _saving ? null : _toggleUrgent,
                              activeColor: AppColors.deepPurple,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedSubcategoryIds.isEmpty
                                    ? 'اختر تخصصاً واحداً على الأقل.'
                                    : 'تم اختيار ${_selectedSubcategoryIds.length} تخصص/تخصصات.',
                                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (_saving)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._categories.map((cat) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: ExpansionTile(
                            title: Text(
                              cat.name,
                              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                            ),
                            children: cat.subcategories.map((sub) {
                              final selected = _selectedSubcategoryIds.contains(sub.id);
                              return CheckboxListTile(
                                value: selected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedSubcategoryIds.add(sub.id);
                                    } else {
                                      _selectedSubcategoryIds.remove(sub.id);
                                    }
                                  });
                                  _persistDoneFlag();
                                  _scheduleSave();
                                },
                                title: Text(sub.name, style: const TextStyle(fontFamily: 'Cairo')),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: AppColors.deepPurple,
                              );
                            }).toList(),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }
}
