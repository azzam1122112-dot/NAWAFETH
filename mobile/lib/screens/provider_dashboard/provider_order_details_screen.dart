import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../models/provider_order.dart';
import '../../services/chat_nav.dart';
import '../../services/marketplace_api.dart';

class ProviderOrderDetailsScreen extends StatefulWidget {
  final ProviderOrder order;
  final int requestId;
  final String rawStatus;
  final String requestType;
  final List<Map<String, dynamic>> statusLogs;

  const ProviderOrderDetailsScreen({
    super.key,
    required this.order,
    required this.requestId,
    required this.rawStatus,
    required this.requestType,
    this.statusLogs = const [],
  });

  @override
  State<ProviderOrderDetailsScreen> createState() => _ProviderOrderDetailsScreenState();
}

class _ProviderOrderDetailsScreenState extends State<ProviderOrderDetailsScreen> {
  static const Color _mainColor = Colors.deepPurple;

  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;
  late final TextEditingController _estimatedAmountController;
  late final TextEditingController _receivedAmountController;
  late final TextEditingController _remainingAmountController;
  late final TextEditingController _actualAmountController;
  late final TextEditingController _cancelReasonController;
  final TextEditingController _executionUpdateController = TextEditingController();

  late String _status;
  late String _initialRawStatus;
  DateTime? _createdAt;
  DateTime? _expectedDeliveryAt;
  DateTime? _deliveredAt;
  DateTime? _canceledAt;

  List<ProviderOrderAttachment> _attachments = const [];
  List<Map<String, dynamic>> _statusLogs = const [];

  bool _accountChecked = false;
  bool _isProviderAccount = false;
  bool _isSaving = false;
  bool _isLoadingDetail = false;

  bool get _isUrgentRequest => widget.requestType.trim().toLowerCase() == 'urgent';
  bool get _isCompetitiveRequest => widget.requestType.trim().toLowerCase() == 'competitive';
  bool get _isNewLikeStatus {
    final s = _initialRawStatus;
    return s == 'new' || s == 'sent' || s == 'open' || s == 'pending';
  }

  @override
  void initState() {
    super.initState();
    _ensureProviderAccount();

    _titleController = TextEditingController(text: widget.order.title);
    _detailsController = TextEditingController(text: widget.order.details);
    _estimatedAmountController = TextEditingController(text: _formatNumber(widget.order.estimatedServiceAmountSR));
    _receivedAmountController = TextEditingController(text: _formatNumber(widget.order.receivedAmountSR));
    _remainingAmountController = TextEditingController(text: _formatNumber(widget.order.remainingAmountSR));
    _actualAmountController = TextEditingController(text: _formatNumber(widget.order.actualServiceAmountSR));
    _cancelReasonController = TextEditingController(text: widget.order.cancelReason ?? '');

    _status = widget.order.status;
    _initialRawStatus = widget.rawStatus.trim().toLowerCase();
    _createdAt = widget.order.createdAt;
    _expectedDeliveryAt = widget.order.expectedDeliveryAt;
    _deliveredAt = widget.order.deliveredAt;
    _canceledAt = widget.order.canceledAt;

    _attachments = widget.order.attachments;
    _statusLogs = widget.statusLogs;
    _executionUpdateController.text = _latestStatusNote();

    _loadRequestDetail();
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
    _executionUpdateController.dispose();
    super.dispose();
  }

  Future<void> _ensureProviderAccount() async {
    if (!mounted) return;
    setState(() {
      _isProviderAccount = true;
      _accountChecked = true;
    });
  }

  Future<void> _loadRequestDetail() async {
    if (_isLoadingDetail) return;
    setState(() => _isLoadingDetail = true);
    try {
      final data = await MarketplaceApi().getProviderRequestDetail(requestId: widget.requestId);
      if (data == null || !mounted) return;

      final raw = (data['status'] ?? '').toString().trim().toLowerCase();
      final statusLabel = (data['status_label'] ?? '').toString().trim();
      final mappedStatus = statusLabel.isNotEmpty ? statusLabel : _mapRawToStatusAr(raw);

      final attachments = <ProviderOrderAttachment>[];
      final attachmentsRaw = data['attachments'];
      if (attachmentsRaw is List) {
        for (final item in attachmentsRaw) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final url = (map['file_url'] ?? '').toString();
          final type = (map['file_type'] ?? 'file').toString();
          attachments.add(
            ProviderOrderAttachment(
              name: url.isEmpty ? 'مرفق' : url,
              type: type,
            ),
          );
        }
      }

      List<Map<String, dynamic>> logs = const [];
      if (data['status_logs'] is List) {
        logs = (data['status_logs'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      setState(() {
        _titleController.text = (data['title'] ?? '').toString();
        _detailsController.text = (data['description'] ?? '').toString();
        _status = mappedStatus;
        if (raw.isNotEmpty) {
          _initialRawStatus = raw;
        }
        _createdAt = DateTime.tryParse((data['created_at'] ?? '').toString()) ?? _createdAt;
        _attachments = attachments;
        _statusLogs = logs;
        final latest = _latestStatusNote();
        if (latest.isNotEmpty) {
          _executionUpdateController.text = latest;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('HH:mm dd/MM/yyyy', 'ar').format(date);
  }

  String _formatDateOnly(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'ar').format(date);
  }

  String _formatNumber(double? value) {
    if (value == null) return '';
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toString();
  }

  String _mapRawToStatusAr(String raw) {
    switch (raw) {
      case 'accepted':
      case 'in_progress':
        return 'تحت التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return 'ملغي';
      case 'new':
      case 'open':
      case 'pending':
      case 'sent':
      default:
        return 'جديد';
    }
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

  List<String> _availableStatuses() {
    if (_isUrgentRequest || _isCompetitiveRequest) return [_status];

    if (_isNewLikeStatus) return const ['جديد', 'تحت التنفيذ', 'ملغي'];
    if (_initialRawStatus == 'accepted') return const ['تحت التنفيذ'];
    if (_initialRawStatus == 'in_progress') return const ['تحت التنفيذ', 'مكتمل'];
    if (_initialRawStatus == 'completed') return const ['مكتمل'];
    if (_initialRawStatus == 'cancelled') return const ['ملغي'];
    return const ['جديد', 'تحت التنفيذ', 'مكتمل', 'ملغي'];
  }

  String _extractActionMessage(MarketplaceActionResult result, String fallback) {
    final msg = (result.message ?? '').trim();
    return msg.isEmpty ? fallback : msg;
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
    return DateTime(date.year, date.month, date.day, pickedTime.hour, pickedTime.minute);
  }

  void _openChat() {
    ChatNav.openThread(
      context,
      requestId: widget.requestId,
      name: widget.order.clientName,
      isOnline: false,
    );
  }
  Future<void> _save() async {
    if (_isSaving) return;
    if (_isUrgentRequest || _isCompetitiveRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('استخدم زر الإجراء الأساسي لهذا الطلب.', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

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

      if (targetRaw == initial) {
        ok = true;
      } else if (_isNewLikeStatus && targetRaw == 'in_progress') {
        final acceptRes = await api.acceptAssignedRequestDetailed(requestId: widget.requestId);
        if (!acceptRes.ok) {
          ok = false;
          message = _extractActionMessage(acceptRes, 'تعذر قبول الطلب حالياً.');
        } else {
          final startOk = await api.startAssignedRequest(
            requestId: widget.requestId,
            note: _executionUpdateController.text.trim().isEmpty ? 'بدء التنفيذ' : _executionUpdateController.text.trim(),
          );
          ok = startOk;
          message = startOk ? 'تم قبول الطلب وبدء التنفيذ.' : 'تم القبول ولكن تعذر بدء التنفيذ.';
        }
      } else if (_isNewLikeStatus && targetRaw == 'cancelled') {
        ok = await api.rejectAssignedRequest(
          requestId: widget.requestId,
          note: _cancelReasonController.text.trim().isEmpty ? 'رفض من المزود' : _cancelReasonController.text.trim(),
        );
        message = ok ? 'تم رفض الطلب.' : 'تعذر رفض الطلب حالياً.';
      } else if (initial == 'accepted' && targetRaw == 'in_progress') {
        ok = await api.startAssignedRequest(
          requestId: widget.requestId,
          note: _executionUpdateController.text.trim().isEmpty ? 'بدء التنفيذ' : _executionUpdateController.text.trim(),
        );
        message = ok ? 'تم بدء التنفيذ.' : 'تعذر بدء التنفيذ حالياً.';
      } else if (initial == 'in_progress' && targetRaw == 'completed') {
        ok = await api.completeAssignedRequest(
          requestId: widget.requestId,
          note: _executionUpdateController.text.trim().isEmpty ? 'تم الإنجاز' : _executionUpdateController.text.trim(),
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

  Future<void> _primaryActionForSpecialRequest() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_isUrgentRequest) {
        final ok = await MarketplaceApi().acceptUrgentRequest(requestId: widget.requestId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'تم قبول الطلب العاجل.' : 'تعذر قبول الطلب العاجل حالياً.', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: ok ? Colors.green : null,
          ),
        );
        if (ok) Navigator.pop(context, true);
        return;
      }

      if (_isCompetitiveRequest) {
        final ok = await _showOfferDialogAndSubmit();
        if (ok && mounted) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _showOfferDialogAndSubmit() async {
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
                decoration: const InputDecoration(labelText: 'السعر (ريال)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المدة (أيام)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظة', border: OutlineInputBorder()),
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

    if (confirmed != true) return false;
    final price = double.tryParse(priceController.text.trim());
    final days = int.tryParse(daysController.text.trim());
    if (price == null || price <= 0 || days == null || days <= 0) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تحقق من السعر والمدة', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return false;
    }

    final ok = await MarketplaceApi().createOffer(
      requestId: widget.requestId,
      price: price,
      durationDays: days,
      note: noteController.text.trim(),
    );
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم إرسال العرض.' : 'تعذر إرسال العرض.', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: ok ? Colors.green : null,
      ),
    );
    return ok;
  }

  String _latestStatusNote() {
    for (var i = _statusLogs.length - 1; i >= 0; i--) {
      final note = (_statusLogs[i]['note'] ?? '').toString().trim();
      if (note.isNotEmpty) return note;
    }
    return '';
  }

  String _statusLabelFromRaw(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'new':
      case 'open':
      case 'pending':
      case 'sent':
        return 'جديد (تحت التقييم والمناقشة)';
      case 'accepted':
      case 'in_progress':
        return 'تحت التنفيذ';
      case 'completed':
        return 'مكتمل (تم التسليم وسداد المستحقات)';
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return 'ملغي';
      default:
        return raw;
    }
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _mainColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'R${widget.requestId.toString().padLeft(6, '0')}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _mainColor,
                  ),
                ),
              ),
              _statusPill(_status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.order.serviceCode}  @${widget.order.clientName}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(_createdAt ?? widget.order.createdAt),
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: Colors.black.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String statusAr) {
    final color = switch (statusAr) {
      'مكتمل' => Colors.green,
      'ملغي' => Colors.red,
      'تحت التنفيذ' => Colors.orange,
      _ => Colors.amber.shade800,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        statusAr,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
  Widget _readonlyField({required String title, required String value, int minLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minLines == 1 ? 48 : 96),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _mainColor.withValues(alpha: 0.22)),
          ),
          child: Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _attachmentsBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.attach_file, color: _mainColor, size: 18),
            SizedBox(width: 6),
            Text('المرفقات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _mainColor.withValues(alpha: 0.22)),
          ),
          child: _attachments.isEmpty
              ? Text(
                  'لا توجد مرفقات',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black.withValues(alpha: 0.6)),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachments
                      .map(
                        (a) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _mainColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            a.type,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _mainColor),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _statusDropdown() {
    final options = _availableStatuses();
    final current = options.contains(_status) ? _status : options.first;
    if (current != _status) {
      _status = current;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _mainColor.withValues(alpha: 0.55), width: 1.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _mainColor),
          items: options
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text(s, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (_isUrgentRequest || _isCompetitiveRequest)
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
        ),
      ),
    );
  }

  Widget _executionUpdateBox() {
    return TextField(
      controller: _executionUpdateController,
      minLines: 5,
      maxLines: 7,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
      decoration: InputDecoration(
        hintText: 'اكتب تحديث حالة التنفيذ هنا...',
        hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black.withValues(alpha: 0.45)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mainColor.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mainColor.withValues(alpha: 0.22)),
        ),
      ),
    );
  }

  Widget _statusTimelineSection() {
    final logs = _statusLogs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _mainColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'قائمة منسدلة:',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: _mainColor),
          ),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text('لا توجد سجلات حالة حتى الآن', style: TextStyle(fontFamily: 'Cairo', fontSize: 13))
          else
            ...logs.map((log) {
              final toStatus = _statusLabelFromRaw((log['to_status'] ?? '').toString());
              final at = DateTime.tryParse((log['created_at'] ?? '').toString());
              final actor = (log['actor_name'] ?? '-').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 6, color: _mainColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$toStatus${at != null ? ' - ${DateFormat('dd/MM/yyyy HH:mm', 'ar').format(at)}' : ''}${actor.trim().isEmpty ? '' : ' - $actor'}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statusSpecificCard() {
    if (_status == 'تحت التنفيذ') {
      return _boxCard(
        title: 'تحت التنفيذ',
        child: Column(
          children: [
            _dateField(
              label: 'موعد التسليم المتوقع',
              value: _expectedDeliveryAt,
              onTap: () async {
                final initial = _expectedDeliveryAt ?? DateTime.now();
                final picked = await _pickDateTime(initial);
                if (picked != null && mounted) setState(() => _expectedDeliveryAt = picked);
              },
            ),
            const SizedBox(height: 8),
            _moneyField('قيمة الخدمة المقدرة (SR)', _estimatedAmountController),
            const SizedBox(height: 8),
            _moneyField('المبلغ المستلم (SR)', _receivedAmountController),
            const SizedBox(height: 8),
            _moneyField('المبلغ المتبقي (SR)', _remainingAmountController),
          ],
        ),
      );
    }

    if (_status == 'مكتمل') {
      return _boxCard(
        title: 'مكتمل',
        child: Column(
          children: [
            _dateField(
              label: 'موعد التسليم الفعلي',
              value: _deliveredAt,
              onTap: () async {
                final initial = _deliveredAt ?? DateTime.now();
                final picked = await _pickDateTime(initial);
                if (picked != null && mounted) setState(() => _deliveredAt = picked);
              },
            ),
            const SizedBox(height: 8),
            _moneyField('قيمة الخدمة الفعلية (SR)', _actualAmountController),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _mainColor.withValues(alpha: 0.20)),
              ),
              child: const Text(
                'مرفقات: صور - تقارير - فواتير - إيصالات - مقطع فيديو',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_status == 'ملغي') {
      return _boxCard(
        title: 'ملغي',
        child: Column(
          children: [
            _dateField(
              label: 'تاريخ الإلغاء',
              value: _canceledAt,
              onTap: () async {
                final initial = _canceledAt ?? DateTime.now();
                final picked = await _pickDateTime(initial);
                if (picked != null && mounted) setState(() => _canceledAt = picked);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cancelReasonController,
              minLines: 2,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'سبب الإلغاء',
                labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _mainColor.withValues(alpha: 0.25)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _boxCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _mainColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _mainColor, width: 1.2),
              ),
              child: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _mainColor)),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _mainColor.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: _mainColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? label : '$label: ${_formatDateOnly(value)}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _mainColor.withValues(alpha: 0.20)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_accountChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isProviderAccount) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final specialActionTitle = _isUrgentRequest
        ? 'قبول الطلب العاجل'
        : (_isCompetitiveRequest ? 'تقديم عرض' : '');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _mainColor,
          elevation: 0,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: _mainColor.withValues(alpha: 0.14),
            ),
            child: const Text(
              'تفاصيل الطلب',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: _mainColor),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _openChat,
              tooltip: 'فتح محادثة مع العميل',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              color: _mainColor,
              onRefresh: _loadRequestDetail,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 120),
                children: [
                  _headerCard(),
                  const SizedBox(height: 12),
                  _readonlyField(title: 'عنوان الطلب', value: _titleController.text),
                  const SizedBox(height: 12),
                  _readonlyField(title: 'تفاصيل الطلب', value: _detailsController.text, minLines: 3),
                  const SizedBox(height: 12),
                  _attachmentsBox(),
                  const SizedBox(height: 12),
                  const Text(
                    'تحديث عن حالة تنفيذ العمل',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: _mainColor),
                  ),
                  const SizedBox(height: 6),
                  _executionUpdateBox(),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.check_box_outline_blank_rounded, color: _mainColor, size: 18),
                      SizedBox(width: 6),
                      Text('حالة الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: _mainColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _statusDropdown(),
                  _statusSpecificCard(),
                  const SizedBox(height: 12),
                  _statusTimelineSection(),
                ],
              ),
            ),
            if (_isLoadingDetail)
              const Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : (_isUrgentRequest || _isCompetitiveRequest ? _primaryActionForSpecialRequest : _save),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mainColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          (_isUrgentRequest || _isCompetitiveRequest) ? specialActionTitle : 'حفظ',
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: _mainColor.withValues(alpha: 0.55)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: _mainColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
