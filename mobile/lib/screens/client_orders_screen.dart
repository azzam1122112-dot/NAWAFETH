import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/client_order.dart';
import '../services/marketplace_api.dart';
import 'client_order_details_screen.dart';

class ClientOrdersScreen extends StatefulWidget {
  final bool embedded;

  const ClientOrdersScreen({super.key, this.embedded = false});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  static const Color _mainColor = Colors.deepPurple;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'الكل';
  String _selectedType = 'الكل';

  List<ClientOrder> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final jsonList = await MarketplaceApi().getMyRequests();
      if (mounted) {
        setState(() {
          _orders = jsonList.map((e) => ClientOrder.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ClientOrder> _demoOrdersForCurrentClient() {
    return [
      ClientOrder(
        id: 'R055544',
        serviceCode: '@111222',
        createdAt: DateTime(2024, 1, 1, 16, 35),
        status: 'جديد',
        title: 'تصميم فيلا خاصة',
        details: 'تفاصيل الطلب هنا (وهمية): تصميم فيلا خاصة مع توزيع الغرف والمساحات وإخراج مبدئي للمخططات.',
        attachments: const [
          ClientOrderAttachment(name: 'متطلبات_العميل.pdf', type: 'PDF'),
          ClientOrderAttachment(name: 'صور_مرجعية.zip', type: 'ZIP'),
        ],
      ),
      ClientOrder(
        id: 'R055545',
        serviceCode: '@111223',
        createdAt: DateTime(2024, 1, 2, 10, 20),
        status: 'تحت التنفيذ',
        title: 'إصلاح سيارة',
        details: 'تفاصيل الطلب هنا (وهمية): فحص شامل وتقدير تكلفة الإصلاح مع تحديد قطع الغيار المطلوبة.',
        expectedDeliveryAt: DateTime(2024, 1, 10, 18, 0),
        serviceAmountSR: 1200,
        receivedAmountSR: 400,
        remainingAmountSR: 800,
        attachments: const [
          ClientOrderAttachment(name: 'صورة_العطل.jpg', type: 'IMG'),
        ],
      ),
      ClientOrder(
        id: 'R055546',
        serviceCode: '@111224',
        createdAt: DateTime(2024, 1, 3, 9, 10),
        status: 'مكتمل',
        title: 'تجديد ديكور صالة',
        details: 'تفاصيل الطلب هنا (وهمية): اقتراح ألوان/أثاث وتوزيع إضاءة وإخراج تصور نهائي.',
        deliveredAt: DateTime(2024, 1, 8, 13, 0),
        actualServiceAmountSR: 950,
        ratingResponseSpeed: 4,
        ratingCostValue: 4,
        ratingQuality: 3,
        ratingCredibility: 4,
        ratingOnTime: 5,
        ratingComment: 'تعامل ممتاز وتسليم في الموعد (وهمي).',
      ),
      ClientOrder(
        id: 'R055547',
        serviceCode: '@111225',
        createdAt: DateTime(2024, 1, 4, 14, 5),
        status: 'ملغي',
        title: 'تصميم شعار',
        details: 'تفاصيل الطلب هنا (وهمية): تم الإلغاء قبل بدء التنفيذ.',
        canceledAt: DateTime(2024, 1, 5, 9, 30),
        cancelReason: 'تغيير المتطلبات من العميل قبل بدء التنفيذ.',
      ),
    ];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'مكتمل':
        return Colors.green;
      case 'ملغي':
        return Colors.red;
      case 'تحت التنفيذ':
        return Colors.orange;
      case 'جديد':
      case 'أُرسل':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    // dd:MM - HH:mm - dd/MM/yyyy (simple, consistent with mock)
    return DateFormat('HH:mm  dd/MM/yyyy', 'ar').format(date);
  }

  List<ClientOrder> _filteredOrders(List<ClientOrder> orders) {
    final query = _searchController.text.trim();
    Iterable<ClientOrder> result = orders;

    if (_selectedType != 'الكل') {
      result = result.where((o) => _typeLabel(o.requestType) == _selectedType);
    }

    if (_selectedFilter != 'الكل') {
      result = result.where((o) => o.status == _selectedFilter);
    }

    if (query.isNotEmpty) {
      result = result.where(
        (o) =>
            o.id.toLowerCase().contains(query.toLowerCase()) ||
            o.title.toLowerCase().contains(query.toLowerCase()) ||
            o.serviceCode.toLowerCase().contains(query.toLowerCase()),
      );
    }

    return result.toList();
  }

  String _typeLabel(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'urgent':
        return 'عاجل';
      case 'competitive':
        return 'عروض';
      case 'normal':
      default:
        return 'عادي';
    }
  }

  Color _typeColor(String label) {
    switch (label) {
      case 'عاجل':
        return Colors.redAccent;
      case 'عروض':
        return Colors.blueGrey;
      default:
        return Colors.deepPurple;
    }
  }

  Widget _filterChip({
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
          color: selected ? _mainColor.withOpacity(0.12) : Colors.transparent,
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

  Future<void> _openDetails(ClientOrder order) async {
    final updated = await Navigator.push<ClientOrder>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientOrderDetailsScreen(order: order),
      ),
    );

    if (!mounted || updated == null) return;
    setState(() {
      final index = _orders.indexWhere((o) => o.id == updated.id);
      if (index != -1) _orders[index] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final orders = _filteredOrders(_orders);
    
    final content = _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _buildBody(isDark: isDark, orders: orders);

    if (widget.embedded) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: content,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
        appBar: AppBar(
          backgroundColor: _mainColor,
          title: const Text(
            'طلباتي',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: content,
      ),
    );
  }

  Widget _buildBody({required bool isDark, required List<ClientOrder> orders}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'بحث',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    if (_searchController.text.trim().isNotEmpty)
                      IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                        tooltip: 'مسح',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'الكل',
                      selected: _selectedType == 'الكل',
                      onTap: () => setState(() => _selectedType = 'الكل'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'عادي',
                      selected: _selectedType == 'عادي',
                      onTap: () => setState(() => _selectedType = 'عادي'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'عاجل',
                      selected: _selectedType == 'عاجل',
                      onTap: () => setState(() => _selectedType = 'عاجل'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'عروض',
                      selected: _selectedType == 'عروض',
                      onTap: () => setState(() => _selectedType = 'عروض'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'الكل',
                      selected: _selectedFilter == 'الكل',
                      onTap: () => setState(() => _selectedFilter = 'الكل'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'جديد',
                      selected: _selectedFilter == 'جديد',
                      onTap: () => setState(() => _selectedFilter = 'جديد'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'أُرسل',
                      selected: _selectedFilter == 'أُرسل',
                      onTap: () => setState(() => _selectedFilter = 'أُرسل'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'مقبول',
                      selected: _selectedFilter == 'مقبول',
                      onTap: () => setState(() => _selectedFilter = 'مقبول'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'تحت التنفيذ',
                      selected: _selectedFilter == 'تحت التنفيذ',
                      onTap: () => setState(() => _selectedFilter = 'تحت التنفيذ'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'مكتمل',
                      selected: _selectedFilter == 'مكتمل',
                      onTap: () => setState(() => _selectedFilter = 'مكتمل'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'ملغي',
                      selected: _selectedFilter == 'ملغي',
                      onTap: () => setState(() => _selectedFilter = 'ملغي'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'منتهي',
                      selected: _selectedFilter == 'منتهي',
                      onTap: () => setState(() => _selectedFilter = 'منتهي'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد طلبات',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final order = orders[index];
                    return _orderCard(order: order, isDark: isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _orderCard({required ClientOrder order, required bool isDark}) {
    final statusColor = _statusColor(order.status);
    final typeLabel = _typeLabel(order.requestType);
    final typeColor = _typeColor(typeLabel);

    return InkWell(
      onTap: () => _openDetails(order),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.id}  ${order.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: typeColor.withAlpha(90)),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(28),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    order.status,
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
            const SizedBox(height: 8),
            Text(
              '${order.serviceCode} • ${order.city.isEmpty ? '-' : order.city}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(order.createdAt),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            if ((order.providerName ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'المزود: ${order.providerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
