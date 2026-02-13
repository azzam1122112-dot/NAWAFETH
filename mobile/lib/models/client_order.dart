class ClientOrderAttachment {
  final String name;
  final String type; // e.g. PDF, DOCX, IMG

  const ClientOrderAttachment({required this.name, required this.type});
}

class ClientOrder {
  final String id; // e.g. R055544
  final String serviceCode; // e.g. @111222
  final DateTime createdAt;
  final String status; // جديد، تحت التنفيذ، مكتمل، ملغي

  final String requestType; // normal | urgent | competitive
  final String city;
  final String? providerName;

  final String title;
  final String details;
  final List<ClientOrderAttachment> attachments;

  // Optional fields shown in details depending on status
  final DateTime? expectedDeliveryAt;
  final double? serviceAmountSR;
  final double? receivedAmountSR;
  final double? remainingAmountSR;
  final bool? providerInputsApproved;
  final DateTime? providerInputsDecidedAt;
  final String? providerInputsDecisionNote;

  // Completed order fields
  final DateTime? deliveredAt;
  final double? actualServiceAmountSR;

  // Service rating (for completed orders)
  final double? ratingResponseSpeed;
  final double? ratingCostValue;
  final double? ratingQuality;
  final double? ratingCredibility;
  final double? ratingOnTime;
  final String? ratingComment;
  final List<ClientOrderAttachment> ratingAttachments;

  final DateTime? canceledAt;
  final String? cancelReason;

  const ClientOrder({
    required this.id,
    required this.serviceCode,
    required this.createdAt,
    required this.status,
    this.requestType = 'normal',
    this.city = '',
    this.providerName,
    required this.title,
    required this.details,
    this.attachments = const [],
    this.expectedDeliveryAt,
    this.serviceAmountSR,
    this.receivedAmountSR,
    this.remainingAmountSR,
    this.providerInputsApproved,
    this.providerInputsDecidedAt,
    this.providerInputsDecisionNote,
    this.deliveredAt,
    this.actualServiceAmountSR,
    this.ratingResponseSpeed,
    this.ratingCostValue,
    this.ratingQuality,
    this.ratingCredibility,
    this.ratingOnTime,
    this.ratingComment,
    this.ratingAttachments = const [],
    this.canceledAt,
    this.cancelReason,
  });

  factory ClientOrder.fromJson(Map<String, dynamic> json) {
    String mapStatus(String status) {
      switch ((status).toString().trim().toLowerCase()) {
        case 'open':
        case 'pending':
        case 'new':
        case 'sent':
          return 'جديد';
        case 'accepted':
          return 'بانتظار اعتماد العميل';
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

    final statusLabel = (json['status_label'] ?? '').toString().trim();
    return ClientOrder(
      id: json['id'].toString(),
      serviceCode: json['subcategory_name'] ?? 'General',
      // If date comes as string, parse it.
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      status: statusLabel.isNotEmpty
          ? statusLabel
          : mapStatus(json['status'] ?? 'open'),
      requestType: (json['request_type'] ?? 'normal').toString(),
      city: (json['city'] ?? '').toString(),
      providerName: (json['provider_name'] ?? '').toString().trim().isEmpty
          ? null
          : (json['provider_name'] ?? '').toString(),
      title: json['title'] ?? '',
      details: json['description'] ?? '',
      expectedDeliveryAt: DateTime.tryParse(
        (json['expected_delivery_at'] ?? '').toString(),
      ),
      serviceAmountSR: double.tryParse(
        (json['estimated_service_amount'] ?? '').toString(),
      ),
      receivedAmountSR: double.tryParse(
        (json['received_amount'] ?? '').toString(),
      ),
      remainingAmountSR: double.tryParse(
        (json['remaining_amount'] ?? '').toString(),
      ),
      providerInputsApproved: json['provider_inputs_approved'] is bool
          ? json['provider_inputs_approved'] as bool
          : null,
      providerInputsDecidedAt: DateTime.tryParse(
        (json['provider_inputs_decided_at'] ?? '').toString(),
      ),
      providerInputsDecisionNote:
          (json['provider_inputs_decision_note'] ?? '')
              .toString()
              .trim()
              .isEmpty
          ? null
          : (json['provider_inputs_decision_note'] ?? '').toString(),
      deliveredAt: DateTime.tryParse((json['delivered_at'] ?? '').toString()),
      actualServiceAmountSR: double.tryParse(
        (json['actual_service_amount'] ?? '').toString(),
      ),
      canceledAt: DateTime.tryParse((json['canceled_at'] ?? '').toString()),
      cancelReason: (json['cancel_reason'] ?? '').toString().trim().isEmpty
          ? null
          : (json['cancel_reason'] ?? '').toString(),
    );
  }

  ClientOrder copyWith({
    String? id,
    String? serviceCode,
    DateTime? createdAt,
    String? status,
    String? requestType,
    String? city,
    String? providerName,
    String? title,
    String? details,
    List<ClientOrderAttachment>? attachments,
    DateTime? expectedDeliveryAt,
    double? serviceAmountSR,
    double? receivedAmountSR,
    double? remainingAmountSR,
    bool? providerInputsApproved,
    DateTime? providerInputsDecidedAt,
    String? providerInputsDecisionNote,
    DateTime? deliveredAt,
    double? actualServiceAmountSR,
    double? ratingResponseSpeed,
    double? ratingCostValue,
    double? ratingQuality,
    double? ratingCredibility,
    double? ratingOnTime,
    String? ratingComment,
    List<ClientOrderAttachment>? ratingAttachments,
    DateTime? canceledAt,
    String? cancelReason,
  }) {
    return ClientOrder(
      id: id ?? this.id,
      serviceCode: serviceCode ?? this.serviceCode,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      requestType: requestType ?? this.requestType,
      city: city ?? this.city,
      providerName: providerName ?? this.providerName,
      title: title ?? this.title,
      details: details ?? this.details,
      attachments: attachments ?? this.attachments,
      expectedDeliveryAt: expectedDeliveryAt ?? this.expectedDeliveryAt,
      serviceAmountSR: serviceAmountSR ?? this.serviceAmountSR,
      receivedAmountSR: receivedAmountSR ?? this.receivedAmountSR,
      remainingAmountSR: remainingAmountSR ?? this.remainingAmountSR,
      providerInputsApproved:
          providerInputsApproved ?? this.providerInputsApproved,
      providerInputsDecidedAt:
          providerInputsDecidedAt ?? this.providerInputsDecidedAt,
      providerInputsDecisionNote:
          providerInputsDecisionNote ?? this.providerInputsDecisionNote,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      actualServiceAmountSR:
          actualServiceAmountSR ?? this.actualServiceAmountSR,
      ratingResponseSpeed: ratingResponseSpeed ?? this.ratingResponseSpeed,
      ratingCostValue: ratingCostValue ?? this.ratingCostValue,
      ratingQuality: ratingQuality ?? this.ratingQuality,
      ratingCredibility: ratingCredibility ?? this.ratingCredibility,
      ratingOnTime: ratingOnTime ?? this.ratingOnTime,
      ratingComment: ratingComment ?? this.ratingComment,
      ratingAttachments: ratingAttachments ?? this.ratingAttachments,
      canceledAt: canceledAt ?? this.canceledAt,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }
}
