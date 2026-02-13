import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/provider_order.dart';
import '../../services/marketplace_api.dart';
import '../../services/role_controller.dart';

class ProviderOrderDetailsScreen extends StatefulWidget {
  final ProviderOrder order;
  final int requestId;
  final String rawStatus;
  final List<Map<String, dynamic>> statusLogs;

  const ProviderOrderDetailsScreen({
    super.key,
    required this.order,
    required this.requestId,
    required this.rawStatus,
    this.statusLogs = const [],
  });

  @override
  State<ProviderOrderDetailsScreen> createState() =>
      _ProviderOrderDetailsScreenState();
}

class _ProviderOrderDetailsScreenState extends State<ProviderOrderDetailsScreen> {
  static const Color _mainColor = Colors.deepPurple;

  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;

  late String _status;
  DateTime? _expectedDeliveryAt;
  DateTime? _deliveredAt;
  DateTime? _canceledAt;

  final TextEditingController _estimatedAmountController =
      TextEditingController();
  final TextEditingController _receivedAmountController =
      TextEditingController();
  final TextEditingController _remainingAmountController =
      TextEditingController();

  final TextEditingController _actualAmountController = TextEditingController();
  final TextEditingController _cancelReasonController = TextEditingController();

  bool _accountChecked = false;
  bool _isProviderAccount = false;
  bool _isSaving = false;
  late String _initialRawStatus;

  @override
  void initState() {
    super.initState();
    _ensureProviderAccount();
    _titleController = TextEditingController(text: widget.order.title);
    _detailsController = TextEditingController(text: widget.order.details);

    _status = widget.order.status;
    _initialRawStatus = widget.rawStatus.trim().toLowerCase();

    _expectedDeliveryAt = widget.order.expectedDeliveryAt;
    _deliveredAt = widget.order.deliveredAt;
    _canceledAt = widget.order.canceledAt;

    _estimatedAmountController.text =
        _formatNumber(widget.order.estimatedServiceAmountSR);
    _receivedAmountController.text = _formatNumber(widget.order.receivedAmountSR);
    _remainingAmountController.text =
        _formatNumber(widget.order.remainingAmountSR);

    _actualAmountController.text = _formatNumber(widget.order.actualServiceAmountSR);
    _cancelReasonController.text = widget.order.cancelReason ?? '';
  }

  Future<void> _ensureProviderAccount() async {
    final roleValue = RoleController.instance.notifier.value;
    bool isProvider = roleValue.isProvider;
    if (!isProvider) {
      final prefs = await SharedPreferences.getInstance();
      isProvider = prefs.getBool('isProvider') ?? false;
    }
    if (!mounted) return;
    setState(() {
      _isProviderAccount = isProvider;
      _accountChecked = true;
    });

    if (!_isProviderAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _estimatedAmountController.dispose();
    _receivedAmountController.dispose();
    _remainingAmountController.dispose();
    _actualAmountController.dispose();
    _cancelReasonController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('HH:mm  dd/MM/yyyy', 'ar').format(date);
  }

  String _formatDateOnly(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'ar').format(date);
  }

  String _formatNumber(double? value) {
    if (value == null) return '';
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toString();
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

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ar'),
    );
    if (date == null) return null;

    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    final pickedTime = time ?? TimeOfDay.fromDateTime(initial);
    return DateTime(
      date.year,
      date.month,
      date.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _openChat() {
    Navigator.pushNamed(context, '/chats');
  }

  String _statusToRaw(String statusAr) {
    switch (statusAr) {
      case 'جديد':
        return 'new';
      case 'تحت التنفيذ':
        return 'in_progress';
      case 'مكتمل':
        return 'completed';
      case 'ملغي':
        return 'cancelled';
      default:
        return '';
    }
  }

  String _extractActionMessage(MarketplaceActionResult result, String fallback) {
    final msg = (result.message ?? '').trim();
    return msg.isEmpty ? fallback : msg;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final targetRaw = _statusToRaw(_status);
    if (targetRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حالة الطلب غير صالحة', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final api = MarketplaceApi();
      bool ok = false;
      String message = 'تم حفظ التحديث';

      final initial = _initialRawStatus;
      final isNewLike = initial == 'new' || initial == 'sent' || initial == 'open' || initial == 'pending';

      if (targetRaw == initial) {
        ok = true;
      } else if (isNewLike && targetRaw == 'in_progress') {
        final acceptRes = await api.acceptAssignedRequestDetailed(requestId: widget.requestId);
        if (!acceptRes.ok) {
          ok = false;
          message = _extractActionMessage(acceptRes, 'تعذر قبول الطلب حالياً.');
        } else {
          final startOk = await api.startAssignedRequest(
            requestId: widget.requestId,
            note: 'بدء التنفيذ من صفحة تفاصيل الطلب',
          );
          ok = startOk;
          message = startOk ? 'تم قبول الطلب وبدء التنفيذ.' : 'تم القبول ولكن تعذر بدء التنفيذ.';
        }
      } else if (isNewLike && targetRaw == 'cancelled') {
        ok = await api.rejectAssignedRequest(
          requestId: widget.requestId,
          note: _cancelReasonController.text.trim(),
        );
        message = ok ? 'تم رفض الطلب.' : 'تعذر رفض الطلب حالياً.';
      } else if (isNewLike && targetRaw == 'new') {
        ok = true;
      } else if (initial == 'accepted' && targetRaw == 'in_progress') {
        ok = await api.startAssignedRequest(
          requestId: widget.requestId,
          note: 'بدء التنفيذ من صفحة تفاصيل الطلب',
        );
        message = ok ? 'تم بدء التنفيذ.' : 'تعذر بدء التنفيذ حالياً.';
      } else if (initial == 'in_progress' && targetRaw == 'completed') {
        ok = await api.completeAssignedRequest(
          requestId: widget.requestId,
          note: 'تم الإنجاز من صفحة تفاصيل الطلب',
        );
        message = ok ? 'تم تحديث الطلب إلى مكتمل.' : 'تعذر إكمال الطلب حالياً.';
      } else {
        ok = false;
        message = 'هذا الانتقال غير مدعوم في النظام حالياً.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: ok ? Colors.green : null,
        ),
      );
      if (ok) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _mainColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _readOnlyBox({required String label, required String value, int maxLines = 3}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _mainColor.withAlpha(50)),
          ),
          child: Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required bool enabled,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mainColor.withAlpha(70)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mainColor.withAlpha(170), width: 1.3),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mainColor.withAlpha(35)),
        ),
      ),
    );
  }

  Widget _dateLine({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
  }) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _mainColor.withAlpha(70)),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 18, color: _mainColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? label : '$label: ${_formatDateOnly(value)}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
              ),
            ),
            const Icon(Icons.expand_more, color: Colors.black45),
          ],
        ),
      ),
    );
  }

  Widget _moneyField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        const SizedBox(height: 6),
        _textField(
          controller: controller,
          enabled: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hint: '0',
        ),
      ],
    );
  }

  Widget _statusSpecificSection() {
    switch (_status) {
      case 'تحت التنفيذ':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dateLine(
              label: 'موعد التسليم المتوقع',
              value: _expectedDeliveryAt,
              onPick: () async {
                final initial = _expectedDeliveryAt ?? DateTime.now();
                final picked = await _pickDateTime(initial);
                if (picked != null && mounted) {
                  setState(() => _expectedDeliveryAt = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _moneyField('قيمة الخدمة المقدرة (SR)', _estimatedAmountController),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _moneyField('المبلغ المستلم (SR)', _receivedAmountController),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _moneyField('المبلغ المتبقي (SR)', _remainingAmountController),
          ],
        );

      case 'مكتمل':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dateLine(
              label: 'موعد التسليم الفعلي',
              value: _deliveredAt,
              onPick: () async {
                final initial = _deliveredAt ?? DateTime.now();
                final picked = await _pickDateTime(initial);
                if (picked != null && mounted) {
                  setState(() => _deliveredAt = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            _moneyField('قيمة الخدمة الفعلية (SR)', _actualAmountController),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _mainColor.withAlpha(70)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: _mainColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مرفقات (صور - تقارير - فواتير...)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'إيصالات - مقطع فيديو',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.black.withAlpha(160),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.order.attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...widget.order.attachments.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.black45),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a.name,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                        ),
                      ),
                      Text(
                        a.type,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.black.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );

      case 'ملغي':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dateLine(
              label: 'تاريخ الإلغاء',
              value: _canceledAt,
              onPick: () async {
                final initial = _canceledAt ?? DateTime.now();
                final picked = await _pickDateTime(initial);
                if (picked != null && mounted) {
                  setState(() => _canceledAt = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            Text('سبب الإلغاء', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            const SizedBox(height: 6),
            _textField(
              controller: _cancelReasonController,
              enabled: true,
              maxLines: 2,
              hint: 'اكتب سبب الإلغاء...',
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_accountChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isProviderAccount) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final statusColor = _statusColor(_status);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: _mainColor),
          actions: [
            IconButton(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline, color: _mainColor),
              tooltip: 'فتح محادثة',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: _mainColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _mainColor.withAlpha(70)),
                      ),
                      child: const Text(
                        'تفاصيل الطلب',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _mainColor,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline, color: _mainColor),
                  tooltip: 'فتح محادثة',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _mainColor.withAlpha(8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _mainColor.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: _mainColor),
                      const SizedBox(width: 8),
                      const Text(
                        'بيانات العميل',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _mainColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoLine(
                    icon: Icons.badge_outlined,
                    label: 'الاسم',
                    value: widget.order.clientName,
                  ),
                  const SizedBox(height: 10),
                  _infoLine(
                    icon: Icons.phone,
                    label: 'الجوال',
                    value: (widget.order.clientPhone ?? '').trim().isEmpty
                        ? 'غير متوفر'
                        : widget.order.clientPhone!.trim(),
                  ),
                  const SizedBox(height: 10),
                  _infoLine(
                    icon: Icons.location_on_outlined,
                    label: 'المدينة',
                    value: (widget.order.clientCity ?? '').trim().isEmpty
                        ? 'غير متوفر'
                        : widget.order.clientCity!.trim(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.order.id}  ${widget.order.serviceCode}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${widget.order.clientName}  ${widget.order.clientHandle}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(widget.order.createdAt),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _pill(_status, statusColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _readOnlyBox(label: 'عنوان الطلب', value: widget.order.title, maxLines: 2),
                  const SizedBox(height: 12),
                  _readOnlyBox(label: 'تفاصيل الطلب', value: widget.order.details, maxLines: 6),
                ],
              ),
            ),

            const SizedBox(height: 14),
            if (widget.statusLogs.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الرسائل / سجل الحالة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.statusLogs.take(8).map((item) {
                      final from = (item['from_status'] ?? '').toString();
                      final to = (item['to_status'] ?? '').toString();
                      final note = (item['note'] ?? '').toString();
                      final actor = (item['actor_name'] ?? '-').toString();
                      final at = _formatDate(item['created_at'] != null ? DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now() : DateTime.now());
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '- $at | $actor | $from -> $to${note.trim().isNotEmpty ? ' | $note' : ''}',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            if (widget.statusLogs.isNotEmpty) const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'مرفقات العميل',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.order.attachments.isEmpty)
                    const Text(
                      'لا توجد مرفقات',
                      style: TextStyle(fontFamily: 'Cairo', color: Colors.black54),
                    )
                  else
                    ...widget.order.attachments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 18, color: Colors.black45),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                a.name,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _mainColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _mainColor.withAlpha(60)),
                              ),
                              child: Text(
                                a.type,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: _mainColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('تحديث عن حالة تنفيذ العمل'),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_status),
                    initialValue: _status,
                    items: const [
                      DropdownMenuItem(value: 'جديد', child: Text('جديد', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'تحت التنفيذ', child: Text('تحت التنفيذ', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'مكتمل', child: Text('مكتمل', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'ملغي', child: Text('ملغي', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    decoration: InputDecoration(
                      labelText: 'حالة الطلب',
                      labelStyle: const TextStyle(fontFamily: 'Cairo'),
                      prefixIcon: const Icon(Icons.inventory_2_outlined, color: _mainColor),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(color: _mainColor.withAlpha(70)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(color: _mainColor.withAlpha(170), width: 1.3),
                      ),
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _mainColor.withAlpha(10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _mainColor.withAlpha(60)),
                    ),
                    child: _statusSpecificSection(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: _mainColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('حفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
