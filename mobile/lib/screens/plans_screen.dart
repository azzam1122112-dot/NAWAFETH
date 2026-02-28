import 'package:flutter/material.dart';
import '../services/subscriptions_service.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String? _error;
  bool _subscribing = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final plans = await SubscriptionsService.getPlans();
    if (!mounted) return;

    if (plans.isEmpty) {
      setState(() {
        _error = 'لا توجد باقات متاحة حالياً';
        _loading = false;
      });
      return;
    }
    setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  Future<void> _subscribe(int planId, String planTitle) async {
    setState(() => _subscribing = true);
    final res = await SubscriptionsService.subscribe(planId);
    if (!mounted) return;
    setState(() => _subscribing = false);

    if (res.isSuccess) {
      showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text('تم الاشتراك'),
            ]),
            content: Text(
              'تم الاشتراك في باقة $planTitle بنجاح.',
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.error ?? 'فشل الاشتراك',
            style: const TextStyle(fontFamily: 'Cairo')),
      ));
    }
  }

  // Cycle gradient and icon per index
  static const _gradients = [
    [Color(0xFF42A5F5), Color(0xFF1565C0)], // blue
    [Color(0xFF7E57C2), Color(0xFF4527A0)], // purple
    [Color(0xFFFFA726), Color(0xFFE65100)], // orange
    [Color(0xFF26A69A), Color(0xFF00695C)], // teal
  ];
  static const _icons = [
    Icons.star_border,
    Icons.workspace_premium,
    Icons.verified,
    Icons.diamond,
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('الباقات المدفوعة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(_error!,
                          style: const TextStyle(fontFamily: 'Cairo')),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _loadPlans,
                          child: const Text('إعادة المحاولة',
                              style: TextStyle(fontFamily: 'Cairo'))),
                    ]))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      itemCount: _plans.length,
                      itemBuilder: (context, index) {
                        final plan = _plans[index];
                        final g = _gradients[index % _gradients.length];
                        final icon = _icons[index % _icons.length];
                        return _planCard(plan, g[0], g[1], icon);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _planCard(
      Map<String, dynamic> plan, Color c1, Color c2, IconData icon) {
    final id = plan['id'] as int;
    final title = plan['title'] as String? ?? '';
    final description = plan['description'] as String? ?? '';
    final price = plan['price'];
    final period = plan['period'] as String? ?? '';
    final features = (plan['features'] as List?)?.cast<String>() ?? [];

    final priceDisplay = price == null || price.toString() == '0.00'
        ? 'مجاني'
        : '$price ر.س / ${period == 'year' ? 'سنة' : 'شهر'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            colors: [c1, c2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: c2.withAlpha(75),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withAlpha(40),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withAlpha(50),
                child: Icon(icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    if (description.isNotEmpty)
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(priceDisplay,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: c2)),
              ),
            ]),
            const SizedBox(height: 20),

            // Features
            if (features.isNotEmpty)
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle,
                          size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(f,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  color: Colors.white))),
                    ]),
                  )),
            const SizedBox(height: 20),

            // Subscribe button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _subscribing ? null : () => _subscribe(id, title),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _subscribing
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c2))
                    : Text('اشترك الآن',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: c2)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
