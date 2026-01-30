class UserSummary {
  final int id;
  final String? username;
  final String displayName;

  const UserSummary({
    required this.id,
    required this.displayName,
    this.username,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final display = (json['display_name'] ?? '').toString().trim();
    final username = (json['username'] ?? '').toString().trim();

    return UserSummary(
      id: json['id'] as int,
      displayName: display.isNotEmpty ? display : (username.isNotEmpty ? username : 'مستخدم'),
      username: username.isEmpty ? null : username,
    );
  }
}
