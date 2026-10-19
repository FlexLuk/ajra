class ConversationItem {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantAvatars;
  final String lastMessageText;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final Map<String, int> unreadCounts;

  const ConversationItem({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    this.participantAvatars = const {},
    required this.lastMessageText,
    required this.lastMessageTime,
    required this.lastSenderId,
    this.unreadCounts = const {},
  });

  String getOtherParticipantName(String currentUserId) {
    for (final entry in participantNames.entries) {
      if (entry.key != currentUserId) return entry.value;
    }
    return 'Membre AJRA';
  }

  String? getOtherParticipantAvatar(String currentUserId) {
    for (final entry in participantAvatars.entries) {
      if (entry.key != currentUserId) return entry.value;
    }
    return null;
  }

  int getUnreadCount(String currentUserId) {
    return unreadCounts[currentUserId] ?? 0;
  }

  factory ConversationItem.fromJson(Map<String, dynamic> json, String docId) {
    return ConversationItem(
      id: docId,
      participantIds: (json['participantIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      participantNames: (json['participantNames'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      participantAvatars: (json['participantAvatars'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v?.toString()),
          ) ??
          {},
      lastMessageText: (json['lastMessageText'] as String?) ?? '',
      lastMessageTime:
          DateTime.tryParse(json['lastMessageTime']?.toString() ?? '') ?? DateTime.now(),
      lastSenderId: (json['lastSenderId'] as String?) ?? '',
      unreadCounts: (json['unreadCounts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
      'lastMessageText': lastMessageText,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'lastSenderId': lastSenderId,
      'unreadCounts': unreadCounts,
    };
  }
}

class MessageItem {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final bool isRead;

  const MessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.isRead = false,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json, String docId) {
    return MessageItem(
      id: docId,
      conversationId: (json['conversationId'] as String?) ?? '',
      senderId: (json['senderId'] as String?) ?? '',
      senderName: (json['senderName'] as String?) ?? 'Membre',
      text: (json['text'] as String?) ?? '',
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ?? DateTime.now(),
      isRead: (json['isRead'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'sentAt': sentAt.toIso8601String(),
      'isRead': isRead,
    };
  }
}
