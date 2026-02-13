import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../constants/colors.dart';
import '../models/client_order.dart';
import '../services/marketplace_api.dart';
import 'client_order_details_screen.dart';

/// صفحة طلباتي الخاصة بالعميل
/// ============================
/// هذه الصفحة مخصصة فقط للعملاء لرؤية طلباتهم الخاصة.
/// مرتبطة بـ /marketplace/client/requests/ في الـ backend
///
/// ملاحظة مهمة: هذه الصفحة منفصلة تماماً عن ProviderOrdersScreen (تتبع الطلبات لمزود الخدمة)
///
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
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
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل الطلبات، حاول مرة أخرى.';
        });
      }
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
      case 'بانتظار اعتماد العميل':
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
      if (_selectedFilter == 'تحت التنفيذ') {
        result = result.where(
          (o) =>
              o.status == 'تحت التنفيذ' || o.status == 'بانتظار اعتماد العميل',
        );
      } else {
        result = result.where((o) => o.status == _selectedFilter);
      }
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
          color: selected
              ? _mainColor.withValues(alpha: 0.12)
              : Colors.transparent,
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
      MaterialPageRoute(builder: (_) => ClientOrderDetailsScreen(order: order)),
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
    final width = MediaQuery.sizeOf(context).width;
    final bool isCompact = width < 370;
    final orders = _filteredOrders(_orders);

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildBody(isDark: isDark, orders: orders, isCompact: isCompact);

    if (widget.embedded) {
      return Directionality(textDirection: TextDirection.rtl, child: content);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
        appBar: AppBar(
          backgroundColor: _mainColor,
          title: const Text(
            'طلباتي',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: _fetchOrders,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: content,
      ),
    );
  }

  Widget _buildBody({
    required bool isDark,
    required List<ClientOrder> orders,
    required bool isCompact,
  }) {
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final cardRadius = isCompact ? 14.0 : 18.0;

    final total = _orders.length;
    final inProgress = _orders
        .where(
          (o) =>
              o.status == 'تحت التنفيذ' || o.status == 'بانتظار اعتماد العميل',
        )
        .length;
    final completed = _orders.where((o) => o.status == 'مكتمل').length;
    final canceled = _orders.where((o) => o.status == 'ملغي').length;

    final listContent = orders.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              14,
            ),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.12),
              Container(
                padding: EdgeInsets.all(isCompact ? 16 : 22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: isCompact ? 34 : 40,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: isCompact ? 8 : 10),
                    Text(
                      'لا توجد طلبات حالياً',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 13 : 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'عند إنشاء طلب جديد سيظهر هنا مع حالته وتفاصيله.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: isCompact ? 11 : 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              14,
            ),
            itemCount: orders.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: isCompact ? 8 : 10),
            itemBuilder: (_, index) {
              final order = orders[index];
              return _orderCard(
                order: order,
                isDark: isDark,
                isCompact: isCompact,
              );
            },
          );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 12 : 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B5BD6), Color(0xFF8C7BFF)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(cardRadius),
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
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'طلباتي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: isCompact ? 14 : 16,
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
                        fontSize: isCompact ? 11 : 12,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryBadge(
                          'الإجمالي',
                          total.toString(),
                          compact: isCompact,
                        ),
                        _summaryBadge(
                          'تحت التنفيذ',
                          inProgress.toString(),
                          compact: isCompact,
                        ),
                        _summaryBadge(
                          'مكتمل',
                          completed.toString(),
                          compact: isCompact,
                        ),
                        _summaryBadge(
                          'ملغي',
                          canceled.toString(),
                          compact: isCompact,
                        ),
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
                  borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
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
                        decoration: InputDecoration(
                          hintText: 'بحث',
                          border: InputBorder.none,
                          isDense: true,
                          hintStyle: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: isCompact ? 12 : 13,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: isCompact ? 12 : 13,
                        ),
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
        if (_errorMessage != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              8,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(onRefresh: _fetchOrders, child: listContent),
        ),
      ],
    );
  }

  Widget _orderCard({
    required ClientOrder order,
    required bool isDark,
    required bool isCompact,
  }) {
    final statusColor = _statusColor(order.status);
    final typeLabel = _typeLabel(order.requestType);
    final typeColor = _typeColor(typeLabel);

    return InkWell(
      onTap: () => _openDetails(order),
      borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 12 : 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
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
            Text(
              order.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: isCompact ? 14 : 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  text: typeLabel,
                  textColor: typeColor,
                  bgColor: typeColor.withAlpha(26),
                  borderColor: typeColor.withAlpha(90),
                  compact: isCompact,
                ),
                _pill(
                  text: order.status,
                  textColor: statusColor,
                  bgColor: statusColor.withAlpha(28),
                  borderColor: statusColor.withAlpha(80),
                  compact: isCompact,
                ),
              ],
            ),
            SizedBox(height: isCompact ? 7 : 8),
            Text(
              'رقم الطلب: ${order.id}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: isCompact ? 11 : 12,
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
                fontSize: isCompact ? 11 : 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'تاريخ الإنشاء: ${_formatDate(order.createdAt)}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: isCompact ? 11 : 12,
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
                  fontSize: isCompact ? 11 : 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
            SizedBox(height: isCompact ? 8 : 10),
            Row(
              children: [
                Text(
                  'عرض التفاصيل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.bold,
                    color: _mainColor.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: _mainColor.withValues(alpha: 0.9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill({
    required String text,
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontFamily: 'Cairo',
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.bold,
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

  Widget _summaryBadge(String title, String value, {required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 6 : 7,
      ),
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
              fontSize: compact ? 10 : 11,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
