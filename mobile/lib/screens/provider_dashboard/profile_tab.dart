import 'package:flutter/material.dart';

import '../../services/providers_api.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final Color mainColor = Colors.deepPurple;

  bool _loading = true;
  bool _saving = false;

  String _providerType = 'individual';
  bool _acceptsUrgent = false;

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _coverageRadiusController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _yearsExperienceController.dispose();
    _coverageRadiusController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final json = await ProvidersApi().getMyProviderProfile();
    if (!mounted) return;

    void setText(TextEditingController c, dynamic v) {
      final s = (v ?? '').toString();
      c.text = s;
    }

    setState(() {
      _loading = false;
      if (json == null) return;

      _providerType = (json['provider_type'] ?? 'individual').toString();
      _acceptsUrgent = json['accepts_urgent'] == true;

      setText(_displayNameController, json['display_name']);
      setText(_bioController, json['bio']);
      setText(_cityController, json['city']);
      setText(_yearsExperienceController, json['years_experience']);
      setText(_coverageRadiusController, json['coverage_radius_km']);
      setText(_latController, json['lat']);
      setText(_lngController, json['lng']);
    });
  }

  int? _parseInt(String s) {
    final v = int.tryParse(s.trim());
    return v;
  }

  double? _parseDouble(String s) {
    final v = double.tryParse(s.trim());
    return v;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final patch = <String, dynamic>{
      'provider_type': _providerType,
      'display_name': _displayNameController.text.trim(),
      'bio': _bioController.text.trim(),
      'city': _cityController.text.trim(),
      'accepts_urgent': _acceptsUrgent,
    };

    final years = _parseInt(_yearsExperienceController.text);
    if (years != null) patch['years_experience'] = years;

    final radius = _parseInt(_coverageRadiusController.text);
    if (radius != null) patch['coverage_radius_km'] = radius;

    final lat = _parseDouble(_latController.text);
    final lng = _parseDouble(_lngController.text);
    if (lat != null) patch['lat'] = lat;
    if (lng != null) patch['lng'] = lng;

    final updated = await ProvidersApi().updateMyProviderProfile(patch);
    if (!mounted) return;
    setState(() => _saving = false);

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ البيانات حالياً.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ البيانات بنجاح')),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey[100],
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: _inputDecoration(label),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: mainColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'الملف الشخصي',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'حفظ',
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save, color: Colors.white),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'بيانات المزود',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _providerType,
                          decoration: _inputDecoration('نوع الحساب'),
                          items: const [
                            DropdownMenuItem(value: 'individual', child: Text('فرد', style: TextStyle(fontFamily: 'Cairo'))),
                            DropdownMenuItem(value: 'company', child: Text('منشأة', style: TextStyle(fontFamily: 'Cairo'))),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _providerType = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        _field(label: 'اسم الصفحة', controller: _displayNameController),
                        _field(label: 'نبذة مختصرة', controller: _bioController, maxLines: 3),
                        _field(label: 'المدينة', controller: _cityController),
                        _field(
                          label: 'سنوات الخبرة',
                          controller: _yearsExperienceController,
                          keyboardType: TextInputType.number,
                        ),
                        _field(
                          label: 'نطاق التغطية (كم)',
                          controller: _coverageRadiusController,
                          keyboardType: TextInputType.number,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'Latitude',
                                controller: _latController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                label: 'Longitude',
                                controller: _lngController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile.adaptive(
                          value: _acceptsUrgent,
                          onChanged: (v) => setState(() => _acceptsUrgent = v),
                          title: const Text('أقبل الطلبات العاجلة', style: TextStyle(fontFamily: 'Cairo')),
                          contentPadding: EdgeInsets.zero,
                          activeColor: mainColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),

    );
  }
}

/*
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            controller: _tabController,
            tabs: [
              Tab(text: "معلومات الحساب"),
              Tab(text: "معلومات عامة"),
              Tab(text: "معلومات إضافية"),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF4F4F4),
        body: TabBarView(
          controller: _tabController,
          children: [
            buildSection([
              {
                "key": "fullName",
                "label": "الاسم الكامل",
                "icon": Icons.person,
              },
              {
                "key": "englishName",
                "label": "الاسم بالإنجليزية",
                "icon": Icons.translate,
              },
              {
                "key": "accountType",
                "label": "صفة الحساب",
                "icon": Icons.badge_outlined,
              },
              {
                "key": "about",
                "label": "نبذة عنك",
                "icon": Icons.info_outline,
                "multiline": true,
              },
              {
                "key": "specialization",
                "label": "التخصص",
                "icon": Icons.category,
              },
            ]),
            buildSection([
              {
                "key": "experience",
                "label": "سنوات الخبرة",
                "icon": Icons.work_history,
              },
              {
                "key": "languages",
                "label": "لغات التواصل",
                "icon": Icons.language,
              },
              {
                "key": "location",
                "label": "النطاق الجغرافي",
                "icon": Icons.location_on_outlined,
              },
              {
                "key": "map",
                "label": "الموقع على الخريطة",
                "icon": Icons.map_outlined,
              },
            ]),
            buildSection([
              {
                "key": "details",
                "label": "شرح تفصيلي",
                "icon": Icons.notes,
                "multiline": true,
              },
              {
                "key": "qualification",
                "label": "المؤهلات",
                "icon": Icons.school,
              },
              {
                "key": "website",
                "label": "الموقع الإلكتروني",
                "icon": Icons.link,
              },
              {
                "key": "social",
                "label": "روابط التواصل",
                "icon": Icons.share_outlined,
              },
              {
                "key": "phone",
                "label": "رقم الجوال",
                "icon": Icons.phone_android,
              },
              {
                "key": "keywords",
                "label": "الكلمات المفتاحية",
                "icon": Icons.label_outline,
                "multiline": true,
              },
            ]),
          ],
        ),
      ),
    );
  }
}

*/
