enum NotificationType { questCompleted }

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.questId,
    this.readAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? questId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  static NotificationType _typeFromApi(String? value) {
    switch (value) {
      case 'quest_completed':
        return NotificationType.questCompleted;
      default:
        return NotificationType.questCompleted;
    }
  }

  static DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: _typeFromApi(json['type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      questId: json['quest_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: _parseDate(json['read_at'] as String?),
    );
  }
}

