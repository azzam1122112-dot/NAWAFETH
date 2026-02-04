class ProviderProfile {
  final int id;
  final String? displayName;
  final String? bio;
  final int yearsExperience;
  final String? city;
  final String? phone;
  final String? whatsapp;
  final double? lat;
  final double? lng;
  final bool acceptsUrgent;
  final bool isVerifiedBlue;
  final bool isVerifiedGreen;
  final double ratingAvg;
  final int ratingCount;
  final int followersCount;
  final int likesCount;

  const ProviderProfile({
    required this.id,
    this.displayName,
    this.bio,
    this.yearsExperience = 0,
    this.city,
    this.phone,
    this.whatsapp,
    this.lat,
    this.lng,
    this.acceptsUrgent = false,
    this.isVerifiedBlue = false,
    this.isVerifiedGreen = false,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.followersCount = 0,
    this.likesCount = 0,
  });

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    double? _parseNullableDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ProviderProfile(
      id: json['id'],
      displayName: json['display_name'],
      bio: json['bio'],
      yearsExperience: json['years_experience'] ?? 0,
      city: json['city'],
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      lat: _parseNullableDouble(json['lat']),
      lng: _parseNullableDouble(json['lng']),
      acceptsUrgent: json['accepts_urgent'] ?? false,
      isVerifiedBlue: json['is_verified_blue'] ?? false,
      isVerifiedGreen: json['is_verified_green'] ?? false,
      ratingAvg: (json['rating_avg'] ?? 0.0).toDouble(),
      ratingCount: json['rating_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
    );
  }

  // Placeholder for image until we have it in backend
  String get placeholderImage => 'assets/images/1.png'; 
}
