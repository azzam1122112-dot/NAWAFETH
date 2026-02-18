import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../constants/colors.dart';
import '../models/client_order.dart';
import '../services/marketplace_api.dart';
import '../services/session_storage.dart';
import '../utils/auth_guard.dart';
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

  final SessionStorage _session = const SessionStorage();

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'الكل';
  String _selectedType = 'الكل';

  List<ClientOrder> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _loginRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final loggedIn = await _session.isLoggedIn();
      if (!loggedIn) {
        setState(() {
          _isLoading = false;
          _orders = [];
          _loginRequired = true;
          _errorMessage = 'تسجيل الدخول مطلوب لعرض الطلبات.';
        });
        return;
      }
      await _fetchOrders();
    });
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchOrders() async {
    final loggedIn = await _session.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _orders = [];
        _loginRequired = true;
        _errorMessage = 'تسجيل الدخول مطلوب لعرض الطلبات.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loginRequired = false;
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

  void _setTypeFilter(String value) {
    if (_selectedType == value) return;
    setState(() => _selectedType = value);
    _fetchOrders();
  }

  void _setStatusFilter(String value) {
    if (_selectedFilter == value) return;
    setState(() => _selectedFilter = value);
    _fetchOrders();
  }

  void _resetFilters() {
    final noChanges = _selectedType == 'الكل' &&
        _selectedFilter == 'الكل' &&
        _searchController.text.trim().isEmpty;
    if (noChanges) return;
    setState(() {
      _selectedType = 'الكل';
      _selectedFilter = 'الكل';
      _searchController.clear();
    });
    _fetchOrders();
  }

  Widget _modernDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required bool isCompact,
  }) {
    return Expanded(
      child: Container(
        height: isCompact ? 44 : 48,
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE8E7F0),
            width: 1.2,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _mainColor,
              size: 22,
            ),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Icon(
                      _getIconForItem(item, label),
                      size: isCompact ? 15 : 16,
                      color: item == value ? _mainColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: isCompact ? 11.5 : 12.5,
                          fontWeight: item == value ? FontWeight.bold : FontWeight.w500,
                          color: item == value
                              ? _mainColor
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
            selectedItemBuilder: (BuildContext context) {
              return items.map<Widget>((String item) {
                return Row(
                  children: [
                    Icon(icon, size: isCompact ? 15 : 16, color: _mainColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: isCompact ? 12 : 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  IconData _getIconForItem(String item, String category) {
    if (category == 'النوع') {
      switch (item) {
        case 'الكل':
          return Icons.apps_rounded;
        case 'عادي':
          return Icons.assignment_rounded;
        case 'عاجل':
          return Icons.bolt_rounded;
        case 'عروض':
          return Icons.request_quote_rounded;
        default:
          return Icons.circle_outlined;
      }
    } else {
      // category == 'الحالة'
      switch (item) {
        case 'الكل':
          return Icons.tune_rounded;
        case 'جديد':
          return Icons.fiber_new_rounded;
        case 'تحت التنفيذ':
          return Icons.timelapse_rounded;
        case 'مكتمل':
          return Icons.task_alt_rounded;
        case 'ملغي':
          return Icons.cancel_outlined;
        default:
          return Icons.circle_outlined;
      }
    }
  }

  Widget _filterPanel({required bool isDark, required bool isCompact}) {
    final typeItems = ['الكل', 'عادي', 'عاجل', 'عروض'];
    final statusItems = ['الكل', 'جديد', 'تحت التنفيذ', 'مكتمل', 'ملغي'];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE9E7F3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _mainColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _mainColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  size: isCompact ? 16 : 18,
                  color: _mainColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'تصفية الطلبات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF3D395B),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _resetFilters,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: _mainColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 10,
                    vertical: 4,
                  ),
                ),
                icon: Icon(Icons.restart_alt_rounded, size: isCompact ? 16 : 18),
                label: Text(
                  'إعادة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 12),
          Row(
            children: [
              _modernDropdown(
                label: 'النوع',
                icon: Icons.category_rounded,
                value: _selectedType,
                items: typeItems,
                onChanged: (val) {
                  if (val != null) _setTypeFilter(val);
                },
                isDark: isDark,
                isCompact: isCompact,
              ),
              SizedBox(width: isCompact ? 8 : 10),
              _modernDropdown(
                label: 'الحالة',
                icon: Icons.flag_rounded,
                value: _selectedFilter,
                items: statusItems,
                onChanged: (val) {
                  if (val != null) _setStatusFilter(val);
                },
                isDark: isDark,
                isCompact: isCompact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDetails(ClientOrder order) async {
    final updated = await Navigator.push<ClientOrder>(
      context,
      MaterialPageRoute(builder: (_) => ClientOrderDetailsScreen(order: order)),
    );

    if (!mounted || updated == null) return;
    await _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final bool isCompact = width < 370;
    final orders = _filteredOrders(_orders);

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : (_loginRequired
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 140, 16, 16),
                children: [
                  Center(
                    child: Text(
                      'تسجيل الدخول مطلوب لعرض الطلبات.',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => checkAuth(context),
                      child: const Text('دخول', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ),
                ],
              )
            : _buildBody(isDark: isDark, orders: orders, isCompact: isCompact));

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
              onPressed: () async {
                if (_loginRequired) {
                  await checkAuth(context);
                  return;
                }
                await _fetchOrders();
              },
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
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 14 : 16,
                  vertical: isCompact ? 12 : 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE9E7F3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _mainColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: _mainColor,
                        size: isCompact ? 18 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن طلب بالرقم أو العنوان...',
                          border: InputBorder.none,
                          isDense: true,
                          hintStyle: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: isCompact ? 12 : 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: isCompact ? 12 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_searchController.text.trim().isNotEmpty)
                      IconButton(
                        onPressed: () => _searchController.clear(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade600,
                        ),
                        iconSize: 20,
                        tooltip: 'مسح',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _filterPanel(isDark: isDark, isCompact: isCompact),
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
      borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 14 : 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE9E7F3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: _mainColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
}
