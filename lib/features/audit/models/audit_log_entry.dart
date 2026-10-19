class AuditLogEntry {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.timestamp,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json, String docId) {
    return AuditLogEntry(
      id: docId,
      userId: (json['userId'] as String?) ?? '',
      userName: (json['userName'] as String?) ?? 'Inconnu',
      userRole: (json['userRole'] as String?) ?? 'MEMBRE',
      action: (json['action'] as String?) ?? '',
      entityType: (json['entityType'] as String?) ?? '',
      entityId: (json['entityId'] as String?) ?? '',
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
