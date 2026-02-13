import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../models/provider_order.dart';
import '../../services/marketplace_api.dart';
import '../../services/role_controller.dart';
import '../client_orders_screen.dart';
import 'provider_order_details_screen.dart';

/// صفحة تتبع الطلبات الخاصة بمزود الخدمة
/// ====================================
/// هذه الصفحة مخصصة فقط لمزودي الخدمة لرؤية وإدارة طلباتهم.
/// 
/// التبويبات الثلاثة:
/// 1. طلباتي (Assigned): الطلبات المُسندة للمزود (مرتبطة بـ /marketplace/provider/requests/)
/// 2. العاجلة المتاحة (Urgent Available): الطلبات العاجلة التي يمكن قبولها (مرتبطة بـ /marketplace/provider/urgent/available/)
/// 3. العروض المتاحة (Competitive Available): طلبات العروض التنافسية (مرتبطة بـ /marketplace/provider/competitive/available/)
/// 
/// ملاحظة مهمة: هذه الصفحة منفصلة تماماً عن ClientOrdersScreen (طلبات العميل)
/// 
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

  ProviderOrder _toProviderOrder(Map<String, dynamic> req) {
    DateTime parseDate(dynamic raw) =>
        DateTime.tryParse((raw ?? '').toString()) ?? DateTime.now();

    final attachmentsRaw = req['attachments'];
    final attachments = <ProviderOrderAttachment>[];
    if (attachmentsRaw is List) {
      for (final item in attachmentsRaw) {
        if (item is! Map) continue;
        final type = (item['file_type'] ?? 'file').toString();
        final url = (item['file_url'] ?? '').toString();
        attachments.add(
          ProviderOrderAttachment(
            name: url.isEmpty ? 'ملف مرفق' : url,
            type: type,
          ),
        );
      }
    }

    final statusAr = (req['status_label'] ?? '').toString().trim().isNotEmpty
        ? (req['status_label'] ?? '').toString().trim()
        : _mapStatus((req['status'] ?? '').toString());

    return ProviderOrder(
      id: '#${(_extractRequestId(req) ?? '').toString()}',
      serviceCode: (req['subcategory_name'] ?? '').toString(),
      createdAt: parseDate(req['created_at']),
      status: statusAr,
      clientName: (req['client_name'] ?? '-').toString(),
      clientHandle: '',
      clientPhone: (req['client_phone'] ?? '').toString(),
      clientCity: (req['city'] ?? '').toString(),
      title: (req['title'] ?? '').toString(),
      details: (req['description'] ?? '').toString(),
      attachments: attachments,
    );
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

  Widget _requestCard(Map<String, dynamic> req, {required bool urgentTab}) {
    final statusLabel = (req['status_label'] ?? '').toString().trim();
    final statusAr = statusLabel.isNotEmpty
        ? statusLabel
        : _mapStatus((req['status'] ?? '').toString());
    final statusColor = _statusColor(statusAr);
    final type = (req['request_type'] ?? '').toString().trim().toLowerCase();
    final isUrgent = type == 'urgent';
    final isCompetitive = type == 'competitive';
    final typeLabel = isUrgent ? 'عاجل' : (isCompetitive ? 'عروض' : 'عادي');
    final typeColor = isUrgent ? Colors.redAccent : (isCompetitive ? Colors.blueGrey : _mainColor);
    
    // تحديد ما إذا كان الطلب جديد ويحتاج "بدء التنفيذ"
    final rawStatus = (req['status'] ?? '').toString().trim().toLowerCase();
    final showStartButton = !urgentTab && (rawStatus == 'new' || rawStatus == 'sent' || rawStatus == 'open' || rawStatus == 'pending');

    return InkWell(
      onTap: () => _openRequestDetails(req, urgentTab: urgentTab),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان والرقم
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '#${_extractRequestId(req) ?? '-'}  ${(req['title'] ?? '').toString()}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // الشارات (عاجل/عروض + الحالة)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: typeColor.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  statusAr,
                  style: TextStyle(
                    color: statusColor,
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // التصنيف والمدينة
          Text(
            '${(req['subcategory_name'] ?? '').toString()} • ${(req['city'] ?? '').toString()}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          // التاريخ ورقم الهاتف
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(req['created_at']),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black45),
              ),
              if ((req['client_phone'] ?? '').toString().trim().isNotEmpty)
                Text(
                  (req['client_phone'] ?? '').toString(),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black45),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // الوصف
          Text(
            (req['description'] ?? '').toString(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // الأزرار
          Row(
            children: [
              if (showStartButton) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startRequest(req),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text(
                      'بدء التنفيذ',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openRequestDetails(req, urgentTab: urgentTab),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text(
                    'شرح الطلب',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _openRequestDetails(Map<String, dynamic> req, {required bool urgentTab}) async {
    final requestId = _extractRequestId(req);
    Map<String, dynamic> details = req;
    if (requestId != null) {
      final fresh = await MarketplaceApi().getProviderRequestDetail(requestId: requestId);
      if (fresh != null) {
        details = {...req, ...fresh};
      }
    }
    if (!mounted) return;
    if (requestId == null || requestId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الطلب غير صالح', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }
    final order = _toProviderOrder(details);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderOrderDetailsScreen(
          order: order,
          requestId: requestId,
          rawStatus: _rawStatus(details),
          requestType: (details['request_type'] ?? '').toString(),
          statusLogs: (details['status_logs'] is List)
              ? (details['status_logs'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : const [],
        ),
      ),
    );
    if (changed == true && mounted) {
      await _refreshAll();
    }
  }

  Future<void> _startRequest(Map<String, dynamic> req) async {
    final requestId = _extractRequestId(req);
    if (requestId == null || requestId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الطلب غير صالح', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // تأكيد بدء التنفيذ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('بدء التنفيذ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text(
            'هل تريد بدء تنفيذ هذا الطلب؟',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _mainColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('بدء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    // إرسال الطلب للـ backend
    final success = await MarketplaceApi().startAssignedRequest(requestId: requestId);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم بدء تنفيذ الطلب بنجاح', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
        ),
      );
      await _refreshAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء بدء التنفيذ، يرجى المحاولة مرة أخرى', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            ...filtered.map((e) => _requestCard(e, urgentTab: isUrgent)),
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
