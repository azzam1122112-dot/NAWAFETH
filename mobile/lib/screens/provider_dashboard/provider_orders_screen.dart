import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../services/marketplace_api.dart';
import '../../services/role_controller.dart';
import '../client_orders_screen.dart';

class ProviderOrdersScreen extends StatefulWidget {
  final bool embedded;

  const ProviderOrdersScreen({super.key, this.embedded = false});

  @override
  State<ProviderOrdersScreen> createState() => _ProviderOrdersScreenState();
}

class _ProviderOrdersScreenState extends State<ProviderOrdersScreen> with SingleTickerProviderStateMixin {
  static const Color _mainColor = Colors.deepPurple;

  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  bool _accountChecked = false;
  bool _isProviderAccount = false;

  bool _loadingAssigned = true;
  bool _loadingUrgent = true;

  List<Map<String, dynamic>> _assigned = const [];
  List<Map<String, dynamic>> _urgent = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _ensureProviderAccount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureProviderAccount() async {
    final role = RoleController.instance.notifier.value;
    if (!mounted) return;
    setState(() {
      _isProviderAccount = role.isProvider;
      _accountChecked = true;
    });

    if (!_isProviderAccount) {
      if (widget.embedded) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientOrdersScreen()),
        );
      });
      return;
    }

    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchAssigned(),
      _fetchUrgent(),
    ]);
  }

  Future<void> _fetchAssigned() async {
    if (!mounted) return;
    setState(() => _loadingAssigned = true);
    try {
      final list = await MarketplaceApi().getMyProviderRequests();
      if (!mounted) return;
      setState(() {
        _assigned = (list is List) ? list.cast<Map<String, dynamic>>() : const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assigned = const [];
      });
    } finally {
      if (mounted) setState(() => _loadingAssigned = false);
    }
  }

  Future<void> _fetchUrgent() async {
    if (!mounted) return;
    setState(() => _loadingUrgent = true);
    try {
      final list = await MarketplaceApi().getAvailableUrgentRequestsForProvider();
      if (!mounted) return;
      setState(() {
        _urgent = (list is List) ? list.cast<Map<String, dynamic>>() : const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _urgent = const [];
      });
    } finally {
      if (mounted) setState(() => _loadingUrgent = false);
    }
  }

  String _mapStatus(String status) {
    switch ((status).toString().trim().toLowerCase()) {
      case 'open':
      case 'pending':
      case 'new':
        return 'جديد';
      case 'sent':
        return 'أُرسل';
      case 'accepted':
        return 'مقبول';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
      case 'canceled':
        return 'ملغي';
      case 'expired':
        return 'منتهي';
      default:
        return status;
    }
  }

  Color _statusColor(String statusAr) {
    switch (statusAr) {
      case 'مكتمل':
        return Colors.green;
      case 'ملغي':
        return Colors.red;
      case 'قيد التنفيذ':
      case 'مقبول':
        return Colors.orange;
      case 'أُرسل':
        return Colors.blue;
      case 'جديد':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic raw) {
    final dt = DateTime.tryParse((raw ?? '').toString()) ?? DateTime.now();
    return DateFormat('HH:mm  dd/MM/yyyy', 'ar').format(dt);
  }

  bool _matchesQuery(Map<String, dynamic> item, String query) {
    final q = query.toLowerCase();
    bool match(dynamic v) => (v ?? '').toString().toLowerCase().contains(q);
    return match(item['id']) ||
        match(item['title']) ||
        match(item['subcategory_name']) ||
        match(item['category_name']) ||
        match(item['city']) ||
        match(item['client_phone']);
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> src) {
    final query = _searchController.text.trim();
    if (query.isEmpty) return src;
    return src.where((e) => _matchesQuery(e, query)).toList();
  }

  Future<void> _acceptUrgent(Map<String, dynamic> req) async {
    final id = int.tryParse((req['id'] ?? '').toString());
    if (id == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري قبول الطلب العاجل...')),
    );

    final ok = await MarketplaceApi().acceptUrgentRequest(requestId: id);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قبول الطلب حالياً.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم قبول الطلب بنجاح.'), backgroundColor: Colors.green),
    );

    await _refreshAll();
    if (!mounted) return;
    _tabController.animateTo(0);
  }

  Widget _requestCard(Map<String, dynamic> req, {required bool urgentTab}) {
    final statusAr = _mapStatus((req['status'] ?? '').toString());
    final statusColor = _statusColor(statusAr);
    final type = (req['request_type'] ?? '').toString().trim().toLowerCase();
    final isUrgent = type == 'urgent';
    final typeLabel = isUrgent ? 'عاجل' : 'تنافسي';
    final typeColor = isUrgent ? Colors.redAccent : Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${req['id']}  ${(req['title'] ?? '').toString()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: typeColor.withAlpha(80)),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(color: typeColor, fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: statusColor.withAlpha(80)),
                ),
                child: Text(
                  statusAr,
                  style: TextStyle(color: statusColor, fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${(req['subcategory_name'] ?? '').toString()} • ${(req['city'] ?? '').toString()}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(req['created_at']),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                ),
              ),
              if ((req['client_phone'] ?? '').toString().trim().isNotEmpty)
                Text(
                  (req['client_phone'] ?? '').toString(),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (req['description'] ?? '').toString(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black87, height: 1.4),
          ),
          if (urgentTab) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _acceptUrgent(req),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('قبول الطلب العاجل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'ابحث بالعنوان/التخصص/المدينة...',
                hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12),
              ),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 42, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _tabBody({required bool urgentTab}) {
    final loading = urgentTab ? _loadingUrgent : _loadingAssigned;
    final list = urgentTab ? _urgent : _assigned;
    final filtered = _filtered(list);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: urgentTab ? _fetchUrgent : _fetchAssigned,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.embedded) _searchBar(),
          if (!widget.embedded) const SizedBox(height: 12),
          if (filtered.isEmpty)
            _emptyState(
              urgentTab ? 'لا توجد طلبات عاجلة متاحة حالياً' : 'لا توجد طلبات حالياً',
              urgentTab
                  ? 'تأكد من تفعيل الطلبات العاجلة واختيار تخصصاتك في إكمال الملف التعريفي.'
                  : 'ستظهر الطلبات هنا عندما يتم إسنادها لك.',
            )
          else
            ...filtered.map((e) => _requestCard(e, urgentTab: urgentTab)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_accountChecked) {
      if (widget.embedded) return const Center(child: CircularProgressIndicator());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isProviderAccount) {
      if (widget.embedded) return const SizedBox.shrink();
      return const Scaffold(body: SizedBox.shrink());
    }

    if (widget.embedded) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: _tabBody(urgentTab: false),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: _mainColor,
          foregroundColor: Colors.white,
          title: const Text('تتبع الطلبات', style: TextStyle(fontFamily: 'Cairo')),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'طلباتي'),
              Tab(text: 'العاجلة المتاحة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _tabBody(urgentTab: false),
            _tabBody(urgentTab: true),
          ],
        ),
      ),
    );
  }
}
