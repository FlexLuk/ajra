import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../membership/models/member_profile.dart';
import '../../membership/providers/membership_provider.dart';
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

  Future<void> _startDirectChat(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final members = ref.read(allMembersProvider).value ?? [];
    final eligibleMembers = members.where((m) => m.userId != user.uid).toList();

    if (eligibleMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun autre membre disponible pour chatter.')),
      );
      return;
    }

    final selectedMember = await showDialog<MemberProfile>(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = eligibleMembers
                .where((m) =>
                    m.fullName.toLowerCase().contains(query.toLowerCase()) ||
                    m.email.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return AlertDialog(
              title: const Text('Nouveau message privé'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un membre...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (val) => setModalState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                              backgroundImage:
                                  m.photoUrl != null ? NetworkImage(m.photoUrl!) : null,
                              child: m.photoUrl == null
                                  ? Text(
                                      m.firstName.isNotEmpty
                                          ? m.firstName[0].toUpperCase()
                                          : 'M',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary),
                                    )
                                  : null,
                            ),
                            title: Text(m.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(m.email, style: const TextStyle(fontSize: 12)),
                            onTap: () => Navigator.pop(ctx, m),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedMember != null && context.mounted) {
      final repo = ref.read(messagingRepoProvider);
      final convId = await repo.startOrGetConversation(
        currentUserId: user.uid,
        currentUserName: user.displayName,
        currentUserAvatar: user.photoUrl,
        otherUserId: selectedMember.userId,
        otherUserName: selectedMember.fullName,
        otherUserAvatar: selectedMember.photoUrl,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId,
              otherParticipantName: selectedMember.fullName,
              otherUserId: selectedMember.userId,
              isGroup: false,
            ),
          ),
        );
      }
    }
  }

  Future<void> _createGroupChat(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final members = ref.read(allMembersProvider).value ?? [];
    final eligibleMembers = members.where((m) => m.userId != user.uid).toList();

    final groupNameController = TextEditingController();
    final Set<String> selectedMemberIds = {};
    final Map<String, String> selectedMemberNames = {
      user.uid: user.displayName,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = eligibleMembers
                .where((m) =>
                    m.fullName.toLowerCase().contains(filter.toLowerCase()) ||
                    m.email.toLowerCase().contains(filter.toLowerCase()))
                .toList();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.groups_rounded, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Créer un groupe AJRA')),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight: MediaQuery.of(context).size.height * 0.58,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    TextField(
                      controller: groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du groupe *',
                        hintText: 'ex: Commission Fêtes & Sorties',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Sélectionner les membres participants (${selectedMemberIds.length} sélectionné(s)) :',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filtrer les membres...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                      onChanged: (val) => setModalState(() => filter = val),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final m = filtered[index];
                          final isSelected = selectedMemberIds.contains(m.userId);

                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            title: Text(m.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            subtitle: Text(m.email, style: const TextStyle(fontSize: 11.5)),
                            secondary: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                              backgroundImage:
                                  m.photoUrl != null ? NetworkImage(m.photoUrl!) : null,
                              child: m.photoUrl == null
                                  ? Text(
                                      m.firstName.isNotEmpty
                                          ? m.firstName[0].toUpperCase()
                                          : 'M',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primary),
                                    )
                                  : null,
                            ),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  selectedMemberIds.add(m.userId);
                                  selectedMemberNames[m.userId] = m.fullName;
                                } else {
                                  selectedMemberIds.remove(m.userId);
                                  selectedMemberNames.remove(m.userId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (groupNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez renseigner un nom pour le groupe.')),
                      );
                      return;
                    }
                    if (selectedMemberIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Veuillez sélectionner au moins un membre pour le groupe.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Créer le groupe'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final repo = ref.read(messagingRepoProvider);
      final participantIds = [user.uid, ...selectedMemberIds];

      final convId = await repo.createGroupConversation(
        groupName: groupNameController.text.trim(),
        participantIds: participantIds,
        participantNames: selectedMemberNames,
        createdByUserId: user.uid,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId,
              otherParticipantName: groupNameController.text.trim(),
              isGroup: true,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final convsAsync = ref.watch(userConversationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Discussions & Groupes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Nouveau message direct',
            onPressed: () => _startDirectChat(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Créer un groupe de discussion',
            onPressed: () => _createGroupChat(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat),
        label: const Text('Nouveau chat / Groupe'),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(Icons.person, color: AppColors.primary),
                    ),
                    title: const Text('Message privé (1-à-1)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Démarrer une discussion avec un membre'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startDirectChat(context, ref);
                    },
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFD1FAE5),
                      child: Icon(Icons.groups_rounded, color: Color(0xFF10B981)),
                    ),
                    title: const Text('Nouveau groupe',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Créer un groupe avec plusieurs membres'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _createGroupChat(context, ref);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: convsAsync.when(
        data: (convs) {
          if (convs.isEmpty) {
            return EmptyStateView(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Aucune discussion',
              message:
                  'Échangez avec les autres membres ou créez un groupe comme sur WhatsApp !',
              actionLabel: 'Démarrer une discussion',
              onAction: () => _startDirectChat(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: convs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = convs[index];
              final currentUid = user?.uid ?? '';
              final displayName = c.getDisplayName(currentUid);
              final unread = c.getUnreadCount(currentUid);
              final timeStr = DateFormat('dd/MM HH:mm', 'fr_FR').format(c.lastMessageTime);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.8)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: c.isGroup
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : AppColors.primaryLight.withValues(alpha: 0.15),
                    child: c.isGroup
                        ? const Icon(Icons.groups_rounded, color: Color(0xFF10B981), size: 24)
                        : Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary),
                          ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
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
                      if (c.isGroup) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${c.participantIds.length} membres',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          c.lastMessageText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? AppColors.textPrimaryLight
                                : AppColors.textSecondaryLight,
                            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                          otherParticipantName: displayName,
                          otherUserId: (user != null && !c.isGroup) ? c.getOtherParticipantId(user.uid) : null,
                          isGroup: c.isGroup,
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
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.refresh(userConversationsProvider),
        ),
      ),
    );
  }
}
