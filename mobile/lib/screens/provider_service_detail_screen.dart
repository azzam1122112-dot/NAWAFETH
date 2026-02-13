import 'package:flutter/material.dart';

import '../models/provider_service.dart';
import '../services/providers_api.dart';
import '../services/reviews_api.dart';
import '../utils/auth_guard.dart';
import 'service_request_form_screen.dart';

class ProviderServiceDetailScreen extends StatefulWidget {
  final ProviderService service;
  final String providerName;
  final String providerId;

  const ProviderServiceDetailScreen({
    super.key,
    required this.service,
    required this.providerName,
    required this.providerId,
  });

  @override
  State<ProviderServiceDetailScreen> createState() => _ProviderServiceDetailScreenState();
}

class _ProviderServiceDetailScreenState extends State<ProviderServiceDetailScreen> {
  final ProvidersApi _providersApi = ProvidersApi();
  final ReviewsApi _reviewsApi = ReviewsApi();

  bool _loadingReviews = false;
  bool _loadingLike = false;
  bool _isLiked = false;
  int _likesCount = 0;
  double _ratingAvg = 0;
  int _ratingCount = 0;
  List<Map<String, dynamic>> _reviews = const [];

  int? get _providerId => int.tryParse(widget.providerId.trim());

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadLikesState(),
      _loadReviews(),
    ]);
  }

  Future<void> _loadLikesState() async {
    final providerId = _providerId;
    if (providerId == null) return;
    try {
      final liked = await _providersApi.getMyLikedProviders();
      if (!mounted) return;
      setState(() {
        _isLiked = liked.any((p) => p.id == providerId);
      });
    } catch (_) {}
  }

  Future<void> _loadReviews() async {
    final providerId = _providerId;
    if (providerId == null) return;

    setState(() => _loadingReviews = true);
    try {
      final rating = await _reviewsApi.getProviderRatingSummary(providerId);
      final reviews = await _reviewsApi.getProviderReviews(providerId);
      if (!mounted) return;
      setState(() {
        _ratingAvg = _asDouble(rating['rating_avg']);
        _ratingCount = _asInt(rating['rating_count']) ?? 0;
        _likesCount = _asInt(rating['likes_count']) ?? _likesCount;
        _reviews = reviews;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviews = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingReviews = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    final providerId = _providerId;
    if (providerId == null || _loadingLike) return;
    if (!await checkAuth(context)) return;

    setState(() => _loadingLike = true);
    final next = !_isLiked;
    final ok = next
        ? await _providersApi.likeProvider(providerId)
        : await _providersApi.unlikeProvider(providerId);

    if (!mounted) return;
    setState(() {
      _loadingLike = false;
      if (ok) {
        _isLiked = next;
        _likesCount = (_likesCount + (next ? 1 : -1)).clamp(0, 1 << 31);
      }
    });

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث الإعجاب حالياً.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Colors.deepPurple;
    final sub = widget.service.subcategory;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
          title: const Text('تفاصيل الخدمة', style: TextStyle(fontFamily: 'Cairo')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.service.title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.providerName,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.sell_outlined, size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        widget.service.priceText(),
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
                      const SizedBox(width: 6),
                      Text(
                        '${_ratingAvg.toStringAsFixed(1)} ($_ratingCount)',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _loadingLike ? null : _toggleLike,
                        icon: Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18),
                        label: Text('$_likesCount'),
                      ),
                    ],
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((sub.categoryName ?? '').trim().isNotEmpty) _chip(sub.categoryName!.trim()),
                        if (sub.name.trim().isNotEmpty) _chip(sub.name.trim()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الوصف',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.service.description.trim().isEmpty ? 'لا يوجد وصف لهذه الخدمة.' : widget.service.description,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'التعليقات والتقييمات',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_loadingReviews)
                    const Center(child: CircularProgressIndicator())
                  else if (_reviews.isEmpty)
                    const Text(
                      'لا توجد تعليقات حالياً.',
                      style: TextStyle(fontFamily: 'Cairo'),
                    )
                  else
                    ..._reviews.take(5).map((r) {
                      final comment = (r['comment'] ?? '').toString().trim();
                      final rating = _asDouble(r['rating']);
                      final by = (r['client_name'] ?? r['client_phone'] ?? 'مستخدم').toString();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  by,
                                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(fontFamily: 'Cairo'),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                              ],
                            ),
                            if (comment.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(comment, style: const TextStyle(fontFamily: 'Cairo')),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!await checkFullClient(context)) return;
                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceRequestFormScreen(
                        providerName: widget.providerName,
                        providerId: widget.providerId,
                        initialSubcategoryId: widget.service.subcategory?.id,
                        initialTitle: widget.service.title,
                        initialDetails: widget.service.description,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('اطلب هذه الخدمة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
    );
  }
}
