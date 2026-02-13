import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/providers_api.dart';
import '../constants/colors.dart';

class UrgentProvidersMapScreen extends StatefulWidget {
  final int subcategoryId;
  final String city;
  final String? subcategoryName;

  const UrgentProvidersMapScreen({
    super.key,
    required this.subcategoryId,
    required this.city,
    this.subcategoryName,
  });

  @override
  State<UrgentProvidersMapScreen> createState() =>
      _UrgentProvidersMapScreenState();
}

class _UrgentProvidersMapScreenState extends State<UrgentProvidersMapScreen> {
  final MapController _mapController = MapController();
  final ProvidersApi _providersApi = ProvidersApi();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _providers = [];

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _nameOf(Map<String, dynamic> provider) {
    final s = provider['display_name']?.toString().trim();
    if (s == null || s.isEmpty) return 'مزود خدمة';
    return s;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _providersApi.getProvidersForMap(
        subcategoryId: widget.subcategoryId,
        city: widget.city,
        acceptsUrgentOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _providers = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'خريطة المزودين',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _load,
                  child: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final center = () {
      if (_providers.isNotEmpty) {
        final lat = _asDouble(_providers.first['lat']);
        final lng = _asDouble(_providers.first['lng']);
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
      return const LatLng(24.7136, 46.6753);
    }();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.deepPurple,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مزودو الطلبات العاجلة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
              Text(
                '${widget.city} • ${widget.subcategoryName ?? 'التصنيف المحدد'}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _providers.isEmpty
            ? const Center(
                child: Text(
                  'لا يوجد مزودون مفعّلون للعاجل في هذا النطاق حالياً',
                  style: TextStyle(fontFamily: 'Cairo'),
                  textAlign: TextAlign.center,
                ),
              )
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 12,
                      minZoom: 5,
                      maxZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.nawafeth.app',
                      ),
                      MarkerLayer(
                        markers: _providers
                            .where(
                              (p) =>
                                  _asDouble(p['lat']) != null &&
                                  _asDouble(p['lng']) != null,
                            )
                            .map((provider) {
                              final lat = _asDouble(provider['lat'])!;
                              final lng = _asDouble(provider['lng'])!;
                              return Marker(
                                point: LatLng(lat, lng),
                                width: 42,
                                height: 42,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFE53935),
                                  size: 40,
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Text(
                            'العدد المتاح حالياً: ${_providers.length} مزود',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _providers.length,
                              itemBuilder: (context, index) {
                                final provider = _providers[index];
                                final name = _nameOf(provider);
                                final city = provider['city']?.toString() ?? '';
                                return ListTile(
                                  dense: true,
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFFFE5E5),
                                    child: Icon(
                                      Icons.person,
                                      color: Color(0xFFE53935),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    city,
                                    style: const TextStyle(fontFamily: 'Cairo'),
                                  ),
                                  onTap: () {
                                    final lat = _asDouble(provider['lat']);
                                    final lng = _asDouble(provider['lng']);
                                    if (lat != null && lng != null) {
                                      _mapController.move(LatLng(lat, lng), 14);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
