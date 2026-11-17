import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/ajra_back_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/services/notification_service.dart';
import '../models/conversation_item.dart';
import 'conversations_screen.dart';

final chatMessagesProvider =
    StreamProvider.family<List<MessageItem>, String>((ref, convId) {
  return ref.watch(messagingRepoProvider).watchMessages(convId);
});

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherParticipantName;
  final String? otherUserId;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherParticipantName,
    this.otherUserId,
    this.isGroup = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  bool _showEmojiPicker = false;

  static const List<String> _emojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
    '😊', '😇', '🙂', '😉', '😌', '😍', '🥰', '😘',
    '😗', '😙', '😚', '😋', '😛', '😜', '🤪', '😝',
    '🤩', '🥳', '😎', '🤓', '🧐', '😏', '😒', '😞',
    '😔', '😟', '😕', '🙁', '😣', '😖', '😫', '😩',
    '🥺', '😢', '😭', '😤', '😠', '😡', '🤯', '😳',
    '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭',
    '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯',
    '😴', '🤤', '😪', '😵', '🤐', '🥴', '🤢', '🤮',
    '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '👍', '👎',
    '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉',
    '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋',
    '🤝', '🙏', '✍️', '💪', '👏', '🙌', '👐', '🤲',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘',
    '💝', '🔥', '✨', '🌟', '💫', '💥', '💯', '✅',
    '☑️', '❌', '⚠️', '❓', '❗', '🎉', '🎊', '🎈',
    '🎂', '🎁', '🏆', '🥇', '⚽', '🏀', '🎵', '🎶',
    '📣', '📢', '🔔', '💬', '💭', '📅', '📍', '📌',
    '💰', '💵', '💳', '🧾', '📈', '🎓', '💼', '🏠',
    '✈️', '🚗', '🏖️', '🌴', '☀️', '🌈', '🇲🇬', '🇲🇺',
  ];

  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _clearNotifications() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      ref.read(messagingRepoProvider).markAsRead(
            conversationId: widget.conversationId,
            userId: user.uid,
          );
      FirebaseFirestore.instance
          .collection(AppConstants.colNotifications)
          .where('recipientUserId', isEqualTo: user.uid)
          .where('entityId', isEqualTo: widget.conversationId)
          .get()
          .then((snap) {
        for (final doc in snap.docs) {
          NotificationService.markAsRead(notificationId: doc.id, userId: user.uid);
        }
      }).catchError((_) {});
    }
  }

  @override
  void initState() {
    super.initState();
    // Marquer comme lu à l'ouverture
    Future.microtask(() => _clearNotifications());
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      final repo = ref.read(messagingRepoProvider);
      await repo.sendMessage(
        conversationId: widget.conversationId,
        senderId: user.uid,
        senderName: user.displayName,
        text: text,
        recipientId: widget.isGroup ? 'group' : widget.otherUserId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'envoi : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.conversationId));

    // Si de nouveaux messages arrivent pendant qu'on consulte la discussion, les marquer comme lus
    ref.listen(chatMessagesProvider(widget.conversationId), (previous, next) {
      if (next.hasValue && next.value != null && next.value!.isNotEmpty) {
        _clearNotifications();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: const AjraBackButton(fallbackRoute: '/conversations'),
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: widget.isGroup
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : AppColors.primaryLight.withValues(alpha: 0.15),
              child: widget.isGroup
                  ? const Icon(Icons.groups_rounded, color: Color(0xFF10B981), size: 20)
                  : Text(
                      widget.otherParticipantName.isNotEmpty
                          ? widget.otherParticipantName[0].toUpperCase()
                          : 'M',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherParticipantName,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.isGroup ? 'Groupe de discussion AJRA' : 'Membre AJRA',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFECE5DD), // Couleur de fond style WhatsApp
        ),
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Démarrez la conversation en envoyant un message ci-dessous.',
                        style: TextStyle(color: AppColors.textMutedLight, fontSize: 13),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == user?.uid;
                      final isSystem = msg.senderId == 'system';
                      final timeStr = DateFormat('HH:mm').format(msg.sentAt);

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg.text,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: Radius.circular(isMe ? 12 : 2),
                              bottomRight: Radius.circular(isMe ? 2 : 12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe && widget.isGroup) ...[
                                Text(
                                  msg.senderName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                msg.text,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF1F2937),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.done_all,
                                        size: 13,
                                        color: Colors.blue.shade600,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              loading: () => const LoadingStateView(message: 'Chargement des messages...'),
              error: (e, _) => ErrorStateView(
                message: e.toString(),
                onRetry: () => ref.refresh(chatMessagesProvider(widget.conversationId)),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard_alt_outlined
                              : Icons.emoji_emotions_outlined,
                          color: _showEmojiPicker ? AppColors.primary : Colors.grey.shade600,
                        ),
                        tooltip: 'Emojis',
                        onPressed: () {
                          setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                          });
                          if (_showEmojiPicker) {
                            _focusNode.unfocus();
                          } else {
                            _focusNode.requestFocus();
                          }
                        },
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            minLines: 1,
                            maxLines: 5,
                            onTap: () {
                              if (_showEmojiPicker) {
                                setState(() => _showEmojiPicker = false);
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'Écrire un message...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, color: AppColors.primary),
                        tooltip: 'Envoyer',
                        onPressed: _isSending ? null : _sendMessage,
                      ),
                    ],
                  ),
                  if (_showEmojiPicker) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: _emojis.length,
                        itemBuilder: (context, index) {
                          final emoji = _emojis[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _insertEmoji(emoji),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
