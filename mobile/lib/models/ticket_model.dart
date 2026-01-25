class Ticket {
  final String id;
  final DateTime createdAt;
  final String status; // "جديد", "تحت المعالجة", "مغلق"
  final String supportTeam;
  final String title;
  final String description;
  final List<String> attachments;
  final List<TicketReply> replies;
  final DateTime? lastUpdate;

  Ticket({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.supportTeam,
    required this.title,
    required this.description,
    this.attachments = const [],
    this.replies = const [],
    this.lastUpdate,
  });

  Ticket copyWith({
    String? id,
    DateTime? createdAt,
    String? status,
    String? supportTeam,
    String? title,
    String? description,
    List<String>? attachments,
    List<TicketReply>? replies,
    DateTime? lastUpdate,
  }) {
    return Ticket(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      supportTeam: supportTeam ?? this.supportTeam,
      title: title ?? this.title,
      description: description ?? this.description,
      attachments: attachments ?? this.attachments,
      replies: replies ?? this.replies,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

class TicketReply {
  final String from; // "user" أو "platform"
  final String message;
  final DateTime timestamp;

  TicketReply({
    required this.from,
    required this.message,
    required this.timestamp,
  });
}
