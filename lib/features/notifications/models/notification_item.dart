class NotificationItem {
  final String id;
  final String recipientUserId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final String? targetRoute;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.recipientUserId,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    this.targetRoute,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json, String docId) {
    return NotificationItem(
      id: docId,
      recipientUserId: (json['recipientUserId'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'general',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      isRead: (json['isRead'] as bool?) ?? false,
      targetRoute: json['targetRoute'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipientUserId': recipientUserId,
      'type': type,
      'title': title,
      'body': body,
      'isRead': isRead,
      'targetRoute': targetRoute,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
