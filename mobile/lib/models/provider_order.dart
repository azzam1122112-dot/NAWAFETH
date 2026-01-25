class ProviderOrderAttachment {
  final String name;
  final String type; // e.g. PDF, DOCX, IMG

  const ProviderOrderAttachment({
    required this.name,
    required this.type,
  });
}

class ProviderOrder {
  final String id; // e.g. R012345
  final String serviceCode; // e.g. @111222
  final DateTime createdAt;
  final String status; // جديد، تحت التنفيذ، مكتمل، ملغي

  final String clientName;
  final String clientHandle; // e.g. @xxxxyy
  final String? clientPhone;
  final String? clientCity;

  final String title;
  final String details;
  final List<ProviderOrderAttachment> attachments;

  // Optional fields shown in details depending on status
  final DateTime? expectedDeliveryAt;
  final double? estimatedServiceAmountSR;
  final double? receivedAmountSR;
  final double? remainingAmountSR;

  final DateTime? deliveredAt;
  final double? actualServiceAmountSR;

  final DateTime? canceledAt;
  final String? cancelReason;

  const ProviderOrder({
    required this.id,
    required this.serviceCode,
    required this.createdAt,
    required this.status,
    required this.clientName,
    required this.clientHandle,
    this.clientPhone,
    this.clientCity,
    required this.title,
    required this.details,
    this.attachments = const [],
    this.expectedDeliveryAt,
    this.estimatedServiceAmountSR,
    this.receivedAmountSR,
    this.remainingAmountSR,
    this.deliveredAt,
    this.actualServiceAmountSR,
    this.canceledAt,
    this.cancelReason,
  });

  ProviderOrder copyWith({
    String? id,
    String? serviceCode,
    DateTime? createdAt,
    String? status,
    String? clientName,
    String? clientHandle,
    String? clientPhone,
    String? clientCity,
    String? title,
    String? details,
    List<ProviderOrderAttachment>? attachments,
    DateTime? expectedDeliveryAt,
    double? estimatedServiceAmountSR,
    double? receivedAmountSR,
    double? remainingAmountSR,
    DateTime? deliveredAt,
    double? actualServiceAmountSR,
    DateTime? canceledAt,
    String? cancelReason,
  }) {
    return ProviderOrder(
      id: id ?? this.id,
      serviceCode: serviceCode ?? this.serviceCode,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      clientHandle: clientHandle ?? this.clientHandle,
      clientPhone: clientPhone ?? this.clientPhone,
      clientCity: clientCity ?? this.clientCity,
      title: title ?? this.title,
      details: details ?? this.details,
      attachments: attachments ?? this.attachments,
      expectedDeliveryAt: expectedDeliveryAt ?? this.expectedDeliveryAt,
      estimatedServiceAmountSR:
          estimatedServiceAmountSR ?? this.estimatedServiceAmountSR,
      receivedAmountSR: receivedAmountSR ?? this.receivedAmountSR,
      remainingAmountSR: remainingAmountSR ?? this.remainingAmountSR,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      actualServiceAmountSR: actualServiceAmountSR ?? this.actualServiceAmountSR,
      canceledAt: canceledAt ?? this.canceledAt,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }
}
