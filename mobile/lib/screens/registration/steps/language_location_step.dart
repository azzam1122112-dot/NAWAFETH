import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_radius_picker_screen.dart';

class LanguageLocationStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const LanguageLocationStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<LanguageLocationStep> createState() => _LanguageLocationStepState();
}

class _LanguageLocationStepState extends State<LanguageLocationStep> {
  static const String _draftKey = 'provider_lang_loc_draft_v1';

  final List<String> predefinedLanguages = ['عربي', 'English', 'أخرى'];
  final List<String> selectedLanguages = [];
  final List<String> customLanguages = [];
  final TextEditingController customLanguageController =
      TextEditingController();
  final TextEditingController locationController = TextEditingController();

  int? _selectedDistanceKm;
  LatLng? _selectedCenter;

  final Map<String, bool> serviceRange = {
    'مدينتي 🏙️': false,
    'منطقتي 🗺️': false,
    'دولتي 🌍': false,
    'ضمن نطاق محدد 📍': false,
  };

  static const List<int> _distanceOptionsKm = [2, 5, 10, 20, 50];

  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    customLanguageController.addListener(_scheduleDraftSave);
    locationController.addListener(_scheduleDraftSave);
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.trim().isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;

      List<String> asStringList(dynamic v) {
        if (v is! List) return <String>[];
        return v.map((e) => (e ?? '').toString()).where((s) => s.trim().isNotEmpty).toList();
      }

      int? asInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse((v ?? '').toString());
      }

      double? asDouble(dynamic v) {
        if (v is double) return v;
        if (v is num) return v.toDouble();
        return double.tryParse((v ?? '').toString());
      }

      final langs = asStringList(data['selected_languages']);
      final custom = asStringList(data['custom_languages']);
      final ranges = data['service_range'];
      final distance = asInt(data['distance_km']);
      final lat = asDouble(data['lat']);
      final lng = asDouble(data['lng']);
      final locationText = (data['location_text'] ?? '').toString();

      if (!mounted) return;
      setState(() {
        if (langs.isNotEmpty) {
          selectedLanguages
            ..clear()
            ..addAll(langs);
        }
        if (custom.isNotEmpty) {
          customLanguages
            ..clear()
            ..addAll(custom);
        }
        if (ranges is Map) {
          for (final k in serviceRange.keys) {
            serviceRange[k] = ranges[k] == true;
          }
        }
        _selectedDistanceKm = distance;
        if (lat != null && lng != null) {
          _selectedCenter = LatLng(lat, lng);
        }
        if (locationController.text.trim().isEmpty && locationText.trim().isNotEmpty) {
          locationController.text = locationText;
        }
      });

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
        final data = <String, dynamic>{
          'selected_languages': selectedLanguages,
          'custom_languages': customLanguages,
          'service_range': serviceRange,
          'distance_km': _selectedDistanceKm,
          'lat': _selectedCenter?.latitude,
          'lng': _selectedCenter?.longitude,
          'location_text': locationController.text.trim(),
        };
        await prefs.setString(_draftKey, jsonEncode(data));
      } catch (_) {
        // ignore
      }
    });
  }

  void _updateSectionDone() {
    final hasAnyRange = serviceRange.values.any((v) => v);
    final done = selectedLanguages.isNotEmpty || customLanguages.isNotEmpty || hasAnyRange || _selectedCenter != null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('provider_section_done_lang_loc', done);
    }).catchError((_) {});
  }

  void _handleNext() {
    _updateSectionDone();
    final prefsDone = serviceRange.values.any((v) => v) ||
        selectedLanguages.isNotEmpty ||
        customLanguages.isNotEmpty ||
        _selectedCenter != null;

    if (!prefsDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اختر لغة واحدة على الأقل أو حدّد نطاق/موقع قبل المتابعة.',
          ),
        ),
      );
      return;
    }

    _scheduleDraftSave();
    widget.onNext();
  }

  void _ensureDefaultDistance() {
    if (_selectedDistanceKm == null) {
      _selectedDistanceKm = 10;
    }
  }

  Future<void> _pickMapLocation() async {
    if (_selectedDistanceKm == null) {
      _ensureDefaultDistance();
      if (mounted) setState(() {});
    }

    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapRadiusPickerScreen(
          radiusKm: _selectedDistanceKm!,
          initialCenter: _selectedCenter,
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedCenter = picked;
      locationController.text =
          '(${picked.latitude.toStringAsFixed(5)}, ${picked.longitude.toStringAsFixed(5)}) • ${_selectedDistanceKm} كم';
    });

    _scheduleDraftSave();
    _updateSectionDone();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    customLanguageController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4FC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                Expanded(child: SingleChildScrollView(child: _buildForm())),
                const SizedBox(height: 12),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "اللغة والموقع الجغرافي",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
            fontFamily: "Cairo",
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "حدد اللغات التي يمكنك التعامل بها ونطاق تقديم خدماتك.",
          style: TextStyle(
            fontFamily: "Cairo",
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        _infoTip(
          icon: Icons.info_outline,
          text:
              "اختيار اللغات ونطاق الخدمة يساعد في عرضك للعملاء المناسبين أكثر لاهتماماتك وموقعك.",
        ),
      ],
    );
  }

  Widget _infoTip({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontSize: 11.5,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- FORM ----------------

  Widget _buildForm() {
    return Column(
      children: [
        _sectionCard(
          icon: FontAwesomeIcons.language,
          title: 'ما اللغة التي يمكنك تقديم الخدمة من خلالها؟',
          subtitle:
              "اختر اللغات التي يمكنك التحدث والتعامل بها مع العملاء، ويمكنك إضافة لغات أخرى يدويًا.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    predefinedLanguages.map((lang) {
                      final selected = selectedLanguages.contains(lang);
                      return FilterChip(
                        label: Text(lang),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            val
                                ? selectedLanguages.add(lang)
                                : selectedLanguages.remove(lang);
                          });

                          _scheduleDraftSave();
                          _updateSectionDone();
                        },
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.grey.shade200,
                        labelStyle: TextStyle(
                          fontFamily: "Cairo",
                          color: selected ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList(),
              ),
              if (selectedLanguages.contains('أخرى'))
                _buildCustomLanguageInput(),
              if (customLanguages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    children:
                        customLanguages.map((lang) {
                          return Chip(
                            label: Text(
                              lang,
                              style: const TextStyle(fontFamily: "Cairo"),
                            ),
                            onDeleted: () {
                              setState(() => customLanguages.remove(lang));
                              _scheduleDraftSave();
                              _updateSectionDone();
                            },
                          );
                        }).toList(),
                  ),
                ),
            ],
          ),
        ),

        _sectionCard(
          icon: FontAwesomeIcons.mapMarkedAlt,
          title: 'نطاق الخدمة الجغرافي',
          subtitle:
              "حدد النطاق الذي يمكنك تقديم خدماتك فيه. يمكن اختيار أكثر من خيار حسب طبيعة عملك.",
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                serviceRange.entries.map((entry) {
                  final selected = entry.value;
                  return FilterChip(
                    label: Text(
                      entry.key,
                      style: const TextStyle(fontFamily: "Cairo"),
                    ),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        serviceRange[entry.key] = val;
                        if (entry.key == 'ضمن نطاق محدد 📍' && val) {
                          _ensureDefaultDistance();
                        }
                      });

                      _scheduleDraftSave();
                      _updateSectionDone();
                    },
                    selectedColor: Colors.deepPurple,
                    backgroundColor: Colors.grey.shade200,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                    ),
                  );
                }).toList(),
          ),
        ),

        if (serviceRange['ضمن نطاق محدد 📍'] == true)
          _sectionCard(
            icon: FontAwesomeIcons.locationCrosshairs,
            title: 'المسافة والموقع المحدد',
            subtitle:
                "اختر المسافة التي يمكنك تغطيتها، وحدد موقعك الجغرافي على الخريطة.",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  children:
                      _distanceOptionsKm.map((km) {
                        final selected = _selectedDistanceKm == km;
                        return FilterChip(
                          label: Text(
                            '$km كم',
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedDistanceKm = km;
                              if (_selectedCenter != null) {
                                locationController.text =
                                    '(${_selectedCenter!.latitude.toStringAsFixed(5)}, ${_selectedCenter!.longitude.toStringAsFixed(5)}) • $_selectedDistanceKm كم';
                              }
                            });

                            _scheduleDraftSave();
                            _updateSectionDone();
                          },
                          selectedColor: Colors.deepPurple,
                          backgroundColor: Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _pickMapLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text(
                    "تحديد موقعي الجغرافي",
                    style: TextStyle(fontFamily: "Cairo"),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: locationController,
                  readOnly: true,
                  style: const TextStyle(fontFamily: "Cairo", fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'موقعي المختار والمسافة',
                    hintStyle: const TextStyle(
                      fontFamily: "Cairo",
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.deepPurple,
                        width: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------- CUSTOM LANGUAGE INPUT ----------------

  Widget _buildCustomLanguageInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: customLanguageController,
              style: const TextStyle(fontFamily: "Cairo", fontSize: 13),
              decoration: InputDecoration(
                hintText: 'أدخل اللغة ثم اضغط "تم"',
                hintStyle: const TextStyle(
                  fontFamily: "Cairo",
                  fontSize: 13,
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.deepPurple),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final lang = customLanguageController.text.trim();
              if (lang.isNotEmpty && !customLanguages.contains(lang)) {
                setState(() {
                  customLanguages.add(lang);
                  customLanguageController.clear();
                });

                _scheduleDraftSave();
                _updateSectionDone();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("تم", style: TextStyle(fontFamily: "Cairo")),
          ),
        ],
      ),
    );
  }

  // ---------------- SECTION CARD ----------------

  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                  fontFamily: "Cairo",
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: "Cairo",
                fontSize: 11.5,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ---------------- ACTION BUTTONS ----------------

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _scheduleDraftSave();
              _updateSectionDone();
              widget.onBack();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text("السابق", style: TextStyle(fontFamily: "Cairo")),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.deepPurple),
              foregroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleNext,
            icon: const Icon(Icons.arrow_forward),
            label: const Text("التالي", style: TextStyle(fontFamily: "Cairo")),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
