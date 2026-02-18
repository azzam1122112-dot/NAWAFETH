class NotificationPreference {
  final String key;
  final String title;
  final String tier;
  final bool enabled;
  final bool locked;

  const NotificationPreference({
    required this.key,
    required this.title,
    required this.tier,
    required this.enabled,
    required this.locked,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      tier: (json['tier'] ?? '').toString(),
      enabled: json['enabled'] == true,
      locked: json['locked'] == true,
    );
  }
}
