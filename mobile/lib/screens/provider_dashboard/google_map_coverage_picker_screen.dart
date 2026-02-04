import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:latlong2/latlong.dart';

class GoogleMapCoveragePickerScreen extends StatefulWidget {
  final String? city;
  final LatLng? initialCenter;
  final int initialRadiusKm;

  const GoogleMapCoveragePickerScreen({
    super.key,
    this.city,
    this.initialCenter,
    required this.initialRadiusKm,
  });

  @override
  State<GoogleMapCoveragePickerScreen> createState() =>
      _GoogleMapCoveragePickerScreenState();
}

class _GoogleMapCoveragePickerScreenState
    extends State<GoogleMapCoveragePickerScreen> {
  static const Color _mainColor = Colors.deepPurple;
  static const LatLng _defaultCenter = LatLng(24.7136, 46.6753); // Riyadh

  final MapController _mapController = MapController();

  LatLng _center = _defaultCenter;
  int _radiusKm = 10;
  double _zoom = 12.8;

  bool _resolvingCity = false;
  Timer? _throttle;

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initialRadiusKm;
    _center = widget.initialCenter ?? _defaultCenter;

    if (widget.initialCenter == null) {
      unawaited(_resolveCityIfNeeded());
    }
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

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

  Future<void> _resolveCityIfNeeded() async {
    final city = (widget.city ?? '').trim();
    if (city.isEmpty) return;
    if (_resolvingCity) return;

    setState(() => _resolvingCity = true);
    try {
      final center = _lookupCityCenter(city) ?? await _geocodeCityBestEffort(city);
      if (!mounted) return;
      if (center == null) return;

      setState(() => _center = center);
      _moveTo(center, zoom: 12.8);
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) setState(() => _resolvingCity = false);
    }
  }

  void _moveTo(LatLng target, {double? zoom}) {
    final z = zoom ?? _zoom;
    _zoom = z;
    _mapController.move(target, z);
  }

  void _setCenter(LatLng p) {
    setState(() => _center = p);
    _throttle?.cancel();
    _throttle = Timer(const Duration(milliseconds: 50), () {
      _moveTo(_center);
    });
  }

  void _setRadiusKm(int km) {
    setState(() => _radiusKm = km);
  }

  void _confirm() {
    Navigator.pop<Map<String, dynamic>>(context, {
      'lat': _center.latitude,
      'lng': _center.longitude,
      'coverage_radius_km': _radiusKm,
    });
  }

  Widget _hintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _mainColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'اضغط على الخريطة لتحديد مركز تغطيتك، ثم عدّل نصف القطر ($_radiusKm كم).',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radiusControl() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: _mainColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'نطاق التغطية',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _mainColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _mainColor.withAlpha(64)),
                ),
                child: Text(
                  '$_radiusKm كم',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _mainColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            value: _radiusKm.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            label: '$_radiusKm',
            activeColor: _mainColor,
            onChanged: (v) => _setRadiusKm(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _map() {
    final radiusMeters = _radiusKm * 1000.0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: _zoom,
                  onTap: (tapPosition, point) => _setCenter(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.nawafeth.app',
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center,
                        radius: radiusMeters,
                        useRadiusInMeter: true,
                        color: _mainColor.withAlpha(36),
                        borderColor: _mainColor.withAlpha(230),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: _mainColor,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_resolvingCity)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4FC),
        appBar: AppBar(
          backgroundColor: _mainColor,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'نطاق التغطية',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: _confirm,
              child: const Text(
                'تأكيد',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _hintCard(),
            _radiusControl(),
            _map(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'تأكيد',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
