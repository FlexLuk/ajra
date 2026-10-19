import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/conversation_item.dart';
import '../repositories/messaging_repository.dart';
import 'chat_screen.dart';

final messagingRepoProvider = Provider<BaseMessagingRepository>((ref) {
  return FirestoreMessagingRepository();
});

final userConversationsProvider = StreamProvider<List<ConversationItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(messagingRepoProvider).watchUserConversations(user.uid);
});

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final convsAsync = ref.watch(userConversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie Privée'),
      ),
      body: convsAsync.when(
        data: (convs) {
          if (convs.isEmpty) {
            return const EmptyStateView(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Aucune conversation',
              message: 'Vos échanges privés avec les autres membres de l\'AJRA apparaîtront ici.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: convs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = convs[index];
              final currentUid = user?.uid ?? '';
              final otherName = c.getOtherParticipantName(currentUid);
              final unread = c.getUnreadCount(currentUid);
              final timeStr = DateFormat('dd/MM HH:mm', 'fr_FR').format(c.lastMessageTime);

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                    child: Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : 'M',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
                      ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.lastMessageText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0 ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
                            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: c.id,
                          otherParticipantName: otherName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const LoadingStateView(message: 'Chargement des conversations...'),
        error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
      ),
    );
  }
}
