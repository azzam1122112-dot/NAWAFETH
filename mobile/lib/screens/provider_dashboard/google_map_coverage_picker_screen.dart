import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  GoogleMapController? _controller;

  LatLng _center = _defaultCenter;
  int _radiusKm = 10;

  LatLngBounds? _cityBounds;
  bool _resolvingCity = false;

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initialRadiusKm;
    _center = widget.initialCenter ?? _defaultCenter;
    _resolveCityIfNeeded();
  }

  @override
  void dispose() {
    super.dispose();
  }

  static const double _cityLockKm = 35;

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

    if (widget.initialCenter != null) {
      // If user already has a saved center, don't override.
      _cityBounds = _boundsAroundKm(widget.initialCenter!, _cityLockKm);
      return;
    }

    setState(() => _resolvingCity = true);
    try {
      final center = _lookupCityCenter(city) ?? await _geocodeCityBestEffort(city);
      if (center == null) return;
      _cityBounds = _boundsAroundKm(center, _cityLockKm);
      _center = center;

      if (!mounted) return;
      setState(() {});
      await _animateTo(center);
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) setState(() => _resolvingCity = false);
    }
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

  Future<void> _animateTo(LatLng target) async {
    final c = _controller;
    if (c == null) return;
    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 12.8),
      ),
    );
  }

  void _setCenter(LatLng p) {
    setState(() => _center = p);
  }

  void _setRadiusKm(int km) {
    setState(() => _radiusKm = km);
  }

  Set<Marker> get _markers {
    return {
      Marker(
        markerId: const MarkerId('center'),
        position: _center,
        draggable: true,
        onDragEnd: _setCenter,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      )
    };
  }

  Set<Circle> get _circles {
    return {
      Circle(
        circleId: const CircleId('coverage'),
        center: _center,
        radius: _radiusKm * 1000.0,
        fillColor: _mainColor.withAlpha(36),
        strokeColor: _mainColor.withAlpha(230),
        strokeWidth: 2,
      )
    };
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
    final bounds = _cityBounds;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: _center, zoom: 12.8),
                onMapCreated: (c) {
                  _controller = c;
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                buildingsEnabled: true,
                compassEnabled: false,
                mapToolbarEnabled: false,
                markers: _markers,
                circles: _circles,
                cameraTargetBounds:
                    bounds != null ? CameraTargetBounds(bounds) : CameraTargetBounds.unbounded,
                onTap: _setCenter,
              ),
              if (_resolvingCity)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
