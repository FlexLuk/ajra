class NotificationItem {
  final String id;
  final String recipientUserId;
  final String? senderUserId;
  final String? senderName;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final List<String> readBy;
  final String? targetRoute;
  final String? entityType;
  final String? entityId;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.recipientUserId,
    this.senderUserId,
    this.senderName,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    this.readBy = const [],
    this.targetRoute,
    this.entityType,
    this.entityId,
    required this.createdAt,
  });

  bool isReadByUser(String userId) {
    if (recipientUserId == 'all') {
      return readBy.contains(userId);
    }
    if (isRead) return true;
    if (readBy.contains(userId)) return true;
    return false;
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json, String docId) {
    final rawReadBy = json['readBy'];
    final List<String> readByList = rawReadBy is List
        ? rawReadBy.map((e) => e.toString()).toList()
        : <String>[];

    return NotificationItem(
      id: docId,
      recipientUserId: (json['recipientUserId'] as String?) ?? '',
      senderUserId: json['senderUserId'] as String?,
      senderName: json['senderName'] as String?,
      type: (json['type'] as String?) ?? 'general',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      isRead: (json['isRead'] as bool?) ?? false,
      readBy: readByList,
      targetRoute: json['targetRoute'] as String?,
      entityType: json['entityType'] as String?,
      entityId: json['entityId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipientUserId': recipientUserId,
      'senderUserId': senderUserId,
      'senderName': senderName,
      'type': type,
      'title': title,
      'body': body,
      'isRead': isRead,
      'readBy': readBy,
      'targetRoute': targetRoute,
      'entityType': entityType,
      'entityId': entityId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
