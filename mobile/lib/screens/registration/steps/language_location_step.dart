import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/providers_api.dart';
import '../../../utils/user_scoped_prefs.dart';
import '../../provider_dashboard/google_map_location_picker_screen.dart';

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

  LatLng? _selectedCenter;
  bool _loadingFromBackend = false;
  bool _savingLocation = false;

  Timer? _draftTimer;

  Future<void> _saveDraftNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserScopedPrefs.readUserId();
      final data = <String, dynamic>{
        'selected_languages': selectedLanguages,
        'custom_languages': customLanguages,
        'lat': _selectedCenter?.latitude,
        'lng': _selectedCenter?.longitude,
        'location_text': locationController.text.trim(),
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
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadFromBackendBestEffort();
    customLanguageController.addListener(_scheduleDraftSave);
    locationController.addListener(_scheduleDraftSave);
  }

  Future<void> _loadFromBackendBestEffort() async {
    if (_loadingFromBackend) return;
    setState(() => _loadingFromBackend = true);
    try {
      final json = await ProvidersApi().getMyProviderProfile();
      if (json == null) return;

      double? asDouble(dynamic v) {
        if (v is double) return v;
        if (v is num) return v.toDouble();
        return double.tryParse((v ?? '').toString());
      }

      final lat = asDouble(json['lat']);
      final lng = asDouble(json['lng']);
      if (lat == null || lng == null) return;
      if (!mounted) return;

      setState(() {
        _selectedCenter = LatLng(lat, lng);
        locationController.text =
            '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
      });
      // Keep local draft in sync when backend location changes.
      await _saveDraftNow();
      _updateSectionDone();
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) setState(() => _loadingFromBackend = false);
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

      List<String> asStringList(dynamic v) {
        if (v is! List) return <String>[];
        return v.map((e) => (e ?? '').toString()).where((s) => s.trim().isNotEmpty).toList();
      }

      double? asDouble(dynamic v) {
        if (v is double) return v;
        if (v is num) return v.toDouble();
        return double.tryParse((v ?? '').toString());
      }

      final langs = asStringList(data['selected_languages']);
      final custom = asStringList(data['custom_languages']);
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
        final userId = await UserScopedPrefs.readUserId();
        final data = <String, dynamic>{
          'selected_languages': selectedLanguages,
          'custom_languages': customLanguages,
          'lat': _selectedCenter?.latitude,
          'lng': _selectedCenter?.longitude,
          'location_text': locationController.text.trim(),
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
    final done =
        selectedLanguages.isNotEmpty || customLanguages.isNotEmpty || _selectedCenter != null;
    SharedPreferences.getInstance().then((prefs) async {
      final userId = await UserScopedPrefs.readUserId();
      await UserScopedPrefs.setBoolScoped(
        prefs,
        'provider_section_done_lang_loc',
        done,
        userId: userId,
      );
    }).catchError((_) {});
  }

  void _handleNext() {
    _updateSectionDone();
    final prefsDone = selectedLanguages.isNotEmpty ||
      customLanguages.isNotEmpty ||
      _selectedCenter != null;

    if (!prefsDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اختر لغة واحدة على الأقل أو حدّد موقعك قبل المتابعة.',
          ),
        ),
      );
      return;
    }

    // Ensure draft + backend location are in sync best-effort.
    () async {
      // If user typed coordinates but didn't use the picker, try to parse them.
      if (_selectedCenter == null) {
        final text = locationController.text.trim();
        final m = RegExp(r'\(?\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)?').firstMatch(text);
        if (m != null) {
          final lat = double.tryParse(m.group(1) ?? '');
          final lng = double.tryParse(m.group(2) ?? '');
          if (lat != null && lng != null) {
            _selectedCenter = LatLng(lat, lng);
          }
        }
      }

      await _saveDraftNow();

      final point = _selectedCenter;
      if (point != null) {
        await _saveLocationToBackendBestEffort(point, showSnack: false);
      }
    }();

    _scheduleDraftSave();
    widget.onNext();
  }

  Future<void> _pickMapLocation() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => GoogleMapLocationPickerScreen(
          initialCenter: _selectedCenter,
        ),
      ),
    );

    if (picked == null || !mounted) return;
    final lat = picked['lat'];
    final lng = picked['lng'];
    if (lat is! num || lng is! num) return;

    final point = LatLng(lat.toDouble(), lng.toDouble());
    setState(() {
      _selectedCenter = point;
      locationController.text =
          '(${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
    });

    await _saveDraftNow();
    await _saveLocationToBackendBestEffort(point);
    _scheduleDraftSave();
    _updateSectionDone();
  }

  Future<void> _saveLocationToBackendBestEffort(LatLng point, {bool showSnack = true}) async {
    if (_savingLocation) return;
    setState(() => _savingLocation = true);
    try {
      final res = await ProvidersApi().updateMyProviderProfile({
        'lat': point.latitude,
        'lng': point.longitude,
      });
      if (!mounted) return;
      if (!showSnack) return;
      if (res == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الموقع حالياً.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الموقع الجغرافي.')),
      );
    } catch (e) {
      if (!mounted) return;
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatDioError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingLocation = false);
    }
  }

  String _formatDioError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'انتهت الجلسة. فضلاً سجّل الدخول مرة أخرى.';
      }

      final data = error.response?.data;
      if (data is String) {
        final msg = data.trim();
        if (msg.isNotEmpty) return msg;
      }

      if (data is Map) {
        final map = data.map((k, v) => MapEntry(k.toString(), v));
        final detail = map['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }

        final parts = <String>[];
        for (final entry in map.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is List) {
            final msgs = value
                .map((e) => e?.toString().trim())
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .toList();
            if (msgs.isNotEmpty) parts.add('$key: ${msgs.join('، ')}');
          } else if (value is String && value.trim().isNotEmpty) {
            parts.add('$key: ${value.trim()}');
          }
        }
        if (parts.isNotEmpty) return parts.join('\n');
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'تعذر الاتصال بالخادم حالياً. حاول مرة أخرى.';
        case DioExceptionType.connectionError:
          return 'لا يوجد اتصال بالإنترنت حالياً.';
        default:
          break;
      }

      if (status != null) {
        return 'تعذر حفظ الموقع حالياً (HTTP $status).';
      }
    }
    return 'تعذر حفظ الموقع حالياً.';
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
          "حدد اللغات التي يمكنك التعامل بها وموقعك الجغرافي.",
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
              "اختيار اللغات وتحديد موقعك الجغرافي يساعد في عرضك للعملاء المناسبين أكثر.",
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.4,
                color: Colors.black87,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          icon: FontAwesomeIcons.language,
          title: 'اللغة',
          subtitle: 'اختر اللغات التي يمكنك التواصل بها مع العملاء.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: predefinedLanguages.map((lang) {
                  final selected = selectedLanguages.contains(lang);
                  return FilterChip(
                    label: Text(lang, style: const TextStyle(fontFamily: 'Cairo')),
                    selected: selected,
                    selectedColor: Colors.deepPurple.withOpacity(0.14),
                    checkmarkColor: Colors.deepPurple,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          if (!selectedLanguages.contains(lang)) {
                            selectedLanguages.add(lang);
                          }
                        } else {
                          selectedLanguages.remove(lang);
                        }
                      });
                      _scheduleDraftSave();
                      _updateSectionDone();
                    },
                  );
                }).toList(),
              ),
              if (selectedLanguages.contains('أخرى')) _buildCustomLanguageInput(),
              if (customLanguages.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: customLanguages.map((lang) {
                    return Chip(
                      label: Text(lang, style: const TextStyle(fontFamily: 'Cairo')),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() => customLanguages.remove(lang));
                        _scheduleDraftSave();
                        _updateSectionDone();
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        _sectionCard(
          icon: FontAwesomeIcons.mapMarkedAlt,
          title: 'الموقع الجغرافي',
          subtitle:
              'حدد موقعك الجغرافي الدقيق. سيتم محاولة تحديد موقعك تلقائياً عند فتح الخريطة ويمكنك تحريك الدبوس.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _savingLocation ? null : _pickMapLocation,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        _savingLocation ? 'جارٍ الحفظ…' : 'تحديد الموقع على الخريطة',
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_loadingFromBackend)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: locationController,
                readOnly: true,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'لم يتم تحديد موقع بعد',
                  hintStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 1.4,
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
