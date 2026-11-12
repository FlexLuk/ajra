import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../notifications/services/notification_service.dart';
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
  Future<String> createGroupConversation({
    required String groupName,
    required List<String> participantIds,
    required Map<String, String> participantNames,
    required String createdByUserId,
  });
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String? recipientId,
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
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ConversationItem.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return list;
    });
  }

  @override
  Stream<List<MessageItem>> watchMessages(String conversationId) {
    return _messagesCol
        .where('conversationId', isEqualTo: conversationId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MessageItem.fromJson(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return list;
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
    // Vérifier si une conversation 1-to-1 existe déjà entre ces deux membres
    final query = await _convCol
        .where('participantIds', arrayContains: currentUserId)
        .get();

    for (final doc in query.docs) {
      final isGroup = (doc.data()['isGroup'] as bool?) ?? false;
      if (isGroup) continue;
      final list = (doc.data()['participantIds'] as List<dynamic>?)?.map((e) => e.toString()).toList();
      if (list != null && list.contains(otherUserId) && list.length == 2) {
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
      isGroup: false,
    );

    await _convCol.doc(convId).set(newConv.toJson());
    return convId;
  }

  @override
  Future<String> createGroupConversation({
    required String groupName,
    required List<String> participantIds,
    required Map<String, String> participantNames,
    required String createdByUserId,
  }) async {
    final convId = const Uuid().v4();
    final now = DateTime.now();

    final newConv = ConversationItem(
      id: convId,
      participantIds: participantIds,
      participantNames: participantNames,
      participantAvatars: {},
      lastMessageText: 'Groupe créé par les membres',
      lastMessageTime: now,
      lastSenderId: createdByUserId,
      isGroup: true,
      groupName: groupName.trim(),
      groupAdminId: createdByUserId,
    );

    await _convCol.doc(convId).set(newConv.toJson());

    final messageId = const Uuid().v4();
    final initialMessage = MessageItem(
      id: messageId,
      conversationId: convId,
      senderId: 'system',
      senderName: 'AJRA',
      text: 'Bienvenue dans le groupe "$groupName" !',
      sentAt: now,
      isRead: true,
    );
    await _messagesCol.doc(messageId).set(initialMessage.toJson());

    return convId;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
    String? recipientId,
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
    final Map<String, dynamic> updates = {
      'lastMessageText': text.trim(),
      'lastMessageTime': now.toIso8601String(),
      'lastSenderId': senderId,
    };

    // 1. Lire la conversation pour identifier tous les participants
    DocumentSnapshot<Map<String, dynamic>>? convDoc;
    try {
      convDoc = await _convCol.doc(conversationId).get();
    } catch (_) {}

    final convData = convDoc?.data() ?? {};
    final isGroup = (convData['isGroup'] as bool?) ?? false;
    final groupName = (convData['groupName'] as String?) ?? 'Groupe';
    final pIds = (convData['participantIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final Set<String> targetRecipients = {};
    if (recipientId != null && recipientId.isNotEmpty && recipientId != 'group') {
      targetRecipients.add(recipientId);
    }
    for (final p in pIds) {
      if (p != senderId) {
        targetRecipients.add(p);
      }
    }

    for (final recipientUid in targetRecipients) {
      updates['unreadCounts.$recipientUid'] = FieldValue.increment(1);
    }

    try {
      await _convCol.doc(conversationId).update(updates);
    } catch (_) {}

    // 2. Envoyer systématiquement une notification à chaque destinataire
    for (final recipientUid in targetRecipients) {
      try {
        await NotificationService.createUserNotification(
          recipientUserId: recipientUid,
          title: isGroup ? '$senderName ($groupName)' : 'Nouveau message de $senderName',
          body: text.trim().length > 100 ? '${text.trim().substring(0, 100)}...' : text.trim(),
          type: 'message',
          targetRoute: '/chat/$conversationId',
          entityType: 'conversation',
          entityId: conversationId,
          senderUserId: senderId,
          senderName: senderName,
        );
      } catch (_) {}
    }
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
