import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GoogleMapLocationPickerScreen extends StatefulWidget {
  final String? city;
  final LatLng? initialCenter;

  const GoogleMapLocationPickerScreen({
    super.key,
    this.city,
    this.initialCenter,
  });

  @override
  State<GoogleMapLocationPickerScreen> createState() =>
      _GoogleMapLocationPickerScreenState();
}

class _GoogleMapLocationPickerScreenState
    extends State<GoogleMapLocationPickerScreen> {
  static const Color _mainColor = Colors.deepPurple;
  static const LatLng _defaultCenter = LatLng(24.7136, 46.6753); // Riyadh

  final MapController _mapController = MapController();
  LatLng _selected = _defaultCenter;
  double _zoom = 15.5;

  bool _loadingGps = false;
  bool _resolvingCity = false;

  Timer? _throttle;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter ?? _defaultCenter;

    // Auto-detect GPS only when no saved point exists.
    if (widget.initialCenter == null) {
      unawaited(_moveToCurrentLocationBestEffort());
    } else {
      unawaited(_resolveCityBestEffort());
    }
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  void _moveTo(LatLng target, {double? zoom}) {
    final z = zoom ?? _zoom;
    _zoom = z;
    _mapController.move(target, z);
  }

  Future<LatLng?> _tryGeocodeCity(String city) async {
    final q = city.trim();
    if (q.isEmpty) return null;

    final queries = <String>[
      q,
      '$q، السعودية',
      '$q, السعودية',
      '$q, المملكة العربية السعودية',
      '$q, Saudi Arabia',
    ];

    for (final query in queries) {
      try {
        final results = await geocoding
            .locationFromAddress(query)
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

  Future<LatLng?> _getCurrentLatLng() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );

    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _moveToCurrentLocationBestEffort() async {
    if (_loadingGps) return;
    setState(() => _loadingGps = true);

    try {
      final p = await _getCurrentLatLng();
      if (!mounted) return;
      if (p != null) {
        setState(() => _selected = p);
        _moveTo(p, zoom: 16.0);
        return;
      }
      await _resolveCityBestEffort();
    } catch (_) {
      await _resolveCityBestEffort();
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  Future<void> _resolveCityBestEffort() async {
    final city = widget.city?.trim();
    if (city == null || city.isEmpty) return;
    if (_resolvingCity) return;

    setState(() => _resolvingCity = true);
    try {
      final center = await _tryGeocodeCity(city);
      if (!mounted) return;
      if (center != null) {
        setState(() => _selected = center);
        _moveTo(center, zoom: 12.8);
      }
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) setState(() => _resolvingCity = false);
    }
  }

  Widget _pill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: child,
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
            'الموقع الجغرافي',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selected,
                            initialZoom: _zoom,
                            onPositionChanged: (pos, _) {
                              final center = pos.center;
                              final zoom = pos.zoom;

                              _throttle?.cancel();
                              _throttle = Timer(
                                const Duration(milliseconds: 80),
                                () {
                                  if (!mounted) return;
                                  setState(() {
                                    _selected = center;
                                    _zoom = zoom;
                                  });
                                },
                              );
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.nawafeth.app',
                            ),
                          ],
                        ),

                        // Center pin (works without draggable marker plugins).
                        const IgnorePointer(
                          child: Center(
                            child: Icon(
                              Icons.location_pin,
                              size: 44,
                              color: _mainColor,
                            ),
                          ),
                        ),

                        Positioned(
                          top: 12,
                          right: 12,
                          left: 12,
                          child: _pill(
                            child: Text(
                              'اسحب الخريطة لتحريك الدبوس ثم احفظ',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (_resolvingCity)
                          Positioned(
                            top: 58,
                            right: 12,
                            child: _pill(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'جارٍ تحديد المدينة…',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 14,
                          right: 14,
                          child: FloatingActionButton.extended(
                            heroTag: 'gps',
                            onPressed:
                                _loadingGps ? null : _moveToCurrentLocationBestEffort,
                            backgroundColor: Colors.white,
                            foregroundColor: _mainColor,
                            icon: _loadingGps
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: const Text(
                              'موقعي الحالي',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'الإحداثيات: ${_selected.latitude.toStringAsFixed(6)}, ${_selected.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop<Map<String, dynamic>>(context, {
                          'lat': _selected.latitude,
                          'lng': _selected.longitude,
                        });
                      },
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'حفظ الموقع',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mainColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
