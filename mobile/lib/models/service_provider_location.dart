class ServiceProviderLocation {
  final String id;
  final String name;
  final String category;           // "صيانة المركبات"
  final String subCategory;        // "ميكانيكا"
  final double latitude;
  final double longitude;
  final double rating;
  final int operationsCount;
  final bool isAvailable;          // متاح الآن؟
  final bool isUrgentEnabled;      // يقبل طلبات عاجلة؟
  final String? profileImage;
  final double? distanceFromUser;  // محسوبة ديناميكياً (بالكيلومتر)
  
  // بيانات إضافية
  final String phoneNumber;
  final List<String> urgentServices;  // الخدمات العاجلة المتاحة
  final int responseTime;             // متوسط وقت الرد (بالدقائق)
  final bool verified;                // موثق؟

  ServiceProviderLocation({
    required this.id,
    required this.name,
    required this.category,
    required this.subCategory,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.operationsCount,
    this.isAvailable = true,
    this.isUrgentEnabled = true,
    this.profileImage,
    this.distanceFromUser,
    required this.phoneNumber,
    this.urgentServices = const [],
    this.responseTime = 15,
    this.verified = false,
  });

  // ✅ إنشاء من JSON
  factory ServiceProviderLocation.fromJson(Map<String, dynamic> json) {
    return ServiceProviderLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      subCategory: json['subCategory'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      operationsCount: json['operationsCount'] ?? 0,
      isAvailable: json['isAvailable'] ?? true,
      isUrgentEnabled: json['isUrgentEnabled'] ?? true,
      profileImage: json['profileImage'],
      distanceFromUser: json['distanceFromUser']?.toDouble(),
      phoneNumber: json['phoneNumber'] ?? '',
      urgentServices: List<String>.from(json['urgentServices'] ?? []),
      responseTime: json['responseTime'] ?? 15,
      verified: json['verified'] ?? false,
    );
  }

  // ✅ تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'subCategory': subCategory,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'operationsCount': operationsCount,
      'isAvailable': isAvailable,
      'isUrgentEnabled': isUrgentEnabled,
      'profileImage': profileImage,
      'distanceFromUser': distanceFromUser,
      'phoneNumber': phoneNumber,
      'urgentServices': urgentServices,
      'responseTime': responseTime,
      'verified': verified,
    };
  }

  // ✅ نسخ مع تعديلات
  ServiceProviderLocation copyWith({
    String? id,
    String? name,
    String? category,
    String? subCategory,
    double? latitude,
    double? longitude,
    double? rating,
    int? operationsCount,
    bool? isAvailable,
    bool? isUrgentEnabled,
    String? profileImage,
    double? distanceFromUser,
    String? phoneNumber,
    List<String>? urgentServices,
    int? responseTime,
    bool? verified,
  }) {
    return ServiceProviderLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      operationsCount: operationsCount ?? this.operationsCount,
      isAvailable: isAvailable ?? this.isAvailable,
      isUrgentEnabled: isUrgentEnabled ?? this.isUrgentEnabled,
      profileImage: profileImage ?? this.profileImage,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      urgentServices: urgentServices ?? this.urgentServices,
      responseTime: responseTime ?? this.responseTime,
      verified: verified ?? this.verified,
    );
  }
}
