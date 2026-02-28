/// نموذج رسالة من GET /api/messaging/direct/thread/{id}/messages/
class ChatMessage {
  final int id;
  final int senderId;
  final String senderPhone;
  final String body;
  final String? attachmentUrl;
  final String attachmentType; // audio | image | file | ""
  final String attachmentName;
  final DateTime createdAt;
  final List<int> readByIds;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderPhone,
    required this.body,
    this.attachmentUrl,
    required this.attachmentType,
    required this.attachmentName,
    required this.createdAt,
    required this.readByIds,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      senderId: json['sender'] as int,
      senderPhone: (json['sender_phone'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: (json['attachment_type'] ?? '') as String,
      attachmentName: (json['attachment_name'] ?? '') as String,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      readByIds: (json['read_by_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  /// هل الرسالة تحتوي على مرفق؟
  bool get hasAttachment =>
      attachmentUrl != null && attachmentUrl!.isNotEmpty;

  /// هل هي رسالة نصية فقط؟
  bool get isTextOnly => !hasAttachment && body.isNotEmpty;
}
