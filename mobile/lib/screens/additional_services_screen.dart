import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/billing_api.dart';
import '../services/extras_api.dart';
import '../services/payment_checkout.dart';
import '../services/promo_api.dart';
import '../widgets/bottom_nav.dart';

class AdditionalServicesScreen extends StatefulWidget {
  const AdditionalServicesScreen({super.key});

  @override
  State<AdditionalServicesScreen> createState() => _AdditionalServicesScreenState();
}

class _AdditionalServicesScreenState extends State<AdditionalServicesScreen> with SingleTickerProviderStateMixin {
  final BillingApi _billingApi = BillingApi();
  final ExtrasApi _extrasApi = ExtrasApi();
  final PromoApi _promoApi = PromoApi();

  late TabController _tabController;

  late Future<List<Map<String, dynamic>>> _catalogFuture;
  late Future<List<Map<String, dynamic>>> _myExtrasFuture;
  late Future<List<Map<String, dynamic>>> _myPromoFuture;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _targetCategoryCtrl = TextEditingController();
  final TextEditingController _targetCityCtrl = TextEditingController();
  final TextEditingController _redirectUrlCtrl = TextEditingController();

  DateTime? _startAt;
  DateTime? _endAt;
  String _adType = 'banner_home';
  String _frequency = '60s';
  String _position = 'normal';
  bool _submittingPromo = false;

  static const Map<String, String> _adTypeLabels = {
    'banner_home': 'بانر الرئيسية',
    'banner_category': 'بانر القسم',
    'banner_search': 'بانر البحث',
    'popup_home': 'نافذة منبثقة رئيسية',
    'popup_category': 'نافذة منبثقة داخل القسم',
    'featured_top5': 'تمييز ضمن أول 5',
    'featured_top10': 'تمييز ضمن أول 10',
    'boost_profile': 'تعزيز الملف',
    'push_notification': 'إشعار Push',
  };

  static const Map<String, String> _frequencyLabels = {
    '10s': 'كل 10 ثواني',
    '20s': 'كل 20 ثانية',
    '30s': 'كل 30 ثانية',
    '60s': 'كل 60 ثانية',
  };

  static const Map<String, String> _positionLabels = {
    'first': 'الأول',
    'second': 'الثاني',
    'top5': 'ضمن أول 5',
    'top10': 'ضمن أول 10',
    'normal': 'عادي',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reloadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _targetCategoryCtrl.dispose();
    _targetCityCtrl.dispose();
    _redirectUrlCtrl.dispose();
    super.dispose();
  }

  void _reloadAll() {
    setState(() {
      _catalogFuture = _extrasApi.getCatalog();
      _myExtrasFuture = _extrasApi.getMyExtras();
      _myPromoFuture = _promoApi.getMyRequests();
    });
  }

  Future<void> _buyExtra(String sku) async {
    try {
      final purchase = await _extrasApi.buy(sku);
      if (!mounted) return;

      final invoiceId = _asInt(purchase['invoice']);
      if (invoiceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء طلب شراء الإضافة، لكن رقم الفاتورة غير متوفر.')),
        );
        return;
      }

      await PaymentCheckout.initAndOpen(
        context: context,
        billingApi: _billingApi,
        invoiceId: invoiceId,
        idempotencyKey: 'extra-$sku-${DateTime.now().millisecondsSinceEpoch}',
        successMessage: 'تم إنشاء طلب الإضافة وفتح صفحة الدفع.',
      );
      _reloadAll();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractError(e, fallback: 'تعذر شراء الإضافة.'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر شراء الإضافة.')));
    }
  }

  Future<void> _createPromo() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _startAt == null || _endAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل عنوان الحملة وتواريخ البداية والنهاية.')),
      );
      return;
    }

    if (!_endAt!.isAfter(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البداية.')),
      );
      return;
    }

    setState(() => _submittingPromo = true);

    try {
      final payload = {
        'title': title,
        'ad_type': _adType,
        'start_at': _startAt!.toUtc().toIso8601String(),
        'end_at': _endAt!.toUtc().toIso8601String(),
        'frequency': _frequency,
        'position': _position,
        'target_category': _targetCategoryCtrl.text.trim(),
        'target_city': _targetCityCtrl.text.trim(),
        'redirect_url': _redirectUrlCtrl.text.trim(),
      };

      final created = await _promoApi.createRequest(payload);
      if (!mounted) return;
      final invoiceId = _asInt(created['invoice']);
      if (invoiceId != null) {
        await PaymentCheckout.initAndOpen(
          context: context,
          billingApi: _billingApi,
          invoiceId: invoiceId,
          idempotencyKey: 'promo-${created['id'] ?? title}-${DateTime.now().millisecondsSinceEpoch}',
          successMessage: 'تم إنشاء طلب الترويج وفتح صفحة الدفع.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إنشاء طلب الترويج: ${created['code'] ?? '#${created['id'] ?? '-'}'}')),
        );
      }

      _titleCtrl.clear();
      _targetCategoryCtrl.clear();
      _targetCityCtrl.clear();
      _redirectUrlCtrl.clear();
      setState(() {
        _startAt = null;
        _endAt = null;
      });
      _reloadAll();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractError(e, fallback: 'تعذر إنشاء طلب الترويج.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء طلب الترويج.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingPromo = false);
      }
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = dt;
      } else {
        _endAt = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'الخدمات الإضافية والترويج',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'كتالوج الإضافات'),
            Tab(text: 'مشترياتي'),
            Tab(text: 'الترويج'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCatalogTab(),
          _buildMyExtrasTab(),
          _buildPromoTab(),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
    );
  }

  Widget _buildCatalogTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StateMessage(text: 'تعذر تحميل الكتالوج.', action: 'إعادة المحاولة', onTap: _reloadAll);
        }

        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _StateMessage(text: 'لا توجد إضافات متاحة حالياً.', action: 'تحديث', onTap: _reloadAll);
        }

        return RefreshIndicator(
          onRefresh: () async => _reloadAll(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final sku = (item['sku'] ?? '').toString();
              return Card(
                child: ListTile(
                  title: Text((item['title'] ?? sku).toString(), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  subtitle: Text('SKU: $sku', style: const TextStyle(fontFamily: 'Cairo')),
                  trailing: ElevatedButton(
                    onPressed: sku.isEmpty ? null : () => _buyExtra(sku),
                    child: Text('${item['price']} ر.س', style: const TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMyExtrasTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _myExtrasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StateMessage(text: 'تعذر تحميل مشتريات الإضافات.', action: 'إعادة المحاولة', onTap: _reloadAll);
        }

        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _StateMessage(text: 'لا توجد مشتريات إضافات حالياً.', action: 'تحديث', onTap: _reloadAll);
        }

        return RefreshIndicator(
          onRefresh: () async => _reloadAll(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text((item['title'] ?? item['sku'] ?? '').toString(), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'الحالة: ${item['status'] ?? '-'}\nفاتورة: ${item['invoice'] ?? '-'}',
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPromoTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _myPromoFuture,
      builder: (context, snapshot) {
        final promoItems = snapshot.data ?? const [];

        return RefreshIndicator(
          onRefresh: () async => _reloadAll(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('إنشاء طلب ترويج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'عنوان الحملة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _adType,
                items: _adTypeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Cairo'))))
                    .toList(),
                onChanged: (v) => setState(() => _adType = v ?? _adType),
                decoration: const InputDecoration(labelText: 'نوع الإعلان', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      items: _frequencyLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Cairo'))))
                          .toList(),
                      onChanged: (v) => setState(() => _frequency = v ?? _frequency),
                      decoration: const InputDecoration(labelText: 'التكرار', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _position,
                      items: _positionLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Cairo'))))
                          .toList(),
                      onChanged: (v) => setState(() => _position = v ?? _position),
                      decoration: const InputDecoration(labelText: 'الموضع', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDateTime(isStart: true),
                      child: Text(
                        _startAt == null ? 'تاريخ البداية' : _startAt!.toString(),
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDateTime(isStart: false),
                      child: Text(
                        _endAt == null ? 'تاريخ النهاية' : _endAt!.toString(),
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _targetCategoryCtrl,
                decoration: const InputDecoration(labelText: 'الفئة المستهدفة (اختياري)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _targetCityCtrl,
                decoration: const InputDecoration(labelText: 'المدينة المستهدفة (اختياري)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _redirectUrlCtrl,
                decoration: const InputDecoration(labelText: 'رابط التحويل (اختياري)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submittingPromo ? null : _createPromo,
                child: _submittingPromo
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('إرسال طلب الترويج', style: TextStyle(fontFamily: 'Cairo')),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              const Text('طلباتي الترويجية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _StateMessage(text: 'تعذر تحميل طلبات الترويج.', action: 'إعادة المحاولة', onTap: _reloadAll)
              else if (promoItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('لا توجد طلبات ترويج حالياً.', style: TextStyle(fontFamily: 'Cairo')),
                )
              else
                ...promoItems.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text((item['title'] ?? item['code'] ?? '').toString(), style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'الحالة: ${item['status'] ?? '-'}\nالفاتورة: ${item['invoice'] ?? '-'}',
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _extractError(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      for (final value in data.values) {
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is List && value.isNotEmpty && value.first is String) {
          final first = (value.first as String).trim();
          if (first.isNotEmpty) return first;
        }
      }
    }
    return fallback;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

class _StateMessage extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;

  const _StateMessage({required this.text, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontFamily: 'Cairo')),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: onTap, child: Text(action, style: const TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
  }
}
