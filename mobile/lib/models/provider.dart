class ProviderProfile {
  final int id;
  final String? displayName;
  final String? bio;
  final int yearsExperience;
  final String? city;
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
    this.acceptsUrgent = false,
    this.isVerifiedBlue = false,
    this.isVerifiedGreen = false,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.followersCount = 0,
    this.likesCount = 0,
  });

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    return ProviderProfile(
      id: json['id'],
      displayName: json['display_name'],
      bio: json['bio'],
      yearsExperience: json['years_experience'] ?? 0,
      city: json['city'],
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
