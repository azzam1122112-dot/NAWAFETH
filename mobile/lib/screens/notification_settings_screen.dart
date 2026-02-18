import 'package:flutter/material.dart';

import '../models/notification_preference.dart';
import '../services/notifications_api.dart';
import '../utils/auth_guard.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationsApi _api = NotificationsApi();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<NotificationPreference> _items = const [];

  static const List<String> _tierOrder = <String>[
    'basic',
    'leading',
    'professional',
    'extra',
  ];

  static const Map<String, String> _tierTitle = <String, String>{
    'basic': 'الباقة الأساسية',
    'leading': 'الباقة الريادية',
    'professional': 'الباقة الاحترافية',
    'extra': 'تنبيهات الخدمات الإضافية',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await checkAuth(context);
      if (!ok || !mounted) return;
      await _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _api.getPreferences();
      final list = ((raw['results'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => NotificationPreference.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل إعدادات الإشعارات';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggle(NotificationPreference item, bool value) async {
    if (item.locked || _saving) return;
    setState(() {
      _saving = true;
      _items = _items
          .map((e) => e.key == item.key
              ? NotificationPreference(
                  key: e.key,
                  title: e.title,
                  tier: e.tier,
                  enabled: value,
                  locked: e.locked,
                )
              : e)
          .toList();
    });

    try {
      await _api.updatePreferences(
        updates: [
          {'key': item.key, 'enabled': value},
        ],
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((e) => e.key == item.key
                ? NotificationPreference(
                    key: e.key,
                    title: e.title,
                    tier: e.tier,
                    enabled: !value,
                    locked: e.locked,
                  )
                : e)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التعديل')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          title: const Text(
            'إعدادات الإشعارات',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(fontFamily: 'Cairo')),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: _tierOrder
                          .map((tier) => _buildTierCard(tier))
                          .whereType<Widget>()
                          .toList(),
                    ),
                  ),
      ),
    );
  }

  Widget? _buildTierCard(String tier) {
    final group = _items.where((e) => e.tier == tier).toList();
    if (group.isEmpty) return null;
    final allLocked = group.every((e) => e.locked);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Row(
          children: [
            Text(
              _tierTitle[tier] ?? tier,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            if (allLocked) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'يتطلب ترقية',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
        children: group
            .map(
              (item) => SwitchListTile(
                dense: true,
                value: item.enabled,
                onChanged: item.locked ? null : (v) => _toggle(item, v),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: item.locked ? Colors.grey : Colors.black87,
                  ),
                ),
                subtitle: item.locked
                    ? const Text(
                        'غير متاح في باقتك الحالية',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                        ),
                      )
                    : null,
              ),
            )
            .toList(),
      ),
    );
  }
}
