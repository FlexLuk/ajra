import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/forms/ajra_currency_field.dart';
import '../../../shared/widgets/forms/ajra_date_field.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/error_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/event_item.dart';
import '../models/event_transaction.dart';
import '../repositories/events_repository.dart';
import '../../notifications/services/notification_service.dart';
import 'event_detail_screen.dart';

final eventsRepoProvider = Provider<BaseEventsRepository>((ref) {
  return FirestoreEventsRepository();
});

final eventsStreamProvider = StreamProvider<List<EventItem>>((ref) {
  return ref.watch(eventsRepoProvider).watchEvents();
});

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  Future<void> _openNewEventDialog() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locController = TextEditingController();
    final budgetController = TextEditingController(text: '0');
    final feeController = TextEditingController(text: '');
    DateTime startDate = DateTime.now().add(const Duration(days: 7));
    String eventType = 'Sortie Détente & Plage';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.event_available, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Créer une sortie / événement')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AjraTextField(
                  controller: titleController,
                  label: 'Titre de l\'événement / Sortie *',
                  hint: 'Nom de la sortie ou événement',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: eventType,
                  decoration: const InputDecoration(labelText: 'Type d\'activité'),
                  items: const [
                    DropdownMenuItem(value: 'Sortie Détente & Plage', child: Text('Sortie Détente & Plage')),
                    DropdownMenuItem(value: 'Rencontre & Échange', child: Text('Rencontre & Échange')),
                    DropdownMenuItem(value: 'Tournoi Sportif', child: Text('Tournoi Sportif')),
                    DropdownMenuItem(value: 'Culturel & Festif', child: Text('Culturel & Festif')),
                    DropdownMenuItem(value: 'Assemblée Générale', child: Text('Assemblée Générale')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => eventType = v);
                  },
                ),
                const SizedBox(height: 12),
                AjraDateField(
                  label: 'Date de l\'événement *',
                  initialDate: startDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  onDateSelected: (d) => startDate = d,
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: locController,
                  label: 'Lieu de rendez-vous / Destination *',
                  hint: 'Lieu ou adresse du rassemblement',
                ),
                const SizedBox(height: 12),
                AjraCurrencyField(
                  controller: feeController,
                  label: 'Participation (PAF) par personne (${AppConstants.currencySymbol})',
                  hint: '0 si gratuit ou montant par personne',
                ),
                const SizedBox(height: 12),
                AjraCurrencyField(
                  controller: budgetController,
                  label: 'Budget prévisionnel global (${AppConstants.currencySymbol})',
                  hint: 'Montant prévisionnel (optionnel)',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: descController,
                  label: 'Description détaillée de la sortie',
                  hint: 'Programme, transport prévu, horaires de départ...',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty || locController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez renseigner au moins le titre et le lieu.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Créer et Publier', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final budget = Money.fromRupees(double.tryParse(budgetController.text.trim()) ?? 0);
      final rawFee = double.tryParse(feeController.text.trim());
      final fee = rawFee != null && rawFee > 0 ? Money.fromRupees(rawFee) : null;

      final event = EventItem(
        id: const Uuid().v4(),
        title: titleController.text.trim(),
        description: descController.text.trim(),
        type: eventType,
        startDate: startDate,
        endDate: startDate.add(const Duration(hours: 6)),
        location: locController.text.trim(),
        organizerUserId: user.uid,
        organizerName: user.displayName,
        estimatedBudget: budget,
        participationFee: fee,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(eventsRepoProvider);
      await repo.createEvent(event);

      // Notification générale envoyée à tous les membres
      final dateFormatted = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(startDate);
      await NotificationService.createBroadcastNotification(
        title: 'Sortie / Événement : ${event.title}',
        body: 'Une nouvelle activité (${event.type}) a été organisée pour le $dateFormatted à ${event.location}.',
        type: 'event',
        targetRoute: '/events',
        entityType: 'event',
        entityId: event.id,
        senderUserId: user.uid,
        senderName: user.displayName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Événement créé et notifié aux membres avec succès.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canManageEvents = user != null && (user.role.isAdmin || user.role.isBureau);
    final eventsAsync = ref.watch(eventsStreamProvider);

    return AppScaffold(
      selectedIndex: 4,
      child: Scaffold(
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
          title: const Text('Événements & Sorties'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: () => ref.refresh(eventsStreamProvider),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bannière explicative
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_outlined, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activités & Sorties de l\'AJRA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Cliquez sur un événement pour voir les participants, le bilan financier et les dépenses de courses.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Bouton Créer Événement pour Admin / Bureau
              if (canManageEvents) ...[
                AjraButton(
                  label: 'Créer une sortie / événement',
                  icon: Icons.add_circle_outline,
                  onPressed: _openNewEventDialog,
                  variant: AjraButtonVariant.primary,
                ),
                const SizedBox(height: 18),
              ],

              // Liste des événements
              eventsAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.event_busy_outlined,
                      title: 'Aucun événement programmé',
                      message: 'Les prochaines sorties de l\'association apparaîtront ici.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final e = events[index];
                      return _buildEventCard(context, e);
                    },
                  );
                },
                loading: () => const LoadingStateView(message: 'Chargement des sorties...'),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.refresh(eventsStreamProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventItem event) {
    final dateStr = DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(event.startDate);
    final user = ref.watch(currentUserProvider);
    final repo = ref.read(eventsRepoProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.type,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  event.status.label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: AppColors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
          if (event.participationFee != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  'PAF : ${event.participationFee!.toFormattedString()} / pers.',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // StreamBuilder pour participation directe SANS ouvrir l'événement
          StreamBuilder<List<EventParticipant>>(
            stream: repo.watchParticipants(event.id),
            builder: (context, snapshot) {
              final participants = snapshot.data ?? [];
              final isRegistered = user != null && participants.any((p) => p.userId == user.uid);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isRegistered ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isRegistered ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isRegistered ? Icons.check_circle_rounded : Icons.people_outline,
                      size: 18,
                      color: isRegistered ? AppColors.success : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRegistered
                            ? 'Inscrit(e) (${participants.length} part.)'
                            : '${participants.length} participant(s)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isRegistered ? FontWeight.bold : FontWeight.w500,
                          color: isRegistered ? AppColors.success : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (user == null) return;
                        if (isRegistered) {
                          await repo.unregisterParticipant(eventId: event.id, userId: user.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Votre participation a été retirée.')),
                            );
                          }
                        } else {
                          await repo.registerParticipant(
                            eventId: event.id,
                            userId: user.uid,
                            userName: user.displayName,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('Vous participez à cet événement !'),
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        isRegistered ? Icons.close : Icons.how_to_reg,
                        size: 14,
                        color: isRegistered ? AppColors.danger : AppColors.primary,
                      ),
                      label: Text(
                        isRegistered ? 'Annuler' : 'Je participe',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isRegistered ? AppColors.danger : AppColors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        side: BorderSide(
                          color: isRegistered ? AppColors.danger.withValues(alpha: 0.4) : AppColors.primary,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.query_stats_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Bilan financier & Courses',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: event),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: const [
                      Text(
                        'Ouvrir',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
