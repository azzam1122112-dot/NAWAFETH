class AppNotification {
  final int id;
  final String title;
  final String body;
  final String kind;
  final String? url;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.url,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      url: json['url']?.toString(),
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
