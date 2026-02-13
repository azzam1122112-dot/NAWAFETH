import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:latlong2/latlong.dart';

import '../../services/providers_api.dart';
import 'google_map_location_picker_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final Color mainColor = const Color(0xFF00695C);
  final Color accentColor = const Color(0xFF009688);

  static const Map<String, LatLng> _knownSaudiCityCenters = {
    'المدينة المنورة': LatLng(24.5246542, 39.5691841),
    'المدينة المنوره': LatLng(24.5246542, 39.5691841),
    'المدينة': LatLng(24.5246542, 39.5691841),
    'مكة المكرمة': LatLng(21.3890824, 39.8579118),
    'مكة': LatLng(21.3890824, 39.8579118),
    'مكه': LatLng(21.3890824, 39.8579118),
    'الرياض': LatLng(24.7135517, 46.6752957),
    'جدة': LatLng(21.543333, 39.172778),
    'الدمام': LatLng(26.4206828, 50.0887943),
    'الخبر': LatLng(26.2172, 50.1971),
    'الطائف': LatLng(21.27028, 40.41583),
  };

  bool _loading = true;
  bool _saving = false;
  DateTime? _lastSavedAt;

  String _providerType = 'individual';
  bool _acceptsUrgent = false;

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _yearsExperienceController = TextEditingController();

  double? _lat;
  double? _lng;

  LatLng? _cityCenter;
  bool _resolvingCity = false;
  Timer? _cityDebounce;

  @override
  void initState() {
    super.initState();
    _cityController.addListener(_onCityChanged);
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _yearsExperienceController.dispose();
    _cityDebounce?.cancel();
    super.dispose();
  }

  void _onCityChanged() {
    _cityDebounce?.cancel();
    _cityDebounce = Timer(const Duration(milliseconds: 550), () {
      _resolveCityCenter();
    });
  }

  LatLng? _lookupCityCenter(String rawCity) {
    final city = rawCity.trim();
    if (city.isEmpty) return null;

    final direct = _knownSaudiCityCenters[city];
    if (direct != null) return direct;

    for (final entry in _knownSaudiCityCenters.entries) {
      if (city.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Future<LatLng?> _geocodeCityBestEffort(String city) async {
    final queries = <String>[
      city,
      '$city، السعودية',
      '$city, السعودية',
      '$city, المملكة العربية السعودية',
      '$city, Saudi Arabia',
    ];

    for (final q in queries) {
      try {
        final results = await geocoding
            .locationFromAddress(q)
            .timeout(const Duration(seconds: 6));
        if (results.isEmpty) continue;
        final first = results.first;
        return LatLng(first.latitude, first.longitude);
      } catch (_) {
        // Best-effort.
      }
    }
    return null;
  }

  Future<void> _resolveCityCenter() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    if (_lat != null && _lng != null) {
      final c = LatLng(_lat!, _lng!);
      setState(() {
        _cityCenter = c;
      });
      return;
    }

    setState(() => _resolvingCity = true);
    try {
      final c = _lookupCityCenter(city) ?? await _geocodeCityBestEffort(city);
      if (c == null) return;
      if (!mounted) return;
      setState(() {
        _cityCenter = c;
      });
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) setState(() => _resolvingCity = false);
    }
  }

  Future<void> _load() async {
    final json = await ProvidersApi().getMyProviderProfile();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (json == null) return;
      _applyProfile(json);
    });

    await _resolveCityCenter();
  }

  void _applyProfile(Map<String, dynamic> json) {
    void setText(TextEditingController c, dynamic v) {
      c.text = (v ?? '').toString();
    }

    _providerType = (json['provider_type'] ?? 'individual').toString();
    _acceptsUrgent = json['accepts_urgent'] == true;

    setText(_displayNameController, json['display_name']);
    setText(_bioController, json['bio']);
    setText(_cityController, json['city']);
    setText(_yearsExperienceController, json['years_experience']);

    double? asDouble(dynamic v) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString().trim());
    }

    _lat = asDouble(json['lat']);
    _lng = asDouble(json['lng']);

    if (_lat != null && _lng != null) {
      _cityCenter = LatLng(_lat!, _lng!);
    }
  }

  int? _parseInt(String s) {
    return int.tryParse(s.trim());
  }

  String _formatDioError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'انتهت الجلسة. فضلاً سجّل الدخول مرة أخرى.';
      }

      final data = error.response?.data;
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
        default:
          break;
      }
    }

    return 'تعذر حفظ البيانات حالياً.';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final displayName = _displayNameController.text.trim();
    final city = _cityController.text.trim();
    final bio = _bioController.text.trim();

    if (displayName.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فضلاً اكتب اسم العرض.')),
      );
      return;
    }

    if (city.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فضلاً اختر المدينة.')),
      );
      return;
    }

    final patch = <String, dynamic>{
      'provider_type': _providerType,
      'display_name': displayName,
      'accepts_urgent': _acceptsUrgent,
      'city': city,
    };

    // Avoid sending empty strings (common source of backend validation errors).
    if (bio.isNotEmpty) patch['bio'] = bio;

    final yearsRaw = _yearsExperienceController.text.trim();
    if (yearsRaw.isNotEmpty) {
      final years = _parseInt(yearsRaw);
      if (years == null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('سنوات الخبرة يجب أن تكون رقم.')),
        );
        return;
      }
      patch['years_experience'] = years;
    }

    if (_lat != null) patch['lat'] = _lat;
    if (_lng != null) patch['lng'] = _lng;

    try {
      final updated = await ProvidersApi().updateMyProviderProfile(patch);
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (updated != null) {
          _applyProfile(updated);
          _lastSavedAt = DateTime.now();
        }
      });

      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ البيانات حالياً.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ البيانات بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatDioError(e))),
      );
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: mainColor.withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: mainColor.withValues(alpha: 0.50), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF7FAF9),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _pickGeoLocationOnMap() async {
    final city = _cityController.text.trim();
    final LatLng? initialCenter =
        (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : null;

    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => GoogleMapLocationPickerScreen(
          city: city.isEmpty ? null : city,
          initialCenter: initialCenter,
        ),
      ),
    );

    if (res == null || !mounted) return;
    final lat = res['lat'];
    final lng = res['lng'];

    setState(() {
      if (lat is num) _lat = lat.toDouble();
      if (lng is num) _lng = lng.toDouble();
      if (_lat != null && _lng != null) {
        final c = LatLng(_lat!, _lng!);
        _cityCenter = c;
      }
    });
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: mainColor),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
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

  Widget _geoLocationCard() {
    final center = (_lat != null && _lng != null)
        ? LatLng(_lat!, _lng!)
        : (_cityCenter ?? const LatLng(24.7136, 46.6753));

    return _sectionCard(
      title: 'الموقع الجغرافي',
      icon: Icons.location_on_outlined,
      subtitle:
          'حدد موقعك الجغرافي الدقيق على خريطة Google. سيتم محاولة تحديد موقعك تلقائياً (GPS) عند فتح الخريطة، ويمكنك تحريك الدبوس ثم حفظه.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 190,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 12.8,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom |
                            InteractiveFlag.drag |
                            InteractiveFlag.doubleTapZoom |
                            InteractiveFlag.flingAnimation,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nawafeth.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.location_pin,
                              size: 44,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_resolvingCity)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'جارٍ تحديد المدينة…',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickGeoLocationOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text(
                    'تحديد الموقع على الخريطة',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: mainColor,
                    side: BorderSide(color: mainColor.withAlpha(128)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (_lat != null && _lng != null)
                ? 'الإحداثيات: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                : 'لم يتم تحديد موقع بعد.',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
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

  Widget _buildTopStatusCard() {
    final savedText = _lastSavedAt == null
        ? 'لم يتم الحفظ بعد'
        : 'آخر حفظ: ${_lastSavedAt!.hour.toString().padLeft(2, '0')}:${_lastSavedAt!.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mainColor, accentColor],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user_outlined, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملف المزود',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  savedText,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
        backgroundColor: const Color(0xFFF4F7F8),
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
                  _buildTopStatusCard(),
                  _sectionCard(
                    title: 'بيانات المزود',
                    icon: Icons.badge_outlined,
                    subtitle: 'عدّل بيانات صفحتك بشكل بسيط وواضح.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _providerType,
                          decoration: _inputDecoration('نوع الحساب'),
                          items: const [
                            DropdownMenuItem(
                              value: 'individual',
                              child: Text('فرد',
                                  style: TextStyle(fontFamily: 'Cairo')),
                            ),
                            DropdownMenuItem(
                              value: 'company',
                              child: Text('منشأة',
                                  style: TextStyle(fontFamily: 'Cairo')),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _providerType = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        _field(
                          label: 'اسم الصفحة',
                          controller: _displayNameController,
                        ),
                        _field(
                          label: 'نبذة مختصرة',
                          controller: _bioController,
                          maxLines: 3,
                        ),
                        _field(label: 'المدينة', controller: _cityController),
                        _field(
                          label: 'سنوات الخبرة',
                          controller: _yearsExperienceController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _acceptsUrgent,
                          onChanged: (v) => setState(() => _acceptsUrgent = v),
                          title: const Text(
                            'يدعم الطلبات المستعجلة',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _geoLocationCard(),
                  const SizedBox(height: 4),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      'حفظ التغييرات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
