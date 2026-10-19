import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/forms/ajra_currency_field.dart';
import '../../../shared/widgets/forms/ajra_date_field.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/indicators/status_badge.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../fundraising/models/fundraising_campaign.dart';
import '../models/event_item.dart';
import '../repositories/events_repository.dart';

final eventsRepoProvider = Provider<BaseEventsRepository>((ref) {
  return FirestoreEventsRepository();
});

final eventsStreamProvider = StreamProvider<List<EventItem>>((ref) {
  return ref.watch(eventsRepoProvider).watchEvents();
});

final campaignsStreamProvider = StreamProvider<List<FundraisingCampaign>>((ref) {
  return ref.watch(eventsRepoProvider).watchCampaigns();
});

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openNewEventDialog() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locController = TextEditingController();
    final budgetController = TextEditingController(text: '0');
    DateTime startDate = DateTime.now().add(const Duration(days: 7));
    String eventType = 'Rencontre & Échange';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Créer un événement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AjraTextField(
                  controller: titleController,
                  label: 'Titre de l\'événement *',
                  hint: 'ex: Assemblée Générale Annuelle 2026',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: eventType,
                  decoration: const InputDecoration(labelText: 'Type d\'événement'),
                  items: const [
                    DropdownMenuItem(value: 'Rencontre & Échange', child: Text('Rencontre & Échange')),
                    DropdownMenuItem(value: 'Assemblée Générale', child: Text('Assemblée Générale')),
                    DropdownMenuItem(value: 'Culturel & Festif', child: Text('Culturel & Festif')),
                    DropdownMenuItem(value: 'Tournoi Sportif', child: Text('Tournoi Sportif')),
                    DropdownMenuItem(value: 'Action Solidaire', child: Text('Action Solidaire')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => eventType = v);
                  },
                ),
                const SizedBox(height: 12),
                AjraDateField(
                  label: 'Date de l\'événement',
                  initialDate: startDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  onDateSelected: (d) => startDate = d,
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: locController,
                  label: 'Lieu *',
                  hint: 'ex: Salle municipale de Quatre Bornes',
                ),
                const SizedBox(height: 12),
                AjraCurrencyField(
                  controller: budgetController,
                  label: 'Budget prévisionnel (MUR)',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: descController,
                  label: 'Description détaillée',
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publier l\'événement'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      if (titleController.text.trim().isEmpty) return;
      final budget = Money.fromRupees(double.tryParse(budgetController.text.trim()) ?? 0);

      final event = EventItem(
        id: const Uuid().v4(),
        title: titleController.text.trim(),
        description: descController.text.trim(),
        type: eventType,
        startDate: startDate,
        endDate: startDate.add(const Duration(hours: 4)),
        location: locController.text.trim(),
        organizerUserId: user.uid,
        organizerName: user.displayName,
        estimatedBudget: budget,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(eventsRepoProvider);
      await repo.createEvent(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Événement créé et publié avec succès.'),
          ),
        );
      }
    }
  }

  Future<void> _openDonateDialog(FundraisingCampaign campaign) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final amountController = TextEditingController();
    final refController = TextEditingController();
    String paymentMode = 'Virement bancaire MCB';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Participer à la collecte :\n${campaign.title}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Objectif : ${campaign.goalAmount.toFormattedString()} (Collecté : ${campaign.collectedAmount.toFormattedString()})',
                style: const TextStyle(fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              AjraCurrencyField(
                controller: amountController,
                label: 'Montant de votre contribution (MUR)',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMode,
                decoration: const InputDecoration(labelText: 'Mode de règlement hors-app'),
                items: const [
                  DropdownMenuItem(value: 'Virement bancaire MCB', child: Text('Virement MCB')),
                  DropdownMenuItem(value: 'Virement bancaire SBM', child: Text('Virement SBM')),
                  DropdownMenuItem(value: 'Espèces', child: Text('Espèces au responsable')),
                ],
                onChanged: (v) {
                  if (v != null) setModalState(() => paymentMode = v);
                },
              ),
              const SizedBox(height: 12),
              AjraTextField(
                controller: refController,
                label: 'Référence de transaction / reçu',
                hint: 'ex: DON-MCB-77221',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Déclarer la contribution'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final amount = Money.fromRupees(double.tryParse(amountController.text.trim()) ?? 0);
      if (amount.isZero) return;

      final repo = ref.read(eventsRepoProvider);
      await repo.declareContribution(
        campaignId: campaign.id,
        campaignTitle: campaign.title,
        userId: user.uid,
        contributorName: user.displayName,
        amount: amount,
        paymentMode: paymentMode,
        reference: refController.text.trim().isEmpty ? 'DON-${DateTime.now().millisecondsSinceEpoch}' : refController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Contribution déclarée ! En attente de vérification par le trésorier.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canManageEvents = user != null && (user.isAdmin || user.canManageEvents);

    return AppScaffold(
      selectedIndex: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Événements & Collectes'),
          actions: [
            if (canManageEvents)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Créer un événement',
                onPressed: _openNewEventDialog,
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Événements AJRA'),
              Tab(text: 'Collectes de fonds'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEventsTab(),
            _buildCampaignsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    final eventsAsync = ref.watch(eventsStreamProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const EmptyStateView(
            icon: Icons.event_busy_outlined,
            title: 'Aucun événement programmé',
            message: 'Les prochaines activités de l\'association seront annoncées ici.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final e = events[index];
            final dateStr = DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(e.startDate);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          e.type,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        e.status.label,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    e.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
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
                          e.location,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                  if (e.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      e.description,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget : ${e.estimatedBudget.toFormattedString()}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      AjraButton(
                        label: 'Je participe',
                        icon: Icons.check,
                        height: 36,
                        variant: AjraButtonVariant.primary,
                        onPressed: () {
                          final user = ref.read(currentUserProvider);
                          if (user != null) {
                            ref.read(eventsRepoProvider).registerParticipant(
                                  eventId: e.id,
                                  userId: user.uid,
                                  userName: user.displayName,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('Inscription à l\'événement confirmée !'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const LoadingStateView(message: 'Chargement des événements...'),
      error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
    );
  }

  Widget _buildCampaignsTab() {
    final campaignsAsync = ref.watch(campaignsStreamProvider);

    return campaignsAsync.when(
      data: (campaigns) {
        if (campaigns.isEmpty) {
          return const EmptyStateView(
            icon: Icons.volunteer_activism_outlined,
            title: 'Aucune collecte active',
            message: 'Les appels de dons solidaires apparaîtront dans cette rubrique.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: campaigns.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final c = campaigns[index];
            final pct = c.progressPercentage;

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          c.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(0)} %',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100.0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Collecté : ${c.collectedAmount.toFormattedString()}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                      Text(
                        'Objectif : ${c.goalAmount.toFormattedString()}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AjraButton(
                    label: 'Contribuer à cette collecte',
                    icon: Icons.volunteer_activism_outlined,
                    variant: AjraButtonVariant.primary,
                    height: 40,
                    onPressed: () => _openDonateDialog(c),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const LoadingStateView(message: 'Chargement des collectes...'),
      error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
    );
  }
}
