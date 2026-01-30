import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/provider_order.dart';
import '../client_orders_screen.dart';
import 'provider_order_details_screen.dart';

class ProviderOrdersScreen extends StatefulWidget {
  final bool embedded;

  const ProviderOrdersScreen({super.key, this.embedded = false});

  @override
  State<ProviderOrdersScreen> createState() => _ProviderOrdersScreenState();
}

class _ProviderOrdersScreenState extends State<ProviderOrdersScreen> {
  static const Color _mainColor = Colors.deepPurple;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  late List<ProviderOrder> _orders;

  bool _accountChecked = false;
  bool _isProviderAccount = false;

  @override
  void initState() {
    super.initState();
    _ensureProviderAccount();
    // NOTE: لا نعرض بيانات وهمية. سيتم ربط شاشة الطلبات بواجهة الباكند لاحقاً.
    _orders = <ProviderOrder>[];
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _ensureProviderAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final isProvider = prefs.getBool('isProvider') ?? false;
    if (!mounted) return;
    setState(() {
      _isProviderAccount = isProvider;
      _accountChecked = true;
    });

    if (!_isProviderAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientOrdersScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_accountChecked) {
      if (widget.embedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isProviderAccount) {
      if (widget.embedded) {
        return const SizedBox.shrink();
      }
      return const Scaffold(body: SizedBox.shrink());
    }

    return widget.embedded
        ? _buildProviderOrdersBody(context)
        : _buildProviderOrders(context);
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
    return DateFormat('HH:mm  dd/MM/yyyy', 'ar').format(date);
  }

  List<ProviderOrder> _filteredOrders() {
    final query = _searchController.text.trim();
    Iterable<ProviderOrder> result = _orders;

    if (_selectedStatus != null) {
      result = result.where((o) => o.status == _selectedStatus);
    }

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      bool match(String s) => s.toLowerCase().contains(q);
      result = result.where((o) {
        return match(o.id) ||
            match(o.serviceCode) ||
            match(o.clientName) ||
            match(o.clientHandle) ||
            match(o.title);
      });
    }

    return result.toList();
  }

  Future<void> _openDetails(ProviderOrder order) async {
    final updated = await Navigator.push<ProviderOrder>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderOrderDetailsScreen(order: order),
      ),
    );

    if (updated == null || !mounted) return;
    setState(() {
      final idx = _orders.indexWhere((o) => o.id == updated.id);
      if (idx != -1) {
        _orders[idx] = updated;
      }
    });
  }

  Widget _filterChip(String label) {
    final isSelected = _selectedStatus == label;
    final color = _statusColor(label);

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : color,
          ),
        ),
        selected: isSelected,
        selectedColor: color,
        backgroundColor: color.withAlpha(26),
        side: BorderSide(color: color.withAlpha(90)),
        onSelected: (_) {
          setState(() {
            _selectedStatus = isSelected ? null : label;
          });
        },
      ),
    );
  }

  Widget _orderCard(ProviderOrder order) {
    final statusColor = _statusColor(order.status);
    return InkWell(
      onTap: () => _openDetails(order),
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
                    '${order.id}  ${order.clientName}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.title}  ${order.serviceCode}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${order.clientHandle} • ${_formatDate(order.createdAt)}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderOrders(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: _mainColor,
          title: const Text(
            'إدارة الطلبات',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildProviderOrdersBody(context),
        ),
      ),
    );
  }

  Widget _buildProviderOrdersBody(BuildContext context) {
    final filtered = _filteredOrders();

    return Column(
      children: [
        TextField(
          controller: _searchController,
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'بحث',
            hintStyle: const TextStyle(fontFamily: 'Cairo'),
            prefixIcon: const Icon(Icons.search, color: _mainColor),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('جديد'),
              _filterChip('تحت التنفيذ'),
              _filterChip('مكتمل'),
              _filterChip('ملغي'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد طلبات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.black54,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _orderCard(filtered[index]),
                ),
        ),
      ],
    );
  }
}
