import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/providers_api.dart';
import '../constants/colors.dart';
import '../utils/auth_guard.dart';
import '../utils/whatsapp_helper.dart';
import '../services/messaging_api.dart';
import '../services/chat_nav.dart';
import '../services/session_storage.dart';
import 'provider_profile_screen.dart';
import 'service_request_form_screen.dart';

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
  int? _selectedProviderId;
  int? _busyProviderId;
  String? _myPhone;

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

  String? _asNonEmptyString(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  String _formatPhoneE164(String rawPhone) {
    final phone = rawPhone.replaceAll(RegExp(r'\s+'), '');
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('05') && phone.length == 10) return '+966${phone.substring(1)}';
    if (phone.startsWith('5') && phone.length == 9) return '+966$phone';
    return phone;
  }

  String _buildWhatsAppMessage(String providerName) {
    final buffer = StringBuffer();
    buffer.writeln('@${providerName.replaceAll(' ', '')}');
    buffer.writeln('السلام عليكم');
    buffer.writeln('أنا عميل في منصة (نوافذ)');
    buffer.writeln('أتواصل معك بخصوص طلب عاجل');
    buffer.writeln('المدينة: ${widget.city}');
    buffer.writeln('التصنيف: ${widget.subcategoryName ?? 'خدمة عامة'}');
    return buffer.toString().trim();
  }

  Future<void> _openPhoneCall(String rawPhone) async {
    final e164 = _formatPhoneE164(rawPhone);
    final uri = Uri(scheme: 'tel', path: e164);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الاتصال')),
    );
  }

  Future<void> _openWhatsApp({
    required String providerName,
    required String rawPhone,
  }) async {
    await WhatsAppHelper.open(
      context: context,
      contact: rawPhone,
      message: _buildWhatsAppMessage(providerName),
    );
  }

  Future<void> _openInAppChat({
    required String providerName,
    required String providerId,
  }) async {
    if (!await checkAuth(context)) return;
    if (!mounted) return;

    try {
      final api = MessagingApi();
      final thread = await api.getOrCreateDirectThread(int.parse(providerId));
      final threadId = thread['id'] as int?;
      if (threadId == null) throw Exception('no thread id');
      if (!mounted) return;
      ChatNav.openThread(
        context,
        threadId: threadId,
        name: providerName,
        isDirect: true,
        peerId: providerId,
        peerName: providerName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المحادثة. حاول مرة أخرى.')),
      );
    }
  }

  Future<void> _openProviderProfile(Map<String, dynamic> provider) async {
    final id = provider['id']?.toString();
    if (id == null || id.isEmpty) return;
    final name = _nameOf(provider);
    final imageUrl = _asNonEmptyString(provider['image_url']);
    final phone = _asNonEmptyString(provider['phone']);
    final lat = _asDouble(provider['lat']);
    final lng = _asDouble(provider['lng']);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderProfileScreen(
          providerId: id,
          providerName: name,
          providerImage: imageUrl,
          providerPhone: phone,
          providerLat: lat,
          providerLng: lng,
        ),
      ),
    );
  }

  void _selectProvider(Map<String, dynamic> provider) {
    final providerId = (provider['id'] as num?)?.toInt();
    final lat = _asDouble(provider['lat']);
    final lng = _asDouble(provider['lng']);
    if (providerId == null) return;
    setState(() => _selectedProviderId = providerId);
    if (lat != null && lng != null) {
      _mapController.move(LatLng(lat, lng), 14.5);
    }
  }

  Future<void> _requestServiceFromProvider(Map<String, dynamic> provider) async {
    final providerId = (provider['id'] as num?)?.toInt();
    if (providerId == null || _busyProviderId != null) return;
    setState(() => _busyProviderId = providerId);
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ServiceRequestFormScreen(
            providerName: _nameOf(provider),
            providerId: providerId.toString(),
            initialSubcategoryId: widget.subcategoryId,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyProviderId = null);
    }
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
        _selectedProviderId = data.isEmpty
            ? null
            : ((data.first['id'] as num?)?.toInt());
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
    _loadMyPhone();
    _load();
  }

  Future<void> _loadMyPhone() async {
    final phone = await const SessionStorage().readPhone();
    if (!mounted) return;
    setState(() => _myPhone = phone?.trim());
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
                              final providerId = (provider['id'] as num?)?.toInt();
                              final isSelected =
                                  providerId != null && providerId == _selectedProviderId;
                              return Marker(
                                point: LatLng(lat, lng),
                                width: 42,
                                height: 42,
                                child: GestureDetector(
                                  onTap: () => _selectProvider(provider),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: isSelected
                                        ? const Color(0xFF6A1B9A)
                                        : const Color(0xFFE53935),
                                    size: isSelected ? 42 : 38,
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ],
                  ),
                  DraggableScrollableSheet(
                    initialChildSize: 0.30,
                    minChildSize: 0.22,
                    maxChildSize: 0.80,
                    builder: (context, scrollController) {
                      final selected = _providers.cast<Map<String, dynamic>>().firstWhere(
                            (p) => ((p['id'] as num?)?.toInt()) == _selectedProviderId,
                            orElse: () => _providers.first,
                          );
                      final selectedName = _nameOf(selected);
                      final selectedCity = (selected['city'] ?? '').toString();
                      final phone = _asNonEmptyString(selected['phone']);
                      final whatsapp = _asNonEmptyString(selected['whatsapp']);
                      final contact = whatsapp ?? phone;
                      final canCall = phone != null;
                      final canWhatsApp = contact != null || (_myPhone?.isNotEmpty == true);
                      final providerId = (selected['id'] as num?)?.toInt();
                      final isBusy = providerId != null && _busyProviderId == providerId;

                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              width: 44,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  Text(
                                    'العدد المتاح حالياً: ${_providers.length} مزود',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E5F5),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'المزود المحدد',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6A1B9A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F7FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE3D8FF)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _openProviderProfile(selected),
                                          borderRadius: BorderRadius.circular(999),
                                          child: CircleAvatar(
                                            radius: 21,
                                            backgroundColor: const Color(0xFFEDE7F6),
                                            child: Text(
                                              selectedName.isEmpty ? 'م' : selectedName.substring(0, 1),
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF6A1B9A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _openProviderProfile(selected),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  selectedName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  selectedCity.isEmpty ? widget.city : selectedCity,
                                                  style: const TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'وسيلة الاتصال: ${contact ?? 'غير متاحة'}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 11.5,
                                                    color: Colors.black45,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _QuickActionButton(
                                          label: 'اتصال',
                                          icon: Icons.call_rounded,
                                          color: Colors.blue,
                                          onTap: canCall ? () => _openPhoneCall(phone!) : null,
                                        ),
                                        _QuickActionButton(
                                          label: 'واتساب',
                                          iconData: FontAwesomeIcons.whatsapp,
                                          color: const Color(0xFF25D366),
                                          onTap: canWhatsApp
                                              ? () => _openWhatsApp(
                                                    providerName: selectedName,
                                                    rawPhone: contact ?? '',
                                                  )
                                              : null,
                                        ),
                                        _QuickActionButton(
                                          label: 'محادثة',
                                          icon: Icons.chat_bubble_outline_rounded,
                                          color: const Color(0xFF6A1B9A),
                                          onTap: providerId == null
                                              ? null
                                              : () => _openInAppChat(
                                                    providerName: selectedName,
                                                    providerId: providerId.toString(),
                                                  ),
                                        ),
                                        _QuickActionButton(
                                          label: isBusy ? 'جارٍ...' : 'اطلب خدمة',
                                          icon: Icons.add_task_rounded,
                                          color: const Color(0xFFE53935),
                                          onTap: (providerId == null || isBusy)
                                              ? null
                                              : () => _requestServiceFromProvider(selected),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                                itemCount: _providers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final p = _providers[index];
                                  final pid = (p['id'] as num?)?.toInt();
                                  final isSelected = pid != null && pid == _selectedProviderId;
                                  return Material(
                                    color: isSelected ? const Color(0xFFF3E5F5) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _selectProvider(p),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: isSelected
                                                  ? const Color(0xFF6A1B9A)
                                                  : const Color(0xFFFFE5E5),
                                              child: Icon(
                                                Icons.person,
                                                size: 16,
                                                color: isSelected ? Colors.white : const Color(0xFFE53935),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _nameOf(p),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 13.5,
                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              (p['city'] ?? '').toString(),
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11.5,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? iconData;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.label,
    this.icon,
    this.iconData,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (disabled ? Colors.grey : color).withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (disabled ? Colors.grey : color).withOpacity(0.26),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData ?? icon, size: 15.5, color: disabled ? Colors.grey : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: disabled ? Colors.grey : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
