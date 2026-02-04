import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../models/client_order.dart';
import '../models/offer.dart';
import '../services/marketplace_api.dart';
import '../services/reviews_api.dart';

class ClientOrderDetailsScreen extends StatefulWidget {
  final ClientOrder order;

  const ClientOrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<ClientOrderDetailsScreen> createState() => _ClientOrderDetailsScreenState();
}

class _ClientOrderDetailsScreenState extends State<ClientOrderDetailsScreen> {
  static const Color _mainColor = Colors.deepPurple;

  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;
  final TextEditingController _reminderController = TextEditingController();

  bool _editTitle = false;
  bool _editDetails = false;

  bool _reopenCanceledOrder = false;
  bool _approveProviderInputs = false;
  bool _rejectProviderInputs = false;

  bool _showRatingForm = false;
  late double _ratingResponseSpeed;
  late double _ratingCostValue;
  late double _ratingQuality;
  late double _ratingCredibility;
  late double _ratingOnTime;
  final TextEditingController _ratingCommentController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _didSubmitReview = false;

  List<Offer> _offers = [];
  bool _isLoadingOffers = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.order.title);
    _detailsController = TextEditingController(text: widget.order.details);

    _ratingResponseSpeed = widget.order.ratingResponseSpeed ?? 0;
    _ratingCostValue = widget.order.ratingCostValue ?? 0;
    _ratingQuality = widget.order.ratingQuality ?? 0;
    _ratingCredibility = widget.order.ratingCredibility ?? 0;
    _ratingOnTime = widget.order.ratingOnTime ?? 0;
    _ratingCommentController.text = widget.order.ratingComment ?? '';

    _fetchOffers();
  }

  bool _isValidCriterion(double value) => value >= 1 && value <= 5;

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) {
          return v.first.toString();
        }
        if (v is String && v.trim().isNotEmpty) {
          return v;
        }
      }
    }
    if (data is String && data.trim().isNotEmpty) return data;
    return null;
  }

  Future<void> _submitReview() async {
    if (_isSubmittingReview) return;

    if (widget.order.status != 'مكتمل') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إرسال التقييم إلا بعد اكتمال الطلب', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    final requestId = int.tryParse(widget.order.id);
    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إرسال التقييم: رقم الطلب غير صالح', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    final values = <double>[
      _ratingResponseSpeed,
      _ratingCostValue,
      _ratingQuality,
      _ratingCredibility,
      _ratingOnTime,
    ];
    if (!values.every(_isValidCriterion)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فضلاً اختر تقييمًا لكل خيار (من 1 إلى 5)', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);
    try {
      await ReviewsApi().createReview(
        requestId: requestId,
        responseSpeed: _ratingResponseSpeed.round(),
        costValue: _ratingCostValue.round(),
        quality: _ratingQuality.round(),
        credibility: _ratingCredibility.round(),
        onTime: _ratingOnTime.round(),
        comment: _ratingCommentController.text,
      );

      _didSubmitReview = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال التقييم بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
      );
      _save();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _extractErrorMessage(e.response?.data) ?? 'تعذر إرسال التقييم';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال التقييم', style: TextStyle(fontFamily: 'Cairo'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _fetchOffers() async {
    // Only fetch offers if order is active/new
    if (widget.order.status == 'جديد' || widget.order.status == 'أُرسل') {
      setState(() => _isLoadingOffers = true);
      try {
        final offers = await MarketplaceApi().getRequestOffers(widget.order.id);
        if (mounted) {
          setState(() {
            _offers = offers;
          });
        }
      } catch (e) {
        debugPrint('Error fetching offers: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoadingOffers = false);
        }
      }
    }
  }

  Future<void> _acceptOffer(Offer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('قبول العرض'),
          content: Text('هل أنت متأكد من قبول عرض بقيمة ${offer.price} ريال؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد القبول'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري قبول العرض...')));
      
      final success = await MarketplaceApi().acceptOffer(offer.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول العرض بنجاح')));
        Navigator.pop(context, widget.order.copyWith(status: 'تحت التنفيذ')); // Return updated order
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل قبول العرض')));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _reminderController.dispose();
    _ratingCommentController.dispose();
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
      case 'أُرسل':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('HH:mm  dd/MM/yyyy', 'ar').format(date);
  }

  void _openChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'سيتم فتح المحادثة مع مقدم الخدمة قريباً',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  void _save() {
    final bool shouldReopen = widget.order.status == 'ملغي' && _reopenCanceledOrder;

    final bool canUpdateRating = widget.order.status == 'مكتمل' && _didSubmitReview;

    final updated = widget.order.copyWith(
      status: shouldReopen ? 'جديد' : widget.order.status,
      title: _titleController.text.trim().isEmpty
          ? widget.order.title
          : _titleController.text.trim(),
      details: _detailsController.text.trim().isEmpty
          ? widget.order.details
          : _detailsController.text.trim(),
      ratingResponseSpeed: canUpdateRating ? _ratingResponseSpeed : widget.order.ratingResponseSpeed,
      ratingCostValue: canUpdateRating ? _ratingCostValue : widget.order.ratingCostValue,
      ratingQuality: canUpdateRating ? _ratingQuality : widget.order.ratingQuality,
      ratingCredibility: canUpdateRating ? _ratingCredibility : widget.order.ratingCredibility,
      ratingOnTime: canUpdateRating ? _ratingOnTime : widget.order.ratingOnTime,
      ratingComment: canUpdateRating ? _ratingCommentController.text.trim() : widget.order.ratingComment,
    );

    Navigator.pop(context, updated);
  }

  String _formatDateOnly(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'ar').format(date);
  }

  String _formatMoney(double? value) {
    if (value == null) return '-';
    final formatted = value.toStringAsFixed(0);
    return '$formatted (SR)';
  }

  Widget _ratingRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          RatingBar.builder(
            initialRating: value,
            minRating: 0,
            allowHalfRating: false,
            itemCount: 5,
            itemSize: 20,
            itemPadding: const EdgeInsets.symmetric(horizontal: 1.5),
            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.transparent,
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required bool canEdit,
    required bool isEditing,
    required VoidCallback onToggle,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (canEdit)
          TextButton(
            onPressed: onToggle,
            child: Text(
              isEditing ? 'إيقاف' : 'تعديل',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(widget.order.status);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
        appBar: AppBar(
          backgroundColor: _mainColor,
          title: const Text(
            'تفاصيل الطلب',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: _openChat,
              tooltip: 'فتح محادثة',
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.order.id,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  widget.order.status,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.order.title} ${widget.order.serviceCode}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(widget.order.createdAt),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Offers Section
                    if (_isLoadingOffers)
                      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                    
                    if (!_isLoadingOffers && (widget.order.status == 'جديد' || widget.order.status == 'أُرسل') && _offers.isNotEmpty) ...[
                      const Text(
                        "العروض المقدمة",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._offers.map((offer) {
                        return Container(
                           margin: const EdgeInsets.only(bottom: 10),
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(
                              color: cardColor,
                            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(12),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(offer.providerName, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black)),
                                    Text('${offer.price} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontFamily: 'Cairo')),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('المدة: ${offer.durationDays} يوم', style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white70 : Colors.black87)),
                                if (offer.note.isNotEmpty) ...[
                                   const SizedBox(height: 4),
                                   Text('ملاحظات: ${offer.note}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                                ],
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _acceptOffer(offer),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('قبول العرض', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                                  ),
                                ),
                             ],
                           ),
                        );
                      }),
                      const SizedBox(height: 14),
                    ],

                    // Completed order: actual delivery + actual amount + rating entry
                    if (widget.order.status == 'مكتمل')
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoLabel('موعد التسليم الفعلي'),
                            _infoRow(
                              label: 'موعد التسليم الفعلي',
                              value: widget.order.deliveredAt == null
                                  ? '-'
                                  : _formatDateOnly(widget.order.deliveredAt!),
                            ),
                            const SizedBox(height: 10),
                            _infoLabel('قيمة الخدمة الفعلية (SR)'),
                            _infoRow(
                              label: 'قيمة الخدمة الفعلية (SR)',
                              value: _formatMoney(widget.order.actualServiceAmountSR),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => setState(() => _showRatingForm = !_showRatingForm),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: _mainColor),
                                ),
                                child: const Text(
                                  'تقييم الخدمة',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    color: _mainColor,
                                  ),
                                ),
                              ),
                            ),
                            if (_showRatingForm) ...[
                              const SizedBox(height: 12),
                              _ratingRow(
                                label: 'سرعة الاستجابة',
                                value: _ratingResponseSpeed,
                                onChanged: (v) => setState(() => _ratingResponseSpeed = v),
                              ),
                              _ratingRow(
                                label: 'التكلفة مقابل الخدمة',
                                value: _ratingCostValue,
                                onChanged: (v) => setState(() => _ratingCostValue = v),
                              ),
                              _ratingRow(
                                label: 'جودة الخدمة',
                                value: _ratingQuality,
                                onChanged: (v) => setState(() => _ratingQuality = v),
                              ),
                              _ratingRow(
                                label: 'المصداقية',
                                value: _ratingCredibility,
                                onChanged: (v) => setState(() => _ratingCredibility = v),
                              ),
                              _ratingRow(
                                label: 'وقت الإنجاز',
                                value: _ratingOnTime,
                                onChanged: (v) => setState(() => _ratingOnTime = v),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'تعليق على الخدمة المقدمة (300 حرف)',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _ratingCommentController,
                                maxLength: 300,
                                buildCounter: (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => null,
                                minLines: 3,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmittingReview ? null : _submitReview,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: _mainColor,
                                  ),
                                  child: _isSubmittingReview
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text(
                                          'إرسال التقييم',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    if (widget.order.status == 'مكتمل') const SizedBox(height: 12),

                    // Under execution extra fields
                    if (widget.order.status == 'تحت التنفيذ')
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoLabel('موعد التسليم المتوقع'),
                            _infoRow(
                              label: 'موعد التسليم المتوقع',
                              value: widget.order.expectedDeliveryAt == null
                                  ? '-'
                                  : _formatDateOnly(widget.order.expectedDeliveryAt!),
                            ),
                            const SizedBox(height: 10),
                            _infoLabel('قيمة الخدمة المقدرة (SR)'),
                            _infoRow(
                              label: 'قيمة الخدمة المقدرة (SR)',
                              value: _formatMoney(widget.order.serviceAmountSR),
                            ),
                            const SizedBox(height: 10),
                            _infoLabel('المبلغ المستلم (SR)'),
                            _infoRow(
                              label: 'المبلغ المستلم (SR)',
                              value: _formatMoney(widget.order.receivedAmountSR),
                            ),
                            const SizedBox(height: 10),
                            _infoLabel('المبلغ المتبقي (SR)'),
                            _infoRow(
                              label: 'المبلغ المتبقي (SR)',
                              value: _formatMoney(widget.order.remainingAmountSR),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'البيانات المدخلة من مقدم الخدمة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _approveProviderInputs,
                                  onChanged: (v) {
                                    setState(() {
                                      _approveProviderInputs = v ?? false;
                                      if (_approveProviderInputs) _rejectProviderInputs = false;
                                    });
                                  },
                                ),
                                const Text(
                                  'اعتماد',
                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                Checkbox(
                                  value: _rejectProviderInputs,
                                  onChanged: (v) {
                                    setState(() {
                                      _rejectProviderInputs = v ?? false;
                                      if (_rejectProviderInputs) _approveProviderInputs = false;
                                    });
                                  },
                                ),
                                const Text(
                                  'رفض',
                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    if (widget.order.status == 'تحت التنفيذ') const SizedBox(height: 12),

                    // Canceled extra fields
                    if (widget.order.status == 'ملغي')
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoLabel('تاريخ الإلغاء'),
                            _infoRow(
                              label: 'تاريخ الإلغاء',
                              value: widget.order.canceledAt == null
                                  ? '-'
                                  : _formatDateOnly(widget.order.canceledAt!),
                            ),
                            const SizedBox(height: 10),
                            _infoLabel('سبب الإلغاء'),
                            _infoRow(
                              label: 'سبب الإلغاء',
                              value: widget.order.cancelReason ?? '-',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Checkbox(
                                  value: _reopenCanceledOrder,
                                  onChanged: (v) => setState(() => _reopenCanceledOrder = v ?? false),
                                ),
                                const Text(
                                  'إعادة فتح الطلب',
                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.order.status == 'ملغي') const SizedBox(height: 12),

                    // Title section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            title: 'عنوان الطلب',
                            canEdit: true,
                            isEditing: _editTitle,
                            onToggle: () => setState(() => _editTitle = !_editTitle),
                          ),
                          TextField(
                            controller: _titleController,
                            enabled: _editTitle,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Details section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            title: 'تفاصيل الطلب',
                            canEdit: true,
                            isEditing: _editDetails,
                            onToggle: () => setState(() => _editDetails = !_editDetails),
                          ),
                          TextField(
                            controller: _detailsController,
                            enabled: _editDetails,
                            minLines: 4,
                            maxLines: 7,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'تنبيه: سيتم إشعار مقدم الخدمة بأي تعديل في بيانات الطلب.',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Attachments section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'المرفقات',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تعديل المرفقات سيُضاف لاحقاً',
                                        style: TextStyle(fontFamily: 'Cairo'),
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'تعديل',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.order.attachments.isEmpty)
                            Text(
                              'لا يوجد مرفقات',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            )
                          else
                            ...widget.order.attachments.map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.attach_file, size: 18, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        a.name,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      a.type,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reminder section (bell + dashed area look-alike)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notifications_none, color: _mainColor),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'ارسال تنبيه وتذكير للمختص',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reminderController,
                            minLines: 6,
                            maxLines: 10,
                            decoration: InputDecoration(
                              hintText: 'اكتب رسالتك هنا...',
                              hintStyle: const TextStyle(fontFamily: 'Cairo'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: _mainColor,
                        ),
                        child: const Text(
                          'حفظ',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
