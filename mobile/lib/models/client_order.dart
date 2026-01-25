class ClientOrderAttachment {
  final String name;
  final String type; // e.g. PDF, DOCX, IMG

  const ClientOrderAttachment({
    required this.name,
    required this.type,
  });
}

class ClientOrder {
  final String id; // e.g. R055544
  final String serviceCode; // e.g. @111222
  final DateTime createdAt;
  final String status; // جديد، تحت التنفيذ، مكتمل، ملغي

  final String title;
  final String details;
  final List<ClientOrderAttachment> attachments;

  // Optional fields shown in details depending on status
  final DateTime? expectedDeliveryAt;
  final double? serviceAmountSR;
  final double? receivedAmountSR;
  final double? remainingAmountSR;

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
    required this.title,
    required this.details,
    this.attachments = const [],
    this.expectedDeliveryAt,
    this.serviceAmountSR,
    this.receivedAmountSR,
    this.remainingAmountSR,
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
      switch (status) {
        case 'open':
        case 'pending':
        case 'new':
          return 'جديد';
        case 'sent':
          return 'أُرسل';
        case 'in_progress':
          return 'تحت التنفيذ';
        case 'completed':
          return 'مكتمل';
        case 'canceled':
          return 'ملغي';
        default:
          return status;
      }
    }

    return ClientOrder(
      id: json['id'].toString(),
      serviceCode: json['subcategory_name'] ?? 'General',
      // If date comes as string, parse it.
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      status: mapStatus(json['status'] ?? 'open'),
      title: json['title'] ?? '',
      details: json['description'] ?? '',
    );
  }

  ClientOrder copyWith({
    String? id,
    String? serviceCode,
    DateTime? createdAt,
    String? status,
    String? title,
    String? details,
    List<ClientOrderAttachment>? attachments,
    DateTime? expectedDeliveryAt,
    double? serviceAmountSR,
    double? receivedAmountSR,
    double? remainingAmountSR,
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
      title: title ?? this.title,
      details: details ?? this.details,
      attachments: attachments ?? this.attachments,
      expectedDeliveryAt: expectedDeliveryAt ?? this.expectedDeliveryAt,
      serviceAmountSR: serviceAmountSR ?? this.serviceAmountSR,
      receivedAmountSR: receivedAmountSR ?? this.receivedAmountSR,
      remainingAmountSR: remainingAmountSR ?? this.remainingAmountSR,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      actualServiceAmountSR: actualServiceAmountSR ?? this.actualServiceAmountSR,
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
