import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/cards/metric_card.dart';
import '../../../shared/widgets/forms/ajra_currency_field.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../accounting/models/financial_transaction.dart';
import '../../accounting/providers/accounting_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/services/notification_service.dart';
import '../../posts/models/post_item.dart';
import '../models/event_item.dart';
import '../models/event_transaction.dart';
import '../repositories/events_repository.dart';
import 'events_list_screen.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final EventItem event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _toggleParticipation(bool isRegistered) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final repo = ref.read(eventsRepoProvider);
    if (isRegistered) {
      await repo.unregisterParticipant(
        eventId: widget.event.id,
        userId: user.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre participation a été annulée.')),
        );
      }
    } else {
      await repo.registerParticipant(
        eventId: widget.event.id,
        userId: user.uid,
        userName: user.displayName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Participation confirmée avec succès !'),
          ),
        );
      }
    }
  }

  Future<void> _openAddTransactionDialog({required bool isIncome}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = isIncome ? 'Dotation Caisse AJRA' : 'Nourriture & Courses';
    String selectedMode = 'Espèces';
    bool debitAssociationCaisse = isIncome;
    String selectedAccountId = AppConstants.accountCash;

    final categories = isIncome
        ? [
            'Dotation Caisse AJRA',
            'Cotisation Sortie',
            'Don & Sponsor',
            'Vente & Recette',
            'Autre',
          ]
        : [
            'Nourriture & Courses',
            'Boissons',
            'Transport / Bus',
            'Matériel & Charbon',
            'Location & Salle',
            'Animation & Sono',
            'Autre',
          ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isIncome ? Icons.arrow_downward_rounded : Icons.shopping_cart_outlined,
                color: isIncome ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isIncome ? 'Ajouter une Entrée (Recette)' : 'Enregistrer une Dépense / Courses',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AjraTextField(
                  controller: titleController,
                  label: isIncome ? 'Libellé de la recette *' : 'Objet des courses ou achat *',
                  hint: isIncome ? 'Libellé de la recette...' : 'Objet de la dépense ou achat...',
                ),
                const SizedBox(height: 12),
                AjraCurrencyField(
                  controller: amountController,
                  label: 'Montant (${AppConstants.currencySymbol}) *',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() {
                        selectedCategory = v;
                        if (v == 'Dotation Caisse AJRA') {
                          debitAssociationCaisse = true;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Moyen de paiement'),
                  items: const [
                    DropdownMenuItem(value: 'Espèces', child: Text('Espèces (Cash)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Juice MCB', child: Text('Juice MCB', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                      value: 'Virement bancaire',
                      child: Text('Virement bancaire', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(value: 'Autre', child: Text('Autre', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedMode = v);
                  },
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: refController,
                  label: isIncome ? 'Référence paiement' : 'N° Ticket de caisse / Justificatif',
                  hint: isIncome ? 'Référence ou n° reçu' : 'N° facture ou ticket de caisse',
                ),
                const SizedBox(height: 12),
                AjraTextField(
                  controller: notesController,
                  label: 'Remarques ou détails des achats',
                  hint: 'Détails ou remarques complémentaires...',
                  maxLines: 2,
                ),
                if (isIncome) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: debitAssociationCaisse
                          ? AppColors.primary.withValues(alpha: 0.07)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: debitAssociationCaisse
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            'Sortie depuis la Caisse AJRA',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Déduire automatiquement cette somme de la trésorerie générale de l\'association',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: debitAssociationCaisse,
                          onChanged: (val) {
                            setModalState(() {
                              debitAssociationCaisse = val;
                              if (val && selectedCategory == 'Cotisation Sortie') {
                                selectedCategory = 'Dotation Caisse AJRA';
                              }
                            });
                          },
                        ),
                        if (debitAssociationCaisse) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: selectedAccountId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Compte de l\'association à débiter',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: AppConstants.accountCash,
                                child: Text('Caisse Espèces AJRA (Cash)', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.accountBank,
                                child: Text('Compte Bancaire Principal AJRA', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: AppConstants.accountJuice,
                                child: Text('Juice (MCB) AJRA', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setModalState(() => selectedAccountId = v);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
                final amt = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
                if (titleController.text.trim().isEmpty || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Veuillez saisir un libellé et un montant valide.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isIncome ? AppColors.success : AppColors.danger,
              ),
              child: Text(
                isIncome ? 'Valider l\'entrée' : 'Enregistrer la dépense',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final amount = Money.fromRupees(double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0);
      final tx = EventTransaction(
        id: const Uuid().v4(),
        eventId: widget.event.id,
        type: isIncome ? EventTransactionType.income : EventTransactionType.expense,
        title: titleController.text.trim(),
        amount: amount,
        category: selectedCategory,
        date: DateTime.now(),
        paymentMode: selectedMode,
        recordedByUserId: user.uid,
        recordedByName: user.displayName,
        receiptReference: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      await ref.read(eventsRepoProvider).addEventTransaction(tx);

      if (isIncome && debitAssociationCaisse) {
        final generalTx = FinancialTransaction(
          id: const Uuid().v4(),
          type: TransactionType.expense,
          category: 'Événement & Activités',
          amount: amount,
          date: DateTime.now(),
          description: 'Dotation Caisse pour l\'événement : ${widget.event.title} - ${titleController.text.trim()}',
          paymentMode: selectedMode,
          reference: refController.text.trim().isNotEmpty
              ? refController.text.trim()
              : 'EVT-${widget.event.id.length > 8 ? widget.event.id.substring(0, 8) : widget.event.id}',
          accountId: selectedAccountId,
          createdByUserId: user.uid,
          createdByName: user.displayName,
          validatedByUserId: user.uid,
          validatedByName: user.displayName,
          status: TransactionStatus.validated,
          linkedEntityType: 'event',
          linkedEntityId: widget.event.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await ref.read(accountingRepoProvider).createTransaction(generalTx);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isIncome ? AppColors.success : AppColors.danger,
            content: Text(
              isIncome
                  ? (debitAssociationCaisse
                      ? 'Entrée de ${amount.toFormattedString()} enregistrée et déduite de la Caisse générale AJRA avec succès !'
                      : 'Entrée enregistrée avec succès.')
                  : 'Dépense / Courses enregistrée avec succès.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _publishEventToFeed() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publier l\'événement'),
        content: Text(
          'Voulez-vous publier cet événement "${widget.event.title}" dans le fil d\'actualités de l\'association ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publier'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
      final postId = const Uuid().v4();
      final post = PostItem(
        id: postId,
        title: 'Sortie / Événement : ${widget.event.title}',
        content:
            'L\'association AJRA organise un événement :\n\n📍 Lieu : ${widget.event.location}\n🗓 Date : ${dateFormat.format(widget.event.startDate)}\n💰 PAF : ${widget.event.participationFee != null ? widget.event.participationFee!.toFormattedString() : "Gratuit"}\n\n${widget.event.description}',
        authorUserId: user.uid,
        authorName: user.displayName,
        publishedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection(AppConstants.colPosts)
          .doc(postId)
          .set(post.toJson());

      // Notification broadcast if bureau member
      await NotificationService.notifyIfBureauAction(
        actorUserId: user.uid,
        actorName: user.displayName,
        actorRole: user.role.code,
        title: 'Nouvel Événement Publié',
        body: 'Le bureau a publié l\'événement "${widget.event.title}" prévu le ${dateFormat.format(widget.event.startDate)}.',
        entityType: 'event',
        entityId: widget.event.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Événement publié dans les actualités avec succès !'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final repo = ref.watch(eventsRepoProvider);
    final canManageFinance = user?.role.isAdmin == true || user?.role.isBureau == true;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/events');
            }
          },
        ),
        title: Text(widget.event.title),
        actions: [
          if (canManageFinance)
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Publier dans le fil d\'actualités',
              onPressed: _publishEventToFeed,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bannière descriptive de l'événement
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.event.type,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.event.status.label,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.event.location,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Du ${dateFormat.format(widget.event.startDate)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
                if (widget.event.participationFee != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 16, color: Colors.black87),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Participation (PAF) : ${widget.event.participationFee!.toFormattedString()} / personne',
                            softWrap: true,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bouton de participation "Je participe ou pas" (pour TOUT le monde)
          StreamBuilder<List<EventParticipant>>(
            stream: repo.watchParticipants(widget.event.id),
            builder: (context, snapshot) {
              final participants = snapshot.data ?? [];
              final isUserRegistered = user != null && participants.any((p) => p.userId == user.uid);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: isUserRegistered ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Icon(
                      isUserRegistered ? Icons.check_circle_rounded : Icons.group_outlined,
                      color: isUserRegistered ? AppColors.success : AppColors.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUserRegistered ? 'Vous participez à cet événement !' : 'Participez à cette sortie',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isUserRegistered ? AppColors.success : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${participants.length} participant(s) confirmé(s)',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _toggleParticipation(isUserRegistered),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUserRegistered ? AppColors.dangerLight : AppColors.primary,
                        foregroundColor: isUserRegistered ? AppColors.danger : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        isUserRegistered ? 'Ne plus participer' : 'Je participe',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Onglets : 1. Bilan Financier (Entrées / Sorties / Courses) | 2. Participants
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryLight,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Bilan Financier & Courses'),
              Tab(icon: Icon(Icons.people_outline), text: 'Participants'),
            ],
          ),

          // Contenu plein écran réactif
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFinancialTab(context, repo, canManageFinance),
                _buildParticipantsTab(context, repo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTab(BuildContext context, BaseEventsRepository repo, bool canManageFinance) {
    return StreamBuilder<List<EventTransaction>>(
      stream: repo.watchEventTransactions(widget.event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingStateView(message: 'Calcul du budget de l\'événement...');
        }

        final txs = snapshot.data ?? [];
        int totalIncomeCents = 0;
        int totalExpenseCents = 0;

        for (final t in txs) {
          if (t.type == EventTransactionType.income) {
            totalIncomeCents += t.amount.cents;
          } else {
            totalExpenseCents += t.amount.cents;
          }
        }

        final totalIncome = Money.fromCents(totalIncomeCents);
        final totalExpense = Money.fromCents(totalExpenseCents);
        final netBalance = Money.fromCents(totalIncomeCents - totalExpenseCents);
        final isProfit = netBalance.cents >= 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Synthèse Bilan Financier
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Total Entrées',
                      value: totalIncome.toFormattedString(),
                      icon: Icons.arrow_downward_rounded,
                      iconColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      title: 'Total Sorties',
                      value: totalExpense.toFormattedString(),
                      icon: Icons.arrow_upward_rounded,
                      iconColor: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isProfit ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isProfit ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isProfit ? Icons.savings_outlined : Icons.warning_amber_rounded,
                            color: isProfit ? AppColors.success : AppColors.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isProfit ? 'Bénéfice Net (Excédent)' : 'Déficit Net',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isProfit ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                                Text(
                                  isProfit
                                      ? 'Excédent pour la caisse de l\'AJRA'
                                      : 'Dépenses supérieures aux recettes',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      netBalance.toFormattedString(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isProfit ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Boutons d'action pour Admin et Bureau uniquement
              if (canManageFinance) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter Entrée'),
                        onPressed: () => _openAddTransactionDialog(isIncome: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                        label: const Text('Enregistrer Courses'),
                        onPressed: () => _openAddTransactionDialog(isIncome: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Titre de l'historique
              const Text(
                'Détail des opérations & courses de l\'événement',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (txs.isEmpty)
                const EmptyStateView(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune opération enregistrée',
                  message: 'Les recettes et dépenses de courses apparaîtront ici.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tx = txs[index];
                    final isInc = tx.type == EventTransactionType.income;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isInc ? AppColors.successLight : AppColors.dangerLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isInc ? Icons.arrow_downward : Icons.shopping_bag_outlined,
                              size: 18,
                              color: isInc ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tx.category} • ${tx.paymentMode}${tx.receiptReference != null ? " • Réf: ${tx.receiptReference}" : ""}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                                if (tx.notes != null)
                                  Text(
                                    tx.notes!,
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isInc ? "+" : "-"}${tx.amount.toFormattedString()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isInc ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              if (canManageFinance)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.black38),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => repo.deleteEventTransaction(widget.event.id, tx.id),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticipantsTab(BuildContext context, BaseEventsRepository repo) {
    return StreamBuilder<List<EventParticipant>>(
      stream: repo.watchParticipants(widget.event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingStateView(message: 'Chargement des participants...');
        }

        final participants = snapshot.data ?? [];
        if (participants.isEmpty) {
          return const EmptyStateView(
            icon: Icons.person_off_outlined,
            title: 'Aucun participant pour le moment',
            message: 'Soyez le premier à vous inscrire avec le bouton "Je participe" !',
          );
        }

        final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: participants.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final part = participants[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                    child: Text(
                      part.userName.isNotEmpty ? part.userName[0].toUpperCase() : 'M',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Inscrit le ${dateFormat.format(part.registeredAt)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                  const ContainerBadge(label: 'Confirmé', color: AppColors.success),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class ContainerBadge extends StatelessWidget {
  final String label;
  final Color color;

  const ContainerBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
