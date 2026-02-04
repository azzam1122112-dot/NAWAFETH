import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/providers_api.dart';
import '../services/marketplace_api.dart';

class ProviderMapSelectionScreen extends StatefulWidget {
  final int subcategoryId;
  final String title;
  final String description;
  final String city;

  const ProviderMapSelectionScreen({
    super.key,
    required this.subcategoryId,
    required this.title,
    required this.description,
    required this.city,
  });

  @override
  State<ProviderMapSelectionScreen> createState() =>
      _ProviderMapSelectionScreenState();
}

class _ProviderMapSelectionScreenState
    extends State<ProviderMapSelectionScreen> {
  final MapController _mapController = MapController();
  List<dynamic> _providers = [];
  bool _loading = true;
  String? _error;
  List<int> _selectedProviderIds = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final providersApi = ProvidersApi();
      final providers = await providersApi.getProvidersForMap(
        subcategoryId: widget.subcategoryId,
      );
      setState(() {
        _providers = providers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleProvider(int providerId) {
    setState(() {
      if (_selectedProviderIds.contains(providerId)) {
        _selectedProviderIds.remove(providerId);
      } else {
        _selectedProviderIds.add(providerId);
      }
    });
  }

  Future<void> _submitToSelectedProviders() async {
    if (_selectedProviderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر مزود خدمة واحد على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final marketplaceApi = MarketplaceApi();
      
      // إرسال طلب لكل مزود مختار
      int successCount = 0;
      for (final providerId in _selectedProviderIds) {
        final success = await marketplaceApi.createRequest(
          subcategoryId: widget.subcategoryId,
          title: widget.title,
          description: widget.description,
          requestType: 'urgent',
          city: widget.city,
          providerId: providerId,
        );
        if (success) successCount++;
      }

      if (!mounted) return;

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال الطلب لـ $successCount مزود'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إرسال الطلبات، حاول مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _submitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إرسال الطلب: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // الموقع الافتراضي (الرياض)
    final defaultCenter = LatLng(24.7136, 46.6753);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'اختر من الخريطة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'اختر المزودين القريبين منك',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        toolbarHeight: 80,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadProviders,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : _providers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off,
                                size: 60,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'لا يوجد مزودين في هذه المنطقة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _providers.isNotEmpty &&
                                    _providers[0]['lat'] != null &&
                                    _providers[0]['lng'] != null
                                ? LatLng(
                                    _providers[0]['lat'],
                                    _providers[0]['lng'],
                                  )
                                : defaultCenter,
                            initialZoom: 12.0,
                            minZoom: 5.0,
                            maxZoom: 18.0,
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
                                  .where((p) =>
                                      p['lat'] != null &&
                                      p['lng'] != null)
                                  .map((provider) {
                                final isSelected = _selectedProviderIds
                                    .contains(provider['id']);
                                return Marker(
                                  point: LatLng(
                                    provider['lat'],
                                    provider['lng'],
                                  ),
                                  width: 50,
                                  height: 50,
                                  child: GestureDetector(
                                    onTap: () => _toggleProvider(provider['id']),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? const Color(0xFFFF6B6B)
                                            : Colors.blue,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.person_pin,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        // قائمة المزودين في الأسفل
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 250),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Handle
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                // عدد المختارين
                                Container(
                                  margin: const EdgeInsets.all(16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B6B),
                                        Color(0xFFFF8E53)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'المزودين المختارين: ${_selectedProviderIds.length}',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: _submitting
                                            ? null
                                            : _submitToSelectedProviders,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor:
                                              const Color(0xFFFF6B6B),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: _submitting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.send_rounded,
                                                size: 18),
                                        label: Text(
                                          _submitting ? 'جاري الإرسال...' : 'إرسال',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // قائمة المزودين
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    itemCount: _providers.length,
                                    itemBuilder: (context, index) {
                                      final provider = _providers[index];
                                      final isSelected = _selectedProviderIds
                                          .contains(provider['id']);
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          onTap: () =>
                                              _toggleProvider(provider['id']),
                                          leading: CircleAvatar(
                                            backgroundColor: isSelected
                                                ? const Color(0xFFFF6B6B)
                                                : Colors.blue,
                                            child: Icon(
                                              isSelected
                                                  ? Icons.check
                                                  : Icons.person,
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Text(
                                            provider['display_name'] ??
                                                'مزود خدمة',
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            provider['city'] ??
                                                widget.city,
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFFFF6B6B)
                                                  : Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              isSelected ? 'مختار' : 'اختر',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ),
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
    );
  }
}
