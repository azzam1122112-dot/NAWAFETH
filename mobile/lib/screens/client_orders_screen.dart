import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../constants/colors.dart';
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
  static const Color _mainColor = AppColors.deepPurple;

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
      String? statusGroup;
      switch (_selectedFilter) {
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
      }

      String? type;
      switch (_selectedType) {
        case 'عاجل':
          type = 'urgent';
          break;
        case 'عروض':
          type = 'competitive';
          break;
        case 'عادي':
          type = 'normal';
          break;
      }

      final jsonList = await MarketplaceApi().getMyRequests(
        statusGroup: statusGroup,
        type: type,
      );
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

  Color _statusColor(String status) {
    switch (status) {
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
          color: selected ? _mainColor.withValues(alpha: 0.12) : Colors.transparent,
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
    final total = _orders.length;
    final inProgress = _orders.where((o) => o.status == 'تحت التنفيذ').length;
    final completed = _orders.where((o) => o.status == 'مكتمل').length;
    final canceled = _orders.where((o) => o.status == 'ملغي').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B5BD6), Color(0xFF8C7BFF)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B5BD6).withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'طلباتي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'كل طلباتك في مكان واحد مع حالة واضحة لكل طلب.',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryBadge('الإجمالي', total.toString()),
                        _summaryBadge('تحت التنفيذ', inProgress.toString()),
                        _summaryBadge('مكتمل', completed.toString()),
                        _summaryBadge('ملغي', canceled.toString()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionTitle('ابحث عن طلبك'),
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
              _sectionTitle('نوع الطلب'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'الكل',
                      selected: _selectedType == 'الكل',
                        onTap: () {
                          setState(() => _selectedType = 'الكل');
                          _fetchOrders();
                        },
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'عادي',
                      selected: _selectedType == 'عادي',
                        onTap: () {
                          setState(() => _selectedType = 'عادي');
                          _fetchOrders();
                        },
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'عاجل',
                      selected: _selectedType == 'عاجل',
                        onTap: () {
                          setState(() => _selectedType = 'عاجل');
                          _fetchOrders();
                        },
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'عروض',
                      selected: _selectedType == 'عروض',
                        onTap: () {
                          setState(() => _selectedType = 'عروض');
                          _fetchOrders();
                        },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionTitle('حالة الطلب'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'الكل',
                      selected: _selectedFilter == 'الكل',
                        onTap: () {
                          setState(() => _selectedFilter = 'الكل');
                          _fetchOrders();
                        },
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'جديد',
                      selected: _selectedFilter == 'جديد',
                        onTap: () {
                          setState(() => _selectedFilter = 'جديد');
                          _fetchOrders();
                        },
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'تحت التنفيذ',
                      selected: _selectedFilter == 'تحت التنفيذ',
                        onTap: () {
                          setState(() => _selectedFilter = 'تحت التنفيذ');
                          _fetchOrders();
                        },
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'مكتمل',
                      selected: _selectedFilter == 'مكتمل',
                        onTap: () {
                          setState(() => _selectedFilter = 'مكتمل');
                          _fetchOrders();
                        },
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'ملغي',
                      selected: _selectedFilter == 'ملغي',
                        onTap: () {
                          setState(() => _selectedFilter = 'ملغي');
                          _fetchOrders();
                        },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'لا توجد طلبات حالياً',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'عند إنشاء طلب جديد سيظهر هنا مع حالته وتفاصيله.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: orders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
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
              'رقم الطلب: ${order.id}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'الخدمة: ${order.serviceCode} • المدينة: ${order.city.isEmpty ? '-' : order.city}',
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
              'تاريخ الإنشاء: ${_formatDate(order.createdAt)}',
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
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'عرض التفاصيل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _mainColor.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left_rounded, size: 18, color: _mainColor.withValues(alpha: 0.9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.softBlue,
        ),
      ),
    );
  }

  Widget _summaryBadge(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
