import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/providers_api.dart';
import 'google_map_coverage_picker_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final Color mainColor = Colors.deepPurple;

  static const double _cityLockKm = 35; // Keep the map focused around the city.

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

  String _providerType = 'individual';
  bool _acceptsUrgent = false;

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _yearsExperienceController = TextEditingController();

  int _coverageRadiusKm = 10;
  double? _lat;
  double? _lng;

  LatLng? _cityCenter;
  LatLngBounds? _cityBounds;
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

  LatLngBounds _boundsAroundKm(LatLng center, double km) {
    final dLat = km / 111.0;
    final latRad = center.latitude * (math.pi / 180.0);
    final cosLat = math.cos(latRad).abs().clamp(0.2, 1.0);
    final dLng = km / (111.0 * cosLat);
    return LatLngBounds(
      southwest: LatLng(center.latitude - dLat, center.longitude - dLng),
      northeast: LatLng(center.latitude + dLat, center.longitude + dLng),
    );
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
        // Continue.
      }
    }
    return null;
  }

  Future<void> _resolveCityCenter() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    // If user already selected a precise point, keep it.
    if (_lat != null && _lng != null) {
      final c = LatLng(_lat!, _lng!);
      setState(() {
        _cityCenter = c;
        _cityBounds = _boundsAroundKm(c, _cityLockKm);
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
        _cityBounds = _boundsAroundKm(c, _cityLockKm);
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

      final radiusRaw = (json['coverage_radius_km'] ?? '').toString();
      final radius = int.tryParse(radiusRaw.trim());
      if (radius != null && radius > 0) _coverageRadiusKm = radius;

      final latRaw = (json['lat'] ?? '').toString().trim();
      final lngRaw = (json['lng'] ?? '').toString().trim();
      _lat = double.tryParse(latRaw);
      _lng = double.tryParse(lngRaw);

      if (_lat != null && _lng != null) {
        final c = LatLng(_lat!, _lng!);
        _cityCenter = c;
        _cityBounds = _boundsAroundKm(c, _cityLockKm);
      }
    });

    // Resolve city center for map preview if no lat/lng.
    await _resolveCityCenter();
  }

  int? _parseInt(String s) {
    final v = int.tryParse(s.trim());
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

    patch['coverage_radius_km'] = _coverageRadiusKm;
    if (_lat != null) patch['lat'] = _lat;
    if (_lng != null) patch['lng'] = _lng;

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

  Future<void> _pickCoverageOnMap() async {
    final city = _cityController.text.trim();
    final LatLng? initialCenter =
        (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : null;

    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => GoogleMapCoveragePickerScreen(
              city: city.isEmpty ? null : city,
              initialCenter: initialCenter,
              initialRadiusKm: _coverageRadiusKm,
            ),
      ),
    );

    if (res == null || !mounted) return;
    final lat = res['lat'];
    final lng = res['lng'];
    final radius = res['coverage_radius_km'];

    setState(() {
      if (lat is num) _lat = lat.toDouble();
      if (lng is num) _lng = lng.toDouble();
      if (radius is int) _coverageRadiusKm = radius;
      if (_lat != null && _lng != null) {
        final c = LatLng(_lat!, _lng!);
        _cityCenter = c;
        _cityBounds = _boundsAroundKm(c, _cityLockKm);
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
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
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

  Widget _coverageCard() {
    final center = (_lat != null && _lng != null)
        ? LatLng(_lat!, _lng!)
        : (_cityCenter ?? const LatLng(24.7136, 46.6753));
    final bounds = _cityBounds;

    return _sectionCard(
      title: 'نطاق التغطية',
      icon: Icons.radar,
      subtitle:
          'حدد مركز تغطيتك على خريطة Google واختر نصف القطر (كم). إذا كانت المدينة مكتوبة (مثلاً: المدينة المنورة) سيتم تركيز الخريطة عليها تلقائياً.',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 190,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: center, zoom: 12.8),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    buildingsEnabled: true,
                    markers: {
                      Marker(
                        markerId: const MarkerId('center'),
                        position: center,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueViolet,
                        ),
                      ),
                    },
                    circles: {
                      Circle(
                        circleId: const CircleId('coverage'),
                        center: center,
                        radius: _coverageRadiusKm * 1000.0,
                        fillColor: mainColor.withAlpha(36),
                        strokeColor: mainColor.withAlpha(230),
                        strokeWidth: 2,
                      )
                    },
                    cameraTargetBounds: bounds != null
                        ? CameraTargetBounds(bounds)
                        : CameraTargetBounds.unbounded,
                    onTap: (_) {
                      // Preview only
                    },
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
                              style:
                                  TextStyle(fontFamily: 'Cairo', fontSize: 12),
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
                child: OutlinedButton.icon(
                  onPressed: _pickCoverageOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text(
                    'تحديد على الخريطة',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mainColor,
                    side: BorderSide(color: mainColor.withAlpha(128)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: mainColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: mainColor.withAlpha(51)),
                ),
                child: Text(
                  '$_coverageRadiusKm كم',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_lat != null && _lng != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'المركز: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.black54,
                ),
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4FC),
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
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                              child:
                                  Text('فرد', style: TextStyle(fontFamily: 'Cairo')),
                            ),
                            DropdownMenuItem(
                              value: 'company',
                              child:
                                  Text('منشأة', style: TextStyle(fontFamily: 'Cairo')),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _providerType = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        _field(label: 'اسم الصفحة', controller: _displayNameController),
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
                  _coverageCard(),
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
