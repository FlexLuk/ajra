import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';

final userNotificationsProvider = StreamProvider<List<NotificationItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection(AppConstants.colNotifications)
      .where('recipientUserId', whereIn: [user.uid, 'all'])
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs.map((doc) => NotificationItem.fromJson(doc.data(), doc.id)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

/// Fournit le nombre exact de notifications NON LUES par l'utilisateur connecté
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  final notifs = ref.watch(userNotificationsProvider).value ?? [];
  return notifs.where((n) => !n.isReadByUser(user.uid)).length;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final notifsAsync = ref.watch(userNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

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
        title: Text(
          unreadCount > 0 ? 'Notifications ($unreadCount non lue${unreadCount > 1 ? 's' : ''})' : 'Notifications',
        ),
        actions: [
          if (unreadCount > 0 && user != null)
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Tout marquer lu', style: TextStyle(fontSize: 12)),
              onPressed: () {
                final notifs = notifsAsync.value ?? [];
                final unreadIds = notifs
                    .where((n) => !n.isReadByUser(user.uid))
                    .map((n) => n.id)
                    .toList();
                if (unreadIds.isNotEmpty) {
                  NotificationService.markAllAsRead(
                    notificationIds: unreadIds,
                    userId: user.uid,
                  );
                }
              },
            ),
        ],
      ),
      body: notifsAsync.when(
        data: (notifs) {
          if (notifs.isEmpty) {
            return const EmptyStateView(
              icon: Icons.notifications_off_outlined,
              title: 'Aucune notification',
              message: 'Vous êtes à jour ! Vos notifications de cotisations, événements et messages apparaîtront ici.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = notifs[index];
              final isRead = user != null ? n.isReadByUser(user.uid) : n.isRead;
              final dateStr = DateFormat('dd/MM à HH:mm', 'fr_FR').format(n.createdAt);

              IconData iconData = Icons.notifications_active;
              Color iconColor = AppColors.primary;
              if (n.type == 'event') {
                iconData = Icons.event_available;
                iconColor = Colors.orange;
              } else if (n.type == 'message') {
                iconData = Icons.chat_bubble;
                iconColor = AppColors.secondary;
              } else if (n.type == 'post') {
                iconData = Icons.newspaper;
                iconColor = Colors.teal;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  if (user != null && !isRead) {
                    await NotificationService.markAsRead(
                      notificationId: n.id,
                      userId: user.uid,
                    );
                  }
                  if (context.mounted) {
                    if (n.type == 'message' && n.entityId != null && n.entityId!.isNotEmpty) {
                      context.push('/chat/${n.entityId}');
                    } else if (n.targetRoute != null && n.targetRoute!.isNotEmpty) {
                      context.go(n.targetRoute!);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isRead
                          ? AppColors.borderLight
                          : AppColors.primaryLight.withValues(alpha: 0.4),
                      width: isRead ? 1 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isRead ? 0.02 : 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: isRead
                              ? const Color(0xFFF1F5F9)
                              : iconColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRead ? Icons.notifications_none : iconData,
                          size: 20,
                          color: isRead ? AppColors.textMutedLight : iconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                      fontSize: 14,
                                      color: isRead ? Colors.black87 : AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.body,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isRead ? AppColors.textSecondaryLight : const Color(0xFF1E293B),
                                height: 1.35,
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Nouveau - cliquer pour ouvrir',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
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
        loading: () => const LoadingStateView(message: 'Chargement des notifications...'),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.refresh(userNotificationsProvider),
        ),
      ),
    );
  }
}
