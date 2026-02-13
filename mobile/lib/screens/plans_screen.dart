import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/billing_api.dart';
import '../services/payment_checkout.dart';
import '../services/subscriptions_api.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final SubscriptionsApi _api = SubscriptionsApi();
  final BillingApi _billingApi = BillingApi();
  late Future<List<Map<String, dynamic>>> _plansFuture;
  final Set<int> _subscribingPlanIds = <int>{};

  @override
  void initState() {
    super.initState();
    _plansFuture = _api.getPlans();
  }

  Future<void> _reload() async {
    setState(() {
      _plansFuture = _api.getPlans();
    });
  }

  Future<void> _subscribe(Map<String, dynamic> plan) async {
    final planId = _asInt(plan['id']);
    if (planId == null || _subscribingPlanIds.contains(planId)) return;

    setState(() {
      _subscribingPlanIds.add(planId);
    });

    try {
      final sub = await _api.subscribe(planId);
      if (!mounted) return;

      final invoiceId = _asInt(sub['invoice']);
      if (invoiceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الاشتراك بنجاح، لكن رقم الفاتورة غير متوفر.')),
        );
        return;
      }

      await PaymentCheckout.initAndOpen(
        context: context,
        billingApi: _billingApi,
        invoiceId: invoiceId,
        idempotencyKey: 'subscription-plan-$planId-${DateTime.now().millisecondsSinceEpoch}',
        successMessage: 'تم إنشاء الاشتراك وفتح صفحة الدفع.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _extractMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تنفيذ الاشتراك حالياً.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _subscribingPlanIds.remove(planId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'الباقات المدفوعة',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _reload);
          }

          final plans = snapshot.data ?? const [];
          if (plans.isEmpty) {
            return _EmptyState(onRetry: _reload);
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final scheme = _colorScheme(index);

                final planId = _asInt(plan['id']);
                final isLoading = planId != null && _subscribingPlanIds.contains(planId);

                final title = (plan['title'] ?? plan['code'] ?? 'Plan').toString();
                final price = _formatPrice(plan['price'], period: plan['period']);
                final features = _featuresAsText(plan['features']);
                final highlight = index == 0 ? false : index == 1;

                return _planCard(
                  context,
                  name: title,
                  price: price,
                  features: features,
                  color1: scheme.$1,
                  color2: scheme.$2,
                  icon: scheme.$3,
                  highlight: highlight,
                  loading: isLoading,
                  onSubscribe: () => _subscribe(plan),
                );
              },
            ),
          );
        },
      ),
    );
  }

  (Color, Color, IconData) _colorScheme(int index) {
    switch (index % 3) {
      case 0:
        return (Colors.blue.shade400, Colors.blue.shade700, Icons.star_border);
      case 1:
        return (Colors.purple.shade400, Colors.deepPurple.shade700, Icons.workspace_premium);
      default:
        return (Colors.orange.shade400, Colors.deepOrange.shade700, Icons.verified);
    }
  }

  List<String> _featuresAsText(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const <String>[];
  }

  String _formatPrice(dynamic raw, {dynamic period}) {
    final price = raw?.toString() ?? '0';
    final p = (period ?? '').toString().toLowerCase();
    if (p == 'year') return '$price ر.س / سنة';
    if (p == 'month') return '$price ر.س / شهر';
    return '$price ر.س';
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      for (final v in data.values) {
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is List && v.isNotEmpty) {
          final first = v.first;
          if (first is String && first.trim().isNotEmpty) return first.trim();
        }
      }
    }
    return 'تعذر تنفيذ الاشتراك حالياً.';
  }

  Widget _planCard(
    BuildContext context, {
    required String name,
    required String price,
    required List<String> features,
    required Color color1,
    required Color color2,
    required IconData icon,
    required bool highlight,
    required bool loading,
    required VoidCallback onSubscribe,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color2.withValues(alpha: 0.3),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color2,
                      ),
                    ),
                  ),
                ],
              ),
              if (highlight)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'الأكثر شهرة ⭐',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (features.isEmpty)
                const Text(
                  'لا توجد ميزات محددة لهذه الباقة.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: features
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color2,
                          ),
                        )
                      : Text(
                          'اشترك الآن',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: color2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'تعذر تحميل الباقات.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'لا توجد باقات متاحة حالياً.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}
