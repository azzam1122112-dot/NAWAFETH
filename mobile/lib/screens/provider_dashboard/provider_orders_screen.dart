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

  String _selectedAssignedStatus = 'جديد';

  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  bool _accountChecked = false;
  bool _isProviderAccount = false;

  bool _loadingAssigned = true;
  bool _loadingUrgent = true;
  bool _loadingCompetitive = true;

  List<Map<String, dynamic>> _assigned = const [];
  List<Map<String, dynamic>> _urgent = const [];
  List<Map<String, dynamic>> _competitive = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      _fetchCompetitive(),
    ]);
  }

  Future<void> _fetchAssigned() async {
    if (!mounted) return;
    setState(() => _loadingAssigned = true);
    try {
      String statusGroup;
      switch (_selectedAssignedStatus) {
        case 'جديد':
          statusGroup = 'new';
          break;
        case 'تحت التنفيذ':
          statusGroup = 'in_progress';
          break;
        case 'مكتمل':
          statusGroup = 'completed';
          break;
        case 'ملغي':
          statusGroup = 'cancelled';
          break;
        default:
          statusGroup = 'new';
          break;
      }

      final list = await MarketplaceApi().getMyProviderRequests(statusGroup: statusGroup);
      if (!mounted) return;
      setState(() {
        _assigned = list.cast<Map<String, dynamic>>();
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
        _urgent = list.cast<Map<String, dynamic>>();
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

  Future<void> _fetchCompetitive() async {
    if (!mounted) return;
    setState(() => _loadingCompetitive = true);
    try {
      final list = await MarketplaceApi().getAvailableCompetitiveRequestsForProvider();
      if (!mounted) return;
      setState(() {
        _competitive = list.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _competitive = const [];
      });
    } finally {
      if (mounted) setState(() => _loadingCompetitive = false);
    }
  }

  String _mapStatus(String status) {
    switch ((status).toString().trim().toLowerCase()) {
      case 'open':
      case 'pending':
      case 'new':
      case 'sent':
        return 'جديد';
      case 'accepted':
      case 'in_progress':
        return 'تحت التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return 'ملغي';
      default:
        return 'جديد';
    }
  }

  int? _extractRequestId(Map<String, dynamic> req) {
    final raw = req['id'] ?? req['request_id'];
    if (raw is int) return raw;
    return int.tryParse((raw ?? '').toString());
  }

  String _statusGroup(Map<String, dynamic> req) {
    final group = (req['status_group'] ?? '').toString().trim().toLowerCase();
    if (group.isNotEmpty) return group;

    final raw = (req['status'] ?? '').toString().trim().toLowerCase();
    if (raw.isNotEmpty) {
      if (raw == 'open' || raw == 'pending' || raw == 'new' || raw == 'sent') {
        return 'new';
      }
      if (raw == 'accepted' || raw == 'in_progress') {
        return 'in_progress';
      }
      if (raw == 'completed') return 'completed';
      if (raw == 'cancelled' || raw == 'canceled' || raw == 'expired') return 'cancelled';
    }

    final label = (req['status_label'] ?? '').toString().trim();
    if (label == 'جديد') return 'new';
    if (label == 'تحت التنفيذ') return 'in_progress';
    if (label == 'مكتمل') return 'completed';
    if (label == 'ملغي') return 'cancelled';

    return 'new';
  }

  String _rawStatus(Map<String, dynamic> req) {
    final raw = (req['status'] ?? '').toString().trim().toLowerCase();
    if (raw.isNotEmpty) return raw;
    final group = _statusGroup(req);
    if (group == 'new') return 'new';
    if (group == 'in_progress') return 'accepted';
    if (group == 'completed') return 'completed';
    if (group == 'cancelled') return 'cancelled';
    return '';
  }

  Color _statusColor(String statusAr) {
    switch (statusAr) {
      case 'مكتمل':
        return Colors.green;
      case 'ملغي':
        return Colors.red;
      case 'تحت التنفيذ':
        return Colors.orange;
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

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _mainColor.withAlpha(28) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _mainColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? _mainColor : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _assignedStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            label: 'جديد',
            selected: _selectedAssignedStatus == 'جديد',
            onTap: () {
              setState(() => _selectedAssignedStatus = 'جديد');
              _fetchAssigned();
            },
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'تحت التنفيذ',
            selected: _selectedAssignedStatus == 'تحت التنفيذ',
            onTap: () {
              setState(() => _selectedAssignedStatus = 'تحت التنفيذ');
              _fetchAssigned();
            },
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'مكتمل',
            selected: _selectedAssignedStatus == 'مكتمل',
            onTap: () {
              setState(() => _selectedAssignedStatus = 'مكتمل');
              _fetchAssigned();
            },
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'ملغي',
            selected: _selectedAssignedStatus == 'ملغي',
            onTap: () {
              setState(() => _selectedAssignedStatus = 'ملغي');
              _fetchAssigned();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _acceptUrgent(Map<String, dynamic> req) async {
    final id = _extractRequestId(req);
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
    final statusLabel = (req['status_label'] ?? '').toString().trim();
    final statusAr = statusLabel.isNotEmpty
        ? statusLabel
        : _mapStatus((req['status'] ?? '').toString());
    final statusGroup = _statusGroup(req);
    final rawStatus = _rawStatus(req);
    final statusColor = _statusColor(statusAr);
    final type = (req['request_type'] ?? '').toString().trim().toLowerCase();
    final isUrgent = type == 'urgent';
    final isCompetitive = type == 'competitive';
    final typeLabel = isUrgent ? 'عاجل' : (isCompetitive ? 'عروض' : 'عادي');
    final typeColor = isUrgent ? Colors.redAccent : (isCompetitive ? Colors.blueGrey : _mainColor);

    final canAcceptRejectAssigned =
      !urgentTab &&
      !isCompetitive &&
      (statusGroup == 'new' || rawStatus == 'open' || rawStatus == 'pending');
    final canStartAssigned = !urgentTab && !isCompetitive && rawStatus == 'accepted';
    final canCompleteAssigned =
      !urgentTab &&
      !isCompetitive &&
      (rawStatus == 'in_progress' || (rawStatus.isEmpty && statusGroup == 'in_progress'));

    return InkWell(
      onTap: () => _openRequestDetails(req, urgentTab: urgentTab),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                    '#${_extractRequestId(req) ?? '-'}  ${(req['title'] ?? '').toString()}',
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
            const SizedBox(height: 10),
            if (urgentTab) ...[
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
            ] else if (canAcceptRejectAssigned) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectAssigned(req),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withAlpha(120)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptAssigned(req),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('قبول', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mainColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (canStartAssigned) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startAssigned(req),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('بدء التنفيذ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mainColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ] else if (canCompleteAssigned) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _completeAssigned(req),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('تأكيد إكمال الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openRequestDetails(req, urgentTab: urgentTab),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text(
                  'فتح الطلب',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptAssigned(Map<String, dynamic> req) async {
    final id = _extractRequestId(req);
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('قبول الطلب', style: TextStyle(fontFamily: 'Cairo')),
          content: const Text('هل تريد قبول هذا الطلب؟', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: _mainColor, foregroundColor: Colors.white),
              child: const Text('قبول'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final ok = await MarketplaceApi().acceptAssignedRequest(requestId: id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم قبول الطلب.' : 'تعذر قبول الطلب حالياً.', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: ok ? Colors.green : null,
      ),
    );

    await _fetchAssigned();
  }

  Future<void> _rejectAssigned(Map<String, dynamic> req) async {
    final id = _extractRequestId(req);
    if (id == null) return;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض الطلب', style: TextStyle(fontFamily: 'Cairo')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اكتب سبب الرفض (اختياري):', style: TextStyle(fontFamily: 'Cairo')),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('رفض'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final ok = await MarketplaceApi().rejectAssignedRequest(
      requestId: id,
      note: noteController.text,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم رفض الطلب.' : 'تعذر رفض الطلب حالياً.', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: ok ? Colors.green : null,
      ),
    );

    await _fetchAssigned();
  }

  Future<void> _sendOffer(Map<String, dynamic> req) async {
    final id = _extractRequestId(req);
    if (id == null) return;

    final priceController = TextEditingController();
    final daysController = TextEditingController(text: '3');
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تقديم عرض', style: TextStyle(fontFamily: 'Cairo')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر (ريال)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المدة (بالأيام)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال العرض')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final price = double.tryParse(priceController.text.trim());
    final days = int.tryParse(daysController.text.trim());
    if (price == null || price <= 0 || days == null || days <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تحقق من السعر والمدة', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    final ok = await MarketplaceApi().createOffer(
      requestId: id,
      price: price,
      durationDays: days,
      note: noteController.text,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم إرسال العرض.' : 'تعذر إرسال العرض.', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: ok ? Colors.green : null,
      ),
    );

    await _fetchCompetitive();
  }

  Future<void> _startAssigned(Map<String, dynamic> req) async {
    final id = _extractRequestId(req);
    if (id == null) return;

    final ok = await MarketplaceApi().startAssignedRequest(requestId: id, note: 'بدء التنفيذ من التطبيق');
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم بدء التنفيذ.' : 'تعذر بدء التنفيذ حالياً.', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: ok ? Colors.green : null,
      ),
    );

    await _fetchAssigned();
  }

  Future<void> _completeAssigned(Map<String, dynamic> req) async {
    final id = _extractRequestId(req);
    if (id == null) return;

    final ok = await MarketplaceApi().completeAssignedRequest(requestId: id, note: 'تم الإنجاز من التطبيق');
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم تحديث الطلب إلى مكتمل.' : 'تعذر إكمال الطلب حالياً.', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: ok ? Colors.green : null,
      ),
    );

    await _fetchAssigned();
  }

  Future<void> _openRequestDetails(Map<String, dynamic> req, {required bool urgentTab}) async {
    final statusGroup = _statusGroup(req);
    final rawStatus = _rawStatus(req);
    final type = (req['request_type'] ?? '').toString().trim().toLowerCase();
    final isCompetitive = type == 'competitive';

    final canAcceptRejectAssigned =
        !urgentTab &&
        !isCompetitive &&
        (statusGroup == 'new' || rawStatus == 'open' || rawStatus == 'pending');
    final canStartAssigned = !urgentTab && !isCompetitive && rawStatus == 'accepted';
    final canCompleteAssigned =
        !urgentTab &&
        !isCompetitive &&
        (rawStatus == 'in_progress' || (rawStatus.isEmpty && statusGroup == 'in_progress'));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(40),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    (req['title'] ?? '').toString(),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'رقم الطلب: #${(_extractRequestId(req) ?? '').toString()}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'التصنيف: ${(req['subcategory_name'] ?? '').toString()}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المدينة: ${(req['city'] ?? '').toString()}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (req['description'] ?? '').toString(),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  if (isCompetitive)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendOffer(req);
                        },
                        icon: const Icon(Icons.local_offer_outlined),
                        label: const Text('تقديم عرض', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (urgentTab)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _acceptUrgent(req);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('قبول الطلب العاجل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (canAcceptRejectAssigned) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _acceptAssigned(req);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('قبول الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: _mainColor, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _rejectAssigned(req);
                        },
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('رفض الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ),
                  ],
                  if (canStartAssigned)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _startAssigned(req);
                        },
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('بدء التنفيذ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: _mainColor, foregroundColor: Colors.white),
                      ),
                    ),
                  if (canCompleteAssigned)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _completeAssigned(req);
                        },
                        icon: const Icon(Icons.task_alt_rounded),
                        label: const Text('تأكيد إكمال الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _tabBody({required int tabIndex}) {
    final isAssigned = tabIndex == 0;
    final isUrgent = tabIndex == 1;
    final isCompetitive = tabIndex == 2;

    final loading = isAssigned ? _loadingAssigned : (isUrgent ? _loadingUrgent : _loadingCompetitive);
    final list = isAssigned ? _assigned : (isUrgent ? _urgent : _competitive);
    final filtered = _filtered(list);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: isAssigned ? _fetchAssigned : (isUrgent ? _fetchUrgent : _fetchCompetitive),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.embedded) _searchBar(),
          if (!widget.embedded) const SizedBox(height: 12),
          if (isAssigned) _assignedStatusChips(),
          if (isAssigned) const SizedBox(height: 12),
          if (filtered.isEmpty)
            _emptyState(
              isUrgent
                  ? 'لا توجد طلبات عاجلة متاحة حالياً'
                  : (isCompetitive ? 'لا توجد طلبات عروض متاحة حالياً' : 'لا توجد طلبات حالياً'),
              isUrgent
                  ? 'تأكد من تفعيل الطلبات العاجلة واختيار تخصصاتك في إكمال الملف التعريفي.'
                  : (isCompetitive
                      ? 'ستظهر هنا طلبات العروض المطابقة لتخصصك ومدينتك لتقديم عروضك.'
                      : 'ستظهر الطلبات هنا عندما يتم إسنادها لك.'),
            )
          else
            ...filtered.map((e) {
              if (isCompetitive) {
                return Column(
                  children: [
                    _requestCard(e, urgentTab: false),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _sendOffer(e),
                        icon: const Icon(Icons.local_offer_outlined),
                        label: const Text('قدّم عرض', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
              return _requestCard(e, urgentTab: isUrgent);
            }),
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
        child: Column(
          children: [
            Container(
              color: _mainColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'طلباتي'),
                  Tab(text: 'العاجلة المتاحة'),
                  Tab(text: 'العروض المتاحة'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _tabBody(tabIndex: 0),
                  _tabBody(tabIndex: 1),
                  _tabBody(tabIndex: 2),
                ],
              ),
            ),
          ],
        ),
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
              Tab(text: 'العروض المتاحة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _tabBody(tabIndex: 0),
            _tabBody(tabIndex: 1),
            _tabBody(tabIndex: 2),
          ],
        ),
      ),
    );
  }
}
