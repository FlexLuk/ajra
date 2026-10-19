import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../models/conversation_item.dart';

abstract class BaseMessagingRepository {
  Stream<List<ConversationItem>> watchUserConversations(String userId);
  Stream<List<MessageItem>> watchMessages(String conversationId);
  Future<String> startOrGetConversation({
    required String currentUserId,
    required String currentUserName,
    String? currentUserAvatar,
    required String otherUserId,
    required String otherUserName,
    String? otherUserAvatar,
  });
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    required String recipientId,
  });
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  });
}

class FirestoreMessagingRepository implements BaseMessagingRepository {
  final FirebaseFirestore _firestore;

  FirestoreMessagingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _convCol =>
      _firestore.collection(AppConstants.colConversations);

  CollectionReference<Map<String, dynamic>> get _messagesCol =>
      _firestore.collection(AppConstants.colMessages);

  @override
  Stream<List<ConversationItem>> watchUserConversations(String userId) {
    return _convCol
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ConversationItem.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Stream<List<MessageItem>> watchMessages(String conversationId) {
    return _messagesCol
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageItem.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<String> startOrGetConversation({
    required String currentUserId,
    required String currentUserName,
    String? currentUserAvatar,
    required String otherUserId,
    required String otherUserName,
    String? otherUserAvatar,
  }) async {
    // Vérifier si une conversation existe déjà entre ces deux membres
    final query = await _convCol
        .where('participantIds', arrayContains: currentUserId)
        .get();

    for (final doc in query.docs) {
      final list = (doc.data()['participantIds'] as List<dynamic>?)?.map((e) => e.toString()).toList();
      if (list != null && list.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Créer une nouvelle conversation
    final convId = const Uuid().v4();
    final now = DateTime.now();

    final newConv = ConversationItem(
      id: convId,
      participantIds: [currentUserId, otherUserId],
      participantNames: {
        currentUserId: currentUserName,
        otherUserId: otherUserName,
      },
      participantAvatars: {
        currentUserId: currentUserAvatar,
        otherUserId: otherUserAvatar,
      },
      lastMessageText: 'Conversation démarrée',
      lastMessageTime: now,
      lastSenderId: currentUserId,
    );

    await _convCol.doc(convId).set(newConv.toJson());
    return convId;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    required String recipientId,
  }) async {
    final now = DateTime.now();
    final messageId = const Uuid().v4();

    final message = MessageItem(
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      text: text.trim(),
      sentAt: now,
      isRead: false,
    );

    await _messagesCol.doc(messageId).set(message.toJson());

    // Mettre à jour le résumé de conversation
    await _convCol.doc(conversationId).update({
      'lastMessageText': text.trim(),
      'lastMessageTime': now.toIso8601String(),
      'lastSenderId': senderId,
      'unreadCounts.$recipientId': FieldValue.increment(1),
    });
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    await _convCol.doc(conversationId).update({
      'unreadCounts.$userId': 0,
    });
  }
}
