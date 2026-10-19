class PostItem {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String authorUserId;
  final String authorName;
  final String? linkedEventId;
  final DateTime publishedAt;
  final bool isArchived;

  const PostItem({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.authorUserId,
    required this.authorName,
    this.linkedEventId,
    required this.publishedAt,
    this.isArchived = false,
  });

  factory PostItem.fromJson(Map<String, dynamic> json, String docId) {
    return PostItem(
      id: docId,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      imageUrl: json['imageUrl'] as String?,
      authorUserId: (json['authorUserId'] as String?) ?? '',
      authorName: (json['authorName'] as String?) ?? 'Bureau AJRA',
      linkedEventId: json['linkedEventId'] as String?,
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? '') ?? DateTime.now(),
      isArchived: (json['isArchived'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'authorUserId': authorUserId,
      'authorName': authorName,
      'linkedEventId': linkedEventId,
      'publishedAt': publishedAt.toIso8601String(),
      'isArchived': isArchived,
    };
  }
}
