class ProviderProfile {
  final int id;
  final String? displayName;
  final String? username;
  final String? bio;
  final int yearsExperience;
  final String? city;
  final String? phone;
  final String? whatsapp;
  final double? lat;
  final double? lng;
  final bool isOnline;
  final bool acceptsUrgent;
  final bool isVerifiedBlue;
  final bool isVerifiedGreen;
  final String? imageUrl;
  final double ratingAvg;
  final int ratingCount;
  final int? completedRequests;
  final int followersCount;
  final int followingCount;
  final int likesCount;

  const ProviderProfile({
    required this.id,
    this.displayName,
    this.username,
    this.bio,
    this.yearsExperience = 0,
    this.city,
    this.phone,
    this.whatsapp,
    this.lat,
    this.lng,
    this.isOnline = false,
    this.acceptsUrgent = false,
    this.isVerifiedBlue = false,
    this.isVerifiedGreen = false,
    this.imageUrl,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.completedRequests,
    this.followersCount = 0,
    this.followingCount = 0,
    this.likesCount = 0,
  });

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    double? parseNullableDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    double parseDouble(dynamic v, {double fallback = 0.0}) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    int parseInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return ProviderProfile(
      id: parseInt(json['id']),
      displayName: json['display_name'],
      username: json['username']?.toString(),
      bio: json['bio'],
      yearsExperience: parseInt(json['years_experience']),
      city: json['city'],
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      lat: parseNullableDouble(json['lat']),
      lng: parseNullableDouble(json['lng']),
      isOnline: (json['is_online'] == true),
      acceptsUrgent: json['accepts_urgent'] ?? false,
      isVerifiedBlue: json['is_verified_blue'] ?? false,
      isVerifiedGreen: json['is_verified_green'] ?? false,
      imageUrl: (json['logo'] ??
              json['logo_url'] ??
              json['avatar'] ??
              json['avatar_url'] ??
              json['image'] ??
              json['image_url'] ??
              json['profile_image'] ??
              json['profile_image_url'])
          ?.toString(),
      ratingAvg: parseDouble(json['rating_avg']),
      ratingCount: parseInt(json['rating_count']),
      completedRequests: json['completed_requests'] == null
          ? (json['completed_orders_count'] == null
              ? null
              : parseInt(json['completed_orders_count']))
          : parseInt(json['completed_requests']),
      followersCount: parseInt(json['followers_count']),
      followingCount: parseInt(json['following_count']),
      likesCount: parseInt(json['likes_count']),
    );
  }
}
