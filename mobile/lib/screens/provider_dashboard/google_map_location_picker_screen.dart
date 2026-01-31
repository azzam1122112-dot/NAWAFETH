import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  GoogleMapController? _controller;
  LatLng _selected = _defaultCenter;

  bool _loadingGps = false;
  bool _resolvingCity = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter ?? _defaultCenter;

    // Try to auto-detect the current location only when no saved point exists.
    if (widget.initialCenter == null) {
      unawaited(_moveToCurrentLocationBestEffort());
    } else {
      // Still try to resolve city bounds for a nicer initial zoom if needed.
      unawaited(_resolveCityBestEffort());
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _animateTo(LatLng target, {double zoom = 15.5}) async {
    final c = _controller;
    if (c == null) return;
    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ),
    );
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
        // Continue.
      }
    }

    return null;
  }

  Future<void> _resolveCityBestEffort() async {
    final city = (widget.city ?? '').trim();
    if (city.isEmpty) return;

    setState(() => _resolvingCity = true);
    try {
      final c = await _tryGeocodeCity(city);
      if (c == null) return;
      if (!mounted) return;

      // Only use city as a fallback when we have no selected point yet.
      if (widget.initialCenter == null) {
        setState(() => _selected = c);
      }

      await _animateTo(widget.initialCenter ?? c, zoom: 12.8);
    } catch (_) {
      // Best-effort.
    } finally {
      if (mounted) setState(() => _resolvingCity = false);
    }
  }

  Future<LatLng?> _getCurrentLatLng() async {
    // Permissions
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _moveToCurrentLocationBestEffort({bool showFeedback = false}) async {
    if (_loadingGps) return;
    setState(() => _loadingGps = true);

    try {
      final p = await _getCurrentLatLng();
      if (p == null) {
        if (!mounted) return;
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر الوصول للموقع. تأكد من تفعيل الصلاحية.'),
            ),
          );
        }
        await _resolveCityBestEffort();
        return;
      }

      if (!mounted) return;
      setState(() => _selected = p);
      await _animateTo(p, zoom: 16.0);
    } catch (_) {
      if (!mounted) return;
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد موقعك الحالي.')),
        );
      }
      await _resolveCityBestEffort();
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  void _setSelected(LatLng p) {
    setState(() => _selected = p);
  }

  Set<Marker> get _markers {
    return {
      Marker(
        markerId: const MarkerId('picked'),
        position: _selected,
        draggable: true,
        onDragEnd: _setSelected,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ),
    };
  }

  void _confirm() {
    Navigator.pop<Map<String, dynamic>>(context, {
      'lat': _selected.latitude,
      'lng': _selected.longitude,
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
          const Icon(Icons.my_location, color: _mainColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'سيتم تحديد موقعك تلقائياً إن أمكن. يمكنك الضغط على الخريطة أو سحب الدبوس لتعديل الموقع ثم حفظه.',
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
          actions: [
            TextButton(
              onPressed: _confirm,
              child: const Text(
                'حفظ',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _hintCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadingGps
                          ? null
                          : () => _moveToCurrentLocationBestEffort(
                                showFeedback: true,
                              ),
                      icon: _loadingGps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gps_fixed),
                      label: const Text(
                        'موقعي الحالي',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: _mainColor,
                        side: BorderSide(color: _mainColor.withAlpha(90)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_resolvingCity)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selected,
                      zoom: 15.0,
                    ),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: _markers,
                    onMapCreated: (c) {
                      _controller = c;
                      // Sync initial view.
                      unawaited(_animateTo(_selected, zoom: 15.0));
                    },
                    onTap: _setSelected,
                  ),
                ),
              ),
            ),
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
                        backgroundColor: Colors.white,
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
                        'حفظ الموقع',
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
