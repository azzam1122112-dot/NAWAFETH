class Offer {
  final int id;
  final int providerId;
  final String providerName;
  final double price;
  final int durationDays;
  final String note;
  final String status;
  final DateTime createdAt;

  const Offer({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.price,
    required this.durationDays,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'],
      providerId: json['provider'],
      providerName: json['provider_name'] ?? 'مقدم خدمة',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      durationDays: json['duration_days'] ?? 0,
      note: json['note'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
