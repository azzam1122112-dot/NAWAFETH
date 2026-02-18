class AppNotification {
  final int id;
  final String title;
  final String body;
  final String kind;
  final String? url;
  final bool isRead;
  final bool isPinned;
  final bool isFollowUp;
  final bool isUrgent;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.url,
    required this.isRead,
    required this.isPinned,
    required this.isFollowUp,
    required this.isUrgent,
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
      isPinned: (json['is_pinned'] as bool?) ?? false,
      isFollowUp: (json['is_follow_up'] as bool?) ?? false,
      isUrgent: (json['is_urgent'] as bool?) ?? false,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
